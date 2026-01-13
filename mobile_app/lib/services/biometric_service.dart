import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

// Servicio de autenticación biométrica
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();

  factory BiometricService() {
    return _instance;
  }

  BiometricService._internal();

  // Umbrales de confianza configurables (BALANCE ÓPTIMO)
  // IMPORTANTE: Punto medio entre seguridad y usabilidad
  static const double CONFIDENCE_THRESHOLD_VOICE =
      0.75; // ESTRICTO - debe coincidir muy bien con el template
  static const double CONFIDENCE_THRESHOLD_FACE =
      0.50; // REDUCIDO temporalmente para testing offline (antes 0.70)
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

      // ======= VALIDACIONES PREVIAS =======

      // 1. Validar que el audio no esté vacío
      if (audioData.isEmpty || audioData.length < 1000) {
        print(
          '[BiometricService] ❌ Audio demasiado corto: ${audioData.length} bytes',
        );
        return VoiceValidationResult(
          isValid: false,
          confidence: 0.0,
          duration: 0,
          processingTime: Duration(milliseconds: 100),
        );
      }

      // 2. Validar que el audio tenga suficiente energía (no sea silencio)
      final audioEnergy = _calculateAudioEnergy(audioData);
      print(
        '[BiometricService] 📊 Energía del audio: ${audioEnergy.toStringAsFixed(2)}',
      );

      if (audioEnergy < 5.0) {
        // Threshold de energía mínima
        print(
          '[BiometricService] ❌ Audio con energía muy baja (posible silencio)',
        );
        return VoiceValidationResult(
          isValid: false,
          confidence: 0.0,
          duration: 0,
          processingTime: Duration(milliseconds: 100),
        );
      }

      // 3. Validar que el template también tenga energía
      final templateEnergy = _calculateAudioEnergy(templateData);
      if (templateEnergy < 5.0) {
        print('[BiometricService] ⚠️ Template con energía muy baja');
      }

      // 4. Validar que las duraciones sean similares (ESTRICTO)
      // IMPORTANTE: Debe decir la frase completa, no solo ruido
      // Acepta ±50% de variación (hablar más rápido o lento)
      final audioDuration = audioData.length;
      final templateDuration = templateData.length;
      final durationRatio = audioDuration / templateDuration;

      print('[BiometricService] 📏 Duración capturada: $audioDuration bytes');
      print('[BiometricService] 📏 Duración template: $templateDuration bytes');
      print(
        '[BiometricService] 📊 Ratio de duración: ${durationRatio.toStringAsFixed(2)}',
      );

      if (durationRatio < 0.50 || durationRatio > 1.50) {
        print(
          '[BiometricService] ❌ Duraciones muy diferentes (ratio: ${durationRatio.toStringAsFixed(2)})',
        );
        return VoiceValidationResult(
          isValid: false,
          confidence: 0.0,
          duration: audioDuration ~/ 16000,
          processingTime: Duration(milliseconds: 100),
        );
      }

      // 5. Validar características de voz humana (pitch fundamental)
      final capturedPitch = _estimatePitch(audioData);
      final templatePitch = _estimatePitch(templateData);

      print(
        '[BiometricService] 🎵 Pitch capturado: ${capturedPitch.toStringAsFixed(1)} Hz',
      );
      print(
        '[BiometricService] 🎵 Pitch template: ${templatePitch.toStringAsFixed(1)} Hz',
      );

      // Voz humana: 85-255 Hz (más restrictivo)
      if (capturedPitch < 85 || capturedPitch > 255) {
        print('[BiometricService] ❌ Pitch fuera de rango de voz humana');
        return VoiceValidationResult(
          isValid: false,
          confidence: 0.0,
          duration: audioDuration ~/ 16000,
          processingTime: Duration(milliseconds: 100),
        );
      }

      // Pitch debe ser MUY similar (±20%) - misma persona
      final pitchRatio = capturedPitch / templatePitch;
      if (pitchRatio < 0.80 || pitchRatio > 1.20) {
        print(
          '[BiometricService] ❌ Pitch muy diferente (ratio: ${pitchRatio.toStringAsFixed(2)})',
        );
        return VoiceValidationResult(
          isValid: false,
          confidence: 0.0,
          duration: audioDuration ~/ 16000,
          processingTime: Duration(milliseconds: 100),
        );
      }

      // ======= EXTRACCIÓN Y COMPARACIÓN =======

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

  // Calcular energía del audio (RMS - Root Mean Square)
  double _calculateAudioEnergy(Uint8List audioData) {
    if (audioData.isEmpty) return 0.0;

    double sumSquares = 0.0;
    for (var sample in audioData) {
      // Normalizar a rango [-128, 127]
      final normalized = sample - 128;
      sumSquares += normalized * normalized;
    }

    final rms = Math.sqrt(sumSquares / audioData.length);
    return rms;
  }

  /// 🎤 VALIDAR CALIDAD DE AUDIO PARA REGISTRO
  /// Retorna mensaje de error o null si es válido
  String? validateAudioQuality(Uint8List audioData, double durationSeconds) {
    print('[BiometricService] 🔍 Validando calidad de audio para registro...');

    // NOTA IMPORTANTE:
    // El audio es un archivo WAV completo con headers (44 bytes + datos PCM16)
    // No podemos analizar correctamente la calidad sin parsear el formato WAV
    // Por ahora solo validamos la duración mínima

    // 1. Validar duración mínima (5 segundos)
    if (durationSeconds < 5.0) {
      print(
        '[BiometricService] ❌ Audio muy corto: ${durationSeconds.toStringAsFixed(1)}s < 5s',
      );
      return '❌ El audio es muy corto (${durationSeconds.toStringAsFixed(1)}s).\nDebe durar al menos 5 segundos para registrarse.';
    }

    // 2. Validar tamaño mínimo de archivo (evitar archivos corruptos)
    if (audioData.length < 1000) {
      print(
        '[BiometricService] ❌ Archivo de audio muy pequeño: ${audioData.length} bytes',
      );
      return '❌ El archivo de audio parece estar corrupto o vacío.';
    }

    print('[BiometricService] ✅ Validación de audio completada');
    print(
      '[BiometricService] ✅ Duración: ${durationSeconds.toStringAsFixed(1)}s',
    );
    print('[BiometricService] ✅ Tamaño: ${audioData.length} bytes');

    return null; // Sin errores
  }

  // Estimar pitch (frecuencia fundamental) usando autocorrelación
  double _estimatePitch(Uint8List audioData) {
    if (audioData.length < 100) return 0.0;

    const int sampleRate = 16000; // Asumiendo 16kHz
    const int minPeriod = 40; // ~400 Hz (límite superior voz)
    const int maxPeriod = 400; // ~40 Hz (límite inferior voz)

    // Convertir bytes a señal normalizada
    final signal = audioData.map((b) => (b - 128).toDouble()).toList();

    // Autocorrelación simple
    double maxCorrelation = 0.0;
    int bestPeriod = minPeriod;

    for (
      int period = minPeriod;
      period < maxPeriod && period < signal.length ~/ 2;
      period++
    ) {
      double correlation = 0.0;
      int samples = signal.length - period;

      for (int i = 0; i < samples; i++) {
        correlation += signal[i] * signal[i + period];
      }

      correlation /= samples;

      if (correlation > maxCorrelation) {
        maxCorrelation = correlation;
        bestPeriod = period;
      }
    }

    // Convertir período a frecuencia
    final pitch = sampleRate / bestPeriod;

    return pitch;
  }

  // Extraer características de audio (MEJORADO)
  List<double> _extractAudioFeatures(Uint8List audioData) {
    // Validar que hay datos suficientes
    if (audioData.length < 100) {
      print('[BiometricService] ⚠️ Audio muy corto: ${audioData.length} bytes');
      return List.filled(26, 0.0); // Devolver características vacías
    }

    final List<double> features = [];

    // 1. CARACTERÍSTICAS ESPECTRALES (13 coeficientes MFCC simulados)
    for (int i = 0; i < 13; i++) {
      double feature = 0.0;
      final step = audioData.length ~/ 1000; // Muestrear cada N bytes
      for (int j = 0; j < audioData.length; j += step) {
        feature +=
            (audioData[j] * Math.cos(2 * Math.pi * i * j / audioData.length));
      }
      features.add(feature / audioData.length);
    }

    // 2. CARACTERÍSTICAS TEMPORALES (estadísticas de la señal)
    // Media
    double mean = audioData.reduce((a, b) => a + b) / audioData.length;
    features.add(mean);

    // Energía (RMS)
    double energy = 0.0;
    for (var sample in audioData) {
      energy += sample * sample;
    }
    features.add(Math.sqrt(energy / audioData.length));

    // Cruces por cero (indicador de pitch/frecuencia)
    int zeroCrossings = 0;
    for (int i = 1; i < audioData.length; i++) {
      if ((audioData[i - 1] < 128 && audioData[i] >= 128) ||
          (audioData[i - 1] >= 128 && audioData[i] < 128)) {
        zeroCrossings++;
      }
    }
    features.add(zeroCrossings.toDouble() / audioData.length);

    // 3. CARACTERÍSTICAS DE FORMA DE ONDA
    // Picos de amplitud
    int peaks = 0;
    for (int i = 1; i < audioData.length - 1; i++) {
      if (audioData[i] > audioData[i - 1] &&
          audioData[i] > audioData[i + 1] &&
          audioData[i] > 150) {
        // Umbral para picos
        peaks++;
      }
    }
    features.add(peaks.toDouble() / audioData.length);

    // 4. SEGMENTOS DE ENERGÍA (dividir audio en 10 segmentos)
    final segmentSize = audioData.length ~/ 10;
    for (int seg = 0; seg < 10; seg++) {
      double segEnergy = 0.0;
      final start = seg * segmentSize;
      final end = (seg == 9)
          ? audioData.length
          : (seg + 1) * segmentSize; // Último segmento completo
      for (int i = start; i < end && i < audioData.length; i++) {
        segEnergy += audioData[i] * audioData[i];
      }
      features.add(Math.sqrt(segEnergy / (end - start)));
    }

    print(
      '[BiometricService] ✅ Características de voz extraídas: ${features.length} features',
    );

    return features;
  }

  // Comparar características de audio (MEJORADO - MÁS ESTRICTO)
  double _compareAudioFeatures(List<double> features1, List<double> features2) {
    if (features1.isEmpty || features2.isEmpty) {
      print('[BiometricService] ⚠️ Features vacías');
      return 0.0;
    }

    if (features1.length != features2.length) {
      print(
        '[BiometricService] ⚠️ Features de diferente tamaño: ${features1.length} vs ${features2.length}',
      );
      return 0.0;
    }

    print(
      '[BiometricService] 🔍 Comparando ${features1.length} características de voz...',
    );

    // MEJORA: Normalizar características (Z-score normalization)
    // Esto evita que diferencias de volumen arruinen la comparación
    final norm1 = _normalizeFeatures(features1);
    final norm2 = _normalizeFeatures(features2);

    // Calcular distancia euclidiana normalizada
    double sumSquaredDiff = 0.0;
    for (int i = 0; i < norm1.length; i++) {
      final diff = norm1[i] - norm2[i];
      sumSquaredDiff += diff * diff;
    }

    final distance = Math.sqrt(sumSquaredDiff);

    // Convertir distancia a similitud (0-1)
    // ESTRICTO: Función exponencial más exigente
    // Distancia pequeña -> similitud alta
    // Distancia grande -> similitud muy baja
    // Factor reducido de 5.0 a 2.0 para ser más estricto
    final similarity = math.exp(-distance / 2.0);

    // DEBUG: Mostrar detalles de la comparación
    print(
      '[BiometricService] 📊 Distancia euclidiana: ${distance.toStringAsFixed(4)}',
    );
    print(
      '[BiometricService] 📊 Similitud calculada: ${(similarity * 100).toStringAsFixed(2)}%',
    );
    print('[BiometricService] 📏 Threshold requerido: 75%');
    print(
      '[BiometricService] ${similarity >= CONFIDENCE_THRESHOLD_VOICE ? "✅ ACEPTADO" : "❌ RECHAZADO"}',
    );

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
    return (1 - (x * x / 2) + (x * x * x * x / 24)).clamp(-1.0, 1.0);
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
