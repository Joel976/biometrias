# 🎯 Sincronización Reactiva con UI en Tiempo Real

## ✨ Lo que acabas de implementar:

### 📊 Flujo de Sincronización:

```
CON INTERNET ✅:
  Usuario registra → Guarda en backend Y SQLite local
                  → Confirmación inmediata
                  → UI muestra "Online ✅"

SIN INTERNET ❌:
  Usuario registra → Guarda SOLO en SQLite local
                  → Agrega a cola de sincronización
                  → UI muestra "Offline ❌"
                  
MONITOREO (cada 5 minutos):
  Timer verifica → ¿Hay internet?
                 │
                 ├─► SÍ ✅ → Sincroniza cola pendiente
                 │         → UI muestra "Sincronizando..."
                 │         → UI muestra "Sincronizado ✓"
                 │
                 └─► NO ❌ → Omite sincronización
                           → UI muestra "Esperando conexión"
```

---

## 🚀 Implementación Rápida

### 1. Agregar el indicador en tu AppBar:

```dart
import 'package:biometrics_app/services/bidirectional_sync_service.dart';
import 'package:biometrics_app/widgets/sync_status_indicator.dart';

class MyHomeScreen extends StatefulWidget {
  @override
  State<MyHomeScreen> createState() => _MyHomeScreenState();
}

class _MyHomeScreenState extends State<MyHomeScreen> {
  final _syncService = BidirectionalSyncService();

  @override
  void initState() {
    super.initState();
    
    // Iniciar monitoreo cada 5 minutos
    _syncService.startAutoSync(
      idUsuario: currentUserId,      // Tu ID de usuario
      dispositivoId: deviceId,        // ID del dispositivo
      interval: Duration(minutes: 5), // Cada 5 minutos
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mi App'),
        actions: [
          // Widget reactivo que muestra estado en tiempo real
          SyncStatusIndicator(syncService: _syncService),
          SizedBox(width: 8),
        ],
      ),
      body: YourContent(),
    );
  }

  @override
  void dispose() {
    _syncService.dispose(); // Importante: limpiar recursos
    super.dispose();
  }
}
```

### 2. (Opcional) Mostrar card con información completa:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Mi App'),
      actions: [
        SyncStatusIndicator(syncService: _syncService),
        SizedBox(width: 8),
      ],
    ),
    body: Column(
      children: [
        // Card expandido con estadísticas
        SyncStatusCard(syncService: _syncService),
        
        // Tu contenido
        Expanded(
          child: YourContent(),
        ),
      ],
    ),
  );
}
```

---

## 📱 Lo que verá el usuario:

### En el AppBar (Indicador compacto):

**Con internet:**
```
┌────────────────────┐
│ 📶 Online          │
│ Verificaciones: 3  │
└────────────────────┘
```

**Sin internet:**
```
┌────────────────────┐
│ 📵 Offline         │
│ Verificaciones: 5  │
└────────────────────┘
```

**Sincronizando:**
```
┌────────────────────┐
│ ⏳ Online          │
│ Verificaciones: 7  │
└────────────────────┘
```

### En el Card (Vista completa):

```
┌─────────────────────────────────────────┐
│  ☁️ Conectado                            │
│  Última sincronización exitosa          │
│─────────────────────────────────────────│
│   🔍            ↑             ↓         │
│   Verificaciones Subidos    Descargados │
│        7           2            3        │
│─────────────────────────────────────────│
│ ℹ️  Los datos se guardan localmente     │
│    y en el servidor                     │
└─────────────────────────────────────────┘
```

---

## 🔄 Estados Reactivos en Tiempo Real

El widget se actualiza automáticamente cuando:

1. **Cambia la conectividad:**
   - Usuario pierde WiFi → UI muestra "Offline" inmediatamente
   - Usuario conecta WiFi → UI muestra "Online" inmediatamente

2. **Inicia sincronización:**
   - UI muestra spinner + "Sincronizando..."

3. **Termina sincronización:**
   - UI muestra "Sincronizado ✓ (↑2 ↓3)"

4. **Cada 5 minutos:**
   - UI muestra el número de verificaciones
   - Si hay internet → Sincroniza y actualiza estadísticas
   - Si no hay internet → Muestra "Esperando conexión"

---

## 🎨 Personalización del Widget

### Cambiar colores:

Edita `lib/widgets/sync_status_indicator.dart`:

```dart
Color _getBackgroundColor() {
  if (_isSyncing) return Colors.purple.withOpacity(0.1); // Tu color
  if (_hasInternet) return Colors.blue.withOpacity(0.1); // Tu color
  return Colors.orange.withOpacity(0.1);                 // Tu color
}
```

### Cambiar intervalo de verificación:

```dart
// Cada 3 minutos
_syncService.startAutoSync(
  idUsuario: userId,
  interval: Duration(minutes: 3),
);

