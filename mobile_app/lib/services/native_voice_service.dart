import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

// ============================================================================
// TYPEDEFS FFI - Declaraciones de funciones nativas
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

// int voz_mobile_obtener_cola_sincronizacion(char* cola_json, size_t buffer_size)
typedef _VozMobileObtenerColaSincronizacionNative =
    ffi.Int32 Function(ffi.Pointer<ffi.Char> colaJson, ffi.IntPtr bufferSize);
typedef _VozMobileObtenerColaSincronizacionDart =
    int Function(ffi.Pointer<ffi.Char> colaJson, int bufferSize);

// int voz_mobile_marcar_sincronizado(int id_sync)
typedef _VozMobileMarcarSincronizadoNative =
    ffi.Int32 Function(ffi.Int32 idSync);
typedef _VozMobileMarcarSincronizadoDart = int Function(int idSync);

// void voz_mobile_obtener_ultimo_error(char* buffer, size_t buffer_size)
typedef _VozMobileObtenerUltimoErrorNative =
    ffi.Void Function(ffi.Pointer<ffi.Char> buffer, ffi.IntPtr bufferSize);
typedef _VozMobileObtenerUltimoErrorDart =
    void Function(ffi.Pointer<ffi.Char> buffer, int bufferSize);

/// Servicio FFI para la librería nativa libvoz_mobile.so
/// Proporciona funcionalidad de biometría de voz offline/online
class NativeVoiceService {
  static final NativeVoiceService _instance = NativeVoiceService._internal();
  factory NativeVoiceService() => _instance;
  NativeVoiceService._internal();

  ffi.DynamicLibrary? _library;
  bool _initialized = false;
  String? _dbPath;
  String? _modelPath;
  String? _datasetPath;

  // ============================================================================
  // FUNCIONES DART
  // ============================================================================

  late final _VozMobileInitDart _vozMobileInit;
  late final _VozMobileCleanupDart _vozMobileCleanup;
  late final _VozMobileVersionDart _vozMobileVersion;
  late final _VozMobileObtenerIdUsuarioDart _vozMobileObtenerIdUsuario;
  late final _VozMobileCrearUsuarioDart _vozMobileCrearUsuario;
  late final _VozMobileUsuarioExisteDart _vozMobileUsuarioExiste;
  late final _VozMobileObtenerFraseAleatoriaDart
  _vozMobileObtenerFraseAleatoria;
  late final _VozMobileRegistrarBiometriaDart _vozMobileRegistrarBiometria;
  late final _VozMobileAutenticarDart _vozMobileAutenticar;
  late final _VozMobileObtenerColaSincronizacionDart
  _vozMobileObtenerColaSincronizacion;
  late final _VozMobileMarcarSincronizadoDart _vozMobileMarcarSincronizado;
  late final _VozMobileObtenerUltimoErrorDart _vozMobileObtenerUltimoError;

  /// Inicializa la librería nativa y carga todos los símbolos
  Future<bool> initialize() async {
    if (_initialized) {
      print('[NativeVoiceService] ✅ Ya inicializado');
      return true;
    }

    try {
      // 1. Cargar la librería nativa
      print('[NativeVoiceService] 📚 Cargando libvoz_mobile.so...');
      if (Platform.isAndroid) {
        _library = ffi.DynamicLibrary.open('libvoz_mobile.so');
      } else if (Platform.isIOS) {
        _library = ffi.DynamicLibrary.process();
      } else {
        throw Exception('Plataforma no soportada');
      }

      // 2. Cargar símbolos de funciones
      print('[NativeVoiceService] 🔗 Vinculando símbolos FFI...');
      _loadSymbols();

      // 3. Copiar assets en primera ejecución
      await _copiarAssetsEnPrimeraEjecucion();

      // 4. Inicializar la librería nativa
      final appDir = await getApplicationDocumentsDirectory();
      _dbPath = '${appDir.path}/biometria_mobile.db';
      _modelPath = '${appDir.path}/models/v1';
      _datasetPath = '${appDir.path}/caracteristicas/v1';

      print('[NativeVoiceService] 🚀 Inicializando librería nativa...');
      print('[NativeVoiceService]   DB: $_dbPath');
      print('[NativeVoiceService]   Models: $_modelPath');
      print('[NativeVoiceService]   Dataset: $_datasetPath');

      final dbPathPtr = _dbPath!.toNativeUtf8().cast<ffi.Char>();
      final modelPathPtr = _modelPath!.toNativeUtf8().cast<ffi.Char>();
      final datasetPathPtr = _datasetPath!.toNativeUtf8().cast<ffi.Char>();

      final result = _vozMobileInit(dbPathPtr, modelPathPtr, datasetPathPtr);

      malloc.free(dbPathPtr);
      malloc.free(modelPathPtr);
      malloc.free(datasetPathPtr);

      if (result != 0) {
        final error = getLastError();
        throw Exception('Error inicializando librería nativa: $error');
      }

      _initialized = true;
      final version = getVersion();
      print(
        '[NativeVoiceService] ✅ Librería inicializada correctamente (v$version)',
      );
      return true;
    } catch (e) {
      print('[NativeVoiceService] ❌ Error en inicialización: $e');
      return false;
    }
  }

