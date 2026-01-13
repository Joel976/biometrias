# 🆕 Paneles de Usuarios por Estado de Sincronización

## 📋 Resumen
Se han agregado **3 paneles nuevos** en el Panel de Administración para clasificar usuarios según su estado de sincronización entre la base de datos **local (SQLite)** y el **backend (PostgreSQL)**.

---

## ✨ Paneles Implementados

### 1️⃣ **📱 Usuarios Solo Offline**

**Descripción:**  
Muestra usuarios que están **registrados localmente** en el dispositivo pero **NO están sincronizados** al backend en la nube.

**Características:**
- 🔍 Busca usuarios en la base de datos SQLite local
- ☁️ Compara con usuarios en el backend (PostgreSQL)
- 📊 Filtra solo los que NO existen en el backend
- 🟠 Identificados con icono `phonelink_off` y color naranja

**Casos de uso:**
- Usuarios registrados **sin conexión a internet**
- Usuarios que **fallaron al sincronizarse** al backend
- Registros **pendientes de subir** a la nube

**Interfaz:**
```
┌─────────────────────────────────────┐
│ 📱 Usuarios Solo Offline            │
│ 🔄 Recargar                         │
├─────────────────────────────────────┤
│ [🟠] Joel Pérez                     │
│      ID: 0503096083                 │
│      📱 Solo en dispositivo local   │
│      [☁️ Sincronizar]               │
├─────────────────────────────────────┤
│ [🟠] María González                 │
│      ID: 1234567890                 │
│      📱 Solo en dispositivo local   │
│      [☁️ Sincronizar]               │
└─────────────────────────────────────┘
```

**Logs:**
```
[AdminPanel] 📱 Buscando usuarios solo offline...
[AdminPanel] 📱 3 usuarios solo offline encontrados
✅ 3 usuarios solo offline
```

---

### 2️⃣ **☁️ Usuarios Solo Online**

**Descripción:**  
Muestra usuarios que están **en el backend** (PostgreSQL) pero **NO están descargados** localmente en el dispositivo.

**Características:**
- 🌐 Busca usuarios en el backend (API REST)
- 📱 Compara con usuarios en SQLite local
- 🔽 Filtra solo los que NO existen localmente
- 🔵 Identificados con icono `cloud` y color azul

**Casos de uso:**
- Usuarios **registrados en otro dispositivo**
- Usuarios **eliminados localmente** pero no en el backend
- Usuarios **nuevos en el backend** que no se han descargado

**Interfaz:**
```
┌─────────────────────────────────────┐
│ ☁️ Usuarios Solo Online              │
│ 🔄 Recargar                         │
├─────────────────────────────────────┤
│ [🔵] Ana Torres                     │
│      ID: 9876543210                 │
│      ☁️ Solo en backend             │
│      [⬇️ Descargar]                 │
├─────────────────────────────────────┤
│ [🔵] Carlos Ruiz                    │
│      ID: 1122334455                 │
│      ☁️ Solo en backend             │
│      [⬇️ Descargar]                 │
└─────────────────────────────────────┘
```

**Logs:**
```
[AdminPanel] ☁️ Buscando usuarios solo online...
[AdminPanel] ☁️ 2 usuarios solo online encontrados
✅ 2 usuarios solo online
```

---

### 3️⃣ **🔄 Usuarios Sincronizados**

**Descripción:**  
Muestra usuarios que están **tanto localmente como en el backend**, es decir, **perfectamente sincronizados**.

**Características:**
- ✅ Busca usuarios que existen en AMBOS lados
- 🔄 Valida sincronización bidireccional
- 🟢 Identificados con icono `sync` y color verde

**Casos de uso:**
- Usuarios **completamente sincronizados**
- Validar que el **registro fue exitoso** en ambos lados
- Verificar **integridad de datos**

**Interfaz:**
```
┌─────────────────────────────────────┐
│ 🔄 Usuarios Sincronizados           │
│ 🔄 Recargar                         │
├─────────────────────────────────────┤
│ [🟢] Pedro Sánchez                  │
│      ID: 5566778899                 │
│      ✅ Sincronizado (Local+Backend)│
│      [✓]                            │
├─────────────────────────────────────┤
│ [🟢] Laura Martínez                 │
│      ID: 6677889900                 │
│      ✅ Sincronizado (Local+Backend)│
│      [✓]                            │
└─────────────────────────────────────┘
```

**Logs:**
```
[AdminPanel] 🔄 Buscando usuarios sincronizados...
[AdminPanel] 🔄 5 usuarios sincronizados encontrados
✅ 5 usuarios sincronizados
```

---

## 🔧 Implementación Técnica

### Variables de Estado Agregadas:

