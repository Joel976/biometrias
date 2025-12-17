# Sistema de Sincronización Offline

## Descripción General

La aplicación Biométrica implementa un sistema robusto de sincronización offline que permite:

1. **Guardar datos localmente** cuando el dispositivo está sin conexión a internet
2. **Sincronizar automáticamente** cuando se recupera la conexión
3. **Mostrar estado de conectividad** con iconografía clara para el usuario
4. **Indicador visual** de datos pendientes de sincronizar

## Arquitectura

### Componentes Principales

#### 1. **ConnectivityStatusWidget**
- **Ubicación:** `lib/widgets/connectivity_status_widget.dart`
- **Función:** Monitorea en tiempo real el estado de conectividad
- **Características:**
  - Badge flotante (esquina superior derecha) con icono Wi-Fi ✓ (verde) / ✗ (rojo)
  - Banner de reconexión cuando se recupera la conexión
  - Banner de advertencia cuando pierde conexión
  - Integración con `SyncManager` para sincronización automática

#### 2. **OfflineSyncService**
- **Ubicación:** `lib/services/offline_sync_service.dart`
- **Función:** Maneja el almacenamiento de datos en SQLite
- **Base de datos:** `biometrics_offline.db` (tabla: `pending_sync`)
- **Métodos principales:**
  - `savePendingData()` - Guardar datos pendientes
  - `getPendingData()` - Obtener datos pendientes
  - `markAsSynced()` - Marcar como sincronizado
  - `getPendingCount()` - Contar datos sin sincronizar
  - `cleanupOldSyncedData()` - Limpiar datos antiguos

#### 3. **SyncManager** (actualizado)
- **Ubicación:** `lib/services/sync_manager.dart`
- **Función:** Orquesta la sincronización bidireccional
- **Métodos nuevos:**
  - `saveDataForOfflineSync()` - Guardar para sincronización offline
  - `getPendingSyncCount()` - Obtener cantidad pendiente
  - `getPendingSyncCountStream()` - Stream de cambios en cantidad pendiente
  - `syncOfflineData()` - Sincronizar datos pendientes cuando hay conexión

#### 4. **Widgets de Sincronización**
- **Ubicación:** `lib/widgets/sync_status_widgets.dart`
- **Componentes:**
  - `PendingSyncBadge` - Muestra contador de datos pendientes
  - `SyncStatusCard` - Tarjeta con estado y botón para sincronizar manualmente

## Flujo de Funcionamiento

### Escenario 1: Registro sin Internet

```
1. Usuario rellena formulario de registro
2. Usuario captura 3 fotos de oreja
3. Usuario graba audio de voz
4. Usuario presiona "Registrarse"
5. App verifica conectividad → SIN CONEXIÓN
6. App guarda todo en SQLite con savePendingData()
7. Muestra mensaje: "✗ Sin conexión. Registro guardado localmente"
8. Vuelve a LoginScreen
```

### Escenario 2: Reconexión Automática

```
1. Dispositivo recupera conexión a internet
2. ConnectivityStatusWidget detecta cambio
3. Muestra banner azul: "✓ Conectado • Sincronizando datos..."
4. SyncManager.performSync() se activa
5. syncOfflineData() procesa todos los registros guardados
6. Cada registro se envía al backend
7. Si OK: marca como sincronizado y elimina de BD
8. Si ERROR: incrementa contador de reintentos
9. Banner desaparece automáticamente en 2 segundos
```

### Escenario 3: Sincronización Manual

```
1. Usuario ve badge naranja: "1 pendiente"
2. Usuario accede a HomeScreen
3. Ve tarjeta de SyncStatusCard con botón "Sincronizar Ahora"
4. Presiona botón
5. App sincroniza datos pendientes
6. Muestra SnackBar con resultado
```

## Esquema de Base de Datos (SQLite)

```sql
CREATE TABLE pending_sync (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  endpoint TEXT NOT NULL,              -- Ej: /auth/register
  data TEXT NOT NULL,                  -- JSON serializado con datos
  photo_base64 TEXT,                   -- Foto de oreja (base64)
  audio_base64 TEXT,                   -- Audio de voz (base64)
  created_at TEXT NOT NULL,            -- Timestamp ISO 8601
  retry_count INTEGER DEFAULT 0,       -- Número de reintentos
  synced INTEGER DEFAULT 0             -- 0: pendiente, 1: sincronizado
)
```

