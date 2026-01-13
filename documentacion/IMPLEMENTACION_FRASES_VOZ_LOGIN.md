# Implementación: Frases Dinámicas en Login de Voz

## 📋 Resumen

Se implementó el sistema de **frases dinámicas** para la autenticación de voz en el login, donde:
1. Al seleccionar "Voz", la app consulta una frase aleatoria del backend
2. La frase se muestra al usuario para que la diga
3. Se usa el ID de esa frase específica para autenticar

---

## 🎯 Cambios Implementados

### 1. **Variables de Estado en `login_screen.dart`**

Agregadas nuevas variables para gestionar las frases:

```dart
// 🎤 Variables para autenticación de voz
String? _currentPhrase;       // Frase que el usuario debe decir
int? _currentPhraseId;        // ID de la frase actual
bool _isLoadingPhrase = false; // Cargando frase desde backend
```

### 2. **Método `_loadRandomPhrase()`**

Nuevo método que consulta una frase aleatoria del backend:

```dart
Future<void> _loadRandomPhrase() async {
  setState(() {
    _isLoadingPhrase = true;
    _currentPhrase = null;
    _currentPhraseId = null;
  });

  try {
    final backendService = BiometricBackendService();
    final isOnline = await backendService.isOnline();

    if (isOnline) {
      print('[Login] 🌐 Obteniendo frase aleatoria del backend...');
      
      final phraseData = await backendService.obtenerFraseAleatoria();
      
      setState(() {
        _currentPhraseId = phraseData['id_texto'] ?? phraseData['id'];
        _currentPhrase = phraseData['frase'];
        _isLoadingPhrase = false;
      });
      
      print('[Login] ✅ Frase cargada: $_currentPhrase (ID: $_currentPhraseId)');
    } else {
      // Fallback: usar frase local por defecto
      print('[Login] ⚠️ Sin conexión, usando frase local por defecto');
      setState(() {
        _currentPhrase = 'Mi voz es mi contraseña';
        _currentPhraseId = 1;
        _isLoadingPhrase = false;
      });
    }
  } catch (e) {
    print('[Login] ❌ Error cargando frase: $e');
    // Usar frase por defecto
    setState(() {
      _currentPhrase = 'Mi voz es mi contraseña';
      _currentPhraseId = 1;
      _isLoadingPhrase = false;
      _errorMessage = 'No se pudo cargar frase del servidor, usando frase por defecto';
    });
  }
}
```

**Características:**
- ✅ Consulta `GET /frases/aleatoria` del backend de voz
- ✅ Maneja errores con graceful fallback a frase por defecto
- ✅ Funciona offline usando frase predeterminada
- ✅ Logs detallados para debugging

### 3. **Trigger al Seleccionar "Voz"**

Modificado el `ChoiceChip` para cargar la frase automáticamente:

```dart
ChoiceChip(
  label: const Text('Voz'),
  selected: _selectedBiometricType == 2,
  onSelected: (_) {
    setState(() => _selectedBiometricType = 2);
    _loadRandomPhrase(); // 🎤 Cargar frase cuando selecciona voz
  },
),
```

### 4. **UI Mejorada - Visualización de la Frase**

Se agregó un widget visual que muestra la frase antes de grabar:

```dart
// 🎤 Mostrar frase que debe decir el usuario
if (_isLoadingPhrase)
  // Indicador de carga
  const Center(
    child: Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 8),
        Text('Cargando frase...'),
      ],
    ),
  )
else if (_currentPhrase != null)
  // Frase cargada exitosamente
  Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.blue.shade300,
        width: 2,
      ),
    ),
    child: Column(
      children: [
        const Row(
          children: [
            Icon(Icons.record_voice_over, 
              color: Colors.blue,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Di la siguiente frase:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '"$_currentPhrase"',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            color: Colors.black87,
          ),
        ),
      ],
    ),
  )
else
  // Error al cargar frase
  Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.orange.shade300,
        width: 2,
      ),
    ),
    child: const Row(
      children: [
        Icon(Icons.warning_amber_rounded, 
          color: Colors.orange,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'No se pudo cargar la frase. Verifica tu conexión.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  ),
```

**Estados visuales:**
- 🔄 **Cargando:** Spinner mientras consulta el backend
- ✅ **Frase cargada:** Card azul con la frase destacada
- ⚠️ **Error:** Card naranja con advertencia

### 5. **Autenticación con ID de Frase Específica**

Modificado el flujo de autenticación para usar `_currentPhraseId`:

