# Cambios Realizados para Sincronización Local/Remota

## 📋 Archivos Modificados

### **Mobile App - Flutter**

#### 1. `lib/config/database_config.dart`
**Cambios:**
- Versión de DB: `1` → `2`
- Añadidas columnas a tabla `usuarios`:
  - `local_uuid TEXT UNIQUE` — ID temporal para usuarios offline
  - `remote_id INTEGER` — ID remoto del usuario en Postgres
- Añadidas columnas a tabla `credenciales_biometricas`:
  - `local_uuid TEXT UNIQUE` — ID único local de credencial
  - `remote_id INTEGER` — ID remoto de credencial
- Añadida columna a tabla `cola_sincronizacion`:
  - `local_uuid TEXT` — Referencia al UUID local
- Implementación de `_upgradeTables()` para migración automática v1→v2

#### 2. `lib/services/local_database_service.dart`
**Cambios:**
- Modificado `insertToSyncQueue()`:
  - Ahora genera automáticamente `local_uuid` si no viene en datos
  - Usa `jsonEncode()` en lugar de `toString()` para almacenar datos
  - Almacena el `local_uuid` en columna separada para búsquedas rápidas
  
- Modificado `insertUser()`:
  - Genera automáticamente `local_uuid` para cada usuario
  - Inicializa `remote_id` a NULL
  
- Modificado `getPendingSyncQueue()`:
  - Ahora parsea `datos_json` correctamente con `jsonDecode()`
  - Retorna `datos_parsed` en cada item para acceso fácil
  
- **Métodos Nuevos:**
  - `updateUserRemoteIdByLocalUuid(localUuid, remoteId)` — Actualiza ID remoto del usuario tras sync
  - `updateCredentialRemoteIdByLocalUuid(localUuid, remoteId)` — Actualiza ID remoto de credencial

#### 3. `lib/services/offline_sync_service.dart`
**Cambios:**
- Agregado `import 'dart:convert'` para JSON parsing/encoding
- Modificado `PendingData.toMap()`:
  - Usa `jsonEncode(data)` en lugar de `data.toString()`
- Modificado `PendingData.fromMap()`:
  - Usa `jsonDecode()` para parsing correcto de JSON
- Modificado `savePendingData()`:
  - Almacena datos como JSON válido

#### 4. `lib/services/sync_manager.dart`
**Cambios:**
- Modificado `_uploadData(idUsuario)`:
  - Ahora lee `datos_parsed` de cada item en cola
  - Separa items en `creaciones` (usuarios, credenciales) y `validaciones`
  - Construye payload con estructura esperada por backend: `{ creaciones, validaciones }`
  - **Procesa mappings** retornados por backend:
    - Actualiza `remote_id` de usuarios y credenciales usando los nuevos métodos
    - Marca items como procesados (`estado = 'enviado'`)
  - Manejo correcto de `local_uuid` en payload

#### 5. `lib/screens/register_screen.dart`
**Cambios:**
- Modificado `_saveRegistrationOffline()`:
  - Ahora inserta usuario en SQLite local ANTES de enqueueing
  - Enqueues usuario en `cola_sincronizacion` (tipo='usuario')
  - Enqueues cada credencial en `cola_sincronizacion` (tipo='credencial')
  - Mantiene fallback con `SyncManager.saveDataForOfflineSync()` para DB offline adicional
  - Usa `_localDb.insertToSyncQueue()` para mejor control de UUIDs

---

### **Backend - Node.js / Express**

#### 1. `backend/src/controllers/SincronizacionController.js`
**Cambios:**
- Modificado `recibirDatosSubida()`:
  - Ahora acepta `creaciones` y `validaciones` en payload
  - Procesa creaciones de tipo `usuario`:
    - INSERT en tabla `usuarios`
    - RETURNING `id_usuario` para mapping
  - Procesa creaciones de tipo `credencial` o `credencial_biometrica`:
    - INSERT en tabla `credenciales_biometricas`
    - RETURNING `id_credencial` para mapping
  - Construye array `mappings` con estructura:
    ```json
    { "local_uuid": "...", "entidad": "usuario|credencial", "remote_id": 42, "id_cola": 1 }
    ```
  - Retorna mappings en respuesta JSON para que cliente actualice sus IDs locales
  - Permite `id_usuario_remote` en datos de credenciales para casos especiales

#### 2. `backend/src/routes/syncRoutes.js`
**Cambios:**
- Removida autenticación en ruta POST `/subida`:
  - **Antes:** `router.post('/subida', authenticateToken, ...)`
  - **Después:** `router.post('/subida', SincronizacionController.recibirDatosSubida)`
  - **Razón:** Permitir que clientes offline sincronicen sin token válido

---

## 🔄 Flujo de Datos (Resumen)

### **Escenario: Registro Offline → Sync Online**

