# Sincronización Offline - Guía Rápida de Integración

## ¿Qué Se Implementó?

Tu app ahora tiene un sistema completo de sincronización offline que:

1. ✅ **Detecta automáticamente** cuando pierdes/recuperas conexión a internet
2. ✅ **Guarda datos localmente** en SQLite cuando no hay conexión
3. ✅ **Sincroniza automáticamente** cuando se recupera la conexión
4. ✅ **Muestra iconografía clara** sobre el estado (WiFi verde/rojo, banners)
5. ✅ **Permite sincronización manual** desde la interfaz

---

## Iconografía Visual

### Badge de Conectividad (Esquina Superior Derecha)

```
Con Internet            Sin Internet
    📡                      📡
   Verde                    Rojo
    (✓)                     (✗)
```

### Banners de Estado (Parte Superior)

#### 1. Sin Conexión (Naranja)
```
┌──────────────────────────────────────────┐
│ ☁️ ✗ Sin conexión a internet             │
│    Los datos se guardarán localmente     │
└──────────────────────────────────────────┘
```

#### 2. Sincronizando (Azul)
```
┌──────────────────────────────────────────┐
│ 🔵 ✓ Conectado • Sincronizando datos... ↻ │
└──────────────────────────────────────────┘
```

### Badge de Datos Pendientes (Flotante)

```
En HomeScreen aparece:

┌──────────────────┐
│ 📤 3 pendientes  │  ← Naranja
└──────────────────┘
```

---

## Archivos Creados/Modificados

### Nuevos Archivos

```
✅ lib/widgets/connectivity_status_widget.dart
   → Widget principal de monitoreo de conectividad
   → Muestra badges y banners

✅ lib/services/offline_sync_service.dart
   → Servicio de almacenamiento SQLite
   → Maneja tabla pending_sync

✅ lib/widgets/sync_status_widgets.dart
   → PendingSyncBadge (contador)
   → SyncStatusCard (tarjeta de sincronización)

✅ docs/OFFLINE_SYNC_GUIDE.md
   → Documentación completa del sistema

✅ docs/OFFLINE_SYNC_DIAGRAMS.md
   → Diagramas visuales de flujos
```

### Archivos Modificados

```
✏️ lib/main.dart
   → Añadida ConnectivityStatusWidget wrapper
   → Integrada con SyncManager

✏️ lib/screens/register_screen.dart
   → Verifica conectividad antes de registrar
   → Guarda offline si no hay conexión
   → Método _saveRegistrationOffline()

✏️ lib/services/sync_manager.dart
   → Nuevos métodos: saveDataForOfflineSync()
   → Nuevos métodos: syncOfflineData()
   → Nuevos métodos: getPendingSyncCount()
   → Importa OfflineSyncService
```

---

## Flujo de Uso (Paso a Paso)

### Escenario 1: Usuario Registra SIN Internet

```
1. Usuario abre app → Badge WiFi ROJO (sin conexión)

2. Usuario va a "Registrarse"
   - Llena formulario
   - Captura 3 fotos de oreja
   - Graba audio

3. Presiona botón "Registrarse"
   ↓
   App verifica: ¿Hay conexión?
   ↓
   NO HAY CONEXIÓN
   ↓
   App guarda TODO en SQLite:
   - Datos personales
   - 3 fotos (base64)
   - Audio (base64)
   ↓
   Muestra: "✗ Sin conexión. Registro guardado localmente"
   ↓
   Vuelve a LoginScreen

4. Usuario recupera WiFi/Internet
   ↓
   Badge WiFi pasa a VERDE
   ↓
   Aparece banner AZUL: "✓ Conectado • Sincronizando datos..."
   ↓
   App envía TODOS los datos guardados al backend
   ↓
   Después de 2 segundos, banner desaparece
   ↓
   Registro completado! ✓
```

### Escenario 2: Usuario Registra CON Internet

```
1. Usuario abre app → Badge WiFi VERDE (con conexión)

2. Usuario se registra normalmente
   ↓
   Los datos se envían directo al backend
   ↓
   Registro exitoso inmediatamente ✓
```

### Escenario 3: Ver Datos Pendientes

```
1. Usuario abrió app sin internet
2. Registró datos (guardados offline)
3. Usuario abre HomeScreen
   ↓
   Ve badge naranja: "📤 3 pendientes"
   ↓
   Ve tarjeta "Estado de Sincronización"
   - "3 datos pendientes"
   - Botón [Sincronizar Ahora]
   ↓
   Usuario presiona botón
   ↓
   App intenta sincronizar
   ↓
   Muestra resultado en SnackBar
```

---

## Base de Datos SQLite