```dart
// 🆕 Usuarios por categoría de sincronización
List<User> _offlineOnlyUsers = [];
List<User> _onlineOnlyUsers = [];
List<User> _syncedUsers = [];
bool _isLoadingOfflineUsers = false;
bool _isLoadingOnlineUsers = false;
bool _isLoadingSyncedUsers = false;
```

### Métodos Implementados:

#### 1. `_loadOfflineOnlyUsers()`
```dart
Future<void> _loadOfflineOnlyUsers() async {
  // 1. Obtener todos los usuarios locales (SQLite)
  final localUsers = await _dbService.getAllUsers();
  
  // 2. Obtener usuarios del backend (API REST)
  final response = await dio.get('/usuarios');
  final backendUsers = <String>{};
  
  // 3. Extraer IDs de usuarios en el backend
  for (var userData in response.data) {
    backendUsers.add(user.identificadorUnico);
  }
  
  // 4. Filtrar usuarios que SOLO están offline
  final offlineOnly = localUsers.where((user) {
    return !backendUsers.contains(user.identificadorUnico);
  }).toList();
}
```

#### 2. `_loadOnlineOnlyUsers()`
```dart
Future<void> _loadOnlineOnlyUsers() async {
  // 1. Obtener usuarios del backend
  final backendUsers = await _fetchBackendUsers();
  
  // 2. Obtener usuarios locales
  final localUsers = await _dbService.getAllUsers();
  final localIds = localUsers.map((u) => u.identificadorUnico).toSet();
  
  // 3. Filtrar usuarios que SOLO están en backend
  final onlineOnly = backendUsers.where((user) {
    return !localIds.contains(user.identificadorUnico);
  }).toList();
}
```

#### 3. `_loadSyncedUsers()`
```dart
Future<void> _loadSyncedUsers() async {
  // 1. Obtener usuarios locales
  final localUsers = await _dbService.getAllUsers();
  
  // 2. Obtener usuarios del backend
  final backendUsers = await _fetchBackendUsers();
  final backendIds = backendUsers.map((u) => u.identificadorUnico).toSet();
  
  // 3. Filtrar usuarios en AMBOS lados
  final synced = localUsers.where((user) {
    return backendIds.contains(user.identificadorUnico);
  }).toList();
}
```

---

## 📍 Ubicación en el Panel de Administración

### Desktop (2 columnas):

```
┌─────────────────────┬─────────────────────┐
│ 👥 Gestión Usuarios │ 🌐 Red y API        │
│ 📱 Solo Offline     │ 🐛 Debug            │
│ ☁️ Solo Online      │ 📸 Biometría        │
│ 🔄 Sincronizados    │ ⚙️ Acciones         │
│ 💬 Frases           │                     │
│ 🎨 Apariencia       │                     │
└─────────────────────┴─────────────────────┘
```

### Mobile (1 columna):

```
┌─────────────────────┐
│ 👥 Gestión Usuarios │
│ 📱 Solo Offline     │
│ ☁️ Solo Online      │
│ 🔄 Sincronizados    │
│ 💬 Frases           │
│ 🎨 Apariencia       │
│ 🔄 Sincronización   │
│ 🔒 Seguridad        │
│ ...                 │
└─────────────────────┘
```

---

## 🧪 Cómo Probar

### Prueba 1: Usuarios Solo Offline
```bash
1. Abre la app SIN internet
2. Registra un usuario nuevo (ej: "TEST OFFLINE")
3. Ve al Panel de Administración
4. Click en "Buscar Usuarios Offline"
5. ✅ Deberías ver al usuario "TEST OFFLINE"
```

### Prueba 2: Usuarios Solo Online
```bash
1. Registra un usuario en OTRO dispositivo
2. En tu dispositivo, NO cargues usuarios aún
3. Abre Panel de Administración
4. Click en "Buscar Usuarios Online"
5. ✅ Deberías ver al usuario del otro dispositivo
```

### Prueba 3: Usuarios Sincronizados
```bash
1. Registra un usuario CON internet
2. Espera a que se sincronice
3. Ve al Panel de Administración
4. Click en "Buscar Usuarios Sincronizados"
5. ✅ Deberías ver al usuario con ✅ verde
```

---

## 📊 Estadísticas de Ejemplo

Supongamos que tienes:
- **5 usuarios** en SQLite local
- **8 usuarios** en el backend (PostgreSQL)

**Resultados esperados:**
- **📱 Solo Offline:** 2 usuarios (están en local pero no en backend)
- **☁️ Solo Online:** 5 usuarios (están en backend pero no en local)
- **🔄 Sincronizados:** 3 usuarios (están en AMBOS lados)

**Diagrama:**
```
Local (SQLite):     [A, B, C, D, E]
Backend (PostgreSQL): [C, D, E, F, G, H, I, J]

Solo Offline:  [A, B]
Solo Online:   [F, G, H, I, J]
Sincronizados: [C, D, E]
```

---

