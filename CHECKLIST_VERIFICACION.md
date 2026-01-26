# ✅ CHECKLIST DE VERIFICACIÓN - Sistema Oreja

## 📋 Antes de compilar

- [x] Código C++ tiene `extern "C" int oreja_mobile_reload_templates()`
- [x] Header `oreja_mobile_api.h` tiene la declaración
- [x] Dart FFI binding `_orejaMobileReloadTemplates` configurado
- [x] Método `reloadTemplates()` en `native_ear_mobile_service.dart`
- [x] Login screen llama `reloadTemplates()` después de `initialize()`
- [x] Sin errores de compilación en Dart (`flutter analyze`)

---

## 🔧 Compilación

- [ ] Ejecutado `flutter clean`
- [ ] Ejecutado `flutter pub get`
- [ ] Ejecutado `flutter build apk --release`
- [ ] Verificado símbolo con `nm -D liboreja_mobile.so | grep reload`
- [ ] Símbolo `oreja_mobile_reload_templates` aparece en la salida

---

## 🧪 Pruebas de registro

- [ ] Abre la app
- [ ] Va a pantalla de Registro
- [ ] Ingresa cédula nueva (ej: `1234567890`)
- [ ] Selecciona biometría "Oreja"
- [ ] Toma 5 fotos de la oreja derecha
- [ ] Ve mensaje "✅ Registro exitoso"
- [ ] Log muestra: `Registro OK. templates_csv=.../templates_k1.csv clases=51`

---

## 🧪 Pruebas de login

### Test 1: Login inmediato después de registro

- [ ] Cierra y abre la app
- [ ] Va a pantalla de Login
- [ ] Ingresa la misma cédula (`1234567890`)
- [ ] Selecciona biometría "Oreja"
- [ ] Toma 1 foto de la oreja
- [ ] Ve mensaje "✅ Login exitoso"
- [ ] Log muestra: `Reload templates OK. clases=51`
- [ ] Log muestra: `Auth result: pred=123 claimed=123 score=0.XX ok=1`

### Test 2: Múltiples usuarios

- [ ] Registra Usuario A (cédula `1111111111`)
- [ ] Registra Usuario B (cédula `2222222222`)
- [ ] Cierra y abre app
- [ ] Login como Usuario A → ✅ Funciona
- [ ] Logout
- [ ] Login como Usuario B → ✅ Funciona
- [ ] Login como Usuario A con foto de B → ❌ Rechazado

### Test 3: Modo offline

- [ ] Activa modo avión
- [ ] Intenta login con usuario ya registrado
- [ ] Login funciona sin conexión

---

## 📊 Logs esperados

### Inicialización
```
[NativeEarMobile] 🚀 Inicializando...
[NativeEarMobile] ✅ Librería cargada
[OREJA][INFO] Init oreja_mobile
[OREJA][INFO] Modelos cargados OK: zscore, pca, lda
[NativeEarMobile] 📦 Versión: 1.0.0-mobile-oreja
```

### Registro
```
[NativeEarMobile] 📝 Registrando biometría...
[OREJA][INFO] Registro biometria: id=123 imgs=5
[OREJA][INFO] Registro OK. templates_csv=.../templates_k1.csv clases=51
[NativeEarMobile] ✅ Registro exitoso
```

### Login con reload
```
[Login] 🔄 Recargando templates desde disco...
[OREJA][INFO] Reload templates OK. clases=51  ← ¡Clave!
[NativeEarMobile] ✅ Templates recargados correctamente
[Login] 🔐 Autenticando...
[OREJA][INFO] Autenticar: claimed=123
[OREJA][INFO] Auth result: pred=123 claimed=123 score_claimed=0.95 ok=1
[Login] ✅ Autenticado correctamente
```

---

## 🐛 Problemas comunes

### ❌ "Función reload_templates no disponible"

**Síntoma**:
```
[NativeEarMobile] ❌ Función reload_templates no disponible
```

