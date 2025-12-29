# 🧠 Validación de Orejas con TensorFlow Lite

## ¿Qué hace?

El sistema ahora valida que las fotos capturadas sean realmente **orejas** usando un modelo de Machine Learning (TensorFlow Lite) antes de aceptarlas para registro o login.

## Implementación

### 📦 Archivos Creados

1. **`lib/services/ear_validator_service.dart`**
   - Servicio singleton que carga el modelo `.tflite`
   - Valida imágenes con confianza mínima del 70%
   - Retorna `EarDetectionResult` con:
     - `isEar`: boolean indicando si es oreja
     - `confidence`: nivel de confianza (0.0 a 1.0)
     - `error`: mensaje de error si falla la validación
     - `isValid`: helper que combina `isEar && error == null`

### 🔧 Archivos Modificados

1. **`pubspec.yaml`**
   - Agregado: `tflite_flutter: ^0.10.4`

2. **`lib/screens/register_screen.dart`**
   - Importado: `EarValidatorService`
   - Inicializado en `_initializeServices()`
   - Validación en `_captureEarPhoto()`:
     ```dart
     final validationResult = await _earValidator.validateEar(result);
     
     if (!validationResult.isValid) {
       // Rechazar foto con mensaje de error
       return;
     }
     
     // Aceptar foto ✅
     ```

3. **`lib/screens/login_screen.dart`**
   - Importado: `EarValidatorService`
   - Inicializado en `_initializeServices()`
   - Validación en `_capturePhotoForAuth()`:
     ```dart
     final validationResult = await _earValidator.validateEar(photoBytes);
     
     if (!validationResult.isValid) {
       // Rechazar foto con mensaje de error
       return;
     }
     
     // Continuar con autenticación ✅
     ```

## 📋 Cómo Funciona

### Flujo de Registro
1. Usuario captura foto de oreja
2. **🧠 VALIDACIÓN CON IA:**
   - Se redimensiona imagen a 224x224
   - Se normaliza a valores 0-1
   - Se pasa por el modelo TensorFlow
   - Se obtiene probabilidad de que sea oreja
3. Si confianza < 70%:
   - ❌ Foto rechazada
   - Mensaje: "No parece ser una oreja válida (XX.X%)"
4. Si confianza >= 70%:
   - ✅ Foto aceptada
   - Mensaje: "Foto 1 de oreja capturada (XX.X%)"
5. Usuario completa 3 fotos válidas
6. Registro exitoso

### Flujo de Login
1. Usuario selecciona autenticación por oreja
2. Captura foto
3. **🧠 VALIDACIÓN CON IA:**
   - Mismo proceso que registro
4. Si válida:
   - ✅ Continúa con comparación biométrica
5. Si inválida:
   - ❌ Rechazada antes de consultar backend

## ⚙️ Configuración del Modelo

### Ubicación del Modelo
```
assets/models/modelo_oreja.tflite
```

### Parámetros Actuales
```dart
static const int _inputWidth = 224;
static const int _inputHeight = 224;
static const int _numChannels = 3; // RGB
static const double _confidenceThreshold = 0.7; // 70%
```

### Ajustar Umbral de Confianza
Si el modelo es muy estricto o muy permisivo, puedes ajustar el umbral en:

```dart
// ear_validator_service.dart línea 18
static const double _confidenceThreshold = 0.7; // Cambiar este valor

// Opciones:
// 0.5 = 50% - Más permisivo (acepta más fotos)
// 0.7 = 70% - Balanceado (recomendado)
// 0.9 = 90% - Muy estricto (solo fotos perfectas)
```

## 🧪 Cómo Probar

### 1. Ejecutar la App
```powershell
cd C:\Users\User\Downloads\biometrias\mobile_app
flutter run
```

### 2. Probar en Registro
1. Click en "¿No tienes cuenta? Regístrate"
2. Llenar datos personales
3. Click "Siguiente"
4. En "Paso 2: Fotos de Oreja":
   - **Prueba con oreja real**: Debería aceptar (✅ verde)
   - **Prueba con otra cosa**: Debería rechazar (❌ rojo)
5. Observa los mensajes:
   - ✅ "Foto 1 de oreja capturada (85.3%)"
   - ❌ "No es una oreja válida (42.1%)"

### 3. Probar en Login
1. En pantalla de login
2. Asegúrate que "Usar biometría" esté activado
3. Click en botón de cámara
4. Captura foto
5. Observa validación:
   - ✅ Verde: "Foto capturada (78.9%)"
   - ❌ Rojo: "No es una oreja válida (35.2%)"

### 4. Ver Logs en Consola
El servicio imprime información útil:
```
[EarValidator] 🧠 Modelo cargado exitosamente
[EarValidator] 📐 Input shape: [1, 224, 224, 3]
[EarValidator] 📐 Output shape: [1, 2]
[EarValidator] 🎯 Resultado: ES OREJA
[EarValidator] 📊 Confianza: 87.65%
```

## ✅ Ventajas

1. **Seguridad Mejorada**: No se puede registrar/autenticar con fotos de otras cosas
2. **Feedback Inmediato**: Usuario sabe al instante si la foto es válida
3. **Ahorro de Recursos**: No se envían fotos inválidas al backend
4. **Mejor UX**: Mensajes claros con porcentaje de confianza

## ⚠️ Notas Importantes

### Formato del Modelo
El código asume que el modelo tiene:
- **Input**: Tensor de forma `[1, 224, 224, 3]` (imagen RGB)
- **Output**: Tensor de forma `[1, 2]` (clasificación binaria)
  - `output[0][0]`: probabilidad de NO ser oreja
  - `output[0][1]`: probabilidad de SER oreja

Si tu modelo es diferente, ajusta:
1. Las dimensiones en las constantes
2. El procesamiento del output en `validateEar()`

### Rendimiento
- Primera validación: ~500ms (carga del modelo)
- Validaciones siguientes: ~100-200ms (modelo en memoria)

### Memoria
El modelo se mantiene en memoria durante toda la sesión para mejor rendimiento. Se libera al cerrar la app.

## 🛠️ Solución de Problemas

### Error: "No se pudo cargar el modelo"
- Verifica que `assets/models/modelo_oreja.tflite` existe
- Verifica que `pubspec.yaml` incluye `assets/models/` en assets
- Ejecuta `flutter clean` y `flutter pub get`

### Error: "The name 'EarValidationResult' is defined in multiple libraries"
- Ya solucionado: la clase se renombró a `EarDetectionResult`

### Todas las fotos son rechazadas
- El modelo puede necesitar reentrenamiento
- Baja el umbral de confianza temporalmente para probar
- Verifica que las fotos tengan buena iluminación

### Todas las fotos son aceptadas
- El modelo puede ser muy permisivo
- Sube el umbral de confianza
- Verifica que el modelo esté correctamente entrenado

## 📊 Próximos Pasos (Opcional)

1. **Mejorar el Modelo**:
   - Entrenar con más datos
   - Usar data augmentation
   - Probar arquitecturas como MobileNetV2, EfficientNet

2. **Feedback Visual**:
   - Mostrar preview con overlay indicando si es oreja
   - Agregar guías visuales para posicionar la oreja

3. **Analytics**:
   - Registrar cuántas fotos son rechazadas
   - Identificar patrones de error

4. **Optimización**:
   - Cuantizar el modelo (reducir tamaño)
   - Usar GPU delegates para inferencia más rápida
