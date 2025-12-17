import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/api_config.dart';
import '../services/local_database_service.dart';
import '../services/offline_sync_service.dart';
import '../models/biometric_models.dart';

/// Servicio de sincronización bidireccional
/// Maneja el flujo de datos Backend ↔ Frontend
/// ✨ REACTIVO: La UI puede escuchar cambios en tiempo real
class BidirectionalSyncService {
  final Dio _dio;
  final LocalDatabaseService _localDb;
  final OfflineSyncService _offlineSync;
  final FlutterSecureStorage _storage;
  final Connectivity _connectivity;

  // Timer para sincronización automática
  Timer? _autoSyncTimer;
  bool _isSyncing = false;

  // Suscripción a cambios de conectividad
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasInternet = false;
  int _syncAttempts = 0; // Contador para logs

  // Stream Controllers para UI reactiva
  final _connectivityController = StreamController<bool>.broadcast();
  final _syncStatusController =
      StreamController<Map<String, dynamic>>.broadcast();

  BidirectionalSyncService({
    Dio? dio,
    LocalDatabaseService? localDb,
    OfflineSyncService? offlineSync,
    FlutterSecureStorage? storage,
    Connectivity? connectivity,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: ApiConfig.baseUrl,
               connectTimeout: ApiConfig.connectTimeout,
               receiveTimeout: ApiConfig.receiveTimeout,
             ),
           ),
       _localDb = localDb ?? LocalDatabaseService(),
       _offlineSync = offlineSync ?? OfflineSyncService(),
       _storage = storage ?? const FlutterSecureStorage(),
       _connectivity = connectivity ?? Connectivity() {
    // Verificar conectividad inicial
    _checkInitialConnectivity();
  }

