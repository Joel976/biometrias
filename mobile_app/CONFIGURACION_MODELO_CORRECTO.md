# Configuración Correcta del Modelo TFLite

**Fecha:** 23 de diciembre de 2025  
**Modelo:** MobileNetV2 con 3 clases

---

## ✅ Estructura del Modelo Confirmada

### Clases de Entrenamiento (en orden):

```python
# Tu script de entrenamiento
DATASET_DIR = "dataset_orejas"
├── no_oreja/          # Clase 0
├── oreja_borrosa/     # Clase 1
└── oreja_clara/       # Clase 2
```

**Salida del modelo:**
```
Output shape: [1, 3]
[no_oreja_prob, oreja_borrosa_prob, oreja_clara_prob]
```

---

## 🎯 Lógica de Validación Implementada

### Código Actualizado:

```dart
// CLASES DEL MODELO:
// Clase 0: no_oreja
// Clase 1: oreja_borrosa
// Clase 2: oreja_clara

double noOrejaProb = output[0][0];
double orejaBorrosaProb = output[0][1];
double orejaClaraProb = output[0][2];

// Probabilidad total de que sea oreja (borrosa O clara)
double totalOrejaProb = orejaBorrosaProb + orejaClaraProb;

// Mejor confianza entre borrosa y clara
double maxOrejaProb = max(orejaBorrosaProb, orejaClaraProb);

// VALIDACIÓN con doble condición:
bool isEar = maxOrejaProb >= 0.7 && totalOrejaProb > noOrejaProb;
```

### Condiciones para Aceptar:

1. ✅ **La mejor probabilidad de oreja >= 70%**
   - Puede ser `oreja_borrosa` >= 70%
   - O `oreja_clara` >= 70%

2. ✅ **Probabilidad total de oreja > probabilidad de NO oreja**
   - `(oreja_borrosa + oreja_clara) > no_oreja`

---

## 📊 Ejemplos de Validación

### ✅ Caso 1: Oreja Clara (Válido)
```
no_oreja=5%, oreja_borrosa=10%, oreja_clara=85%
→ maxOrejaProb=85% >= 70% ✅
→ totalOrejaProb=95% > 5% ✅
→ RESULTADO: ✅ ES OREJA (clara)
```

### ✅ Caso 2: Oreja Borrosa (Válido)
```
no_oreja=8%, oreja_borrosa=78%, oreja_clara=14%
→ maxOrejaProb=78% >= 70% ✅
→ totalOrejaProb=92% > 8% ✅
→ RESULTADO: ✅ ES OREJA (borrosa)
```

### ❌ Caso 3: No es Oreja (Rechazado)
```
no_oreja=88%, oreja_borrosa=8%, oreja_clara=4%
→ maxOrejaProb=8% < 70% ❌
→ totalOrejaProb=12% < 88% ❌
→ RESULTADO: ❌ NO ES OREJA
```

### ⚠️ Caso 4: Borderline (Ambiguo)
```
no_oreja=45%, oreja_borrosa=40%, oreja_clara=15%
→ maxOrejaProb=40% < 70% ❌
→ totalOrejaProb=55% > 45% ✅
→ RESULTADO: ❌ NO ES OREJA (no alcanza umbral)
```

### ✅ Caso 5: Orejas Combinadas
```
no_oreja=10%, oreja_borrosa=45%, oreja_clara=45%
→ maxOrejaProb=45% < 70% ❌
→ totalOrejaProb=90% > 10% ✅
→ RESULTADO: ❌ NO ES OREJA (ninguna clase individual supera umbral)
```

**Nota:** Este último caso podría ser ajustado si quieres aceptar orejas cuando la probabilidad **combinada** es alta.

---

## 🔧 Ajustes Disponibles

### Opción 1: Ajustar Umbral de Confianza

En `ear_validator_service.dart`, línea 19:

```dart
static const double _confidenceThreshold = 0.7; // Actual (70%)
```

