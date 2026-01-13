import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:typed_data';

import '../models/user.dart';
import '../services/local_database_service.dart';
import '../services/biometric_service.dart';
import '../services/biometric_backend_service.dart'; // ✅ NUEVO
import '../models/biometric_models.dart';
import '../config/api_config.dart';

class AuthServiceFix {
  // Singleton
  AuthServiceFix._privateConstructor();
  static final AuthServiceFix instance = AuthServiceFix._privateConstructor();

  final Dio _dio = ApiConfig().dio;
  final _secureStorage = const FlutterSecureStorage();
  final _biometricBackend = BiometricBackendService(); // ✅ NUEVO

  /// ✅ NUEVO: Actualizar URLs del backend biométrico desde configuración
  Future<void> updateBackendUrls() async {
    await _biometricBackend.updateBackendUrls();
  }

  Future<String> register({
    required String nombres,
    required String apellidos,
    required String email,
    required String identificadorUnico,
    String? contrasena,
  }) async {
    try {
      print('[AuthService] 📤 POST ${_dio.options.baseUrl}/auth/register');

      final response = await _dio.post(
        '/auth/register',
        data: {
          'nombres': nombres,
          'apellidos': apellidos,
          'email': email,
          'identificadorUnico': identificadorUnico,
          'estado': 'activo',
        },
      );

      print('[AuthService] 📥 Respuesta: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final token = response.data['token'] as String?;
        if (token != null) {
          await _secureStorage.write(key: 'access_token', value: token);
          return token;
        }
        throw Exception('No token en respuesta');
      }
      throw Exception(
        'Error en registro: ${response.statusCode} ${response.data}',
      );
    } on DioException catch (e) {
      print('[AuthService] ❌ DioException: ${e.message}');
      print('[AuthService] 🌐 URL usada: ${e.requestOptions.uri}');

      // Manejar error 409 (usuario duplicado) con mensaje mejorado
      if (e.response?.statusCode == 409) {
        final data = e.response?.data;
        final mensaje = data is Map
            ? data['mensaje'] ?? data['error']
            : 'Usuario ya existe';
        throw Exception(mensaje);
      }
      // Manejar otros errores
      if (e.response?.data != null) {
        final data = e.response!.data;
        final errorMsg = data is Map ? data['error'] : data.toString();
        throw Exception('Error al registrar: $errorMsg');
      }
      throw Exception('Error al registrar: ${e.message}');
    } catch (e) {
      print('[AuthService] ❌ Exception: $e');
      throw Exception('Error al registrar: $e');
    }
  }

  Future<String> login({
    required String identificadorUnico,
    required String contrasena,
  }) async {
    try {
      // 1. Intentar login ONLINE primero
      final response = await _dio.post(
        '/auth/login-basico',
        data: {
          'identificador_unico': identificadorUnico,
          'password': contrasena,
        },
      );

      if (response.statusCode == 200) {
        // Online login exitoso
        final tokens = response.data['tokens'];
        final access = tokens != null ? tokens['accessToken'] as String? : null;
        final refresh = tokens != null
            ? tokens['refreshToken'] as String?
            : null;

        if (access != null) {
          await _secureStorage.write(key: 'access_token', value: access);
          if (refresh != null)
            await _secureStorage.write(key: 'refresh_token', value: refresh);
          return access;
        }

        final token = response.data['token'] as String?;
        if (token != null) {
          await _secureStorage.write(key: 'access_token', value: token);
          return token;
        }

        throw Exception('No token en respuesta');
      }

      throw Exception(
        'Error en login: ${response.statusCode} ${response.data}',
      );
    } on DioException catch (e) {
      // Si falla online, intentar offline (si hay error de conexión)
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.unknown) {
        // Modo offline: la autenticación por contraseña fue removida.
        throw Exception(
          'Sin conexión: la autenticación por contraseña no está disponible offline. Use la verificación biométrica.',
        );
      }

      // Manejar otros errores online
      if (e.response?.statusCode == 401) {
        throw Exception(
          '❌ Credenciales inválidas\nVerifica usuario y contraseña',
        );
      }

      if (e.response?.data != null) {
        final data = e.response!.data;
        final errorMsg = data is Map ? data['error'] : data.toString();
        throw Exception('Error al autenticar: $errorMsg');
      }

      throw Exception('Error al autenticar: ${e.message}');
    } catch (e) {
      throw Exception('Error al autenticar: $e');
    }
  }

  // Autenticación offline por contraseña removida.
  // La aplicación usa únicamente biometría para autenticación local/offline.

  Future<User> getCurrentUser() async {
    try {
      final token = await _secureStorage.read(key: 'access_token');
      if (token == null) throw Exception('No token disponible');

      final response = await _dio.get(
        '/auth/verify',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        return User.fromJson(response.data['usuario'] ?? response.data);
      }
      throw Exception('Error al obtener usuario');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  /// Registrar foto de oreja
  Future<int> registerEarPhoto(
    String identificadorUnico,
    List<int> photoBytes,
    int numero,
  ) async {
    try {
      // PRIMERO: Guardar en BD local (IMPORTANTE para login offline)
      final localDb = LocalDatabaseService();
      final user = await localDb.getUserByIdentifier(identificadorUnico);
      if (user != null) {
        final int idUsuario = user['id_usuario'] as int;
        final credential = BiometricCredential(
          id: 0,
          idUsuario: idUsuario,
          tipoBiometria: 'oreja',
          template: photoBytes,
          versionAlgoritmo: '1.0',
        );
        await localDb.insertBiometricCredential(credential);
      }

      final token = await _secureStorage.read(key: 'access_token');
      final base64Photo = base64Encode(photoBytes);

      final response = await _dio.post(
        '/biometria/registrar-oreja',
        data: {
          'identificadorUnico': identificadorUnico,
          'foto': base64Photo,
          'numero': numero,
        },
        options: Options(
          headers: {
            'Authorization': token != null ? 'Bearer $token' : null,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['id_credencial'] as int? ?? 0;
      }

      throw Exception(
        'Error registrando foto: ${response.statusCode} ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Error al registrar foto de oreja: ${e.message}');
    } catch (e) {
      throw Exception('Error al registrar foto de oreja: $e');
    }
  }

  /// Registrar audio de voz
  Future<int> registerVoiceAudio(
    String identificadorUnico,
    List<int> audioBytes,
  ) async {
    try {
      // PRIMERO: Guardar en BD local (IMPORTANTE para login offline)
      final localDb = LocalDatabaseService();
      final user = await localDb.getUserByIdentifier(identificadorUnico);
      if (user != null) {
        final int idUsuario = user['id_usuario'] as int;
        final credential = BiometricCredential(
          id: 0,
          idUsuario: idUsuario,
          tipoBiometria: 'audio',
          template: audioBytes,
          versionAlgoritmo: '1.0',
        );
        await localDb.insertBiometricCredential(credential);
      }

      final token = await _secureStorage.read(key: 'access_token');
      final base64Audio = base64Encode(audioBytes);

      final response = await _dio.post(
        '/biometria/registrar-voz',
        data: {'identificadorUnico': identificadorUnico, 'audio': base64Audio},
        options: Options(
          headers: {
            'Authorization': token != null ? 'Bearer $token' : null,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['id_credencial'] as int? ?? 0;
      }

      throw Exception(
        'Error registrando audio: ${response.statusCode} ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Error al registrar audio de voz: ${e.message}');
    } catch (e) {
      throw Exception('Error al registrar audio de voz: $e');
    }
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: 'access_token');
  }
}
