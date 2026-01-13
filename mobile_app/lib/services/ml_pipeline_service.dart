import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'dart:math' as math;

/// Servicio de Pipeline de Machine Learning
/// Maneja: preprocesamiento, extracción de características, normalización, clasificación
class MLPipelineService {
  static final MLPipelineService _instance = MLPipelineService._internal();
  factory MLPipelineService() => _instance;
  MLPipelineService._internal();

  // =====================================================
  // PREPROCESAMIENTO DE IMÁGENES (OREJA)
  // =====================================================

  /// Preprocesar imagen de oreja para el modelo TFLite y backend
  /// Pasos:
  /// 1. Redimensionar a 224x224 (tamaño del modelo)
  /// 2. Convertir a RGB
  /// 3. Normalizar píxeles [0, 1]
  /// 4. Aplicar ecualización de histograma (mejorar contraste)
  Future<Uint8List> preprocessEarImage(Uint8List imageBytes) async {
    try {
      print('[MLPipeline] 🖼️ Iniciando preprocesamiento de oreja...');

      // Decodificar imagen
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('No se pudo decodificar la imagen');
      }

      // 1. Redimensionar a 224x224
      image = img.copyResize(
        image,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );
      print('[MLPipeline]   ✓ Redimensionado a 224x224');

      // 2. Convertir a RGB (eliminar canal alpha si existe)
      // La librería image maneja esto automáticamente
      print('[MLPipeline]   ✓ Convertido a RGB');

      // 3. Ecualización de histograma (mejorar contraste)
      image = _equalizeHistogram(image);
      print('[MLPipeline]   ✓ Histograma ecualizado');

      // 4. Normalización se hace en el modelo TFLite
      // pero aquí podemos aplicar filtros adicionales

      // Reducir ruido con filtro gaussiano suave
      image = _applyGaussianBlur(image, radius: 1);
      print('[MLPipeline]   ✓ Ruido reducido');

      // Codificar de vuelta a bytes
      final processedBytes = img.encodePng(image);
      print('[MLPipeline] ✅ Preprocesamiento completado');

      return Uint8List.fromList(processedBytes);
    } catch (e) {
      print('[MLPipeline] ❌ Error en preprocesamiento: $e');
      rethrow;
    }
  }

  /// Ecualizar histograma para mejorar contraste
  img.Image _equalizeHistogram(img.Image image) {
    // Calcular histograma
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final gray = ((pixel.r.toInt() + pixel.g.toInt() + pixel.b.toInt()) / 3)
            .round();
        histogram[gray]++;
      }
    }

    // Calcular distribución acumulativa
    final cdf = List<int>.filled(256, 0);
    cdf[0] = histogram[0];
    for (int i = 1; i < 256; i++) {
      cdf[i] = cdf[i - 1] + histogram[i];
    }

    // Normalizar CDF
    final totalPixels = image.width * image.height;
    final scale = 255.0 / totalPixels;

    // Aplicar transformación
    final equalized = img.Image.from(image);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final gray = ((pixel.r.toInt() + pixel.g.toInt() + pixel.b.toInt()) / 3)
            .round();
        final newValue = (cdf[gray] * scale).round().clamp(0, 255);

        equalized.setPixelRgb(x, y, newValue, newValue, newValue);
      }
    }

    return equalized;
  }

  /// Aplicar desenfoque gaussiano para reducir ruido
  img.Image _applyGaussianBlur(img.Image image, {int radius = 2}) {
    return img.gaussianBlur(image, radius: radius);
  }

  /// Extraer características de imagen (para análisis adicional)
  Map<String, dynamic> extractImageFeatures(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return {};

      // Extraer características básicas
      final features = <String, dynamic>{
        'width': image.width,
        'height': image.height,
        'aspect_ratio': image.width / image.height,
        'num_channels': image.numChannels,
        'brightness': _calculateAverageBrightness(image),
        'contrast': _calculateContrast(image),
        'sharpness': _calculateSharpness(image),
      };

      return features;
    } catch (e) {
      print('[MLPipeline] ⚠️ Error extrayendo características: $e');
      return {};
    }
  }

  double _calculateAverageBrightness(img.Image image) {
    double sum = 0;
    int count = 0;

    for (int y = 0; y < image.height; y += 5) {
      for (int x = 0; x < image.width; x += 5) {
        final pixel = image.getPixel(x, y);
        sum += (pixel.r + pixel.g + pixel.b) / 3;
        count++;
      }
    }

    return count > 0 ? sum / count : 0;
  }

  double _calculateContrast(img.Image image) {
    final pixels = <double>[];

    for (int y = 0; y < image.height; y += 5) {
      for (int x = 0; x < image.width; x += 5) {
        final pixel = image.getPixel(x, y);
        pixels.add((pixel.r + pixel.g + pixel.b) / 3);
      }
    }

    if (pixels.isEmpty) return 0;

    final mean = pixels.reduce((a, b) => a + b) / pixels.length;
    final variance =
        pixels.map((p) => math.pow(p - mean, 2)).reduce((a, b) => a + b) /
        pixels.length;

    return math.sqrt(variance);
  }

  double _calculateSharpness(img.Image image) {
    // Implementación simplificada de detección de bordes (Sobel)
    double sharpness = 0;
    int count = 0;

    for (int y = 1; y < image.height - 1; y += 3) {
      for (int x = 1; x < image.width - 1; x += 3) {
        final center = image.getPixel(x, y);
        final right = image.getPixel(x + 1, y);
        final bottom = image.getPixel(x, y + 1);

        final centerGray = (center.r + center.g + center.b) / 3;
        final rightGray = (right.r + right.g + right.b) / 3;
        final bottomGray = (bottom.r + bottom.g + bottom.b) / 3;

        final dx = (rightGray - centerGray).abs();
        final dy = (bottomGray - centerGray).abs();

        sharpness += math.sqrt(dx * dx + dy * dy);
        count++;
      }
    }

    return count > 0 ? sharpness / count : 0;
  }

  // =====================================================
  // PREPROCESAMIENTO DE AUDIO (VOZ)
  // =====================================================

  /// Preprocesar audio de voz para el modelo
  /// Pasos:
  /// 1. Verificar formato WAV 16kHz mono
  /// 2. Normalizar amplitud
  /// 3. Aplicar filtro de ruido
  /// 4. Extraer características (MFCC en backend)
  Future<Uint8List> preprocessVoiceAudio(Uint8List audioBytes) async {
    try {
      print('[MLPipeline] 🎤 Iniciando preprocesamiento de voz...');

      // Verificar encabezado WAV
      if (audioBytes.length < 44) {
        throw Exception('Audio demasiado corto o formato inválido');
      }

      // Leer encabezado WAV
      final riff = String.fromCharCodes(audioBytes.sublist(0, 4));
      final wave = String.fromCharCodes(audioBytes.sublist(8, 12));

      if (riff != 'RIFF' || wave != 'WAVE') {
        throw Exception('Formato de audio no es WAV válido');
      }
      print('[MLPipeline]   ✓ Formato WAV verificado');

      // TODO: Normalizar amplitud si es necesario
      // TODO: Aplicar filtro paso-alto para eliminar ruido de baja frecuencia

      // Por ahora retornamos el audio original
      // El procesamiento avanzado (MFCC, espectrogramas) se hace en el backend

      print('[MLPipeline] ✅ Preprocesamiento de voz completado');
      return audioBytes;
    } catch (e) {
      print('[MLPipeline] ❌ Error en preprocesamiento de voz: $e');
      rethrow;
    }
  }

  /// Extraer características básicas de audio
  Map<String, dynamic> extractAudioFeatures(Uint8List audioBytes) {
    try {
      if (audioBytes.length < 44) {
        return {'error': 'Audio inválido'};
      }

      // Leer encabezado WAV
      final sampleRate = _readInt32(audioBytes, 24);
      final numChannels = _readInt16(audioBytes, 22);
      final bitsPerSample = _readInt16(audioBytes, 34);
      final dataSize = audioBytes.length - 44;

      final durationSeconds =
          dataSize / (sampleRate * numChannels * (bitsPerSample / 8));

      return {
        'sample_rate': sampleRate,
        'num_channels': numChannels,
        'bits_per_sample': bitsPerSample,
        'duration_seconds': durationSeconds,
        'file_size_bytes': audioBytes.length,
        'is_valid_format': sampleRate == 16000 && numChannels == 1,
      };
    } catch (e) {
      print('[MLPipeline] ⚠️ Error extrayendo características de audio: $e');
      return {'error': e.toString()};
    }
  }

  int _readInt16(Uint8List bytes, int offset) {
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  int _readInt32(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  // =====================================================
  // NORMALIZACIÓN
  // =====================================================

  /// Normalizar valores de píxeles a rango [0, 1]
  List<double> normalizePixels(Uint8List imageBytes) {
    return imageBytes.map((byte) => byte / 255.0).toList();
  }

  /// Normalizar valores de audio a rango [-1, 1]
  List<double> normalizeAudioSamples(List<int> samples, int bitsPerSample) {
    final maxValue = math.pow(2, bitsPerSample - 1);
    return samples.map((sample) => sample / maxValue).toList();
  }

  // =====================================================
  // CLASIFICACIÓN (HELPERS)
  // =====================================================

  /// Aplicar softmax a logits de salida del modelo
  List<double> softmax(List<double> logits) {
    final maxLogit = logits.reduce(math.max);
    final exps = logits.map((x) => math.exp(x - maxLogit)).toList();
    final sumExps = exps.reduce((a, b) => a + b);
    return exps.map((x) => x / sumExps).toList();
  }

  /// Obtener clase predicha y confianza
  Map<String, dynamic> getTopPrediction(
    List<double> probabilities,
    List<String> classNames,
  ) {
    if (probabilities.isEmpty || classNames.isEmpty) {
      return {'class': 'unknown', 'confidence': 0.0};
    }

    double maxProb = probabilities[0];
    int maxIndex = 0;

    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        maxIndex = i;
      }
    }

    return {
      'class': classNames[maxIndex],
      'confidence': maxProb,
      'all_probabilities': Map.fromIterables(classNames, probabilities),
    };
  }

  // =====================================================
  // VALIDACIÓN DE CALIDAD
  // =====================================================

  /// Validar calidad de imagen de oreja
  Map<String, dynamic> validateEarImageQuality(Uint8List imageBytes) {
    try {
      final features = extractImageFeatures(imageBytes);

      final brightness = features['brightness'] ?? 0;
      final contrast = features['contrast'] ?? 0;
      final sharpness = features['sharpness'] ?? 0;

      // Criterios de calidad
      final isValid =
          brightness >= 50 &&
          brightness <= 200 &&
          contrast >= 20 &&
          sharpness >= 5;

      return {
        'is_valid': isValid,
        'brightness': brightness,
        'contrast': contrast,
        'sharpness': sharpness,
        'issues': _getQualityIssues(brightness, contrast, sharpness),
      };
    } catch (e) {
      return {'is_valid': false, 'error': e.toString()};
    }
  }

  List<String> _getQualityIssues(
    double brightness,
    double contrast,
    double sharpness,
  ) {
    final issues = <String>[];

    if (brightness < 50) issues.add('Imagen muy oscura');
    if (brightness > 200) issues.add('Imagen sobreexpuesta');
    if (contrast < 20) issues.add('Contraste insuficiente');
    if (sharpness < 5) issues.add('Imagen borrosa');

    return issues;
  }

  /// Validar calidad de audio de voz
  Map<String, dynamic> validateVoiceAudioQuality(Uint8List audioBytes) {
    try {
      final features = extractAudioFeatures(audioBytes);

      final sampleRate = features['sample_rate'] ?? 0;
      final numChannels = features['num_channels'] ?? 0;
      final duration = features['duration_seconds'] ?? 0.0;

      final isValid =
          sampleRate == 16000 && numChannels == 1 && duration >= 5.0;

      return {
        'is_valid': isValid,
        'sample_rate': sampleRate,
        'num_channels': numChannels,
        'duration': duration,
        'issues': _getAudioQualityIssues(sampleRate, numChannels, duration),
      };
    } catch (e) {
      return {'is_valid': false, 'error': e.toString()};
    }
  }

  List<String> _getAudioQualityIssues(
    int sampleRate,
    int channels,
    double duration,
  ) {
    final issues = <String>[];

    if (sampleRate != 16000) issues.add('Sample rate debe ser 16kHz');
    if (channels != 1) issues.add('Audio debe ser mono');
    if (duration < 5.0) issues.add('Duración mínima 5 segundos');

    return issues;
  }
}
