import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

// ============================================================================
// TYPEDEFS FFI - Basados en mobile_api.h
// ============================================================================

// int voz_mobile_init(const char* db_path, const char* model_path, const char* dataset_path)
typedef _VozMobileInitNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Char> dbPath,
      ffi.Pointer<ffi.Char> modelPath,
      ffi.Pointer<ffi.Char> datasetPath,
    );
typedef _VozMobileInitDart =
    int Function(
      ffi.Pointer<ffi.Char> dbPath,
      ffi.Pointer<ffi.Char> modelPath,
      ffi.Pointer<ffi.Char> datasetPath,
    );

// void voz_mobile_cleanup()
typedef _VozMobileCleanupNative = ffi.Void Function();
typedef _VozMobileCleanupDart = void Function();

// const char* voz_mobile_version()
typedef _VozMobileVersionNative = ffi.Pointer<ffi.Char> Function();
typedef _VozMobileVersionDart = ffi.Pointer<ffi.Char> Function();

// int voz_mobile_obtener_id_usuario(const char* identificador)
typedef _VozMobileObtenerIdUsuarioNative =
    ffi.Int32 Function(ffi.Pointer<ffi.Char> identificador);
typedef _VozMobileObtenerIdUsuarioDart =
    int Function(ffi.Pointer<ffi.Char> identificador);

// int voz_mobile_crear_usuario(const char* identificador)
typedef _VozMobileCrearUsuarioNative =
    ffi.Int32 Function(ffi.Pointer<ffi.Char> identificador);
typedef _VozMobileCrearUsuarioDart =
    int Function(ffi.Pointer<ffi.Char> identificador);

// int voz_mobile_usuario_existe(const char* identificador)
typedef _VozMobileUsuarioExisteNative =
    ffi.Int32 Function(ffi.Pointer<ffi.Char> identificador);
typedef _VozMobileUsuarioExisteDart =
    int Function(ffi.Pointer<ffi.Char> identificador);

// int voz_mobile_obtener_frase_aleatoria(char* buffer, size_t buffer_size)
typedef _VozMobileObtenerFraseAleatoriaNative =
    ffi.Int32 Function(ffi.Pointer<ffi.Char> buffer, ffi.IntPtr bufferSize);
typedef _VozMobileObtenerFraseAleatoriaDart =
    int Function(ffi.Pointer<ffi.Char> buffer, int bufferSize);

// int voz_mobile_obtener_frase_por_id(int id_frase, char* buffer, size_t buffer_size)
typedef _VozMobileObtenerFrasePorIdNative =
    ffi.Int32 Function(
      ffi.Int32 idFrase,
      ffi.Pointer<ffi.Char> buffer,
      ffi.IntPtr bufferSize,
    );
typedef _VozMobileObtenerFrasePorIdDart =
    int Function(int idFrase, ffi.Pointer<ffi.Char> buffer, int bufferSize);

// int voz_mobile_insertar_frases(const char* frases_json)
typedef _VozMobileInsertarFrasesNative =
    ffi.Int32 Function(ffi.Pointer<ffi.Char> frasesJson);
typedef _VozMobileInsertarFrasesDart =
    int Function(ffi.Pointer<ffi.Char> frasesJson);

// int voz_mobile_registrar_biometria(const char* identificador, const char* audio_path, int id_frase, char* resultado_json, size_t buffer_size)
typedef _VozMobileRegistrarBiometriaNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Char> identificador,
      ffi.Pointer<ffi.Char> audioPath,
      ffi.Int32 idFrase,
      ffi.Pointer<ffi.Char> resultadoJson,
      ffi.IntPtr bufferSize,
    );
typedef _VozMobileRegistrarBiometriaDart =
    int Function(
      ffi.Pointer<ffi.Char> identificador,
      ffi.Pointer<ffi.Char> audioPath,
      int idFrase,
      ffi.Pointer<ffi.Char> resultadoJson,
      int bufferSize,
    );

