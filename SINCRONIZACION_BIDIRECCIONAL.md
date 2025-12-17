# 🔄 Sincronización Bidireccional: Backend ↔ Frontend

## 📋 Índice
1. [Resumen del Problema](#problema)
2. [Solución Implementada](#solución)
3. [Cómo Funciona](#funcionamiento)
4. [Cómo Usar el Servicio](#uso)
5. [Flujos de Sincronización](#flujos)
6. [Ejemplo Completo](#ejemplo)

---

## 🎯 Problema

### Situación
Tienes **DOS BASES DE DATOS** independientes:
- **Backend:** PostgreSQL (en servidor)
- **Frontend:** SQLite (en dispositivo móvil)

### Escenarios Problemáticos

#### Escenario 1: Datos guardados directamente en el backend
```
❌ PROBLEMA:
1. Admin guarda un nuevo usuario en PostgreSQL (backend)
2. App móvil NO tiene ese usuario en su SQLite
3. Usuario no puede hacer login porque el frontend no lo conoce
```

#### Escenario 2: Múltiples dispositivos
```
❌ PROBLEMA:
1. Dispositivo A registra una credencial biométrica
2. Dispositivo A sincroniza hacia el backend ✅
3. Dispositivo B no sabe que existe esa credencial ❌
4. Dispositivo B tiene datos desactualizados
```

---

## ✅ Solución Implementada

Se implementó **SINCRONIZACIÓN BIDIRECCIONAL** con tres componentes:

### 1. **Subida (App → Backend)** 
Ya existía: `OfflineSyncService`
- Guarda operaciones pendientes cuando no hay conexión
- Sube datos al backend cuando se recupera conexión

### 2. **Descarga (Backend → App)** 
**NUEVO:** `BidirectionalSyncService`
- Descarga datos nuevos desde el backend
- Actualiza SQLite local con datos del servidor
- Mantiene ambas bases sincronizadas

### 3. **Sincronización Automática**
**NUEVO:** Timer periódico
- Ejecuta sincronización cada X minutos
- Sube datos pendientes
- Descarga datos nuevos
- Sin intervención del usuario

---

## 🔧 Cómo Funciona

### Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                     FLUJO BIDIRECCIONAL                      │
└─────────────────────────────────────────────────────────────┘

📱 APP MÓVIL (SQLite)              🌐 BACKEND (PostgreSQL)
    │                                      │
    │  1️⃣ SUBIDA (Upload)                  │
    │ ────────────────────────────────────>│
    │  POST /api/sync/subida               │
    │  - Validaciones pendientes           │
    │  - Credenciales nuevas               │
    │  - Eventos offline                   │
    │                                      │
    │  2️⃣ DESCARGA (Download)               │
    │ <────────────────────────────────────│
    │  POST /api/sync/descarga             │
    │  - Credenciales nuevas del servidor  │
    │  - Textos de audio actualizados      │
    │  - Datos desde última sincronización │
    │                                      │
```

### Flujo Detallado de Descarga

```dart
// 1. Frontend solicita datos al backend
POST /api/sync/descarga
Body: {
  "id_usuario": 123,
  "dispositivo_id": "abc123",
  "ultima_sync": "2024-12-09T10:00:00Z"  // Última vez que sincronizó
}

// 2. Backend responde con datos nuevos
Response: {
  "success": true,
  "timestamp": "2024-12-09T12:30:00Z",
  "datos": {
    "credenciales_biometricas": [
      {
        "id_credencial": 456,
        "id_usuario": 123,
        "tipo_biometria": "oreja",
        "template": "base64_encoded_data...",
        "validez_hasta": "2025-12-09",
        "version_algoritmo": "1.0"
      }
    ],
    "textos_audio": [
      {
        "id_texto": 789,
        "id_usuario": 123,
        "frase": "Mi código de seguridad es alfa bravo",
        "estado_texto": "activo",
        "fecha_asignacion": "2024-12-09"
      }
    ]
  }
}

// 3. Frontend guarda en SQLite local
for (credencial in response.credenciales_biometricas) {
  await _localDb.insertBiometricCredential(credencial);
}
```

---

## 📱 Cómo Usar el Servicio

### 1. Importar el Servicio

```dart
import 'package:biometrics_app/services/bidirectional_sync_service.dart';
```

### 2. Crear Instancia

```dart
final syncService = BidirectionalSyncService();
```

### 3. Opciones de Sincronización

#### Opción A: Sincronización Manual Completa (Recomendado)

```dart
// Ejecutar sincronización bidireccional completa
final result = await syncService.fullSync(
  idUsuario: currentUserId,
  dispositivoId: 'device_unique_id',
);

if (result['success']) {
  print('✅ Sincronización exitosa');
  print('Subidos: ${result['upload']['uploaded']} registros');
  print('Descargados: ${result['download']['downloaded']} registros');
} else {
  print('❌ Error en sincronización: ${result['error']}');
}
```

#### Opción B: Solo Descargar desde Backend

```dart
// Solo descargar datos nuevos del servidor
final result = await syncService.syncDownFromBackend(
  idUsuario: currentUserId,
  dispositivoId: 'device_unique_id',
);

print('Descargados: ${result['downloaded']} registros');
```

#### Opción C: Solo Subir al Backend

```dart
// Solo subir datos pendientes
final result = await syncService.syncUpToBackend();

print('Subidos: ${result['uploaded']} registros');
print('Fallidos: ${result['failed']} registros');
```

### 4. Sincronización Automática (Recomendado)

```dart
// Iniciar sincronización automática cada 5 minutos
syncService.startAutoSync(
  idUsuario: currentUserId,
  dispositivoId: 'device_unique_id',
  interval: Duration(minutes: 5),
);

// Detener sincronización automática
syncService.stopAutoSync();

// Limpiar recursos al cerrar la app
@override
void dispose() {
  syncService.dispose();
  super.dispose();
}
```

---

## 🔄 Flujos de Sincronización

### Flujo 1: Registro de Usuario Offline

```
Usuario registra cuenta sin conexión:

1️⃣ Usuario completa registro → Datos guardados en SQLite
2️⃣ Se agrega a cola de sincronización (OfflineSyncService)
3️⃣ Usuario se conecta a WiFi
4️⃣ AutoSync ejecuta fullSync()
5️⃣ SUBIDA: Envía usuario al backend → Se crea en PostgreSQL
6️⃣ DESCARGA: Recibe ID remoto del usuario
7️⃣ Actualiza SQLite con ID remoto
✅ Usuario sincronizado en ambas bases
```

### Flujo 2: Admin Crea Credencial en Backend

```
Admin agrega credencial directamente en PostgreSQL:

1️⃣ Admin ejecuta: INSERT INTO credenciales_biometricas ...
2️⃣ Datos guardados en PostgreSQL ✅
3️⃣ App móvil ejecuta fullSync() (automático cada 5 min)
4️⃣ DESCARGA: Frontend solicita datos nuevos
5️⃣ Backend responde con credencial nueva
6️⃣ Frontend guarda en SQLite local
✅ Credencial disponible en la app
```

### Flujo 3: Validación Biométrica

```
Usuario valida su identidad:

1️⃣ Usuario captura biometría (oreja/voz)
2️⃣ Validación exitosa → Resultado guardado en SQLite
3️⃣ Se agrega a cola de sincronización
4️⃣ AutoSync ejecuta fullSync()
5️⃣ SUBIDA: Envía validación al backend
6️⃣ Backend guarda en PostgreSQL para auditoría
✅ Validación registrada en ambas bases
```

---

## 💡 Ejemplo Completo

### En `main.dart` o `login_screen.dart`

```dart
import 'package:biometrics_app/services/bidirectional_sync_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _syncService = BidirectionalSyncService();
  final _storage = FlutterSecureStorage();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initAutoSync();
  }

  // Iniciar sincronización automática al cargar la pantalla
  Future<void> _initAutoSync() async {
    final userIdStr = await _storage.read(key: 'user_id');
    if (userIdStr != null) {
      final userId = int.parse(userIdStr);
      
      // Sincronización automática cada 5 minutos
      _syncService.startAutoSync(
        idUsuario: userId,
        dispositivoId: await _getDeviceId(),
        interval: Duration(minutes: 5),
      );

      // Sincronización inicial inmediata
      _manualSync();
    }
  }

  // Botón para sincronizar manualmente
  Future<void> _manualSync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final userIdStr = await _storage.read(key: 'user_id');
      if (userIdStr == null) {
        _showError('Usuario no autenticado');
        return;
      }

      final userId = int.parse(userIdStr);
      final result = await _syncService.fullSync(
        idUsuario: userId,
        dispositivoId: await _getDeviceId(),
      );

      if (result['success']) {
        final uploaded = result['upload']['uploaded'] ?? 0;
        final downloaded = result['download']['downloaded'] ?? 0;
        
        _showSuccess(
          'Sincronización exitosa\n'
          'Subidos: $uploaded\n'
          'Descargados: $downloaded'
        );
      } else {
        _showError('Error: ${result['error']}');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<String> _getDeviceId() async {
    // Implementar con device_info_plus
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Biometric App'),
        actions: [
          // Botón de sincronización manual
          IconButton(
            icon: _isSyncing
                ? CircularProgressIndicator(color: Colors.white)
                : Icon(Icons.sync),
            onPressed: _manualSync,
            tooltip: 'Sincronizar ahora',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Estado: ${_isSyncing ? 'Sincronizando...' : 'Listo'}'),
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.sync),
              label: Text('Sincronizar Manualmente'),
              onPressed: _isSyncing ? null : _manualSync,
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🚀 Configuración Rápida

### 1. En tu `pubspec.yaml` (ya deberían estar):
```yaml
dependencies:
  dio: ^5.0.0
  flutter_secure_storage: ^9.0.0
  sqflite: ^2.0.0
  device_info_plus: ^9.0.0  # Para obtener ID del dispositivo
```

### 2. En tu `main.dart` o pantalla principal:

```dart
import 'package:biometrics_app/services/bidirectional_sync_service.dart';

// Al iniciar sesión:
final syncService = BidirectionalSyncService();

syncService.startAutoSync(
  idUsuario: loggedInUserId,
  dispositivoId: deviceId,
  interval: Duration(minutes: 5),
);

// Importante: Detener al cerrar sesión
syncService.stopAutoSync();
syncService.dispose();
```

---

## ⚙️ Personalización

### Cambiar Intervalo de Sincronización

```dart
// Cada 3 minutos
syncService.startAutoSync(
  idUsuario: userId,
  interval: Duration(minutes: 3),
);

// Cada 30 segundos (solo para testing)
syncService.startAutoSync(
  idUsuario: userId,
  interval: Duration(seconds: 30),
);

// Cada 1 hora
syncService.startAutoSync(
  idUsuario: userId,
  interval: Duration(hours: 1),
);
```

### Sincronización Solo cuando Cambias de Pantalla

```dart
class MyScreen extends StatefulWidget {
  @override
  _MyScreenState createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> with WidgetsBindingObserver {
  final _syncService = BidirectionalSyncService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App volvió al primer plano → Sincronizar
      _syncService.fullSync(
        idUsuario: currentUserId,
        dispositivoId: deviceId,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncService.dispose();
    super.dispose();
  }
}
```

---

## 📊 Monitoreo y Logs

Los logs se imprimen automáticamente en la consola:

```
[SyncUp] 3 registros pendientes
[SyncUp] ✅ Sincronizado: /api/auth/register
[SyncDown] Última sincronización: 2024-12-09 10:00:00
[SyncDown] Descargando datos para usuario: 123
[SyncDown] ✅ Credencial guardada: 456
[SyncDown] ✅ Frase de audio guardada: 789
[SyncDown] Resultado: 2 registros descargados
[AutoSync] Ejecutando sincronización automática...
[AutoSync] Resultado: ✅ Exitoso
```

---

## ✅ Ventajas de Esta Solución

1. **🔄 Bidireccional:** Datos fluyen en ambas direcciones
2. **⚡ Automática:** No requiere intervención del usuario
3. **📴 Offline First:** Funciona sin conexión, sincroniza después
4. **🔁 Reintentos:** Si falla, reintenta automáticamente
5. **📊 Auditoría:** Logs detallados de cada operación
6. **🧹 Limpieza:** Elimina datos antiguos automáticamente
7. **⏱️ Optimizada:** Solo descarga datos desde última sincronización

---

## 🎯 Resumen

### Antes (Solo Subida)
```
App → Backend ✅
Backend → App ❌
```

### Ahora (Bidireccional)
```
App ⇄ Backend ✅
- Subida automática de datos offline
- Descarga automática de datos del servidor
- Sincronización cada 5 minutos
- Mantiene ambas bases actualizadas
```

---

## 🔗 Archivos Relacionados

- **Servicio:** `mobile_app/lib/services/bidirectional_sync_service.dart`
- **Backend:** `backend/src/controllers/SincronizacionController.js`
- **Rutas:** `backend/src/routes/syncRoutes.js`
- **Modelos:** `mobile_app/lib/models/biometric_models.dart`

---

## 📞 Ejemplo de Uso Completo

```dart
// 1. Importar
import 'package:biometrics_app/services/bidirectional_sync_service.dart';

// 2. Crear instancia
final syncService = BidirectionalSyncService();

// 3. Iniciar sincronización automática al hacer login
await syncService.startAutoSync(
  idUsuario: loggedInUser.id,
  dispositivoId: await getDeviceId(),
  interval: Duration(minutes: 5),
);

// 4. Sincronizar manualmente cuando necesites
final result = await syncService.fullSync(
  idUsuario: loggedInUser.id,
  dispositivoId: await getDeviceId(),
);

// 5. Detener al cerrar sesión
syncService.stopAutoSync();
syncService.dispose();
```

¡Listo! Ahora tu app mantiene ambas bases de datos sincronizadas automáticamente. 🎉
