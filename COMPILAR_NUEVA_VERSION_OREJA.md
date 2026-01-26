# ✅ Compilar nueva versión liboreja_mobile.so con reload_templates()

## 📋 Resumen

Tu compañero ya implementó la función `oreja_mobile_reload_templates()` en el código C++. Ahora solo falta:

1. ✅ Reemplazar el archivo `.cpp` principal con el nuevo código
2. ✅ Compilar la librería `.so` para Android ARM64
3. ✅ Copiar el `.so` al proyecto Flutter
4. ✅ Probar con `flutter run --uninstall-first`

---

## 🔧 PASO 1: Reemplazar código C++

El archivo que tu compañero debe editar es:

```
mobile_app/lib/entrega_flutter_oreja/src/oreja_mobile_api.cpp
```

### Cambios principales implementados:

1. **Agregada la función `oreja_mobile_reload_templates()`** (línea ~273):
   ```cpp
   extern "C" int oreja_mobile_reload_templates()
   {
       std::lock_guard<std::mutex> lock(g_mutex);

       if (!check_initialized())
           return -1;

       TemplateModel tm;
       if (!load_templates_from_disk(tm))
       {
           log_err("Reload templates failed: " + g_state->lastError);
           return -1;
       }

       log_info("Reload templates OK. clases=" + std::to_string(tm.clases.size()));
       return 0;
   }
   ```

2. **Función auxiliar `load_templates_from_disk()`** (línea ~234):
   - Lee `templates_k1.csv` desde disco
   - Carga todos los templates de usuarios registrados
   - Retorna `TemplateModel` con vectores y etiquetas

### ✅ El código ya está completo en el archivo que enviaste

---

## 🔧 PASO 2: Compilar con CMake para Android ARM64

### Opción A: Compilar con NDK directamente

```bash
cd mobile_app/lib/entrega_flutter_oreja

# Crear carpeta de build
mkdir -p build/android-arm64
cd build/android-arm64

# Configurar con CMake
cmake ../.. \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-21 \
  -DCMAKE_BUILD_TYPE=Release

# Compilar
make -j$(nproc)
```

### Opción B: Usar Flutter build (recomendado)

```bash
cd mobile_app

# Compilar para Android ARM64
flutter build apk --release
```

Esto compilará automáticamente todas las librerías nativas configuradas en `CMakeLists.txt`.

---

## 🔧 PASO 3: Copiar librería compilada

### Si compilaste manualmente:

```bash
# Copiar .so compilado al directorio jniLibs
cp build/android-arm64/liboreja_mobile.so \
   android/app/src/main/jniLibs/arm64-v8a/

# También crear versión debug si es necesario
mkdir -p android/app/src/debug/jniLibs/arm64-v8a/
cp build/android-arm64/liboreja_mobile.so \
   android/app/src/debug/jniLibs/arm64-v8a/
```

### Si usaste Flutter build:

La librería ya está incluida automáticamente en el APK.

---

## 🔧 PASO 4: Verificar que la función esté exportada

```bash
# Ver símbolos exportados en el .so
nm -D liboreja_mobile.so | grep reload

# Deberías ver:
# 00001234 T oreja_mobile_reload_templates
```

Si NO aparece, revisar que el header tenga `extern "C"`:

```cpp
extern "C" int oreja_mobile_reload_templates();
```

---

## ✅ PASO 5: Probar en la app

```bash
cd mobile_app

# Desinstalar completamente y reinstalar
flutter run --uninstall-first
```

### Logs esperados:

#### 1. Al hacer LOGIN:
```
[Login] 🔄 Recargando templates desde disco...
[OREJA][INFO] Reload templates OK. clases=50
[Login] ✅ Servicio nativo inicializado correctamente
```

#### 2. Al hacer REGISTRO (5 fotos):
```
[NativeEarMobile] 📝 Registrando biometría...
[OREJA][INFO] Registro OK. templates_csv=.../templates_k1.csv clases=51
[NativeEarMobile] ✅ Registro exitoso
```

#### 3. Al hacer LOGIN después del registro:
```
[Login] 🔄 Recargando templates desde disco...
[OREJA][INFO] Reload templates OK. clases=51  ← ¡Ahora incluye nuevo usuario!
[OREJA][INFO] Auth result: pred=123 claimed=123 score_claimed=0.95 ok=1
[Login] ✅ Autenticado correctamente
```

---

## 🐛 Troubleshooting

### Error: "Función reload_templates no disponible"

**Causa**: La función no se compiló o no está exportada.

**Solución**:
```bash
# Verificar que el .so tenga el símbolo
nm -D android/app/src/main/jniLibs/arm64-v8a/liboreja_mobile.so | grep reload

# Si NO aparece, recompilar con:
flutter clean
flutter pub get
flutter build apk --release
```

### Error: "Timeout recargando templates"

