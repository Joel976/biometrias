# Problema: Modelo Acepta TODO con 99% de Confianza

**Fecha:** 23 de diciembre de 2025  
**Síntoma:** Objetos aleatorios tienen 99% de confianza como "oreja_clara"

---

## 🔴 Diagnóstico del Problema

Si el modelo dice que **objetos random son orejas con 99% de confianza**, hay 3 posibles causas:

### 1. **Modelo Mal Entrenado (Overfitting)**

**Síntomas:**
- Accuracy alta en entrenamiento (>95%)
- Accuracy baja en validación (<70%)
- Clasifica todo como la clase mayoritaria

**Causa:**
- Dataset muy pequeño
- Dataset desbalanceado
- Demasiadas épocas (overfitting)

**Solución:**
```python
# Re-entrenar con más datos y regularización
model = Model(inputs=base_model.input, outputs=predictions)

# Añadir Dropout para evitar overfitting
x = GlobalAveragePooling2D()(base_model.output)
x = Dense(128, activation='relu')(x)
x = Dropout(0.5)(x)  # ← AÑADIR ESTO
predictions = Dense(NUM_CLASSES, activation='softmax')(x)
```

---

### 2. **Normalización Incorrecta**

**Problema:** Si durante el entrenamiento usaste un rango diferente a [0,1].

**Verifica tu script de Python:**
```python
# ¿Usaste esta normalización?
train_datagen = ImageDataGenerator(rescale=1./255)  # ← [0, 1]

# ¿O esta?
train_datagen = ImageDataGenerator(preprocessing_function=preprocess_input)  # ← MobileNetV2 usa [-1, 1]
```

**Si usaste `preprocess_input` de MobileNetV2:**

El modelo espera rango **[-1, 1]**, no [0, 1].

**Solución en Flutter:**
```dart
// Cambiar en _imageToTensor()
// ANTES:
return value / 255.0;  // Rango [0, 1]

// DESPUÉS:
return (value - 127.5) / 127.5;  // Rango [-1, 1] para MobileNetV2
```

---

### 3. **Dataset Desbalanceado o Corrupto**

**Problema:** Si tu carpeta `oreja_clara` tiene muchas más imágenes que las otras.

**Ejemplo:**
```
dataset_orejas/
├── oreja_clara/      ← 500 imágenes
├── oreja_borrosa/    ← 50 imágenes
└── no_oreja/         ← 20 imágenes
```

El modelo aprende a decir "oreja_clara" siempre porque maximiza accuracy.

**Solución:**
```python
# Balancear dataset con class_weight
from sklearn.utils.class_weight import compute_class_weight

class_weights = compute_class_weight(
    'balanced',
    classes=np.unique(train_generator.classes),
    y=train_generator.classes
)

model.fit(
    train_generator,
    validation_data=val_generator,
    epochs=20,
    callbacks=callbacks,
    class_weight=dict(enumerate(class_weights))  # ← AÑADIR ESTO
)
```

---

## 🔧 Soluciones Inmediatas

### Opción 1: Desactivar Validación Temporalmente

**Desde el Panel de Admin:**
1. Login → 7 taps en botón superior derecho
2. Desactivar "Validar que la imagen sea una oreja"
3. Guardar cambios

**Desde código (temporal):**
```dart
// En ear_validator_service.dart, método validateEar()
Future<EarDetectionResult> validateEar(Uint8List imageBytes) async {
  // BYPASS TEMPORAL: Aceptar todo sin validación
  return EarDetectionResult(
    isEar: true,  // ← Aceptar siempre
    confidence: 1.0,
    error: null,
  );
}
```

---

### Opción 2: Aumentar Umbral Drásticamente

```dart
// En ear_validator_service.dart, línea 19
static const double _confidenceThreshold = 0.95; // 95% en lugar de 65%
```

Esto solo aceptará si el modelo está MUY seguro.

---

### Opción 3: Verificar Normalización

