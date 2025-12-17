# 🧬 Integración de Librerías Biométricas

Guía completa para integrar reconocimiento de voz, oreja y huella palmar.

---

## 1️⃣ Reconocimiento de Voz (Audio Biometría)

### Librerías Recomendadas

#### A. Microsoft Azure Speaker Recognition
**Ventajas**: Alta precisión, API cloud, muy documentado
**Desventajas**: Requiere internet, costo por API

```dart
// pubspec.yaml
dependencies:
  azure_speech: ^1.0.0
```

```dart
// lib/services/voice_recognition_service.dart
import 'package:azure_speech/speech_config.dart';
import 'package:azure_speech/speaker_recognition.dart';

class VoiceRecognitionService {
  late final SpeechConfig _config;

  Future<void> initialize() async {
    _config = SpeechConfig.fromSubscription(
      subscriptionKey: 'YOUR_AZURE_KEY',
      region: 'eastus',
    );
  }

  Future<double> verifyVoiceMatch({
    required String audioPath,
    required String enrollmentId,
  }) async {
    // Implementación de verificación
    // Retorna similitud 0.0 - 1.0
  }

  Future<void> enrollVoice({
    required String audioPath,
    required String userId,
  }) async {
    // Enroll usuario para reconocimiento futuro
  }
}
```

#### B. DeepSpeech + Extractor Local
**Ventajas**: Funciona offline, código abierto
**Desventajas**: Menos preciso que Azure

```dart
// pubspec.yaml
dependencies:
  tflite_flutter: ^0.10.0
  audio_session: ^0.1.0
  flutter_sound: ^9.2.13
```

```dart
// lib/services/deepseech_service.dart
import 'dart:typed_data';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';

class DeepSpeechService {
  late Interpreter _interpreter;
  List<double> _mfccFeatures = [];

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('models/deepspeech_model.tflite');
    } catch (e) {
      print('Error cargando modelo: $e');
    }
  }

  // Extraer características MFCC del audio
  List<List<double>> extractMFCC(List<double> audioSignal, {
    int sampleRate = 16000,
    int numMFCC = 13,
  }) {
    final List<List<double>> mfccMatrix = [];

    // Aplicar FFT
    final fftResult = _fft(audioSignal);

    // Aplicar Mel filterbank
    final melFilterbank = _melFilterbank(fftResult, sampleRate);

    // Aplicar log y DCT
    for (int i = 0; i < melFilterbank.length; i++) {
      final mfcc = _dct(melFilterbank[i]);
      mfccMatrix.add(mfcc.take(numMFCC).toList());
    }

    return mfccMatrix;
  }

  // Comparar templates de voz
  double compareVoiceTemplates(
    List<double> template1,
    List<double> template2,
  ) {
    // Similitud del coseno
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < template1.length; i++) {
      dotProduct += template1[i] * template2[i];
      norm1 += template1[i] * template1[i];
      norm2 += template2[i] * template2[i];
    }

    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  List<double> _fft(List<double> input) {
    // Implementar FFT (usar librería si es posible)
    return input;
  }

  List<List<double>> _melFilterbank(List<double> fftResult, int sampleRate) {
    // Implementar Mel filterbank
    return [];
  }

  List<double> _dct(List<double> input) {
    // Discrete Cosine Transform
    return input;
  }
}
```

---

## 2️⃣ Reconocimiento de Oreja

### Librerías Recomendadas

#### A. OpenCV + TensorFlow Lite
```dart
// pubspec.yaml
dependencies:
  opencv: ^1.0.0
  tflite_flutter: ^0.10.0
  camera: ^0.10.0
```

```dart
// lib/services/ear_recognition_service.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:math';

class EarRecognitionService {
  // Detectar oreja usando Haar Cascade o YOLO
  Future<Rect?> detectEar(Image image) async {
    // Usar OpenCV o modelo YOLO para detectar oreja
    // Retorna bounding box de la oreja detectada
  }

  // Extraer características CNN
  Future<List<double>> extractEarFeatures(Uint8List imageData) async {
    // 1. Preparar imagen
    final processedImage = _preprocessImage(imageData);

    // 2. Pasar por modelo CNN
    final features = await _runCNNModel(processedImage);

    return features;
  }

  // Comparar características
  double compareEarFeatures(
    List<double> features1,
    List<double> features2,
  ) {
    // Similitud del coseno (ver sección de voz)
    return _cosineSimilarity(features1, features2);
  }

  Uint8List _preprocessImage(Uint8List imageData) {
    // Normalizar a 224x224
    // Aplicar augmentación si es necesario
    return imageData;
  }

  Future<List<double>> _runCNNModel(Uint8List imageData) async {
    // Usar TensorFlow Lite para ejecutar modelo CNN
    return [];
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return normA == 0 || normB == 0 ? 0 : dot / (sqrt(normA) * sqrt(normB));
  }
}
```

