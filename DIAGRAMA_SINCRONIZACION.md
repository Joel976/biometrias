# 🔄 Diagrama Visual: Sincronización Bidireccional

## 📊 Flujo Completo de Sincronización

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SINCRONIZACIÓN BIDIRECCIONAL                          │
│                          App ⇄ Backend                                  │
└─────────────────────────────────────────────────────────────────────────┘

📱 FRONTEND (SQLite)                    🌐 BACKEND (PostgreSQL)
┌─────────────────────┐                 ┌────────────────────┐
│                     │                 │                    │
│  Local Database     │                 │   Remote Database  │
│   (SQLite)          │                 │   (PostgreSQL)     │
│                     │                 │                    │
│  • usuarios         │                 │  • usuarios        │
│  • credenciales     │◄────────────────┤  • credenciales    │
│  • validaciones     │─────────────────►│  • validaciones    │
│  • sync_queue       │   Sincroniza    │  • sincronizaciones│
│                     │                 │                    │
└─────────────────────┘                 └────────────────────┘
```

---

## 🔄 Escenario 1: Admin Crea Datos en Backend

```
                 PROBLEMA SIN SINCRONIZACIÓN
                 ═══════════════════════════

1. Admin ejecuta en PostgreSQL:
   ┌─────────────────────────────────────┐
   │ INSERT INTO credenciales_biometricas│
   │ (id_usuario, tipo_biometria, ...)   │
   │ VALUES (123, 'oreja', ...);         │
   └─────────────────────────────────────┘
                    ⬇
   ✅ Credencial guardada en PostgreSQL

2. Usuario abre la app móvil:
   ┌────────────────────────────────────┐
   │ SELECT * FROM                      │
   │ credenciales_biometricas           │
   │ WHERE id_usuario = 123             │
   └────────────────────────────────────┘
                    ⬇
   ❌ NO ENCUENTRA NADA en SQLite
   ❌ Usuario no puede hacer login


                 SOLUCIÓN CON SINCRONIZACIÓN
                 ═══════════════════════════

1. Admin ejecuta en PostgreSQL:
   ┌─────────────────────────────────────┐
   │ INSERT INTO credenciales_biometricas│
   │ (id_usuario, tipo_biometria, ...)   │
   │ VALUES (123, 'oreja', ...);         │
   └─────────────────────────────────────┘
                    ⬇
   ✅ Credencial en PostgreSQL

2. App ejecuta sincronización (automática cada 5 min):
   ┌────────────────────────────────────┐
   │ POST /api/sync/descarga            │
   │ {                                  │
   │   "id_usuario": 123,               │
   │   "ultima_sync": "2024-12-09..."   │
   │ }                                  │
   └────────────────────────────────────┘
                    ⬇
   Backend responde con datos nuevos:
   ┌────────────────────────────────────┐
   │ {                                  │
   │   "credenciales_biometricas": [    │
   │     {                              │
   │       "id_credencial": 456,        │
   │       "tipo_biometria": "oreja",   │
   │       ...                          │
   │     }                              │
   │   ]                                │
   │ }                                  │
   └────────────────────────────────────┘
                    ⬇
3. App guarda en SQLite:
   ┌────────────────────────────────────┐
   │ INSERT INTO credenciales_biometricas│
   │ (id_credencial, tipo_biometria,...) │
   │ VALUES (456, 'oreja', ...);        │
   └────────────────────────────────────┘
                    ⬇
   ✅ Credencial ahora en SQLite
   ✅ Usuario puede hacer login
```

---

## 📤 Escenario 2: Usuario Registra Offline

```
                 FLUJO OFFLINE → ONLINE
                 ══════════════════════

1. Usuario SIN conexión registra cuenta:
   📱 App Móvil (OFFLINE)
   ┌────────────────────────────────────┐
   │ Usuario completa formulario        │
   │ Captura 3 fotos oreja + voz        │
   └────────────────────────────────────┘
                    ⬇
   Guardar en SQLite local:
   ┌────────────────────────────────────┐
   │ INSERT INTO usuarios               │
   │ (nombres, apellidos, ...)          │
   │ VALUES ('Juan', 'Pérez', ...)      │
   │                                    │
   │ local_id = 999 (temporal)          │
   └────────────────────────────────────┘
                    ⬇
   Agregar a cola de sincronización:
   ┌────────────────────────────────────┐
   │ INSERT INTO sync_queue             │
   │ (endpoint, data, synced)           │
   │ VALUES                             │
   │ ('/auth/register', {...}, 0)       │
   └────────────────────────────────────┘
                    ⬇
   ✅ Usuario puede usar la app OFFLINE
   ⏳ Datos pendientes de sincronizar


