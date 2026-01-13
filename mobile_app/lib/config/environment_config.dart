/// Configuración de ambiente para desarrollo y producción
/// Maneja URLs dinámicas y cambio automático entre local/remoto
class EnvironmentConfig {
  // ============================================
  // CONFIGURACIÓN DE AMBIENTE
  // ============================================

  /// Ambiente actual: 'development', 'staging', 'production'
  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  /// Modo offline-first (trabaja siempre con SQLite local)
  static const bool offlineFirst = bool.fromEnvironment(
    'OFFLINE_FIRST',
    defaultValue: false,
  );

  // ============================================
  // URLs DEL BACKEND
  // ============================================

  /// URL base para oreja (puerto 8080)
  static String get orejaBackendUrl {
    return 'http://167.71.155.9:8080';
  }

  /// URL base para voz (puerto 8081)
  static String get vozBackendUrl {
    return 'http://167.71.155.9:8081';
  }

  /// URL del backend según el ambiente (LEGACY - usar orejaBackendUrl o vozBackendUrl)
  static String get backendUrl {
    switch (environment) {
      case 'production':
        // URLs de producción en la nube
        return _productionUrl ?? 'http://167.71.155.9:3001';

      case 'staging':
        return 'http://staging-server.com:3000/api';

      case 'development':
      default:
        // Red local para desarrollo
        return 'http://10.52.41.36:3000/api';
    }
  }

  /// URL de producción (puede ser actualizada en runtime)
  static String? _productionUrl;

  /// Actualizar URL de producción dinámicamente
  static void setProductionUrl(String url) {
    _productionUrl = url;
    print('[EnvironmentConfig] 🌐 URL de producción actualizada: $url');
  }

  // ============================================
  // ENDPOINTS DEL BACKEND
  // ============================================

  static String get healthEndpoint => '/health';

  // Usuarios
  static String get registerUserEndpoint => '/usuarios';
  static String getUserEndpoint(String identificador) =>
      '/usuarios/$identificador';

  // Biometría - Oreja
  static String get registerEarEndpoint => '/biometria/registrar-oreja';
  static String get verifyEarEndpoint => '/biometria/verificar-oreja';

  // Biometría - Voz
  static String get registerVoiceEndpoint => '/biometria/registrar-voz';
  static String get verifyVoiceEndpoint => '/biometria/verificar-voz';

  // Frases dinámicas
  static String get getDynamicPhraseEndpoint => '/frases/obtener-activa';

  // ============================================
  // CONFIGURACIÓN DE TIMEOUTS
  // ============================================

  static Duration get connectTimeout {
    return environment == 'production'
        ? Duration(seconds: 15)
        : Duration(seconds: 10);
  }

  static Duration get receiveTimeout {
    return environment == 'production'
        ? Duration(seconds: 45) // Entrenamiento ML puede tardar
        : Duration(seconds: 30);
  }

  // ============================================
  // CONFIGURACIÓN DE ML
  // ============================================

  /// Requiere mínimo 3 fotos para entrenar modelo de oreja
  static const int minEarPhotos = 3;

  /// Requiere 1 audio de mínimo 5 segundos para entrenar voz
  static const int minVoiceDuration = 5; // segundos

  /// Umbral de confianza para aceptar autenticación biométrica
  static const double confidenceThreshold = 0.75; // 75%

  /// Umbral específico para oreja (validación TFLite local)
  static const double earConfidenceThreshold = 0.65; // 65%

  // ============================================
  // CONFIGURACIÓN DE SINCRONIZACIÓN
  // ============================================

  /// Intervalo de sincronización automática (minutos)
  static const int autoSyncIntervalMinutes = 15;

  /// Reintentar sincronización fallida después de N minutos
  static const int retryFailedSyncMinutes = 5;

  /// Máximo de reintentos antes de marcar como error permanente
  static const int maxSyncRetries = 3;

  // ============================================
  // HELPERS
  // ============================================

  /// Verificar si estamos en producción
  static bool get isProduction => environment == 'production';

  /// Verificar si estamos en desarrollo
  static bool get isDevelopment => environment == 'development';

  /// Verificar si modo offline está habilitado
  static bool get isOfflineMode => offlineFirst;

  /// Obtener información del ambiente actual
  static Map<String, dynamic> get environmentInfo => {
    'environment': environment,
    'backend_url': backendUrl,
    'offline_first': offlineFirst,
    'is_production': isProduction,
    'connect_timeout_seconds': connectTimeout.inSeconds,
    'receive_timeout_seconds': receiveTimeout.inSeconds,
  };

  /// Imprimir configuración actual (para debugging)
  static void printConfig() {
    print('╔═══════════════════════════════════════════╗');
    print('║     CONFIGURACIÓN DE AMBIENTE             ║');
    print('╠═══════════════════════════════════════════╣');
    print('║ Ambiente: $environment');
    print('║ Backend URL: $backendUrl');
    print('║ Offline First: $offlineFirst');
    print('║ Timeout Conexión: ${connectTimeout.inSeconds}s');
    print('║ Timeout Recepción: ${receiveTimeout.inSeconds}s');
    print('║ Min Fotos Oreja: $minEarPhotos');
    print('║ Min Duración Voz: ${minVoiceDuration}s');
    print('║ Umbral Confianza: ${(confidenceThreshold * 100).toInt()}%');
    print('╚═══════════════════════════════════════════╝');
  }
}
