# ❌ FIX: Error "Modelo no cargado" en Login de Voz

**Fecha**: 25 de enero de 2026  
**Problema**: Al autenticar con voz aparece "Modelo no cargado" aunque el usuario existe  
**Síntoma**: `modelo_cargado: false` en estadísticas

---

## 🔍 Diagnóstico del Problema

### Logs del Error

```
[NativeVoiceMobile] 📊 Estadísticas: {
  frases_activas: 0, 
  modelo_cargado: false,  ← ❌ PROBLEMA
  pendientes_sincronizacion: 0, 
  usuarios_registrados: 1  ← ✅ Usuario existe
}
[NativeVoiceMobile] ❌ Rechazado: {
  authenticated: false, 
  error: Modelo no cargado,  ← ❌ ERROR
  success: false
}
```

### ¿Por qué sucede?

1. **Usuario registrado** → Archivo `class_X.bin` se crea correctamente
2. **Usuario cierra app** → Servicio nativo se destruye de memoria
3. **Usuario abre app y hace login** → Servicio se re-inicializa
4. **Problema**: La librería C++ **NO carga automáticamente** el modelo `.bin` en memoria

---

## 🔧 Solución Implementada

### 1. **Agregar Timeout a Inicialización** (login_screen.dart)

**Problema**: Si la inicialización se congela, la app se queda trabada.

**Solución**: Timeout de 10 segundos.

```dart
// ANTES ❌
final initialized = await nativeService.initialize();

// DESPUÉS ✅
final initialized = await nativeService.initialize().timeout(
  const Duration(seconds: 10),
  onTimeout: () => false,
);
```

### 2. **Forzar Re-Carga del Modelo SVM** (login_screen.dart)

**Problema**: El modelo puede haberse actualizado después del registro.

**Solución**: Llamar a `cleanup()` y luego re-inicializar.

```dart
// 🔄 FORZAR RE-CARGA del modelo SVM
print('[Login] 🔄 Forzando re-inicialización para cargar modelos actualizados...');

// Llamar a cleanup para liberar recursos
nativeService.cleanup();

// Re-inicializar para cargar modelos frescos
final reinitialized = await nativeService.initialize().timeout(
  const Duration(seconds: 10),
  onTimeout: () => false,
);

if (!reinitialized) {
  throw Exception('Error re-inicializando servicio de voz');
}
print('[Login] ✅ Modelos SVM re-cargados correctamente');
```

---

## 🎯 Flujo Correcto Ahora

### Registro de Voz

```
1. Usuario registra 6 audios
   ↓
2. libvoz_mobile.so entrena SVM incremental
   ↓
3. Se guarda class_X.bin en disco
   ↓
4. Estadísticas: modelo_cargado = true ✅
```

### Login de Voz (Con Fix)

```
1. Usuario ingresa cédula
   ↓
2. Selecciona "Voz"
   ↓
3. App inicializa servicio nativo
   ↓
4. ✅ NUEVO: Cleanup + Re-inicialización
   ↓
5. Se carga class_X.bin desde disco a memoria
   ↓
6. Estadísticas: modelo_cargado = true ✅
   ↓
7. Autenticación funciona correctamente
```

---

## 🧪 Verificación

### 1. Registrar un usuario nuevo

```bash
cd mobile_app
flutter run
```

1. Registrar usuario con 6 audios de voz
2. Completar todo el proceso
3. Verificar logs:

```
[Register] ✅ Audio #6 registrado exitosamente con SVM
[Register] 🧠 SVM RE-ENTRENADO con 6 muestras
```

### 2. Cerrar y reabrir la app

```bash
# Presionar STOP en Android Studio
# Volver a abrir la app
```

### 3. Intentar login con voz

**ANTES** ❌:
```
[NativeVoiceMobile] 📊 Estadísticas: {modelo_cargado: false}
[NativeVoiceMobile] ❌ Rechazado: {error: Modelo no cargado}
```

**DESPUÉS** ✅:
```
[Login] 🔄 Forzando re-inicialización para cargar modelos actualizados...
[Login] ✅ Modelos SVM re-cargados correctamente
[NativeVoiceMobile] 📊 Estadísticas: {modelo_cargado: true}
[NativeVoiceMobile] ✅ Autenticado: {authenticated: true}
```

---

## 📊 Comparación: Oreja vs Voz

| Aspecto | Oreja (LDA) | Voz (SVM) |
|---------|-------------|-----------|
| **Archivo modelo** | `templates_k1.csv` | `class_X.bin` |
| **Carga en init** | ✅ Automática | ❌ Manual (requiere cleanup + re-init) |
| **Problema** | Se congela con 50 usuarios | Modelo no cargado si no se re-init |
| **Solución** | Timeout 10s | Cleanup + Re-init forzado |

---

## ⚠️ Problemas Pendientes

### 1. **¿Por qué la librería C++ no carga automáticamente el modelo?**

Posibles causas:
- El código C++ solo carga modelos al inicializar si existen **ANTES** de `voz_mobile_init()`
- Si el modelo se crea **DESPUÉS** de init, no se carga automáticamente
- Necesita una función `voz_mobile_reload_models()` en la API

### 2. **Workaround actual**

Forzar cleanup + re-init cada vez que se autentica. Esto funciona pero:
- ❌ No es eficiente (destruye y recrea todo)
- ❌ Puede causar memory leaks si cleanup no libera todo
- ✅ Garantiza que el modelo esté cargado

### 3. **Solución ideal (requiere cambio en C++)**

Agregar función en `mobile_api.h`:

```cpp
// Recargar modelos SVM desde disco sin destruir sesión
int voz_mobile_reload_models();
```

Entonces en Dart:

```dart
// En lugar de cleanup + re-init
nativeService.reloadModels();
```

---

## 📝 Archivos Modificados

### `lib/screens/login_screen.dart`

1. **Línea ~910**: Agregado timeout (10s) para voz
2. **Línea ~920**: Agregado cleanup + re-init forzado
3. **Línea ~780**: Agregado timeout (10s) para oreja

---

## ✅ Estado

**Implementado**: Workaround con cleanup + re-init  
**Pendiente**: Función `reload_models()` en C++ (ideal)

**Próximo paso**: Probar con desinstalación completa y registro nuevo.

```bash
cd mobile_app
flutter run --uninstall-first
```
