import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import '../models/admin_settings.dart';

/// Servicio para gestionar configuraciones de administrador
class AdminSettingsService {
  static final AdminSettingsService _instance =
      AdminSettingsService._internal();
  factory AdminSettingsService() => _instance;
  AdminSettingsService._internal();

  final _storage = FlutterSecureStorage();
  AdminSettings? _currentSettings;

  // Contraseña maestra (hasheada) - Cambiar esto en producción
  static const String _masterPasswordHash =
      '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918'; // "admin"

  // Clave secreta adicional (hasheada)
  static const String _secretKeyHash =
      '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8'; // "password"

  /// Verificar contraseña maestra y clave secreta
  bool authenticate(String password, String secretKey) {
    final passwordHash = _hashString(password);
    final keyHash = _hashString(secretKey);

    final isValid =
        passwordHash == _masterPasswordHash && keyHash == _secretKeyHash;

    if (isValid) {
      print('[Admin] ✅ Autenticación exitosa');
    } else {
      print('[Admin] ❌ Autenticación fallida');
    }

    return isValid;
  }

  /// Generar hash SHA-256 de un string
  String _hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Cargar configuraciones guardadas
  Future<AdminSettings> loadSettings() async {
    if (_currentSettings != null) {
      return _currentSettings!;
    }

    try {
      final settingsJson = await _storage.read(key: 'admin_settings');

      if (settingsJson != null) {
        final map = jsonDecode(settingsJson) as Map<String, dynamic>;
        _currentSettings = AdminSettings.fromJson(map);
        print('[Admin] ⚙️ Configuraciones cargadas desde storage');
      } else {
        _currentSettings = AdminSettings(); // Valores por defecto
        print('[Admin] ⚙️ Usando configuraciones por defecto');
      }
    } catch (e) {
      print('[Admin] ⚠️ Error cargando configuraciones: $e');
      _currentSettings = AdminSettings();
    }

    return _currentSettings!;
  }

  /// Guardar configuraciones
  Future<void> saveSettings(AdminSettings settings) async {
    try {
      final json = jsonEncode(settings.toJson());
      await _storage.write(key: 'admin_settings', value: json);
      _currentSettings = settings;
      print('[Admin] 💾 Configuraciones guardadas');
    } catch (e) {
      print('[Admin] ❌ Error guardando configuraciones: $e');
      throw e;
    }
  }

  /// Obtener configuraciones actuales (sin cargar de storage)
  AdminSettings? get currentSettings => _currentSettings;

  /// Restablecer a valores por defecto
  Future<void> resetToDefaults() async {
    final defaults = AdminSettings();
    await saveSettings(defaults);
    print('[Admin] 🔄 Configuraciones restablecidas a valores por defecto');
  }

  /// Cambiar tema (oscuro/claro)
  Future<void> toggleTheme() async {
    final settings = await loadSettings();
    final newSettings = settings.copyWith(isDarkMode: !settings.isDarkMode);
    await saveSettings(newSettings);
    print(
      '[Admin] 🎨 Tema cambiado a: ${newSettings.isDarkMode ? "Oscuro" : "Claro"}',
    );
  }

  /// Actualizar URL de la API
  Future<void> updateApiUrl(String newUrl) async {
    final settings = await loadSettings();
    final newSettings = settings.copyWith(apiBaseUrl: newUrl);
    await saveSettings(newSettings);
    print('[Admin] 🌐 API URL actualizada: $newUrl');
  }

  /// Actualizar intervalo de sincronización
  Future<void> updateSyncInterval(int minutes) async {
    final settings = await loadSettings();
    final newSettings = settings.copyWith(syncIntervalMinutes: minutes);
    await saveSettings(newSettings);
    print('[Admin] ⏱️ Intervalo de sync actualizado: $minutes minutos');
  }

  /// Exportar configuraciones como JSON
  Future<String> exportSettings() async {
    final settings = await loadSettings();
    return jsonEncode(settings.toJson());
  }

  /// Importar configuraciones desde JSON
  Future<void> importSettings(String jsonString) async {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      final settings = AdminSettings.fromJson(map);
      await saveSettings(settings);
      print('[Admin] 📥 Configuraciones importadas exitosamente');
    } catch (e) {
      print('[Admin] ❌ Error importando configuraciones: $e');
      throw e;
    }
  }

  /// Generar hash de contraseña personalizada
  String generatePasswordHash(String password) {
    return _hashString(password);
  }

  /// Limpiar cache de configuraciones
  void clearCache() {
    _currentSettings = null;
    print('[Admin] 🗑️ Cache de configuraciones limpiado');
  }
}