```dart
// Voz - Backend Cloud
if (_recordedAudio == null) {
  throw Exception('Por favor graba tu voz primero');
}

// 🎤 Usar la frase que se mostró al usuario
if (_currentPhraseId == null) {
  throw Exception(
    'No hay frase cargada. Por favor selecciona "Voz" nuevamente.',
  );
}

print('[Login] 🎤 Autenticando voz con frase ID: $_currentPhraseId');

final result = await backendService.autenticarVoz(
  audioBytes: _recordedAudio!,
  identificador: _identifierController.text,
  idFrase: _currentPhraseId!, // ✅ Usar ID de la frase mostrada
);
```

**Ventajas:**
- ✅ El usuario sabe exactamente qué frase debe decir
- ✅ El backend valida contra la misma frase específica
- ✅ Evita desincronización entre frase mostrada y validada
- ✅ Validación robusta con mensaje de error claro

---

## 🔧 Endpoint Backend Utilizado

### GET `/frases/aleatoria`

**URL completa:**
```
GET http://167.71.155.9:8081/frases/aleatoria
```

**Respuesta esperada:**
```json
{
  "id_texto": 5,
  "frase": "Acceso seguro mediante biometría vocal",
  "estado_texto": "activo"
}
```

**Códigos de estado:**
- `200 OK` → Frase obtenida exitosamente
- `404 Not Found` → No hay frases activas
- `500 Internal Server Error` → Error del servidor

---

## 🎨 Flujo UX Completo

### Paso 1: Usuario Selecciona "Voz"
```
Usuario hace clic en chip "Voz"
    ↓
App ejecuta _loadRandomPhrase()
    ↓
Muestra "Cargando frase..." (spinner)
    ↓
Consulta GET /frases/aleatoria al backend
```

### Paso 2: Frase Cargada
```
Backend responde con frase aleatoria
    ↓
App guarda _currentPhrase y _currentPhraseId
    ↓
Muestra card azul con:
  🎤 "Di la siguiente frase:"
  📝 "Mi voz es mi contraseña"
```

### Paso 3: Usuario Graba Voz
```
Usuario presiona botón de micrófono
    ↓
App graba audio durante 3-5 segundos
    ↓
Usuario presiona stop
    ↓
Audio guardado en _recordedAudio
```

### Paso 4: Autenticación
```
Usuario presiona "Iniciar Sesión"
    ↓
App envía a backend:
  - audio: archivo de voz grabado
  - identificador: ID del usuario
  - id_frase: _currentPhraseId (ej: 5)
    ↓
Backend compara:
  - Voz del audio vs plantillas registradas
  - Transcripción vs frase ID 5
    ↓
Respuesta: autenticado = true/false
```

---

## 📊 Diagrama de Flujo

```
┌─────────────────────────────────────────────────────────┐
│  Usuario selecciona "Voz" en Login                      │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  _loadRandomPhrase() ejecutado                          │
│  • Verifica conexión                                    │
│  • GET /frases/aleatoria                                │
└────────────────────┬────────────────────────────────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
    ┌─────────┐          ┌──────────┐
    │ Online  │          │ Offline  │
    └────┬────┘          └─────┬────┘
         │                     │
         ▼                     ▼
┌──────────────────┐   ┌────────────────────┐
│ Frase del backend│   │ Frase por defecto  │
│ ID: 5            │   │ ID: 1              │
│ "Acceso seguro..." │ │ "Mi voz es mi..." │
└────┬─────────────┘   └─────┬──────────────┘
     │                       │
     └───────────┬───────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│  Mostrar frase en UI (card azul destacado)              │
│  "Di la siguiente frase: 'Acceso seguro...'"            │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  Usuario graba audio diciendo la frase                  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  POST /voz/autenticar                                   │
│  • audio: archivo grabado                               │
│  • identificador: "1234567890"                          │
│  • id_frase: 5                                          │
└────────────────────┬────────────────────────────────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
    ┌──────────┐          ┌──────────┐
    │ Éxito    │          │ Fallo    │
    │ ✅       │          │ ❌       │
    └────┬─────┘          └─────┬────┘
         │                      │
         ▼                      ▼
┌─────────────────┐    ┌─────────────────┐
│ Ir a Main Menu  │    │ Mensaje error   │
└─────────────────┘    │ Intentos: 9     │
                       └─────────────────┘
```

---

## 🧪 Pruebas

### Caso 1: Login con Conexión ✅

**Pasos:**
1. Conectar dispositivo a WiFi/datos
2. Abrir app de login
3. Ingresar identificador
4. Seleccionar "Voz"
5. Verificar que aparece frase del backend
6. Grabar voz diciendo la frase
7. Presionar "Iniciar Sesión"

**Resultado esperado:**
- ✅ Frase se carga del backend
- ✅ Frase se muestra en card azul
- ✅ Audio se envía con `id_frase` correcto
- ✅ Autenticación exitosa

