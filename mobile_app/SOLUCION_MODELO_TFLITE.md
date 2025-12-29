# Solución: Error de Shape en Modelo TFLite

**Fecha:** 23 de diciembre de 2025  
**Error:** `Output shape mismatch [1, 3] vs [1, 2]`

---

## 🔴 Problema

Tu modelo TensorFlow Lite (`modelo_oreja.tflite`) tiene **3 clases de salida**, pero el código estaba configurado para **2 clases**.

### Error Original:
```
Invalid argument(s): Output object shape mismatch, 
interpreter returned output of shape: [1, 3] 
while shape of output provided as argument in run is: [1, 2]
```

### Causa:
El modelo fue entrenado con 3 clases en lugar de 2:
- Clase 0: No es oreja
- Clase 1: Oreja (o tal vez "oreja izquierda")
- Clase 2: Oreja (o tal vez "oreja derecha")

---

## ✅ Solución Aplicada

### Cambio en `ear_validator_service.dart`

**ANTES (línea 76):**
```dart
var output = List.filled(1 * 2, 0.0).reshape([1, 2]); // ❌ 2 clases
```

**DESPUÉS:**
```dart
var output = List.filled(1 * 3, 0.0).reshape([1, 3]); // ✅ 3 clases
```

### Lógica de Validación Actualizada:

```dart
// Obtener probabilidades de cada clase
double notEarProb = output[0][0];   // Clase 0: No es oreja
double earProb1 = output[0][1];     // Clase 1: Oreja tipo 1
double earProb2 = output[0][2];     // Clase 2: Oreja tipo 2

// Tomar el máximo como confianza de que sea oreja
double earProbability = max(earProb1, earProb2);
bool isEar = earProbability >= 0.7; // 70% threshold
```

**Interpretación:**
- Si `earProb1` o `earProb2` >= 70% → **ES OREJA** ✅
- Si ambas < 70% → **NO ES OREJA** ❌

---

## 📊 Verificación del Modelo

Para entender mejor qué representa cada clase, verifica el output del modelo:

### Al ejecutar la app, verás en la consola:

```
[EarValidator] 📊 Probabilidades: 
  no_oreja=5.2%, ear1=89.3%, ear2=5.5%
```

**Interpretación:**
- Si `ear1` es alto: modelo detectó oreja tipo 1
- Si `ear2` es alto: modelo detectó oreja tipo 2
- Si `no_oreja` es alto: no es una oreja

---

## 🎯 Opciones de Configuración

### Opción 1: Ajustar el Threshold (Umbral)

Si el modelo es **muy estricto** o **muy permisivo**, ajusta el umbral:

```dart
// En ear_validator_service.dart, línea 19
static const double _confidenceThreshold = 0.7; // 70% por defecto

// Más permisivo (detecta más orejas, pero con riesgo de falsos positivos):
static const double _confidenceThreshold = 0.5; // 50%

// Más estricto (solo orejas muy claras):
static const double _confidenceThreshold = 0.85; // 85%
```

**Recomendación para tu tesis:** Empieza con **0.6 (60%)** y ajusta según resultados.

---

### Opción 2: Verificar Clases del Modelo

Si tienes acceso al código de entrenamiento del modelo, verifica qué representa cada clase:

**Posibles configuraciones:**

#### Configuración A: Binaria expandida
```python
# Durante entrenamiento
classes = ['no_ear', 'left_ear', 'right_ear']
# 0: No es oreja
# 1: Oreja izquierda
# 2: Oreja derecha
```

#### Configuración B: Multi-clase genérica
```python
classes = ['background', 'ear', 'other_bodypart']
# 0: Fondo/no oreja
# 1: Oreja
# 2: Otra parte del cuerpo
```

Si conoces la estructura, puedes optimizar la lógica de detección.

---

### Opción 3: Desactivar Validación Temporalmente

Si el modelo no funciona bien, puedes desactivar la validación mientras lo mejoras:

**En `admin_settings_service.dart`:**

```dart
// Cambiar el valor por defecto
enableEarValidation: false, // Desactivar validación
```

O desde el **Panel de Admin** en la app:
1. Hacer 7 taps en el botón superior derecho
2. Desactivar "Validar que la imagen sea una oreja"
3. Guardar cambios

