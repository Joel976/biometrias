## GUÍA DE TESTING - Errores de Sincronización Corregidos

### 📚 Documentación Relacionada
- **Sincronización Bidireccional:** Ver `SINCRONIZACION_BIDIRECCIONAL.md`
- **Guía Completa:** Backend ↔ Frontend con ejemplos y configuración

---

### Estado Actual:

✅ **Backend**: En ejecución en `http://localhost:3000`  
✅ **Base de Datos**: Migraciones aplicadas  
✅ **AuthController**: Corregido para no insertar `password_hash`  
✅ **SincronizacionController**: Maneja `id_usuario = null` para offline  
✅ **Sincronización Bidireccional**: Implementada (App ⇄ Backend)

---

### Errores Corregidos:

#### Error 1: HTTP 500 en /auth/register
```
ANTES:
  INSERT INTO usuarios (..., password_hash, ...) 
  → ❌ Columna no existe → HTTP 500

AHORA:
  INSERT INTO usuarios (nombres, apellidos, ...) 
  → ✅ Sin password_hash
```

**Causante**: `backend/src/controllers/AuthController.js`  
**Solución**: Remover insert de `password_hash`  
**Status**: ✅ CORREGIDO

---

#### Error 2: "Usuario no encontrado localmente" en Offline
```
ANTES:
  _saveRegistrationOffline() → No llamaba insertUser()
  → ❌ Usuario no en SQLite

AHORA:
  _saveRegistrationOffline() 
  → _localDb.insertUser() ← Crea usuario local
  → _localDb.insertToSyncQueue() ← Encola para sync
```

**Causante**: Flujo de offline en `mobile_app/lib/screens/register_screen.dart`  
**Solución**: Ya estaba implementado, solo verificado  
**Status**: ✅ FUNCIONANDO

---

#### Error 3: NOT NULL constraint en id_usuario
```
ERROR:
  Error en subida de sincronización: error: el valor nulo en la 
  columna "id_usuario" de la relación "sincronizaciones" viola 
  la restricción de no nulo

CAUSA:
  Tabla sincronizaciones tiene: id_usuario INTEGER NOT NULL
  Pero en registro offline, no hay usuario aún → NULL

SOLUCIÓN:
  ALTER TABLE sincronizaciones 
    ALTER COLUMN id_usuario DROP NOT NULL;
```

**Causante**: `backend/migrations/001_init_schema.sql`  
**Solución**: Migración 002 aplicada  
**Status**: ✅ CORREGIDO

---

### Cómo Probar:

#### OPCIÓN A: Prueba desde Flutter (Recomendado)

1. **Terminal 1: Backend ejecutándose**
   ```powershell
   cd c:\Users\User\Downloads\biometrias\backend
   npm run dev
   # Debe mostrar:
   # Servidor Biométrico iniciado
   # Puerto: 3000
   # Entorno: development
   ```

2. **Terminal 2: Ejecutar app Flutter**
   ```powershell
   cd c:\Users\User\Downloads\biometrias\mobile_app
   flutter run
   ```

3. **Prueba Manual (Registro Online)**:
   - Conectar WiFi
   - Tap en "Registrarse"
   - Llenar: Nombres, Apellidos, Email, Identificador Único, Contraseña
   - Tap en "Siguiente" → Capturar 3 fotos de oreja
   - Tap en "Siguiente" → Grabar audio de voz
   - Tap en "Registrarse"
   - **Esperado**: ✅ No HTTP 500, Usuario creado, Navega a Home

4. **Prueba Manual (Registro Offline)**:
   - Desactivar WiFi/datos móviles
   - Tap en "Registrarse"
   - Llenar datos + fotos + audio
   - Tap en "Registrarse"
   - **Esperado**: ✅ Mensaje "Guardado localmente"
   - Reactivar WiFi
   - **Esperado**: ✅ App auto-sincroniza

---

#### OPCIÓN B: Prueba desde Terminal (Avanzado)

1. **Verificar endpoint /auth/register**:
   ```powershell
   $body = @{
       nombres = "Juan"
       apellidos = "Pérez"
       email = "juan@test.com"
       identificadorUnico = "ID12345"
       contrasena = "pass123"
   } | ConvertTo-Json

   curl -X POST http://localhost:3000/auth/register `
     -ContentType "application/json" `
     -Body $body
   ```
   
   **Esperado**:
   ```json
   {
     "success": true,
     "mensaje": "Usuario registrado exitosamente",
     "usuario": {
       "id_usuario": 1,
       "nombres": "Juan",
       "apellidos": "Pérez",
       "identificador_unico": "ID12345"
     },
     "token": "eyJh..."
   }
   ```

2. **Verificar endpoint /sync/ping**:
   ```powershell
   curl http://localhost:3000/sync/ping
   ```
   
   **Esperado**:
   ```json
   {
     "status": "ok",
     "timestamp": "2025-12-01T16:43:29.273Z",
     "servidor": "Servidor Biométrico"
   }
   ```

