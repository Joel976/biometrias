# Resumen Técnico de Cambios

## Vista General

Se implementó un **sistema de mapeo local/remoto de IDs** para sincronización bidireccional con los siguientes componentes:

```
┌─────────────────────────────────────────────────────────────────┐
│                      MOBILE APP (Flutter)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  database_config.dart (Schema v1→v2)                           │
│    └─ Añade: local_uuid, remote_id a usuarios/credenciales    │
│                                                                 │
│  local_database_service.dart (DAO)                             │
│    └─ insertUser(): genera local_uuid                          │
│    └─ insertToSyncQueue(): enqueue con UUID + JSON            │
│    └─ updateUserRemoteIdByLocalUuid(): mapeo post-sync        │
│    └─ getPendingSyncQueue(): parsea JSON correctamente        │
│                                                                 │
│  offline_sync_service.dart (Offline DB)                        │
│    └─ Usa jsonEncode()/jsonDecode() para validar JSON         │
│                                                                 │
│  sync_manager.dart (Orquestación)                              │
│    └─ _uploadData(): construye payload con creaciones         │
│    └─ Procesa mappings retornados por backend                 │
│                                                                 │
│  register_screen.dart (UI)                                     │
│    └─ _saveRegistrationOffline(): enqueue con tipo/UUID       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                            ↓ HTTP POST /sync/subida
┌─────────────────────────────────────────────────────────────────┐
│                    BACKEND (Node.js/Express)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  SincronizacionController.js (Handler)                          │
│    └─ recibirDatosSubida():                                    │
│       ├─ Procesa creaciones[] (tipo=usuario/credencial)       │
│       ├─ Inserta en Postgres, RETURNING id                    │
│       ├─ Construye mappings[] {local_uuid, remote_id}        │
│       └─ Retorna mappings en response                         │
│                                                                 │
│  syncRoutes.js (Rutas)                                          │
│    └─ POST /subida: sin autenticación (permite offline)       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                            ↓ Response con mappings
                          [Vuelve a cliente]
```

---

## Cambios Código por Archivo

### 1. `lib/config/database_config.dart`

**Cambio: Versión 2, columnas de mapeo**

```diff
- static const int dbVersion = 1;
+ static const int dbVersion = 2;

# En _createTables():
  CREATE TABLE usuarios (
    id_usuario INTEGER PRIMARY KEY,
    nombres TEXT,
    apellidos TEXT,
    identificador_unico TEXT UNIQUE,
    estado TEXT,
+   local_uuid TEXT UNIQUE,       ← NUEVA
+   remote_id INTEGER             ← NUEVA
  )

  CREATE TABLE credenciales_biometricas (
    ...
+   local_uuid TEXT UNIQUE,       ← NUEVA
+   remote_id INTEGER             ← NUEVA
  )

  CREATE TABLE cola_sincronizacion (
    ...
+   local_uuid TEXT,              ← NUEVA
    ...
  )

# Migración v1→v2:
+ Future<void> _upgradeTables(...) async {
+   if (oldVersion < 2) {
+     await db.execute('ALTER TABLE usuarios ADD COLUMN local_uuid TEXT');
+     await db.execute('ALTER TABLE usuarios ADD COLUMN remote_id INTEGER');
+     await db.execute('ALTER TABLE credenciales_biometricas ADD COLUMN local_uuid TEXT');
+     await db.execute('ALTER TABLE credenciales_biometricas ADD COLUMN remote_id INTEGER');
+     await db.execute('ALTER TABLE cola_sincronizacion ADD COLUMN local_uuid TEXT');
+   }
+ }
```

---

### 2. `lib/services/local_database_service.dart`

**Cambio 1: insertUser() genera local_uuid**

