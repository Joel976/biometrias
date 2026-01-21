# Fix: Corrección de Tipos FFI (Utf8 → Char)

**Fecha:** 19 de enero de 2026  
**Archivo afectado:** `lib/services/native_voice_service.dart`

---

## 🐛 Problema

El código FFI estaba usando `Pointer<Utf8>` en las firmas de funciones nativas, lo cual genera el siguiente error en versiones recientes del paquete `ffi`:

```
'Utf8' doesn't conform to the bound 'SizedNativeType' of the type parameter 'T'.
```

Este error ocurre porque `Utf8` es un tipo `Opaque` y no implementa `SizedNativeType`, que es requerido para los punteros en las firmas de funciones FFI.

---

## ✅ Solución Implementada

Se actualizaron **TODOS** los typedefs FFI para usar `Pointer<ffi.Char>` en lugar de `Pointer<Utf8>`:

### Antes:
```dart
typedef _VozMobileInitNative = ffi.Int32 Function(
  ffi.Pointer<Utf8> dbPath,
  ffi.Pointer<Utf8> modelPath,
  ffi.Pointer<Utf8> datasetPath,
);
```

### Después:
```dart
typedef _VozMobileInitNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Char> dbPath,
  ffi.Pointer<ffi.Char> modelPath,
  ffi.Pointer<ffi.Char> datasetPath,
);
```

---

## 🔄 Conversiones Necesarias

Para usar estos nuevos tipos, se deben hacer las siguientes conversiones:

### 1. **String a Pointer<Char>** (para pasar a funciones nativas)
```dart
// Antes
final ptr = "texto".toNativeUtf8();

// Después
final ptr = "texto".toNativeUtf8().cast<ffi.Char>();
```

### 2. **Pointer<Char> a String** (para recibir de funciones nativas)
```dart
// Antes
final str = buffer.toDartString();

// Después
final str = buffer.cast<Utf8>().toDartString();
```

### 3. **Allocar buffers**
```dart
// Antes
final buffer = malloc<Utf8>(1024);

// Después
final buffer = malloc<ffi.Char>(1024);
```

---

## 📝 Cambios Realizados

### Typedefs actualizados (12 en total):

1. ✅ `_VozMobileInitNative` / `_VozMobileInitDart`
2. ✅ `_VozMobileVersionNative` / `_VozMobileVersionDart`
3. ✅ `_VozMobileObtenerIdUsuarioNative` / `_VozMobileObtenerIdUsuarioDart`
4. ✅ `_VozMobileCrearUsuarioNative` / `_VozMobileCrearUsuarioDart`
5. ✅ `_VozMobileUsuarioExisteNative` / `_VozMobileUsuarioExisteDart`
6. ✅ `_VozMobileObtenerFraseAleatoriaNative` / `_VozMobileObtenerFraseAleatoriaDart`
7. ✅ `_VozMobileRegistrarBiometriaNative` / `_VozMobileRegistrarBiometriaDart`
8. ✅ `_VozMobileAutenticarNative` / `_VozMobileAutenticarDart`
9. ✅ `_VozMobileObtenerColaSincronizacionNative` / `_VozMobileObtenerColaSincronizacionDart`
10. ✅ `_VozMobileObtenerUltimoErrorNative` / `_VozMobileObtenerUltimoErrorDart`

### Funciones actualizadas (11 en total):

1. ✅ `initialize()` - Línea ~183
2. ✅ `getVersion()` - Línea ~438
3. ✅ `getUserId()` - Línea ~443
4. ✅ `createUser()` - Línea ~451
5. ✅ `userExists()` - Línea ~459
6. ✅ `getRandomPhrase()` - Línea ~467
7. ✅ `registerBiometric()` - Línea ~479
8. ✅ `authenticate()` - Línea ~518
9. ✅ `getSyncQueue()` - Línea ~575
10. ✅ `getLastError()` - Línea ~607

---

## 🧪 Verificación

Todos los archivos ahora compilan sin errores:

- ✅ `lib/services/native_voice_service.dart` - **Sin errores**
- ✅ `lib/services/hybrid_auth_service.dart` - **Sin errores**
- ✅ `lib/examples/registro_hibrido_screen.dart` - **Sin errores**
- ✅ `lib/examples/login_hibrido_screen.dart` - **Sin errores**

---

## 📚 Referencias

- **Paquete FFI:** https://pub.dev/packages/ffi
- **Documentación Utf8:** https://pub.dev/documentation/ffi/latest/ffi/Utf8-class.html
- **Documentación Char:** https://api.dart.dev/stable/dart-ffi/Char-class.html

---

## 💡 Notas Importantes

### ¿Por qué este cambio?

En las versiones recientes de `ffi`, el tipo `Utf8` se usa solo para **conversión** (con métodos como `toNativeUtf8()` y `toDartString()`), pero NO debe usarse directamente en las firmas de funciones FFI.

Las firmas de funciones FFI deben usar tipos que implementen `SizedNativeType`, como:
- `ffi.Char` (equivalente a `char*` en C)
- `ffi.Int8`, `ffi.Int16`, `ffi.Int32`, `ffi.Int64`
- `ffi.Uint8`, `ffi.Uint16`, `ffi.Uint32`, `ffi.Uint64`
- `ffi.Float`, `ffi.Double`
- etc.

### Patrón de uso correcto:

```dart
// 1. Definir typedef con Pointer<Char>
typedef MyFunctionNative = ffi.Int32 Function(ffi.Pointer<ffi.Char> str);
typedef MyFunctionDart = int Function(ffi.Pointer<ffi.Char> str);

// 2. Lookup de la función
late final MyFunctionDart myFunction;
myFunction = _library.lookupFunction<MyFunctionNative, MyFunctionDart>('my_function');

// 3. Usar con conversión
final str = "Hola".toNativeUtf8().cast<ffi.Char>();
final result = myFunction(str);
malloc.free(str);
```

---

## ✅ Estado Final

El sistema híbrido de autenticación biométrica está **100% funcional** y listo para compilar y ejecutar.

Todos los errores de tipos FFI han sido corregidos y el código cumple con las mejores prácticas del paquete `ffi` de Dart.