2. Usuario SE CONECTA a WiFi:
   📡 Conexión Detectada
   ┌────────────────────────────────────┐
   │ Auto-Sync Timer (cada 5 min)      │
   │ Ejecuta: fullSync()                │
   └────────────────────────────────────┘
                    ⬇
   SUBIDA (App → Backend):
   ┌────────────────────────────────────┐
   │ POST /api/sync/subida              │
   │ {                                  │
   │   "creaciones": [                  │
   │     {                              │
   │       "tipo": "usuario",           │
   │       "datos": {                   │
   │         "nombres": "Juan",         │
   │         "apellidos": "Pérez"       │
   │       },                           │
   │       "local_uuid": "999"          │
   │     }                              │
   │   ]                                │
   │ }                                  │
   └────────────────────────────────────┘
                    ⬇
   Backend crea usuario:
   ┌────────────────────────────────────┐
   │ INSERT INTO usuarios               │
   │ (nombres, apellidos, ...)          │
   │ VALUES ('Juan', 'Pérez', ...)      │
   │ RETURNING id_usuario;              │
   │                                    │
   │ remote_id = 123 (real)             │
   └────────────────────────────────────┘
                    ⬇
   Backend responde con mapping:
   ┌────────────────────────────────────┐
   │ {                                  │
   │   "mappings": [                    │
   │     {                              │
   │       "local_uuid": "999",         │
   │       "remote_id": 123             │
   │     }                              │
   │   ]                                │
   │ }                                  │
   └────────────────────────────────────┘
                    ⬇
   DESCARGA (Backend → App):
   ┌────────────────────────────────────┐
   │ POST /api/sync/descarga            │
   │ Descarga datos actualizados        │
   └────────────────────────────────────┘
                    ⬇
   App actualiza SQLite:
   ┌────────────────────────────────────┐
   │ UPDATE usuarios                    │
   │ SET id_usuario = 123               │
   │ WHERE id_usuario = 999;            │
   │                                    │
   │ DELETE FROM sync_queue             │
   │ WHERE synced = 1;                  │
   └────────────────────────────────────┘
                    ⬇
   ✅ Usuario con ID real
   ✅ Sincronizado en ambas bases
```

---

## 🔁 Sincronización Automática Continua

```
┌──────────────────────────────────────────────────────────────┐
│                    TIMER AUTOMÁTICO                           │
│                   Ejecuta cada 5 minutos                      │
└──────────────────────────────────────────────────────────────┘

    t=0min          t=5min          t=10min         t=15min
      │               │               │               │
      │   ┌───────┐   │   ┌───────┐   │   ┌───────┐   │
      ├──►│ Sync  │◄──┼──►│ Sync  │◄──┼──►│ Sync  │◄──┤
      │   └───┬───┘   │   └───┬───┘   │   └───┬───┘   │
      │       │       │       │       │       │       │
      │   1. SUBIDA   │   1. SUBIDA   │   1. SUBIDA   │
      │   ↓ ↓ ↓       │   ↓ ↓ ↓       │   ↓ ↓ ↓       │
      │   Datos       │   Datos       │   Datos       │
      │   pendientes  │   pendientes  │   pendientes  │
      │   al backend  │   al backend  │   al backend  │
      │       │       │       │       │       │       │
      │   2. DESCARGA │   2. DESCARGA │   2. DESCARGA │
      │   ↓ ↓ ↓       │   ↓ ↓ ↓       │   ↓ ↓ ↓       │
      │   Datos       │   Datos       │   Datos       │
      │   nuevos del  │   nuevos del  │   nuevos del  │
      │   servidor    │   servidor    │   servidor    │
      │       │       │       │       │       │       │
      └───────┘       └───────┘       └───────┘       └───

Resultado:
✅ Ambas bases de datos siempre sincronizadas
✅ Cambios en backend → Llegan al frontend en máximo 5 minutos
✅ Cambios offline → Se suben cuando hay conexión
```

---

## 📊 Comparación: Antes vs Ahora

### ANTES (Solo Subida)

```
┌──────────────────────────────────────────────────────────────┐
│                         LIMITACIÓN                            │
└──────────────────────────────────────────────────────────────┘

📱 App Móvil                        🌐 Backend
    │                                   │
    │  Registro offline                 │
    ├──────────────────────────────────►│
    │  POST /sync/subida                │
    │                                   │
    │                                   ├─► Guarda en PostgreSQL
    │                                   │
    │  ❌ NO PUEDE DESCARGAR            │
    │                                   │
    │  Si admin crea datos:             │
    │  - NO los recibe                  │
    │  - SQLite desactualizado          │
    │  - Usuario puede tener problemas  │
    │                                   │
```

### AHORA (Bidireccional)

```
┌──────────────────────────────────────────────────────────────┐
│                    SINCRONIZACIÓN COMPLETA                    │
└──────────────────────────────────────────────────────────────┘

