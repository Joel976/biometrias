import 'package:connectivity_plus/connectivity_plus.dart';
import 'native_voice_mobile_service.dart';
import 'biometric_backend_service.dart';
import 'backend_service.dart';
import 'dart:io';

/// Servicio híbrido de autenticación que maneja:
/// - OFFLINE: Usa libvoz_mobile.so (FFI) para autenticación local
/// - ONLINE: Sincroniza con servidor PostgreSQL en la nube
class HybridAuthService {
  static final HybridAuthService _instance = HybridAuthService._internal();
  factory HybridAuthService() => _instance;
  HybridAuthService._internal();

  final NativeVoiceMobileService _nativeService = NativeVoiceMobileService();
  final BiometricBackendService _backendService = BiometricBackendService();
  final BackendService _backend = BackendService();
  final Connectivity _connectivity = Connectivity();

  bool _isInitialized = false;
  bool _isOnline = false;

  // 🔄 Control de sincronización - solo una vez cada 30 minutos
  DateTime? _lastSyncTime;
  static const Duration _syncCooldown = Duration(minutes: 30);

  // 👥 Usuarios ya sincronizados (para no volver a intentar)
  final Set<String> _syncedUsers = {};

  /// Inicializa el servicio híbrido
  Future<bool> initialize() async {
    if (_isInitialized) {
      print('[HybridAuthService] ✅ Ya inicializado');
      return true;
    }

    print('[HybridAuthService] 🚀 Inicializando servicio híbrido...');

    // 1. Inicializar servicio nativo (librería .so)
    final nativeOk = await _nativeService.initialize();
    if (!nativeOk) {
      print('[HybridAuthService] ⚠️ Error inicializando servicio nativo');
      return false;
    }

    // 2. Verificar conectividad
    _isOnline = await _backend.isOnline();
    print('[HybridAuthService] 📶 Modo: ${_isOnline ? "ONLINE" : "OFFLINE"}');

    // 3. Configurar listener de conectividad
    _connectivity.onConnectivityChanged.listen((result) {
      _onConnectivityChanged(result.first);
    });

    _isInitialized = true;
    print('[HybridAuthService] ✅ Servicio híbrido inicializado');
    return true;
  }

  /// Maneja cambios en la conectividad
  void _onConnectivityChanged(ConnectivityResult result) async {
    final wasOffline = !_isOnline;
    _isOnline = await _backend.isOnline();

    print(
      '[HybridAuthService] 📶 Conectividad cambió: ${_isOnline ? "ONLINE" : "OFFLINE"}',
    );

    if (wasOffline && _isOnline) {
      // Recuperó conexión → Verificar si debe sincronizar
      print('[HybridAuthService] 🔄 Conexión recuperada');

      // Solo sincronizar si han pasado más de 30 minutos desde la última sincronización
      final now = DateTime.now();
      final shouldSync =
          _lastSyncTime == null ||
          now.difference(_lastSyncTime!) > _syncCooldown;

      if (shouldSync) {
        print(
          '[HybridAuthService] ✅ Iniciando sincronización (última: ${_lastSyncTime ?? "nunca"})',
        );
        await syncPendingData();
        _lastSyncTime = now;
      } else {
        final minutesSinceLastSync = now.difference(_lastSyncTime!).inMinutes;
        print(
          '[HybridAuthService] ⏭️ Sincronización omitida (última hace $minutesSinceLastSync min, cooldown: 30 min)',
        );
      }
    }
  }

  // ==========================================================================
  // REGISTRO DE USUARIO
  // ==========================================================================