// int voz_mobile_autenticar(const char* identificador, const char* audio_path, int id_frase, char* resultado_json, size_t buffer_size)
typedef _VozMobileAutenticarNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Char> identificador,
      ffi.Pointer<ffi.Char> audioPath,
      ffi.Int32 idFrase,
      ffi.Pointer<ffi.Char> resultadoJson,
      ffi.IntPtr bufferSize,
    );
typedef _VozMobileAutenticarDart =
    int Function(
      ffi.Pointer<ffi.Char> identificador,
      ffi.Pointer<ffi.Char> audioPath,
      int idFrase,
      ffi.Pointer<ffi.Char> resultadoJson,
      int bufferSize,
    );

// int voz_mobile_sync_push(const char* server_url, char* resultado_json, size_t buffer_size)
typedef _VozMobileSyncPushNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Char> serverUrl,
      ffi.Pointer<ffi.Char> resultadoJson,
      ffi.IntPtr bufferSize,
    );
typedef _VozMobileSyncPushDart =
    int Function(
      ffi.Pointer<ffi.Char> serverUrl,
      ffi.Pointer<ffi.Char> resultadoJson,
      int bufferSize,
    );

// int voz_mobile_sync_pull(const char* server_url, const char* desde, char* resultado_json, size_t buffer_size)
typedef _VozMobileSyncPullNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Char> serverUrl,
      ffi.Pointer<ffi.Char> desde,
      ffi.Pointer<ffi.Char> resultadoJson,
      ffi.IntPtr bufferSize,
    );
typedef _VozMobileSyncPullDart =
    int Function(
      ffi.Pointer<ffi.Char> serverUrl,
      ffi.Pointer<ffi.Char> desde,
      ffi.Pointer<ffi.Char> resultadoJson,
      int bufferSize,
    );

// int voz_mobile_sync_modelo(const char* server_url, const char* identificador, char* resultado_json, size_t buffer_size)
typedef _VozMobileSyncModeloNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Char> serverUrl,
      ffi.Pointer<ffi.Char> identificador,
      ffi.Pointer<ffi.Char> resultadoJson,
      ffi.IntPtr bufferSize,
    );
typedef _VozMobileSyncModeloDart =
    int Function(
      ffi.Pointer<ffi.Char> serverUrl,
      ffi.Pointer<ffi.Char> identificador,
      ffi.Pointer<ffi.Char> resultadoJson,
      int bufferSize,
    );

// int voz_mobile_obtener_uuid_dispositivo(char* buffer, size_t buffer_size)
typedef _VozMobileObtenerUuidDispositivoNative =
    ffi.Int32 Function(ffi.Pointer<ffi.Char> buffer, ffi.IntPtr bufferSize);
typedef _VozMobileObtenerUuidDispositivoDart =
    int Function(ffi.Pointer<ffi.Char> buffer, int bufferSize);

// int voz_mobile_establecer_uuid_dispositivo(const char* uuid)
typedef _VozMobileEstablecerUuidDispositivoNative =
    ffi.Int32 Function(ffi.Pointer<ffi.Char> uuid);
typedef _VozMobileEstablecerUuidDispositivoDart =
    int Function(ffi.Pointer<ffi.Char> uuid);

// void voz_mobile_obtener_ultimo_error(char* buffer, size_t buffer_size)
typedef _VozMobileObtenerUltimoErrorNative =
    ffi.Void Function(ffi.Pointer<ffi.Char> buffer, ffi.IntPtr bufferSize);
typedef _VozMobileObtenerUltimoErrorDart =
    void Function(ffi.Pointer<ffi.Char> buffer, int bufferSize);

// int voz_mobile_obtener_estadisticas(char* stats_json, size_t buffer_size)
typedef _VozMobileObtenerEstadisticasNative =
    ffi.Int32 Function(ffi.Pointer<ffi.Char> statsJson, ffi.IntPtr bufferSize);
