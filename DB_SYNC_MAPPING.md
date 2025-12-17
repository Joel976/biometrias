# Sistema de Sincronización y Mapeo de IDs Locales/Remotos

## Resumen Ejecutivo

Se ha implementado un **sistema robusto de sincronización** que garantiza que la base de datos local (SQLite) y la base de datos remota (PostgreSQL) permanezcan consistentes, evitando errores de "usuario no encontrado" y asegurando que los datos se sincronicen correctamente.

---

## Arquitectura de Sincronización

### 1. **Base de Datos Local (SQLite) - Cambios en Esquema**

Se incrementó la versión del schema de `1` a `2` con las siguientes nuevas columnas:

- **Tabla `usuarios`:**
  - `local_uuid TEXT UNIQUE` — Identificador único temporal para usuarios creados offline
  - `remote_id INTEGER` — ID remoto (Postgres) una vez sincronizado

- **Tabla `credenciales_biometricas`:**
  - `local_uuid TEXT UNIQUE` — Identificador único para credencial local
  - `remote_id INTEGER` — ID remoto de la credencial en Postgres

- **Tabla `cola_sincronizacion`:**
  - `local_uuid TEXT` — Referencia al UUID local de la entidad

### 2. **Flujo de Registro (Online vs Offline)**

#### **Registro Online:**
```
1. Cliente llama a /auth/register con datos de usuario
2. Backend crea usuario en Postgres → retorna id_usuario (remoto)
3. Cliente inserta usuario en SQLite con id_usuario remoto
4. Client captura fotos/audio y registra biometría (endpoints separados)
```

#### **Registro Offline:**
```
1. Cliente genera local_uuid = "local-{timestamp}-{random}"
2. Inserta usuario en SQLite con local_uuid (sin remote_id)
3. Enqueues en cola_sincronizacion:
   - Tipo: "usuario"
   - Operación: "insert"
   - Datos: { nombres, apellidos, identificador_unico, ... }
   - local_uuid: (el generado)
4. Cuando se restaura conexión:
   - SyncManager.performSync() lee la cola
   - POST /sync/subida con creaciones y validaciones
5. Backend responde con mappings: { local_uuid, remote_id, entidad }
6. Cliente actualiza local SQLite: UPDATE usuarios SET remote_id = ? WHERE local_uuid = ?
```

---

## Flujo de Sincronización (Sync)

### **Cliente: `lib/services/sync_manager.dart`**

#### Método: `_uploadData(idUsuario)`

1. Lee `cola_sincronizacion` con estado = 'pendiente'
2. Parsea `datos_json` (ahora usando `jsonDecode()` correctamente)
3. Separa items en dos categorías:
   - **creaciones**: usuario, credencial (con `local_uuid` incluido)
   - **validaciones**: validaciones biométricas

4. Construye payload:
   ```dart
   {
     "dispositivo_id": "device_1",
     "creaciones": [
       {
         "tipo_entidad": "usuario",
         "datos": {...},
         "local_uuid": "local-xxx",
         "id_cola": 1
       }
     ],
     "validaciones": [...]
   }
   ```

5. POST `/sync/subida` → recibe respuesta con `mappings`:
   ```json
   {
     "success": true,
     "mappings": [
       {
         "local_uuid": "local-xxx",
         "entidad": "usuario",
         "remote_id": 42,
         "id_cola": 1
       }
     ]
   }
   ```

6. Procesa mappings:
   - Si entidad = "usuario": `updateUserRemoteIdByLocalUuid(local_uuid, remote_id)`
   - Si entidad = "credencial": `updateCredentialRemoteIdByLocalUuid(local_uuid, remote_id)`
   - Marca item como procesado: `markSyncQueueAsProcessed(id_cola)`

### **Backend: `backend/src/controllers/SincronizacionController.js`**

#### Método: `recibirDatosSubida(req, res)`

