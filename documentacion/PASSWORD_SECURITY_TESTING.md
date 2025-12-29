# 🧪 Password Security Testing Guide

## Quick Start Test

### Pre-requisitos
```bash
# Backend encendido
cd backend
npm start
# → Server escuchando en http://localhost:3000

# Mobile app lista
cd mobile_app
flutter run
# → App lista en device/emulator
```

---

## Test Scenarios

### Test 1: Registration with Strong Password

**Objetivo:** Verificar que registro con contraseña fuerte funciona

**Pasos:**
1. Abre la app → RegisterScreen
2. Ingresa datos:
   - Nombres: "Juan"
   - Apellidos: "Pérez"
   - Identificador: "juan.perez@123"
   - **Contraseña: "Juan@2024secure"** (cumple requisitos)
3. Captura foto oreja + audio
4. Tap "Enviar"

**Resultado esperado:**
```json
✅ Usuario registrado exitosamente
  • Contraseña hasheada localmente en SQLite
  • Contraseña enviada a backend
  • Backend valida fortaleza
  • Backend hashea y almacena en PostgreSQL
  • Response 201: { success: true, usuario: {...}, token: "..." }
```

**Verificación en terminal (Backend):**
```bash
# En PostgreSQL
psql -U postgres -d biometrias

SELECT id_usuario, identificador_unico, password_hash FROM usuarios 
WHERE identificador_unico = 'juan.perez@123';

# Esperado: password_hash formato "salt$hash" (ejemplo: "a7f3b9c2e...bcf$8f3a1b9c2...")
```

---

### Test 2: Registration with Weak Password

**Objetivo:** Verificar rechazo de contraseñas débiles

**Pasos:**
1. RegisterScreen
2. Ingresa:
   - Nombres: "Pedro"
   - Apellidos: "García"
   - Identificador: "pedro.garcia@123"
   - **Contraseña: "123456"** (solo números)
3. Tap "Enviar"

**Resultado esperado:**
```json
❌ Error 400: Contraseña débil
   mensaje: "Contraseña debe contener mayúsculas, minúsculas, números y caracteres especiales"
   
ℹ️ En Flutter: Mostrar mensaje en SnackBar rojo
```

---

### Test 3: Duplicate User Registration

**Objetivo:** Prevenir usuarios duplicados

**Pasos:**
1. Intenta registrar usuario "juan.perez@123" nuevamente
2. Ingresa nueva contraseña (ej: "NewPass@2024")

**Resultado esperado:**
```json
❌ Error 409: Usuario ya existe
   error: "❌ Usuario ya existe"
   mensaje: "El identificador único 'juan.perez@123' ya está registrado..."
   codigo: "USUARIO_DUPLICADO"
```

---

### Test 4: Online Login with Correct Password

**Objetivo:** Autenticación online funciona con validación de hash

**Pasos:**
1. Cierra sesión (logout)
2. LoginScreen
3. Ingresa:
   - Identificador: "juan.perez@123"
   - Contraseña: "Juan@2024secure"
4. Tap "Login"
5. Completa biometría si se solicita

**Resultado esperado:**
```json
✅ Autenticación exitosa
   usuario: { id_usuario: 1, nombres: "Juan", apellidos: "Pérez" }
   tokens: { accessToken: "eyJhbGc...", refreshToken: "...", expiresIn: 3600 }
   
→ HomeScreen abierta
→ Access token válido en todas las APIs subsecuentes
```

**Verificación:**
```dart
// En Flutter console
print(AuthServiceFix.instance.accessToken);
// → Debe mostrar JWT token válido
```

---

### Test 5: Online Login with Wrong Password

**Objetivo:** Rechazar credenciales inválidas

**Pasos:**
1. LoginScreen
2. Ingresa:
   - Identificador: "juan.perez@123"
   - Contraseña: "WrongPassword@123" ❌
3. Tap "Login"

**Resultado esperado:**
```json
❌ Error 401: Credenciales inválidas
   error: "Contraseña incorrecta"
   
ℹ️ En Flutter: Toast rojo "Contraseña incorrecta"
→ Permanecer en LoginScreen
→ Permitir reintentar
```

---

### Test 6: Offline Login with Correct Password

**Objetivo:** Verificar fallback a autenticación local sin internet