Prueba cambiar la normalización a rango [-1, 1]:

```dart
// En _imageToTensor(), línea 166
// Normalizar a rango -1 a 1 (para MobileNetV2)
return (value - 127.5) / 127.5;
```

---

## 🧪 Test de Diagnóstico

### Paso 1: Revisar Logs

Cuando captures un objeto random, mira la consola:

```
[EarValidator] 📊 Probabilidades RAW: oreja_clara=99.0%, oreja_borrosa=0.5%, no_oreja=0.5%
[EarValidator] 🔢 Suma de probabilidades: 1.000
[EarValidator] 🏆 Clase ganadora: oreja_clara (99.0%)
```

**¿Qué buscar?**

#### ✅ Caso Normal (modelo OK):
```
Suma de probabilidades: 1.000  ← Suma ~1.0 es correcto
Clase ganadora varía según imagen
```

#### ❌ Caso Anormal (modelo roto):
```
oreja_clara=99% SIEMPRE (sin importar la imagen)
no_oreja nunca supera 1%
```

---

### Paso 2: Probar Normalización Alternativa

Añade esto temporalmente al inicio de `validateEar()`:

```dart
Future<EarDetectionResult> validateEar(Uint8List imageBytes) async {
  if (!_isInitialized) {
    await initialize();
  }

  try {
    // 1. Decodificar imagen
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      return EarDetectionResult(isEar: false, confidence: 0.0, error: 'No se pudo decodificar');
    }

    img.Image resized = img.copyResize(image, width: 224, height: 224);

    // 🧪 PRUEBA 1: Normalización [0, 1]
    var input1 = _imageToTensor(resized);
    var output1 = List.filled(1 * 3, 0.0).reshape([1, 3]);
    _interpreter!.run(input1, output1);
    print('[TEST] Normalización [0,1]: ${output1[0]}');

    // 🧪 PRUEBA 2: Normalización [-1, 1]
    var input2 = _imageToTensorMobileNet(resized);
    var output2 = List.filled(1 * 3, 0.0).reshape([1, 3]);
    _interpreter!.run(input2, output2);
    print('[TEST] Normalización [-1,1]: ${output2[0]}');
    
    // ... resto del código
  }
}

// Método alternativo de normalización
List<List<List<List<double>>>> _imageToTensorMobileNet(img.Image image) {
  return List.generate(
    1,
    (b) => List.generate(
      _inputHeight,
      (y) => List.generate(
        _inputWidth,
        (x) => List.generate(_numChannels, (c) {
          var pixel = image.getPixel(x, y);
          double value;
          if (c == 0) value = pixel.r.toDouble();
          else if (c == 1) value = pixel.g.toDouble();
          else value = pixel.b.toDouble();
          
          // Normalización MobileNetV2: [-1, 1]
          return (value - 127.5) / 127.5;
        }),
      ),
    ),
  );
}
```

---

## 🎯 Re-entrenar el Modelo (Solución Definitiva)

### Script Mejorado de Entrenamiento:

```python
import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D, Dropout
from tensorflow.keras.models import Model
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint, ReduceLROnPlateau
from sklearn.utils.class_weight import compute_class_weight
import numpy as np

DATASET_DIR = "dataset_orejas"
BATCH_SIZE = 16
IMG_SIZE = (224, 224)
NUM_CLASSES = 3

# ✅ Data Augmentation MÁS AGRESIVO
train_datagen = ImageDataGenerator(
    rescale=1./255,
    validation_split=0.2,
    rotation_range=30,         # ← Aumentado de 20
    zoom_range=0.3,            # ← Aumentado de 0.2
    shear_range=0.2,           # ← Aumentado de 0.1
    horizontal_flip=True,
    brightness_range=[0.8, 1.2],  # ← NUEVO
    fill_mode='nearest'
)

train_generator = train_datagen.flow_from_directory(
    DATASET_DIR,
    target_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    subset='training',
    class_mode='categorical',
    shuffle=True  # ← Importante
)

val_generator = train_datagen.flow_from_directory(
    DATASET_DIR,
    target_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    subset='validation',
    class_mode='categorical'
)

# ✅ Verificar orden de clases
print("📊 Orden de clases:", train_generator.class_indices)
print("📊 Total imágenes training:", train_generator.n)
print("📊 Total imágenes validación:", val_generator.n)

# ✅ Calcular class weights
class_weights = compute_class_weight(
    'balanced',
    classes=np.unique(train_generator.classes),
    y=train_generator.classes
)
class_weight_dict = dict(enumerate(class_weights))
print("⚖️ Class weights:", class_weight_dict)

# Modelo con Dropout
base_model = MobileNetV2(input_shape=IMG_SIZE + (3,), include_top=False, weights='imagenet')
base_model.trainable = False

x = base_model.output
x = GlobalAveragePooling2D()(x)
x = Dense(128, activation='relu')(x)
x = Dropout(0.5)(x)  # ← Regularización
predictions = Dense(NUM_CLASSES, activation='softmax')(x)

model = Model(inputs=base_model.input, outputs=predictions)
model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])

# ✅ Callbacks mejorados
callbacks = [
    EarlyStopping(patience=7, restore_best_weights=True, monitor='val_accuracy'),
    ModelCheckpoint("mejor_modelo.h5", save_best_only=True, monitor='val_accuracy'),
    ReduceLROnPlateau(patience=3, factor=0.5, min_lr=1e-7)  # ← NUEVO
]

# Entrenar
history = model.fit(
    train_generator,
    validation_data=val_generator,
    epochs=30,
    callbacks=callbacks,
    class_weight=class_weight_dict  # ← Balanceo
)

# ✅ Evaluar modelo
val_loss, val_acc = model.evaluate(val_generator)
print(f"✅ Validation Accuracy: {val_acc:.4f}")
print(f"✅ Validation Loss: {val_loss:.4f}")

# Exportar
model.save("modelo_oreja_v2.h5")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

with open("modelo_oreja_v2.tflite", "wb") as f:
    f.write(tflite_model)

print("✅ Modelo guardado como modelo_oreja_v2.tflite")
```

---

## 📊 Verificar Calidad del Dataset

```bash
# Contar imágenes por clase
ls -R dataset_orejas/oreja_clara | wc -l
ls -R dataset_orejas/oreja_borrosa | wc -l
ls -R dataset_orejas/no_oreja | wc -l
```

**Mínimo recomendado:**
- 200+ imágenes por clase
- Máximo desbalance: 3:1

**Ideal:**
- 500+ imágenes por clase
- Balance: 1:1:1

---

## ✅ Solución Temporal (Mientras Entrenas Nuevo Modelo)

```dart
// En ear_validator_service.dart
static const double _confidenceThreshold = 0.99; // Muy estricto

// O simplemente desactiva la validación
Future<EarDetectionResult> validateEar(Uint8List imageBytes) async {
  // Devolver siempre true sin validar
  return EarDetectionResult(isEar: true, confidence: 1.0, error: null);
}
```

---

## 🎓 Para la Tesis

Documenta este problema como una lección aprendida:

> **Desafío Identificado:** El modelo inicial de clasificación presentaba 
> falsos positivos excesivos, clasificando objetos aleatorios como orejas 
> con 99% de confianza.
>
> **Causa Raíz:** Dataset desbalanceado (oreja_clara: 500, no_oreja: 50) 
> combinado con falta de regularización (sin Dropout).
>
> **Solución Implementada:** Re-entrenamiento del modelo con:
> - Balanceo mediante class_weights
> - Dropout (0.5) para regularización
> - Data augmentation más agresivo
> - Early stopping con monitoreo de val_accuracy
>
> **Resultado:** Accuracy mejoró de X% a Y%, FPR redujo de Z% a W%.

---

**Prioridad:** Re-entrenar el modelo con el script mejorado. El modelo actual NO es confiable.