**Causa**: El archivo `templates_k1.csv` es muy grande (>10 MB).

**Solución**: Aumentar timeout en `login_screen.dart`:
```dart
await nativeEarService.reloadTemplates().timeout(
  const Duration(seconds: 10),  // ← Aumentar de 5 a 10 segundos
  onTimeout: () { ... }
);
```

### Error: "Templates no existe"

**Causa**: El archivo `templates_k1.csv` no está en `app_flutter/models/`.

**Solución**: Verificar que los assets se copiaron correctamente:
```dart
// En native_ear_mobile_service.dart, _copyAssets()
await _copyAsset(
  'assets/models/templates_k1.csv',  // ← Debe existir en assets
  '${appDir.path}/models/templates_k1.csv',
);
```

---

## 📊 Flujo completo (Registro + Login)

```
┌─────────────────────────────────────────────────────────┐
│ 1. PRIMER REGISTRO (Usuario 1)                         │
├─────────────────────────────────────────────────────────┤
│ ✅ oreja_mobile_init()                                  │
│    └─ Carga templates_k1.csv (50 usuarios base)        │
│                                                          │
│ ✅ oreja_mobile_registrar_biometria()                   │
│    ├─ Procesa 5 fotos                                   │
│    ├─ Extrae features LBP → PCA → LDA                   │
│    ├─ Agrega al dataset CSV                             │
│    └─ Actualiza templates_k1.csv (51 usuarios)          │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ 2. LOGIN (Usuario 1)                                    │
├─────────────────────────────────────────────────────────┤
│ ✅ oreja_mobile_init()                                  │
│    └─ Carga templates_k1.csv (51 usuarios)              │
│                                                          │
│ ✅ oreja_mobile_reload_templates()  ← ¡NUEVA FUNCIÓN!   │
│    └─ Recarga templates_k1.csv (por si hubo cambios)    │
│                                                          │
│ ✅ oreja_mobile_autenticar()                            │
│    ├─ Procesa foto → LBP → PCA → LDA                    │
│    ├─ Compara con templates (cosine similarity)         │
│    └─ Retorna: autenticado=true, score=0.95             │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ 3. SEGUNDO REGISTRO (Usuario 2)                         │
├─────────────────────────────────────────────────────────┤
│ ✅ oreja_mobile_registrar_biometria()                   │
│    └─ Actualiza templates_k1.csv (52 usuarios)          │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ 4. LOGIN (Usuario 2)                                    │
├─────────────────────────────────────────────────────────┤
│ ✅ oreja_mobile_reload_templates()                      │
│    └─ Recarga templates_k1.csv (52 usuarios)            │
│                                                          │
│ ✅ oreja_mobile_autenticar()                            │
│    └─ ✅ Usuario 2 autenticado correctamente            │
└─────────────────────────────────────────────────────────┘
```

---

## ✅ Checklist final

- [ ] Código C++ actualizado con `oreja_mobile_reload_templates()`
- [ ] Header `oreja_mobile_api.h` tiene la declaración `extern "C"`
- [ ] Compilado con CMake + NDK para ARM64
- [ ] Librería `.so` copiada a `jniLibs/arm64-v8a/`
- [ ] Dart FFI bindings actualizados (`native_ear_mobile_service.dart`)
- [ ] Login screen llama `reloadTemplates()` antes de autenticar
- [ ] Probado con `flutter run --uninstall-first`
- [ ] Logs muestran "Reload templates OK. clases=X"

---

## 🎯 Resultado esperado

✅ **Registro**: Usuario agrega 5 fotos → templates_k1.csv actualizado
✅ **Login**: Templates se recargan automáticamente → autenticación exitosa
✅ **Sin errores**: "Modelo no cargado" desaparece
✅ **Sin freezes**: Timeout de 10s evita bloqueos indefinidos

---

## 📚 Archivos modificados

1. ✅ `mobile_app/lib/entrega_flutter_oreja/src/oreja_mobile_api.cpp`
   - Agregada función `oreja_mobile_reload_templates()`
   
2. ✅ `mobile_app/lib/entrega_flutter_oreja/apis/oreja_mobile_api.h`
   - Declaración `extern "C"` de la función

3. ✅ `mobile_app/lib/services/native_ear_mobile_service.dart`
   - FFI binding `_orejaMobileReloadTemplates`
   - Método público `reloadTemplates()`

4. ✅ `mobile_app/lib/screens/login_screen.dart`
   - Llamada a `reloadTemplates()` después de `initialize()`

---

## 🚀 Próximos pasos

1. **Compilar** el nuevo `.so` con el código actualizado
2. **Probar** registro + login con logs habilitados
3. **Validar** que no haya más errores "Modelo no cargado"
4. **Optimizar** (opcional): Cachear `TemplateModel` en `MobileState` para evitar releer CSV en cada autenticación

¡Listo para compilar! 🎉