**Pasos:**
1. **Antes:** Hacer login online exitoso para descargar datos locales
2. **Activar Airplane Mode** (desconectar internet)
3. Cierra sesión
4. LoginScreen (sin internet)
5. Ingresa:
   - Identificador: "juan.perez@123"
   - Contraseña: "Juan@2024secure"
6. Tap "Login"

**Resultado esperado:**
```json
✅ Autenticación OFFLINE exitosa
   usuario: { id_usuario: 1, nombres: "Juan", apellidos: "Pérez" }
   tokens: { 
     accessToken: "offline_1_1234567890123",  ← Formato especial
     refreshToken: null,
     expiresIn: 900  ← 15 minutos en lugar de 1 hora
   }
   modo: "OFFLINE"
   
→ HomeScreen abierta
→ Nota: "Modo offline - Sincronización pendiente"
```

**Verificación en Logs:**
```
[AuthServiceFix] Intento de login online falló: connectionTimeout
[AuthServiceFix] Intentando login offline...
[LocalDatabaseService] Verificando password local...
[AuthServiceFix] Login offline exitoso. Token temporal: offline_1_...
```

---

### Test 7: Offline Login with Wrong Password

**Objetivo:** Rechazar credenciales incorrectas incluso offline

**Pasos:**
1. **Con Airplane Mode activado**
2. LoginScreen
3. Ingresa:
   - Identificador: "juan.perez@123"
   - Contraseña: "WrongPassword@123" ❌
4. Tap "Login"

**Resultado esperado:**
```json
❌ Error: Credenciales inválidas (modo offline)
   error: "Contraseña incorrecta"
   modo: "OFFLINE"
   
ℹ️ En Flutter: Toast rojo
→ Permanecer en LoginScreen
→ No genera token offline
```

---

### Test 8: Offline User Not Registered

**Objetivo:** Usuario que nunca hizo login online no puede hacer login offline

**Pasos:**
1. Registra usuario SOLO en backend (no sincronizado a mobile)
2. **Activar Airplane Mode**
3. LoginScreen
4. Intenta login con ese usuario

**Resultado esperado:**
```json
❌ Error: Usuario no encontrado
   error: "Usuario no registrado localmente. Requiere login online inicial"
   
ℹ️ En Flutter: Toast con instrucciones
→ Forzar que se conecte a internet y haga login online
```

---

### Test 9: Password Hash Verification (Backend Unit Test)

**Objetivo:** Verificar que el algoritmo PBKDF2-like funciona correctamente

**Pasos:**
```bash
# En backend, crea archivo test.js
const PasswordService = require('./src/utils/PasswordService');

// Test 1: Hash y Verify
const pwd = "TestPassword123!";
const hash = PasswordService.hashPassword(pwd);
console.log("Hash:", hash);

const isValid = PasswordService.verifyPassword(pwd, hash);
console.log("Válido:", isValid);  // → true

const isInvalid = PasswordService.verifyPassword("WrongPassword", hash);
console.log("Inválido:", isInvalid);  // → false

// Test 2: Fortaleza
const fuerte = PasswordService.validatePasswordStrength("Strong@Pass123");
const debil = PasswordService.validatePasswordStrength("weak");

console.log("Fuerte:", fuerte);  // → { isValid: true, message: "..." }
console.log("Débil:", debil);    // → { isValid: false, message: "..." }

// Ejecutar
node test.js
```

**Resultado esperado:**
```
Hash: a7f3b9c2e1d4f6a8b0c3d5e7f9a1b3c5$8f3a1b9c2e5d7f0a1c4e6b8d0f2a4c6
Válido: true
Inválido: false
Fuerte: { isValid: true, message: 'Contraseña fuerte ✓' }
Débil: { isValid: false, message: 'Contraseña debe tener al menos 6 caracteres' }
```

---

### Test 10: Hash Consistency (Same Password = Different Hash)

**Objetivo:** Verificar que cada password genera hash único (salt diferente)

**Pasos:**
```bash
# Backend test
const PasswordService = require('./src/utils/PasswordService');

const pwd = "SamePassword123!";
const hash1 = PasswordService.hashPassword(pwd);
const hash2 = PasswordService.hashPassword(pwd);
const hash3 = PasswordService.hashPassword(pwd);

console.log("Hash 1:", hash1);
console.log("Hash 2:", hash2);
console.log("Hash 3:", hash3);
console.log("Todos diferentes:", hash1 !== hash2 && hash2 !== hash3 && hash1 !== hash3);  // true

// Pero todos verifican igual password
console.log("Hash 1 verifica:", PasswordService.verifyPassword(pwd, hash1));  // true
console.log("Hash 2 verifica:", PasswordService.verifyPassword(pwd, hash2));  // true
console.log("Hash 3 verifica:", PasswordService.verifyPassword(pwd, hash3));  // true

node test.js
```

