import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'svm_classifier_service.dart';
import 'native_voice_mobile_service.dart';

/// 🎤 Servicio Completo de Autenticación por Voz
///
/// Combina:
/// 1. Extracción de MFCC (libvoz_mobile.so vía FFI)
/// 2. Clasificación SVM (vectores preentrenados)
///
/// Flujo:
/// - Audio WAV → MFCC (250 dimensiones) → SVM → Predicción de usuario
class VoiceAuthCompleteService {
  static final VoiceAuthCompleteService _instance =
      VoiceAuthCompleteService._internal();
  factory VoiceAuthCompleteService() => _instance;
  VoiceAuthCompleteService._internal();

  final _nativeService = NativeVoiceMobileService();
  final _svmClassifier = SVMClassifierService();

  bool _isInitialized = false;

  /// Inicializar servicios nativos y SVM
  Future<void> initialize() async {
    if (_isInitialized) {
      print('[VoiceAuthComplete] ✅ Ya inicializado');
      return;
    }

    try {
      print('[VoiceAuthComplete] 🚀 Inicializando servicios...');

      // 1. Inicializar FFI nativo (MFCC)
      final nativeOk = await _nativeService.initialize();
      if (!nativeOk) {
        throw Exception('Error inicializando servicio nativo FFI');
      }

      // 2. Inicializar clasificador SVM
      await _svmClassifier.initialize();

      _isInitialized = true;
      print('[VoiceAuthComplete] ✅ Inicialización completa');
    } catch (e) {
      print('[VoiceAuthComplete] ❌ Error en inicialización: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// 🎯 AUTENTICACIÓN COMPLETA con audio WAV
  ///
  /// Pasos:
  /// 1. Guardar audio temporal en disco
  /// 2. Extraer MFCCs usando FFI nativa
  /// 3. Clasificar con SVM para obtener ID de usuario
  /// 4. Retornar resultado de autenticación
  ///
  /// Parámetros:
  /// - audioBytes: Audio WAV (16kHz, mono, 16-bit)
  /// - expectedUserId: ID del usuario que se espera autenticar (opcional)
  ///
  /// Retorna:
  /// - Map con: authenticated, predicted_user_id, similarity, mfcc_extracted
  Future<Map<String, dynamic>> authenticate({
    required Uint8List audioBytes,
    int? expectedUserId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      print('[VoiceAuthComplete] 🎤 Iniciando autenticación por voz...');
      print('[VoiceAuthComplete] 📊 Tamaño audio: ${audioBytes.length} bytes');

      // PASO 1: Guardar audio temporal
      final audioPath = await _saveAudioToTemp(audioBytes);
      print('[VoiceAuthComplete] 💾 Audio guardado en: $audioPath');

      // PASO 2: Extraer MFCCs usando librería nativa
      final mfccVector = await _extractMFCC(audioPath);
      if (mfccVector == null) {
        throw Exception('Error extrayendo características MFCC');
      }
      print(
        '[VoiceAuthComplete] ✅ MFCCs extraídos: ${mfccVector.length} dimensiones',
      );

      // PASO 3: Clasificar con SVM
      final svmResult = await _svmClassifier.predict(mfccVector);
      final predictedUserId = svmResult['user_id'] as int?;
      final similarity = svmResult['similarity'] as double;
      final isAuthenticated = svmResult['is_authenticated'] as bool;

      // PASO 4: Validar contra usuario esperado (si se proporcionó)
      bool finalAuthenticated = isAuthenticated;
      if (expectedUserId != null && predictedUserId != null) {
        finalAuthenticated =
            isAuthenticated && (predictedUserId == expectedUserId);

        if (predictedUserId != expectedUserId) {
          print(
            '[VoiceAuthComplete] ⚠️ Usuario predicho ($predictedUserId) != esperado ($expectedUserId)',
          );
        }
      }

      final result = {
        'authenticated': finalAuthenticated,
        'predicted_user_id': predictedUserId,
        'expected_user_id': expectedUserId,
        'similarity': similarity,
        'threshold': SVMClassifierService.SIMILARITY_THRESHOLD,
        'mfcc_extracted': true,
        'mfcc_dimension': mfccVector.length,
        'num_classes_compared': svmResult['num_classes_compared'],
      };

      print('[VoiceAuthComplete] 🎯 Resultado:');
      print('   - Autenticado: ${finalAuthenticated ? "✅ SÍ" : "❌ NO"}');
      print('   - Usuario predicho: $predictedUserId');
      print('   - Similitud: ${(similarity * 100).toStringAsFixed(2)}%');

      // Limpiar archivo temporal
      await File(audioPath).delete();

      return result;
    } catch (e) {
      print('[VoiceAuthComplete] ❌ Error en autenticación: $e');
      rethrow;
    }
  }

  /// 📝 REGISTRAR nuevo vector biométrico
  ///
  /// Extrae MFCCs y los almacena para futuro entrenamiento del SVM
  /// (En modo offline, este método solo extrae características)
  Future<Map<String, dynamic>> registerBiometric({
    required String identificador,
    required Uint8List audioBytes,
    int? idFrase,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      print('[VoiceAuthComplete] 📝 Registrando biometría de voz...');
      print('[VoiceAuthComplete] 👤 Usuario: $identificador');

      // PASO 1: Guardar audio temporal
      final audioPath = await _saveAudioToTemp(audioBytes);

      // PASO 2: Extraer MFCCs
      final mfccVector = await _extractMFCC(audioPath);
      if (mfccVector == null) {
        throw Exception('Error extrayendo características MFCC');
      }

      print(
        '[VoiceAuthComplete] ✅ MFCCs extraídos: ${mfccVector.length} dimensiones',
      );

      // PASO 3: Usar servicio nativo para registrar
      final resultado = await _nativeService.registerBiometric(
        identificador: identificador,
        audioPath: audioPath,
        idFrase: idFrase ?? 1,
      );

      // Limpiar archivo temporal
      await File(audioPath).delete();

      return {
        'success': true,
        'identificador': identificador,
        'mfcc_dimension': mfccVector.length,
        'native_result': resultado,
      };
    } catch (e) {
      print('[VoiceAuthComplete] ❌ Error en registro: $e');
      rethrow;
    }
  }

  /// Extraer vector MFCC de un archivo de audio
  Future<Float32List?> _extractMFCC(String audioPath) async {
    // Aquí deberías llamar a la función FFI que extrae MFCCs
    // Por ahora, usamos un método placeholder

    // TODO: Implementar llamada FFI real
    // Ejemplo: return _nativeService.extractMFCCFromFile(audioPath);

    // PLACEHOLDER: Generar vector de prueba
    print(
      '[VoiceAuthComplete] ⚠️ USANDO MFCC PLACEHOLDER - Implementar extracción real',
    );
    return Float32List(250); // Vector vacío de 250 dimensiones
  }

  /// Guardar audio en archivo temporal
  Future<String> _saveAudioToTemp(Uint8List audioBytes) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final audioPath = '${tempDir.path}/voice_auth_$timestamp.wav';

    final file = File(audioPath);
    await file.writeAsBytes(audioBytes);

    return audioPath;
  }

  /// Obtener estadísticas de ambos servicios
  Map<String, dynamic> getStats() {
    return {
      'is_initialized': _isInitialized,
      'native_service': _nativeService.getVersion(),
      'svm_classifier': _svmClassifier.getStats(),
    };
  }

  /// Liberar recursos
  void dispose() {
    _nativeService.cleanup();
    _svmClassifier.dispose();
    _isInitialized = false;
    print('[VoiceAuthComplete] 🗑️ Recursos liberados');
  }
}
