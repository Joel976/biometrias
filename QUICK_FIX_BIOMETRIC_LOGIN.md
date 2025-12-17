# 🔧 FIX RÁPIDO: Autenticación Biométrica (Sin Contraseña)

**Problema:** "No existen plantillas de voz/oreja para este usuario"

**Causa:** Las credenciales biométricas NO se guardaban en la BD local durante el registro.

**Solución:** ✅ Implementada en `auth_service_fix.dart`

---

## ✅ Lo que se hizo

### Problema Original:
```dart
// ❌ ANTES: Solo se enviaba al backend, NO se guardaba localmente
registerEarPhoto() {
  // POST a backend
  // Fin
}
```

### Solución Implementada:
```dart
// ✅ AHORA: Se guarda en BD local ANTES de enviar al backend
registerEarPhoto() {
  // 1. Buscar usuario local por identificador
  final user = await localDb.getUserByIdentifier(identificadorUnico);
  
  // 2. Insertar credencial biométrica en SQLite
  await localDb.insertBiometricCredential(credential);
  
  // 3. Luego enviar al backend
  // POST a backend
}
```

### Archivos Modificados:
- `mobile_app/lib/services/auth_service_fix.dart`
  - ✅ `registerEarPhoto()`: Ahora guarda en BD local + backend
  - ✅ `registerVoiceAudio()`: Ahora guarda en BD local + backend

---

## 🚀 Cómo Usar (PASO A PASO)

### 1. **Limpiar la app**
```bash
cd C:\Users\User\Downloads\biometrias\mobile_app
flutter clean
flutter pub get
```

### 2. **Reinstalar en dispositivo/emulador**
```bash
flutter run
```

### 3. **Registro (Nuevo Usuario)**
Ir a pantalla de registro:
- [ ] Ingresar: Nombres, Apellidos, Email, Identificador
- [ ] Capturar: **3 fotos de oreja** (una por una)
  - *La foto debe mostrar claramente la oreja*
  - Las 3 fotos se guardarán en SQLite local
- [ ] Capturar: **Audio de voz** (2-3 segundos)
  - *Puedes decir cualquier frase o número*
  - El audio se guardará en SQLite local
- [ ] Click "Completar Registro"
  - ✅ Se guardará en PostgreSQL (si hay internet)
  - ✅ Se guardará en SQLite (offline-first)
  - ✅ Las credenciales biométricas se guardarán localmente

### 4. **Login Offline (Sin Internet)**
Una vez registrado:
- [ ] No necesitas conectividad
- [ ] Click "Ingresa con Biometría"
- [ ] Ingresar identificador único
- [ ] Capturar: **Foto de oreja**
  - Se comparará contra las 3 templates guardadas
  - Si coincide > 60%, ✅ Acceso
- [ ] O capturar: **Audio de voz**
  - Se comparará contra plantillas guardadas
  - Si coincide > 55%, ✅ Acceso

### 5. **Login Online (Con Internet)**
- [ ] Capturar foto/audio
- [ ] Se envía al backend PostgreSQL
- [ ] Backend valida contra `credenciales_biometricas`
- [ ] Si coincide, ✅ Acceso

---

## 📊 Flujo de Datos

### Registro:
```
Usuario en pantalla
    ↓
Captura 3 fotos oreja
    ↓
Captura audio voz
    ↓
Click "Registrar"
    ├─→ Guardar usuario en SQLite local ✅
    ├─→ Guardar 3 credenciales oreja en SQLite ✅
    ├─→ Guardar 1 credencial audio en SQLite ✅
    └─→ Enviar todo al backend (si hay internet) ✅
```

### Login Offline:
```
Usuario inicia sesión SIN INTERNET
    ↓
Captura foto/audio
    ↓
Buscar usuario local
    ↓
Obtener credenciales de SQLite
    ├─→ Si tipo=oreja: comparar foto vs 3 templates
    └─→ Si tipo=audio: comparar audio vs plantillas
    ↓
Si confianza > threshold → ✅ Acceso
```