**Causa**: El `.so` no tiene la función compilada.

**Solución**:
```bash
# Verificar símbolo
nm -D liboreja_mobile.so | grep reload

# Si NO aparece, recompilar:
flutter clean
flutter pub get
flutter build apk --release
```

---

### ❌ "Timeout recargando templates"

**Síntoma**:
```
[Login] ⚠️ Timeout recargando templates (continuando...)
```

**Causa**: El archivo `templates_k1.csv` es muy grande.

**Solución**: Aumentar timeout en `login_screen.dart`:
```dart
await nativeEarService.reloadTemplates().timeout(
  const Duration(seconds: 10),  // Aumentar de 5 a 10
  ...
);
```

---

### ❌ "Usuario no encontrado en templates"

**Síntoma**: Login falla después de registro exitoso.

**Causa**: El registro no actualizó `templates_k1.csv`.

**Verificar**:
```bash
# Conectar device por USB
adb shell
cd /data/data/com.example.mobile_app/app_flutter/models
cat templates_k1.csv

# Debería tener líneas con: ID_USUARIO;feature1;feature2;...
```

**Verificar logs**:
```
[OREJA][INFO] Registro OK. templates_csv=.../templates_k1.csv clases=51
```

Si dice `clases=50` (no incrementó), el registro falló.

---

### ❌ "Undefined symbol: oreja_mobile_reload_templates"

**Síntoma**:
```
E/AndroidRuntime: java.lang.UnsatisfiedLinkError: 
dlopen failed: cannot locate symbol "oreja_mobile_reload_templates"
```

**Causa**: La función no se exportó correctamente.

**Solución**:
1. Verifica que el código C++ tenga:
   ```cpp
   extern "C" int oreja_mobile_reload_templates() { ... }
   ```

2. Verifica que el header tenga:
   ```cpp
   #ifdef __cplusplus
   extern "C" {
   #endif
   
   int oreja_mobile_reload_templates();
   
   #ifdef __cplusplus
   }
   #endif
   ```

3. Recompila:
   ```bash
   flutter clean
   rm -rf build/
   flutter pub get
   flutter build apk --release
   ```

---

## ✅ Criterios de éxito

- [ ] Usuario puede registrarse con 5 fotos de oreja
- [ ] `templates_k1.csv` se actualiza después del registro
- [ ] Archivo incrementa número de clases (50 → 51 → 52 ...)
- [ ] Login carga templates actualizados automáticamente
- [ ] Login autentica correctamente después de registro
- [ ] No hay errores "Modelo no cargado"
- [ ] No hay freezes de app durante init/reload
- [ ] Logs muestran "Reload templates OK. clases=X"
- [ ] Sistema funciona offline (sin conexión)
- [ ] Múltiples usuarios pueden registrarse y autenticarse

---

## 📈 Métricas de performance

### Tiempos esperados:

| Operación | Tiempo esperado |
|-----------|----------------|
| `initialize()` | < 3 segundos |
| `reloadTemplates()` | < 1 segundo (hasta 100 usuarios) |
| `registerBiometric()` (5 fotos) | < 10 segundos |
| `authenticate()` (1 foto) | < 2 segundos |

### Archivo templates_k1.csv:

| Usuarios | Tamaño estimado |
|----------|----------------|
| 50 base | ~100 KB |
| 100 usuarios | ~200 KB |
| 500 usuarios | ~1 MB |
| 1000 usuarios | ~2 MB |

**Nota**: Si el archivo supera 5 MB, considerar aumentar timeout de reload a 10 segundos.

---

## 🚀 Todo listo cuando...

✅ Todos los checkboxes marcados  
✅ Logs muestran `Reload templates OK`  
✅ Login funciona después de registro  
✅ Sin errores ni freezes  
✅ Performance dentro de lo esperado

---

¡SISTEMA COMPLETO Y FUNCIONANDO! 🎉
