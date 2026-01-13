import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/environment_config.dart';
import '../services/admin_settings_service.dart'; // ✅ NUEVO

/// Servicio para comunicación con los backends de oreja y voz en la nube
/// IP: 167.71.155.9 (configurable desde Admin Panel)
/// Puerto Oreja: 8080 (configurable desde Admin Panel)
/// Puerto Voz: 8081 (configurable desde Admin Panel)
class BiometricBackendService {
  static final BiometricBackendService _instance =
      BiometricBackendService._internal();
  factory BiometricBackendService() => _instance;
  BiometricBackendService._internal();

  final _adminService = AdminSettingsService(); // ✅ NUEVO

  final Dio _dioOreja = Dio(
    BaseOptions(
      baseUrl: EnvironmentConfig.orejaBackendUrl,
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 10),
    ),
  );

  final Dio _dioVoz = Dio(
    BaseOptions(
      baseUrl: EnvironmentConfig.vozBackendUrl,
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 10),
    ),
  );

  // Cliente Dio para el backend principal (API REST en puerto 3001)
  final Dio _dioApi = Dio(
    BaseOptions(
      baseUrl: 'http://167.71.155.9:3001/api',
      connectTimeout: Duration(seconds: 30),
      receiveTimeout: Duration(seconds: 30),
    ),
  );

  final Connectivity _connectivity = Connectivity();

  /// ✅ NUEVO: Actualiza las URLs base desde las configuraciones de admin
  Future<void> updateBackendUrls() async {
    try {
      final settings = await _adminService.loadSettings();
      final orejaUrl =
          'http://${settings.backendIp}:${settings.backendPuertoOreja}';
      final vozUrl =
          'http://${settings.backendIp}:${settings.backendPuertoVoz}';

      _dioOreja.options.baseUrl = orejaUrl;
      _dioVoz.options.baseUrl = vozUrl;

      print('[BiometricBackend] ✅ URLs actualizadas:');
      print('[BiometricBackend]    Oreja: $orejaUrl');
      print('[BiometricBackend]    Voz: $vozUrl');
    } catch (e) {
      print('[BiometricBackend] ⚠️ Error actualizando URLs: $e');
      // Mantener URLs por defecto si hay error
    }
  }

  /// Verifica si hay conexión a internet
  Future<bool> isOnline() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }
      return true;
    } catch (e) {
      print('[BiometricBackend] ⚠️ Error verificando conectividad: $e');
      return false;
    }
  }

  // =====================================================
  // OREJA - Endpoints
  // =====================================================

  /// 1) Registrar usuario (datos en JSON)
  /// POST /registrar_usuario
  /// Body: JSON con identificador_unico, nombres, apellidos, fecha_nacimiento, sexo
  Future<Map<String, dynamic>> registrarUsuario({
    required String identificadorUnico,
    required String nombres,
    required String apellidos,
    String? fechaNacimiento,
    String? sexo,
  }) async {
    try {
      print('[BiometricBackend] 📝 Registrando usuario: $identificadorUnico');

      final requestData = {
        'identificador_unico': identificadorUnico,
        'nombres': nombres,
        'apellidos': apellidos,
        'fecha_nacimiento': fechaNacimiento ?? '',
        'sexo': sexo ?? '',
      };

      print(
        '[BiometricBackend] 📤 POST ${_dioOreja.options.baseUrl}/registrar_usuario',
      );
      print('[BiometricBackend] 📦 Body: $requestData');

      final response = await _dioOreja.post(
        '/registrar_usuario',
        data: requestData,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      print('[BiometricBackend] ✅ Status: ${response.statusCode}');
      print('[BiometricBackend] ✅ Usuario registrado: ${response.data}');
      return response.data;
    } on DioException catch (e) {
      print('[BiometricBackend] ❌ Error registrando usuario');
      print('[BiometricBackend] 🔴 Status Code: ${e.response?.statusCode}');
      print('[BiometricBackend] 🔴 Response Data: ${e.response?.data}');
      print('[BiometricBackend] 🔴 Request: ${e.requestOptions.data}');
      print('[BiometricBackend] 🔴 URL: ${e.requestOptions.uri}');
      rethrow;
    } catch (e) {
      print('[BiometricBackend] ❌ Error registrando usuario: $e');
      rethrow;
    }
  }

  /// 2) Registrar biometría de oreja (enrolamiento)
  /// POST /oreja/registrar
  /// Requiere: identificador (query param) + 7+ imágenes como multipart/form-data
  Future<Map<String, dynamic>> registrarBiometriaOreja({
    required String identificador,
    required List<Uint8List> imagenes,
  }) async {
    try {
      if (imagenes.length < 7) {
        throw Exception('Se requieren al menos 7 imágenes para registro');
      }

      print(
        '[BiometricBackend] 📸 Registrando ${imagenes.length} imágenes de oreja para: $identificador',
      );

      final formData = FormData();

      // Agregar cada imagen como archivo
      for (int i = 0; i < imagenes.length; i++) {
        formData.files.add(
          MapEntry(
            'img$i',
            MultipartFile.fromBytes(
              imagenes[i],
              filename: 'img_$i.jpg',
              contentType: MediaType('image', 'jpeg'),
            ),
          ),
        );
      }

      final response = await _dioOreja.post(
        '/oreja/registrar',
        queryParameters: {'identificador': identificador},
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      print(
        '[BiometricBackend] ✅ Biometría de oreja registrada: ${response.data}',
      );
      return {'success': true, 'message': response.data};
    } catch (e) {
      print('[BiometricBackend] ❌ Error registrando biometría oreja: $e');
      rethrow;
    }
  }

  /// 5) Autenticación / Verificación biométrica (oreja)
  /// POST /oreja/autenticar?etiqueta=XXX
  /// Requiere: archivo (imagen) + etiqueta (query param)
  Future<Map<String, dynamic>> autenticarOreja({
    required Uint8List imagenBytes,
    required String identificador,
  }) async {
    try {
      print('[BiometricBackend] 🔐 Autenticando oreja para: $identificador');
      print(
        '[BiometricBackend] 📤 POST ${_dioOreja.options.baseUrl}/oreja/autenticar?etiqueta=$identificador',
      );

      final formData = FormData.fromMap({
        'archivo': MultipartFile.fromBytes(
          imagenBytes,
          filename: 'imagen.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      });

      final response = await _dioOreja.post(
        '/oreja/autenticar',
        queryParameters: {
          'etiqueta': identificador,
        }, // ✅ Query param, no FormData
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          validateStatus: (status) =>
              status! < 500, // Acepta 200, 401, 403, 404
        ),
      );

      if (response.statusCode == 200) {
        print('[BiometricBackend] ✅ Autenticación exitosa: ${response.data}');
        return {
          'success': true,
          'autenticado': response.data['autenticado'] ?? true,
          'id_usuario': response.data['id_usuario'],
          'margen': response.data['margen'],
          'umbral': response.data['umbral'],
          'mensaje': response.data['mensaje'],
        };
      } else if (response.statusCode == 401) {
        print('[BiometricBackend] ⚠️ Autenticación fallida (401)');
        return {
          'success': false,
          'autenticado': false,
          'mensaje': 'No autenticado: margen insuficiente o no coincide',
        };
      } else if (response.statusCode == 403) {
        print('[BiometricBackend] ⚠️ Usuario no activo o sin credencial (403)');
        return {
          'success': false,
          'autenticado': false,
          'mensaje': response.data ?? 'Usuario no activo o sin credencial',
        };
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      print('[BiometricBackend] ❌ Error autenticando oreja: $e');
      rethrow;
    }
  }

  /// 3) Eliminar usuario (soft delete)
  /// POST /auth/usuario/eliminar?identificador=XXX
  Future<Map<String, dynamic>> eliminarUsuario({
    required String identificador,
  }) async {
    try {
      print('[BiometricBackend] 🗑️ Eliminando usuario: $identificador');

      final response = await _dioApi.post(
        '/auth/usuario/eliminar',
        queryParameters: {'identificador': identificador},
      );

      print('[BiometricBackend] ✅ Usuario eliminado: ${response.data}');
      return {'success': true, 'data': response.data};
    } catch (e) {
      print('[BiometricBackend] ❌ Error eliminando usuario: $e');
      rethrow;
    }
  }

  /// 4) Restaurar usuario
  /// POST /auth/usuario/restaurar?identificador=XXX
  Future<Map<String, dynamic>> restaurarUsuario({
    required String identificador,
  }) async {
    try {
      print('[BiometricBackend] ♻️ Restaurando usuario: $identificador');

      final response = await _dioApi.post(
        '/auth/usuario/restaurar',
        queryParameters: {'identificador': identificador},
      );

      print('[BiometricBackend] ✅ Usuario restaurado: ${response.data}');
      return {'success': true, 'data': response.data};
    } catch (e) {
      print('[BiometricBackend] ❌ Error restaurando usuario: $e');
      rethrow;
    }
  }

  // =====================================================
  // VOZ - Endpoints
  // =====================================================

  /// Registrar biometría de voz (6 audios)
  /// POST /voz/registrar_biometria
  /// Requiere: identificador + 6 archivos de audio (.flac o .wav)
  Future<Map<String, dynamic>> registrarBiometriaVoz({
    required String identificador,
    required List<Uint8List> audios,
  }) async {
    try {
      // Validar cantidad exacta de audios (mínimo 5, máximo 6)
      if (audios.length < 5) {
        throw Exception('Se requieren al menos 5 audios para registro');
      }
      if (audios.length > 6) {
        throw Exception(
          'No se pueden registrar más de 6 audios. Recibidos: ${audios.length}',
        );
      }

      print(
        '[BiometricBackend] 🎤 Registrando ${audios.length} audios de voz para: $identificador',
      );
      print(
        '[BiometricBackend] 📤 POST ${_dioVoz.options.baseUrl}/voz/registrar_biometria',
      );

      final formData = FormData();

      // Agregar identificador PRIMERO como campo de texto
      formData.fields.add(MapEntry('identificador', identificador));
      print('[BiometricBackend] 📝 Campo identificador: $identificador');

      // Agregar cada audio como archivo con el MISMO nombre 'audios'
      for (int i = 0; i < audios.length; i++) {
        formData.files.add(
          MapEntry(
            'audios', // ✅ Campo correcto (plural)
            MultipartFile.fromBytes(
              audios[i],
              filename: 'audio${i + 1}.wav', // ✅ WAV
              contentType: MediaType('audio', 'wav'), // ✅ Content-Type correcto
            ),
          ),
        );
        print(
          '[BiometricBackend] 🎵 Audio ${i + 1}: audio${i + 1}.wav (${audios[i].length} bytes)',
        );
      }

      final response = await _dioVoz.post(
        '/voz/registrar_biometria',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      print('[BiometricBackend] ✅ Status: ${response.statusCode}');
      print(
        '[BiometricBackend] ✅ Biometría de voz registrada: ${response.data}',
      );
      return {'success': true, 'message': response.data};
    } on DioException catch (e) {
      print('[BiometricBackend] ❌ Error registrando biometría voz');
      print('[BiometricBackend] 🔴 Status Code: ${e.response?.statusCode}');
      print('[BiometricBackend] 🔴 Response Data: ${e.response?.data}');
      print(
        '[BiometricBackend] 🔴 Request Headers: ${e.requestOptions.headers}',
      );
      print('[BiometricBackend] 🔴 URL: ${e.requestOptions.uri}');
      rethrow;
    } catch (e) {
      print('[BiometricBackend] ❌ Error registrando biometría voz: $e');
      rethrow;
    }
  }

  /// Autenticar usuario con voz
  /// POST /voz/autenticar
  /// Requiere: audio (archivo) + identificador (text) + id_frase (text)
  Future<Map<String, dynamic>> autenticarVoz({
    required Uint8List audioBytes,
    required String identificador,
    required int idFrase,
  }) async {
    try {
      print(
        '[BiometricBackend] 🔐 Autenticando voz para: $identificador (frase: $idFrase)',
      );
      print(
        '[BiometricBackend] 📤 POST ${_dioVoz.options.baseUrl}/voz/autenticar',
      );

      final formData = FormData.fromMap({
        'audio': MultipartFile.fromBytes(
          audioBytes,
          filename: 'audio_auth.wav',
          contentType: MediaType('audio', 'wav'),
        ),
        'identificador': identificador,
        'id_frase': idFrase.toString(),
      });

      print('[BiometricBackend] 📝 Campos enviados:');
      print(
        '[BiometricBackend]    - audio: audio_auth.wav (${audioBytes.length} bytes, WAV binary)',
      );
      print('[BiometricBackend]    - Content-Type: audio/wav');
      print('[BiometricBackend]    - identificador: $identificador');
      print('[BiometricBackend]    - id_frase: $idFrase');

      final response = await _dioVoz.post(
        '/voz/autenticar',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        print(
          '[BiometricBackend] ✅ Autenticación voz exitosa: ${response.data}',
        );
        return {'success': true, 'autenticado': true, 'data': response.data};
      } else {
        print('[BiometricBackend] ⚠️ Autenticación voz fallida');
        return {
          'success': false,
          'autenticado': false,
          'mensaje': response.data ?? 'Autenticación fallida',
        };
      }
    } catch (e) {
      print('[BiometricBackend] ❌ Error autenticando voz: $e');
      rethrow;
    }
  }

  // =====================================================
  // FRASES DINÁMICAS
  // =====================================================

  /// Listar todas las frases disponibles
  /// GET /listar/frases
  Future<List<Map<String, dynamic>>> listarFrases() async {
    try {
      final response = await _dioVoz.get('/listar/frases');
      // El backend devuelve {"frases": [...], "success": true, "total": N}
      final data = response.data;
      if (data is Map && data.containsKey('frases')) {
        print('[BiometricBackend] ✅ Frases listadas: ${data['total'] ?? 0}');
        return List<Map<String, dynamic>>.from(data['frases']);
      }
      print('[BiometricBackend] ✅ Frases listadas: ${response.data.length}');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      print('[BiometricBackend] ❌ Error listando frases: $e');
      rethrow;
    }
  }

  /// Obtener frase específica
  /// GET /listar/frases?id=N
  Future<Map<String, dynamic>> obtenerFrase({required int id}) async {
    try {
      final response = await _dioVoz.get(
        '/listar/frases',
        queryParameters: {'id': id},
      );
      print('[BiometricBackend] ✅ Frase obtenida: ${response.data}');
      return response.data;
    } catch (e) {
      print('[BiometricBackend] ❌ Error obteniendo frase: $e');
      rethrow;
    }
  }

  /// Obtener frase aleatoria activa
  /// GET /frases/aleatoria
  Future<Map<String, dynamic>> obtenerFraseAleatoria() async {
    try {
      final response = await _dioVoz.get('/frases/aleatoria');
      print('[BiometricBackend] ✅ Frase aleatoria: ${response.data}');
      return response.data;
    } catch (e) {
      print('[BiometricBackend] ❌ Error obteniendo frase aleatoria: $e');
      rethrow;
    }
  }

  /// Agregar nueva frase
  /// POST /agregar/frases
  Future<Map<String, dynamic>> agregarFrase({required String frase}) async {
    try {
      final response = await _dioVoz.post(
        '/agregar/frases',
        data: {'frase': frase},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      print('[BiometricBackend] ✅ Frase agregada: ${response.data}');
      return response.data;
    } catch (e) {
      print('[BiometricBackend] ❌ Error agregando frase: $e');
      rethrow;
    }
  }

  /// Activar/Desactivar frase
  /// PATCH /frases/:id/estado
  Future<Map<String, dynamic>> cambiarEstadoFrase({
    required int id,
    required bool activo,
  }) async {
    try {
      final response = await _dioVoz.patch(
        '/frases/$id/estado',
        data: {'activo': activo ? 1 : 0},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      print('[BiometricBackend] ✅ Estado de frase cambiado: ${response.data}');
      return response.data;
    } catch (e) {
      print('[BiometricBackend] ❌ Error cambiando estado de frase: $e');
      rethrow;
    }
  }

  /// Eliminar frase
  /// DELETE /frases/:id
  Future<Map<String, dynamic>> eliminarFrase({required int id}) async {
    try {
      final response = await _dioVoz.delete('/frases/$id');
      print('[BiometricBackend] ✅ Frase eliminada: ${response.data}');
      return {'success': true, 'message': response.data};
    } catch (e) {
      print('[BiometricBackend] ❌ Error eliminando frase: $e');
      rethrow;
    }
  }

  /// Listar usuarios (voz)
  /// GET /voz/usuarios
  Future<List<Map<String, dynamic>>> listarUsuariosVoz() async {
    try {
      final response = await _dioVoz.get('/voz/usuarios');
      print(
        '[BiometricBackend] ✅ Usuarios voz listados: ${response.data.length}',
      );
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      print('[BiometricBackend] ❌ Error listando usuarios voz: $e');
      rethrow;
    }
  }

  /// Eliminar usuario de voz
  /// DELETE /voz/usuarios/:id
  Future<Map<String, dynamic>> eliminarUsuarioVoz({required int id}) async {
    try {
      final response = await _dioVoz.delete('/voz/usuarios/$id');
      print('[BiometricBackend] ✅ Usuario voz eliminado: ${response.data}');
      return {'success': true, 'message': response.data};
    } catch (e) {
      print('[BiometricBackend] ❌ Error eliminando usuario voz: $e');
      rethrow;
    }
  }
}
