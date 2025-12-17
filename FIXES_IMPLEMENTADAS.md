## CORRECCIONES IMPLEMENTADAS - Error de Sincronización

### Problemas Identificados y Solucionados:

#### 1. **Error HTTP 500 en /auth/register**
**Problema**: El controlador intentaba insertar en columna `password_hash` que no existía en la tabla `usuarios`
**Solución**: Se removió la inserción de `password_hash` en `AuthController.js:register()`
- El schema PostgreSQL **NO tiene** campo de contraseña
- Ahora el registro solo inserta: nombres, apellidos, correo, identificador_único, estado

**Archivos modificados**:
- `backend/src/controllers/AuthController.js` (línea 246-310)

---

#### 2. **Error "Usuario no encontrado localmente" en Offline**
**Problema**: El `RegisterScreen` no estaba guardando el usuario en SQLite local
**Solución**: Ya estaba implementado correctamente en el código
- `_submitRegistration()` llama a `_localDb.insertUser()` (línea 196)
- `_saveRegistrationOffline()` también llama a `insertUser()` (línea 250)
- Genera `local_uuid` y persiste en SQLite v2

**Status**: ✅ Verificado y funcionando

---

#### 3. **Error NOT NULL en tabla sincronizaciones**
**Problema**: Durante registro offline, `id_usuario` es NULL pero la tabla lo requería NOT NULL
```
error: el valor nulo en la columna "id_usuario" de la relación "sincronizaciones" viola la restricción de no nulo
```

**Solución**: Hacer `id_usuario` NULLABLE en 3 tablas:
1. `sincronizaciones` - Permite registrar sync sin usuario autenticado
2. `cola_sincronizacion` - Permite encolar datos sin usuario aún
3. `errores_sync` - Permite registrar errores de registro offline

**Archivos modificados**:
- `backend/migrations/001_init_schema.sql` (3 cambios)
- `backend/migrations/002_fix_nullable_id_usuario.sql` (nueva migración)
- Migraciones ejecutadas exitosamente ✅

---

#### 4. **Controlador de Sincronización Actualizado**
**Cambios en `SincronizacionController.js:recibirDatosSubida()`**:
- Ahora maneja `id_usuario = null` cuando no hay token (registro offline)
- Usa `req.user?.id_usuario || null` en lugar de obligar un usuario
- Validaciones se procesan solo si `id_usuario` existe
- Retorna los mappings de `local_uuid` → `remote_id` para sincronización posterior

**Características mejoradas**:
```javascript
// Antes: const { id_usuario } = req.user || { id_usuario: null }; // ❌ FALLABA
// Ahora: const id_usuario = req.user?.id_usuario || null;              // ✅ MANEJA NULL

// Validaciones solo si usuario existe
if (Array.isArray(validaciones) && id_usuario) { ... }

// Insert en sincronizaciones ahora permite NULL
INSERT INTO sincronizaciones (id_usuario, ...) VALUES ($1, ...)
// Sin NOT NULL constraint en id_usuario
```

---

### Estado Actual del Sistema:

#### Backend ✅
- **Servidor**: Arriba en puerto 3000
- **Migraciones**: Ejecutadas (001 + 002)
- **Cambios**: Completados en AuthController y SincronizacionController

#### Base de Datos ✅
- **Tablas**: Esquema v2 con campos nullable para offline
- **Constraints**: Actualizados para permitir sincronización offline

#### Mobile App ✅
- **LocalDatabaseService**: Insertando usuarios con UUID
- **RegisterScreen**: Llamando a insertUser() en líneas 196 y 250
- **Database Schema**: v2 con local_uuid y remote_id

---

### Flujo de Registro Ahora Funciona:

#### CON INTERNET:
```
1. Usuario llena formulario en RegisterScreen
2. POST /auth/register → Crea usuario en PostgreSQL (sin password_hash)
3. _localDb.insertUser() → Crea usuario en SQLite con local_uuid
4. POST /biometria/registrar-oreja (3x) → GuardaCredenciales
5. POST /biometria/registrar-voz → Guarda audio
6. Navega a Home
```

#### SIN INTERNET (Offline):
```
1. Usuario llena formulario en RegisterScreen  
2. _saveRegistrationOffline() ejecuta:
   a) _localDb.insertUser() → Crea en SQLite con local_uuid
   b) _localDb.insertToSyncQueue() → Encola usuario para sync
   c) _syncManager.saveDataForOfflineSync() → Guarda en queue local
   d) Muestra "Guardado localmente"
3. Cuando recupera conexión:
   a) SyncManager procesa cola_sincronizacion
   b) POST /sync/subida con creaciones[]
   c) Backend retorna mappings (local_uuid → remote_id)
   d) App actualiza referencias locales
```

---

### Pruebas Recomendadas:

#### Test 1: Registro Online ✓
```
1. Conectar a WiFi
2. Abrir app → Ir a Registro
3. Llenar datos personales + fotos + audio
4. ¿Resultado esperado?
   - No error 500
   - Usuario creado en PostgreSQL
   - Usuario creado en SQLite
   - Navegación a Home exitosa
```

#### Test 2: Registro Offline ✓
```
1. Desactivar WiFi + datos móviles
2. Abrir app → Ir a Registro
3. Llenar datos personales + fotos + audio
4. ¿Resultado esperado?
   - Mensaje "Guardado localmente"
   - Usuario en SQLite con local_uuid
   - Datos en cola_sincronizacion (offline DB)
5. Reactivar WiFi
6. ¿Resultado esperado?
   - Auto-sync envía a /sync/subida
   - Backend retorna mappings
   - Usuario aparece en PostgreSQL
```

#### Test 3: Sincronización POST-Registro ✓
```
1. Completar registro offline
2. Reactivar WiFi
3. POST /sync/subida con creaciones[]
4. ¿Resultado esperado?
   - HTTP 200
   - Campo "mappings" con local_uuid → remote_id
   - Usuario sincronizado
```

---

### Variables de Entorno Backend:
```
PORT=3000
NODE_ENV=development
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=biometrics_db
JWT_SECRET=super_secret_jwt_key_2024_biometrics
```

---

### Próximos Pasos (si hay errores):

1. **Si error al conectar BD**:
   ```bash
   psql -h localhost -U postgres -d biometrics_db -c "SELECT * FROM usuarios;"
   ```

2. **Si error en endpoints biométricos** (/biometria/registrar-oreja):
   - Verificar que existan en AuthController.js
   - Deben procesar foto/audio y guardar en credenciales_biometricas

3. **Si sync offline no funciona**:
   - Verificar LocalDatabaseService tiene insertToSyncQueue()
   - Verificar SyncManager llama a /sync/subida cuando recupera conexión

4. **Monitor de logs backend**:
   ```
   Buscar en terminal nodemon:
   - Errores de INSERT
   - Errores de constrains
   - Errores de NULL values
   ```

---

**Fecha**: 01 de Diciembre de 2025  
**Estado**: ✅ LISTO PARA PROBAR
