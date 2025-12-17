import 'dart:async';
import 'dart:typed_data';

// Servicio de autenticación biométrica
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();

  factory BiometricService() {
    return _instance;
  }

  BiometricService._internal();

  // Umbrales de confianza configurables (BALANCE ÓPTIMO)
  // IMPORTANTE: Punto medio entre seguridad y usabilidad
  static const double CONFIDENCE_THRESHOLD_VOICE = 0.68; // Balance para voz
  static const double CONFIDENCE_THRESHOLD_FACE =
      0.70; // BALANCE para oreja (72% similitud)
  static const double CONFIDENCE_THRESHOLD_PALM = 0.70; // Balance para palma

  final _biometricStatusStream = StreamController<BiometricStatus>.broadcast();
  Stream<BiometricStatus> get biometricStatus => _biometricStatusStream.stream;

  // =============== VALIDACIÓN DE VOZ ===============

  /// Capturar y procesar audio para validación de voz
  Future<VoiceValidationResult> validateVoice({
    required Uint8List audioData,
    required String targetPhrase,
    required Uint8List templateData,
  }) async {
    try {
      _emitStatus(BiometricStatus.processing);

      // Extraer características del audio capturado
      final capturedFeatures = _extractAudioFeatures(audioData);

      // Cargar template de referencia
      final referenceFeatures = _extractAudioFeatures(templateData);

      // Comparar características
      final similarity = _compareAudioFeatures(
        capturedFeatures,
        referenceFeatures,
      );

      final isValid = similarity >= CONFIDENCE_THRESHOLD_VOICE;

      _emitStatus(BiometricStatus.complete);

      return VoiceValidationResult(
        isValid: isValid,
        confidence: similarity,
        duration: audioData.length ~/ 16000, // Asumiendo 16kHz
        processingTime: Duration(milliseconds: 500),
      );
    } catch (error) {
      _emitStatus(BiometricStatus.error);
      throw BiometricException('Error en validación de voz: $error');
    }
  }

  // Extraer características de audio (MFCC simplificado)
  List<double> _extractAudioFeatures(Uint8List audioData) {
    // En producción usar librerías como TensorFlow Lite o DeepSpeech
    // Por ahora simulamos extracción básica
    final List<double> features = [];

    // Implementación simplificada de MFCC
    for (int i = 0; i < 13; i++) {
      double feature = 0.0;
      for (int j = 0; j < audioData.length; j++) {
        feature +=
            (audioData[j] * Math.cos(2 * Math.pi * i * j / audioData.length));
      }
      features.add(feature / audioData.length);
    }

    return features;
  }

  // Comparar características de audio (CON NORMALIZACIÓN)
  double _compareAudioFeatures(List<double> features1, List<double> features2) {
    if (features1.length != features2.length) {
      return 0.0;
    }

    // MEJORA: Normalizar características (Z-score normalization)
    // Esto evita que diferencias de volumen arruinen la comparación
    final norm1 = _normalizeFeatures(features1);
    final norm2 = _normalizeFeatures(features2);

    // Comparar características normalizadas
    double sumSquaredDiff = 0.0;
    for (int i = 0; i < norm1.length; i++) {
      final diff = norm1[i] - norm2[i];
      sumSquaredDiff += diff * diff;
    }

    // Convertir distancia euclidiana a similitud (0-1)
    final distance = Math.sqrt(sumSquaredDiff);
    final similarity = 1.0 / (1.0 + distance);

    // DEBUG: Mostrar similitud calculada
    print('[BiometricService] Audio similarity: $similarity');

    return similarity;
  }

  /// Normalizar características usando Z-score normalization
  /// Evita que escala diferente (volumen diferente) arruine la comparación
  List<double> _normalizeFeatures(List<double> features) {
    if (features.isEmpty) return features;

    // Calcular media
    final mean = features.reduce((a, b) => a + b) / features.length;

    // Calcular desviación estándar
    final variance =
        features.fold(0.0, (sum, f) => sum + (f - mean) * (f - mean)) /
        features.length;
    final stdDev = Math.sqrt(variance);

    // Aplicar Z-score: (x - media) / desv_est
    // Esto convierte los datos a media=0, std_dev=1
    return features
        .map(
          (f) => (f - mean) / (stdDev + 1e-8),
        ) // +1e-8 evita división por cero
        .toList();
  }

  // =============== VALIDACIÓN DE OREJA ===============

  /// Capturar y procesar imagen de oreja para validación
  Future<EarValidationResult> validateEar({
    required Uint8List imageData,
    required Uint8List templateData,
  }) async {
    try {
      _emitStatus(BiometricStatus.processing);

      // Detectar oreja en la imagen
      final earDetected = await _detectEar(imageData);
      if (!earDetected) {
        return EarValidationResult(
          isValid: false,
          confidence: 0.0,
          errorMessage: 'No se detectó oreja en la imagen',
        );
      }

      // Extraer características de la oreja
      final earFeatures = await _extractEarFeatures(imageData);
      final templateFeatures = await _extractEarFeatures(templateData);

      // Comparar características
      final similarity = _compareImageFeatures(earFeatures, templateFeatures);

      final isValid = similarity >= CONFIDENCE_THRESHOLD_FACE;

      // DEBUG: Mostrar comparación detallada
      print('[BiometricService] ===== VALIDACIÓN DE OREJA =====');
      print('[BiometricService] Features extraídas: ${earFeatures.length}');
      print(
        '[BiometricService] Similitud calculada: ${similarity.toStringAsFixed(4)}',
      );
      print(
        '[BiometricService] Threshold requerido: $CONFIDENCE_THRESHOLD_FACE',
      );
      print(
        '[BiometricService] Resultado: ${isValid ? "✅ VÁLIDO" : "❌ RECHAZADO"}',
      );
      print('[BiometricService] =====================================');

      _emitStatus(BiometricStatus.complete);

      return EarValidationResult(
        isValid: isValid,
        confidence: similarity,
        qualityScore: _assessImageQuality(imageData),
        processingTime: Duration(milliseconds: 800),
      );
    } catch (error) {
      _emitStatus(BiometricStatus.error);
      throw BiometricException('Error en validación de oreja: $error');
    }
  }

  Future<bool> _detectEar(Uint8List imageData) async {
    // Validación básica: verificar que la imagen tenga contenido
    if (imageData.length < 1000) {
      return false;
    }

    // TODO: En producción implementar detección real con TensorFlow Lite
    // Por ahora hacemos validación básica de contenido
    await Future.delayed(Duration(milliseconds: 100));
    return true;
  }

  Future<List<double>> _extractEarFeatures(Uint8List imageData) async {
    // Algoritmo BALANCEADO - punto medio entre simple y robusto
    // Suficientes características para diferenciar, pero tolerante a variaciones

    final List<double> features = [];

    // 1. ANÁLISIS DE REGIONES (grid 5x5 - balance)
    final regionSize = 768; // Regiones medianas
    final regionsPerSide = 5; // Grid de 5x5 = 25 regiones
    final totalRegions = regionsPerSide * regionsPerSide;

    for (
      int region = 0;
      region < totalRegions && region * regionSize < imageData.length;
      region++
    ) {
      final start = region * regionSize;
      final end = (start + regionSize).clamp(0, imageData.length);

      // Calcular media Y varianza (más discriminante)
      double regionMean = 0;
      for (int i = start; i < end; i++) {
        regionMean += imageData[i];
      }
      regionMean /= (end - start);

      double regionVariance = 0;
      for (int i = start; i < end; i++) {
        final diff = imageData[i] - regionMean;
        regionVariance += diff * diff;
      }
      regionVariance /= (end - start);

      features.add(regionMean / 255.0);
      features.add(Math.sqrt(regionVariance) / 255.0); // Desviación estándar
    }

    // 2. HISTOGRAMA DETALLADO (12 bins - más discriminante)
    final histogramBins = 12;
    final histogram = List<int>.filled(histogramBins, 0);
    for (int i = 0; i < imageData.length; i++) {
      final bin = (imageData[i] * histogramBins / 256).floor().clamp(
        0,
        histogramBins - 1,
      );
      histogram[bin]++;
    }
    for (int i = 0; i < histogram.length; i++) {
      features.add(histogram[i] / imageData.length);
    }

    // 3. GRADIENTES SIMPLES (bordes básicos)
    final gradientStep = 512;
    int gradientCount = 0;
    for (int i = 0; i < imageData.length - gradientStep; i += gradientStep) {
      final gradient = (imageData[i + gradientStep] - imageData[i]).abs();
      features.add(gradient / 255.0);
      gradientCount++;
      if (gradientCount >= 10) break; // Solo 10 gradientes
    }

    // 4. CARACTERÍSTICAS GLOBALES (min, max, rango)
    int minVal = 255;
    int maxVal = 0;
    int sum = 0;
    for (int i = 0; i < imageData.length; i++) {
      final val = imageData[i];
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
      sum += imageData[i];
    }

    features.add(sum / (imageData.length * 255.0)); // Media
    features.add(minVal / 255.0); // Mínimo
    features.add(maxVal / 255.0); // Máximo
    features.add((maxVal - minVal) / 255.0); // Rango

    print(
      '[BiometricService] Características extraídas: ${features.length} (BALANCEADO)',
    );

    return features;
  }

  // =============== VALIDACIÓN DE PALMA ===============

  /// Capturar y procesar imagen de palma para validación
  Future<PalmValidationResult> validatePalm({
    required Uint8List imageData,
    required Uint8List templateData,
  }) async {
    try {
      _emitStatus(BiometricStatus.processing);

      // Detectar palma en la imagen
      final palmDetected = await _detectPalm(imageData);
      if (!palmDetected) {
        return PalmValidationResult(
          isValid: false,
          confidence: 0.0,
          errorMessage: 'No se detectó palma en la imagen',
        );
      }

      // Extraer características de la palma (líneas principales)
      final palmFeatures = await _extractPalmFeatures(imageData);
      final templateFeatures = await _extractPalmFeatures(templateData);

      // Comparar características
      final similarity = _compareImageFeatures(palmFeatures, templateFeatures);

      final isValid = similarity >= CONFIDENCE_THRESHOLD_PALM;

      _emitStatus(BiometricStatus.complete);

      return PalmValidationResult(
        isValid: isValid,
        confidence: similarity,
        qualityScore: _assessImageQuality(imageData),
        processingTime: Duration(milliseconds: 1000),
      );
    } catch (error) {
      _emitStatus(BiometricStatus.error);
      throw BiometricException('Error en validación de palma: $error');
    }
  }

  Future<bool> _detectPalm(Uint8List imageData) async {
    // Detectar palma en imagen
    await Future.delayed(Duration(milliseconds: 200));
    return true;
  }

  Future<List<double>> _extractPalmFeatures(Uint8List imageData) async {
    // Extraer líneas principales de la palma
    final List<double> features = [];
    for (int i = 0; i < 256; i++) {
      features.add((imageData[i % imageData.length] / 255.0) * 2.0 - 1.0);
    }
    return features;
  }

  // =============== UTILIDADES ===============

  double _compareImageFeatures(List<double> features1, List<double> features2) {
    if (features1.length != features2.length) {
      return 0.0;
    }

    // Usar distancia euclidiana DIRECTA (sin normalización que causa NaN)
    double sumSquaredDiff = 0.0;

    for (int i = 0; i < features1.length; i++) {
      final diff = features1[i] - features2[i];
      sumSquaredDiff += diff * diff;
    }

    // Convertir distancia a similitud (0-1)
    final distance = Math.sqrt(sumSquaredDiff);
    final similarity = 1.0 / (1.0 + distance);

    // DEBUG: Mostrar similitud calculada
    print('[BiometricService] Image similarity: $similarity');
    print('[BiometricService] Distance: $distance');

    return similarity;
  }

  double _assessImageQuality(Uint8List imageData) {
    // Evaluar la calidad de la imagen
    // Simulación: retornar puntuación aleatoria entre 0.7 y 1.0
    if (imageData.isEmpty) return 0.0;
    return 0.75 + (imageData.length % 100) / 500;
  }

  void _emitStatus(BiometricStatus status) {
    _biometricStatusStream.add(status);
  }

  void dispose() {
    _biometricStatusStream.close();
  }
}