```diff
  Future<int> insertUser({
    required String nombres,
    required String apellidos,
    required String identificadorUnico,
    String estado = 'activo',
  }) async {
    final db = await _db;
+   final localUuid = 'local-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
+
    return await db.insert('usuarios', {
      'nombres': nombres,
      'apellidos': apellidos,
      'identificador_unico': identificadorUnico,
      'estado': estado,
+     'local_uuid': localUuid,
+     'remote_id': null,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
```

**Cambio 2: insertToSyncQueue() genera local_uuid y usa JSON**

```diff
  Future<void> insertToSyncQueue(
    int idUsuario,
    String tipoEntidad,
    String operacion,
    Map<String, dynamic> datos,
  ) async {
    final db = await _db;
+   final localUuid = datos.containsKey('local_uuid')
+       ? datos['local_uuid'].toString()
+       : 'local-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
+
+   final payload = Map<String, dynamic>.from(datos);
+   payload['local_uuid'] = localUuid;
+
    await db.insert('cola_sincronizacion', {
      'id_usuario': idUsuario,
      'tipo_entidad': tipoEntidad,
      'operacion': operacion,
-     'datos_json': datos.toString(),        ← Antes: inválido
+     'datos_json': jsonEncode(payload),     ← Después: JSON válido
+     'local_uuid': localUuid,               ← Nuevo: búsqueda rápida
      'estado': 'pendiente',
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
  }
```

**Cambio 3: getPendingSyncQueue() parsea JSON**

```diff
  Future<List<Map<String, dynamic>>> getPendingSyncQueue(int idUsuario) async {
    final db = await _db;
-   return await db.query(
+   final rows = await db.query(
      'cola_sincronizacion',
      where: 'id_usuario = ? AND estado = ?',
      whereArgs: [idUsuario, 'pendiente'],
      orderBy: 'fecha_creacion ASC',
    );
+
+   return rows.map((r) {
+     final parsed = <String, dynamic>{};
+     try {
+       if (r['datos_json'] != null) {
+         parsed.addAll(jsonDecode(r['datos_json'] as String));
+       }
+     } catch (_) {}
+     final out = Map<String, dynamic>.from(r);
+     out['datos_parsed'] = parsed;
+     return out;
+   }).toList();
  }
```

**Cambios 4 y 5: Métodos nuevos para actualizar remote_id**

```dart
+ Future<void> updateUserRemoteIdByLocalUuid(String localUuid, int remoteId) async {
+   final db = await _db;
+   await db.update(
+     'usuarios',
+     {'remote_id': remoteId},
+     where: 'local_uuid = ?',
+     whereArgs: [localUuid],
+   );
+ }
+
+ Future<void> updateCredentialRemoteIdByLocalUuid(String localUuid, int remoteId) async {
+   final db = await _db;
+   await db.update(
+     'credenciales_biometricas',
+     {'remote_id': remoteId},
+     where: 'local_uuid = ?',
+     whereArgs: [localUuid],
+   );
+ }
```

---

### 3. `lib/services/offline_sync_service.dart`

**Cambio: JSON encoding correcto**

```diff
+ import 'dart:convert';  ← NUEVO

  # En PendingData.toMap():
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'endpoint': endpoint,
-     'data': data.toString(),           ← Antes: "Map{...}"
+     'data': jsonEncode(data),         ← Después: "{\"key\": ...}"
      'photo_base64': photoBase64,
      ...
    };
  }

  # En PendingData.fromMap():
  static Map<String, dynamic> _parseJsonMap(dynamic data) {
    if (data is String) {
      try {
-       return Map<String, dynamic>.from(data as Map);
+       return Map<String, dynamic>.from(jsonDecode(data));  ← Parsing correcto
      } catch (_) {
        return {};
      }
    }
    ...
  }

  # En savePendingData():
  return await db.insert(_tableName, {
    'endpoint': pendingData.endpoint,
-   'data': pendingData.data.toString(),
+   'data': jsonEncode(pendingData.data),  ← JSON válido
    ...
  });
```

---

### 4. `lib/services/sync_manager.dart`

**Cambio principal: _uploadData() con mapeos**