#### B. Detección con Haar Cascade
```dart
// lib/services/haar_cascade_service.dart
class HaarCascadeEarDetector {
  // Cargar cascada pre-entrenada
  Future<void> loadCascade() async {
    // Cargar haarcascade_ear.xml
  }

  // Detectar orejas en imagen
  List<Rect> detectEars(Image image) {
    // Usar OpenCV Android/iOS bridge
    return [];
  }
}
```

---

## 3️⃣ Reconocimiento de Palma

### Librerías Recomendadas

#### A. Neurotechnology MegaMatcher SDK
**Ventajas**: Especializado en biometría de palma, muy preciso
**Desventajas**: Comercial, licencia requerida

```dart
// lib/services/palm_recognition_service.dart
import 'dart:typed_data';

class PalmRecognitionService {
  // Inicializar SDK
  Future<void> initialize() async {
    // Inicializar MegaMatcher SDK
  }

  // Capturar plantilla de palma
  Future<Uint8List> capturePalmTemplate(Image image) async {
    // Capturar y generar template
    return Uint8List(0);
  }

  // Verificar plantilla
  Future<double> verifyPalmMatch({
    required Uint8List capturedTemplate,
    required Uint8List enrolledTemplate,
  }) async {
    // Comparar templates
    return 0.0;
  }
}
```

#### B. OpenCV + Extractor Personalizado
```dart
// lib/services/palm_extractor.dart
import 'package:image/image.dart' as img;

class PalmExtractor {
  // Detectar palma en imagen
  Future<img.Image?> detectPalm(Uint8List imageData) async {
    var image = img.decodeImage(imageData);
    if (image == null) return null;

    // 1. Conversión a escala de grises
    var gray = img.grayscale(image);

    // 2. Aplicar threshold binario
    var binary = img.adjustColor(gray, saturation: -100);

    // 3. Encontrar contornos
    // (Usar OpenCV Android/iOS para mejor rendimiento)

    return binary;
  }

  // Extraer líneas principales (Life lines, Head line, etc.)
  Future<List<Line>> extractPalmLines(img.Image image) async {
    final lines = <Line>[];

    // Aplicar Hough Transform para detectar líneas
    // Filtrar líneas por longitud y posición

    return lines;
  }

  // Generar descriptor de palma
  Future<List<double>> generatePalmDescriptor(
    List<Line> lines,
  ) async {
    final descriptor = <double>[];

    // Para cada línea, extraer:
    // - Longitud
    // - Ángulo
    // - Curvatura
    // - Profundidad

    for (var line in lines) {
      descriptor.addAll([
        line.length.toDouble(),
        line.angle,
        line.curvature,
        line.depth,
      ]);
    }

    return descriptor;
  }

  // Comparar descriptores
  double comparePalmDescriptors(
    List<double> descriptor1,
    List<double> descriptor2,
  ) {
    // Similitud del coseno
    return _cosineSimilarity(descriptor1, descriptor2);
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return normA == 0 || normB == 0 ? 0 : dot / (sqrt(normA) * sqrt(normB));
  }
}

class Line {
  final double length;
  final double angle;
  final double curvature;
  final double depth;

  Line({
    required this.length,
    required this.angle,
    required this.curvature,
    required this.depth,
  });
}
```

---

## 🔌 Integración en Backend (C++)

### Estructura de Módulo Biométrico

```cpp
// biometric_manager.h
#ifndef BIOMETRIC_MANAGER_H
#define BIOMETRIC_MANAGER_H

#include <vector>
#include <string>

typedef struct {
  double* features;
  int feature_count;
} BiometricTemplate;

class BiometricManager {
private:
  double CONFIDENCE_THRESHOLD;
  
public:
  BiometricManager();
  ~BiometricManager();
  
  // Validación de voz
  double verifyVoice(
    const unsigned char* audio_data,
    int audio_size,
    const BiometricTemplate* reference_template
  );
  
  // Validación de oreja
  double verifyEar(
    const unsigned char* image_data,
    int image_size,
    const BiometricTemplate* reference_template
  );
  
  // Validación de palma
  double verifyPalm(
    const unsigned char* image_data,
    int image_size,
    const BiometricTemplate* reference_template
  );
  
private:
  double compareTemplates(
    const BiometricTemplate* t1,
    const BiometricTemplate* t2
  );
  double cosineSimilarity(
    const double* v1,
    const double* v2,
    int size
  );
};

#endif // BIOMETRIC_MANAGER_H
```