// Clases de resultado
class VoiceValidationResult {
  final bool isValid;
  final double confidence;
  final int duration;
  final Duration processingTime;

  VoiceValidationResult({
    required this.isValid,
    required this.confidence,
    required this.duration,
    required this.processingTime,
  });
}

class EarValidationResult {
  final bool isValid;
  final double confidence;
  final double? qualityScore;
  final Duration? processingTime;
  final String? errorMessage;

  EarValidationResult({
    required this.isValid,
    required this.confidence,
    this.qualityScore,
    this.processingTime,
    this.errorMessage,
  });
}

class PalmValidationResult {
  final bool isValid;
  final double confidence;
  final double? qualityScore;
  final Duration? processingTime;
  final String? errorMessage;

  PalmValidationResult({
    required this.isValid,
    required this.confidence,
    this.qualityScore,
    this.processingTime,
    this.errorMessage,
  });
}

class BiometricException implements Exception {
  final String message;

  BiometricException(this.message);

  @override
  String toString() => message;
}

enum BiometricStatus { idle, processing, capturing, comparing, complete, error }

// Clase Math auxiliar
class Math {
  static const double pi = 3.141592653589793;

  static double cos(double x) {
    // Implementación simplificada del coseno
    return (1 - (x * x / 2) + (x * x * x * x / 24)).clamp(-1.0, 1.0) as double;
  }

  static double sqrt(double x) {
    if (x < 0) return 0;
    double res = x;
    for (int i = 0; i < 32; i++) {
      res = (res + x / res) / 2;
    }
    return res;
  }
}