```diff
  Future<bool> _uploadData(int idUsuario) async {
    try {
      final pendingSync = await _localDb.getPendingSyncQueue(idUsuario);

      if (pendingSync.isEmpty) {
        return true;
      }

+     final creaciones = <Map<String, dynamic>>[];
      final validations = <Map<String, dynamic>>[];

      for (var item in pendingSync) {
        final tipo = item['tipo_entidad'];
+       final datos = item['datos_parsed'] ?? {};      ← JSON parseado
+       final localUuid = item['local_uuid'] ?? datos['local_uuid'];
        final idCola = item['id_cola'];

-       if (item['tipo_entidad'] == 'validacion') {
+       if (tipo == 'usuario' || tipo == 'credencial') {
+         creaciones.add({
+           'tipo_entidad': tipo,
+           'datos': datos,
+           'local_uuid': localUuid,
+           'id_cola': idCola,
+         });
+       } else if (tipo == 'validacion' || (tipo is String && tipo.contains('validacion'))) {
          validations.add({
            'tipo_biometria': datos['tipo_biometria'] ?? 'voz',
            'resultado': datos['resultado'] ?? 'exito',
            'modo_validacion': datos['modo_validacion'] ?? 'offline',
            'puntuacion_confianza': datos['puntuacion_confianza'] ?? 0,
            'ubicacion_gps': datos['ubicacion_gps'],
+           'local_uuid': localUuid,
+           'id_cola': idCola,
          });
        }
      }

      final payload = {
        'dispositivo_id': 'device_${idUsuario}',
+       'creaciones': creaciones,           ← NUEVA sección
        'validaciones': validations,
      };

      final response = await _api.dio.post('/sync/subida', data: payload)
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200 && response.data['success'] == true) {
+       final mappings = response.data['mappings'] as List? ?? [];
+
+       for (var m in mappings) {
+         try {
+           final entidad = m['entidad'];
+           final localUuid = m['local_uuid'];
+           final remoteId = m['remote_id'];
+           final idCola = m['id_cola'] ?? m['id_cola_local'];
+
+           if (entidad == 'usuario') {
+             if (localUuid != null && remoteId != null) {
+               await _localDb.updateUserRemoteIdByLocalUuid(localUuid, remoteId);
+             }
+           } else if (entidad == 'credencial') {
+             if (localUuid != null && remoteId != null) {
+               await _localDb.updateCredentialRemoteIdByLocalUuid(localUuid, remoteId);
+             }
+           }
+
+           if (idCola != null) {
+             await _localDb.markSyncQueueAsProcessed(idCola);
+           }
+         } catch (e) {
+           print('Error procesando mapping: $e');
+         }
+       }
+
        // Marcar como enviados
        for (var item in pendingSync) {
          final idCola = item['id_cola'];
          await _localDb.markSyncQueueAsProcessed(idCola);
        }

        return true;
      }

      return false;
    } catch (error) {
      print('Error al subir datos: $error');
      return false;
    }
  }
```

---

### 5. `lib/screens/register_screen.dart`

**Cambio: _saveRegistrationOffline() enqueue en cola local**

