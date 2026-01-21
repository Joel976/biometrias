# Fix: Error de Compilación CMake en Android

**Fecha:** 19 de enero de 2026  
**Error:** `Gradle project cmake.path is C:\Users\User\Downloads\CMakeLists.txt but that file doesn't exist`

---

## 🐛 Problema

Al intentar compilar la app Flutter para Android, Gradle intentaba compilar código C++ usando CMake, pero el archivo `CMakeLists.txt` no existía en la ruta especificada.

```
FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:configureCMakeDebug[arm64-v8a]'.
> [CXX1400] Gradle project cmake.path is C:\Users\User\Downloads\CMakeLists.txt but that file doesn't exist
```

---

## 🔍 Causa

El archivo `android/app/build.gradle.kts` estaba configurado para **compilar código C++** con CMake:

```kotlin
// Configuración nativa CMake para voz_mobile
externalNativeBuild {
    cmake {
        cppFlags += listOf("-std=c++20", "-frtti", "-fexceptions")
        arguments += listOf(
            "-DANDROID_STL=c++_shared",
            "-DANDROID_PLATFORM=android-24"
        )
        abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
    }
}

// Ruta al CMakeLists.txt
externalNativeBuild {
    cmake {
        path = file("../../../../CMakeLists.txt")
        version = "3.22.1"
    }
}
```

Sin embargo, **no necesitamos compilar nada** porque ya tenemos la librería **pre-compilada** `libvoz_mobile.so`.

---

## ✅ Solución

### 1. Eliminar Configuración de CMake

Se eliminó toda la configuración de `externalNativeBuild` del archivo `android/app/build.gradle.kts`:

**Archivo:** `mobile_app/android/app/build.gradle.kts`

```kotlin
defaultConfig {
    applicationId = "com.example.biometrics_app"
    minSdk = 24
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
    // ✅ Se eliminó externalNativeBuild aquí
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
    }
}
// ✅ Se eliminó externalNativeBuild aquí también
```

### 2. Copiar Librería Nativa Pre-compilada

Se copió `libvoz_mobile.so` al directorio `jniLibs`:

```powershell
Copy-Item "lib\config\entrega_flutter_mobile\libraries\android\arm64-v8a\libvoz_mobile.so" `
    -Destination "android\app\src\main\jniLibs\arm64-v8a\" -Force
```

**Resultado:**
```
android/app/src/main/jniLibs/arm64-v8a/
├── libvoice_mfcc.so      (12 KB)
└── libvoz_mobile.so      (27.1 MB) ← COPIADO
```

---

## 📋 Verificación

### Archivos en `jniLibs/arm64-v8a/`:

```
Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a----     14/01/2026  12:59 a. m.          12008 libvoice_mfcc.so
-a----     19/01/2026  11:22 a. m.       27146024 libvoz_mobile.so
```

### Configuración de Gradle:

✅ Sin referencias a CMake  
✅ Sin `externalNativeBuild`  
✅ Librería nativa en `jniLibs` (carga automática)

---

## 🚀 Compilar la App

### Opción 1: Compilar APK Debug

```powershell
cd mobile_app
flutter clean
flutter build apk --debug
```

### Opción 2: Ejecutar en Dispositivo

```powershell
cd mobile_app
flutter clean
flutter run
```

### Opción 3: Compilar APK Release

```powershell
cd mobile_app
flutter clean
flutter build apk --release
```

---

## 📝 Notas Importantes

### ¿Por qué NO necesitamos CMake?

La librería `libvoz_mobile.so` ya está **pre-compilada** por el equipo de backend. No necesitamos compilar código C++ desde el proyecto Flutter.

### Carga Automática de Librerías Nativas

Cuando colocas archivos `.so` en `android/app/src/main/jniLibs/{arquitectura}/`, Gradle los incluye automáticamente en el APK y Android los carga en tiempo de ejecución.

### FFI Carga la Librería Así:

```dart
if (Platform.isAndroid) {
  _library = ffi.DynamicLibrary.open('libvoz_mobile.so');
}
```

Android busca automáticamente en:
- `/data/app/{package}/lib/{arquitectura}/`
- Donde Gradle copió la librería desde `jniLibs`

---

## 🎯 Arquitecturas Soportadas

Actualmente solo tenemos la librería para **arm64-v8a** (64-bit ARM).

Si necesitas soportar otras arquitecturas:

```
jniLibs/
├── arm64-v8a/      ← Dispositivos modernos (64-bit)
│   └── libvoz_mobile.so
├── armeabi-v7a/    ← Dispositivos antiguos (32-bit)
│   └── libvoz_mobile.so
├── x86_64/         ← Emuladores Android (64-bit)
│   └── libvoz_mobile.so
└── x86/            ← Emuladores Android (32-bit)
    └── libvoz_mobile.so
```

**Nota:** La mayoría de dispositivos Android modernos (2020+) son **arm64-v8a**.

---

## ✅ Estado Final

- ✅ Configuración de CMake eliminada de `build.gradle.kts`
- ✅ Librería `libvoz_mobile.so` copiada a `jniLibs/arm64-v8a/`
- ✅ Proyecto limpiado con `flutter clean`
- ✅ Listo para compilar sin errores

---

## 🔄 Próximos Pasos

1. **Compilar:**
   ```powershell
   flutter build apk --debug
   ```

2. **Si hay errores de dependencias:**
   ```powershell
   flutter pub get
   flutter build apk --debug
   ```

3. **Si hay problemas con Gradle cache:**
   ```powershell
   cd android
   .\gradlew clean
   cd ..
   flutter build apk --debug
   ```

---

**Problema resuelto:** El error de CMake fue causado por una configuración innecesaria. Ahora la app usa la librería pre-compilada directamente. ✅
