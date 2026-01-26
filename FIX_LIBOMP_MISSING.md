# 🔧 FIX: libomp.so Missing - OpenMP Library Required

## ❌ Problema

```
dlopen failed: library "libomp.so" not found
needed by /data/app/.../liboreja_mobile.so
```

`liboreja_mobile.so` fue compilado con soporte OpenMP pero `libomp.so` no está incluida en el APK.

---

## ✅ Solución: Agregar libomp.so al Proyecto

### Opción 1: Descargar desde Android NDK (RECOMENDADO)

1. **Descargar NDK r25c** (o la versión que usaste para compilar):
   ```
   https://developer.android.com/ndk/downloads
   ```

2. **Ubicar libomp.so**:
   ```
   <NDK_PATH>/toolchains/llvm/prebuilt/<OS>/sysroot/usr/lib/aarch64-linux-android/libomp.so
   ```

3. **Copiar a jniLibs**:
   ```powershell
   # Desde PowerShell en mobile_app/
   Copy-Item -Path "<NDK_PATH>/toolchains/llvm/prebuilt/windows-x86_64/sysroot/usr/lib/aarch64-linux-android/libomp.so" `
             -Destination "android\app\src\main\jniLibs\arm64-v8a\libomp.so"
   ```

### Opción 2: Descargar Pre-compilado

1. **Desde repositorio oficial LLVM**:
   ```
   https://github.com/llvm/llvm-project/releases
   ```

2. **Extraer `libomp.so` para arm64-v8a**

3. **Copiar**:
   ```powershell
   Copy-Item -Path "path\to\libomp.so" `
             -Destination "android\app\src\main\jniLibs\arm64-v8a\libomp.so"
   ```

### Opción 3: Re-compilar sin OpenMP (SI NO NECESITAS PARALELISMO)

Si no necesitas procesamiento paralelo en `liboreja_mobile.so`:

1. **Modificar CMakeLists.txt** (en el proyecto nativo de oreja):
   ```cmake
   # ELIMINAR o COMENTAR:
   find_package(OpenMP REQUIRED)
   target_link_libraries(oreja_mobile PRIVATE OpenMP::OpenMP_CXX)
   ```

2. **Re-compilar** con:
   ```bash
   cmake -DCMAKE_BUILD_TYPE=Release \
         -DANDROID_ABI=arm64-v8a \
         -DANDROID_NDK=<NDK_PATH> \
         -DCMAKE_TOOLCHAIN_FILE=<NDK_PATH>/build/cmake/android.toolchain.cmake \
         ..
   make -j8
   ```

3. **Copiar nueva librería**:
   ```powershell
   Copy-Item -Path "build/liboreja_mobile.so" `
             -Destination "mobile_app/android/app/src/main/jniLibs/arm64-v8a/"
   ```

---

## 🚀 Verificación

Después de agregar `libomp.so`:

1. **Verificar archivos en jniLibs**:
   ```powershell
   cd mobile_app
   Get-ChildItem -Path "android\app\src\main\jniLibs\arm64-v8a\"
   ```

   Deberías ver:
   ```
   libc++_shared.so
   libomp.so           <-- NUEVA
   liboreja_mobile.so
   libvoice_mfcc.so
   libvoz_mobile.so
   ```

2. **Limpiar y recompilar**:
   ```powershell
   flutter clean
   flutter pub get
   flutter run --uninstall-first
   ```

3. **Probar registro de oreja**:
   - Capturar 5 fotos
   - Verificar logs:
     ```
     [NativeEarMobile] ✅ Inicializado correctamente
     [Register] ✅ Orejas registradas con LDA exitosamente
     ```

---

## 📋 Ubicaciones de libomp.so según NDK

| NDK Version | Ubicación                                                                  |
|-------------|---------------------------------------------------------------------------|
| r25c        | `toolchains/llvm/prebuilt/<OS>/sysroot/usr/lib/aarch64-linux-android/`   |
| r23b        | `toolchains/llvm/prebuilt/<OS>/sysroot/usr/lib/aarch64-linux-android/`   |
| r21e        | `sources/cxx-stl/llvm-libc++/libs/arm64-v8a/`                             |

**Nota**: `<OS>` puede ser `windows-x86_64`, `darwin-x86_64`, o `linux-x86_64`

---

## 🔍 Estado Actual

**Librerías en jniLibs/arm64-v8a:**
- ✅ `libc++_shared.so` (C++ runtime)
- ❌ `libomp.so` (FALTA - necesaria para OpenMP)
- ✅ `liboreja_mobile.so` (oreja biometrics)
- ✅ `libvoice_mfcc.so` (voice features)
- ✅ `libvoz_mobile.so` (voice biometrics)

**Comportamiento actual:**
- ❌ Registro de oreja falla con error `libomp.so not found`
- ✅ Fotos se guardan en cola de sincronización (fallback)
- ✅ Login con oreja funciona (usa backend API)
- ✅ Voz funciona perfectamente (no usa OpenMP)

---

## 🎯 Solución Rápida (SI TIENES NDK INSTALADO)

```powershell
# En mobile_app/

# 1. Buscar NDK instalado
echo $env:ANDROID_NDK_HOME

# 2. Copiar libomp.so
Copy-Item -Path "$env:ANDROID_NDK_HOME\toolchains\llvm\prebuilt\windows-x86_64\sysroot\usr\lib\aarch64-linux-android\libomp.so" `
          -Destination "android\app\src\main\jniLibs\arm64-v8a\libomp.so"

# 3. Verificar
Get-ChildItem "android\app\src\main\jniLibs\arm64-v8a\libomp.so"

# 4. Recompilar
flutter clean
flutter run --uninstall-first
```

---

## 📞 Alternativa: Deshabilitar Temporalmente

Si no puedes agregar `libomp.so` ahora, el sistema funciona con el **fallback al backend**:

1. **Registro**: Fotos se guardan en `sync_queue` → se envían al backend cuando haya conexión
2. **Login**: Usa API del backend directamente
3. **Offline completo**: Solo funciona si el backend ya procesó las fotos

**Para habilitar offline completo NECESITAS**:
- ✅ `libomp.so` instalada
- ✅ Modelos LDA/PCA cargados
- ✅ Templates locales actualizados

---

*Fecha: 25 enero 2026*
*Problema: libomp.so missing for liboreja_mobile.so*
*Solución: Agregar libomp.so desde Android NDK*
