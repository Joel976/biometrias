/// Modelo para las configuraciones de administrador
class AdminSettings {
  // Tema
  bool isDarkMode;

  // Configuraciones de sincronización
  int syncIntervalMinutes;
  int maxRetryAttempts;
  bool autoSyncEnabled;

  // Configuraciones de seguridad
  int sessionTimeoutMinutes;
  bool biometricRequired;
  int maxLoginAttempts;

  // Configuraciones de red
  String apiBaseUrl;
  int requestTimeoutSeconds;
  bool allowInsecureConnections;

  // ✅ NUEVO: URLs del backend biométrico en la nube
  String backendIp;
  int backendPuertoOreja;
  int backendPuertoVoz;

  // Configuraciones de debug
  bool enableDebugLogs;
  bool showNetworkIndicator;
  bool showSyncStatus;

  // Configuraciones de biometría
  int minPhotoQuality;
  int audioRecordingDuration;
  bool allowMultipleRegistrations;
  bool enableEarValidation; // Nueva: Habilitar validación con TFLite
  bool
  requireAllFieldsInRegistration; // Nueva: Bloquear "Siguiente" si hay campos vacíos
  bool
  requireBothBiometricsInLogin; // Nueva: Requerir AMBAS biometrías (oreja Y voz) en el login

  // Configuraciones de notificaciones
  int
  offlineMessageIntervalMinutes; // Intervalo para mostrar mensaje de "sin conexión"

  AdminSettings({
    this.isDarkMode = false,
    this.syncIntervalMinutes = 5,
    this.maxRetryAttempts = 5,
    this.autoSyncEnabled = true,
    this.sessionTimeoutMinutes = 30,
    this.biometricRequired = true,
    this.maxLoginAttempts = 3,
    this.apiBaseUrl = 'http://10.52.41.36:3000/api',
    this.requestTimeoutSeconds = 30,
    this.allowInsecureConnections = true,
    // ✅ NUEVO: Valores por defecto del backend en la nube
    this.backendIp = '167.71.155.9',
    this.backendPuertoOreja = 8080,
    this.backendPuertoVoz = 8081,
    this.enableDebugLogs = true,
    this.showNetworkIndicator = true,
    this.showSyncStatus = true,
    this.minPhotoQuality = 70,
    this.audioRecordingDuration = 5,
    this.allowMultipleRegistrations = true,
    this.enableEarValidation = true, // ✅ HABILITADO para testing
    this.requireAllFieldsInRegistration =
        true, // ✅ Por defecto requiere todos los campos
    this.requireBothBiometricsInLogin =
        false, // ✅ Por defecto NO requiere ambas biometrías
    this.offlineMessageIntervalMinutes = 1, // ✅ Mostrar mensaje cada 1 minuto
  });

  /// Convertir a Map para guardar en storage
  Map<String, dynamic> toJson() {
    return {
      'isDarkMode': isDarkMode,
      'syncIntervalMinutes': syncIntervalMinutes,
      'maxRetryAttempts': maxRetryAttempts,
      'autoSyncEnabled': autoSyncEnabled,
      'sessionTimeoutMinutes': sessionTimeoutMinutes,
      'biometricRequired': biometricRequired,
      'maxLoginAttempts': maxLoginAttempts,
      'apiBaseUrl': apiBaseUrl,
      'requestTimeoutSeconds': requestTimeoutSeconds,
      'allowInsecureConnections': allowInsecureConnections,
      'backendIp': backendIp, // ✅ NUEVO
      'backendPuertoOreja': backendPuertoOreja, // ✅ NUEVO
      'backendPuertoVoz': backendPuertoVoz, // ✅ NUEVO
      'enableDebugLogs': enableDebugLogs,
      'showNetworkIndicator': showNetworkIndicator,
      'showSyncStatus': showSyncStatus,
      'minPhotoQuality': minPhotoQuality,
      'audioRecordingDuration': audioRecordingDuration,
      'allowMultipleRegistrations': allowMultipleRegistrations,
      'enableEarValidation': enableEarValidation,
      'requireAllFieldsInRegistration': requireAllFieldsInRegistration,
      'requireBothBiometricsInLogin': requireBothBiometricsInLogin,
      'offlineMessageIntervalMinutes': offlineMessageIntervalMinutes,
    };
  }