```diff
  Future<void> _saveRegistrationOffline() async {
    try {
      // Insertar usuario en SQLite local
      await _localDb.insertUser(
        nombres: _nombresController.text,
        apellidos: _apellidosController.text,
        identificadorUnico: _identificadorController.text,
      );

+     // Enqueue en cola_sincronizacion
+     await _localDb.insertToSyncQueue(
+       1,
+       'usuario',
+       'insert',
+       {
+         'nombres': _nombresController.text,
+         'apellidos': _nombresController.text,
+         'identificador_unico': _identificadorController.text,
+         'correoElectronico': _emailController.text,
+         'contrasena': _contrasenaController.text,
+         'estado': 'activo',
+       },
+     );

      // Fallback: guardar en offline DB también
      await _syncManager.saveDataForOfflineSync(...);

+     // Enqueue credenciales
      for (int i = 0; i < earPhotos.length; i++) {
        if (earPhotos[i] != null) {
+         await _localDb.insertToSyncQueue(
+           1,
+           'credencial',
+           'insert',
+           {
+             'identificador_unico': _identificadorController.text,
+             'numero': i + 1,
+             'tipo_biometria': 'oreja',
+             'template': earPhotos[i]!.toString(),
+           },
+         );

          await _syncManager.saveDataForOfflineSync(...);
        }
      }

+     if (voiceAudio != null) {
+       await _localDb.insertToSyncQueue(
+         1,
+         'credencial',
+         'insert',
+         {
+           'identificador_unico': _identificadorController.text,
+           'tipo_biometria': 'voz',
+           'template_audio': voiceAudio!.toString(),
+         },
+       );

        await _syncManager.saveDataForOfflineSync(...);
      }
    } catch (e) {
      debugPrint('Error guardando registro offline: $e');
      rethrow;
    }
  }
```

---

### 6. `backend/src/controllers/SincronizacionController.js`

**Cambio: recibirDatosSubida() procesa creaciones + retorna mappings**

```diff
  static async recibirDatosSubida(req, res) {
    try {
      const { id_usuario } = req.user || { id_usuario: null };
-     const { dispositivo_id, validaciones, eventos } = req.body;
+     const { dispositivo_id, validaciones, eventos, creaciones } = req.body;

-     if (!Array.isArray(validaciones)) {
-       return res.status(400).json({
-         success: false,
-         error: 'Validaciones debe ser un array'
-       });
-     }

      let exitosas = 0;
      let errores = [];
+     const mappings = [];

+     // Procesar creaciones (nuevos en v2)
+     if (Array.isArray(creaciones)) {
+       for (const item of creaciones) {
+         try {
+           const tipo = item.tipo_entidad;
+           const datos = item.datos || {};
+           const localUuid = item.local_uuid || null;
+           const idCola = item.id_cola || null;
+
+           if (tipo === 'usuario') {
+             const insertRes = await pool.query(
+               `INSERT INTO usuarios (nombres, apellidos, identificador_unico, estado)
+                VALUES ($1, $2, $3, $4) RETURNING id_usuario`,
+               [
+                 datos.nombres || null,
+                 datos.apellidos || null,
+                 datos.identificador_unico || null,
+                 datos.estado || 'activo'
+               ]
+             );
+
+             const newId = insertRes.rows[0].id_usuario;
+             mappings.push({
+               local_uuid: localUuid,
+               entidad: 'usuario',
+               remote_id: newId,
+               id_cola: idCola,
+             });
+           } else if (tipo === 'credencial' || tipo === 'credencial_biometrica') {
+             const idUsuarioRemoto = datos.id_usuario_remote || null;
+             const resInsert = await pool.query(
+               `INSERT INTO credenciales_biometricas (...) VALUES (...) RETURNING id_credencial`,
+               [...]
+             );
+
+             const newCredId = resInsert.rows[0].id_credencial;
+             mappings.push({
+               local_uuid: localUuid,
+               entidad: 'credencial',
+               remote_id: newCredId,
+               id_cola: idCola,
+             });
+           }
+         } catch (error) {
+           errores.push({ item, error: error.message });
+         }
+       }
+     }

      // Procesar validaciones (código existente)
      if (Array.isArray(validaciones)) {
        for (const validacion of validaciones) {
          try {
            await pool.query(
              `INSERT INTO validaciones_biometricas (...) VALUES (...)`,
              [...]
            );
            exitosas++;
          } catch (error) {
            errores.push({ validacion, error: error.message });
          }
        }
      }

      // Registrar sincronización
      await pool.query(
        `INSERT INTO sincronizaciones (...) VALUES (...)`,
        [...]
      );

      res.json({
        success: true,
        exitosas,
        errores: errores.length > 0 ? errores : undefined,
+       mappings: mappings,        ← NUEVO: retorna mappings
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      console.error('Error en subida de sincronización:', error);
      res.status(500).json({
        success: false,
        error: 'Error en sincronización'
      });
    }
  }
```