**Nombre:** `biometrics_offline.db`
**Tabla:** `pending_sync`

### Estructura

```sql
id              → Identificador único (auto-increment)
endpoint        → URL del API (ej: /auth/register)
data            → Datos JSON a enviar
photo_base64    → Foto de oreja (si aplica)
audio_base64    → Audio de voz (si aplica)
created_at      → Cuándo se guardó
retry_count     → Número de intentos fallidos
synced          → 0 (pendiente) o 1 (sincronizado)
```

### Ejemplo de Registro Pendiente

```json
{
  "id": 1,
  "endpoint": "/auth/register",
  "data": "{nombres: Juan, apellidos: Pérez, email: juan@example.com, ...}",
  "photo_base64": null,
  "audio_base64": null,
  "created_at": "2025-11-29T14:35:00Z",
  "retry_count": 0,
  "synced": 0
}
```

---

## Métodos Principales (Para Usar)

### 1. Guardar Datos Offline

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

### 2. Obtener Cantidad Pendiente

```dart
final count = await syncManager.getPendingSyncCount();
print('$count datos pendientes');
```

### 3. Escuchar Cambios

```dart
StreamBuilder<int>(
  stream: syncManager.getPendingSyncCountStream(),
  builder: (context, snapshot) {
    final count = snapshot.data ?? 0;
    return Text('$count pendientes');
  },
)
```

### 4. Sincronizar Manualmente

```dart
final result = await syncManager.syncOfflineData();
if (result.success) {
  print('✓ ${result.message}');
} else {
  print('✗ ${result.message}');
}
```

---

## Configuración (Opcionales)

### Cambiar Intervalo de Sincronización Automática

En `sync_manager.dart`, línea ~22:

```dart
// De:
final _syncInterval = Duration(minutes: 5);

// A:
final _syncInterval = Duration(minutes: 2);  // Cada 2 minutos
```

### Cambiar Máximo de Reintentos

En `offline_sync_service.dart`, línea ~13:

```dart
// De:
static const _maxRetries = 5;

// A:
static const _maxRetries = 10;  // 10 intentos máximo
```

### Cambiar Tiempo de Backoff

En `offline_sync_service.dart`, líneas ~14-15:

```dart
// De:
static const _initialRetryDelayMs = 5000;      // 5 segundos
static const _maxRetryDelayMs = 1800000;       // 30 minutos

// A:
static const _initialRetryDelayMs = 2000;      // 2 segundos
static const _maxRetryDelayMs = 600000;        // 10 minutos
```

---

## Testing (Cómo Probar)

### Test 1: Simular Sin Internet (Emulador)

```bash
# En Android Studio
1. Click en emulador
2. Extended Controls (Ctrl+Shift+E)
3. Cellular → Buscar "Data" → Desactivar
```

### Test 2: Simular Sin Internet (Dispositivo)

```
1. Activa Modo Avión
   O
2. Desactiva WiFi y datos móviles
```

### Test 3: Forzar en Código (Dev)

En `register_screen.dart`:

```dart
@override
void initState() {
  super.initState();
  _initializeServices();
  // PARA TESTING: Fuerza sin conexión
  _isOnline = false;  // ← Descomenta para probar
  _checkConnectivity();
}
```

### Test 4: Ver Logs de Sincronización

```bash
flutter run -v | grep -E "(sync|Connectivity|offline)"
```

---

## Reintentos Automáticos

Si una sincronización falla, se reintenta automáticamente con espacio exponencial:

```
Intento 1: 5 segundos después
Intento 2: 10 segundos después
Intento 3: 20 segundos después
Intento 4: 40 segundos después
Intento 5: 80 segundos después
(Máximo: 30 minutos entre intentos)
```

Si falla todos los reintentos, se guardará en la BD y esperará la próxima sincronización automática cada 5 minutos.

---

## Solución de Problemas

### Problema: App no detecta desconexión

**Solución:** Verifica que `connectivity_plus` esté instalado:
```bash
flutter pub get
```

### Problema: Datos no se guardan offline

**Solución:** Revisa permisos de escritura SQLite:
```bash
flutter run -v | grep -i "offline_sync"
```

### Problema: Sincronización no termina

**Solución:** Verifica que el backend esté respondiendo:
```bash
curl http://10.0.2.2:3000/api/sync/ping
```

---

## Próximos Pasos

- [ ] Implementar encriptación de datos con SQLCipher
- [ ] Agregar interfaz de usuario para ver datos pendientes en detalle
- [ ] Implementar sincronización bidireccional (descargar datos también)
- [ ] Agregar notificaciones push cuando se completa sincronización
- [ ] Compresión de fotos/audios antes de guardar offline
