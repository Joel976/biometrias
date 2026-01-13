import 'dart:convert';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../config/database_config.dart';
import '../models/biometric_models.dart';
import '../models/user.dart';

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
    // ✅ FIX: textos_dinamicos_audio NO tiene columna id_usuario (es tabla global)
    final result = await db.query(
      'textos_dinamicos_audio',
      where: 'estado_texto = ?',
      whereArgs: ['activo'],
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

  /// 🔄 Sincronizar frases del backend a la base de datos local
  Future<void> syncPhrasesFromBackend(
    List<Map<String, dynamic>> backendPhrases,
  ) async {
    final db = await _db;

    try {
      await db.transaction((txn) async {
        // 1. Limpiar frases existentes
        await txn.delete('textos_dinamicos_audio');

        // 2. Insertar nuevas frases del backend
        for (var phrase in backendPhrases) {
          await txn.insert('textos_dinamicos_audio', {
            'id_texto': phrase['id_texto'] ?? phrase['id'],
            'frase': phrase['frase'],
            'estado_texto': phrase['estado_texto'] ?? 'activo',
          });
        }
      });

      print(
        '[LocalDB] ✅ ${backendPhrases.length} frases sincronizadas desde backend',
      );
    } catch (e) {
      print('[LocalDB] ❌ Error sincronizando frases: $e');
    }
  }

  /// 📊 Obtener estadísticas de frases locales
  Future<Map<String, dynamic>> getPhrasesStats() async {
    final db = await _db;

    final total =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM textos_dinamicos_audio'),
        ) ??
        0;

    final activas =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM textos_dinamicos_audio WHERE estado_texto = ?',
            ['activo'],
          ),
        ) ??
        0;

    return {'total': total, 'activas': activas, 'inactivas': total - activas};
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
    String? fechaNacimiento,
    String? sexo,
    String estado = 'activo',
  }) async {
    final db = await _db;

    final userData = {
      'nombres': nombres,
      'apellidos': apellidos,
      'identificador_unico': identificadorUnico,
      'estado': estado,
      'fecha_registro': DateTime.now().toIso8601String(),
    };

    // Agregar campos opcionales solo si están presentes
    if (fechaNacimiento != null && fechaNacimiento.isNotEmpty) {
      userData['fecha_nacimiento'] = fechaNacimiento;
    }
    if (sexo != null && sexo.isNotEmpty) {
      userData['sexo'] = sexo;
    }

    final userId = await db.insert(
      'usuarios',
      userData,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // 🔥 AGREGAR A COLA DE SINCRONIZACIÓN
    if (userId > 0) {
      print('[LocalDB] 📋 Agregando usuario a cola de sincronización...');
      await insertToSyncQueue(userId, 'usuario', 'crear', userData);
      print('[LocalDB] ✅ Usuario agregado a cola de sincronización');
    }

    return userId;
  }

  // Nota: la verificación y almacenamiento de contraseñas fue removida.
  // Autenticación en la aplicación ahora se realiza exclusivamente por biometría.

  /// Obtener cola de sincronización pendiente para un usuario específico
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

  /// Obtener TODOS los datos pendientes de sincronización (todos los usuarios)
  Future<List<Map<String, dynamic>>> getAllPendingSyncQueue() async {
    final db = await _db;
    final rows = await db.query(
      'cola_sincronizacion',
      where: 'estado = ?',
      whereArgs: ['pendiente'],
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
      where: 'id = ?',
      whereArgs: [idCola],
    );
  }

  /// 🗑️ Limpiar items enviados de la cola de sincronización
  /// Elimina permanentemente los registros con estado='enviado'
  Future<int> cleanSentSyncQueue() async {
    final db = await _db;
    print('[LocalDB] 🗑️ Limpiando items ya enviados de la cola...');

    final deletedCount = await db.delete(
      'cola_sincronizacion',
      where: 'estado = ?',
      whereArgs: ['enviado'],
    );

    print('[LocalDB] ✅ $deletedCount items enviados eliminados de la cola');
    return deletedCount;
  }

  /// 📊 Obtener estadísticas de la base de datos local
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await _db;

    final usuarios = await db.query('usuarios');
    final credencialesOreja = await db.query(
      'credenciales_biometricas',
      where: 'tipo_biometria = ?',
      whereArgs: ['oreja'],
    );
    final credencialesVoz = await db.query(
      'credenciales_biometricas',
      where: 'tipo_biometria = ?',
      whereArgs: ['voz'],
    );
    final colaPendiente = await db.query(
      'cola_sincronizacion',
      where: 'estado = ?',
      whereArgs: ['pendiente'],
    );
    final colaEnviado = await db.query(
      'cola_sincronizacion',
      where: 'estado = ?',
      whereArgs: ['enviado'],
    );

    final stats = {
      'usuarios': usuarios.length,
      'credenciales_oreja': credencialesOreja.length,
      'credenciales_voz': credencialesVoz.length,
      'cola_pendiente': colaPendiente.length,
      'cola_enviado': colaEnviado.length,
    };

    print('[LocalDB] 📊 ESTADÍSTICAS DE BASE DE DATOS LOCAL:');
    print('[LocalDB]   👥 Usuarios: ${stats['usuarios']}');
    print('[LocalDB]   👂 Credenciales oreja: ${stats['credenciales_oreja']}');
    print('[LocalDB]   🎤 Credenciales voz: ${stats['credenciales_voz']}');
    print('[LocalDB]   📋 Cola pendiente: ${stats['cola_pendiente']}');
    print('[LocalDB]   ✅ Cola enviado: ${stats['cola_enviado']}');

    return stats;
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

  // =============== MÉTODOS DE COMPLETITUD POR ETAPAS ===============

  /// Actualizar estado de completitud de un usuario
  Future<void> updateUserCompletionStatus({
    required String identificadorUnico,
    bool? datosCompletos,
    bool? orejasCompletas,
    bool? vozCompleta,
  }) async {
    final db = await _db;
    final updates = <String, dynamic>{};

    if (datosCompletos != null) {
      updates['datos_completos'] = datosCompletos ? 1 : 0;
    }
    if (orejasCompletas != null) {
      updates['orejas_completas'] = orejasCompletas ? 1 : 0;
    }
    if (vozCompleta != null) {
      updates['voz_completa'] = vozCompleta ? 1 : 0;
    }

    if (updates.isNotEmpty) {
      await db.update(
        'usuarios',
        updates,
        where: 'identificador_unico = ?',
        whereArgs: [identificadorUnico],
      );
    }
  }

  /// Obtener estado de completitud de un usuario
  Future<Map<String, bool>> getUserCompletionStatus(
    String identificadorUnico,
  ) async {
    final db = await _db;
    final result = await db.query(
      'usuarios',
      columns: ['datos_completos', 'orejas_completas', 'voz_completa'],
      where: 'identificador_unico = ?',
      whereArgs: [identificadorUnico],
      limit: 1,
    );

    if (result.isEmpty) {
      return {
        'datosCompletos': false,
        'orejasCompletas': false,
        'vozCompleta': false,
      };
    }

    final row = result.first;
    return {
      'datosCompletos': (row['datos_completos'] as int?) == 1,
      'orejasCompletas': (row['orejas_completas'] as int?) == 1,
      'vozCompleta': (row['voz_completa'] as int?) == 1,
    };
  }

  /// Verificar si un usuario existe por su identificador
  Future<bool> userExists(String identificadorUnico) async {
    final db = await _db;
    final result = await db.query(
      'usuarios',
      columns: ['id_usuario'],
      where: 'identificador_unico = ?',
      whereArgs: [identificadorUnico],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Obtener todos los usuarios registrados
  Future<List<User>> getAllUsers() async {
    final db = await _db;
    final result = await db.query('usuarios', orderBy: 'fecha_registro DESC');

    return result.map((map) => User.fromJson(map)).toList();
  }

  /// Actualizar estado del usuario (eliminado/activo)
  Future<void> updateUserState(String identificadorUnico, String estado) async {
    final db = await _db;
    await db.update(
      'usuarios',
      {'estado': estado},
      where: 'identificador_unico = ?',
      whereArgs: [identificadorUnico],
    );
  }

  /// Eliminar usuario (soft delete - cambiar estado a 'eliminado')
  Future<void> deleteUser(String identificadorUnico) async {
    await updateUserState(identificadorUnico, 'eliminado');
  }

  /// Restaurar usuario (cambiar estado a 'activo')
  Future<void> restoreUser(String identificadorUnico) async {
    await updateUserState(identificadorUnico, 'activo');
  }

  /// � REPARAR COLA DE SINCRONIZACIÓN
  /// Encuentra credenciales locales que no estén en la cola y las agrega
  Future<int> repairSyncQueue() async {
    final db = await _db;
    int itemsAgregados = 0;

    print('[LocalDB] 🔧 Reparando cola de sincronización...');

    try {
      // 1. Buscar todos los usuarios locales
      final usuarios = await db.query('usuarios');
      print('[LocalDB] 👥 Encontrados ${usuarios.length} usuarios locales');

      for (var usuario in usuarios) {
        final idUsuario = usuario['id_usuario'] as int;
        final identificador = usuario['identificador_unico'] as String;

        print(
          '[LocalDB] 🔍 Verificando usuario: $identificador (ID: $idUsuario)',
        );

        // 2. Verificar si el usuario está en la cola
        final usuarioEnCola = await db.query(
          'cola_sincronizacion',
          where: 'id_usuario = ? AND tipo_entidad = ?',
          whereArgs: [idUsuario, 'usuario'],
        );

        if (usuarioEnCola.isEmpty) {
          print('[LocalDB] ➕ Agregando usuario a cola de sincronización...');
          await insertToSyncQueue(idUsuario, 'usuario', 'crear', {
            'identificador_unico': usuario['identificador_unico'],
            'nombres': usuario['nombres'],
            'apellidos': usuario['apellidos'],
            'correo': usuario['correo'],
            'celular': usuario['celular'],
          });
          itemsAgregados++;
        }

        // 3. Buscar credenciales de OREJA
        final credencialesOreja = await db.query(
          'credenciales_biometricas',
          where: 'id_usuario = ? AND tipo_biometria = ?',
          whereArgs: [idUsuario, 'oreja'],
        );

        print(
          '[LocalDB] 👂 Encontradas ${credencialesOreja.length} credenciales de oreja',
        );

        for (var credencial in credencialesOreja) {
          final idCredencial = credencial['id_credencial'] as int;

          // Verificar si esta credencial está en la cola
          final credencialEnCola = await db.query(
            'cola_sincronizacion',
            where: 'id_usuario = ? AND tipo_entidad = ? AND datos_json LIKE ?',
            whereArgs: [
              idUsuario,
              'credencial',
              '%"id_credencial":$idCredencial%',
            ],
          );

          if (credencialEnCola.isEmpty) {
            print(
              '[LocalDB] ➕ Agregando credencial oreja #$idCredencial a cola...',
            );
            await insertToSyncQueue(idUsuario, 'credencial', 'crear', {
              'id_credencial': idCredencial,
              'identificador_unico': identificador,
              'tipo_biometria': 'oreja',
              'template': credencial['template'],
            });
            itemsAgregados++;
          }
        }

        // 4. Buscar credenciales de VOZ
        final credencialesVoz = await db.query(
          'credenciales_biometricas',
          where: 'id_usuario = ? AND tipo_biometria = ?',
          whereArgs: [idUsuario, 'voz'],
        );

        print(
          '[LocalDB] 🎤 Encontradas ${credencialesVoz.length} credenciales de voz',
        );

        for (var credencial in credencialesVoz) {
          final idCredencial = credencial['id_credencial'] as int;

          // Verificar si esta credencial está en la cola
          final credencialEnCola = await db.query(
            'cola_sincronizacion',
            where: 'id_usuario = ? AND tipo_entidad = ? AND datos_json LIKE ?',
            whereArgs: [
              idUsuario,
              'credencial',
              '%"id_credencial":$idCredencial%',
            ],
          );

          if (credencialEnCola.isEmpty) {
            print(
              '[LocalDB] ➕ Agregando credencial voz #$idCredencial a cola...',
            );
            await insertToSyncQueue(idUsuario, 'credencial', 'crear', {
              'id_credencial': idCredencial,
              'identificador_unico': identificador,
              'tipo_biometria': 'voz',
              'template': credencial['template'],
            });
            itemsAgregados++;
          }
        }
      }

      print(
        '[LocalDB] ✅ Reparación completada: $itemsAgregados items agregados a cola',
      );
      return itemsAgregados;
    } catch (e) {
      print('[LocalDB] ❌ Error reparando cola: $e');
      return 0;
    }
  }

  /// �🗑️ ELIMINAR PERMANENTEMENTE un usuario y sus datos biométricos (solo offline)
  /// ADVERTENCIA: Esta acción NO se puede deshacer
  Future<void> deleteUserPermanently(String identificadorUnico) async {
    final db = await _db;

    print(
      '[LocalDB] 🗑️💀 Eliminando PERMANENTEMENTE usuario: $identificadorUnico',
    );

    // 0. Primero obtener el id_usuario (INTEGER) usando identificador_unico (TEXT)
    final userResult = await db.query(
      'usuarios',
      columns: ['id_usuario'],
      where: 'identificador_unico = ?',
      whereArgs: [identificadorUnico],
    );

    if (userResult.isEmpty) {
      print('[LocalDB] ⚠️ Usuario no encontrado: $identificadorUnico');
      return;
    }

    final idUsuario = userResult.first['id_usuario'] as int;
    print('[LocalDB] 📌 ID Usuario encontrado: $idUsuario');

    // 1. Eliminar credenciales biométricas (usa id_usuario INTEGER)
    final deletedCredentials = await db.delete(
      'credenciales_biometricas',
      where: 'id_usuario = ?',
      whereArgs: [idUsuario],
    );
    print(
      '[LocalDB] ✅ $deletedCredentials credenciales biométricas eliminadas',
    );

    // 2. Eliminar usuario (usa identificador_unico TEXT)
    final deletedUser = await db.delete(
      'usuarios',
      where: 'identificador_unico = ?',
      whereArgs: [identificadorUnico],
    );
    print('[LocalDB] ✅ Usuario eliminado de tabla usuarios');

    // 3. Eliminar de cola de sincronización (usa id_usuario INTEGER)
    final deletedQueue = await db.delete(
      'cola_sincronizacion',
      where: 'id_usuario = ?',
      whereArgs: [idUsuario],
    );
    print('[LocalDB] ✅ Eliminado de cola de sincronización');

    print(
      '[LocalDB] 💀 Eliminación permanente completada: $deletedUser usuario, $deletedCredentials credenciales, $deletedQueue registros de cola',
    );
  }
}
