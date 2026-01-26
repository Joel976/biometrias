# 🎯 Para el compañero: Cómo compilar liboreja_mobile.so

## ✅ Ya está TODO listo

Tu código C++ ya está perfecto. Solo falta compilar el `.so` y probarlo.

---

## 📋 Qué ya está hecho

1. ✅ **Código C++ completo** con `oreja_mobile_reload_templates()`
2. ✅ **Header actualizado** (`oreja_mobile_api.h`) con la declaración
3. ✅ **Dart FFI binding** (`native_ear_mobile_service.dart`) configurado
4. ✅ **Login screen** llama automáticamente a `reloadTemplates()`

**Solo falta**: Compilar el `.so` para Android ARM64

---

## 🔧 Opción 1: Compilar con Flutter (RECOMENDADO)

Esta es la forma más fácil:

```bash
# Ir al directorio del proyecto
cd mobile_app

# Limpiar builds anteriores
flutter clean

# Obtener dependencias
flutter pub get

# Compilar para Android (incluye compilación de .so nativo)
flutter build apk --release
```

**Qué hace este comando**:
- Lee `CMakeLists.txt` en `lib/entrega_flutter_oreja/`
- Compila `oreja_mobile_api.cpp` usando Android NDK
- Genera `liboreja_mobile.so` para ARM64
- Lo incluye automáticamente en el APK

**Resultado**: APK listo para instalar con el `.so` actualizado

---

## 🔧 Opción 2: Compilar manualmente con CMake

Si prefieres compilar el `.so` por separado:

### Paso 1: Verificar que tienes Android NDK

```bash
echo $ANDROID_NDK_HOME
# Debería mostrar algo como: /Users/tu-usuario/Android/sdk/ndk/25.1.8937393
```

Si no está configurado:
```bash
# En Flutter, el NDK suele estar en:
export ANDROID_NDK_HOME=$HOME/Android/sdk/ndk/25.1.8937393

# O en Windows:
set ANDROID_NDK_HOME=C:\Users\User\AppData\Local\Android\sdk\ndk\25.1.8937393
```

### Paso 2: Compilar con CMake

```bash
cd mobile_app/lib/entrega_flutter_oreja

# Crear directorio de build
mkdir -p build/android-arm64
cd build/android-arm64

# Configurar con CMake para Android ARM64
cmake ../.. \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-21 \
  -DCMAKE_BUILD_TYPE=Release

# Compilar
make -j8
```

**Resultado**: `build/android-arm64/liboreja_mobile.so`

### Paso 3: Copiar al proyecto Flutter

```bash
# Copiar al directorio jniLibs
mkdir -p ../../../../android/app/src/main/jniLibs/arm64-v8a/
cp liboreja_mobile.so ../../../../android/app/src/main/jniLibs/arm64-v8a/

# También copiar a debug si es necesario
mkdir -p ../../../../android/app/src/debug/jniLibs/arm64-v8a/
cp liboreja_mobile.so ../../../../android/app/src/debug/jniLibs/arm64-v8a/
```

### Paso 4: Verificar que la función esté exportada

```bash
# Ver símbolos exportados
nm -D liboreja_mobile.so | grep reload

# Deberías ver:
# 00001234 T oreja_mobile_reload_templates
```

Si **NO** aparece:
- Verifica que el código C++ tenga `extern "C"`
- Verifica que el header tenga la declaración
- Recompila con `make clean && make`

---

## 🧪 Probar la app

```bash
cd mobile_app

# Desinstalar app anterior (importante para limpiar datos)
flutter run --uninstall-first
```

### Logs esperados:

#### Al abrir la app por primera vez:
```
[NativeEarMobile] 🚀 Inicializando...
[NativeEarMobile] ✅ Librería cargada
[NativeEarMobile] ✅ Funciones FFI cargadas
[OREJA][INFO] Init oreja_mobile
[OREJA][INFO] Modelos cargados OK: zscore, pca, lda
[NativeEarMobile] 📦 Versión: 1.0.0-mobile-oreja
```

#### Al hacer REGISTRO:
```
[NativeEarMobile] 📝 Registrando biometría...
[NativeEarMobile]    Usuario ID: 123
[NativeEarMobile]    Imágenes: 5
[OREJA][INFO] Registro biometria: id=123 imgs=5
[OREJA][INFO] Registro OK. templates_csv=.../templates_k1.csv clases=51
[NativeEarMobile] ✅ Registro exitoso
```

