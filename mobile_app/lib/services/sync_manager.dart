import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/api_config.dart';
import '../services/local_database_service.dart';
import '../services/offline_sync_service.dart';
import '../services/admin_settings_service.dart';
import '../models/biometric_models.dart';
import 'package:dio/dio.dart';

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();

  factory SyncManager() {
    return _instance;
  }

  SyncManager._internal();

  final _connectivity = Connectivity();
  final _localDb = LocalDatabaseService();
  final _offlineSync = OfflineSyncService();
  final _api = ApiConfig();
  final _adminService = AdminSettingsService();

  Timer? _syncTimer;
  bool _isSyncing = false;
  Duration _syncInterval = Duration(
    minutes: 5,
  ); // Default, se actualiza desde admin

  // Configuración de reintentos (se actualiza desde admin settings)
  int _maxRetries = 5;
  static const _initialRetryDelayMs = 5000; // 5 segundos
  static const _maxRetryDelayMs = 1800000; // 30 minutos

  // Stream para notificaciones de sync
  final _syncStatusStream = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatus => _syncStatusStream.stream;

  // Iniciar sincronización automática
  void startAutoSync() async {
    // Cargar configuraciones de admin
    try {
      final settings = await _adminService.loadSettings();
      _syncInterval = Duration(minutes: settings.syncIntervalMinutes);
      _maxRetries = settings.maxRetryAttempts;

      if (settings.enableDebugLogs) {
        print(
          '[SyncManager] ⚙️ Configurado con intervalo: ${settings.syncIntervalMinutes} min, reintentos: ${settings.maxRetryAttempts}',
        );
      }
    } catch (e) {
      print(
        '[SyncManager] ⚠️ Error cargando configuraciones, usando valores por defecto: $e',
      );
    }

    _syncTimer?.cancel();

    // Solo iniciar auto-sync si está habilitado en configuraciones
    final settings = await _adminService.loadSettings();
    if (!settings.autoSyncEnabled) {
      if (settings.enableDebugLogs) {
        print('[SyncManager] ⏸️ Auto-sync deshabilitado en configuraciones');
      }
      return;
    }

    _syncTimer = Timer.periodic(_syncInterval, (_) async {
      await performSync();
    });
  }

  // Detener sincronización automática
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // Realizar sincronización
  Future<SyncResult> performSync({int idUsuario = 1}) async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sincronización ya en progreso',
      );
    }

    _isSyncing = true;
    _emitStatus(SyncStatus.syncing);

    try {
      // Verificar conectividad con timeout
      final connectivityResult = await _connectivity
          .checkConnectivity()
          .timeout(
            Duration(seconds: 5),
            onTimeout: () {
              print('[SyncManager] ⚠️ Timeout verificando conectividad');
              return [ConnectivityResult.none];
            },
          );

      final isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      if (!isOnline) {
        _emitStatus(SyncStatus.offline);
        return SyncResult(success: false, message: 'Sin conexión de red');
      }

      // Ping al servidor
      final pingSuccess = await _pingServer();
      if (!pingSuccess) {
        _emitStatus(SyncStatus.serverUnavailable);
        return SyncResult(success: false, message: 'Servidor no disponible');
      }

      // Sincronización bidireccional
      var uploadSuccess = false;
      var downloadSuccess = false;

      // 1. Subir datos (App → Backend)
      uploadSuccess = await _uploadData(idUsuario);

      // 2. Descargar datos (Backend → App)
      downloadSuccess = await _downloadData(idUsuario);

      final overallSuccess = uploadSuccess && downloadSuccess;

      if (overallSuccess) {
        _emitStatus(SyncStatus.syncComplete);

        // Registrar sincronización exitosa
        final syncState = SyncState(
          id: 0,
          idUsuario: idUsuario,
          fechaUltimoSync: DateTime.now(),
          tipoSync: 'bidireccional',
          estadoSync: 'completo',
          cantidadItems: 0,
        );
        await _localDb.insertSyncState(syncState);
      } else {
        _emitStatus(SyncStatus.syncError);
      }

      return SyncResult(
        success: overallSuccess,
        message: overallSuccess
            ? 'Sincronización exitosa'
            : 'Error parcial en sincronización',
      );
    } catch (error) {
      _emitStatus(SyncStatus.syncError);
      return SyncResult(
        success: false,
        message: 'Error durante sincronización: $error',
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Guardar datos para sincronización offline (cuando no hay conexión)
  Future<int> saveDataForOfflineSync({
    required String endpoint,
    required Map<String, dynamic> data,
    String? photoBase64,
    String? audioBase64,
  }) async {
    try {
      return await _offlineSync.savePendingData(
        endpoint: endpoint,
        data: data,
        photoBase64: photoBase64,
        audioBase64: audioBase64,
      );
    } catch (e) {
      print('Error guardando dato offline: $e');
      rethrow;
    }
  }

  /// Obtener cantidad de datos pendientes de sincronizar
  Future<int> getPendingSyncCount() async {
    try {
      return await _offlineSync.getPendingCount();
    } catch (e) {
      print('Error obteniendo contador: $e');
      return 0;
    }
  }

  /// Stream para monitorear cantidad de datos pendientes
  Stream<int> getPendingSyncCountStream() async* {
    while (true) {
      final count = await getPendingSyncCount();
      yield count;
      await Future.delayed(Duration(seconds: 5));
    }
  }

  /// Sincronizar datos offline pendientes
  Future<SyncResult> syncOfflineData() async {
    try {
      final pendingDataList = await _offlineSync.getPendingData(limit: 10);

      if (pendingDataList.isEmpty) {
        return SyncResult(success: true, message: 'Sin datos pendientes');
      }

      int syncedCount = 0;
      int failedCount = 0;

      for (final pendingData in pendingDataList) {
        try {
          // Intentar sincronizar
          final response = await _api.dio
              .post(pendingData.endpoint, data: pendingData.data)
              .timeout(Duration(seconds: 30));

          if (response.statusCode == 200 || response.statusCode == 201) {
            // Exitoso
            await _offlineSync.deletePendingData(pendingData.id);
            syncedCount++;
          } else {
            // Error temporal, reintentar luego
            await _offlineSync.incrementRetryCount(pendingData.id);
            failedCount++;
          }
        } catch (e) {
          print('Error sincronizando dato ${pendingData.id}: $e');
          await _offlineSync.incrementRetryCount(pendingData.id);
          failedCount++;
        }
      }

      final success = failedCount == 0;
      final message = success
          ? 'Sincronizados $syncedCount datos'
          : '$syncedCount sincronizados, $failedCount fallidos. Reintentarán luego.';

      return SyncResult(success: success, message: message);
    } catch (e) {
      return SyncResult(success: false, message: 'Error sincronizando: $e');
    }
  }

  Future<bool> _pingServer() async {
    try {
      final response = await _api.dio
          .get(
            '/sync/ping',
            options: Options(
              sendTimeout: Duration(seconds: 5),
              receiveTimeout: Duration(seconds: 5),
            ),
          )
          .timeout(Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (error) {
      print('Error en ping: $error');
      return false;
    }
  }

  // Subir datos al backend
  Future<bool> _uploadData(int idUsuario) async {
    try {
      final pendingSync = await _localDb.getPendingSyncQueue(idUsuario);

      if (pendingSync.isEmpty) {
        return true; // Nada que subir
      }

      final creaciones = <Map<String, dynamic>>[];
      final validations = <Map<String, dynamic>>[];

      for (var item in pendingSync) {
        final tipo = item['tipo_entidad'];
        final datos = item['datos_parsed'] ?? {};
        final localUuid = item['local_uuid'] ?? datos['local_uuid'];
        final idCola = item['id_cola'];

        if (tipo == 'usuario' || tipo == 'credencial') {
          creaciones.add({
            'tipo_entidad': tipo,
            'datos': datos,
            'local_uuid': localUuid,
            'id_cola': idCola,
          });
        } else if (tipo == 'validacion' ||
            (tipo is String && tipo.contains('validacion'))) {
          // Esperamos que datos contengan estructura con tipo_biometria, resultado, etc.
          validations.add({
            'tipo_biometria': datos['tipo_biometria'] ?? 'voz',
            'resultado': datos['resultado'] ?? 'exito',
            'modo_validacion': datos['modo_validacion'] ?? 'offline',
            'puntuacion_confianza': datos['puntuacion_confianza'] ?? 0,
            'ubicacion_gps': datos['ubicacion_gps'],
            'local_uuid': localUuid,
            'id_cola': idCola,
          });
        }
      }

      final payload = {
        'dispositivo_id': 'device_${idUsuario}',
        'creaciones': creaciones,
        'validaciones': validations,
      };

      final response = await _api.dio
          .post('/sync/subida', data: payload)
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Procesar mappings devueltos por backend
        final mappings = response.data['mappings'] as List? ?? [];

        for (var m in mappings) {
          try {
            final entidad = m['entidad'];
            final localUuid = m['local_uuid'];
            final remoteId = m['remote_id'];
            final idCola = m['id_cola'] ?? m['id_cola_local'];

            if (entidad == 'usuario') {
              if (localUuid != null && remoteId != null) {
                await _localDb.updateUserRemoteIdByLocalUuid(
                  localUuid,
                  remoteId,
                );
              }
            } else if (entidad == 'credencial') {
              if (localUuid != null && remoteId != null) {
                await _localDb.updateCredentialRemoteIdByLocalUuid(
                  localUuid,
                  remoteId,
                );
              }
            }

            if (idCola != null) {
              await _localDb.markSyncQueueAsProcessed(idCola);
            }
          } catch (e) {
            print('Error procesando mapping: $e');
          }
        }

        // Marcar como enviados los que no estén en mappings pero fueron incluidos
        for (var item in pendingSync) {
          final idCola = item['id_cola'];
          await _localDb.markSyncQueueAsProcessed(idCola);
        }

        return true;
      }

      return false;
    } catch (error) {
      print('Error al subir datos: $error');
      return false;
    }
  }

  // Descargar datos del backend
  Future<bool> _downloadData(int idUsuario) async {
    try {
      final lastSync = await _localDb.getLastSyncState(idUsuario);
      final ultimaSync = lastSync?.fechaUltimoSync ?? DateTime(2000);

      final response = await _api.dio
          .post(
            '/sync/descarga',
            data: {
              'id_usuario': idUsuario,
              'ultima_sync': ultimaSync.toIso8601String(),
              'dispositivo_id': 'device_$idUsuario',
            },
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200 && response.data['success'] == true) {
        final datos = response.data['datos'];

        // Procesar usuarios
        if (datos['usuarios'] is List) {
          for (var user in datos['usuarios'] as List) {
            // Aquí se guardarían los usuarios localmente
          }
        }

        // Procesar credenciales
        if (datos['credenciales_biometricas'] is List) {
          for (var cred in datos['credenciales_biometricas'] as List) {
            // Procesar credencial
          }
        }

        // Procesar frases de audio
        if (datos['textos_audio'] is List) {
          for (var frase in datos['textos_audio'] as List) {
            // Procesar frase
          }
        }

        return true;
      }

      return false;
    } catch (error) {
      print('Error al descargar datos: $error');
      return false;
    }
  }

  // Reintentar con backoff exponencial
  Future<T> _retryWithBackoff<T>(
    Future<T> Function() operation, {
    int retryCount = 0,
  }) async {
    try {
      return await operation();
    } catch (error) {
      if (retryCount < _maxRetries) {
        final delay = _calculateBackoffDelay(retryCount);
        await Future.delayed(delay);
        return _retryWithBackoff(operation, retryCount: retryCount + 1);
      } else {
        rethrow;
      }
    }
  }

  Duration _calculateBackoffDelay(int retryCount) {
    final delayMs = (_initialRetryDelayMs * (1 << retryCount)).clamp(
      0,
      _maxRetryDelayMs,
    );
    return Duration(milliseconds: delayMs as int);
  }

  void _emitStatus(SyncStatus status) {
    _syncStatusStream.add(status);
  }

  void dispose() {
    stopAutoSync();
    _syncStatusStream.close();
  }
}

class SyncResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  SyncResult({required this.success, required this.message, this.data});
}

enum SyncStatus {
  idle,
  syncing,
  offline,
  serverUnavailable,
  syncComplete,
  syncError,
}