  /// Carga todos los símbolos de la librería
  void _loadSymbols() {
    _vozMobileInit = _library!
        .lookupFunction<_VozMobileInitNative, _VozMobileInitDart>(
          'voz_mobile_init',
        );

    _vozMobileCleanup = _library!
        .lookupFunction<_VozMobileCleanupNative, _VozMobileCleanupDart>(
          'voz_mobile_cleanup',
        );

    _vozMobileVersion = _library!
        .lookupFunction<_VozMobileVersionNative, _VozMobileVersionDart>(
          'voz_mobile_version',
        );

    _vozMobileObtenerIdUsuario = _library!
        .lookupFunction<
          _VozMobileObtenerIdUsuarioNative,
          _VozMobileObtenerIdUsuarioDart
        >('voz_mobile_obtener_id_usuario');

    _vozMobileCrearUsuario = _library!
        .lookupFunction<
          _VozMobileCrearUsuarioNative,
          _VozMobileCrearUsuarioDart
        >('voz_mobile_crear_usuario');

    _vozMobileUsuarioExiste = _library!
        .lookupFunction<
          _VozMobileUsuarioExisteNative,
          _VozMobileUsuarioExisteDart
        >('voz_mobile_usuario_existe');

    _vozMobileObtenerFraseAleatoria = _library!
        .lookupFunction<
          _VozMobileObtenerFraseAleatoriaNative,
          _VozMobileObtenerFraseAleatoriaDart
        >('voz_mobile_obtener_frase_aleatoria');

    _vozMobileRegistrarBiometria = _library!
        .lookupFunction<
          _VozMobileRegistrarBiometriaNative,
          _VozMobileRegistrarBiometriaDart
        >('voz_mobile_registrar_biometria');

    _vozMobileAutenticar = _library!
        .lookupFunction<_VozMobileAutenticarNative, _VozMobileAutenticarDart>(
          'voz_mobile_autenticar',
        );

    _vozMobileObtenerColaSincronizacion = _library!
        .lookupFunction<
          _VozMobileObtenerColaSincronizacionNative,
          _VozMobileObtenerColaSincronizacionDart
        >('voz_mobile_obtener_cola_sincronizacion');

    _vozMobileMarcarSincronizado = _library!
        .lookupFunction<
          _VozMobileMarcarSincronizadoNative,
          _VozMobileMarcarSincronizadoDart
        >('voz_mobile_marcar_sincronizado');

    _vozMobileObtenerUltimoError = _library!
        .lookupFunction<
          _VozMobileObtenerUltimoErrorNative,
          _VozMobileObtenerUltimoErrorDart
        >('voz_mobile_obtener_ultimo_error');
  }