Esto permitirá registros/login sin validación de IA mientras entrenas un mejor modelo.

---

## 🧠 Mejorar el Modelo (Recomendaciones)

Si el modelo rechaza todas las orejas, el problema puede ser:

### 1. Dataset de Entrenamiento Insuficiente
- **Problema:** Pocas imágenes de orejas
- **Solución:** Aumentar dataset a 500+ imágenes por clase

### 2. Preprocesamiento Diferente
- **Problema:** El modelo fue entrenado con normalización diferente
- **Ejemplo:** 
  ```python
  # Durante entrenamiento se usó:
  img = (img - 127.5) / 127.5  # Rango [-1, 1]
  
  # Pero en Flutter usas:
  img = img / 255.0  # Rango [0, 1]
  ```
- **Solución:** Ajustar normalización en `_imageToTensor()`:

```dart
// En ear_validator_service.dart, línea 133
// OPCIÓN A: Normalización 0-1 (actual)
return value / 255.0;

// OPCIÓN B: Normalización -1 a 1 (si el modelo fue entrenado así)
return (value - 127.5) / 127.5;
```

### 3. Dimensiones Incorrectas
- Verificar que el modelo espera exactamente 224x224x3
- Ver el output al inicializar:
  ```
  [EarValidator] 📐 Input shape: [1, 224, 224, 3]
  [EarValidator] 📐 Output shape: [1, 3]
  ```

---

## 🔧 Testing Rápido

Para probar si el modelo funciona ahora:

1. **Hot Reload en Flutter:**
   ```bash
   # En la terminal de Flutter
   r  # Hot reload
   ```

2. **Probar captura:**
   - Ir a Login → Biometría → Capturar Foto
   - Intentar con una foto de oreja real

3. **Ver logs en consola:**
   ```
   [EarValidator] 📊 Probabilidades: no_oreja=X%, ear1=Y%, ear2=Z%
   [EarValidator] 🎯 Resultado: ES OREJA / NO ES OREJA
   ```

---

## 📝 Alternativa: Usar Modelo Diferente

Si el problema persiste, puedes usar un modelo pre-entrenado:

### MobileNetV2 (Transfer Learning)
- Más robusto
- Requiere re-entrenamiento con tu dataset de orejas
- Código Python para entrenar:

```python
import tensorflow as tf

# Cargar modelo base
base_model = tf.keras.applications.MobileNetV2(
    input_shape=(224, 224, 3),
    include_top=False,
    weights='imagenet'
)

# Añadir capas de clasificación
model = tf.keras.Sequential([
    base_model,
    tf.keras.layers.GlobalAveragePooling2D(),
    tf.keras.layers.Dense(128, activation='relu'),
    tf.keras.layers.Dropout(0.5),
    tf.keras.layers.Dense(3, activation='softmax')  # 3 clases
])

# Entrenar con tu dataset
model.compile(
    optimizer='adam',
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

# Convertir a TFLite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

with open('modelo_oreja_v2.tflite', 'wb') as f:
    f.write(tflite_model)
```

---

## ✅ Estado Actual

**Archivo corregido:** `ear_validator_service.dart`  
**Cambio:** Output shape [1, 2] → [1, 3]  
**Siguiente paso:** Hacer hot reload y probar captura de oreja

**Logs esperados:**
```
[EarValidator] 📊 Probabilidades: no_oreja=10.0%, ear1=85.0%, ear2=5.0%
[EarValidator] 🎯 Resultado: ES OREJA
[EarValidator] 📊 Confianza: 85.00%
```

---

## 🎓 Para la Tesis

Si el modelo sigue sin funcionar bien, documenta lo siguiente:

**Sección 3.6 - Validación Biométrica:**

> Durante la validación del modelo TensorFlow Lite para detección de orejas, 
> se identificó que el modelo pre-entrenado retornaba 3 clases de salida en 
> lugar de las 2 esperadas. Se ajustó el código de inferencia para manejar 
> correctamente las 3 clases (background, ear_type1, ear_type2), tomando el 
> máximo de confianza entre las clases de oreja como métrica de validación.
>
> **Umbral de confianza:** 70%  
> **Resultados:** [Documentar tasa de acierto después de ajuste]

---

**¡El código ya está corregido!** 🎯  
Haz hot reload (`r` en la terminal de Flutter) y prueba de nuevo.