  /// Registra un usuario con biometría de voz
  /// - ONLINE: Registra directo en servidor + guarda local
  /// - OFFLINE: Guarda local y encola para sincronizar
  Future<Map<String, dynamic>> registerUser({
    required String identificador,
    required String nombres,
    required String apellidos,
    required String audioPath,
    String? email,
  }) async {
    if (!_isInitialized) {
      throw Exception(
        'Servicio no inicializado. Llama a initialize() primero.',
      );
    }

    print('[HybridAuthService] 📝 Registrando usuario: $identificador');
    print('[HybridAuthService] 🎤 Audio: $audioPath');
    print('[HybridAuthService] 📶 Modo: ${_isOnline ? "ONLINE" : "OFFLINE"}');

    try {
      // 1. Obtener frase aleatoria para registro
      final fraseData = await _nativeService.obtenerFraseAleatoria();
      final idFrase = fraseData['id_frase'] as int;
      final frase = fraseData['frase'] as String;

      print('[HybridAuthService] 💬 Frase: "$frase" (ID: $idFrase)');

      // 2. Registrar biometría LOCALMENTE (siempre)
      print('[HybridAuthService] 🔐 Registrando biometría local...');
      final localResult = await _nativeService.registerBiometric(
        identificador: identificador,
        audioPath: audioPath,
        idFrase: idFrase,
      );

      if (localResult['success'] != true) {
        print('[HybridAuthService] ❌ Error en registro local');
        return {
          'success': false,
          'error': 'Error en registro biométrico local',
          'details': localResult,
        };
      }

      print('[HybridAuthService] ✅ Biometría registrada localmente');

      // 3. Si está ONLINE, registrar también en el servidor
      if (_isOnline) {
        try {
          print('[HybridAuthService] ☁️ Registrando en servidor...');

          // Registrar usuario en PostgreSQL
          await _backend.registerUser(
            nombres: nombres,
            apellidos: apellidos,
            identificadorUnico: identificador,
          );

          // Enviar biometría al servidor (requiere múltiples audios, por ahora solo enviamos uno)
          final audioBytes = await File(audioPath).readAsBytes();
          await _backendService.registrarBiometriaVoz(
            identificador: identificador,
            audios: [
              audioBytes,
            ], // Nota: el backend espera 5-6 audios, aquí solo enviamos 1
          );

          print('[HybridAuthService] ✅ Usuario registrado en servidor');

          // ✅ Marcar como sincronizado para no volver a intentar
          _syncedUsers.add(identificador);
          print(
            '[HybridAuthService] 🔒 Usuario $identificador marcado como sincronizado',
          );

          return {
            'success': true,
            'mode': 'online',
            'message': 'Usuario registrado exitosamente (online)',
            'user_id': localResult['user_id'],
            'credential_id': localResult['credential_id'],
          };
        } catch (e) {
          print('[HybridAuthService] ⚠️ Error sincronizando con servidor: $e');
          print(
            '[HybridAuthService] 📝 Datos guardados localmente, se sincronizarán después',
          );

          return {
            'success': true,
            'mode': 'offline',
            'message':
                'Usuario registrado localmente (se sincronizará cuando haya conexión)',
            'user_id': localResult['user_id'],
            'pending_sync': true,
          };
        }
      } else {
        // Modo OFFLINE
        print(
          '[HybridAuthService] 📱 Modo offline: datos en cola de sincronización',
        );

        return {
          'success': true,
          'mode': 'offline',
          'message':
              'Usuario registrado localmente (se sincronizará cuando haya conexión)',
          'user_id': localResult['user_id'],
          'pending_sync': true,
        };
      }
    } catch (e) {
      print('[HybridAuthService] ❌ Error en registro: $e');
      return {
        'success': false,
        'error': 'Error al registrar usuario',
        'details': e.toString(),
      };
    }
  }

  // ==========================================================================
  // AUTENTICACIÓN
  // ==========================================================================

