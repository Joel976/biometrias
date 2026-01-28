import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

// ============================================================================
// Servicio FFI para libOreja Mobile (Android ARM64)
// ============================================================================

class NativeEarMobileService {
  static final NativeEarMobileService _instance =
      NativeEarMobileService._internal();
  factory NativeEarMobileService() => _instance;
  NativeEarMobileService._internal();

  ffi.DynamicLibrary? _lib;
  bool _initialized = false;

  // ============================================================================
  // FIRMAS DE FUNCIONES FFI
  // ============================================================================

  // int oreja_mobile_init(const char* model_dir, const char* dataset_csv, const char* templates_csv)
  int Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  )?
  _orejaMobileInit;

  // void oreja_mobile_cleanup()
  void Function()? _orejaMobileCleanup;

  // const char* oreja_mobile_version()
  ffi.Pointer<ffi.Char> Function()? _orejaMobileVersion;

  // int oreja_mobile_registrar_biometria(int identificador, const char** paths, int count, char* result, size_t size)
  int Function(
    int,
    ffi.Pointer<ffi.Pointer<ffi.Char>>,
    int,
    ffi.Pointer<ffi.Char>,
    int,
  )?
  _orejaMobileRegistrar;

  // int oreja_mobile_autenticar(int identificador, const char* image_path, double umbral, char* result, size_t size)
  int Function(int, ffi.Pointer<ffi.Char>, double, ffi.Pointer<ffi.Char>, int)?
  _orejaMobileAutenticar;

  // void oreja_mobile_obtener_ultimo_error(char* buffer, size_t size)
  void Function(ffi.Pointer<ffi.Char>, int)? _orejaMobileGetError;

  // int oreja_mobile_obtener_estadisticas(char* stats, size_t size)
  int Function(ffi.Pointer<ffi.Char>, int)? _orejaMobileStats;

  // int oreja_mobile_reload_templates()
  int Function()? _orejaMobileReloadTemplates;

  // int oreja_mobile_sync_push(const char* server_url, char* resultado_json, size_t buffer_size)
  int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>, int)?
  _orejaMobileSyncPush;

  // int oreja_mobile_sync_pull(const char* server_url, const char* desde, char* resultado_json, size_t buffer_size)
  int Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    int,
  )?
  _orejaMobileSyncPull;

  // int oreja_mobile_sync_modelo(const char* server_url, const char* archivo, char* resultado_json, size_t buffer_size)
  int Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    int,
  )?
  _orejaMobileSyncModelo;

  // ============================================================================
  // INICIALIZACION
  // ============================================================================

  Future<void> initialize() async {
    if (_initialized) {
      print('[NativeEarMobile] ✅ Ya inicializado');
      return;
    }

    try {
      print('[NativeEarMobile] 🚀 Inicializando...');

      // Cargar librería nativa
      _lib = ffi.DynamicLibrary.open('liboreja_mobile.so');
      print('[NativeEarMobile] ✅ Librería cargada');

      // Cargar funciones FFI
      _loadFunctions();
      print('[NativeEarMobile] ✅ Funciones FFI cargadas');

      // Copiar assets a almacenamiento local
      await _copyAssets();

      // Obtener rutas
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = '${appDir.path}/models';
      final datasetCsv = '${appDir.path}/models/caracteristicas_lda_train.csv';
      final templatesCsv = '${appDir.path}/models/templates_k1.csv';

      print('[NativeEarMobile] 📂 Models: $modelDir');
      print('[NativeEarMobile] 📂 Dataset: $datasetCsv');
      print('[NativeEarMobile] 📂 Templates: $templatesCsv');

      // Inicializar librería nativa
      final modelDirPtr = modelDir.toNativeUtf8();
      final datasetPtr = datasetCsv.toNativeUtf8();
      final templatesPtr = templatesCsv.toNativeUtf8();

      final result = _orejaMobileInit!(
        modelDirPtr.cast(),
        datasetPtr.cast(),
        templatesPtr.cast(),
      );

      malloc.free(modelDirPtr);
      malloc.free(datasetPtr);
      malloc.free(templatesPtr);

      if (result != 0) {
        final error = getUltimoError();
        throw Exception('Error inicializando librería nativa: $error');
      }

      print('[NativeEarMobile] ✅ Librería nativa inicializada');

      // Obtener versión
      final version = _orejaMobileVersion!();
      final versionStr = version.cast<Utf8>().toDartString();
      print('[NativeEarMobile] 📦 Versión: $versionStr');

      // Obtener estadísticas
      final stats = await obtenerEstadisticas();
      print('[NativeEarMobile] 📊 Estadísticas: $stats');

      _initialized = true;
    } catch (e) {
      print('[NativeEarMobile] ❌ Error inicializando: $e');
      rethrow;
    }
  }

  void _loadFunctions() {
    _orejaMobileInit = _lib!
        .lookup<
          ffi.NativeFunction<
            ffi.Int32 Function(
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
            )
          >
        >('oreja_mobile_init')
        .asFunction();

    _orejaMobileCleanup = _lib!
        .lookup<ffi.NativeFunction<ffi.Void Function()>>('oreja_mobile_cleanup')
        .asFunction();

    _orejaMobileVersion = _lib!
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function()>>(
          'oreja_mobile_version',
        )
        .asFunction();

    _orejaMobileRegistrar = _lib!
        .lookup<
          ffi.NativeFunction<
            ffi.Int32 Function(
              ffi.Int32,
              ffi.Pointer<ffi.Pointer<ffi.Char>>,
              ffi.Int32,
              ffi.Pointer<ffi.Char>,
              ffi.Size,
            )
          >
        >('oreja_mobile_registrar_biometria')
        .asFunction();

    _orejaMobileAutenticar = _lib!
        .lookup<
          ffi.NativeFunction<
            ffi.Int32 Function(
              ffi.Int32,
              ffi.Pointer<ffi.Char>,
              ffi.Double,
              ffi.Pointer<ffi.Char>,
              ffi.Size,
            )
          >
        >('oreja_mobile_autenticar')
        .asFunction();

    _orejaMobileGetError = _lib!
        .lookup<
          ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Char>, ffi.Size)>
        >('oreja_mobile_obtener_ultimo_error')
        .asFunction();

    _orejaMobileStats = _lib!
        .lookup<
          ffi.NativeFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>, ffi.Size)
          >
        >('oreja_mobile_obtener_estadisticas')
        .asFunction();

    _orejaMobileReloadTemplates = _lib!
        .lookup<ffi.NativeFunction<ffi.Int32 Function()>>(
          'oreja_mobile_reload_templates',
        )
        .asFunction();

    _orejaMobileSyncPush = _lib!
        .lookup<
          ffi.NativeFunction<
            ffi.Int32 Function(
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Size,
            )
          >
        >('oreja_mobile_sync_push')
        .asFunction();

    _orejaMobileSyncPull = _lib!
        .lookup<
          ffi.NativeFunction<
            ffi.Int32 Function(
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Size,
            )
          >
        >('oreja_mobile_sync_pull')
        .asFunction();

    _orejaMobileSyncModelo = _lib!
        .lookup<
          ffi.NativeFunction<
            ffi.Int32 Function(
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Size,
            )
          >
        >('oreja_mobile_sync_modelo')
        .asFunction();
  }

  Future<void> _copyAssets() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = '${appDir.path}/models';

    // Crear directorios
    await Directory(modelsDir).create(recursive: true);

    // ✅ Verificar si ya se copiaron los modelos (primera ejecución)
    final flagFile = File('$modelsDir/.modelos_oreja_copiados');
    if (await flagFile.exists()) {
      print(
        '[NativeEarMobile] ⏭️ Modelos ya copiados previamente (skip para rapidez)',
      );
      return;
    }

    print('[NativeEarMobile] 📦 Primera ejecución: copiando modelos base...');

    // ✅ Copiar modelos base (SOLO si no existen)
    await _copyAsset(
      'assets/models/zscore_params.dat',
      '${appDir.path}/models/zscore_params.dat',
    );
    await _copyAsset(
      'assets/models/modelo_pca.dat',
      '${appDir.path}/models/modelo_pca.dat',
    );
    await _copyAsset(
      'assets/models/modelo_lda.dat',
      '${appDir.path}/models/modelo_lda.dat',
    );
    await _copyAsset(
      'assets/models/caracteristicas_lda_train.csv',
      '${appDir.path}/models/caracteristicas_lda_train.csv',
    );

    // ✅ Templates base (50 usuarios pre-cargados para comparación LDA)
    // Similar a los 68 clasificadores .bin de VOZ
    await _copyAsset(
      'assets/models/templates_k1.csv',
      '${appDir.path}/models/templates_k1.csv',
    );

    print(
      '[NativeEarMobile] ✅ Modelos base copiados (conservando templates pre-cargados)',
    );

    // Marcar que los modelos ya fueron copiados
    await flagFile.writeAsString('1');
    print('[NativeEarMobile] 🏁 Modelos marcados como copiados');
  }

  Future<void> _copyAsset(String assetPath, String targetPath) async {
    try {
      final file = File(targetPath);
      if (await file.exists()) {
        print('[NativeEarMobile] ⏭️ Asset ya existe: $targetPath');
        return;
      }

      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();

      await file.writeAsBytes(bytes);
      print(
        '[NativeEarMobile] ✅ Copiado: $assetPath → $targetPath (${bytes.length} bytes)',
      );
    } catch (e) {
      print('[NativeEarMobile] ⚠️ Error copiando $assetPath: $e');
    }
  }

  // ============================================================================
  // REGISTRO
  // ============================================================================

  Future<Map<String, dynamic>> registerBiometric({
    required int identificadorUnico,
    required List<String> imagePaths,
  }) async {
    if (_orejaMobileRegistrar == null) {
      return {'success': false, 'error': 'Función no disponible'};
    }

    if (imagePaths.length != 5) {
      return {'success': false, 'error': 'Se requieren exactamente 5 imágenes'};
    }

    print('[NativeEarMobile] 📝 Registrando biometría...');
    print('[NativeEarMobile]    Usuario ID: $identificadorUnico');
    print('[NativeEarMobile]    Imágenes: ${imagePaths.length}');

    // Convertir array de strings a punteros
    final pathPointers = <ffi.Pointer<ffi.Char>>[];
    for (final path in imagePaths) {
      pathPointers.add(path.toNativeUtf8().cast());
    }

    final pathsArray = malloc<ffi.Pointer<ffi.Char>>(imagePaths.length);
    for (int i = 0; i < pathPointers.length; i++) {
      pathsArray[i] = pathPointers[i];
    }

    final resultBuffer = malloc<ffi.Char>(8192);

    try {
      final returnCode = _orejaMobileRegistrar!(
        identificadorUnico,
        pathsArray,
        imagePaths.length,
        resultBuffer.cast(),
        8192,
      );

      if (returnCode == 0) {
        final jsonStr = resultBuffer.cast<Utf8>().toDartString();
        final resultado = jsonDecode(jsonStr);

        print('[NativeEarMobile] ✅ Registro exitoso: $resultado');
        return resultado;
      } else {
        final error = getUltimoError();
        print('[NativeEarMobile] ❌ Error en registro: $error');
        return {'success': false, 'error': error};
      }
    } finally {
      for (final ptr in pathPointers) {
        malloc.free(ptr);
      }
      malloc.free(pathsArray);
      malloc.free(resultBuffer);
    }
  }

  // ============================================================================
  // AUTENTICACION
  // ============================================================================

  Future<Map<String, dynamic>> authenticate({
    required int identificadorClaimed,
    required String imagePath,
    double umbral = -1.0, // -1 = usar umbral del modelo
  }) async {
    if (_orejaMobileAutenticar == null) {
      return {'success': false, 'error': 'Función no disponible'};
    }

    print('[NativeEarMobile] 🔐 Autenticando...');
    print('[NativeEarMobile]    Usuario ID: $identificadorClaimed');
    print('[NativeEarMobile]    Imagen: $imagePath');
    print('[NativeEarMobile]    Umbral: $umbral');

    final imagePtr = imagePath.toNativeUtf8();
    final resultBuffer = malloc<ffi.Char>(8192);

    try {
      final returnCode = _orejaMobileAutenticar!(
        identificadorClaimed,
        imagePtr.cast(),
        umbral,
        resultBuffer.cast(),
        8192,
      );

      final jsonStr = resultBuffer.cast<Utf8>().toDartString();
      final resultado = jsonDecode(jsonStr);

      if (returnCode == 1) {
        print('[NativeEarMobile] ✅ Autenticado: $resultado');
      } else if (returnCode == 0) {
        print('[NativeEarMobile] ❌ Rechazado: $resultado');
      } else {
        print('[NativeEarMobile] ❌ Error: $resultado');
      }

      return resultado;
    } finally {
      malloc.free(imagePtr);
      malloc.free(resultBuffer);
    }
  }

  // ============================================================================
  // UTILIDADES
  // ============================================================================

  /// Recarga templates_k1.csv desde disco (después de un registro nuevo)
  Future<bool> reloadTemplates() async {
    if (_orejaMobileReloadTemplates == null) {
      print('[NativeEarMobile] ❌ Función reload_templates no disponible');
      return false;
    }

    try {
      print('[NativeEarMobile] 🔄 Recargando templates desde disco...');
      final result = _orejaMobileReloadTemplates!();

      if (result == 0) {
        print('[NativeEarMobile] ✅ Templates recargados correctamente');
        return true;
      } else {
        final error = getUltimoError();
        print('[NativeEarMobile] ❌ Error recargando templates: $error');
        return false;
      }
    } catch (e) {
      print('[NativeEarMobile] ❌ Excepción recargando templates: $e');
      return false;
    }
  }

  String getUltimoError() {
    if (_orejaMobileGetError == null) return 'Error desconocido';

    final buffer = malloc<ffi.Char>(1024);
    try {
      _orejaMobileGetError!(buffer.cast(), 1024);
      return buffer.cast<Utf8>().toDartString();
    } finally {
      malloc.free(buffer);
    }
  }

  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    if (_orejaMobileStats == null) {
      return {'error': 'Función no disponible'};
    }

    final buffer = malloc<ffi.Char>(4096);
    try {
      final result = _orejaMobileStats!(buffer.cast(), 4096);
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
  // SINCRONIZACION
  // ============================================================================

  /// Push: enviar vectores pendientes al servidor
  Future<Map<String, dynamic>> syncPush(String serverUrl) async {
    if (_orejaMobileSyncPush == null) {
      return {'ok': false, 'error': 'Función no disponible'};
    }

    print('[NativeEarMobile] 🔄 Sync Push → $serverUrl');

    final urlPtr = serverUrl.toNativeUtf8();
    final resultBuffer = malloc<ffi.Char>(8192);

    try {
      final returnCode = _orejaMobileSyncPush!(
        urlPtr.cast(),
        resultBuffer.cast(),
        8192,
      );

      if (returnCode == 0) {
        final jsonStr = resultBuffer.cast<Utf8>().toDartString();
        final resultado = jsonDecode(jsonStr);

        print('[NativeEarMobile] ✅ Sync Push OK: $resultado');
        return resultado;
      } else {
        final error = getUltimoError();
        print('[NativeEarMobile] ❌ Sync Push Error: $error');
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
    if (_orejaMobileSyncPull == null) {
      return {'ok': false, 'error': 'Función no disponible'};
    }

    print('[NativeEarMobile] 🔄 Sync Pull ← $serverUrl');

    final urlPtr = serverUrl.toNativeUtf8();
    final desdePtr = (desde ?? '').toNativeUtf8();
    final resultBuffer = malloc<ffi.Char>(16384);

    try {
      final returnCode = _orejaMobileSyncPull!(
        urlPtr.cast(),
        desdePtr.cast(),
        resultBuffer.cast(),
        16384,
      );

      if (returnCode == 0) {
        final jsonStr = resultBuffer.cast<Utf8>().toDartString();
        final resultado = jsonDecode(jsonStr);

        print('[NativeEarMobile] ✅ Sync Pull OK: $resultado');
        return resultado;
      } else {
        final error = getUltimoError();
        print('[NativeEarMobile] ❌ Sync Pull Error: $error');
        return {'ok': false, 'error': error};
      }
    } finally {
      malloc.free(urlPtr);
      malloc.free(desdePtr);
      malloc.free(resultBuffer);
    }
  }

  /// Pull modelo: descargar archivo del servidor (templates/modelo/umbral)
  Future<Map<String, dynamic>> syncModelo(
    String serverUrl,
    String archivo,
  ) async {
    if (_orejaMobileSyncModelo == null) {
      return {'ok': false, 'error': 'Función no disponible'};
    }

    print('[NativeEarMobile] 🔄 Sync Modelo ← $serverUrl ($archivo)');

    final urlPtr = serverUrl.toNativeUtf8();
    final archivoPtr = archivo.toNativeUtf8();
    final resultBuffer = malloc<ffi.Char>(4096);

    try {
      final returnCode = _orejaMobileSyncModelo!(
        urlPtr.cast(),
        archivoPtr.cast(),
        resultBuffer.cast(),
        4096,
      );

      if (returnCode == 0) {
        final jsonStr = resultBuffer.cast<Utf8>().toDartString();
        final resultado = jsonDecode(jsonStr);

        print('[NativeEarMobile] ✅ Modelo sincronizado: $resultado');
        return resultado;
      } else {
        final error = getUltimoError();
        print('[NativeEarMobile] ❌ Error sincronizando modelo: $error');
        return {'ok': false, 'error': error};
      }
    } finally {
      malloc.free(urlPtr);
      malloc.free(archivoPtr);
      malloc.free(resultBuffer);
    }
  }
}