// Cada 10 minutos (ahorra más batería)
_syncService.startAutoSync(
  idUsuario: userId,
  interval: Duration(minutes: 10),
);

// Cada 30 segundos (solo para testing)
_syncService.startAutoSync(
  idUsuario: userId,
  interval: Duration(seconds: 30),
);
```

---

## 🧪 Cómo Probar

### Prueba 1: Cambio de Conectividad
```
1. Abre la app con WiFi
   ✅ Debería mostrar "Online"

2. Activa modo avión
   ✅ Widget cambia a "Offline" inmediatamente

3. Desactiva modo avión
   ✅ Widget cambia a "Online" inmediatamente
```

### Prueba 2: Sincronización Automática
```
1. Configura interval: Duration(seconds: 30) para testing
2. Observa logs cada 30 segundos:
   
   Con WiFi:
   [AutoSync] 📡 Verificación #1: ✅ ONLINE
   [AutoSync] 🔄 Internet detectado. Sincronizando...
   [AutoSync] Resultado: ✅ Exitoso
   
   Sin WiFi:
   [AutoSync] 📡 Verificación #2: ❌ OFFLINE
   [AutoSync] ⏭️ Sin internet, sincronización omitida
```

### Prueba 3: UI Reactiva
```
1. Abre la app
2. Observa el widget en AppBar
3. Activa/desactiva modo avión
4. ✅ El widget debe cambiar color e icono en tiempo real
5. ✅ NO debe reiniciar la pantalla
6. ✅ Solo el widget se actualiza
```

---

## 📊 Logs Detallados

```
Inicio:
[Sync] 📡 Conectividad inicial: ONLINE ✅
[AutoSync] 🔄 Iniciando monitoreo cada 5 minutos

Verificación con internet:
[AutoSync] 📡 Verificación #1: ✅ ONLINE
[AutoSync] 🔄 Internet detectado. Sincronizando pendientes...
[FullSync] Iniciando sincronización completa
[SyncUp] 2 registros pendientes
[SyncUp] ✅ Sincronizado: /api/auth/register
[SyncDown] ✅ Credencial guardada: 456
[AutoSync] Resultado: ✅ Exitoso

Verificación sin internet:
[AutoSync] 📡 Verificación #2: ❌ OFFLINE
[AutoSync] ⏭️ Sin internet, sincronización omitida
```

---

## 🎯 Ventajas de Esta Implementación

### Antes:
```
❌ Usuario no sabe si hay internet
❌ No sabe si datos se sincronizaron
❌ No sabe cuándo intentará sincronizar
❌ UI estática, no reactiva
```

### Ahora:
```
✅ Usuario VE estado en tiempo real
✅ Sabe si está online/offline
✅ Sabe cuándo sincroniza
✅ Ve estadísticas (subidos/descargados)
✅ UI reactiva con Streams
✅ Widget se actualiza solo
```

---

## 📁 Archivos Creados

1. **Servicio actualizado:**
   - `lib/services/bidirectional_sync_service.dart`
   - Agregados Streams para UI reactiva

2. **Widgets de UI:**
   - `lib/widgets/sync_status_indicator.dart`
   - `SyncStatusIndicator` (compacto para AppBar)
   - `SyncStatusCard` (completo con estadísticas)

3. **Ejemplos:**
   - `lib/examples/sync_example_screen.dart`
   - Implementación mínima
   - Implementación completa

---

## 🚀 Próximos Pasos

1. **Integra en tu app:**
   - Copia el código del ejemplo mínimo
   - Reemplaza `currentUserId` y `deviceId` con tus valores
   - Agrega `SyncStatusIndicator` en tu AppBar

2. **Prueba:**
   - Compila y ejecuta: `flutter run`
   - Activa/desactiva modo avión
   - Observa el widget cambiar en tiempo real

3. **Personaliza:**
   - Cambia colores del widget
   - Ajusta intervalo de verificación
   - Modifica textos según tu marca

---

## 💡 Cómo Funciona Internamente

```dart
// El servicio emite eventos a través de Streams
_connectivityController.add(true);  // Emite: hay internet
_syncStatusController.add({         // Emite: estado de sync
  'syncing': true,
  'hasInternet': true,
});

// El widget escucha estos eventos
widget.syncService.connectivityStream.listen((hasInternet) {
  setState(() {
    _hasInternet = hasInternet; // Actualiza UI
  });
});

// Resultado: UI se actualiza automáticamente sin polling
```

---

¡Tu app ahora tiene sincronización reactiva con UI en tiempo real! 🎉

El usuario puede ver:
- ✅ Estado de conexión (Online/Offline)
- ✅ Cuándo está sincronizando
- ✅ Estadísticas de sincronización
- ✅ Todo en tiempo real sin recargar
