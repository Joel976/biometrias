import 'dart:convert';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../config/database_config.dart';
import '../models/biometric_models.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();

  factory LocalDatabaseService() {
    return _instance;
  }

  LocalDatabaseService._internal();

  Future<Database> get _db async {
    return await DatabaseConfig().database;
  }

  // =============== CREDENCIALES BIOMÉTRICAS ===============

  Future<int> insertBiometricCredential(BiometricCredential credential) async {
    final db = await _db;
    return await db.insert(
      'credenciales_biometricas',
      credential.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<BiometricCredential?> getBiometricCredential(int id) async {
    final db = await _db;
    final result = await db.query(
      'credenciales_biometricas',
      where: 'id_credencial = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) return null;
    return BiometricCredential.fromMap(result.first);
  }

  Future<List<BiometricCredential>> getCredentialsByUserAndType(
    int idUsuario,
    String tipoBiometria,
  ) async {
    final db = await _db;
    final result = await db.query(
      'credenciales_biometricas',
      where: 'id_usuario = ? AND tipo_biometria = ?',
      whereArgs: [idUsuario, tipoBiometria],
      orderBy: 'id_credencial DESC',
    );

    return result.map((map) => BiometricCredential.fromMap(map)).toList();
  }

  Future<void> deleteExpiredCredentials() async {
    final db = await _db;
    await db.delete(
      'credenciales_biometricas',
      where: 'validez_hasta < datetime("now")',
    );
  }

  // =============== FRASES DE AUDIO ===============

  Future<int> insertAudioPhrase(AudioPhrase phrase) async {
    final db = await _db;
    return await db.insert('textos_dinamicos_audio', phrase.toMap());
  }

  Future<List<AudioPhrase>> getActiveAudioPhrases(int idUsuario) async {
    final db = await _db;
    final result = await db.query(
      'textos_dinamicos_audio',
      where: 'id_usuario = ? AND estado_texto = ?',
      whereArgs: [idUsuario, 'activo'],
    );

    return result.map((map) => AudioPhrase.fromMap(map)).toList();
  }

  Future<AudioPhrase?> getRandomAudioPhrase(int idUsuario) async {
    final phrases = await getActiveAudioPhrases(idUsuario);
    if (phrases.isEmpty) return null;

    phrases.shuffle();
    return phrases.first;
  }

  Future<void> updateAudioPhraseStatus(int idTexto, String estado) async {
    final db = await _db;
    await db.update(
      'textos_dinamicos_audio',
      {'estado_texto': estado},
      where: 'id_texto = ?',
      whereArgs: [idTexto],
    );
  }

  // =============== VALIDACIONES BIOMÉTRICAS ===============

  Future<int> insertValidation(BiometricValidation validation) async {
    final db = await _db;
    return await db.insert('validaciones_biometricas', validation.toMap());
  }

  Future<List<BiometricValidation>> getValidationsByUser(
    int idUsuario, {
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _db;
    final result = await db.query(
      'validaciones_biometricas',
      where: 'id_usuario = ?',
      whereArgs: [idUsuario],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return result.map((map) => BiometricValidation.fromMap(map)).toList();
  }

  Future<List<BiometricValidation>> getFailedValidationsRecent(
    int idUsuario,
    Duration duration,
  ) async {
    final db = await _db;
    final cutoffTime = DateTime.now().subtract(duration);

    final result = await db.query(
      'validaciones_biometricas',
      where: 'id_usuario = ? AND resultado = ? AND timestamp > ?',
      whereArgs: [idUsuario, 'fallo', cutoffTime.toIso8601String()],
      orderBy: 'timestamp DESC',
    );

    return result.map((map) => BiometricValidation.fromMap(map)).toList();
  }

  Future<Map<String, int>> getSuccessRate(
    int idUsuario,
    String tipoBiometria,
  ) async {
    final db = await _db;

    final successResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM validaciones_biometricas WHERE id_usuario = ? AND tipo_biometria = ? AND resultado = ?',
      [idUsuario, tipoBiometria, 'exito'],
    );

    final failureResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM validaciones_biometricas WHERE id_usuario = ? AND tipo_biometria = ? AND resultado = ?',
      [idUsuario, tipoBiometria, 'fallo'],
    );

    return {
      'exito': successResult.first['count'] as int? ?? 0,
      'fallo': failureResult.first['count'] as int? ?? 0,
    };
  }

  // =============== SINCRONIZACIÓN ===============

  Future<int> insertSyncState(SyncState syncState) async {
    final db = await _db;
    return await db.insert('sincronizaciones', syncState.toMap());
  }

  Future<SyncState?> getLastSyncState(int idUsuario) async {
    final db = await _db;
    final result = await db.query(
      'sincronizaciones',
      where: 'id_usuario = ?',
      whereArgs: [idUsuario],
      orderBy: 'fecha_ultima_sync DESC',
      limit: 1,
    );

    if (result.isEmpty) return null;
    return SyncState.fromMap(result.first);
  }

  Future<void> insertToSyncQueue(
    int idUsuario,
    String tipoEntidad,
    String operacion,
    Map<String, dynamic> datos,
  ) async {
    final db = await _db;
    // Generar local_uuid si no viene dentro de datos
    final localUuid = datos.containsKey('local_uuid')
        ? datos['local_uuid'].toString()
        : 'local-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';

    final payload = Map<String, dynamic>.from(datos);
    payload['local_uuid'] = localUuid;

    await db.insert('cola_sincronizacion', {
      'id_usuario': idUsuario,
      'tipo_entidad': tipoEntidad,
      'operacion': operacion,
      'datos_json': jsonEncode(payload),
      'local_uuid': localUuid,
      'estado': 'pendiente',
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
  }

  /// Obtener usuario local por su identificador único (ej: cédula)
  Future<Map<String, dynamic>?> getUserByIdentifier(
    String identificador,
  ) async {
    final db = await _db;
    final result = await db.query(
      'usuarios',
      where: 'identificador_unico = ?',
      whereArgs: [identificador],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return result.first;
  }

  /// Insertar usuario local (sin contraseña)
  Future<int> insertUser({
    required String nombres,
    required String apellidos,
    required String identificadorUnico,
    String estado = 'activo',
  }) async {
    final db = await _db;
    final localUuid =
        'local-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';

    return await db.insert('usuarios', {
      'nombres': nombres,
      'apellidos': apellidos,
      'identificador_unico': identificadorUnico,
      'estado': estado,
      'local_uuid': localUuid,
      'remote_id': null,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // Nota: la verificación y almacenamiento de contraseñas fue removida.
  // Autenticación en la aplicación ahora se realiza exclusivamente por biometría.

  Future<List<Map<String, dynamic>>> getPendingSyncQueue(int idUsuario) async {
    final db = await _db;
    final rows = await db.query(
      'cola_sincronizacion',
      where: 'id_usuario = ? AND estado = ?',
      whereArgs: [idUsuario, 'pendiente'],
      orderBy: 'fecha_creacion ASC',
    );

    // Parsear datos_json a Map para facilidad de uso
    return rows.map((r) {
      final parsed = <String, dynamic>{};
      try {
        if (r['datos_json'] != null) {
          parsed.addAll(jsonDecode(r['datos_json'] as String));
        }
      } catch (_) {}
      final out = Map<String, dynamic>.from(r);
      out['datos_parsed'] = parsed;
      return out;
    }).toList();
  }

  Future<void> markSyncQueueAsProcessed(int idCola) async {
    final db = await _db;
    await db.update(
      'cola_sincronizacion',
      {'estado': 'enviado'},
      where: 'id_cola = ?',
      whereArgs: [idCola],
    );
  }

  /// Actualizar remote_id de usuario según su local_uuid
  Future<void> updateUserRemoteIdByLocalUuid(
    String localUuid,
    int remoteId,
  ) async {
    final db = await _db;
    await db.update(
      'usuarios',
      {'remote_id': remoteId},
      where: 'local_uuid = ?',
      whereArgs: [localUuid],
    );
  }

  /// Actualizar remote_id de credencial por local_uuid
  Future<void> updateCredentialRemoteIdByLocalUuid(
    String localUuid,
    int remoteId,
  ) async {
    final db = await _db;
    await db.update(
      'credenciales_biometricas',
      {'remote_id': remoteId},
      where: 'local_uuid = ?',
      whereArgs: [localUuid],
    );
  }

  // =============== LIMPIAR DATOS ===============

  Future<void> clearOldData({
    Duration olderThan = const Duration(days: 30),
  }) async {
    final db = await _db;
    final cutoffDate = DateTime.now().subtract(olderThan);

    // Limpiar validaciones antiguas
    await db.delete(
      'validaciones_biometricas',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );

    // Limpiar sincronizaciones antiguas
    await db.delete(
      'sincronizaciones',
      where: 'fecha_ultima_sync < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  Future<void> clearAll() async {
    final db = await _db;
    await db.delete('credenciales_biometricas');
    await db.delete('textos_dinamicos_audio');
    await db.delete('validaciones_biometricas');
    await db.delete('sincronizaciones');
    await db.delete('cola_sincronizacion');
  }
}