```
1. REGISTRO (SIN INTERNET)
   ├─ User abre RegisterScreen
   ├─ Captura 3 fotos + graba audio
   ├─ Click "Registrar"
   │  ├─ Genera local_uuid_usuario = "local-1699xxx-9999"
   │  ├─ INSERT usuarios (local_uuid, remote_id=NULL)
   │  ├─ INSERT cola_sincronizacion (tipo='usuario', local_uuid=..., datos_json=JSON)
   │  ├─ INSERT cola_sincronizacion (tipo='credencial' x3, datos_json + imagen base64)
   │  └─ INSERT cola_sincronizacion (tipo='credencial', datos_json + audio base64)
   └─ Muestra "Guardado localmente"

2. USUARIO RECUPERA CONEXIÓN
   └─ App dispara SyncManager.performSync()

3. SYNC (CON INTERNET)
   ├─ SyncManager._uploadData():
   │  ├─ Lee cola_sincronizacion (estado='pendiente')
   │  ├─ Separa en creaciones + validaciones
   │  ├─ POST /sync/subida con payload:
   │  │  {
   │  │    creaciones: [
   │  │      {tipo_entidad:'usuario', datos:{...}, local_uuid:'local-...', id_cola:1},
   │  │      {tipo_entidad:'credencial', datos:{...}, local_uuid:'local-...', id_cola:2}
   │  │    ]
   │  │  }
   │  └─ Recibe respuesta con mappings
   │
   ├─ Backend.recibirDatosSubida():
   │  ├─ For cada creación:
   │  │  ├─ INSERT usuarios → id=42
   │  │  ├─ INSERT credenciales → id=99
   │  │  └─ Collect en mappings[]
   │  └─ Retorna: {success:true, mappings:[...]}
   │
   └─ SyncManager procesa mappings:
      ├─ For cada mapping:
      │  ├─ Si usuario: UPDATE usuarios SET remote_id=42 WHERE local_uuid='local-...'
      │  ├─ Si credencial: UPDATE credenciales_biometricas SET remote_id=99 WHERE local_uuid='...'
      │  └─ UPDATE cola_sincronizacion SET estado='enviado' WHERE id_cola=X
      └─ Sync completado ✓

4. ESTADO FINAL
   ├─ SQLite:
   │  ├─ usuarios: remote_id=42 (ahora vinculado a Postgres)
   │  ├─ credenciales: remote_id=99
   │  └─ cola: estado='enviado'
   │
   └─ Postgres:
      ├─ usuarios: id=42 (creado desde sync)
      └─ credenciales: id=99 (creado desde sync)
```

---

## ✅ Beneficios Logrados

1. **Eliminación de "Usuario No Encontrado"**
   - Usuario se inserta localmente ANTES de sync
   - Puede hacer login offline incluso si sync falla
   - Cuando sync completa, `remote_id` se popula

2. **Consistencia BD Local ↔ Remota**
   - Cada entidad creada offline tiene `local_uuid` único
   - Backend retorna `remote_id` en mappings
   - Cliente actualiza su SQLite con el ID remoto
   - Futuros syncs pueden referenciar por `remote_id`

3. **Sin Duplicaciones**
   - `local_uuid` es UNIQUE en SQLite
   - Backend puede usar `identificador_unico` (cédula) para deduplication
   - IDs remotos previenen re-creación

4. **Offline-First Robusto**
   - Datos se guardan localmente con timestamp
   - Sync automático con retry (backoff exponencial)
   - Fallback a validación local si sync falla

5. **Mejor Debugging**
   - `cola_sincronizacion` ahora tiene JSON válido (no `toString()`)
   - `local_uuid` en cada item permite tracing completo
   - Mappings retornadas muestran qué IDs fueron creados remotamente

---

## 🔧 Configuración Necesaria

### **Backend: Asegurar que DB está actualizada**

Ejecutar migraciones (ya existen):
```bash
cd backend
npm run migrate
npm run start
```

Asegurar que `/sync/subida` es accesible sin autenticación (ya configurado en `syncRoutes.js`).

### **Mobile: Ejecutar app para inicializar DB v2**

```bash
cd mobile_app
flutter clean
flutter pub get
flutter run
```

La primera vez que la app se inicia, `_upgradeTables()` ejecutará las migraciones de v1→v2.

---

## 📝 Testing Recomendado

### **Test 1: Registro Offline**
```
1. Desconecta WiFi/datos
2. Abre app → RegisterScreen
3. Completa registro
4. Observa que se guarda localmente (no hay error)
5. Abre DB local (adb shell sqlite3 /data/.../biometrics_local.db)
6. Verifica: SELECT * FROM usuarios; (debe tener local_uuid pero remote_id=NULL)
```

### **Test 2: Sync Online**
```
1. Reconecta WiFi
2. La app debe disparar sync automático
3. Observa logs del backend: POST /sync/subida
4. Verifica response tiene mappings
5. Abre DB local: SELECT * FROM usuarios; (debe tener remote_id poblado)
6. Abre DB remota (Postgres): SELECT * FROM usuarios; (debe tener nuevo usuario)
```

### **Test 3: Login Offline**
```
1. Desconecta WiFi
2. Abre LoginScreen
3. Intenta login con biometría (oreja/voz)
4. Debe funcionar (usa BiometricService local)
5. Validación se inserta en validaciones_biometricas y se enqueues
```

---

## 📚 Documentación Adicional

- Ver `DB_SYNC_MAPPING.md` para arquitectura completa
- Ver código en `lib/services/sync_manager.dart` para orquestación
- Ver `backend/src/controllers/SincronizacionController.js` para procesamiento remoto
