# 📁 ¿Dónde se Guardan REALMENTE los Datos de Oreja?

**Fecha:** 25 de enero de 2026  
**Pregunta:** ¿Por qué `templates_k1.csv` solo tiene 50 líneas (0-49)?

---

## 🔍 **Respuesta Corta**

El archivo `templates_k1.csv` que ves con 50 líneas son **templates DE PRUEBA precargados** en los assets de la app. **NO es donde se guardan tus datos reales de oreja.**

---

## 📦 **Dónde se Guardan REALMENTE tus Templates de Oreja**

### **1. Durante el Registro (EN MEMORIA)**

```
📍 liboreja_mobile.so mantiene en MEMORIA:
   - templates_precargados[] (IDs 0-49)  ← Se eliminan al inicializar
   - templates_nuevos[] (tu ID)          ← Se agrega cuando registras

⚠️ PROBLEMA: Solo se guarda en RAM (memoria volátil)
   - Si cierras la app → SE PIERDEN
   - No hay persistencia en disco
```

---

### **2. Debería Guardarse en SQLite (Backend)**

```
📍 Ubicación: PostgreSQL (servidor backend)
📋 Tabla: credenciales_biometricas
🔑 Campo: template (BLOB - vector LDA de 40 dimensiones)
```

**Flujo de sincronización:**
```
1. Registras en app → liboreja_mobile.so procesa fotos
2. Extrae vector LDA (40 dimensiones)
3. DEBERÍA guardar en SQLite local
4. Cola de sincronización → Backend PostgreSQL
```

---

## ⚠️ **PROBLEMA ACTUAL: Templates NO Persisten**

### **Evidencia**

```csv
# templates_k1.csv (en assets)
0;0.114652;0.044589;...   ← Template precargado fake
1;-0.108409;0.143166;...  ← Template precargado fake
...
49;-0.170452;-0.0816425;... ← Template precargado fake

❌ FALTA: Template real de usuario registrado (ID 50+)
```

### **¿Qué está pasando?**

```cpp
// liboreja_mobile.so - función oreja_mobile_registrar_biometria()

int oreja_mobile_registrar_biometria(...) {
    // 1. Extrae características LDA de 5 fotos ✅
    extract_lda_features(imagePaths, features);
    
    // 2. Agrega template a memoria RAM ✅
    templates_nuevos.push_back({id, features});
    
    // 3. ❌ FALTA: Guardar en archivo CSV persistente
    // save_template_to_csv(id, features);  ← NO IMPLEMENTADO
    
    // 4. ❌ FALTA: Guardar en SQLite local
    // save_to_sqlite(id, features);  ← NO IMPLEMENTADO
    
    return 0;  // success
}
```

---

## 🔧 **¿Por Qué NO Se Guarda en Disco?**

### **Arquitectura Actual:**

```
liboreja_mobile.so (C++)
    ↓ FFI
native_ear_mobile_service.dart (Dart)
    ↓
register_screen.dart

❌ FALTA ENLACE:
   liboreja_mobile.so → SQLite local
   liboreja_mobile.so → templates_k1.csv (actualización)
```

### **Comparación con Voz:**

| Aspecto | Voz (libvoz_mobile.so) | Oreja (liboreja_mobile.so) |
|---------|------------------------|---------------------------|
| Extrae características | ✅ MFCC (143 dim) | ✅ LDA (40 dim) |
| Guarda en SQLite local | ✅ SÍ | ❌ NO |
| Actualiza CSV | ✅ SÍ | ❌ NO |
| Persiste en disco | ✅ SÍ | ❌ NO (solo RAM) |
| Cola sincronización | ✅ SÍ | ⚠️ Parcial (solo backend) |

---

## ✅ **SOLUCIONES**

### **Opción 1: Implementar Persistencia en liboreja_mobile.so (C++)**

**Modificar código C++:**

```cpp
// oreja_mobile.cpp

int oreja_mobile_registrar_biometria(...) {
    // 1. Extraer LDA
    vector<float> features = extract_lda_features(imagePaths);
    
    // 2. Guardar en memoria
    templates[id] = features;
    
    // 3. ✅ NUEVO: Guardar en SQLite
    save_to_sqlite(id, features);
    
    // 4. ✅ NUEVO: Actualizar templates_k1.csv
    append_to_csv("templates_k1.csv", id, features);
    
    return 0;
}
```

**Problema:** Requiere recompilar `liboreja_mobile.so`

---

### **Opción 2: Implementar Persistencia en Dart (Flutter)**

