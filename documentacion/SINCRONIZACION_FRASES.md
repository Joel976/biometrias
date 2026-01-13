# 🔄 Sincronización de Frases para Autenticación Offline

## 📋 Resumen
Se ha implementado un sistema completo de **sincronización de frases** que permite a la aplicación funcionar **sin conexión a internet** para la autenticación por voz.

---

## ✨ Características Implementadas

### 1️⃣ **Base de Datos Local**
La tabla `textos_dinamicos_audio` en SQLite almacena las frases localmente:

```sql
CREATE TABLE textos_dinamicos_audio (
  id_texto INTEGER PRIMARY KEY AUTOINCREMENT,
  frase TEXT NOT NULL,
  estado_texto TEXT DEFAULT 'activo'
)
```

**Ubicación:** `mobile_app/lib/config/database_config.dart`

- ✅ Se crean automáticamente **6 frases predeterminadas** al inicializar la app
- ✅ Las frases se sincronizan desde el backend cuando hay conexión

---

### 2️⃣ **Métodos de Sincronización**

#### En `local_database_service.dart`:

```dart
/// 🔄 Sincronizar frases del backend a la base de datos local
Future<void> syncPhrasesFromBackend(List<Map<String, dynamic>> backendPhrases)

/// 📊 Obtener estadísticas de frases locales
Future<Map<String, dynamic>> getPhrasesStats()

/// 🎲 Obtener frase aleatoria de la base de datos local
Future<AudioPhrase?> getRandomAudioPhrase(int idUsuario)
```

**Funcionalidad:**
- `syncPhrasesFromBackend()` → Limpia y reemplaza todas las frases con las del backend
- `getPhrasesStats()` → Devuelve `{ total, activas, inactivas }`
- `getRandomAudioPhrase()` → Selecciona una frase aleatoria para autenticación offline

---

#### En `sync_manager.dart`:

```dart
/// 🔄 Sincronizar frases del backend a la base de datos local
Future<bool> syncPhrasesFromBackend()
```

**Flujo:**
1. Verifica si hay conexión a internet
2. Llama al backend (`BiometricBackendService.listarFrases()`)
3. Guarda todas las frases en SQLite
4. Devuelve `true` si fue exitoso

**Ubicación:** Se llama automáticamente al iniciar la app en `main.dart`

---

### 3️⃣ **Login Offline Mejorado**

#### En `login_screen.dart`:

La función `_loadRandomPhrase()` ahora tiene **3 niveles de fallback**:

```dart
1. 🌐 ONLINE → Obtener frase del backend (preferido)
2. 📱 OFFLINE → Obtener frase aleatoria de SQLite
3. ⚠️ FALLBACK → Usar frase hardcodeada ("Mi voz es mi contraseña")
```

**Código:**
```dart
if (isOnline) {
  // Obtener del backend
  final phraseData = await backendService.obtenerFraseAleatoria();
} else {
  // Obtener de SQLite
  final localPhrase = await localDb.getRandomAudioPhrase(1);
  
  if (localPhrase != null) {
    _currentPhrase = localPhrase.frase;
    _currentPhraseId = localPhrase.id;
  } else {
    // Última opción: frase predeterminada
    _currentPhrase = 'Mi voz es mi contraseña';
  }
}
```

---

### 4️⃣ **Modelo Actualizado**

El modelo `AudioPhrase` ahora soporta frases locales:

```dart
class AudioPhrase {
  final int id;
  final int? idUsuario;        // ✨ OPCIONAL
  final String frase;
  final String estadoTexto;
  final DateTime? fechaAsignacion;  // ✨ OPCIONAL
}
```

**Cambios:**
- ✅ `idUsuario` y `fechaAsignacion` ahora son **opcionales** (no todas las tablas los tienen)
- ✅ Compatible con `textos_dinamicos_audio` que solo tiene `id_texto`, `frase`, `estado_texto`

---

## 🚀 Flujo de Sincronización

### Al Iniciar la App (main.dart):

```
1. App inicia
2. Espera 2 segundos (para inicialización completa)
3. Llama a _syncPhrasesOnStartup()
4. SyncManager.syncPhrasesFromBackend() ejecuta:
   - Verifica conexión
   - Llama a BiometricBackendService.listarFrases()
   - Guarda en SQLite con LocalDatabaseService.syncPhrasesFromBackend()
5. Frases listas para uso offline
```

