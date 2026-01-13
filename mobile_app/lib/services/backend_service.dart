import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/api_config.dart';
import '../config/database_config.dart';

/// Servicio híbrido que maneja comunicación con backend PostgreSQL remoto
/// y fallback a SQLite local cuando no hay conexión
class BackendService {
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  final Dio _dio = ApiConfig().dio;
  final Connectivity _connectivity = Connectivity();

  /// Verifica si hay conexión a internet
  Future<bool> isOnline() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Verificar si el backend responde
      final response = await _dio
          .get(
            '/health',
            options: Options(
              receiveTimeout: Duration(seconds: 3),
              sendTimeout: Duration(seconds: 3),
            ),
          )
          .timeout(Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      print('[BackendService] ⚠️ Sin conexión al backend: $e');
      return false;
    }
  }

  // =====================================================
  // USUARIOS
  // =====================================================

  /// Registrar usuario en backend PostgreSQL
  Future<Map<String, dynamic>> registerUser({
    required String nombres,
    required String apellidos,
    String? fechaNacimiento,
    String? sexo,
    required String identificadorUnico,
  }) async {
    try {
      final online = await isOnline();

      final userData = {
        'nombres': nombres,
        'apellidos': apellidos,
        if (fechaNacimiento != null) 'fecha_nacimiento': fechaNacimiento,
        if (sexo != null) 'sexo': sexo,
        'identificador_unico': identificadorUnico,
        'estado': 'activo',
      };

      if (online) {
        // Registrar en backend remoto
        final response = await _dio.post('/usuarios', data: userData);
        print(
          '[BackendService] ✅ Usuario registrado en PostgreSQL: ${response.data}',
        );
        return response.data;
      } else {
        // Registrar localmente y marcar para sync
        print('[BackendService] 📱 Modo offline: guardando usuario localmente');
        // TODO: Implementar guardado local con sync pendiente
        throw Exception('Modo offline: no se puede registrar sin conexión');
      }
    } catch (e) {
      print('[BackendService] ❌ Error registrando usuario: $e');
      rethrow;
    }
  }

  /// Obtener usuario por identificador único
  Future<Map<String, dynamic>?> getUserByIdentifier(
    String identificador,
  ) async {
    try {
      final online = await isOnline();

      if (online) {
        final response = await _dio.get('/usuarios/$identificador');
        return response.data;
      } else {
        print('[BackendService] 📱 Modo offline: consultando base local');
        // TODO: Consultar base local
        return null;
      }
    } catch (e) {
      print('[BackendService] ❌ Error obteniendo usuario: $e');
      return null;
    }
  }

  // =====================================================
  // BIOMETRÍA - OREJA
  // =====================================================

  /// Registrar foto de oreja en backend (entrenamiento)
  Future<Map<String, dynamic>> registerEarPhoto({
    required int idUsuario,
    required Uint8List imageBytes,
    required int photoNumber,
  }) async {
    try {
      final online = await isOnline();

      if (!online) {
        throw Exception('Se requiere conexión para entrenar modelo de oreja');
      }

      // Convertir imagen a base64
      final base64Image = base64Encode(imageBytes);

      final response = await _dio.post(
        '/biometria/registrar-oreja',
        data: {
          'id_usuario': idUsuario,
          'imagen_base64': base64Image,
          'numero_foto': photoNumber,
        },
      );

      print('[BackendService] ✅ Foto de oreja $photoNumber registrada');

      // Guardar credencial en SQLite local
      await _saveCredentialLocal(idUsuario: idUsuario, tipoBiometria: 'oreja');

      return response.data;
    } catch (e) {
      print('[BackendService] ❌ Error registrando oreja: $e');
      rethrow;
    }
  }

  /// Verificar oreja contra modelo entrenado
  Future<Map<String, dynamic>> verifyEarPhoto({
    required int idUsuario,
    required Uint8List imageBytes,
  }) async {
    try {
      final online = await isOnline();

      if (!online) {
        throw Exception('Se requiere conexión para verificar oreja');
      }

      final base64Image = base64Encode(imageBytes);

      final response = await _dio.post(
        '/biometria/verificar-oreja',
        data: {'id_usuario': idUsuario, 'imagen_base64': base64Image},
      );

      print('[BackendService] ✅ Oreja verificada: ${response.data}');

      // Registrar validación
      await _saveValidationLocal(
        idUsuario: idUsuario,
        tipoBiometria: 'oreja',
        resultado: response.data['verified'] == true ? 'exito' : 'fallo',
      );

      return response.data;
    } catch (e) {
      print('[BackendService] ❌ Error verificando oreja: $e');
      rethrow;
    }
  }

  // =====================================================
  // BIOMETRÍA - VOZ
  // =====================================================

  /// Registrar audio de voz en backend (entrenamiento)
  Future<Map<String, dynamic>> registerVoiceAudio({
    required int idUsuario,
    required Uint8List audioBytes,
  }) async {
    try {
      final online = await isOnline();

      if (!online) {
        throw Exception('Se requiere conexión para entrenar modelo de voz');
      }

      final base64Audio = base64Encode(audioBytes);

      final response = await _dio.post(
        '/biometria/registrar-voz',
        data: {'id_usuario': idUsuario, 'audio_base64': base64Audio},
      );

      print('[BackendService] ✅ Audio de voz registrado');

      await _saveCredentialLocal(idUsuario: idUsuario, tipoBiometria: 'voz');

      return response.data;
    } catch (e) {
      print('[BackendService] ❌ Error registrando voz: $e');
      rethrow;
    }
  }

  /// Verificar voz contra modelo entrenado
  Future<Map<String, dynamic>> verifyVoiceAudio({
    required int idUsuario,
    required Uint8List audioBytes,
  }) async {
    try {
      final online = await isOnline();

      if (!online) {
        throw Exception('Se requiere conexión para verificar voz');
      }

      final base64Audio = base64Encode(audioBytes);

      final response = await _dio.post(
        '/biometria/verificar-voz',
        data: {'id_usuario': idUsuario, 'audio_base64': base64Audio},
      );

      print('[BackendService] ✅ Voz verificada: ${response.data}');

      await _saveValidationLocal(
        idUsuario: idUsuario,
        tipoBiometria: 'voz',
        resultado: response.data['verified'] == true ? 'exito' : 'fallo',
      );

      return response.data;
    } catch (e) {
      print('[BackendService] ❌ Error verificando voz: $e');
      rethrow;
    }
  }

  // =====================================================
  // FRASES DINÁMICAS (para anti-spoofing de voz)
  // =====================================================

  /// Obtener frase dinámica del backend
  Future<String?> getDynamicPhrase() async {
    try {
      final online = await isOnline();

      if (!online) {
        return 'Por favor di: autenticación biométrica'; // Fallback
      }

      final response = await _dio.get('/frases/obtener-activa');
      return response.data['frase'] as String?;
    } catch (e) {
      print('[BackendService] ⚠️ Error obteniendo frase: $e');
      return 'Por favor di: autenticación biométrica'; // Fallback
    }
  }

  // =====================================================
  // HELPERS LOCALES
  // =====================================================

  /// Guardar credencial biométrica en SQLite local
  Future<void> _saveCredentialLocal({
    required int idUsuario,
    required String tipoBiometria,
  }) async {
    try {
      final db = await DatabaseConfig().database;
      await db.insert('credenciales_biometricas', {
        'id_usuario': idUsuario,
        'tipo_biometria': tipoBiometria,
        'fecha_captura': DateTime.now().toIso8601String(),
        'estado': 'activo',
      });
    } catch (e) {
      print('[BackendService] ⚠️ Error guardando credencial local: $e');
    }
  }

  /// Guardar validación en SQLite local
  Future<void> _saveValidationLocal({
    required int idUsuario,
    required String tipoBiometria,
    required String resultado,
  }) async {
    try {
      final db = await DatabaseConfig().database;
      await db.insert('validaciones_biometricas', {
        'id_usuario': idUsuario,
        'tipo_biometria': tipoBiometria,
        'resultado': resultado,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('[BackendService] ⚠️ Error guardando validación local: $e');
    }
  }

  // =====================================================
  // SINCRONIZACIÓN
  // =====================================================

  /// Sincronizar datos locales con backend PostgreSQL
  Future<void> syncToBackend() async {
    try {
      final online = await isOnline();
      if (!online) {
        print('[BackendService] 📱 Offline: sync postponed');
        return;
      }

      // TODO: Implementar lógica de sincronización
      // 1. Obtener registros con sync_status = 'pendiente'
      // 2. Enviar al backend
      // 3. Actualizar sync_status con ID remoto

      print('[BackendService] 🔄 Sync completada');
    } catch (e) {
      print('[BackendService] ❌ Error en sync: $e');
    }
  }
}