**Recomendaciones según tus necesidades:**

| Umbral | Comportamiento | Uso Recomendado |
|--------|----------------|-----------------|
| **0.5** | Muy permisivo | Testing inicial, dataset pequeño |
| **0.6** | Balanceado | Producción con modelo no perfecto |
| **0.7** | Estricto (actual) | Producción con buen modelo |
| **0.8** | Muy estricto | Solo orejas muy claras |
| **0.9** | Extremo | Research/validación de calidad |

---

### Opción 2: Usar Probabilidad Combinada

Si quieres aceptar orejas cuando la suma de `borrosa + clara` es alta:

```dart
// Cambiar la validación a:
bool isEar = totalOrejaProb >= 0.7 && totalOrejaProb > noOrejaProb;
```

**Ventajas:**
- Acepta orejas aunque estén en el límite entre borrosa/clara
- Más flexible con imágenes intermedias

**Desventajas:**
- Puede aceptar falsos positivos si ambas clases tienen probabilidades medianas

---

### Opción 3: Validación Más Estricta con Margen

Requerir que la clase ganadora supere a "no_oreja" por un margen:

```dart
bool isEar = maxOrejaProb >= 0.7 && 
             totalOrejaProb > noOrejaProb &&
             (totalOrejaProb - noOrejaProb) >= 0.3; // Margen del 30%
```

**Ejemplo:**
```
no_oreja=40%, oreja_total=60%
→ Diferencia: 20% < 30% requerido
→ RECHAZADO (muy ambiguo)
```

---

## 📝 Logs de Debugging

Ahora verás en consola:

```
[EarValidator] 📊 Probabilidades RAW: 
  no_oreja=5.0%, oreja_borrosa=10.0%, oreja_clara=85.0%
[EarValidator] 🏆 Clase ganadora: oreja_clara (85.0%)
[EarValidator] 📊 Probabilidad total oreja: 95.0%
[EarValidator] 🎯 Resultado: ✅ ES OREJA
[EarValidator] 📊 Confianza final: 85.00%
```

**Para rechazos:**
```
[EarValidator] 📊 Probabilidades RAW: 
  no_oreja=88.0%, oreja_borrosa=8.0%, oreja_clara=4.0%
[EarValidator] 🏆 Clase ganadora: no_oreja (88.0%)
[EarValidator] 📊 Probabilidad total oreja: 12.0%
[EarValidator] 🎯 Resultado: ❌ NO ES OREJA
[EarValidator] 📊 Confianza final: 8.00%
```

---

## 🧪 Testing del Modelo

### Test Suite Recomendado:

#### 1. **Orejas Claras (Alta Calidad)**
- ✅ Buena iluminación
- ✅ Enfoque nítido
- ✅ Fondo uniforme
- **Resultado Esperado:** `oreja_clara >= 80%`

#### 2. **Orejas Borrosas (Calidad Media)**
- ⚠️ Iluminación baja
- ⚠️ Ligeramente desenfocada
- ⚠️ Fondo complejo
- **Resultado Esperado:** `oreja_borrosa >= 60%`

#### 3. **No Orejas (Negativos)**
- ❌ Fotos de caras completas
- ❌ Objetos aleatorios
- ❌ Fondos vacíos
- **Resultado Esperado:** `no_oreja >= 70%`

---

## 📊 Métricas de Calidad

Para evaluar el modelo con un dataset de validación:

```python
# Script de validación
import tensorflow as tf
import numpy as np
from sklearn.metrics import classification_report, confusion_matrix

# Cargar modelo
interpreter = tf.lite.Interpreter(model_path="modelo_oreja.tflite")
interpreter.allocate_tensors()

# Evaluar dataset de validación
# ... (cargar imágenes de validación)

# Generar reporte
print(classification_report(y_true, y_pred, 
    target_names=['no_oreja', 'oreja_borrosa', 'oreja_clara']))

# Matriz de confusión
print(confusion_matrix(y_true, y_pred))
```

