import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:typed_data';

import '../models/user.dart';
import '../services/local_database_service.dart';
import '../services/biometric_service.dart';
import '../models/biometric_models.dart';
import '../config/api_config.dart';

class AuthService {
  // Base URL configurable. Por defecto apuntamos a la IP del host en la LAN
  static String baseUrl =
      'http://10.52.41.36:3000/api'; // Ajusta IP/puerto según tu backend

  /// Permite cambiar la base URL en tiempo de ejecución (útil para pruebas en dispositivo físico)
  static void setBaseUrl(String url) => baseUrl = url;
  final Dio _dio = ApiConfig().dio;
  final _secureStorage = const FlutterSecureStorage();

  /// Registrar nuevo usuario con biometría
  /// [nombres], [apellidos], [email], [identificadorUnico]
  /// Retorna token JWT si es exitoso
  Future<String> register({
    required String nombres,
    required String apellidos,
    required String email,
    required String identificadorUnico,
    required String contrasena,
  }) async {
    try {
      final response = await _dio.post(
        AuthService.baseUrl + '/auth/register',
        data: {
          'nombres': nombres,
          'apellidos': apellidos,
          'email': email,
          'identificadorUnico': identificadorUnico,
          'contrasena': contrasena,
          'estado': 'activo',
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final token = response.data['token'] as String?;
        if (token != null) {
          await _secureStorage.write(key: 'auth_token', value: token);
          return token;
        }
        throw Exception('No token en respuesta');
      }
      throw Exception('Error en registro: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error al registrar: $e');
    }
  }

  /// Login con identificador único y contraseña
  Future<String> login({
    required String identificadorUnico,
    required String contrasena,
  }) async {
    try {
      final response = await _dio.post(
        AuthService.baseUrl + '/auth/login',
        data: {
          'identificadorUnico': identificadorUnico,
          'contrasena': contrasena,
        },
      );

      if (response.statusCode == 200) {
        final token = response.data['token'] as String?;
        if (token != null) {
          await _secureStorage.write(key: 'auth_token', value: token);
          return token;
        }
        throw Exception('No token en respuesta');
      }
      throw Exception('Error en login: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error al autenticar: $e');
    }
  }

  /// Obtener usuario actual desde token
  Future<User> getCurrentUser() async {
    try {
      final token = await _secureStorage.read(key: 'auth_token');
      if (token == null) throw Exception('No token disponible');

      final response = await _dio.get(
        AuthService.baseUrl + '/auth/me',
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

  /// Registrar credencial biométrica (foto de oreja)
  Future<void> registerEarPhoto(
    String identificadorUnico,
    List<int> photoBytes,
    int photoNumber, // 1, 2, o 3
  ) async {
    try {
      final token = await _secureStorage.read(key: 'auth_token');
      final base64Photo = base64Encode(photoBytes);

      final response = await _dio.post(
        AuthService.baseUrl + '/biometria/registrar-oreja',
        data: {
          'identificadorUnico': identificadorUnico,
          'foto': base64Photo,
          'numero': photoNumber,
        },
        options: Options(
          headers: {
            'Authorization': token != null ? 'Bearer $token' : null,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Error registrando foto: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al registrar foto de oreja: $e');
    }
  }

  /// Registrar credencial biométrica (audio de voz)
  Future<void> registerVoiceAudio(
    String identificadorUnico,
    List<int> audioBytes,
  ) async {
    try {
      final token = await _secureStorage.read(key: 'auth_token');
      final base64Audio = base64Encode(audioBytes);

      final response = await _dio.post(
        AuthService.baseUrl + '/biometria/registrar-voz',
        data: {'identificadorUnico': identificadorUnico, 'audio': base64Audio},
        options: Options(
          headers: {
            'Authorization': token != null ? 'Bearer $token' : null,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Error registrando audio: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al registrar audio de voz: $e');
    }
  }

  /// Autenticar con foto de oreja
  Future<bool> authenticateWithEarPhoto(
    String identificadorUnico,
    List<int> photoBytes,
  ) async {
    final localDb = LocalDatabaseService();
    final bio = BiometricService();

    // Intentar verificación remota primero
    try {
      final base64Photo = base64Encode(photoBytes);

      final response = await _dio.post(
        AuthService.baseUrl + '/biometria/verificar-oreja',
        data: {'identificadorUnico': identificadorUnico, 'foto': base64Photo},
      );

      if (response.statusCode == 200) {
        final confianza = (response.data['confianza'] ?? 0) as num;

        // Registrar validación localmente (audit)
        final user = await localDb.getUserByIdentifier(identificadorUnico);
        final int? idUsuario = user != null ? user['id_usuario'] as int : null;
        if (idUsuario != null) {
          final validation = BiometricValidation(
            id: 0,
            idUsuario: idUsuario,
            tipoBiometria: 'oreja',
            resultado:
                (response.data['coincidencia'] == true || confianza > 0.8)
                ? 'exito'
                : 'fallo',
            modoValidacion: 'online',
            timestamp: DateTime.now(),
            puntuacionConfianza: confianza.toDouble(),
            duracionValidacion: 0,
          );
          await localDb.insertValidation(validation);
          await localDb
              .insertToSyncQueue(idUsuario, 'validacion_biometrica', 'insert', {
                'tipo_biometria': 'oreja',
                'resultado': validation.resultado,
                'puntuacion_confianza': validation.puntuacionConfianza,
                'timestamp': validation.timestamp.toIso8601String(),
              });
        }

        return response.data['coincidencia'] == true || confianza > 0.8;
      }
    } catch (e) {
      // Ignorar y caer al fallback local
    }

    // Fallback local (offline): buscar plantillas locales y comparar
    try {
      final user = await localDb.getUserByIdentifier(identificadorUnico);
      if (user == null) return false;
      final int idUsuario = user['id_usuario'] as int;

      final templates = await localDb.getCredentialsByUserAndType(
        idUsuario,
        'oreja',
      );
      if (templates.isEmpty) return false;

      double bestConfidence = 0.0;
      EarValidationResult? bestResult;
      final imageData = Uint8List.fromList(photoBytes);

      for (final tpl in templates) {
        final result = await bio.validateEar(
          imageData: imageData,
          templateData: Uint8List.fromList(tpl.template),
        );
        if (result.confidence > bestConfidence) {
          bestConfidence = result.confidence;
          bestResult = result;
        }
      }

      final success = bestResult?.isValid ?? false;

      final validation = BiometricValidation(
        id: 0,
        idUsuario: idUsuario,
        tipoBiometria: 'oreja',
        resultado: success ? 'exito' : 'fallo',
        modoValidacion: 'offline',
        timestamp: DateTime.now(),
        puntuacionConfianza: bestConfidence,
        duracionValidacion: (bestResult?.processingTime != null)
            ? bestResult!.processingTime!.inMilliseconds
            : 0,
      );

      await localDb.insertValidation(validation);
      await localDb
          .insertToSyncQueue(idUsuario, 'validacion_biometrica', 'insert', {
            'tipo_biometria': 'oreja',
            'resultado': validation.resultado,
            'puntuacion_confianza': validation.puntuacionConfianza,
            'timestamp': validation.timestamp.toIso8601String(),
          });

      return success;
    } catch (err) {
      throw Exception('Error autenticando (fallback local): $err');
    }
  }

  /// Autenticar con audio de voz
  Future<bool> authenticateWithVoice(
    String identificadorUnico,
    List<int> audioBytes,
  ) async {
    final localDb = LocalDatabaseService();
    final bio = BiometricService();

    // Intentar verificación remota
    try {
      final base64Audio = base64Encode(audioBytes);

      final response = await _dio.post(
        AuthService.baseUrl + '/biometria/verificar-voz',
        data: {'identificadorUnico': identificadorUnico, 'audio': base64Audio},
      );

      if (response.statusCode == 200) {
        final confianza = (response.data['confianza'] ?? 0) as num;

        final user = await localDb.getUserByIdentifier(identificadorUnico);
        final int? idUsuario = user != null ? user['id_usuario'] as int : null;
        if (idUsuario != null) {
          final validation = BiometricValidation(
            id: 0,
            idUsuario: idUsuario,
            tipoBiometria: 'audio',
            resultado:
                (response.data['coincidencia'] == true || confianza > 0.8)
                ? 'exito'
                : 'fallo',
            modoValidacion: 'online',
            timestamp: DateTime.now(),
            puntuacionConfianza: confianza.toDouble(),
            duracionValidacion: 0,
          );
          await localDb.insertValidation(validation);
          await localDb
              .insertToSyncQueue(idUsuario, 'validacion_biometrica', 'insert', {
                'tipo_biometria': 'audio',
                'resultado': validation.resultado,
                'puntuacion_confianza': validation.puntuacionConfianza,
                'timestamp': validation.timestamp.toIso8601String(),
              });
        }

        return response.data['coincidencia'] == true || confianza > 0.8;
      }
    } catch (e) {
      // Caer al fallback local
    }

    // Fallback local (offline)
    try {
      final user = await localDb.getUserByIdentifier(identificadorUnico);
      if (user == null) return false;
      final int idUsuario = user['id_usuario'] as int;

      final templates = await localDb.getCredentialsByUserAndType(
        idUsuario,
        'audio',
      );
      if (templates.isEmpty) return false;

      double bestConfidence = 0.0;
      VoiceValidationResult? bestResult;
      final audioData = Uint8List.fromList(audioBytes);

      for (final tpl in templates) {
        final result = await bio.validateVoice(
          audioData: audioData,
          targetPhrase: '',
          templateData: Uint8List.fromList(tpl.template),
        );
        if (result.confidence > bestConfidence) {
          bestConfidence = result.confidence;
          bestResult = result;
        }
      }

      final success = bestResult?.isValid ?? false;

      final validation = BiometricValidation(
        id: 0,
        idUsuario: idUsuario,
        tipoBiometria: 'audio',
        resultado: success ? 'exito' : 'fallo',
        modoValidacion: 'offline',
        timestamp: DateTime.now(),
        puntuacionConfianza: bestConfidence,
        duracionValidacion: bestResult?.processingTime?.inMilliseconds ?? 0,
      );

      await localDb.insertValidation(validation);
      await localDb
          .insertToSyncQueue(idUsuario, 'validacion_biometrica', 'insert', {
            'tipo_biometria': 'audio',
            'resultado': validation.resultado,
            'puntuacion_confianza': validation.puntuacionConfianza,
            'timestamp': validation.timestamp.toIso8601String(),
          });

      return success;
    } catch (err) {
      throw Exception('Error autenticando voz (fallback local): $err');
    }
  }

  /// Logout
  Future<void> logout() async {
    await _secureStorage.delete(key: 'auth_token');
  }

  /// Obtener token almacenado
  Future<String?> getToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }
}
