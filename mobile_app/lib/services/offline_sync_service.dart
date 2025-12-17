import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

/// Modelo para datos en cola de sincronización
class PendingData {
  final int id;
  final String endpoint;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final String? photoBase64; // Para fotos de oreja
  final String? audioBase64; // Para audio de voz

  PendingData({
    required this.id,
    required this.endpoint,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.photoBase64,
    this.audioBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'endpoint': endpoint,
      'data': jsonEncode(data),
      'photo_base64': photoBase64,
      'audio_base64': audioBase64,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
    };
  }

  static PendingData fromMap(Map<String, dynamic> map) {
    return PendingData(
      id: map['id'] as int,
      endpoint: map['endpoint'] as String,
      data: _parseJsonMap(map['data']),
      photoBase64: map['photo_base64'] as String?,
      audioBase64: map['audio_base64'] as String?,
      createdAt: DateTime.parse(map['created_at']),
      retryCount: map['retry_count'] ?? 0,
    );
  }

  static Map<String, dynamic> _parseJsonMap(dynamic data) {
    if (data is String) {
      try {
        return Map<String, dynamic>.from(jsonDecode(data));
      } catch (_) {
        return {};
      }
    }
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }
}

/// Servicio de almacenamiento offline con SQLite
class OfflineSyncService {
  static const String _dbName = 'biometrics_offline.db';
  static const String _tableName = 'pending_sync';
  static const int _version = 1;

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, _dbName);

    return openDatabase(
      fullPath,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        endpoint TEXT NOT NULL,
        data TEXT NOT NULL,
        photo_base64 TEXT,
        audio_base64 TEXT,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Índices para mejor performance
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_synced ON $_tableName(synced)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_created_at ON $_tableName(created_at)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Futuras migraciones aquí
    }
  }

  /// Guardar datos pendientes de sincronizar
  Future<int> savePendingData({
    required String endpoint,
    required Map<String, dynamic> data,
    String? photoBase64,
    String? audioBase64,
  }) async {
    final db = await database;
    final pendingData = PendingData(
      id: 0,
      endpoint: endpoint,
      data: data,
      createdAt: DateTime.now(),
      photoBase64: photoBase64,
      audioBase64: audioBase64,
    );

    try {
      return await db.insert(_tableName, {
        'endpoint': pendingData.endpoint,
        'data': jsonEncode(pendingData.data),
        'photo_base64': pendingData.photoBase64,
        'audio_base64': pendingData.audioBase64,
        'created_at': pendingData.createdAt.toIso8601String(),
        'retry_count': 0,
        'synced': 0,
      });
    } catch (e) {
      debugPrint('Error guardando datos pendientes: $e');
      rethrow;
    }
  }

  /// Obtener todos los datos pendientes
  Future<List<PendingData>> getPendingData({int limit = 10}) async {
    final db = await database;
    try {
      final result = await db.query(
        _tableName,
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'created_at ASC',
        limit: limit,
      );
      return result.map((map) => PendingData.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error obteniendo datos pendientes: $e');
      return [];
    }
  }

  /// Marcar dato como sincronizado
  Future<void> markAsSynced(int id) async {
    final db = await database;
    try {
      await db.update(
        _tableName,
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error marcando como sincronizado: $e');
    }
  }

  /// Incrementar contador de reintentos
  Future<void> incrementRetryCount(int id) async {
    final db = await database;
    try {
      await db.rawUpdate(
        'UPDATE $_tableName SET retry_count = retry_count + 1 WHERE id = ?',
        [id],
      );
    } catch (e) {
      debugPrint('Error incrementando reintentos: $e');
    }
  }

  /// Eliminar dato (después de sincronización exitosa)
  Future<void> deletePendingData(int id) async {
    final db = await database;
    try {
      await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('Error eliminando dato: $e');
    }
  }

  /// Obtener cantidad de datos pendientes
  Future<int> getPendingCount() async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName WHERE synced = 0',
      );
      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      debugPrint('Error obteniendo cantidad pendiente: $e');
      return 0;
    }
  }

  /// Limpiar datos sincronizados antiguos (> 30 días)
  Future<void> cleanupOldSyncedData({int daysOld = 30}) async {
    final db = await database;
    try {
      final cutoffDate = DateTime.now()
          .subtract(Duration(days: daysOld))
          .toIso8601String();
      await db.delete(
        _tableName,
        where: 'synced = 1 AND created_at < ?',
        whereArgs: [cutoffDate],
      );
    } catch (e) {
      debugPrint('Error limpiando datos antiguos: $e');
    }
  }

  /// Cerrar base de datos
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// ==========================================
  /// SINCRONIZACIÓN BIDIRECCIONAL
  /// ==========================================

  /// Obtener última fecha de sincronización
  Future<DateTime?> getLastSyncTime() async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT MAX(created_at) as last_sync FROM $_tableName WHERE synced = 1',
      );
      final lastSyncStr = result.first['last_sync'] as String?;
      if (lastSyncStr != null) {
        return DateTime.parse(lastSyncStr);
      }
      return null;
    } catch (e) {
      debugPrint('Error obteniendo última sincronización: $e');
      return null;
    }
  }
}