### Caso 2: Login Sin Conexión 🔄

**Pasos:**
1. Activar modo avión
2. Abrir app de login
3. Ingresar identificador
4. Seleccionar "Voz"
5. Verificar frase por defecto

**Resultado esperado:**
- ⚠️ Frase por defecto: "Mi voz es mi contraseña"
- ⚠️ ID frase: 1
- ✅ UI funciona normalmente
- ⚠️ Autenticación usará fallback local

### Caso 3: Error del Backend ❌

**Pasos:**
1. Simular backend caído (cambiar puerto en admin)
2. Seleccionar "Voz"
3. Esperar timeout

**Resultado esperado:**
- ⚠️ Mensaje: "No se pudo cargar frase del servidor..."
- ✅ Fallback a frase por defecto
- ✅ App no se crashea

---

## 🔧 Correcciones Adicionales

### Fix: Error SQL en `getActiveAudioPhrases()`

**Problema anterior:**
```sql
SELECT * FROM textos_dinamicos_audio 
WHERE id_usuario = ? AND estado_texto = ?
```

❌ Error: `no such column: id_usuario`

**Solución:**
```dart
Future<List<AudioPhrase>> getActiveAudioPhrases(int idUsuario) async {
  final db = await _db;
  // ✅ FIX: textos_dinamicos_audio NO tiene columna id_usuario (es tabla global)
  final result = await db.query(
    'textos_dinamicos_audio',
    where: 'estado_texto = ?',
    whereArgs: ['activo'],
  );

  return result.map((map) => AudioPhrase.fromMap(map)).toList();
}
```

### Agregado: Frases Predeterminadas en SQLite

Se agregó método `_seedDefaultPhrases()` en `database_config.dart`:

```dart
Future<void> _seedDefaultPhrases(Database db) async {
  final count = Sqflite.firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM textos_dinamicos_audio'),
  );
  
  if (count == null || count == 0) {
    print('📝 Insertando frases predeterminadas...');
    
    final defaultPhrases = [
      'Mi voz es mi contraseña',
      'Autenticación por reconocimiento de voz',
      'Acceso seguro mediante biometría vocal',
      'Verificación de identidad por voz',
      'Sistema de seguridad biométrica',
      'Ingreso autorizado por voz',
    ];
    
    for (int i = 0; i < defaultPhrases.length; i++) {
      await db.insert('textos_dinamicos_audio', {
        'frase': defaultPhrases[i],
        'estado_texto': 'activo',
      });
    }
    
    print('✅ ${defaultPhrases.length} frases predeterminadas insertadas');
  }
}
```

---

## 📝 Archivos Modificados

| Archivo | Cambios |
|---------|---------|
| `lib/screens/login_screen.dart` | • Variables de estado para frases<br>• Método `_loadRandomPhrase()`<br>• UI para mostrar frase<br>• Autenticación con `id_frase` específico |
| `lib/services/local_database_service.dart` | • Fix SQL en `getActiveAudioPhrases()`<br>• Eliminado filtro por `id_usuario` |
| `lib/config/database_config.dart` | • Método `_seedDefaultPhrases()`<br>• Inserción automática de 6 frases |
| `lib/services/biometric_backend_service.dart` | • Ya existía `obtenerFraseAleatoria()` ✅ |

---

## 🎯 Validación Final

### Checklist de Implementación

- ✅ Endpoint GET `/frases/aleatoria` se consulta correctamente
- ✅ Frase se muestra al usuario antes de grabar
- ✅ ID de frase se guarda en `_currentPhraseId`
- ✅ Autenticación usa `id_frase` correcto
- ✅ Manejo de errores con fallback
- ✅ UI responsive con estados visuales claros
- ✅ Logs detallados para debugging
- ✅ Funciona offline con frase por defecto
- ✅ No hay errores de compilación

---

## 🚀 Próximos Pasos (Opcional)

### Mejoras Sugeridas:

1. **Cache de frases:**
   - Guardar últimas 5 frases en SQLite
   - Rotar frases offline sin repetir

2. **Visualización de transcripción:**
   - Mostrar texto transcrito después de grabar
   - Comparar visualmente con frase objetivo

3. **Indicador de similitud:**
   - Barra de progreso mostrando % de coincidencia
   - Feedback en tiempo real

4. **Historial de intentos:**
   - Mostrar últimas 3 frases usadas
   - Evitar repetición reciente

---

**Fecha:** 8 de enero de 2026  
**Autor:** GitHub Copilot  
**Estado:** ✅ **IMPLEMENTADO Y FUNCIONANDO**
