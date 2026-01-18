# 🪟 COMPILAR LIBRERÍA NATIVA EN WINDOWS

## ⚠️ Problema con WSL

El error que obtuviste indica que **WSL (Windows Subsystem for Linux)** no está instalado o configurado correctamente:

```
WSL (9) ERROR: CreateProcessEntryCommon:505: execvpe /bin/bash failed 2
```

**Solución:** Usa los scripts `.bat` nativos de Windows en lugar de `.sh`

---

## 🛠️ Opción 1: Usar ndk-build (RECOMENDADO - Más Simple)

### Paso 1: Verificar Android NDK

Verifica que tienes Android NDK instalado:

```powershell
# Buscar en Android SDK
dir "C:\Users\User\AppData\Local\Android\Sdk\ndk"

# O en Android Studio
dir "C:\Program Files\Android\Android Studio\ndk"
```

### Paso 2: Configurar Variable de Entorno

```powershell
# PowerShell (temporal)
$env:ANDROID_NDK = "C:\Users\User\AppData\Local\Android\Sdk\ndk\26.1.10909125"

# O permanente (Panel de Control > Sistema > Variables de entorno)
# Crear variable ANDROID_NDK con la ruta a tu carpeta NDK
```

**Ejemplo de ruta NDK:**
- `C:\Users\User\AppData\Local\Android\Sdk\ndk\26.1.10909125`
- `C:\Users\User\AppData\Local\Android\Sdk\ndk\25.2.9519653`

### Paso 3: Compilar

```cmd
cd C:\Users\User\Downloads\biometrias\native\voice_mfcc
build_ndk.bat
```

**Salida esperada:**
```
============================================
 Compilando con ndk-build (metodo simple)
============================================

[INFO] NDK: C:\Users\User\AppData\Local\Android\Sdk\ndk\26.1.10909125
[INFO] ndk-build encontrado
[INFO] Creando Android.mk...
[INFO] Creando Application.mk...

[BUILD] Compilando con ndk-build...

[armeabi-v7a] Compile++ arm  : voice_mfcc <= voice_mfcc.cpp
[armeabi-v7a] SharedLibrary  : libvoice_mfcc.so
[arm64-v8a] Compile++        : voice_mfcc <= voice_mfcc.cpp
[arm64-v8a] SharedLibrary    : libvoice_mfcc.so
[x86_64] Compile++           : voice_mfcc <= voice_mfcc.cpp
[x86_64] SharedLibrary       : libvoice_mfcc.so

[INFO] Copiando librerias a jniLibs...

============================================
 Compilacion exitosa!
============================================

Librerias generadas en:
C:\...\mobile_app\android\app\src\main\jniLibs\arm64-v8a\libvoice_mfcc.so
C:\...\mobile_app\android\app\src\main\jniLibs\armeabi-v7a\libvoice_mfcc.so
C:\...\mobile_app\android\app\src\main\jniLibs\x86_64\libvoice_mfcc.so
```

---

## 🛠️ Opción 2: Usar CMake + Ninja (Avanzado)

### Requisitos

1. **CMake instalado:**
   ```powershell
   # Verificar si CMake está instalado
   cmake --version
   
   # Si no está instalado:
   choco install cmake
   # O descargar desde: https://cmake.org/download/
   ```

2. **Ninja instalado:**
   ```powershell
   choco install ninja
   # O descargar desde: https://github.com/ninja-build/ninja/releases
   ```

3. **Android NDK configurado:**
   ```powershell
   $env:ANDROID_NDK = "C:\Users\User\AppData\Local\Android\Sdk\ndk\[version]"
   ```

### Compilar

```cmd
cd C:\Users\User\Downloads\biometrias\native\voice_mfcc
build_android.bat
```

---

## 🛠️ Opción 3: Instalar WSL (Para usar build_android.sh)

Si prefieres usar el script `.sh` original:

### Paso 1: Instalar WSL