  /// Autentica un usuario por voz
  /// - ONLINE: Valida contra servidor (modelo global actualizado)
  /// - OFFLINE: Valida localmente con modelo local
  Future<Map<String, dynamic>> authenticate({
    required String identificador,
    required String audioPath,
  }) async {
    if (!_isInitialized) {
      throw Exception(
        'Servicio no inicializado. Llama a initialize() primero.',
      );
    }

    print('[HybridAuthService] 🔓 Autenticando usuario: $identificador');
    print('[HybridAuthService] 🎤 Audio: $audioPath');
    print('[HybridAuthService] 📶 Modo: ${_isOnline ? "ONLINE" : "OFFLINE"}');

    try {
      // 1. Verificar que el usuario existe
      final userExists = _nativeService.usuarioExiste(identificador);
      if (!userExists) {
        print('[HybridAuthService] ❌ Usuario no encontrado');
        return {
          'success': false,
          'authenticated': false,
          'error': 'Usuario no registrado',
        };
      }

      // 2. Obtener frase para autenticación
      final fraseData = await _nativeService.obtenerFraseAleatoria();
      final idFrase = fraseData['id_frase'] as int;
      final frase = fraseData['frase'] as String;

      print('[HybridAuthService] 💬 Frase: "$frase" (ID: $idFrase)');

      // 3. INTENTAR PRIMERO EN SERVIDOR (si hay conexión)
      if (_isOnline) {
        try {
          print('[HybridAuthService] ☁️ Autenticando contra servidor...');

          final audioBytes = await File(audioPath).readAsBytes();
          final serverResult = await _backendService.autenticarVoz(
            audioBytes: audioBytes,
            identificador: identificador,
            idFrase: idFrase,
          );
          if (serverResult['success'] == true) {
            print('[HybridAuthService] ✅ Autenticación exitosa (servidor)');

            // También registrar localmente
            await _nativeService.authenticate(
              identificador: identificador,
              audioPath: audioPath,
              idFrase: idFrase,
            );

            return {
              'success': true,
              'authenticated': serverResult['autenticado'] == true,
              'mode': 'online',
              'confidence': serverResult['data']?['confianza'] ?? 0.0,
              'message': 'Autenticación validada por servidor',
              'details': serverResult['data'],
            };
          }
        } catch (e) {
          print(
            '[HybridAuthService] ⚠️ Error en servidor, usando validación local: $e',
          );
          // Continuar con validación local (fallback)
        }
      }

      // 4. VALIDACIÓN LOCAL (offline o fallback)
      print('[HybridAuthService] 🔐 Autenticando localmente...');
      final localResult = await _nativeService.authenticate(
        identificador: identificador,
        audioPath: audioPath,
        idFrase: idFrase,
      );

      if (localResult['success'] == true) {
        final authenticated = localResult['authenticated'] == true;
        print(
          '[HybridAuthService] ${authenticated ? "✅" : "❌"} Resultado local: ${authenticated ? "ACEPTADO" : "RECHAZADO"}',
        );

        return {
          'success': true,
          'authenticated': authenticated,
          'mode': 'offline',
          'confidence': localResult['confidence'] ?? localResult['confianza'],
          'message': authenticated
              ? 'Autenticación exitosa (local)'
              : 'Autenticación rechazada (local)',
        };
      } else {
        print('[HybridAuthService] ❌ Error en autenticación local');
        return {
          'success': false,
          'authenticated': false,
          'error': 'Error en autenticación',
          'details': localResult,
        };
      }
    } catch (e) {
      print('[HybridAuthService] ❌ Error en autenticación: $e');
      return {
        'success': false,
        'authenticated': false,
        'error': 'Error al autenticar',
        'details': e.toString(),
      };
    }
  }

  // ==========================================================================
  // SINCRONIZACIÓN
  // ==========================================================================

  /// Sincroniza datos pendientes con el servidor
  /// ⚠️ PENDIENTE: Adaptar a nueva API de libvoz_mobile.so
  Future<Map<String, dynamic>> syncPendingData() async {
    if (!_isInitialized) {
      throw Exception('Servicio no inicializado');
    }

    if (!_isOnline) {
      print('[HybridAuthService] ⚠️ Sin conexión, no se puede sincronizar');
      return {'success': false, 'error': 'Sin conexión a internet'};
    }

    print('[HybridAuthService] 🔄 Iniciando sincronización...');
    print(
      '[HybridAuthService] ⚠️ Sincronización manual no implementada en nueva API',
    );
    print('[HybridAuthService] ℹ️ Usa SyncManager en su lugar');

    // TODO: Migrar a usar syncPush/syncPull/syncModelo de libvoz_mobile.so
    return {
      'success': false,
      'error': 'Sincronización manual no implementada',
      'message': 'Usa SyncManager para sincronización automática',
    };
  }

  /// Obtiene el estado de sincronización
  /// ⚠️ PENDIENTE: Adaptar a nueva API de libvoz_mobile.so
  Future<Map<String, dynamic>> getSyncStatus() async {
    if (!_isInitialized) {
      throw Exception('Servicio no inicializado');
    }

    // TODO: Implementar con nueva API
    return {
      'pending_count': 0,
      'pending_items': [],
      'is_online': _isOnline,
      'can_sync': false,
      'message': 'Usa SyncManager para gestión de cola',
    };
  }

  // ==========================================================================
  // UTILIDADES
  // ==========================================================================

  /// Verifica si hay conexión
  Future<bool> checkConnectivity() async {
    _isOnline = await _backend.isOnline();
    return _isOnline;
  }

  /// Obtiene información del servicio
  Map<String, dynamic> getServiceInfo() {
    return {
      'initialized': _isInitialized,
      'is_online': _isOnline,
      'native_version': _isInitialized ? _nativeService.getVersion() : 'N/A',
      'last_error': _isInitialized ? _nativeService.getUltimoError() : 'N/A',
    };
  }

  /// Limpia recursos
  void cleanup() {
    if (_isInitialized) {
      _nativeService.cleanup();
      _isInitialized = false;
      print('[HybridAuthService] 🧹 Recursos liberados');
    }
  }
}