  /// Copia assets (modelos SVM y datasets) al directorio de la app
  Future<void> _copiarAssetsEnPrimeraEjecucion() async {
    final appDir = await getApplicationDocumentsDirectory();
    final assetsCopiados = File('${appDir.path}/.assets_copiados');

    if (await assetsCopiados.exists()) {
      print('[NativeVoiceService] ✅ Assets ya copiados anteriormente');
      return;
    }

    print(
      '[NativeVoiceService] 📦 Copiando modelos y datasets (primera ejecución)...',
    );

    // Crear directorios
    await Directory('${appDir.path}/models/v1').create(recursive: true);
    await Directory(
      '${appDir.path}/caracteristicas/v1',
    ).create(recursive: true);

    // Copiar metadata.json
    try {
      final metadataData = await rootBundle.load(
        'assets/models/v1/metadata.json',
      );
      await File(
        '${appDir.path}/models/v1/metadata.json',
      ).writeAsBytes(metadataData.buffer.asUint8List());
      print('[NativeVoiceService]   ✓ metadata.json copiado');
    } catch (e) {
      print('[NativeVoiceService]   ⚠️ Error copiando metadata.json: $e');
    }

    // Copiar archivos class_*.bin (68 archivos)
    final classFiles = [
      '10013',
      '101',
      '1026',
      '10310',
      '10312',
      '103',
      '10410',
      '10411',
      '10412',
      '10413',
      '10415',
      '1048',
      '10510',
      '10515',
      '10517',
      '10518',
      '10519',
      '10610',
      '10615',
      '10710',
      '10712',
      '10715',
      '10810',
      '10811',
      '10817',
      '10818',
      '10910',
      '10912',
      '11010',
      '11015',
      '11110',
      '11117',
      '11118',
      '11210',
      '11215',
      '11217',
      '11218',
      '11219',
      '11310',
      '11311',
      '11312',
      '11410',
      '11411',
      '11412',
      '11415',
      '11416',
      '11417',
      '11418',
      '11510',
      '11511',
      '11610',
      '11611',
      '11612',
      '11613',
      '11614',
      '11615',
      '11617',
      '11810',
      '11811',
      '11910',
      '11911',
      '12010',
      '12011',
      '12012',
      '12110',
      '12210',
      '13',
      '93',
    ];

    int copiados = 0;
    for (final classId in classFiles) {
      try {
        final data = await rootBundle.load(
          'assets/models/v1/class_$classId.bin',
        );
        await File(
          '${appDir.path}/models/v1/class_$classId.bin',
        ).writeAsBytes(data.buffer.asUint8List());
        copiados++;
      } catch (e) {
        print(
          '[NativeVoiceService]   ⚠️ Error copiando class_$classId.bin: $e',
        );
      }
    }
    print('[NativeVoiceService]   ✓ $copiados archivos class_*.bin copiados');

    // Copiar datasets
    try {
      final trainData = await rootBundle.load(
        'assets/caracteristicas/v1/caracteristicas_train.dat',
      );
      await File(
        '${appDir.path}/caracteristicas/v1/caracteristicas_train.dat',
      ).writeAsBytes(trainData.buffer.asUint8List());
      print('[NativeVoiceService]   ✓ caracteristicas_train.dat copiado');
    } catch (e) {
      print('[NativeVoiceService]   ⚠️ Error copiando train.dat: $e');
    }

    try {
      final testData = await rootBundle.load(
        'assets/caracteristicas/v1/caracteristicas_test.dat',
      );
      await File(
        '${appDir.path}/caracteristicas/v1/caracteristicas_test.dat',
      ).writeAsBytes(testData.buffer.asUint8List());
      print('[NativeVoiceService]   ✓ caracteristicas_test.dat copiado');
    } catch (e) {
      print('[NativeVoiceService]   ⚠️ Error copiando test.dat: $e');
    }

    // Marcar como copiado
    await assetsCopiados.writeAsString('1');
    print('[NativeVoiceService] ✅ Assets copiados correctamente');
  }

  // ============================================================================
  // API PÚBLICA
  // ============================================================================

  /// Obtiene la versión de la librería nativa
  String getVersion() {
    if (!_initialized) return 'No inicializado';
    final versionPtr = _vozMobileVersion();
    return versionPtr.cast<Utf8>().toDartString();
  }

  /// Obtiene el ID de usuario por identificador
  int getUserId(String identificador) {
    if (!_initialized) throw Exception('Servicio no inicializado');
    final idPtr = identificador.toNativeUtf8().cast<ffi.Char>();
    final userId = _vozMobileObtenerIdUsuario(idPtr);
    malloc.free(idPtr);
    return userId; // Retorna -1 si no existe
  }

  /// Crea un nuevo usuario
  int createUser(String identificador) {
    if (!_initialized) throw Exception('Servicio no inicializado');
    final idPtr = identificador.toNativeUtf8().cast<ffi.Char>();
    final userId = _vozMobileCrearUsuario(idPtr);
    malloc.free(idPtr);
    return userId;
  }

  /// Verifica si un usuario existe
  bool userExists(String identificador) {
    if (!_initialized) throw Exception('Servicio no inicializado');
    final idPtr = identificador.toNativeUtf8().cast<ffi.Char>();
    final exists = _vozMobileUsuarioExiste(idPtr);
    malloc.free(idPtr);
    return exists == 1;
  }