**Métricas Objetivo para la Tesis:**

| Métrica | Objetivo | Excelente |
|---------|----------|-----------|
| **Accuracy** | >= 85% | >= 90% |
| **Precision (oreja)** | >= 80% | >= 90% |
| **Recall (oreja)** | >= 80% | >= 90% |
| **F1-Score** | >= 80% | >= 90% |
| **FPR (False Positive Rate)** | <= 10% | <= 5% |

---

## ⚡ Optimizaciones de Rendimiento

### 1. Cuantización (Reducir Tamaño)

Si el modelo es muy pesado:

```python
# En tu script de entrenamiento
converter = tf.lite.TFLiteConverter.from_keras_model(model)

# Cuantización dinámica (reduce tamaño ~4x)
converter.optimizations = [tf.lite.Optimize.DEFAULT]

# Cuantización completa (reduce más, puede bajar precisión)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]

tflite_model = converter.convert()
```

**Trade-off:**
- ✅ Modelo más pequeño (MB)
- ✅ Inferencia más rápida
- ⚠️ Ligera pérdida de precisión (1-3%)

---

### 2. Caché de Modelo

El modelo ya se carga una sola vez en `initialize()`, pero puedes verificar:

```dart
// En ear_validator_service.dart
Future<void> initialize() async {
  if (_isInitialized) return; // ✅ Ya implementado
  
  _interpreter = await Interpreter.fromAsset(
    'assets/models/modelo_oreja.tflite',
  );
  
  _isInitialized = true;
}
```

---

## 🎓 Documentación para la Tesis

### Sección 3.6 - Validación del Modelo de Clasificación

> **Modelo Utilizado:** MobileNetV2 con Transfer Learning
>
> **Arquitectura:**
> - Input: 224×224×3 (RGB normalizado 0-1)
> - Base: MobileNetV2 (pesos de ImageNet, frozen)
> - Clasificador: GlobalAveragePooling2D → Dense(128, ReLU) → Dense(3, Softmax)
>
> **Clases del Modelo:**
> 1. `no_oreja`: Imágenes que no contienen orejas
> 2. `oreja_borrosa`: Orejas de calidad media/baja
> 3. `oreja_clara`: Orejas de alta calidad
>
> **Lógica de Validación Implementada:**
>
> La aplicación acepta una imagen como oreja válida si cumple dos condiciones:
> - La probabilidad máxima entre `oreja_borrosa` y `oreja_clara` >= 70%
> - La probabilidad combinada de ambas clases supera a `no_oreja`
>
> **Parámetros de Entrenamiento:**
> - Optimizer: Adam
> - Loss: Categorical Crossentropy
> - Augmentation: Rotación (±20°), Zoom (20%), Shear (10%), Flip horizontal
> - Early Stopping: Patience=5
> - Batch Size: 16
> - Epochs: 20 (con early stopping)
>
> **Resultados de Validación:**
> - Accuracy: [Completar con tus métricas]
> - Precision: [Completar]
> - Recall: [Completar]
> - F1-Score: [Completar]

---

## ✅ Estado Actual

**Código actualizado:** `ear_validator_service.dart`  
**Clases correctamente mapeadas:**
- Clase 0: `no_oreja`
- Clase 1: `oreja_borrosa`
- Clase 2: `oreja_clara`

**Validación:** Doble condición con probabilidad combinada

---

## 🚀 Siguiente Paso

1. **Hot reload** en Flutter:
   ```bash
   r  # En la terminal
   ```

2. **Probar con diferentes imágenes:**
   - Oreja clara (buena calidad)
   - Oreja borrosa (baja calidad)
   - Cara completa (no oreja)
   - Objeto aleatorio (no oreja)

3. **Revisar logs en consola** para verificar probabilidades

4. **Ajustar umbral** si es necesario (línea 19 de `ear_validator_service.dart`)

---

**¡El modelo ahora está correctamente configurado para tus 3 clases!** 🎯