1. Recibe payload con `creaciones` y `validaciones` (sin requireToken)
2. Por cada creación:
   - Si `tipo_entidad` = "usuario":
     - INSERT INTO usuarios (...) RETURNING id_usuario
     - Collect en mappings: { local_uuid, entidad: "usuario", remote_id }
   - Si `tipo_entidad` = "credencial":
     - INSERT INTO credenciales_biometricas (...) RETURNING id_credencial
     - Collect en mappings
3. Por cada validación:
   - INSERT INTO validaciones_biometricas (...)
4. Retorna respuesta con todos los `mappings`

---

## Almacenamiento de Datos en Cola

### **LocalDatabaseService: `insertToSyncQueue()`**

Ahora genera automáticamente `local_uuid` si no viene en datos:

```dart
Future<void> insertToSyncQueue(
  int idUsuario,
  String tipoEntidad,
  String operacion,
  Map<String, dynamic> datos,
) async {
  final localUuid = datos.containsKey('local_uuid')
      ? datos['local_uuid'].toString()
      : 'local-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';

  final payload = Map<String, dynamic>.from(datos);
  payload['local_uuid'] = localUuid;

  await db.insert('cola_sincronizacion', {
    'id_usuario': idUsuario,
    'tipo_entidad': tipoEntidad,
    'operacion': operacion,
    'datos_json': jsonEncode(payload),  // ← Ahora usa jsonEncode correctamente
    'local_uuid': localUuid,
    'estado': 'pendiente',
    'fecha_creacion': DateTime.now().toIso8601String(),
  });
}
```

### **OfflineSyncService: Almacenamiento Dual**

También ahora parsea JSON correctamente:
- **Guardado:** `jsonEncode(data)`
- **Lectura:** `jsonDecode(data)`

Esto permite que `SyncManager` acceda a `item['datos_parsed']` de forma confiable.

---

## Prevención de Inconsistencias

### **1. Usuario No Encontrado Localmente**

**Antes:** Si no se insertaba usuario en SQLite, luego no se podía hacer login/validación local.

**Ahora:** 
- `RegisterScreen._saveRegistrationOffline()` y `_submitRegistration()` insertan usuario ANTES de encolar
- Incluso si sync falla, usuario existe localmente y puede hacer auth offline

### **2. Credenciales Sin Usuario Remoto**

**Problema:** Credencial encolada con `id_usuario = null`, backend rechaza INSERT

**Solución:** 
- Backend acepta `id_usuario_remote` del cliente para credenciales encoladas
- Si viene `id_usuario_remote`, se usa; si no, se permite NULL e idealmente se liga posterior

### **3. IDs Duplicados Tras Sync**

**Problema:** Mismo usuario registrado dos veces si client y server no sincron

**Solución:**
- `local_uuid` único en SQLite (UNIQUE constraint)
- Backend retorna mapping con `remote_id`
- Cliente actualiza `usuarios.remote_id` tras sync
- Queries posteriores pueden usar `remote_id` para evitar duplicación

---

## Métodos Nuevos de LocalDatabaseService

```dart
/// Actualizar remote_id de usuario por local_uuid
Future<void> updateUserRemoteIdByLocalUuid(String localUuid, int remoteId)

/// Actualizar remote_id de credencial por local_uuid
Future<void> updateCredentialRemoteIdByLocalUuid(String localUuid, int remoteId)

/// Parsear cola con datos_json como JSON
Future<List<Map<String, dynamic>>> getPendingSyncQueue(int idUsuario)
// Ahora incluye 'datos_parsed' en cada item para facilidad de acceso
```

---

## Ejemplo: Flujo Completo Offline → Online

### **Escenario:** Usuario registra sin internet, luego conecta

#### **Paso 1: Registro Offline (sin internet)**