**Modificar `native_ear_mobile_service.dart`:**

```dart
Future<Map<String, dynamic>> registerBiometric({
  required int identificadorUnico,
  required List<String> imagePaths,
}) async {
  // 1. Registrar en .so (solo RAM)
  final resultado = await _orejaMobileRegistrar!(...);
  
  if (resultado['success'] == true) {
    // 2. ✅ NUEVO: Guardar en SQLite Dart
    final vector = resultado['vector']; // Obtener vector LDA
    await _guardarEnSQLiteLocal(identificadorUnico, vector);
    
    // 3. ✅ NUEVO: Actualizar templates_k1.csv en disco
    await _actualizarTemplatesCSV(identificadorUnico, vector);
  }
  
  return resultado;
}
```

**Problema:** Necesita que `.so` retorne el vector LDA en el JSON

---

### **Opción 3: Sistema Híbrido (Backend como fuente de verdad)**

**Flujo actual (parcialmente implementado):**

```
1. Registro en app → liboreja_mobile.so extrae LDA
2. Envía template al backend PostgreSQL ✅
3. Backend guarda en DB (persistente) ✅
4. ❌ FALTA: App sincroniza templates desde backend
```

**Solución:**

```dart
// Al inicializar app
await _sincronizarTemplatesDesdeBackend();

Future<void> _sincronizarTemplatesDesdeBackend() async {
  // 1. Descargar templates desde backend
  final response = await http.get('$baseUrl/templates/oreja/all');
  
  // 2. Guardar en templates_k1.csv local
  final file = File('${appDir.path}/models/templates_k1.csv');
  await file.writeAsString(templatesCSV);
  
  // 3. Re-inicializar liboreja_mobile.so
  await nativeEarService.initialize();
}
```

---

## 🎯 **Recomendación**

### **MEJOR SOLUCIÓN: Opción 3 (Sync desde Backend)**

**Ventajas:**
- ✅ No requiere recompilar `.so`
- ✅ Backend es fuente única de verdad
- ✅ Sincronización automática entre dispositivos
- ✅ Tolerante a fallos (backend siempre disponible)

**Implementación:**

1. **Verificar que backend guarda templates** ✅ (ya lo hace)
2. **Agregar endpoint** `/templates/oreja/all` para descargar
3. **Sincronizar en app init:**
   ```dart
   await syncTemplatesDesdeBackend();
   await nativeEarService.initialize();
   ```
4. **Actualizar templates después de registro:**
   ```dart
   await backend.registrarOreja(...);  // Guarda en PostgreSQL
   await syncTemplatesDesdeBackend();  // Descarga actualizado
   ```

---

## 📊 **Estado Actual vs Estado Deseado**

### **ACTUAL:**
```
Registro → liboreja_mobile.so (RAM) → ❌ Se pierde al cerrar app
          ↓
       Backend PostgreSQL ✅ (persiste)
```

### **DESEADO:**
```
Registro → liboreja_mobile.so (RAM)
          ↓
       Backend PostgreSQL ✅
          ↓
       Sync → templates_k1.csv (local) ✅
          ↓
       Re-init liboreja_mobile.so ✅
          ↓
       Templates cargados en RAM ✅
```

---

## ✅ **Próximos Pasos**

1. ✅ **Implementar endpoint backend:** `GET /templates/oreja/all`
2. ✅ **Agregar función sync en Dart:** `syncTemplatesDesdeBackend()`
3. ✅ **Llamar sync después de registro:**
   ```dart
   await backend.registrarOreja(...);
   await syncTemplatesDesdeBackend();
   await nativeEarService.initialize();
   ```
4. ✅ **Llamar sync en app init:**
   ```dart
   if (await conectividadService.hayConexion()) {
     await syncTemplatesDesdeBackend();
   }
   await nativeEarService.initialize();
   ```

---

## 🎉 **Conclusión**

**Pregunta original:** ¿Por qué mi oreja no se guarda, solo está hasta el 49?

**Respuesta:** 
- Templates 0-49 son **datos fake precargados**
- Tu template (ID 50+) **SÍ se registra en backend PostgreSQL** ✅
- Pero **NO se sincroniza de vuelta a `templates_k1.csv` local** ❌
- Por eso `liboreja_mobile.so` no lo encuentra al autenticar ❌

**Solución:** Implementar sincronización de templates desde backend → CSV local → Reinit `.so`

¡Ahora sabes exactamente dónde están tus datos y cómo hacer que funcionen! 🚀