typedef _VozMobileObtenerEstadisticasDart =
    int Function(ffi.Pointer<ffi.Char> statsJson, int bufferSize);

// ============================================================================
// SERVICIO FFI COMPLETO PARA MOBILE
// ============================================================================

class NativeVoiceMobileService {
  static ffi.DynamicLibrary? _lib;
  static bool _initialized = false;

  // Funciones FFI
  static _VozMobileInitDart? _vozMobileInit;
  static _VozMobileCleanupDart? _vozMobileCleanup;
  static _VozMobileVersionDart? _vozMobileVersion;
  static _VozMobileObtenerIdUsuarioDart? _vozMobileObtenerIdUsuario;
  static _VozMobileCrearUsuarioDart? _vozMobileCrearUsuario;
  static _VozMobileUsuarioExisteDart? _vozMobileUsuarioExiste;
  static _VozMobileObtenerFraseAleatoriaDart? _vozMobileObtenerFraseAleatoria;
  static _VozMobileObtenerFrasePorIdDart? _vozMobileObtenerFrasePorId;
  static _VozMobileInsertarFrasesDart? _vozMobileInsertarFrases;
  static _VozMobileRegistrarBiometriaDart? _vozMobileRegistrar;
  static _VozMobileAutenticarDart? _vozMobileAutenticar;
  static _VozMobileSyncPushDart? _vozMobileSyncPush;
  static _VozMobileSyncPullDart? _vozMobileSyncPull;
  static _VozMobileSyncModeloDart? _vozMobileSyncModelo;
  static _VozMobileObtenerUuidDispositivoDart? _vozMobileObtenerUuid;
  static _VozMobileEstablecerUuidDispositivoDart? _vozMobileEstablecerUuid;
  static _VozMobileObtenerUltimoErrorDart? _vozMobileObtenerError;
  static _VozMobileObtenerEstadisticasDart? _vozMobileObtenerEstadisticas;

  // ============================================================================
  // INICIALIZACION
  // ============================================================================

