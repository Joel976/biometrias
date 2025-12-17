# 🔄 SISTEMA DE SINCRONIZACIÓN OFFLINE - REFERENCIA RÁPIDA

## 📌 Lo Que Se Implementó

Tu app ahora muestra:

### 1. **Badge de WiFi** (Esquina Superior Derecha)
```
Con Internet          Sin Internet
    📡                   📡
   VERDE               ROJO
    ✓                   ✗
```

### 2. **Banner de Estado** (Parte Superior)
```
Sin Conexión (Naranja):
┌────────────────────────────────────────────┐
│ ☁️ ✗ Sin conexión a internet               │
│    Los datos se guardarán localmente       │
└────────────────────────────────────────────┘

Sincronizando (Azul):
┌────────────────────────────────────────────┐
│ 🔵 ✓ Conectado • Sincronizando datos... ↻  │
└────────────────────────────────────────────┘
```

### 3. **Contador de Pendientes** (HomeScreen)
```
Se muestra cuando hay datos sin sincronizar:

┌──────────────────┐
│ 📤 3 pendientes  │  ← Naranja
└──────────────────┘
```

---

## 🔄 Cómo Funciona

### Escenario: Usuario Registra Sin Internet

```
1. Usuario abre app
   → Badge: 📡 ROJO

2. Usuario rellena formulario + captura fotos + graba audio

3. Usuario presiona "Registrarse"
   → App verifica conexión: ¡NO HAY!
   → Guarda TODO en SQLite
   → Banner naranja aparece 2 segundos
   → Vuelve a LoginScreen

4. Usuario abre WiFi
   → Badge: 📡 VERDE
   → Banner azul: "Sincronizando..."
   → App envía datos al backend
   → Banner azul desaparece en 2 segundos
   → ¡Registro completo!
```

---

## 📂 Archivos Clave

```
lib/widgets/
  ├─ connectivity_status_widget.dart    → Badge + banners
  └─ sync_status_widgets.dart           → Contador + tarjeta

lib/services/
  ├─ offline_sync_service.dart          → SQLite
  ├─ sync_manager.dart                  → Orquestador (actualizado)
  └─ auth_service.dart                  → HTTP (actualizado)

lib/screens/
  ├─ register_screen.dart               → Guarda offline (actualizado)
  └─ main.dart                          → Wrapper (actualizado)

lib/db/
  └─ biometrics_offline.db              → SQLite (auto-creada)
```

---

## 🧪 Cómo Probar

### Test Rápido (Emulador)

```bash
# 1. Abre emulador
# 2. Extended Controls (Ctrl+Shift+E)
# 3. Cellular → Desactiva "Data"
# 4. Abre app → Badge se pone ROJO
# 5. Intenta registrarte → Se guarda offline
# 6. Activa "Data" → Badge pasa a VERDE → Sincroniza automático
```

### Test Rápido (Dispositivo)

```bash
# 1. Activa Modo Avión
# 2. Abre app → Badge ROJO
# 3. Prueba registro → Guardado offline
# 4. Desactiva Modo Avión → Sincroniza automático
```

---

## 🔧 Métodos Útiles

### Guardar Offline
```dart
await SyncManager().saveDataForOfflineSync(
  endpoint: '/auth/register',
  data: {...},
);
```

### Obtener Contador
```dart
final count = await SyncManager().getPendingSyncCount();
```

### Sincronizar Manual
```dart
final result = await SyncManager().syncOfflineData();
```

### Escuchar Cambios
```dart
StreamBuilder<int>(
  stream: SyncManager().getPendingSyncCountStream(),
  builder: (context, snapshot) => Text('${snapshot.data} pendientes'),
)
```

---

## 📊 Base de Datos

**Ubicación:** `biometrics_offline.db`
**Tabla:** `pending_sync`

```sql
-- Guarda automáticamente:
-- - Datos de registro
-- - Fotos de oreja (base64)
-- - Audio de voz (base64)
-- - Timestamp
-- - Número de reintentos
```

---

## 🎯 Estados Visuales

| Estado | Badge | Banner | Acción |
|--------|-------|--------|--------|
| **Con Internet** | 📡 Verde | Ninguno | Envía directo al backend |
| **Sin Internet** | 📡 Rojo | Naranja (2s) | Guarda en SQLite |
| **Reconecta** | 📡 Verde | Azul (2s) | Sincroniza automático |
| **Datos Pendientes** | 📡 Verde | Ninguno | Muestra badge "📤 N" |

---

## 🔁 Reintentos Automáticos

Si falla envío:
- Intento 1: 5 segundos
- Intento 2: 10 segundos
- Intento 3: 20 segundos
- Intento 4: 40 segundos
- Intento 5: 80 segundos
- Máximo: 30 minutos entre intentos

---

## 📖 Documentación Completa

```
docs/OFFLINE_SYNC_GUIDE.md              → Arquitectura detallada
docs/OFFLINE_SYNC_DIAGRAMS.md           → Diagramas visuales
docs/OFFLINE_SYNC_QUICK_START.md        → Guía rápida
docs/OFFLINE_SYNC_IMPLEMENTATION.md     → Esta implementación
```

---

## ✅ Checklist

- ✅ Widget de conectividad (badge + banners)
- ✅ SQLite para datos offline
- ✅ SyncManager mejorado
- ✅ RegisterScreen integrado
- ✅ Sincronización automática
- ✅ Sincronización manual
- ✅ Contador de pendientes
- ✅ Reintentos con backoff exponencial
- ✅ Documentación completa

---

## 🚀 Próximo Paso

Para ver en acción:

```bash
cd mobile_app
flutter clean
flutter pub get
flutter run
```

Luego:
1. Abre app
2. Desactiva internet (o Modo Avión)
3. Intenta registrarte
4. Vuelve a activar conexión
5. ¡Sincronización automática! 🎉

---

**Estado:** ✅ **COMPLETADO**
**Versión:** 1.0
**Fecha:** 29 Nov 2025