## 🎨 Identificadores Visuales

| Categoría | Icono | Color | Badge |
|-----------|-------|-------|-------|
| **Solo Offline** | 📱 `phonelink_off` | 🟠 Naranja | "Solo en dispositivo local" |
| **Solo Online** | ☁️ `cloud` | 🔵 Azul | "Solo en backend" |
| **Sincronizados** | 🔄 `sync` | 🟢 Verde | "Sincronizado (Local+Backend)" |

---

## 🚀 Funcionalidades Futuras

### Pendientes de Implementación:

1. **Sincronizar usuario offline al backend**
   - Botón "☁️ Sincronizar" en panel offline
   - Sube usuario de SQLite → PostgreSQL
   - Actualiza credenciales biométricas

2. **Descargar usuario online a local**
   - Botón "⬇️ Descargar" en panel online
   - Descarga usuario de PostgreSQL → SQLite
   - Sincroniza datos biométricos

3. **Re-sincronizar usuario sincronizado**
   - Botón "🔄 Re-sincronizar" en panel sincronizados
   - Compara datos y actualiza diferencias
   - Resuelve conflictos automáticamente

4. **Estadísticas de sincronización**
   - Gráfico de distribución de usuarios
   - Historial de sincronizaciones
   - Alertas de usuarios desincronizados

---

## 🔍 Logs de Depuración

### Logs Completos:

```dart
// Usuarios Solo Offline
[AdminPanel] 📱 Buscando usuarios solo offline...
[AdminPanel] 📡 Obteniendo usuarios del backend...
[AdminPanel] ✅ 8 usuarios en backend
[AdminPanel] 📂 5 usuarios en local
[AdminPanel] 🔍 Comparando identificadores...
[AdminPanel] 📱 2 usuarios solo offline encontrados
✅ 2 usuarios solo offline

// Usuarios Solo Online
[AdminPanel] ☁️ Buscando usuarios solo online...
[AdminPanel] 📡 Obteniendo usuarios del backend...
[AdminPanel] ✅ 8 usuarios en backend
[AdminPanel] 📂 5 usuarios en local
[AdminPanel] 🔍 Comparando identificadores...
[AdminPanel] ☁️ 5 usuarios solo online encontrados
✅ 5 usuarios solo online

// Usuarios Sincronizados
[AdminPanel] 🔄 Buscando usuarios sincronizados...
[AdminPanel] 📂 5 usuarios en local
[AdminPanel] 📡 Obteniendo usuarios del backend...
[AdminPanel] ✅ 8 usuarios en backend
[AdminPanel] 🔍 Comparando identificadores...
[AdminPanel] 🔄 3 usuarios sincronizados encontrados
✅ 3 usuarios sincronizados
```

---

## 📦 Archivos Modificados

| Archivo | Cambios |
|---------|---------|
| `admin_panel_screen.dart` | ✅ Agregadas 3 variables de estado |
| | ✅ Agregados 3 métodos de carga |
| | ✅ Agregados 3 widgets de UI |
| | ✅ Integrados en layouts desktop y móvil |

---

## 💡 Notas Importantes

1. **Requiere conexión a internet** para comparar con el backend
   - Si no hay conexión, solo muestra usuarios locales
   
2. **Comparación por `identificadorUnico`**
   - Usa la cédula/ID como clave única
   - Debe ser igual en ambos lados para considerar sincronizado

3. **No modifica datos automáticamente**
   - Solo muestra el estado actual
   - Las acciones de sincronización están pendientes

4. **Performance optimizado**
   - Usa `Set<String>` para comparaciones rápidas O(1)
   - Filtra con `where()` eficientemente

---

## 🎯 Casos de Uso Reales

### Escenario 1: Registro Offline
```
Usuario registra sin internet
     ↓
Datos guardados en SQLite local
     ↓
Panel muestra en "📱 Solo Offline"
     ↓
Cuando hay internet → Click "Sincronizar"
     ↓
Usuario aparece en "🔄 Sincronizados"
```

### Escenario 2: Usuario de Otro Dispositivo
```
Dispositivo A registra usuario "Juan"
     ↓
Dispositivo B abre panel admin
     ↓
Panel muestra "Juan" en "☁️ Solo Online"
     ↓
Click "Descargar"
     ↓
"Juan" aparece en "🔄 Sincronizados"
```

### Escenario 3: Auditoria de Sincronización
```
Administrador abre panel
     ↓
Click "Buscar Usuarios Sincronizados"
     ↓
Ve 10 usuarios sincronizados ✅
     ↓
Click "Buscar Usuarios Solo Offline"
     ↓
Ve 2 usuarios pendientes de sincronizar ⚠️
     ↓
Sincroniza manualmente
```

---

**Última actualización:** 2026-01-09  
**Estado:** ✅ Completado - Paneles funcionales y listos para usar