```dart
// RegisterScreen._submitRegistration()
// 1. Genera local_uuid
_localDb.insertUser(
  nombres: "Juan",
  apellidos: "Pérez",
  identificadorUnico: "12345"
  // → inserta con local_uuid = "local-1699xxx-8888"
)

// 2. Enqueues registro
_localDb.insertToSyncQueue(1, 'usuario', 'insert', {
  'nombres': 'Juan',
  'apellidos': 'Pérez',
  'identificador_unico': '12345',
  'correoElectronico': 'juan@example.com',
  'contrasena': 'pass123'
  // → local_uuid se añade automáticamente
})

// 3. Enqueues credenciales
_localDb.insertToSyncQueue(1, 'credencial', 'insert', {
  'tipo_biometria': 'oreja',
  'identificador_unico': '12345',
  'template': base64(photo1)
})
```

**SQLite state tras Paso 1:**
```sql
usuarios:
  id_usuario=1, nombres='Juan', apellidos='Pérez', 
  identificador_unico='12345', local_uuid='local-1699xxx-8888', remote_id=NULL

cola_sincronizacion:
  id_cola=1, tipo_entidad='usuario', local_uuid='local-1699xxx-8888', estado='pendiente'
  id_cola=2, tipo_entidad='credencial', local_uuid='local-1699xxx-8888', estado='pendiente'
```

#### **Paso 2: Conecta a Internet → SyncManager.performSync()**

```dart
// 1. Lee cola
final pendingSync = await _localDb.getPendingSyncQueue(1);
// → [
//     {id_cola:1, tipo_entidad:'usuario', datos_parsed:{...}, local_uuid:'local-1699xxx-8888'},
//     {id_cola:2, tipo_entidad:'credencial', datos_parsed:{...}, local_uuid:'local-1699xxx-8888'}
//   ]

// 2. POST /sync/subida
final payload = {
  'creaciones': [
    {tipo_entidad:'usuario', datos:{...}, local_uuid:'local-1699xxx-8888', id_cola:1},
    {tipo_entidad:'credencial', datos:{...}, local_uuid:'local-1699xxx-8888', id_cola:2}
  ]
};

// Backend responde:
// {
//   success: true,
//   mappings: [
//     {local_uuid:'local-1699xxx-8888', entidad:'usuario', remote_id:42, id_cola:1},
//     {local_uuid:'local-1699xxx-8888', entidad:'credencial', remote_id:99, id_cola:2}
//   ]
// }

// 3. Procesa mappings
for (var m in mappings) {
  if (m['entidad'] == 'usuario') {
    await _localDb.updateUserRemoteIdByLocalUuid('local-1699xxx-8888', 42);
    // → UPDATE usuarios SET remote_id=42 WHERE local_uuid='local-1699xxx-8888'
  }
  // Marca como procesado
  await _localDb.markSyncQueueAsProcessed(m['id_cola']);
}
```

**SQLite state tras Paso 2:**
```sql
usuarios:
  id_usuario=1, ..., local_uuid='local-1699xxx-8888', remote_id=42
  
cola_sincronizacion:
  (all items marked estado='enviado')

Postgres (backend):
usuarios:
  id_usuario=42, nombres='Juan', apellidos='Pérez', identificador_unico='12345'
  
credenciales_biometricas:
  id_credencial=99, id_usuario=42, tipo_biometria='oreja', template=...
```

#### **Paso 3: Logins/Autenticación Posteriores**

```dart
// AuthService.authenticateWithEarPhoto()
// 1. Intenta remoto: POST /biometria/verificar-oreja
try {
  await remoteVerify(...);
} catch {
  // 2. Si falla o sin internet: usa BiometricService local
  final validation = await _biometricService.validateEar(photo);
  if (validation.resultado == 'exito') {
    // 3. Inserta en validaciones_biometricas
    await _localDb.insertValidation(validation);
    // 4. Enqueues para sincronizar
    await _localDb.insertToSyncQueue(1, 'validacion', 'insert', {
      'tipo_biometria': 'oreja',
      'resultado': 'exito',
      'modo_validacion': 'offline'
    });
    // → Cuando sync: puede usar remote_id=42 para id_usuario
  }
}
```