  /// Obtiene una frase aleatoria para autenticación
  Map<String, dynamic> getRandomPhrase() {
    if (!_initialized) throw Exception('Servicio no inicializado');
    final buffer = malloc<ffi.Char>(512);
    final idFrase = _vozMobileObtenerFraseAleatoria(buffer, 512);
    final frase = buffer.cast<Utf8>().toDartString();
    malloc.free(buffer);

    return {'id_frase': idFrase, 'frase': frase};
  }

  /// Registra biometría de voz (OFFLINE)
  Map<String, dynamic> registerBiometric({
    required String identificador,
    required String audioPath,
    required int idFrase,
  }) {
    if (!_initialized) throw Exception('Servicio no inicializado');

    final idPtr = identificador.toNativeUtf8().cast<ffi.Char>();
    final audioPtr = audioPath.toNativeUtf8().cast<ffi.Char>();
    final resultBuffer = malloc<ffi.Char>(4096);

    final result = _vozMobileRegistrarBiometria(
      idPtr,
      audioPtr,
      idFrase,
      resultBuffer,
      4096,
    );

    final jsonString = resultBuffer.cast<Utf8>().toDartString();
    malloc.free(idPtr);
    malloc.free(audioPtr);
    malloc.free(resultBuffer);

    if (result == 0) {
      try {
        return json.decode(jsonString);
      } catch (e) {
        return {
          'success': true,
          'message': 'Registro exitoso',
          'raw_response': jsonString,
        };
      }
    } else {
      return {
        'success': false,
        'error': 'Error en registro',
        'error_message': getLastError(),
      };
    }
  }

  /// Autentica usuario por voz (OFFLINE)
  Map<String, dynamic> authenticate({
    required String identificador,
    required String audioPath,
    required int idFrase,
  }) {
    if (!_initialized) throw Exception('Servicio no inicializado');

    final idPtr = identificador.toNativeUtf8().cast<ffi.Char>();
    final audioPtr = audioPath.toNativeUtf8().cast<ffi.Char>();
    final resultBuffer = malloc<ffi.Char>(4096);

    final result = _vozMobileAutenticar(
      idPtr,
      audioPtr,
      idFrase,
      resultBuffer,
      4096,
    );

    final jsonString = resultBuffer.cast<Utf8>().toDartString();
    malloc.free(idPtr);
    malloc.free(audioPtr);
    malloc.free(resultBuffer);

    if (result == 1) {
      // Autenticación exitosa
      try {
        final data = json.decode(jsonString);
        return {'success': true, 'authenticated': true, ...data};
      } catch (e) {
        return {
          'success': true,
          'authenticated': true,
          'message': 'Autenticación exitosa',
        };
      }
    } else if (result == 0) {
      // Autenticación rechazada
      return {
        'success': true,
        'authenticated': false,
        'message': 'Autenticación rechazada',
      };
    } else {
      // Error
      return {
        'success': false,
        'authenticated': false,
        'error': 'Error en autenticación',
        'error_message': getLastError(),
      };
    }
  }

  /// Obtiene la cola de sincronización pendiente
  List<Map<String, dynamic>> getSyncQueue() {
    if (!_initialized) throw Exception('Servicio no inicializado');

    final buffer = malloc<ffi.Char>(16384); // 16KB buffer
    final count = _vozMobileObtenerColaSincronizacion(buffer, 16384);

    if (count < 0) {
      malloc.free(buffer);
      return [];
    }

    final jsonString = buffer.cast<Utf8>().toDartString();
    malloc.free(buffer);

    try {
      final List<dynamic> data = json.decode(jsonString);
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      print('[NativeVoiceService] ❌ Error parseando cola de sync: $e');
      return [];
    }
  }

  /// Marca un item como sincronizado
  bool markAsSynced(int idSync) {
    if (!_initialized) throw Exception('Servicio no inicializado');
    final result = _vozMobileMarcarSincronizado(idSync);
    return result == 0;
  }

  /// Obtiene el último error ocurrido
  String getLastError() {
    if (!_initialized || _library == null) return 'Servicio no inicializado';
    final buffer = malloc<ffi.Char>(1024);
    _vozMobileObtenerUltimoError(buffer, 1024);
    final error = buffer.cast<Utf8>().toDartString();
    malloc.free(buffer);
    return error.isEmpty ? 'Sin error' : error;
  }

  /// Limpia recursos
  void cleanup() {
    if (_initialized && _library != null) {
      _vozMobileCleanup();
      _initialized = false;
      print('[NativeVoiceService] 🧹 Recursos liberados');
    }
  }
}