📱 App Móvil                        🌐 Backend
    │                                   │
    │  1️⃣ SUBIDA                         │
    ├──────────────────────────────────►│
    │  POST /sync/subida                │
    │  - Validaciones offline           │
    │  - Registros pendientes           │
    │                                   ├─► Guarda en PostgreSQL
    │                                   │
    │  2️⃣ DESCARGA                       │
    │◄──────────────────────────────────┤
    │  POST /sync/descarga              │
    │  - Credenciales nuevas            │
    │  - Textos de audio                │
    │                                   │
    ├─► Guarda en SQLite               │
    │                                   │
    │  ✅ Ambas bases sincronizadas      │
    │  ✅ Datos del admin llegan a app   │
    │  ✅ Usuario siempre actualizado    │
    │                                   │
```

---

## 🎯 Casos de Uso Resueltos

### ✅ Caso 1: Admin Agrega Usuario
```
Admin en servidor → INSERT en PostgreSQL
                 ↓
App sincroniza cada 5 min → Descarga usuario
                 ↓
Usuario aparece en la app ✅
```

### ✅ Caso 2: Múltiples Dispositivos
```
Dispositivo A → Registra biometría → Sube a PostgreSQL
                                    ↓
                    Dispositivo B sincroniza → Descarga biometría
                                            ↓
                            Ambos dispositivos tienen mismos datos ✅
```

### ✅ Caso 3: Usuario Offline
```
Usuario sin WiFi → Registra cuenta → Guarda en SQLite
                                  ↓
                  Se conecta a WiFi → Auto-sync sube datos
                                  ↓
                          Backend guarda en PostgreSQL
                                  ↓
                            ID real asignado
                                  ↓
                    App descarga y actualiza SQLite ✅
```

---

## 🚀 Implementación Rápida

### Paso 1: Iniciar Sincronización Automática

```dart
// En tu login_screen.dart o home_screen.dart

import 'package:biometrics_app/services/bidirectional_sync_service.dart';

final syncService = BidirectionalSyncService();

// Al hacer login exitoso:
syncService.startAutoSync(
  idUsuario: loggedInUserId,
  dispositivoId: deviceId,
  interval: Duration(minutes: 5), // Sincroniza cada 5 minutos
);
```

### Paso 2: Detener al Cerrar Sesión

```dart
// Al hacer logout:
syncService.stopAutoSync();
syncService.dispose();
```

### Paso 3: Sincronizar Manualmente (Opcional)

```dart
// Botón "Sincronizar ahora":
final result = await syncService.fullSync(
  idUsuario: currentUserId,
  dispositivoId: deviceId,
);

if (result['success']) {
  print('✅ Sincronizado');
  print('Subidos: ${result['upload']['uploaded']}');
  print('Descargados: ${result['download']['downloaded']}');
}
```

---

## 📈 Monitoreo

### Logs en Consola

```
[AutoSync] Iniciando sincronización automática cada 5 minutos
[FullSync] Iniciando sincronización completa

[SyncUp] 2 registros pendientes
[SyncUp] ✅ Sincronizado: /api/auth/register
[SyncUp] Resultado: 2 exitosos, 0 fallidos

[SyncDown] Última sincronización: 2024-12-09 10:00:00
[SyncDown] Descargando datos para usuario: 123
[SyncDown] ✅ Credencial guardada: 456
[SyncDown] ✅ Frase de audio guardada: 789
[SyncDown] Resultado: 2 registros descargados

[AutoSync] Resultado: ✅ Exitoso
```

---

## 🎉 Resultado Final

### Antes
```
❌ Backend y Frontend desconectados
❌ Datos creados en backend NO llegan a la app
❌ Múltiples dispositivos con datos diferentes
❌ Admin no puede gestionar usuarios remotamente
```

### Ahora
```
✅ Backend y Frontend sincronizados
✅ Datos del backend DESCARGAN automáticamente
✅ Todos los dispositivos tienen mismos datos
✅ Admin puede crear/editar usuarios remotamente
✅ Sincronización cada 5 minutos sin intervención del usuario
```

---

## 📚 Archivos Creados/Modificados

1. **Nuevo Servicio:**
   - `mobile_app/lib/services/bidirectional_sync_service.dart`

2. **Backend (Ya existía):**
   - `backend/src/controllers/SincronizacionController.js`
   - `backend/src/routes/syncRoutes.js`

3. **Documentación:**
   - `SINCRONIZACION_BIDIRECCIONAL.md` ← Guía completa
   - `DIAGRAMA_SINCRONIZACION.md` ← Este archivo

---

¡Ahora tu sistema funciona como una aplicación profesional con sincronización completa! 🚀