3. **Simular subida offline**:
   ```powershell
   $body = @{
       dispositivo_id = "device_001"
       creaciones = @(
           @{
               local_uuid = "uuid-123"
               tipo_entidad = "usuario"
               datos = @{
                   nombres = "Carlos"
                   apellidos = "López"
                   identificador_unico = "ID99999"
                   estado = "activo"
               }
               id_cola = 1
           }
       )
   } | ConvertTo-Json -Depth 5

   curl -X POST http://localhost:3000/sync/subida `
     -ContentType "application/json" `
     -Body $body
   ```
   
   **Esperado**:
   ```json
   {
     "success": true,
     "exitosas": 1,
     "mappings": [
       {
         "local_uuid": "uuid-123",
         "entidad": "usuario",
         "remote_id": 2,
         "id_cola": 1
       }
     ]
   }
   ```

---

### Checklist de Verificación:

#### Backend
- [ ] `npm run dev` inicia sin errores
- [ ] Puerto 3000 responde a `/sync/ping`
- [ ] `/auth/register` retorna HTTP 201 (no 500)
- [ ] `/sync/subida` acepta requests sin token
- [ ] Migraciones ejecutadas: `node migrations/runMigrations.js`

#### Base de Datos (PostgreSQL)
```sql
-- Verificar estructura de tablas
\d sincronizaciones
-- Debe mostrar: id_usuario | integer |  | | (sin NOT NULL)

\d cola_sincronizacion  
-- Debe mostrar: id_usuario | integer |  | | (sin NOT NULL)

\d errores_sync
-- Debe mostrar: id_usuario | integer |  | | (sin NOT NULL)

-- Verificar datos insertados
SELECT * FROM usuarios;
SELECT * FROM sincronizaciones;
SELECT * FROM cola_sincronizacion;
```

#### Mobile App
- [ ] Flutter compila sin errores: `flutter pub get`
- [ ] App inicia: `flutter run`
- [ ] Screen Registro aparece
- [ ] LocalDatabaseService inicializa
- [ ] Camera y Audio servicios disponibles

---

### Si Aún Hay Errores:

#### Error: "relation sincronizaciones does not exist"
```
Solución: Ejecutar migraciones nuevamente
> node migrations/runMigrations.js
```

#### Error: "EADDRINUSE: address already in use :::3000"
```powershell
# Matar procesos node
Get-Process -Name node | Stop-Process -Force
# Esperar 2 segundos
Start-Sleep 2
# Reiniciar
npm run dev
```

#### Error: "error: el valor nulo en la columna id_usuario"
```
Solución: Aplicar migración 002
> psql -h localhost -U postgres -d biometrics_db -f migrations/002_fix_nullable_id_usuario.sql
```

#### Error: "Cannot read property 'insertUser' of undefined"
```
Verificar: LocalDatabaseService está inicializado
- flutter pub add sqflite (ya ejecutado)
- flutter pub run build_runner build
- Limpiar build: flutter clean
```

---

### Monitoreo en Vivo:

#### Terminal Backend (nodemon):
```
Buscar estos logs exitosos:
✓ Migración completada: 001_init_schema.sql
✓ Migración completada: 002_fix_nullable_id_usuario.sql
✓ ¡Todas las migraciones se ejecutaron exitosamente!

Servidor Biométrico iniciado
Puerto: 3000
Entorno: development
```

#### Terminal Flutter:
```
Buscar sin errores:
Building with sound null safety
✓ Built build/app/outputs/flutter-apk/app-debug.apk

Sin errores de:
- MissingPluginException
- PlatformException
- DatabaseException
```

---

### Resumen de Cambios Hechos:

| Archivo | Línea | Cambio |
|---------|-------|--------|
| `AuthController.js` | 246-310 | Remover `password_hash` del INSERT |
| `SincronizacionController.js` | 77 | Manejar `id_usuario = null` |
| `001_init_schema.sql` | 79, 94, 107 | Remover NOT NULL en id_usuario |
| `002_fix_nullable_id_usuario.sql` | NEW | Migración para ALTER TABLE |
| `register_screen.dart` | 196, 250 | ✅ Verificado insertUser() |
| `local_database_service.dart` | - | ✅ Verificado insertUser() |

---

**Fecha**: 01 de Diciembre de 2025  
**Estado**: ✅ LISTO PARA TESTING

📱 Frontend (Flutter)
  ↓
  1. AuthService.register()
  ↓
  2. Dio hace POST a http://10.52.41.36:3000/api/auth/register
  ↓
  3. Headers: { "Content-Type": "application/json" }
  ↓
  4. Body: { "nombres": "...", "apellidos": "...", ... }
  ↓
🌐 RED (WiFi/Datos)
  ↓
💻 Backend (Node.js)
  ↓
  5. CORS middleware verifica origen → ✅ Permite
  ↓
  6. express.json() parsea el body
  ↓
  7. authRoutes.js → router.post('/register')
  ↓
  8. AuthController.register() → INSERT en PostgreSQL
  ↓
  9. Responde: { "message": "Usuario registrado", "id_usuario": 1 }
  ↓
🌐 RED
  ↓
📱 Frontend
  ↓
  10. Dio recibe response (200 OK)
  ↓
  11. AuthService procesa la respuesta
  ↓
  12. Guarda usuario en SQLite local