#### Al hacer LOGIN:
```
[Login] 🔄 Recargando templates desde disco...
[OREJA][INFO] Reload templates OK. clases=51  ← ¡Aquí está la nueva función!
[NativeEarMobile] ✅ Templates recargados correctamente
[Login] 🔐 Autenticando...
[OREJA][INFO] Autenticar: claimed=123
[OREJA][INFO] Auth result: pred=123 claimed=123 score_claimed=0.95 ok=1
[Login] ✅ Autenticado correctamente
```

---

## ❌ Si hay errores...

### Error: "Función reload_templates no disponible"

```
[NativeEarMobile] ❌ Función reload_templates no disponible
```

**Causa**: El `.so` no tiene la función compilada.

**Solución**:
```bash
# Verificar que el símbolo esté exportado
nm -D liboreja_mobile.so | grep reload

# Si NO aparece, recompilar:
cd mobile_app
flutter clean
flutter pub get
flutter build apk --release
```

---

### Error: "Undefined symbol: oreja_mobile_reload_templates"

```
E/AndroidRuntime: java.lang.UnsatisfiedLinkError: dlopen failed: 
cannot locate symbol "oreja_mobile_reload_templates"
```

**Causa**: La función no está en el `.so` o no se exportó correctamente.

**Solución**:
1. Verifica que el header tenga `extern "C"`:
   ```cpp
   extern "C" int oreja_mobile_reload_templates();
   ```

2. Verifica que el `.cpp` también tenga `extern "C"`:
   ```cpp
   extern "C" int oreja_mobile_reload_templates() { ... }
   ```

3. Recompila completamente:
   ```bash
   flutter clean
   rm -rf build/
   flutter pub get
   flutter build apk --release
   ```

---

### Error: "Timeout recargando templates"

```
[Login] ⚠️ Timeout recargando templates (continuando...)
```

**Causa**: El archivo `templates_k1.csv` es muy grande (>100 usuarios o corrupto).

**Solución**:
1. Verificar tamaño del archivo:
   ```bash
   adb shell
   cd /data/data/com.example.mobile_app/app_flutter/models
   ls -lh templates_k1.csv
   ```

2. Si es >10 MB, aumentar timeout en `login_screen.dart`:
   ```dart
   await nativeEarService.reloadTemplates().timeout(
     const Duration(seconds: 10),  // Aumentar de 5 a 10
     ...
   );
   ```

---

## ✅ Checklist final

Antes de dar por terminado:

- [ ] Compilaste el `.so` (opción 1 o 2)
- [ ] Verificaste que `oreja_mobile_reload_templates` aparece en `nm -D`
- [ ] Copiaste el `.so` a `jniLibs/arm64-v8a/` (si compilaste manualmente)
- [ ] Ejecutaste `flutter run --uninstall-first`
- [ ] Registraste un usuario nuevo (5 fotos)
- [ ] Viste logs: `"Registro OK. clases=51"`
- [ ] Cerraste y abriste la app
- [ ] Hiciste login con ese usuario
- [ ] Viste logs: `"Reload templates OK. clases=51"`
- [ ] Viste logs: `"Auth result: ok=1"`
- [ ] Login exitoso ✅

---

## 🎯 Resultado esperado

**Flujo completo funcionando**:

```
1. Registro (Usuario 1234567890)
   ├─ 5 fotos → Procesamiento → templates_k1.csv actualizado
   └─ ✅ "Registro exitoso"

2. Cerrar app

3. Login (Usuario 1234567890)
   ├─ Init → Reload templates (51 usuarios) → 1 foto → Autenticación
   └─ ✅ "Login exitoso"
```

---

## 📚 Archivos importantes

| Archivo | Ubicación | Descripción |
|---------|-----------|-------------|
| `oreja_mobile_api.cpp` | `lib/entrega_flutter_oreja/src/` | Implementación C++ |
| `oreja_mobile_api.h` | `lib/entrega_flutter_oreja/apis/` | Header con declaraciones |
| `CMakeLists.txt` | `lib/entrega_flutter_oreja/` | Configuración de compilación |
| `native_ear_mobile_service.dart` | `lib/services/` | FFI binding Dart |
| `login_screen.dart` | `lib/screens/` | UI de login |
| `liboreja_mobile.so` | `android/app/src/main/jniLibs/arm64-v8a/` | Librería compilada |

---

## 🚀 ¡Ya está todo listo!

Solo falta compilar y probar. Si tienes algún error, revisa la sección "Si hay errores" arriba.

**Comando más simple**:
```bash
cd mobile_app
flutter clean
flutter pub get
flutter build apk --release
flutter run --uninstall-first
```

¡Listo! 🎉
