import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:convert';

/// 🧠 Servicio de Clasificación SVM para Biometría de Voz
///
/// Carga y utiliza los modelos SVM preentrenados (67 clases) para
/// autenticación por voz basada en características MFCC.
///
/// Arquitectura:
/// - 67 archivos binarios (class_*.bin) = vectores de soporte SVM
/// - metadata.json = configuración (dimension=250, num_classes=67)
/// - Clasificación por similitud coseno entre MFCCs
class SVMClassifierService {
  static final SVMClassifierService _instance =
      SVMClassifierService._internal();
  factory SVMClassifierService() => _instance;
  SVMClassifierService._internal();

  // Estado del clasificador
  bool _isInitialized = false;
  Map<int, Float32List>? _svmVectors; // userID -> vector de soporte
  Map<String, dynamic>? _metadata;

  // Parámetros del modelo
  static const String MODEL_VERSION = 'v1';
  static const int EXPECTED_MFCC_DIMENSION = 250; // Según metadata.json
  static const double SIMILARITY_THRESHOLD = 0.75; // Umbral de similitud coseno

  /// Inicializar el clasificador SVM
  /// Carga los 67 archivos class_*.bin y metadata.json desde assets
  Future<void> initialize() async {
    if (_isInitialized) {
      print('[SVMClassifier] ✅ Ya inicializado');
      return;
    }

    try {
      print('[SVMClassifier] 🚀 Iniciando carga de modelos SVM...');

      // 1. Cargar metadata.json
      await _loadMetadata();

      // 2. Cargar los 67 vectores de clase
      await _loadSVMVectors();

      _isInitialized = true;
      print('[SVMClassifier] ✅ Inicialización completa');
      print('[SVMClassifier] 📊 Clases cargadas: ${_svmVectors!.length}');
      print('[SVMClassifier] 📐 Dimensión MFCC: ${_metadata!['dimension']}');
    } catch (e) {
      print('[SVMClassifier] ❌ Error en inicialización: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Cargar metadata.json del modelo
  Future<void> _loadMetadata() async {
    try {
      final metadataPath =
          'lib/config/entrega_flutter_mobile/assets/models/$MODEL_VERSION/metadata.json';
      final jsonString = await rootBundle.loadString(metadataPath);
      _metadata = json.decode(jsonString);

      print('[SVMClassifier] 📋 Metadata cargada:');
      print('   - Clases: ${_metadata!['num_classes']}');
      print('   - Dimensión: ${_metadata!['dimension']}');
      print(
        '   - IDs de usuario: ${(_metadata!['classes'] as List).take(5).join(", ")}...',
      );
    } catch (e) {
      throw Exception('Error cargando metadata.json: $e');
    }
  }

  /// Cargar todos los vectores SVM desde archivos binarios
  Future<void> _loadSVMVectors() async {
    _svmVectors = {};

    final classes = _metadata!['classes'] as List<dynamic>;
    final dimension = _metadata!['dimension'] as int;

    int loaded = 0;
    int failed = 0;

    for (final classId in classes) {
      try {
        final vector = await _loadClassVector(classId, dimension);
        _svmVectors![classId as int] = vector;
        loaded++;
      } catch (e) {
        print('[SVMClassifier] ⚠️ No se pudo cargar class_$classId.bin: $e');
        failed++;
      }
    }

    print('[SVMClassifier] 📦 Vectores cargados: $loaded OK, $failed errores');

    if (loaded == 0) {
      throw Exception('No se pudo cargar ningún vector SVM');
    }
  }

  /// Cargar un archivo class_*.bin individual
  Future<Float32List> _loadClassVector(int classId, int expectedDim) async {
    final classPath =
        'lib/config/entrega_flutter_mobile/assets/models/$MODEL_VERSION/class_$classId.bin';

    final byteData = await rootBundle.load(classPath);
    final buffer = byteData.buffer;

    // Convertir bytes a Float32List
    final floatList = Float32List.view(buffer);

    if (floatList.length != expectedDim) {
      throw Exception(
        'Dimensión incorrecta en class_$classId.bin: '
        'esperado $expectedDim, obtenido ${floatList.length}',
      );
    }

    return floatList;
  }

  /// 🎯 Predecir la clase (usuario) dado un vector MFCC
  ///
  /// Parámetros:
  /// - mfccVector: Vector de características MFCC (debe tener dimension=250)
  ///
  /// Retorna:
  /// - Map con: userId, similarity, isAuthenticated
  Future<Map<String, dynamic>> predict(Float32List mfccVector) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Validar dimensión
    if (mfccVector.length != EXPECTED_MFCC_DIMENSION) {
      throw Exception(
        'Dimensión MFCC incorrecta: esperado $EXPECTED_MFCC_DIMENSION, '
        'obtenido ${mfccVector.length}',
      );
    }

    print('[SVMClassifier] 🔍 Buscando mejor coincidencia...');

    // Encontrar la clase con mayor similitud
    int? bestUserId;
    double bestSimilarity = -1.0;

    for (final entry in _svmVectors!.entries) {
      final userId = entry.key;
      final svmVector = entry.value;

      final similarity = _cosineSimilarity(mfccVector, svmVector);

      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestUserId = userId;
      }
    }

    final isAuthenticated = bestSimilarity >= SIMILARITY_THRESHOLD;

    print('[SVMClassifier] 🎯 Mejor coincidencia:');
    print('   - Usuario ID: $bestUserId');
    print('   - Similitud: ${(bestSimilarity * 100).toStringAsFixed(2)}%');
    print('   - Umbral: ${(SIMILARITY_THRESHOLD * 100).toStringAsFixed(0)}%');
    print('   - Autenticado: ${isAuthenticated ? "✅ SÍ" : "❌ NO"}');

    return {
      'user_id': bestUserId,
      'similarity': bestSimilarity,
      'is_authenticated': isAuthenticated,
      'threshold': SIMILARITY_THRESHOLD,
      'num_classes_compared': _svmVectors!.length,
    };
  }

  /// Calcular similitud coseno entre dos vectores
  ///
  /// Rango: [-1, 1]
  /// - 1 = vectores idénticos
  /// - 0 = vectores ortogonales
  /// - -1 = vectores opuestos
  double _cosineSimilarity(Float32List vec1, Float32List vec2) {
    if (vec1.length != vec2.length) {
      throw ArgumentError('Los vectores deben tener la misma dimensión');
    }

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < vec1.length; i++) {
      dotProduct += vec1[i] * vec2[i];
      norm1 += vec1[i] * vec1[i];
      norm2 += vec2[i] * vec2[i];
    }

    norm1 = norm1 == 0 ? 1.0 : norm1; // Evitar división por cero
    norm2 = norm2 == 0 ? 1.0 : norm2;

    final similarity = dotProduct / (sqrt(norm1) * sqrt(norm2));
    return similarity;
  }

  /// Raíz cuadrada personalizada
  double sqrt(double x) {
    if (x <= 0) return 0;

    double guess = x / 2;
    double epsilon = 0.00001;

    while ((guess * guess - x).abs() > epsilon) {
      guess = (guess + x / guess) / 2;
    }

    return guess;
  }

  /// 🔄 Obtener estadísticas del clasificador
  Map<String, dynamic> getStats() {
    return {
      'is_initialized': _isInitialized,
      'num_classes': _svmVectors?.length ?? 0,
      'mfcc_dimension': _metadata?['dimension'] ?? 0,
      'threshold': SIMILARITY_THRESHOLD,
      'model_version': MODEL_VERSION,
    };
  }

  /// 🗑️ Liberar recursos
  void dispose() {
    _svmVectors?.clear();
    _svmVectors = null;
    _metadata = null;
    _isInitialized = false;
    print('[SVMClassifier] 🗑️ Recursos liberados');
  }
}