```cpp
// biometric_manager.cpp
#include "biometric_manager.h"
#include <cmath>

BiometricManager::BiometricManager() 
  : CONFIDENCE_THRESHOLD(0.85) {}

double BiometricManager::verifyVoice(
  const unsigned char* audio_data,
  int audio_size,
  const BiometricTemplate* reference_template
) {
  // Implementar extracción de características MFCC
  // Comparar con template de referencia
  BiometricTemplate captured = {nullptr, 0};
  // ... extracción de features ...
  return compareTemplates(&captured, reference_template);
}

double BiometricManager::compareTemplates(
  const BiometricTemplate* t1,
  const BiometricTemplate* t2
) {
  if (!t1 || !t2 || t1->feature_count != t2->feature_count) {
    return 0.0;
  }
  
  return cosineSimilarity(
    t1->features,
    t2->features,
    t1->feature_count
  );
}

double BiometricManager::cosineSimilarity(
  const double* v1,
  const double* v2,
  int size
) {
  double dot_product = 0.0;
  double norm1 = 0.0;
  double norm2 = 0.0;
  
  for (int i = 0; i < size; i++) {
    dot_product += v1[i] * v2[i];
    norm1 += v1[i] * v1[i];
    norm2 += v2[i] * v2[i];
  }
  
  if (norm1 == 0.0 || norm2 == 0.0) return 0.0;
  return dot_product / (sqrt(norm1) * sqrt(norm2));
}
```

---

## 📦 CMakeLists.txt para Compilación

```cmake
cmake_minimum_required(VERSION 3.10)
project(BiometricEngine)

set(CMAKE_CXX_STANDARD 17)

# Fuentes
set(BIOMETRIC_SOURCES
  src/biometric/biometric_manager.cpp
  src/extractor_voice.cpp
  src/extractor_ear.cpp
  src/extractor_palm.cpp
)

# Crear librería compartida
add_library(biometric_engine SHARED ${BIOMETRIC_SOURCES})

# Enlaces de OpenSSL para cifrado
find_package(OpenSSL REQUIRED)
target_link_libraries(biometric_engine PRIVATE OpenSSL::Crypto)

# Incluir directorios
target_include_directories(biometric_engine PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Opciones de compilación
target_compile_options(biometric_engine PRIVATE
  -Wall -Wextra -Werror -O3
)

# Instalación
install(TARGETS biometric_engine
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin
)
```

---

## 🧪 Testing Biometría

```dart
// test/biometric_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:biometrics_app/services/biometric_service.dart';

void main() {
  group('BiometricService', () {
    late BiometricService service;

    setUp(() {
      service = BiometricService();
    });

    test('Validación de voz con alta confianza', () async {
      // Arrancar con audio de prueba
      final audioData = generateTestAudioData();
      final templateData = generateTemplateData();

      final result = await service.validateVoice(
        audioData: audioData,
        targetPhrase: 'Frase de prueba',
        templateData: templateData,
      );

      expect(result.isValid, true);
      expect(result.confidence, greaterThanOrEqualTo(0.85));
    });

    test('Validación de oreja correcta', () async {
      final imageData = generateTestEarImage();
      final templateData = generateEarTemplateData();

      final result = await service.validateEar(
        imageData: imageData,
        templateData: templateData,
      );

      expect(result.isValid, true);
      expect(result.confidence, greaterThanOrEqualTo(0.90));
    });

    test('Validación de palma correcta', () async {
      final imageData = generateTestPalmImage();
      final templateData = generatePalmTemplateData();

      final result = await service.validatePalm(
        imageData: imageData,
        templateData: templateData,
      );

      expect(result.isValid, true);
    });
  });
}
```

---

## 📊 Umbrales y Calibración

```dart
// lib/utils/biometric_thresholds.dart
class BiometricThresholds {
  // Umbrales por modalidad (configurables por perfil de riesgo)
  static const double VOICE_THRESHOLD_LOW = 0.80;
  static const double VOICE_THRESHOLD_MEDIUM = 0.85;
  static const double VOICE_THRESHOLD_HIGH = 0.92;

  static const double EAR_THRESHOLD_LOW = 0.85;
  static const double EAR_THRESHOLD_MEDIUM = 0.90;
  static const double EAR_THRESHOLD_HIGH = 0.95;

  static const double PALM_THRESHOLD_LOW = 0.83;
  static const double PALM_THRESHOLD_MEDIUM = 0.88;
  static const double PALM_THRESHOLD_HIGH = 0.93;

  // Seleccionar umbral según contexto
  static double getThreshold(
    String modalidad,
    SecurityLevel securityLevel,
  ) {
    switch (modalidad) {
      case 'voz':
        return _getVoiceThreshold(securityLevel);
      case 'oreja':
        return _getEarThreshold(securityLevel);
      case 'palma':
        return _getPalmThreshold(securityLevel);
      default:
        return 0.85;
    }
  }

  static double _getVoiceThreshold(SecurityLevel level) {
    switch (level) {
      case SecurityLevel.low:
        return VOICE_THRESHOLD_LOW;
      case SecurityLevel.medium:
        return VOICE_THRESHOLD_MEDIUM;
      case SecurityLevel.high:
        return VOICE_THRESHOLD_HIGH;
    }
  }

  // ... Métodos similares para oreja y palma
}

enum SecurityLevel { low, medium, high }
```

---

**Última actualización**: 25 de Noviembre de 2025