```powershell
# PowerShell como Administrador
wsl --install
```

Reinicia tu computadora después de la instalación.

### Paso 2: Instalar Ubuntu

```powershell
wsl --install -d Ubuntu
```

### Paso 3: Compilar

```powershell
cd C:\Users\User\Downloads\biometrias\native\voice_mfcc
wsl bash build_android.sh
```

---

## ❓ ¿Qué NDK Necesito?

### Encontrar tu NDK en Android Studio

1. Abre **Android Studio**
2. Ve a **Tools > SDK Manager**
3. Pestaña **SDK Tools**
4. Marca **NDK (Side by side)**
5. Clic en **Apply** para instalar

### Rutas Comunes de NDK

Windows:
```
C:\Users\[Usuario]\AppData\Local\Android\Sdk\ndk\[version]
```

**Verificar versión instalada:**
```cmd
dir "C:\Users\User\AppData\Local\Android\Sdk\ndk"
```

---

## 🔍 Troubleshooting

### Error: "ndk-build.cmd no encontrado"

**Causa:** Variable `ANDROID_NDK` apunta a la carpeta incorrecta

**Solución:**
```powershell
# Buscar ndk-build.cmd
dir "C:\Users\User\AppData\Local\Android\Sdk" /s /b | findstr ndk-build.cmd

# Configurar ANDROID_NDK a la carpeta que contiene ndk-build.cmd
# Ejemplo:
$env:ANDROID_NDK = "C:\Users\User\AppData\Local\Android\Sdk\ndk\26.1.10909125"
```

---

### Error: "CMake no está instalado"

**Solución 1 - Usar ndk-build (más simple):**
```cmd
build_ndk.bat
```

**Solución 2 - Instalar CMake:**
```powershell
choco install cmake
```

O descargar desde: https://cmake.org/download/

---

### Error: "Ninja not found"

**Solución 1 - Modificar build_android.bat:**

Edita `build_android.bat` y cambia la línea:
```batch
-G "Ninja" ^
```

Por:
```batch
-G "MinGW Makefiles" ^
```

**Solución 2 - Instalar Ninja:**
```powershell
choco install ninja
```

---

## ✅ Verificar que Funcionó

Después de compilar, verifica que las librerías existan:

```cmd
dir C:\Users\User\Downloads\biometrias\mobile_app\android\app\src\main\jniLibs\*\*.so /s
```

**Deberías ver:**
```
libvoice_mfcc.so en arm64-v8a
libvoice_mfcc.so en armeabi-v7a
libvoice_mfcc.so en x86_64
```

---

## 🚀 Después de Compilar

```powershell
cd C:\Users\User\Downloads\biometrias\mobile_app
flutter clean
flutter pub get
flutter build apk --release
```

Luego verifica los logs al ejecutar la app:

```
[VoiceNative] ✅ Librería nativa cargada correctamente
[libvoice_mfcc] 🎤 Iniciando extracción de MFCCs...
```

---

## 📋 Resumen de Scripts Disponibles

| Script | Método | Requisitos | Dificultad |
|--------|--------|-----------|-----------|
| `build_ndk.bat` | ndk-build | Solo NDK | ⭐ Fácil |
| `build_android.bat` | CMake + Ninja | NDK + CMake + Ninja | ⭐⭐⭐ Difícil |
| `build_android.sh` | CMake (Bash) | NDK + WSL/Linux | ⭐⭐ Media |

**RECOMENDACIÓN:** Usa `build_ndk.bat` (más simple y directo)

---

## 🎯 Próximos Pasos

1. ✅ Ejecutar `build_ndk.bat`
2. ✅ Verificar que se crearon las `.so`
3. ✅ `flutter clean && flutter build apk`
4. ✅ Probar en dispositivo Android
5. ✅ Buscar logs de VoiceNative para confirmar FFI

**¿Necesitas ayuda configurando el NDK?** 🤔