  /// Crear desde Map guardado en storage
  factory AdminSettings.fromJson(Map<String, dynamic> json) {
    return AdminSettings(
      isDarkMode: json['isDarkMode'] ?? false,
      syncIntervalMinutes: json['syncIntervalMinutes'] ?? 5,
      maxRetryAttempts: json['maxRetryAttempts'] ?? 5,
      autoSyncEnabled: json['autoSyncEnabled'] ?? true,
      sessionTimeoutMinutes: json['sessionTimeoutMinutes'] ?? 30,
      biometricRequired: json['biometricRequired'] ?? true,
      maxLoginAttempts: json['maxLoginAttempts'] ?? 3,
      apiBaseUrl: json['apiBaseUrl'] ?? 'http://10.52.41.36:3000/api',
      requestTimeoutSeconds: json['requestTimeoutSeconds'] ?? 30,
      allowInsecureConnections: json['allowInsecureConnections'] ?? true,
      backendIp: json['backendIp'] ?? '167.71.155.9', // ✅ NUEVO
      backendPuertoOreja: json['backendPuertoOreja'] ?? 8080, // ✅ NUEVO
      backendPuertoVoz: json['backendPuertoVoz'] ?? 8081, // ✅ NUEVO
      enableDebugLogs: json['enableDebugLogs'] ?? true,
      showNetworkIndicator: json['showNetworkIndicator'] ?? true,
      showSyncStatus: json['showSyncStatus'] ?? true,
      minPhotoQuality: json['minPhotoQuality'] ?? 70,
      audioRecordingDuration: json['audioRecordingDuration'] ?? 5,
      allowMultipleRegistrations: json['allowMultipleRegistrations'] ?? true,
      enableEarValidation: json['enableEarValidation'] ?? false,
      requireAllFieldsInRegistration:
          json['requireAllFieldsInRegistration'] ?? true,
      requireBothBiometricsInLogin:
          json['requireBothBiometricsInLogin'] ?? false,
      offlineMessageIntervalMinutes: json['offlineMessageIntervalMinutes'] ?? 1,
    );
  }

  /// Crear copia con cambios
  AdminSettings copyWith({
    bool? isDarkMode,
    int? syncIntervalMinutes,
    int? maxRetryAttempts,
    bool? autoSyncEnabled,
    int? sessionTimeoutMinutes,
    bool? biometricRequired,
    int? maxLoginAttempts,
    String? apiBaseUrl,
    int? requestTimeoutSeconds,
    bool? allowInsecureConnections,
    String? backendIp, // ✅ NUEVO
    int? backendPuertoOreja, // ✅ NUEVO
    int? backendPuertoVoz, // ✅ NUEVO
    bool? enableDebugLogs,
    bool? showNetworkIndicator,
    bool? showSyncStatus,
    int? minPhotoQuality,
    int? audioRecordingDuration,
    bool? allowMultipleRegistrations,
    bool? enableEarValidation,
    bool? requireAllFieldsInRegistration,
    bool? requireBothBiometricsInLogin,
    int? offlineMessageIntervalMinutes,
  }) {
    return AdminSettings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      sessionTimeoutMinutes:
          sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      biometricRequired: biometricRequired ?? this.biometricRequired,
      maxLoginAttempts: maxLoginAttempts ?? this.maxLoginAttempts,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      requestTimeoutSeconds:
          requestTimeoutSeconds ?? this.requestTimeoutSeconds,
      allowInsecureConnections:
          allowInsecureConnections ?? this.allowInsecureConnections,
      backendIp: backendIp ?? this.backendIp, // ✅ NUEVO
      backendPuertoOreja:
          backendPuertoOreja ?? this.backendPuertoOreja, // ✅ NUEVO
      backendPuertoVoz: backendPuertoVoz ?? this.backendPuertoVoz, // ✅ NUEVO
      enableDebugLogs: enableDebugLogs ?? this.enableDebugLogs,
      showNetworkIndicator: showNetworkIndicator ?? this.showNetworkIndicator,
      showSyncStatus: showSyncStatus ?? this.showSyncStatus,
      minPhotoQuality: minPhotoQuality ?? this.minPhotoQuality,
      audioRecordingDuration:
          audioRecordingDuration ?? this.audioRecordingDuration,
      allowMultipleRegistrations:
          allowMultipleRegistrations ?? this.allowMultipleRegistrations,
      enableEarValidation: enableEarValidation ?? this.enableEarValidation,
      requireAllFieldsInRegistration:
          requireAllFieldsInRegistration ?? this.requireAllFieldsInRegistration,
      requireBothBiometricsInLogin:
          requireBothBiometricsInLogin ?? this.requireBothBiometricsInLogin,
      offlineMessageIntervalMinutes:
          offlineMessageIntervalMinutes ?? this.offlineMessageIntervalMinutes,
    );
  }
}