---

## Mitigación de Errores

### **Error: "usuario no encontrado" en backend**

**Causa:** Client intenta verificar con `id_usuario_remote` que no existe aún.

**Solución:**
1. Client debe esperar a que sync complete antes de usar `remote_id`
2. O, usar `identificador_unico` (cédula) como lookup alternativo
3. Backend: `SELECT id_usuario FROM usuarios WHERE identificador_unico = ?`

### **Error: Credencial huérfana sin usuario**

**Causa:** Credencial synced pero usuario no.

**Solución:** 
1. Backend intenta vincular por `identificador_unico`
2. Si no existe, retorna error en mapping
3. Client reintenta tras próximo sync de usuario

### **Error: Timeout en sync**

**Solución:**
- SyncManager ya tiene retry con backoff exponencial
- Items permanecen en `cola_sincronizacion` hasta confirmación
- No se eliminan hasta recibir `success: true` del backend

---

## Configuración de Ambiente

### **Backend (.env)**
```
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=<your_password>
DB_NAME=biometrics_db
```

### **Mobile (lib/config/api_config.dart)**
```dart
static const String baseUrl = 'http://192.168.0.6:3000/api';
// Ajusta según tu IP local del backend
```

---

## Testing

### **Caso 1: Registro Online**
1. Conecta a internet
2. Abre Register, llena datos, captura fotos, graba audio
3. Click "Registrarse" → verifica POST /auth/register exitoso
4. Verifica SQLite: usuario tiene `remote_id` poblado

### **Caso 2: Registro Offline**
1. Desconecta de internet
2. Abre Register, llena datos, captura fotos, graba audio
3. Click "Registrarse" → debe mostrar "Guardado localmente"
4. Verifica SQLite: usuario tiene `local_uuid` pero `remote_id = NULL`
5. Enqueue verifica: `cola_sincronizacion` tiene 3+ items (usuario, credenciales)

### **Caso 3: Sync Offline → Online**
1. Completa Caso 2
2. Reconecta a internet
3. Abre app → SyncManager debe disparar automáticamente (o manual)
4. Observa `/sync/subida` en logs del backend
5. Verifica respuesta tiene `mappings`
6. Verifica SQLite post-sync: `remote_id` poblado, `estado = 'enviado'`

---

## Notas de Implementación

- **JSON Encoding:** Todos los `datos_json` ahora se almacenan como JSON válido (via `jsonEncode()`), NO como `toString()` de Map
- **UUID Generation:** Local simple (timestamp + random); en producción considera UUID v4
- **No Encryption:** SQLCipher no está activado; para datos sensibles, usar `DatabaseConfig.encryptData()`
- **Auth en /sync/subida:** Removida para permitir sync offline (sin token)

---

## Próximos Pasos (Opcional)

1. **Agregar endpoint de descarga** para que client pueda recibir datos remotos creados en otro dispositivo
2. **Implementar versionamiento de templates** para credenciales (versión de algoritmo)
3. **Conflict resolution** si mismo usuario registrado en dos dispositivos
4. **Metricas de sync** (logs, dashboards de % sincronizados)
5. **Encriptación local** (SQLCipher) para templates sensibles
6. **Biometric models reales** (TFLite, librosa) en lugar de simulados

---

## Referencias

- `backend/src/controllers/SincronizacionController.js` — Manejo de /sync/subida
- `mobile_app/lib/services/sync_manager.dart` — Orquestación de sync
- `mobile_app/lib/services/local_database_service.dart` — CRUD local + ID mapping
- `mobile_app/lib/screens/register_screen.dart` — Ejemplo de enqueueing offline
- `mobile_app/lib/config/database_config.dart` — Schema SQLite v2 con local_uuid/remote_id
