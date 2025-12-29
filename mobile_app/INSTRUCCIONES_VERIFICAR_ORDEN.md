# 🔍 VERIFICAR ORDEN REAL DE CLASES - SIN TENSORFLOW

**Problema:** Tenemos 2 documentos contradictorios sobre el orden de clases.

---

## Método 1: Buscar en tu Script de Entrenamiento

### Paso 1: Encuentra el script Python

Busca un archivo `.py` que tenga:
```python
from tensorflow.keras.preprocessing.image import ImageDataGenerator

train_datagen = ImageDataGenerator(rescale=1./255)
train_generator = train_datagen.flow_from_directory(...)
```

### Paso 2: Agrega esta línea DESPUÉS de crear el generador:

```python
train_generator = train_datagen.flow_from_directory(
    DATASET_DIR,
    target_size=(224, 224),
    batch_size=32,
    class_mode='categorical'
)

# ← AGREGA ESTA LÍNEA AQUÍ:
print("🔍 ORDEN REAL:", train_generator.class_indices)
```

### Paso 3: Ejecuta el script

```bash
python tu_script_de_entrenamiento.py
```

**Output esperado:**
```python
🔍 ORDEN REAL: {'oreja_clara': 0, 'oreja_borrosa': 1, 'no_oreja': 2}
```

O puede ser:
```python
🔍 ORDEN REAL: {'no_oreja': 0, 'oreja_borrosa': 1, 'oreja_clara': 2}
```

---

## Método 2: Prueba Rápida con la App (SIN PYTHON)

Si no encuentras el script, haz esto:

### Paso 1: Busca 3 imágenes de PRUEBA

1. **Una foto clara de tu oreja** (guardada como `test_oreja_clara.jpg`)
2. **Una foto borrosa de oreja** (guardada como `test_oreja_borrosa.jpg`)
3. **Una foto de objeto random** (mouse, teclado, pared) (`test_no_oreja.jpg`)

### Paso 2: Ejecuta la app y toma las 3 fotos

Para cada foto, copia los logs:

```
[EarValidator] 📊 Probabilidades RAW: 
  oreja_clara=X%, oreja_borrosa=Y%, no_oreja=Z%
[EarValidator] 🏆 Clase ganadora: ???
```

### Paso 3: Llena esta tabla

| Imagen Real | output[0][0] | output[0][1] | output[0][2] | Ganadora |
|-------------|--------------|--------------|--------------|----------|
| Oreja clara | ???% | ???% | ???% | ??? |
| Oreja borrosa | ???% | ???% | ???% | ??? |
| No oreja (random) | ???% | ???% | ???% | ??? |

### Paso 4: Interpreta los resultados

#### Escenario A: Orden actual es correcto
```
| Oreja clara | 90% | 5% | 5% | oreja_clara ✅ |
| Oreja borrosa | 10% | 85% | 5% | oreja_borrosa ✅ |
| No oreja | 2% | 3% | 95% | no_oreja ✅ |
```
→ **No cambiar nada**, el mapeo actual es correcto.

#### Escenario B: Orden INVERTIDO (alfabético)
```
| Oreja clara | 5% | 5% | 90% | no_oreja ❌ |
| Oreja borrosa | 5% | 85% | 10% | oreja_borrosa ✅ |
| No oreja | 95% | 2% | 3% | oreja_clara ❌ |
```
→ **Cambiar a orden alfabético:**
```dart
double noOrejaProb = output[0][0];         // Clase 0
double orejaBorrosaProb = output[0][1];    // Clase 1
double orejaClaraProb = output[0][2];      // Clase 2
```

#### Escenario C: Modelo mal entrenado
```
| Oreja clara | 33% | 33% | 34% | aleatorio ❌ |
| Oreja borrosa | 32% | 35% | 33% | aleatorio ❌ |
| No oreja | 34% | 33% | 33% | aleatorio ❌ |
```
→ **El modelo no sirve**, necesitas re-entrenar con más datos.

---

## Método 3: Preguntar Directamente

**¿Recuerdas qué output te dio el entrenamiento?**

Cuando entrenaste, ¿viste algo así?

```python
Found 300 images belonging to 3 classes.
Class indices: {'oreja_clara': 0, 'oreja_borrosa': 1, 'no_oreja': 2}
```

O:
```python
Found 300 images belonging to 3 classes.
Class indices: {'no_oreja': 0, 'oreja_borrosa': 1, 'oreja_clara': 2}
```

Si lo recuerdas, **ese es el orden real**.

---

## 🎯 Acción Inmediata

**Elige UNO de estos métodos:**

1. ✅ **Busca el script de entrenamiento** y agrega el `print`
2. ✅ **Haz las 3 pruebas con la app** y llena la tabla
3. ✅ **Recuerda el output del entrenamiento original**

**Pégame aquí el resultado de cualquiera de estos métodos.**

Con eso puedo darte la configuración 100% correcta.

---

## 📝 Respuesta Rápida

Copia y pega esto llenando los espacios:

```
MÉTODO USADO: [1/2/3]

RESULTADO:
[pega aquí el output del método que elegiste]
```

Ejemplo:
```
MÉTODO USADO: 2

RESULTADO:
Oreja clara: output[0][0]=85%, output[0][1]=10%, output[0][2]=5%
Oreja borrosa: output[0][0]=12%, output[0][1]=80%, output[0][2]=8%
No oreja: output[0][0]=3%, output[0][1]=5%, output[0][2]=92%
```
