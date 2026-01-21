# 🚀 Compilar Librería Nativa para APK

## ¿Qué hace esto?

Compila `libvoz_mobile.so` (Android) automáticamente cuando creas la APK.

## 📋 Archivos Configurados

✅ `CMakeLists.txt` (raíz del proyecto)
✅ `mobile_app/android/app/build.gradle.kts` (configurado con externalNativeBuild)
✅ `apps/mobile/` (código C++ de la API móvil)
✅ `external/` (SQLite amalgamation completo)

## 🔨 Compilar APK con librería nativa

### Opción 1: Compilar APK completa (Debug)

```powershell
cd mobile_app
flutter build apk --debug
```

**Resultado**: 
- APK en `mobile_app/build/app/outputs/flutter-apk/app-debug.apk`
- Incluye `libvoz_mobile.so` compilado automáticamente por Gradle NDK

### Opción 2: Compilar APK (Release)

```powershell
cd mobile_app
flutter build apk --release
```

**Resultado**:
- APK optimizada en `mobile_app/build/app/outputs/flutter-apk/app-release.apk`
- `libvoz_mobile.so` optimizado con `-O3` y strip

### Opción 3: Solo compilar librería nativa (sin APK completa)

```powershell
cd mobile_app/android
./gradlew :app:externalNativeBuildDebug
```

**Resultado**:
- Librería en `mobile_app/android/app/.cxx/Debug/*/libvoz_mobile.so`
- Para cada arquitectura (arm64-v8a, armeabi-v7a, x86, x86_64)

## 📱 Arquitecturas Soportadas

El `build.gradle.kts` está configurado para compilar para:

- ✅ **arm64-v8a** (64-bit ARM - mayoría de dispositivos modernos)
- ✅ **armeabi-v7a** (32-bit ARM - dispositivos antiguos)
- ✅ **x86_64** (Emuladores Android x64)
- ✅ **x86** (Emuladores Android x86)

Si solo quieres una arquitectura específica (APK más pequeña):

```kotlin
// En build.gradle.kts, línea ~35
abiFilters += listOf("arm64-v8a")  // Solo 64-bit
```

## 🔍 Verificar que la librería se compiló

Después de compilar, verifica:

```powershell
# Listar librerías en la APK
cd mobile_app
flutter build apk --debug
jar -tf build/app/outputs/flutter-apk/app-debug.apk | findstr "libvoz_mobile.so"
```

**Salida esperada**:
```
lib/arm64-v8a/libvoz_mobile.so
lib/armeabi-v7a/libvoz_mobile.so
lib/x86/libvoz_mobile.so
lib/x86_64/libvoz_mobile.so
```

## 🐛 Problemas Comunes

### Error: "CMake not found"

**Solución**: Flutter usa el CMake del Android SDK automáticamente. Si falla:

```powershell
# Verificar SDK Manager
flutter doctor -v

# Instalar NDK y CMake si faltan
# Abre Android Studio → Tools → SDK Manager → SDK Tools
# Marca: NDK, CMake
```

### Error: "sqlite3.c not found"

**Causa**: Archivos SQLite no están en `external/`

**Solución**:
```powershell
# Verificar que existen
ls external\sqlite3.*

# Si no existen, copiarlos desde offline_voice
copy offline_voice\apps\mobile\sqlite3.* external\
```

### APK muy grande (>100MB)

**Causa**: Incluye todas las arquitecturas

**Solución**: Compilar solo arm64-v8a
```powershell
flutter build apk --release --split-per-abi
```

Esto genera 4 APKs separadas (una por arquitectura).

## 🎯 Usar la librería desde Dart (Flutter)

Después de compilar, úsala con FFI:

```dart
import 'dart:ffi' as ffi;
import 'dart:io';

// Cargar librería
final DynamicLibrary vozLib = Platform.isAndroid
    ? ffi.DynamicLibrary.open('libvoz_mobile.so')
    : ffi.DynamicLibrary.open('libvoz_mobile.dylib');

// Definir funciones
typedef VozInitNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Utf8> dbPath,
  ffi.Pointer<ffi.Utf8> modelPath,
  ffi.Pointer<ffi.Utf8> datasetPath
);

typedef VozInitDart = int Function(
  ffi.Pointer<ffi.Utf8> dbPath,
  ffi.Pointer<ffi.Utf8> modelPath,
  ffi.Pointer<ffi.Utf8> datasetPath
);

// Vincular
final int Function(ffi.Pointer<ffi.Utf8>, ffi.Pointer<ffi.Utf8>, ffi.Pointer<ffi.Utf8>) vozInit =
    vozLib.lookup<ffi.NativeFunction<VozInitNative>>('voz_mobile_init').asFunction<VozInitDart>();

// Usar
final dbPath = '/data/data/com.example.app/databases/voz.db'.toNativeUtf8();
final result = vozInit(dbPath, ffi.nullptr, ffi.nullptr);
print('Init result: $result');
```

## ✅ Próximos Pasos

1. **Compilar APK**:
   ```powershell
   cd mobile_app
   flutter build apk --debug
   ```

2. **Instalar en dispositivo**:
   ```powershell
   flutter install
   ```

3. **Probar autenticación offline**:
   - Activar modo avión
   - Registrar usuario con voz
   - Autenticar → Debe funcionar SIN internet

## 📊 Flujo de Compilación

```
Flutter build APK
    ↓
Gradle detecta externalNativeBuild
    ↓
Ejecuta CMakeLists.txt con Android NDK
    ↓
Compila mobile_api.cpp + sqlite_adapter.cpp + core/*.cpp
    ↓
Genera libvoz_mobile.so (4 arquitecturas)
    ↓
Gradle empaqueta .so en APK
    ↓
APK lista con autenticación offline
```

## 🎉 Resultado Final

Tu APK tendrá:
- ✅ Autenticación por voz OFFLINE (SQLite local)
- ✅ Autenticación ONLINE (PostgreSQL servidor)
- ✅ Sincronización automática cuando haya internet
- ✅ Funciona sin CMake en el dispositivo (todo está compilado en la APK)

---

**¿Siguiente paso?** Ejecuta:
```powershell
cd mobile_app
flutter build apk --debug
```

Y prueba la APK en tu dispositivo! 📱