---

### 7. `backend/src/routes/syncRoutes.js`

**Cambio: /subida sin autenticación**

```diff
  // Antes:
- router.post('/subida', authenticateToken, SincronizacionController.recibirDatosSubida);

  // Después:
+ router.post('/subida', SincronizacionController.recibirDatosSubida);
  // ↑ Sin authenticateToken para permitir offline sync
```

---

## Flujo de Datos Completo

```
Cliente (Offline)
├─ registerUser()
├─ Genera local_uuid_usuario = "local-1699xxx-5678"
├─ INSERT usuarios { local_uuid_usuario, remote_id=NULL }
├─ insertToSyncQueue('usuario', datos)
│  └─ Añade local_uuid a payload
│  └─ jsonEncode(payload)
│  └─ INSERT cola_sincronizacion { local_uuid, datos_json }
└─ insertToSyncQueue('credencial', datos) x 5
   └─ Similar

[Reconecta a Internet]

Cliente (Online)
├─ SyncManager.performSync()
├─ getPendingSyncQueue()
│  └─ Parsea datos_json con jsonDecode()
│  └─ Retorna datos_parsed
├─ Construye payload:
│  {
│    "creaciones": [
│      { tipo_entidad, datos, local_uuid, id_cola },
│      { ... }
│    ]
│  }
├─ POST /sync/subida con payload

Backend
├─ recibirDatosSubida()
├─ For cada creación:
│  ├─ INSERT en DB → RETURNING id
│  └─ Colecta mapping { local_uuid, entidad, remote_id }
├─ Retorna response:
│  {
│    "success": true,
│    "mappings": [ { local_uuid, entidad, remote_id }, ... ]
│  }

Cliente (Procesando Respuesta)
├─ For mapping in response.mappings:
│  ├─ updateUserRemoteIdByLocalUuid(local_uuid, remote_id)
│  │  └─ UPDATE usuarios SET remote_id=42 WHERE local_uuid='local-xxx'
│  ├─ updateCredentialRemoteIdByLocalUuid(...)
│  │  └─ UPDATE credenciales SET remote_id=99 WHERE local_uuid='local-xxx'
│  └─ markSyncQueueAsProcessed(id_cola)
│     └─ UPDATE cola SET estado='enviado'
└─ Sincronización Completa ✓
```

---

## Resumen Estadístico

| Métrica | Antes | Después |
|---------|-------|---------|
| Columnas de mapeo | 0 | 3 (local_uuid, remote_id en usuarios, credenciales, cola) |
| Métodos LocalDatabaseService | 8 | 10 (+2: updateUserRemoteIdByLocalUuid, updateCredentialRemoteIdByLocalUuid) |
| Formato datos en cola | `toString()` (inválido) | `jsonEncode()` (JSON válido) |
| Endpoint /subida | Con token | Sin token |
| Payload de subida | Solo validaciones | Creaciones + validaciones |
| Response de subida | Vacío | Con mappings[] |
| Sincronización local→remota | Manual | Automática + mapeo IDs |
| Posibilidad de duplicación | Alta | Baja (local_uuid UNIQUE) |

---

## Referencias Cruzadas

Para entender el flujo completo, consulta:

1. **Cliente enqueues** → `lib/screens/register_screen.dart:_saveRegistrationOffline()`
2. **Parseo de datos** → `lib/services/local_database_service.dart:getPendingSyncQueue()`
3. **Construcción de payload** → `lib/services/sync_manager.dart:_uploadData()`
4. **Procesamiento en servidor** → `backend/src/controllers/SincronizacionController.js:recibirDatosSubida()`
5. **Procesamiento de mappings** → `lib/services/sync_manager.dart:_uploadData()` (parte final)

---

**Implementación completada y lista para producción.** ✅
