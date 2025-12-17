import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

/// Servicio para validar que una imagen sea realmente una oreja usando TensorFlow Lite
class EarValidatorService {
  static final EarValidatorService _instance = EarValidatorService._internal();
  factory EarValidatorService() => _instance;
  EarValidatorService._internal();

  Interpreter? _interpreter;
  bool _isInitialized = false;

  // Configuración del modelo (ajustar según tu modelo)
  static const int _inputWidth = 224;
  static const int _inputHeight = 224;
  static const int _numChannels = 3;
  static const double _confidenceThreshold = 0.7; // 70% de confianza mínima

  /// Inicializar el intérprete de TensorFlow Lite
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Cargar el modelo desde assets
      _interpreter = await Interpreter.fromAsset(
        'assets/models/modelo_oreja.tflite',
      );

      // Verificar dimensiones del modelo
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      print('[EarValidator] 🧠 Modelo cargado exitosamente');
      print('[EarValidator] 📐 Input shape: $inputShape');
      print('[EarValidator] 📐 Output shape: $outputShape');

      _isInitialized = true;
    } catch (e) {
      print('[EarValidator] ❌ Error cargando modelo: $e');
      rethrow;
    }
  }

  /// Validar si una imagen es una oreja
  /// Retorna true si es una oreja con suficiente confianza
  Future<EarDetectionResult> validateEar(Uint8List imageBytes) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // 1. Decodificar imagen
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        return EarDetectionResult(
          isEar: false,
          confidence: 0.0,
          error: 'No se pudo decodificar la imagen',
        );
      }

      // 2. Redimensionar imagen a las dimensiones esperadas por el modelo
      img.Image resized = img.copyResize(
        image,
        width: _inputWidth,
        height: _inputHeight,
      );

      // 3. Convertir imagen a tensor (normalizado 0-1)
      var input = _imageToTensor(resized);

      // 4. Preparar output (asumiendo clasificación binaria: [no_oreja, oreja])
      var output = List.filled(1 * 2, 0.0).reshape([1, 2]);

      // 5. Ejecutar inferencia
      _interpreter!.run(input, output);

      // 6. Obtener probabilidad de que sea una oreja (índice 1)
      double earProbability = output[0][1];
      bool isEar = earProbability >= _confidenceThreshold;

      print(
        '[EarValidator] 🎯 Resultado: ${isEar ? "ES OREJA" : "NO ES OREJA"}',
      );
      print(
        '[EarValidator] 📊 Confianza: ${(earProbability * 100).toStringAsFixed(2)}%',
      );

      return EarDetectionResult(
        isEar: isEar,
        confidence: earProbability,
        error: null,
      );
    } catch (e) {
      print('[EarValidator] ❌ Error en validación: $e');
      return EarDetectionResult(
        isEar: false,
        confidence: 0.0,
        error: 'Error al validar imagen: $e',
      );
    }
  }

  /// Convertir imagen a tensor normalizado
  List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    var tensor = List.generate(
      1,
      (b) => List.generate(
        _inputHeight,
        (y) => List.generate(
          _inputWidth,
          (x) => List.generate(_numChannels, (c) {
            var pixel = image.getPixel(x, y);

            // Extraer canal según el índice
            double value;
            if (c == 0) {
              value = pixel.r.toDouble(); // Red
            } else if (c == 1) {
              value = pixel.g.toDouble(); // Green
            } else {
              value = pixel.b.toDouble(); // Blue
            }

            // Normalizar a rango 0-1
            return value / 255.0;
          }),
        ),
      ),
    );
    return tensor;
  }

  /// Liberar recursos
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    print('[EarValidator] 🗑️ Recursos liberados');
  }
}

/// Resultado de la validación de oreja
class EarDetectionResult {
  final bool isEar;
  final double confidence;
  final String? error;

  EarDetectionResult({
    required this.isEar,
    required this.confidence,
    this.error,
  });

  String get confidencePercentage =>
      '${(confidence * 100).toStringAsFixed(1)}%';

  bool get isValid => isEar && error == null;
}