**Logs:**
```
[App] ✅ Frases sincronizadas del backend
[SyncManager] ✅ 10 frases sincronizadas exitosamente
[LocalDB] ✅ 10 frases sincronizadas desde backend
```

---

### Durante el Login:

```
Usuario selecciona "Autenticación por Voz"
   ↓
_loadRandomPhrase() se ejecuta
   ↓
¿Hay conexión? 
   ├─ SÍ → Obtener frase del backend (más reciente)
   └─ NO → Obtener frase de SQLite (sincronizada previamente)
      ↓
¿Hay frases en SQLite?
   ├─ SÍ → Usar frase aleatoria local
   └─ NO → Usar frase predeterminada (fallback final)
```

**Logs Offline:**
```
[Login] 📱 Sin conexión, buscando frase en base de datos local...
[Login] ✅ Frase local cargada: "Verificación de identidad por voz" (ID: 3)
```

**Logs Online:**
```
[Login] 🌐 Obteniendo frase aleatoria del backend...
[Login] ✅ Frase cargada: "Sistema de seguridad biométrica" (ID: 15)
```

---

## 📊 Estadísticas de Frases

Puedes obtener información sobre las frases almacenadas:

```dart
final stats = await localDb.getPhrasesStats();

// Devuelve:
{
  'total': 10,
  'activas': 8,
  'inactivas': 2
}
```

---

## 🧪 Cómo Probar

### Prueba 1: Sincronización al Iniciar
1. Asegúrate de tener conexión a internet
2. Inicia la app
3. Verifica los logs: `[App] ✅ Frases sincronizadas del backend`

### Prueba 2: Login Offline
1. Cierra la app
2. **Desactiva el WiFi y datos móviles**
3. Abre la app
4. Ve a login → selecciona "Autenticación por Voz"
5. **Resultado esperado:** Verás una frase aleatoria de la base de datos local

### Prueba 3: Fallback Final
1. Elimina la base de datos local (reinstala la app)
2. Desactiva el internet
3. Inicia la app e intenta login por voz
4. **Resultado esperado:** Verás "Mi voz es mi contraseña" (frase predeterminada)

---

## 🔧 Archivos Modificados

| Archivo | Cambios |
|---------|---------|
| `local_database_service.dart` | ✅ Agregado `syncPhrasesFromBackend()`, `getPhrasesStats()` |
| `sync_manager.dart` | ✅ Agregado `syncPhrasesFromBackend()` |
| `login_screen.dart` | ✅ Mejorado `_loadRandomPhrase()` con fallback a SQLite |
| `biometric_models.dart` | ✅ Hecho `idUsuario` y `fechaAsignacion` opcionales |
| `main.dart` | ✅ Agregado `_syncPhrasesOnStartup()` en `initState()` |

---

## 📦 Frases Predeterminadas

Estas frases se insertan automáticamente si la tabla está vacía:

1. "Mi voz es mi contraseña"
2. "Autenticación por reconocimiento de voz"
3. "Acceso seguro mediante biometría vocal"
4. "Verificación de identidad por voz"
5. "Sistema de seguridad biométrica"
6. "Ingreso autorizado por voz"

**Ubicación:** `database_config.dart` → método `_seedDefaultPhrases()`

---

## ⚡ Ventajas

✅ **Funciona sin internet:** Login por voz disponible offline  
✅ **Sincronización automática:** Frases se actualizan al iniciar la app  
✅ **Fallback robusto:** 3 niveles de respaldo si falla la carga  
✅ **Frases aleatorias:** Mejora la seguridad (anti-spoofing)  
✅ **Compatibilidad:** No rompe funcionalidad existente  

---

## 🛠️ Mejoras Futuras

- [ ] Sincronización periódica cada X minutos (configurable en admin panel)
- [ ] Indicador visual cuando se usan frases locales vs backend
- [ ] Opción manual de "Actualizar frases" en configuraciones
- [ ] Estadísticas de uso de frases (cuáles se usan más)
- [ ] Soporte para frases personalizadas por usuario

---

## 📞 Soporte

Para más información, consulta:
- 📄 `OFFLINE_SYNC_GUIDE.md` - Guía general de sincronización offline
- 📄 `QUICK_START.md` - Inicio rápido de la aplicación
- 📄 `TESTING_GUIDE.md` - Guía completa de pruebas

---

**Última actualización:** $(Get-Date -Format "yyyy-MM-dd HH:mm")  
**Estado:** ✅ Completado y funcional