  /// Inicializar la librería nativa
  Future<bool> initialize() async {
    if (_initialized) {
      print('[NativeVoiceMobile] ✅ Ya inicializado');
      return true;
    }

    try {
      print('[NativeVoiceMobile] 🚀 Inicializando...');

      // 1. Cargar librería .so (solo si no está cargada)
      if (_lib == null) {
        _lib = ffi.DynamicLibrary.open('libvoz_mobile.so');
        print('[NativeVoiceMobile] ✅ Librería cargada');
      } else {
        print('[NativeVoiceMobile] ⏭️ Librería ya cargada');
      }

      // 2. Cargar funciones FFI (solo si no están cargadas)
      _loadFunctions();
      print('[NativeVoiceMobile] ✅ Funciones FFI cargadas');

      // 3. Copiar assets a almacenamiento local
      await _copyAssetsToLocal();
      print('[NativeVoiceMobile] ✅ Assets copiados');

      // 4. Obtener rutas
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDir.path}/biometria_mobile.db';
      final modelPath = '${appDir.path}/models/v1';
      final datasetPath =
          '${appDir.path}/caracteristicas/v1/caracteristicas_train.dat';

      print('[NativeVoiceMobile] 📂 DB: $dbPath');
      print('[NativeVoiceMobile] 📂 Models: $modelPath');
      print('[NativeVoiceMobile] 📂 Dataset: $datasetPath');

      // 5. Inicializar librería nativa
      final dbPathPtr = dbPath.toNativeUtf8();
      final modelPathPtr = modelPath.toNativeUtf8();
      final datasetPathPtr = datasetPath.toNativeUtf8();

      final result = _vozMobileInit!(
        dbPathPtr.cast(),
        modelPathPtr.cast(),
        datasetPathPtr.cast(),
      );

      malloc.free(dbPathPtr);
      malloc.free(modelPathPtr);
      malloc.free(datasetPathPtr);

      if (result == 0) {
        _initialized = true;
        print('[NativeVoiceMobile] ✅ Librería nativa inicializada');

        // Obtener versión
        final version = getVersion();
        print('[NativeVoiceMobile] 📦 Versión: $version');

        // Obtener estadísticas
        final stats = await getEstadisticas();
        print('[NativeVoiceMobile] 📊 Estadísticas: $stats');

        return true;
      } else {
        final error = getUltimoError();
        print('[NativeVoiceMobile] ❌ Error inicializando: $error');
        return false;
      }
    } catch (e, stackTrace) {
      print('[NativeVoiceMobile] ❌ Excepción: $e');
      print('[NativeVoiceMobile] Stack: $stackTrace');
      return false;
    }
  }

  /// Cargar todas las funciones FFI
  void _loadFunctions() {
    // Solo cargar si no están ya cargadas
    if (_vozMobileInit != null) {
      print('[NativeVoiceMobile] ⏭️ Funciones FFI ya cargadas');
      return;
    }

    _vozMobileInit = _lib!
        .lookup<ffi.NativeFunction<_VozMobileInitNative>>('voz_mobile_init')
        .asFunction<_VozMobileInitDart>();

    _vozMobileCleanup = _lib!
        .lookup<ffi.NativeFunction<_VozMobileCleanupNative>>(
          'voz_mobile_cleanup',
        )
        .asFunction<_VozMobileCleanupDart>();

    _vozMobileVersion = _lib!
        .lookup<ffi.NativeFunction<_VozMobileVersionNative>>(
          'voz_mobile_version',
        )
        .asFunction<_VozMobileVersionDart>();

    _vozMobileObtenerIdUsuario = _lib!
        .lookup<ffi.NativeFunction<_VozMobileObtenerIdUsuarioNative>>(
          'voz_mobile_obtener_id_usuario',
        )
        .asFunction<_VozMobileObtenerIdUsuarioDart>();

    _vozMobileCrearUsuario = _lib!
        .lookup<ffi.NativeFunction<_VozMobileCrearUsuarioNative>>(
          'voz_mobile_crear_usuario',
        )
        .asFunction<_VozMobileCrearUsuarioDart>();

    _vozMobileUsuarioExiste = _lib!
        .lookup<ffi.NativeFunction<_VozMobileUsuarioExisteNative>>(
          'voz_mobile_usuario_existe',
        )
        .asFunction<_VozMobileUsuarioExisteDart>();

    _vozMobileObtenerFraseAleatoria = _lib!
        .lookup<ffi.NativeFunction<_VozMobileObtenerFraseAleatoriaNative>>(
          'voz_mobile_obtener_frase_aleatoria',
        )
        .asFunction<_VozMobileObtenerFraseAleatoriaDart>();

    _vozMobileObtenerFrasePorId = _lib!
        .lookup<ffi.NativeFunction<_VozMobileObtenerFrasePorIdNative>>(
          'voz_mobile_obtener_frase_por_id',
        )
        .asFunction<_VozMobileObtenerFrasePorIdDart>();

    _vozMobileInsertarFrases = _lib!
        .lookup<ffi.NativeFunction<_VozMobileInsertarFrasesNative>>(
          'voz_mobile_insertar_frases',
        )
        .asFunction<_VozMobileInsertarFrasesDart>();

    _vozMobileRegistrar = _lib!
        .lookup<ffi.NativeFunction<_VozMobileRegistrarBiometriaNative>>(
          'voz_mobile_registrar_biometria',
        )
        .asFunction<_VozMobileRegistrarBiometriaDart>();

    _vozMobileAutenticar = _lib!
        .lookup<ffi.NativeFunction<_VozMobileAutenticarNative>>(
          'voz_mobile_autenticar',
        )
        .asFunction<_VozMobileAutenticarDart>();

    _vozMobileSyncPush = _lib!
        .lookup<ffi.NativeFunction<_VozMobileSyncPushNative>>(
          'voz_mobile_sync_push',
        )
        .asFunction<_VozMobileSyncPushDart>();

    _vozMobileSyncPull = _lib!
        .lookup<ffi.NativeFunction<_VozMobileSyncPullNative>>(
          'voz_mobile_sync_pull',
        )
        .asFunction<_VozMobileSyncPullDart>();

    _vozMobileSyncModelo = _lib!
        .lookup<ffi.NativeFunction<_VozMobileSyncModeloNative>>(
          'voz_mobile_sync_modelo',
        )
        .asFunction<_VozMobileSyncModeloDart>();

    _vozMobileObtenerUuid = _lib!
        .lookup<ffi.NativeFunction<_VozMobileObtenerUuidDispositivoNative>>(
          'voz_mobile_obtener_uuid_dispositivo',
        )
        .asFunction<_VozMobileObtenerUuidDispositivoDart>();

    _vozMobileEstablecerUuid = _lib!
        .lookup<ffi.NativeFunction<_VozMobileEstablecerUuidDispositivoNative>>(
          'voz_mobile_establecer_uuid_dispositivo',
        )
        .asFunction<_VozMobileEstablecerUuidDispositivoDart>();

    _vozMobileObtenerError = _lib!
        .lookup<ffi.NativeFunction<_VozMobileObtenerUltimoErrorNative>>(
          'voz_mobile_obtener_ultimo_error',
        )
        .asFunction<_VozMobileObtenerUltimoErrorDart>();

    _vozMobileObtenerEstadisticas = _lib!
        .lookup<ffi.NativeFunction<_VozMobileObtenerEstadisticasNative>>(
          'voz_mobile_obtener_estadisticas',
        )
        .asFunction<_VozMobileObtenerEstadisticasDart>();
  }

  /// Copiar assets (modelos, datasets) desde assets/ a almacenamiento local
  Future<void> _copyAssetsToLocal() async {
    final appDir = await getApplicationDocumentsDirectory();

    // Crear directorios
    await Directory('${appDir.path}/models/v1').create(recursive: true);
    await Directory(
      '${appDir.path}/caracteristicas/v1',
    ).create(recursive: true);

    // Copiar datasets desde assets (YA en la carpeta assets principal)
    await _copyAsset(
      'assets/caracteristicas/v1/caracteristicas_train.dat',
      '${appDir.path}/caracteristicas/v1/caracteristicas_train.dat',
    );
    await _copyAsset(
      'assets/caracteristicas/v1/caracteristicas_test.dat',
      '${appDir.path}/caracteristicas/v1/caracteristicas_test.dat',
    );

    // Copiar metadata desde assets
    await _copyAsset(
      'assets/models/v1/metadata.json',
      '${appDir.path}/models/v1/metadata.json',
    );

    print('[NativeVoiceMobile] ✅ Assets copiados a almacenamiento local');
  }

  /// Copiar un asset individual
  Future<void> _copyAsset(String assetPath, String targetPath) async {
    try {
      final file = File(targetPath);
      if (await file.exists()) {
        print('[NativeVoiceMobile] ⏭️ Asset ya existe: $targetPath');
        return;
      }

      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();

      await file.writeAsBytes(bytes);
      print(
        '[NativeVoiceMobile] ✅ Copiado: $assetPath → $targetPath (${bytes.length} bytes)',
      );
    } catch (e) {
      print('[NativeVoiceMobile] ⚠️ Error copiando $assetPath: $e');
    }
  }

  /// Liberar recursos
  void cleanup() {
    if (_initialized && _vozMobileCleanup != null) {
      _vozMobileCleanup!();
      _initialized = false;
      print('[NativeVoiceMobile] 🧹 Recursos liberados');
    }
  }

  // ============================================================================
  // UTILIDADES
  // ============================================================================

  /// Obtener versión de la librería
  String getVersion() {
    if (_vozMobileVersion == null) return 'unknown';

    final versionPtr = _vozMobileVersion!();
    return versionPtr.cast<Utf8>().toDartString();
  }

  /// Obtener último error
  String getUltimoError() {
    if (_vozMobileObtenerError == null) return 'Error desconocido';

    final buffer = malloc<ffi.Char>(1024);
    _vozMobileObtenerError!(buffer, 1024);

    final error = buffer.cast<Utf8>().toDartString();
    malloc.free(buffer);

    return error;
  }

  /// Obtener estadísticas del modelo
  Future<Map<String, dynamic>> getEstadisticas() async {
    if (_vozMobileObtenerEstadisticas == null) {
      return {'error': 'Función no disponible'};
    }

    final buffer = malloc<ffi.Char>(4096);

    try {
      final result = _vozMobileObtenerEstadisticas!(buffer, 4096);

      if (result == 0) {
        final jsonStr = buffer.cast<Utf8>().toDartString();
        return jsonDecode(jsonStr);
      } else {
        return {'error': getUltimoError()};
      }
    } finally {
      malloc.free(buffer);
    }
  }

  // ============================================================================
  // USUARIOS
  // ============================================================================

  /// Obtener ID de usuario por cédula
  int obtenerIdUsuario(String identificador) {
    if (_vozMobileObtenerIdUsuario == null) return -1;

    final identPtr = identificador.toNativeUtf8();
    final result = _vozMobileObtenerIdUsuario!(identPtr.cast());
    malloc.free(identPtr);

    return result;
  }

  /// Crear nuevo usuario
  int crearUsuario(String identificador) {
    if (_vozMobileCrearUsuario == null) return -1;

    final identPtr = identificador.toNativeUtf8();
    final result = _vozMobileCrearUsuario!(identPtr.cast());
    malloc.free(identPtr);

    print(
      '[NativeVoiceMobile] ${result >= 0 ? "✅" : "❌"} Usuario creado: $identificador (ID: $result)',
    );
    return result;
  }

  /// Verificar si usuario existe
  bool usuarioExiste(String identificador) {
    if (_vozMobileUsuarioExiste == null) return false;

    final identPtr = identificador.toNativeUtf8();
    final result = _vozMobileUsuarioExiste!(identPtr.cast());
    malloc.free(identPtr);

    return result == 1;
  }

  // ============================================================================
  // FRASES DINAMICAS
  // ============================================================================

  /// Obtener frase aleatoria
  Future<Map<String, dynamic>> obtenerFraseAleatoria() async {
    if (_vozMobileObtenerFraseAleatoria == null) {
      return {'error': 'Función no disponible'};
    }

    final buffer = malloc<ffi.Char>(512);

    try {
      final idFrase = _vozMobileObtenerFraseAleatoria!(buffer, 512);

      if (idFrase >= 0) {
        final frase = buffer.cast<Utf8>().toDartString();
        return {'id_frase': idFrase, 'frase': frase};
      } else {
        return {'error': getUltimoError()};
      }
    } finally {
      malloc.free(buffer);
    }
  }

  /// Obtener frase por ID
  Future<String?> obtenerFrasePorId(int idFrase) async {
    if (_vozMobileObtenerFrasePorId == null) return null;

    final buffer = malloc<ffi.Char>(512);

    try {
      final result = _vozMobileObtenerFrasePorId!(idFrase, buffer, 512);

      if (result == 0) {
        return buffer.cast<Utf8>().toDartString();
      } else {
        return null;
      }
    } finally {
      malloc.free(buffer);
    }
  }

  /// Insertar frases desde JSON
  int insertarFrases(List<Map<String, String>> frases) {
    if (_vozMobileInsertarFrases == null) return -1;

    final frasesJson = jsonEncode(frases);
    final jsonPtr = frasesJson.toNativeUtf8();

    final result = _vozMobileInsertarFrases!(jsonPtr.cast());
    malloc.free(jsonPtr);

    print('[NativeVoiceMobile] ✅ Insertadas $result frases');
    return result;
  }

  // ============================================================================
  // REGISTRO BIOMETRICO
  // ============================================================================

  /// Registrar biometría de voz
  Future<Map<String, dynamic>> registerBiometric({
    required String identificador,
    required String audioPath,
    required int idFrase,
  }) async {
    if (_vozMobileRegistrar == null) {
      return {'success': false, 'error': 'Función no disponible'};
    }

    print('[NativeVoiceMobile] 📝 Registrando biometría...');
    print('[NativeVoiceMobile]    Usuario: $identificador');
    print('[NativeVoiceMobile]    Audio: $audioPath');
    print('[NativeVoiceMobile]    Frase ID: $idFrase');

    final identPtr = identificador.toNativeUtf8();
    final audioPtr = audioPath.toNativeUtf8();
    final resultBuffer = malloc<ffi.Char>(8192);

    try {
      final returnCode = _vozMobileRegistrar!(
        identPtr.cast(),
        audioPtr.cast(),
        idFrase,
        resultBuffer.cast(),
        8192,
      );

      if (returnCode == 0) {
        final jsonStr = resultBuffer.cast<Utf8>().toDartString();
        final resultado = jsonDecode(jsonStr);

        print('[NativeVoiceMobile] ✅ Registro exitoso: $resultado');
        return resultado;
      } else {
        final error = getUltimoError();
        print('[NativeVoiceMobile] ❌ Error en registro: $error');
        return {'success': false, 'error': error};
      }
    } finally {
      malloc.free(identPtr);
      malloc.free(audioPtr);
      malloc.free(resultBuffer);
    }
  }

  // ============================================================================
  // AUTENTICACION
  // ============================================================================

  /// Autenticar usuario por voz
  Future<Map<String, dynamic>> authenticate({
    required String identificador,
    required String audioPath,
    required int idFrase,
  }) async {
    if (_vozMobileAutenticar == null) {
      return {'success': false, 'error': 'Función no disponible'};
    }

    print('[NativeVoiceMobile] 🔐 Autenticando...');
    print('[NativeVoiceMobile]    Usuario: $identificador');
    print('[NativeVoiceMobile]    Audio: $audioPath');
    print('[NativeVoiceMobile]    Frase ID: $idFrase');

    final identPtr = identificador.toNativeUtf8();
    final audioPtr = audioPath.toNativeUtf8();
    final resultBuffer = malloc<ffi.Char>(8192);

    try {
      final returnCode = _vozMobileAutenticar!(
        identPtr.cast(),
        audioPtr.cast(),
        idFrase,
        resultBuffer.cast(),
        8192,
      );

      final jsonStr = resultBuffer.cast<Utf8>().toDartString();
      final resultado = jsonDecode(jsonStr);

      if (returnCode == 1) {
        print('[NativeVoiceMobile] ✅ Autenticado: $resultado');
      } else if (returnCode == 0) {
        print('[NativeVoiceMobile] ❌ Rechazado: $resultado');
      } else {
        print('[NativeVoiceMobile] ⚠️ Error: $resultado');
      }

      return resultado;
    } finally {
      malloc.free(identPtr);
      malloc.free(audioPtr);
      malloc.free(resultBuffer);
    }
  }

  // ============================================================================
  // SINCRONIZACION
  // ============================================================================

  /// Push: enviar vectores pendientes al servidor
  Future<Map<String, dynamic>> syncPush(String serverUrl) async {
    if (_vozMobileSyncPush == null) {
      return {'ok': false, 'error': 'Función no disponible'};
    }

    print('[NativeVoiceMobile] 🔄 Sync Push → $serverUrl');

    final urlPtr = serverUrl.toNativeUtf8();
    final resultBuffer = malloc<ffi.Char>(8192);

    try {
      final returnCode = _vozMobileSyncPush!(
        urlPtr.cast(),
        resultBuffer.cast(),
        8192,
      );

      if (returnCode == 0) {
        final jsonStr = resultBuffer.cast<Utf8>().toDartString();
        final resultado = jsonDecode(jsonStr);

        print('[NativeVoiceMobile] ✅ Sync Push OK: $resultado');
        return resultado;
      } else {
        final error = getUltimoError();
        print('[NativeVoiceMobile] ❌ Sync Push Error: $error');
        return {'ok': false, 'error': error};
      }
    } finally {
      malloc.free(urlPtr);
      malloc.free(resultBuffer);
    }
  }

  /// Pull: descargar cambios del servidor
  Future<Map<String, dynamic>> syncPull(
    String serverUrl, {
    String? desde,
  }) async {
    if (_vozMobileSyncPull == null) {
      return {'ok': false, 'error': 'Función no disponible'};
    }

    print('[NativeVoiceMobile] 🔄 Sync Pull ← $serverUrl');

    final urlPtr = serverUrl.toNativeUtf8();
    final desdePtr = (desde ?? '').toNativeUtf8();
    final resultBuffer = malloc<ffi.Char>(16384);

    try {
      final returnCode = _vozMobileSyncPull!(
        urlPtr.cast(),
        desdePtr.cast(),
        resultBuffer.cast(),
        16384,
      );

      if (returnCode == 0) {
        final jsonStr = resultBuffer.cast<Utf8>().toDartString();
        final resultado = jsonDecode(jsonStr);

        print('[NativeVoiceMobile] ✅ Sync Pull OK: $resultado');
        return resultado;
      } else {
        final error = getUltimoError();
        print('[NativeVoiceMobile] ❌ Sync Pull Error: $error');
        return {'ok': false, 'error': error};
      }
    } finally {
      malloc.free(urlPtr);
      malloc.free(desdePtr);
      malloc.free(resultBuffer);
    }
  }

  /// Pull modelo: descargar modelo re-entrenado
  Future<Map<String, dynamic>> syncModelo(
    String serverUrl,
    String identificador,
  ) async {
    if (_vozMobileSyncModelo == null) {
      return {'ok': false, 'error': 'Función no disponible'};
    }

    print('[NativeVoiceMobile] 🔄 Sync Modelo ← $serverUrl ($identificador)');

    final urlPtr = serverUrl.toNativeUtf8();
    final identPtr = identificador.toNativeUtf8();
    final resultBuffer = malloc<ffi.Char>(4096);

    try {
      final returnCode = _vozMobileSyncModelo!(
        urlPtr.cast(),
        identPtr.cast(),
        resultBuffer.cast(),
        4096,
      );

      if (returnCode == 0) {
        final jsonStr = resultBuffer.cast<Utf8>().toDartString();
        final resultado = jsonDecode(jsonStr);

        print('[NativeVoiceMobile] ✅ Modelo sincronizado: $resultado');
        return resultado;
      } else {
        final error = getUltimoError();
        print('[NativeVoiceMobile] ❌ Error sincronizando modelo: $error');
        return {'ok': false, 'error': error};
      }
    } finally {
      malloc.free(urlPtr);
      malloc.free(identPtr);
      malloc.free(resultBuffer);
    }
  }

  /// Obtener UUID del dispositivo
  String? obtenerUuidDispositivo() {
    if (_vozMobileObtenerUuid == null) return null;

    final buffer = malloc<ffi.Char>(128);

    try {
      final result = _vozMobileObtenerUuid!(buffer, 128);

      if (result == 0) {
        return buffer.cast<Utf8>().toDartString();
      } else {
        return null;
      }
    } finally {
      malloc.free(buffer);
    }
  }

  /// Establecer UUID del dispositivo
  bool establecerUuidDispositivo(String uuid) {
    if (_vozMobileEstablecerUuid == null) return false;

    final uuidPtr = uuid.toNativeUtf8();
    final result = _vozMobileEstablecerUuid!(uuidPtr.cast());
    malloc.free(uuidPtr);

    print(
      '[NativeVoiceMobile] ${result == 0 ? "✅" : "❌"} UUID establecido: $uuid',
    );
    return result == 0;
  }
}
