# 🧪 Pantalla de Prueba - Sincronización cada 5 segundos

## 🚀 Cómo Abrir la Pantalla de Prueba

### Opción 1: Desde tu Main.dart

```dart
import 'package:biometrics_app/screens/test_sync_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Sync',
      home: TestSyncScreen(), // ← Abre directamente la pantalla de prueba
    );
  }
}
```

### Opción 2: Con un Botón en tu App

```dart
// En cualquier pantalla de tu app
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TestSyncScreen(),
      ),
    );
  },
  child: Text('Probar Sincronización'),
)
```

---

## 📱 Lo que Verás en la Pantalla

```
┌─────────────────────────────────────────┐
│ Test Sincronización (5 segundos)    📶 │
├─────────────────────────────────────────┤
│                                         │
│              ☁️                          │
│           (Verde/Rojo)                  │
│                                         │
│           CONECTADO                     │
│        ✅ Conexión detectada             │
│                                         │
│     ┌──────────────────────────┐       │
│     │    ESTADÍSTICAS          │       │
│     │  🔍 Verificaciones: 12   │       │
│     │  ↑  Subidos: 2           │       │
│     │  ↓  Descargados: 3       │       │
│     └──────────────────────────┘       │
│                                         │
│     ℹ️  PRUEBA ESTO:                    │
│     1. Observa el contador             │
│     2. Activa modo avión → ROJO        │
│     3. Desactiva modo avión → VERDE    │
│     4. Verifica cada 5 segundos        │
│                                         │
└─────────────────────────────────────────┘
```

---

## 🎯 Qué Hace Cada 5 Segundos

```
CADA 5 SEGUNDOS:

1. Verificación #1 (0:05)
   └─► Verifica conectividad
       └─► ✅ ONLINE → Intenta sincronizar
       └─► ❌ OFFLINE → Omite sincronización

2. Verificación #2 (0:10)
   └─► Verifica conectividad
       └─► Estado se actualiza en UI

3. Verificación #3 (0:15)
   └─► Y así sucesivamente...
```

---

## 🧪 Pruebas que Puedes Hacer

### Prueba 1: Ver el Contador
```
1. Abre la pantalla
2. Observa "Verificaciones: 0"
3. Espera 5 segundos
4. ✅ Debería cambiar a "Verificaciones: 1"
5. Espera 5 segundos más
6. ✅ Debería cambiar a "Verificaciones: 2"
```

### Prueba 2: Activar Modo Avión
```
1. Con WiFi conectado → Pantalla VERDE
2. Activa modo avión
3. ✅ Pantalla cambia a ROJO inmediatamente
4. ✅ Muestra "❌ Sin conexión"
5. Cada 5 segundos verás: "⏭️ Sin internet - Sincronización omitida"
```

### Prueba 3: Desactivar Modo Avión
```
1. Con modo avión → Pantalla ROJA
2. Desactiva modo avión
3. Conecta WiFi
4. ✅ Pantalla cambia a VERDE inmediatamente
5. ✅ Muestra "✅ Conexión detectada"
6. Próximo ciclo (5 seg) sincroniza automáticamente
```

---

## 📊 Logs en Consola

Mientras usas la pantalla de prueba, verás estos logs:

```
[Sync] 📡 Conectividad inicial: ONLINE ✅
[AutoSync] 🔄 Iniciando monitoreo cada 5 segundos

# Cada 5 segundos con internet:
[AutoSync] 📡 Verificación #1: ✅ ONLINE
[AutoSync] 🔄 Internet detectado. Sincronizando pendientes...
[FullSync] Iniciando sincronización completa
[SyncUp] No hay datos pendientes
[SyncDown] Descargando datos para usuario: 123
[AutoSync] Resultado: ✅ Exitoso

# Cada 5 segundos sin internet:
[AutoSync] 📡 Verificación #2: ❌ OFFLINE
[AutoSync] ⏭️ Sin internet, sincronización omitida
```

---

## 🎨 Estados Visuales

### Estado: ONLINE ✅
- AppBar: VERDE
- Icono: ☁️ (nube verde)
- Texto: "CONECTADO"
- Estado: "✅ Conexión detectada"

### Estado: OFFLINE ❌
- AppBar: ROJO
- Icono: ☁️ (nube roja)
- Texto: "DESCONECTADO"
- Estado: "❌ Sin conexión"

### Estado: SINCRONIZANDO 🔄
- Spinner en AppBar
- CircularProgressIndicator abajo
- Estado: "🔄 Sincronizando con el servidor..."

### Estado: COMPLETADO ✅
- Estado: "✅ Sincronizado (↑2 ↓3)"
- Actualiza estadísticas

---

## ⚡ Comandos Rápidos

### Ejecutar la app:
```bash
cd mobile_app
flutter run
```

### Ver logs en tiempo real:
```bash
flutter run --verbose
```

### Si no ves logs:
```bash
# Asegúrate de estar en modo debug
flutter run --debug
```

---

## 🔧 Volver a 5 Minutos

Cuando termines de probar, cambia de vuelta:

```dart
// En bidirectional_sync_service.dart, línea ~316
Duration interval = const Duration(minutes: 5), // 5 minutos normal
```

O simplemente pasa el parámetro:

```dart
_syncService.startAutoSync(
  idUsuario: userId,
  dispositivoId: deviceId,
  interval: Duration(minutes: 5), // Especificar explícitamente
);
```

---

## ✅ Checklist de Prueba

- [ ] Pantalla abre correctamente
- [ ] Muestra estado inicial (ONLINE/OFFLINE)
- [ ] Contador aumenta cada 5 segundos
- [ ] Activar modo avión → Cambia a ROJO
- [ ] Desactivar modo avión → Cambia a VERDE
- [ ] Logs aparecen en consola
- [ ] Estadísticas se actualizan
- [ ] Spinner aparece al sincronizar
- [ ] No crashea la app

---

## 🎉 Resultado Esperado

Deberías ver:
- ✅ Pantalla reactiva que cambia colores
- ✅ Contador que aumenta cada 5 segundos
- ✅ Estado cambia al activar/desactivar modo avión
- ✅ Logs detallados en consola
- ✅ UI fluida sin recargas

---

¡Prueba y me cuentas qué ves! 🚀