  /// Verificar conectividad al inicializar
  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _hasInternet = _isConnected(results);
      _connectivityController.add(_hasInternet); // Notificar a listeners
      debugPrint(
        '[Sync] 📡 Conectividad inicial: ${_hasInternet ? 'ONLINE ✅' : 'OFFLINE ❌'}',
      );
    } catch (e) {
      debugPrint('[Sync] ⚠️ Error verificando conectividad: $e');
      _hasInternet = false;
      _connectivityController.add(false);
    }
  }

  /// Verificar si hay conexión a internet
  bool _isConnected(List<ConnectivityResult> results) {
    return results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet,
    );
  }

  /// Verificar conectividad actual
  Future<bool> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final wasConnected = _hasInternet;
      _hasInternet = _isConnected(results);

      // Notificar cambio de estado a la UI
      if (wasConnected != _hasInternet) {
        _connectivityController.add(_hasInternet);
      }

      return _hasInternet;
    } catch (e) {
      debugPrint('[Sync] ⚠️ Error verificando conectividad: $e');
      _hasInternet = false;
      _connectivityController.add(false);
      return false;
    }
  }

  /// ==========================================
  /// 1. SUBIDA (App → Backend)
  /// ==========================================

  /// Sincronizar datos pendientes hacia el backend
  Future<Map<String, dynamic>> syncUpToBackend() async {
    if (_isSyncing) {
      return {'success': false, 'error': 'Sincronización en progreso'};
    }

    _isSyncing = true;
    try {
      final pendingData = await _offlineSync.getPendingData(limit: 50);

      if (pendingData.isEmpty) {
        debugPrint('[SyncUp] No hay datos pendientes');
        return {'success': true, 'uploaded': 0};
      }

      debugPrint('[SyncUp] ${pendingData.length} registros pendientes');

      int uploaded = 0;
      int failed = 0;

      for (final item in pendingData) {
        try {
          final response = await _dio.post(
            item.endpoint,
            data: {
              ...item.data,
              'photo_base64': item.photoBase64,
              'audio_base64': item.audioBase64,
            },
            options: Options(
              headers: {'Authorization': 'Bearer ${await _getToken()}'},
            ),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            await _offlineSync.markAsSynced(item.id);
            await _offlineSync.deletePendingData(item.id);
            uploaded++;
            debugPrint('[SyncUp] ✅ Sincronizado: ${item.endpoint}');
          }
        } catch (e) {
          debugPrint('[SyncUp] ❌ Error: ${item.endpoint} - $e');
          await _offlineSync.incrementRetryCount(item.id);
          failed++;
        }
      }

      debugPrint('[SyncUp] Resultado: $uploaded exitosos, $failed fallidos');
      return {'success': true, 'uploaded': uploaded, 'failed': failed};
    } catch (e) {
      debugPrint('[SyncUp] Error general: $e');
      return {'success': false, 'error': e.toString()};
    } finally {
      _isSyncing = false;
    }
  }

  /// ==========================================
  /// 2. DESCARGA (Backend → App)
  /// ==========================================

  /// Descargar datos nuevos desde el backend
  Future<Map<String, dynamic>> syncDownFromBackend({
    required int idUsuario,
    String? dispositivoId,
  }) async {
    if (_isSyncing) {
      return {'success': false, 'error': 'Sincronización en progreso'};
    }

    _isSyncing = true;
    try {
      // Obtener última fecha de sincronización
      final lastSync = await _offlineSync.getLastSyncTime();

      debugPrint('[SyncDown] Última sincronización: $lastSync');
      debugPrint('[SyncDown] Descargando datos para usuario: $idUsuario');

      // Llamar al endpoint de descarga
      final response = await _dio.post(
        '/sync/descarga',
        data: {
          'id_usuario': idUsuario,
          'dispositivo_id': dispositivoId ?? 'unknown',
          'ultima_sync': lastSync?.toIso8601String(),
        },
        options: Options(
          headers: {'Authorization': 'Bearer ${await _getToken()}'},
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Error en descarga: ${response.statusCode}');
      }

      final datos = response.data['datos'] as Map<String, dynamic>?;
      if (datos == null) {
        return {'success': true, 'downloaded': 0};
      }

      int downloaded = 0;

      // Procesar credenciales biométricas
      final credenciales = datos['credenciales_biometricas'] as List<dynamic>?;
      if (credenciales != null) {
        for (final credData in credenciales) {
          try {
            // Convertir template de String base64 a List<int>
            final templateStr = credData['template'] as String? ?? '';
            final templateBytes = templateStr.isNotEmpty
                ? templateStr.codeUnits
                : <int>[];

            final credential = BiometricCredential(
              id: credData['id_credencial'] ?? 0,
              idUsuario: credData['id_usuario'] ?? idUsuario,
              tipoBiometria: credData['tipo_biometria'] ?? '',
              template: templateBytes,
              validezHasta: credData['validez_hasta'] != null
                  ? DateTime.parse(credData['validez_hasta'])
                  : null,
              versionAlgoritmo: credData['version_algoritmo'] ?? '1.0',
            );
            await _localDb.insertBiometricCredential(credential);
            downloaded++;
            debugPrint('[SyncDown] ✅ Credencial guardada: ${credential.id}');
          } catch (e) {
            debugPrint('[SyncDown] ❌ Error guardando credencial: $e');
          }
        }
      }

      // Procesar textos de audio
      final textosAudio = datos['textos_audio'] as List<dynamic>?;
      if (textosAudio != null) {
        for (final textoData in textosAudio) {
          try {
            final audioPhrase = AudioPhrase(
              id: textoData['id_texto'] ?? 0,
              idUsuario: textoData['id_usuario'] ?? idUsuario,
              frase: textoData['frase'] ?? '',
              estadoTexto: textoData['estado_texto'] ?? 'activo',
              fechaAsignacion: textoData['fecha_asignacion'] != null
                  ? DateTime.parse(textoData['fecha_asignacion'])
                  : DateTime.now(),
            );
            await _localDb.insertAudioPhrase(audioPhrase);
            downloaded++;
            debugPrint(
              '[SyncDown] ✅ Frase de audio guardada: ${audioPhrase.id}',
            );
          } catch (e) {
            debugPrint('[SyncDown] ❌ Error guardando frase: $e');
          }
        }
      }

      debugPrint('[SyncDown] Resultado: $downloaded registros descargados');
      return {
        'success': true,
        'downloaded': downloaded,
        'timestamp': response.data['timestamp'],
      };
    } catch (e) {
      debugPrint('[SyncDown] Error general: $e');
      return {'success': false, 'error': e.toString()};
    } finally {
      _isSyncing = false;
    }
  }

  /// ==========================================
  /// 3. SINCRONIZACIÓN COMPLETA (Bidireccional)
  /// ==========================================

  /// Sincronización completa: Subir + Descargar
  Future<Map<String, dynamic>> fullSync({
    required int idUsuario,
    String? dispositivoId,
  }) async {
    debugPrint('[FullSync] Iniciando sincronización completa');

    // 1. Subir datos pendientes
    final uploadResult = await syncUpToBackend();

    // 2. Descargar datos nuevos
    final downloadResult = await syncDownFromBackend(
      idUsuario: idUsuario,
      dispositivoId: dispositivoId,
    );

    return {
      'success': uploadResult['success'] && downloadResult['success'],
      'upload': uploadResult,
      'download': downloadResult,
    };
  }

  /// ==========================================
  /// 4. SINCRONIZACIÓN AUTOMÁTICA
  /// ==========================================

  /// Iniciar sincronización automática periódica
  /// Verifica conectividad cada 5 segundos (para testing) y solo sincroniza si hay internet
  void startAutoSync({
    required int idUsuario,
    String? dispositivoId,
    Duration interval = const Duration(seconds: 5), // 5 segundos para testing
  }) {
    stopAutoSync(); // Detener timer anterior si existe

    debugPrint(
      '[AutoSync] 🔄 Iniciando monitoreo cada ${interval.inSeconds} segundos',
    );

    _autoSyncTimer = Timer.periodic(interval, (timer) async {
      _syncAttempts++;

      // Verificar conectividad
      final hasConnection = await _checkConnectivity();

      debugPrint(
        '[AutoSync] 📡 Verificación #$_syncAttempts: ${hasConnection ? '✅ ONLINE' : '❌ OFFLINE'}',
      );

      // Notificar estado a la UI
      _syncStatusController.add({
        'checking': true,
        'hasInternet': hasConnection,
        'attempts': _syncAttempts,
      });

      if (!hasConnection) {
        debugPrint('[AutoSync] ⏭️ Sin internet, sincronización omitida');
        _syncStatusController.add({
          'checking': false,
          'hasInternet': false,
          'skipped': true,
        });
        return; // No sincronizar
      }

      // Solo sincronizar si hay internet
      debugPrint(
        '[AutoSync] 🔄 Internet detectado. Sincronizando pendientes...',
      );
      _syncStatusController.add({'syncing': true, 'hasInternet': true});

      final result = await fullSync(
        idUsuario: idUsuario,
        dispositivoId: dispositivoId,
      );

      debugPrint(
        '[AutoSync] Resultado: ${result['success'] ? '✅ Exitoso' : '❌ Fallido'}',
      );

      // Notificar resultado a la UI
      _syncStatusController.add({
        'syncing': false,
        'completed': true,
        'success': result['success'],
        'uploaded': result['upload']?['uploaded'] ?? 0,
        'downloaded': result['download']?['downloaded'] ?? 0,
      });
    });
  }

  /// Detener sincronización automática
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;

    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    debugPrint('[AutoSync] 🛑 Monitoreo detenido');
  }

  /// ==========================================
  /// UTILIDADES
  /// ==========================================

  /// Obtener token de autenticación
  Future<String?> _getToken() async {
    try {
      return await _storage.read(key: 'auth_token');
    } catch (e) {
      debugPrint('[Sync] Error obteniendo token: $e');
      return null;
    }
  }

  /// Verificar si hay sincronización en progreso
  bool get isSyncing => _isSyncing;

  /// Verificar estado de conexión a internet
  bool get hasInternet => _hasInternet;

  /// Obtener número de verificaciones realizadas
  int get syncAttempts => _syncAttempts;

  /// Stream para escuchar cambios de conectividad en la UI
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Stream para escuchar estado de sincronización en la UI
  Stream<Map<String, dynamic>> get syncStatusStream =>
      _syncStatusController.stream;

  /// Limpiar recursos
  void dispose() {
    stopAutoSync();
    _connectivityController.close();
    _syncStatusController.close();
    debugPrint('[Sync] 🧹 Recursos liberados');
  }
}