**Resultado esperado:**
```
Hash 1: a7f3b9c2...1b3c5$8f3a1b9c2e5d7f0a1c4e6b8d0f2a4c6
Hash 2: d4e7f1a9...5e8f3a1c6d9e2b5f8a1c4$e9b2c5d8f1a4e7c0f3a6d9b2e5f8a1d4
Hash 3: e9b2c5d8...8f1a4e7c0f3a6d9b2e5$c1d4e7f0a3b6c9d2e5f8a1b4c7d0e3f6
Todos diferentes: true
Hash 1 verifica: true
Hash 2 verifica: true
Hash 3 verifica: true

✅ Salt único = Hashes únicos = Misma contraseña verificable
```

---

## Performance Tests

### Test 11: Hash Time Measurement

```dart
// Flutter
final stopwatch = Stopwatch()..start();
final hash = PasswordService.hashPassword("TestPassword123!");
stopwatch.stop();
print("Tiempo hash: ${stopwatch.elapsedMilliseconds}ms");
// Esperado: 400-600ms (por seguridad contra brute-force)
```

### Test 12: Verify Time Measurement

```javascript
// Backend
const start = Date.now();
const isValid = PasswordService.verifyPassword(pwd, hash);
const time = Date.now() - start;
console.log(`Tiempo verify: ${time}ms`);
// Esperado: 100-200ms
```

---

## Security Tests

### Test 13: Timing Attack Resistance

```javascript
// Backend
// Intenta verificar password incorrecto vs correcto
// Ambos deben tomar APROXIMADAMENTE el mismo tiempo

const correctHash = "a7f3b9c2e1d4f6a8b0c3d5e7f9a1b3c5$8f3a1b9c2e5d7f0a1c4e6b8d0f2a4c6";
const wrongPwd1 = "W";  // Falla en primer carácter
const wrongPwd2 = "WrongPasswordWithLongMismatchAtEnd123!";

const t1 = Date.now();
PasswordService.verifyPassword(wrongPwd1, correctHash);
const time1 = Date.now() - t1;

const t2 = Date.now();
PasswordService.verifyPassword(wrongPwd2, correctHash);
const time2 = Date.now() - t2;

console.log(`Tiempo con 'W': ${time1}ms`);
console.log(`Tiempo con 'WrongPassword...': ${time2}ms`);
// Esperado: Muy similar (~100-150ms), NO diferentes
```

---

## Database Tests

### Test 14: Verify password_hash Column Exists

```bash
# PostgreSQL
psql -U postgres -d biometrias

# Verificar columna
\d usuarios

# Esperado output:
# Column         |          Type          | Collation | Nullable | Default
# ───────────────┼────────────────────────┼───────────┼──────────┼─────────
# id_usuario     | integer                |           | not null | nextval(...)
# nombres        | character varying(255) |           | not null |
# ...
# password_hash  | character varying(255) |           |          |  ✅ AQUÍ

# Verificar datos
SELECT 
  identificador_unico,
  SUBSTRING(password_hash, 1, 32) as salt_first_32,
  LENGTH(password_hash) as total_length
FROM usuarios;

# Esperado: password_hash presente, formato "salt$hash"
```

---

## Integration Tests

### Test 15: Full Registration → Online Login → Offline Login Flow

**Escenario End-to-End:**

