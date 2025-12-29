# 🔐 Password Security - Quick Start (5 min)

## TL;DR - Lo que cambió

```
❌ ANTES:
- Contraseña hardcoded como 'test_password'
- No se validaba realmente
- No había login offline
- No se hasheaba nada

✅ AHORA:
- Contraseñas hasheadas (PBKDF2-like SHA-256 x100k)
- Validación real online (backend) + offline (local DB)
- Login funciona sin internet
- Seguro contra fuerza bruta y timing attacks
```

---

## 🚀 Setup en 2 minutos

### Paso 1: Ejecutar Migración Backend
```bash
cd backend
node migrations/runMigrations.js
```

**Esperado:**
```
✓ Migración completada: 001_init_schema.sql
✓ Migración completada: 002_fix_nullable_id_usuario.sql
✓ Migración completada: 003_add_password_hash.sql
✓ ¡Todas las migraciones se ejecutaron exitosamente!
```

**Qué hace:** Agrega columna `password_hash` a tabla `usuarios` en PostgreSQL

---

### Paso 2: Iniciar Backend
```bash
cd backend
npm start
```

**Esperado:**
```
✓ Servidor iniciado en puerto 3000
✓ Conexión a PostgreSQL establecida
```

---

### Paso 3: Iniciar Mobile App
```bash
cd mobile_app
flutter run
```

---

## ✅ Test en 3 pasos

### Test 1: Registro Online
1. RegisterScreen
2. Ingresa:
   - Nombres: "Test"
   - Apellidos: "User"
   - Identificador: "test.user@123"
   - **Contraseña: "TestPass@123"** (mayús + minús + números + especiales)
3. Captura fotos/audio
4. Click "Enviar"

**Esperado:** ✅ Usuario registrado + contraseña hasheada localmente + enviada a backend

---

### Test 2: Login Online
1. Logout
2. LoginScreen
3. Identificador: "test.user@123"
4. Contraseña: "TestPass@123"
5. Click Login

**Esperado:** ✅ HomeScreen abierta

---

### Test 3: Login Offline
1. **Activar Airplane Mode** (desconectar internet)
2. Logout
3. LoginScreen
4. Identificador: "test.user@123"
5. Contraseña: "TestPass@123"
6. Click Login

**Esperado:** ✅ HomeScreen abierta (modo offline)

**Nota:** Mensaje en pantalla dirá "Modo offline - Sincronización pendiente"

---

## 🔍 Verificar que funciona

### En PostgreSQL
```bash
psql -U postgres -d biometrias

# Ver que password_hash existe
\d usuarios

# Ver hash guardado
SELECT identificador_unico, 
       SUBSTRING(password_hash, 1, 32) as salt,
       LENGTH(password_hash) as length
FROM usuarios 
WHERE identificador_unico = 'test.user@123';
```

**Esperado:**
```
identificador_unico | salt                             | length
──────────────────────────────────────────────────────────────
test.user@123       | a7f3b9c2e1d4f6a8b0c3d5e7f9a... | 129
```

---

### En SQLite (Mobile)
Abre `build/` → busca archivo `biometrias.db`
O en Flutter DevTools → Database

```
SELECT identificador_unico, SUBSTR(password_hash, 1, 32) as salt
FROM usuarios
WHERE identificador_unico = 'test.user@123';
```

**Esperado:** Mismo hash que PostgreSQL (porque usas misma contraseña)

---

## ⚠️ Errores Comunes

| Error | Causa | Solución |
|-------|-------|----------|
| "Error de configuración de BD" | Migración no ejecutada | `node migrations/runMigrations.js` |
| "Contraseña débil" | No cumple requisitos | Agregar mayús + minús + números |
| "Usuario no encontrado" | Usuario nunca registrado | Hacer registro online primero |
| "Contraseña incorrecta" | Password es incorrecto | Verificar contraseña exacta |
| Login offline no funciona | Internet aún conectada | Activar Airplane Mode |

---

## 📊 Requisitos de Contraseña

```
✅ VÁLIDA:
- TestPass@123      (6+ chars, mayús, minús, números, especiales)
- MyP@ss123         (cumple todo)
- Abcdef123!        (cumple todo)

❌ INVÁLIDA:
- weak              (solo minúsculas + corta)
- 123456            (solo números)
- abcdef            (solo minúsculas)
- ABCDEF            (solo mayúsculas)
```

---

## 🔄 Flujo Completo

```
┌─ REGISTRO ─────────────────────┐
│ User: "TestPass@123"           │
│ ↓ (Flutter) Valida fortaleza   │
│ ↓ Hash local: "salt$hash"      │
│ ↓ Envía a backend              │
│ ↓ (Node) Valida fortaleza      │
│ ↓ Hash: "salt2$hash2"          │
│ ✅ Guardado en PostgreSQL       │
└────────────────────────────────┘
              ↓
┌─ LOGIN ONLINE ─────────────────┐
│ User input: "TestPass@123"     │
│ ↓ Envía a backend              │
│ ↓ Backend verifica hash        │
│ ↓ SHA256 x100k con salt        │
│ ✅ Token JWT entregado          │
└────────────────────────────────┘
              ↓
┌─ LOGIN OFFLINE ────────────────┐
│ User input: "TestPass@123"     │
│ ↓ (SIN INTERNET)               │
│ ↓ SQLite verifica hash local   │
│ ↓ SHA256 x100k con salt        │
│ ✅ Token offline: "offline_..." │
└────────────────────────────────┘
```

---

## 🧪 Test Suite Completo

Para todos los 15 tests detallados:
→ Ver `PASSWORD_SECURITY_TESTING.md`

Resumen:
- ✅ Registration (fuerte/débil)
- ✅ Online login (correcto/incorrecto)
- ✅ Offline login (correcto/incorrecto)
- ✅ Hash consistency
- ✅ Performance
- ✅ Security (timing attacks)
- ✅ Database schema
- ✅ E2E flow

---

## 📚 Documentación Detallada

- **Arquitectura completa:** `PASSWORD_SECURITY.md`
- **Todos los cambios:** `CAMBIOS_PASSWORD_SECURITY.md`
- **Tests con paso a paso:** `PASSWORD_SECURITY_TESTING.md`

---

## ✨ Beneficios

```
✅ Seguridad Real
   - Hashing seguro (no plaintext)
   - Protección contra fuerza bruta (100k iteraciones)
   - Resistencia timing attacks (comparación constante)

✅ Offline-First
   - Login funciona sin internet
   - Fallback automático a SQLite
   - Sincronización cuando se reconecta

✅ Validación Fuerte
   - Requisitos de contraseña claros
   - Feedback inmediato al usuario
   - Previene contraseñas débiles

✅ Compatible
   - Mismo algoritmo Flutter ↔ Node.js
   - Hashes intercambiables entre plataformas
   - Migraciones automáticas

✅ Production Ready
   - Tested completo
   - Documentado
   - Error handling robusto
```

---

**Status:** ✅ Listo para usar  
**Tiempo setup:** < 5 minutos  
**Tiempo testing:** 20-30 minutos  
**¿Preguntas?** Ver `PASSWORD_SECURITY.md`
