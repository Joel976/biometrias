import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/admin_settings_service.dart';

class ApiConfig {
  // Valores por defecto
  static String baseUrl = 'http://10.52.41.36:3000/api';
  static Duration connectTimeout = Duration(seconds: 10);
  static Duration receiveTimeout = Duration(seconds: 30);

  static const String authEndpoint = '/auth';
  static const String syncEndpoint = '/sync';

  static final ApiConfig _instance = ApiConfig._internal();
  late Dio _dio;
  final _secureStorage = const FlutterSecureStorage();
  final _adminService = AdminSettingsService();

  factory ApiConfig() {
    return _instance;
  }

  ApiConfig._internal() {
    // Inicializar con valores por defecto
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        contentType: 'application/json',
      ),
    );

    // Cargar configuraciones de admin y actualizar
    _loadAdminSettings();
    _setupInterceptors();
  }

  /// Cargar configuraciones de admin y actualizar Dio
  Future<void> _loadAdminSettings() async {
    try {
      print('[ApiConfig] 🔄 Cargando configuraciones de admin...');
      final settings = await _adminService.loadSettings();

      print('[ApiConfig] 📥 Configuración leída desde storage:');
      print('[ApiConfig]    URL: ${settings.apiBaseUrl}');
      print('[ApiConfig]    Timeout: ${settings.requestTimeoutSeconds}s');

      // Actualizar valores estáticos
      baseUrl = settings.apiBaseUrl;
      connectTimeout = Duration(seconds: settings.requestTimeoutSeconds);
      receiveTimeout = Duration(seconds: settings.requestTimeoutSeconds);

      // Actualizar BaseOptions de Dio
      _dio.options.baseUrl = settings.apiBaseUrl;
      _dio.options.connectTimeout = Duration(
        seconds: settings.requestTimeoutSeconds,
      );
      _dio.options.receiveTimeout = Duration(
        seconds: settings.requestTimeoutSeconds,
      );

      print('[ApiConfig] ✅ Configuración de Dio actualizada:');
      print('[ApiConfig]    _dio.options.baseUrl = ${_dio.options.baseUrl}');
      print('[ApiConfig]    baseUrl estático = $baseUrl');
    } catch (e) {
      print('[ApiConfig] ⚠️ Error cargando configuraciones: $e');
    }
  }

  /// Recargar configuraciones manualmente
  Future<void> reloadSettings() async {
    print('[ApiConfig] 🔁 reloadSettings() llamado manualmente');
    await _loadAdminSettings();
    print('[ApiConfig] ✅ reloadSettings() completado');
  }

  void _setupInterceptors() {
    // Interceptor para agregar token de autenticación
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshToken = await _secureStorage.read(
              key: 'refresh_token',
            );

            if (refreshToken != null) {
              try {
                final response = await _dio.post(
                  '$authEndpoint/refresh-token',
                  data: {'refreshToken': refreshToken},
                );

                final newAccessToken = response.data['accessToken'];
                await _secureStorage.write(
                  key: 'access_token',
                  value: newAccessToken,
                );

                // Reintentar la petición original
                final req = error.requestOptions;

                return handler.resolve(
                  await _dio.request(
                    req.path,
                    data: req.data,
                    queryParameters: req.queryParameters,
                    options: Options(
                      method: req.method,
                      headers: {
                        ...req.headers,
                        'Authorization': 'Bearer $newAccessToken',
                      },
                      responseType: req.responseType,
                      contentType: req.contentType,
                    ),
                  ),
                );
              } catch (_) {
                await _secureStorage.deleteAll();
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  // Métodos auxiliares
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _secureStorage.write(key: 'access_token', value: accessToken);
    await _secureStorage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'access_token');
  }

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
  }
}