## Iconografía

### Estado de Conectividad

| Estado | Icono | Color | Ubicación |
|--------|-------|-------|-----------|
| **Con Internet** | 📡 wifi | Verde | Esquina superior derecha |
| **Sin Internet** | 📡 wifi_off | Rojo | Esquina superior derecha |
| **Sincronizando** | ↻ (spinner) | Azul | Banner superior |
| **Pendiente** | ☁️ cloud_upload | Naranja | Badge flotante |

### Estados del Banner

1. **Banner de Desconexión** (naranja)
   ```
   ✗ Sin conexión a internet
   Los datos se guardarán localmente
   ```

2. **Banner de Sincronización** (azul)
   ```
   ✓ Conectado • Sincronizando datos...
   ```

## Configuración

### Variables Importantes

```dart
// SyncManager
static const _syncInterval = Duration(minutes: 5);      // Intervalo auto-sync
static const _maxRetries = 5;                           // Reintentos máximos
static const _initialRetryDelayMs = 5000;               // Primer reintento: 5s
static const _maxRetryDelayMs = 1800000;                // Máx reintento: 30m
```

### Rutas de API Esperadas

```
POST /auth/register                    -- Registro de usuario
POST /biometria/registrar-oreja       -- Registrar foto de oreja
POST /biometria/registrar-voz         -- Registrar audio de voz
POST /sync/ping                        -- Verificar disponibilidad
```

## Reintentos con Backoff Exponencial

Los datos que fallan en sincronización se reintentan con backoff exponencial:

```
Intento 1: 5 segundos
Intento 2: 10 segundos
Intento 3: 20 segundos
Intento 4: 40 segundos
Intento 5: 80 segundos
... (máximo 30 minutos)
```

## Limitaciones Actuales

1. **Datos Sensibles:** Los datos (fotos, audio) se guardan como strings base64 en SQLite
   - Considerar encriptación con SQLCipher en versiones futuras

2. **Sincronización Bidireccional:** Actualmente solo envía datos (upstream)
   - Descarga (downstream) está en `_downloadData()` pero sin implementación completa

3. **Tamaño de Datos:** Las fotos y audios en base64 aumentan significativamente el tamaño
   - Considerar compresión o referencia a archivos en disco

## Uso desde el Código

### Guardar Datos Offline

```dart
final syncManager = SyncManager();

await syncManager.saveDataForOfflineSync(
  endpoint: '/auth/register',
  data: {
    'nombres': 'Juan',
    'apellidos': 'Pérez',
    'email': 'juan@example.com',
  },
  photoBase64: photoBytes.toString(),  // Opcional
  audioBase64: audioBytes.toString(),  // Opcional
);
```

### Obtener Contador Pendiente

```dart
final count = await syncManager.getPendingSyncCount();
print('Pendientes: $count');
```

### Escuchar Cambios de Conectividad

```dart
streamBuilder: (context, snapshot) {
  final count = snapshot.data ?? 0;
  return Text('$count pendientes');
},
stream: syncManager.getPendingSyncCountStream(),
```

### Sincronizar Manualmente

```dart
final result = await syncManager.syncOfflineData();
if (result.success) {
  print('✓ ${result.message}');
} else {
  print('✗ ${result.message}');
}
```

## Testing

Para probar el sistema sin conexión:

1. **Emulador:** Desactiva la conexión en configuración del emulador
2. **Dispositivo físico:** Activa modo avión o desactiva Wi-Fi
3. **Modo Dev:** Modifica `_isOnline` en `register_screen.dart` a `false`

## Monitoreo

Logs útiles:

```bash
# Ver SQLite
flutter run -v | grep "offline_sync"

# Ver sincronización
flutter run -v | grep "SyncManager"

# Ver conectividad
flutter run -v | grep "ConnectivityStatusWidget"
```

## Futuras Mejoras

- [ ] Encriptación con SQLCipher
- [ ] Compresión de fotos/audios
- [ ] Sincronización bidireccional completa
- [ ] Selección manual de qué datos sincronizar
- [ ] Estadísticas de sincronización (total, completados, fallidos)
- [ ] Notificaciones push cuando se completa sincronización
- [ ] Limpieza automática de datos antiguos con JobScheduler