```
┌─ PASO 1: REGISTRO ONLINE ──────────────┐
│ 1. RegisterScreen                      │
│ 2. Ingresa datos + contraseña fuerte   │
│ 3. Backend valida + hashea             │
│ 4. PostgreSQL: password_hash guardado  │
│ 5. SQLite local: password_hash guardado│
│ 6. Response 201 ✅                     │
└────────────────────────────────────────┘
                    ↓
┌─ PASO 2: LOGIN ONLINE ─────────────────┐
│ 1. Cierra sesión (logout)              │
│ 2. LoginScreen                         │
│ 3. Ingresa credenciales                │
│ 4. Backend verifica hash PostgreSQL    │
│ 5. Backend retorna accessToken         │
│ 6. HomeScreen abierta ✅               │
└────────────────────────────────────────┘
                    ↓
┌─ PASO 3: LOGIN OFFLINE ────────────────┐
│ 1. Cierra sesión (logout)              │
│ 2. Activar Airplane Mode               │
│ 3. LoginScreen                         │
│ 4. Ingresa credenciales                │
│ 5. Timeout en Dio (no hay internet)    │
│ 6. Fallback a LocalDatabaseService    │
│ 7. Verifica hash SQLite                │
│ 8. Genera offline_token                │
│ 9. HomeScreen abierta (modo offline) ✅│
│ 10. Nota: "Sincronización pendiente"  │
└────────────────────────────────────────┘
                    ↓
┌─ PASO 4: RECONECTAR ───────────────────┐
│ 1. Desactivar Airplane Mode            │
│ 2. App detecta conexión                │
│ 3. Inicia sincronización automática    │
│ 4. Tokens se refrescan                 │
│ 5. Siguiente login: normal online ✅   │
└────────────────────────────────────────┘
```

**Verificación en Logs:**
```
✓ [Registration] Password hashed + saved locally + sent to backend
✓ [Database] PostgreSQL password_hash: "a7f3...bcf$8f3a...c6"
✓ [Database] SQLite password_hash: "a7f3...bcf$8f3a...c6"
✓ [Online Login] Password validated: OK
✓ [Online Login] Token issued: eyJhbGc...
✓ [Offline Login] Connection timeout detected
✓ [Offline Login] Local verification: OK
✓ [Offline Login] Offline token: offline_1_1234567890123
✓ [Reconnect] Auto-sync initiated
✓ [Next Login] Online authentication normal
```

---

## Troubleshooting Checklist

| Problema | Causa | Solución |
|----------|-------|----------|
| "Contraseña incorrecta" pero es correcta | Hash corrupto / BD desincronizada | Verificar password_hash en ambas BDs |
| Login offline no funciona | Usuario no registrado localmente | Hacer login online primero |
| "Columna password_hash no existe" | Migración no ejecutada | `node migrations/runMigrations.js` |
| Timeout en login | Backend no responde | Verificar: `npm start` en backend |
| Contraseña rechazada como débil | Requisitos incumplidos | Agregar mayús, minús, números y especiales |

---

## Expected Test Results Summary

```
TEST RESULTS:
═════════════════════════════════════════════════════════════
✅ Test 1:  Registration Strong Password      PASS
✅ Test 2:  Registration Weak Password        PASS
✅ Test 3:  Duplicate User                    PASS
✅ Test 4:  Online Login Correct              PASS
✅ Test 5:  Online Login Wrong Password       PASS
✅ Test 6:  Offline Login Correct             PASS
✅ Test 7:  Offline Login Wrong               PASS
✅ Test 8:  Offline Unregistered User         PASS
✅ Test 9:  Hash Unit Test                    PASS
✅ Test 10: Hash Consistency                  PASS
✅ Test 11: Hash Performance (~500ms)         PASS
✅ Test 12: Verify Performance (~100-150ms)   PASS
✅ Test 13: Timing Attack Resistance          PASS
✅ Test 14: Database Schema                   PASS
✅ Test 15: E2E Registration→Online→Offline   PASS
═════════════════════════════════════════════════════════════

Status: ✅ ALL TESTS PASSED - PRODUCTION READY
```

---

## How to Report Issues

Si algún test falla:

1. **Recopila logs:**
   ```bash
   # Flutter
   flutter logs
   
   # Backend
   npm start 2>&1 | tee server.log
   ```

2. **Toma screenshot/screencast**

3. **Anota:**
   - Test number + nombre
   - Pasos exactos para reproducir
   - Resultado esperado vs actual
   - Logs relevantes
   - Device/emulator info

4. **Reporta con formato:**
   ```
   TEST FAILED: Test 6 - Offline Login with Correct Password
   
   Steps:
   1. Made online login successfully
   2. Activated Airplane Mode
   3. Logged out and tried login
   
   Expected: ✅ Offline token generated
   Actual: ❌ Error "Usuario no encontrado"
   
   Logs:
   [AuthServiceFix] Intento online timeout
   [LocalDatabase] Error en query...
   ```

---

**Version:** 1.0  
**Status:** Ready for testing  
**Last Updated:** 2024