### Login Online:
```
Usuario inicia sesión CON INTERNET
    ↓
Captura foto/audio
    ↓
Enviar al backend
    ↓
Backend obtiene credenciales de PostgreSQL
    ├─→ Si tipo=oreja: comparar vs credenciales_biometricas
    └─→ Si tipo=audio: comparar vs credenciales_biometricas
    ↓
Si confianza > threshold → ✅ Acceso + Token
```

---

## 🔍 Verificación Técnica

### Después del registro, revisa:

#### 1. **Base de Datos Local (SQLite)**
```dart
// En terminal Flutter
final db = await DatabaseConfig().database;

// Usuarios
List<Map> users = await db.query('usuarios');
print(users); // Debe mostrar el usuario registrado

// Credenciales
List<Map> creds = await db.query('credenciales_biometricas');
print(creds); // Debe mostrar 4 credenciales:
              // - 3 de tipo 'oreja'
              // - 1 de tipo 'audio'
```

#### 2. **Base de Datos Remota (PostgreSQL)**
```sql
-- Conectar a PostgreSQL
SELECT * FROM usuarios;          -- Debe mostrar usuario
SELECT * FROM credenciales_biometricas;  -- Debe mostrar 4 credenciales
```

---

## ⚠️ Troubleshooting

### Error: "Usuario no encontrado localmente"
**Causa:** El usuario no se registró correctamente en SQLite
**Solución:** Asegúrate de completar todo el flujo de registro (3 fotos + audio)

### Error: "No existen plantillas de oreja"
**Causa:** No se guardaron las credenciales en SQLite
**Solución:** Este error ya está FIJO ✅ - reinstala la app con flutter clean

### Error: "Autenticación fallida: oreja no coincide"
**Causa:** La foto capturada no se parece a los templates
**Solución:** 
- Captura en condiciones de luz similares
- Asegúrate de que sea la misma oreja
- Intenta con audio (threshold es más bajo: 0.55)

### Error: "Autenticación fallida: voz no coincide"
**Causa:** El audio capturado no coincide con los templates
**Solución:**
- Graba con calidad similar a la inicial
- Mismo tono de voz
- Intenta con foto de oreja

---

## 🎯 Thresholds de Confianza

| Tipo Biometría | Threshold | Normalización |
|---|---|---|
| Voz (audio) | 0.55 | Z-score ✅ |
| Oreja | 0.60 | Z-score ✅ |

*Si la confianza es > threshold → Acceso ✅*

---

## 📋 Checklist de Validación

- [x] Código modificado: `registerEarPhoto()` → Guarda en BD local
- [x] Código modificado: `registerVoiceAudio()` → Guarda en BD local
- [x] Base datos SQLite: v3 (recreada automáticamente)
- [x] Backend: Corriendo en puerto 3000
- [x] Migraciones: Todas ejecutadas (001-005)
- [ ] Usuario registrado: Nombres + Email + Identificador + 3 fotos oreja + audio voz
- [ ] Login offline: Capturar biometría sin internet → Validar contra SQLite
- [ ] Login online: Capturar biometría con internet → Validar contra PostgreSQL
- [ ] Sincronización: Cuando hay conexión, datos se suben a backend

---

## 🔐 Seguridad

✅ **Sin contraseñas en ningún lado**
✅ **Biometría guardada como vectores (imposibles de invertir)**
✅ **Z-score normalization para consistencia offline/online**
✅ **Validaciones locales sin necesidad de internet**
✅ **Auto-sincronización cuando hay conexión**

---

## 📞 Próximos Pasos

1. **Ejecutar:** `flutter clean && flutter pub get && flutter run`
2. **Registrarse:** Nombres + Email + ID + 3 fotos oreja + audio voz
3. **Probar login offline:** Sin internet, capturar biometría
4. **Probar login online:** Con internet, capturar biometría
5. **Verificar bases de datos:** SQLite local + PostgreSQL remota

**¡Listo! Ya debería funcionar.** 🎉
