# 🎯 EPIC + HISTORIAS DE USUARIO - Sistema Biométrico Multimodal Flutter

**Proyecto:** Sistema de Autenticación Biométrica Multiplataforma  
**Equipo:** Desarrollo Móvil Flutter  
**Fecha Creación:** 24 de Enero de 2026  
**Stack Técnico:** Flutter 3.27+ | Dart FFI | C++ (libvoz_mobile.so) | SQLite | PostgreSQL | HTTP REST  

---

## 📋 EPIC: BIOM-001

### **Título:** Integración de Biometría Multimodal con Librerías Nativas C++ en Flutter

### **Descripción:**

Como **equipo de desarrollo móvil Flutter**, necesitamos **integrar las librerías nativas C++ compiladas** (libvoz_mobile.so para VOZ y librera para OREJA) mediante **FFI (Foreign Function Interface)** para crear un **sistema móvil de autenticación biométrica multimodal** que funcione en modo **offline-first** con **sincronización bidireccional** hacia el servidor PostgreSQL en la nube.

El backend C++ ya entregó las librerías compiladas mediante CMake:
- **libvoz_mobile.so** (25.85 MB) - Extracción de 143 MFCCs + Clasificador SVM multiclase
- **libomp.so** (1.15 MB, NDK 26) - OpenMP para paralelización
- **libc++_shared.so** (1.74 MB) - C++ Standard Library

Nuestra responsabilidad incluye:

1. **Integración FFI** con las librerías nativas C++ (.so)
2. **Captura de audio** en formato WAV 16kHz mono con frases dinámicas
3. **Captura de imágenes** de oreja con validación TensorFlow Lite
4. **Base de datos SQLite local** (v12) con schema compatible PostgreSQL
5. **Sincronización bidireccional** offline/online con cola de pendientes
6. **UI Flutter** con flujo de registro (3 pasos) y login biométrico
7. **Endpoints HTTP** para sincronizar vectores MFCC, validaciones y usuarios

### **Objetivos de Negocio:**

- ✅ Autenticación biométrica multimodal (Voz + Oreja) en dispositivos móviles
- ✅ Funcionalidad 100% offline con sincronización automática al recuperar conexión
- ✅ Reutilización de librerías C++ del backend (sin reimplementar algoritmos)
- ✅ Experiencia de usuario fluida con captura guiada paso a paso
- ✅ Auditoría completa de validaciones biométricas locales y remotas

### **Stack Técnico:**

**Frontend Mobile:**
- Flutter 3.27.0+ (Dart SDK >=3.8.0)
- dart:ffi para integración con C++
- Provider/Riverpod para state management
- Camera (v0.11.2+1) para captura de imágenes
- Record (v6.1.2) + flutter_sound (v9.2.13) para audio
- TFLite Flutter (v0.11.0) para validación de orejas

**Base de Datos Local:**
- SQLite (sqflite v2.4.2)
- 8 tablas principales (usuarios, credenciales_biometricas, validaciones_biometricas, textos_dinamicos_audio, cola_sincronizacion, etc.)
- Esquema compatible con PostgreSQL backend

**Networking:**
- HTTP (v1.1.0) + Dio (v5.3.1)
- connectivity_plus (v7.0.0) para detección de red
- Endpoints REST: `/auth/register-biometric`, `/auth/authenticate-ear`, `/auth/authenticate-voice`

**Nativo:**
- libvoz_mobile.so (C++ con CMake, NDK 26)
- FFI bindings en `lib/services/native_voice_service.dart`
- JNI libs en `android/app/src/main/jniLibs/arm64-v8a/`

### **Alcance del EPIC:**

✅ **Incluido:**
- Registro completo: datos personales + 7 fotos oreja + 6 audios voz
- Login biométrico: Oreja O Voz (seleccionable)
- Validación offline con libvoz_mobile.so (SVM 143 MFCCs, threshold 99%)
- Validación online con backend PostgreSQL (prioridad cloud-first)
- Cola de sincronización con retry automático
- Frases dinámicas aleatorias (20 frases motivacionales)
- Auditoría local de validaciones biométricas

❌ **Excluido:**
- Biometría facial (no requerida en MVP)
- Sincronización en tiempo real (solo al recuperar conexión)
- Edición de datos personales post-registro
- Panel de administración móvil (existe como webapp separada)

### **Criterios de Aceptación del EPIC:**

- ✅ Usuario puede registrarse 100% offline y sincronizar después
- ✅ Usuario puede autenticarse con voz O oreja en modo offline
- ✅ Sistema prioriza validación cloud cuando hay conexión
- ✅ Cola de sincronización procesa pendientes automáticamente
- ✅ FFI carga libvoz_mobile.so sin errores de símbolos
- ✅ Audio grabado en WAV 16kHz mono compatible con backend
- ✅ Imágenes de oreja recortadas a 224x224 para TFLite
- ✅ Threshold de autenticación configurable (actual: 99%)
- ✅ Base de datos SQLite migra correctamente a v12

### **Story Points Estimados:** 44 SP

**Distribución:**
- BIOM-101: Integración FFI libvoz_mobile.so → 8 SP
- BIOM-102: Sistema captura audio con frases → 5 SP
- BIOM-103: Sincronización bidireccional offline/online → 13 SP
- BIOM-104: Base de datos SQLite con PostgreSQL schema → 8 SP
- BIOM-105: UI Flutter registro y login multimodal → 10 SP

### **Sprints Estimados:** 2 sprints (4 semanas)

**Sprint 1:**
- BIOM-101: Integración FFI ✅ (8 SP)
- BIOM-104: SQLite Database ✅ (8 SP)
- BIOM-102: Audio Capture ✅ (5 SP)
**Total Sprint 1:** 21 SP

**Sprint 2:**
- BIOM-105: UI Flutter ✅ (10 SP)
- BIOM-103: Sync System ✅ (13 SP)
**Total Sprint 2:** 23 SP

### **Dependencias:**
- ✅ Backend C++ debe entregar libvoz_mobile.so compilada (COMPLETADO)
- ✅ Backend debe exponer endpoints REST (COMPLETADO)
- ✅ Modelos SVM pre-entrenados eliminados para generar IDs únicos (COMPLETADO)
- ⏳ Testing en dispositivos físicos Android (arm64-v8a)

### **Riesgos:**
- ⚠️ **Alto:** Incompatibilidad de símbolos OpenMP entre NDK versions → Mitigado con NDK 26
- ⚠️ **Medio:** Threshold muy estricto (99%) rechaza usuarios legítimos → Ajustable por admin
- ⚠️ **Bajo:** Conflictos de sincronización bidireccional → Cola con UUID evita duplicados

---

## 📝 HISTORIA DE USUARIO 1: BIOM-101

### **Título:** Integración FFI con libvoz_mobile.so para autenticación de voz

### **Descripción:**

**Como** desarrollador móvil Flutter  
**Quiero** integrar la librería nativa C++ `libvoz_mobile.so` mediante FFI (Foreign Function Interface)  
**Para** poder ejecutar el registro y autenticación de voz con extracción de 143 MFCCs y clasificación SVM multiclase directamente en el dispositivo sin depender del servidor

### **Prioridad:** 🔴 Alta

### **Story Points:** 8 SP

### **Labels:** 
`Frontend` `Mobile` `Flutter` `FFI` `C++` `Native` `Voice-Biometrics` `Android`

### **Criterios de Aceptación:**

- ✅ La app carga `libvoz_mobile.so` desde `android/app/src/main/jniLibs/arm64-v8a/` sin errores de símbolos
- ✅ FFI bindings declarados en `lib/services/native_voice_service.dart` para todas las funciones:
  - `voz_mobile_init()`
  - `voz_mobile_registrar_biometria()`
  - `voz_mobile_autenticar()`
  - `voz_mobile_usuario_existe()`
  - `voz_mobile_version()`
  - `voz_mobile_cleanup()`
- ✅ Función `initialize()` retorna `true` cuando la librería se carga exitosamente
- ✅ Función `registerBiometric()` acepta `identificador`, `audioPath`, `idFrase` y retorna JSON con:
  - `success: bool`
  - `user_id: int`
  - `features_extracted: int` (debe ser 143)
  - `message: String`
- ✅ Función `authenticate()` acepta `identificador`, `audioPath`, `idFrase` y retorna JSON con:
  - `authenticated: bool`
  - `predicted_class: String`
  - `confidence: double`
  - `all_scores: Map<String, double>`
  - `threshold: double` (0.99)
- ✅ Manejo de errores: si la librería falla al cargar, mostrar mensaje descriptivo en log
- ✅ Conversión correcta entre `String` Dart y `char*` C usando `package:ffi` con `.toNativeUtf8()` y `free()`
- ✅ Assets copiados correctamente en `pubspec.yaml`:
  - `assets/models/v1/metadata.json`
  - Datasets: `caracteristicas_train.dat`, `caracteristicas_test.dat`

### **Tareas Técnicas:**

#### 1. Configurar FFI y dependencias nativas
**Archivos:**
- `pubspec.yaml` (línea 53-54)
- `android/app/build.gradle`
- `android/app/src/main/jniLibs/arm64-v8a/`

**Acciones:**
```yaml
# pubspec.yaml
dependencies:
  ffi: ^2.1.0

# Copiar librerías a jniLibs/
- libvoz_mobile.so (25.85 MB)
- libomp.so (1.15 MB, NDK 26)
- libc++_shared.so (1.74 MB)
```

#### 2. Crear typedefs FFI para todas las funciones nativas
**Archivo:** `lib/services/native_voice_service.dart` (líneas 9-95)

**Código:**
```dart
// Ejemplo: voz_mobile_init
typedef _VozMobileInitNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Char> dbPath,
  ffi.Pointer<ffi.Char> modelPath,
  ffi.Pointer<ffi.Char> datasetPath,
);
typedef _VozMobileInitDart = int Function(
  ffi.Pointer<ffi.Char> dbPath,
  ffi.Pointer<ffi.Char> modelPath,
  ffi.Pointer<ffi.Char> datasetPath,
);
```

#### 3. Implementar carga dinámica de librería
**Archivo:** `lib/services/native_voice_service.dart` (líneas 105-130)

**Código:**
```dart
class NativeVoiceService {
  static ffi.DynamicLibrary? _lib;
  
  Future<bool> initialize() async {
    try {
      _lib = ffi.DynamicLibrary.open('libvoz_mobile.so');
      
      // Cargar funciones
      _vozMobileInit = _lib!.lookupFunction<
        _VozMobileInitNative,
        _VozMobileInitDart
      >('voz_mobile_init');
      
      // Obtener paths de assets
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDir.path}/voz_biometric.db';
      final modelPath = '${appDir.path}/models/v1';
      
      // Inicializar C++
      final result = _callInit(dbPath, modelPath, datasetPath);
      return result == 0;
    } catch (e) {
      print('[FFI] Error: $e');
      return false;
    }
  }
}
```

#### 4. Implementar wrapper de registro biométrico
**Archivo:** `lib/services/native_voice_service.dart` (líneas 200-250)

**Código:**
```dart
Future<Map<String, dynamic>> registerBiometric({
  required String identificador,
  required String audioPath,
  required int idFrase,
}) async {
  final identPtr = identificador.toNativeUtf8();
  final audioPtr = audioPath.toNativeUtf8();
  final resultBuffer = malloc<ffi.Char>(4096);
  
  try {
    final returnCode = _vozMobileRegistrar!(
      identPtr.cast(),
      audioPtr.cast(),
      idFrase,
      resultBuffer.cast(),
      4096,
    );
    
    if (returnCode != 0) {
      throw Exception('Error en registro: código $returnCode');
    }
    
    final jsonStr = resultBuffer.cast<Utf8>().toDartString();
    return jsonDecode(jsonStr);
  } finally {
    malloc.free(identPtr);
    malloc.free(audioPtr);
    malloc.free(resultBuffer);
  }
}
```

#### 5. Implementar wrapper de autenticación
**Archivo:** `lib/services/native_voice_service.dart` (líneas 300-350)

**Código:** Similar a `registerBiometric()` pero llamando `voz_mobile_autenticar`

#### 6. Agregar validación de versión de librería
**Archivo:** `lib/services/native_voice_service.dart` (líneas 150-160)

**Código:**
```dart
String getVersion() {
  final versionPtr = _vozMobileVersion!();
  return versionPtr.cast<Utf8>().toDartString();
}
```

#### 7. Copiar assets de modelos a assets/
**Archivos:**
- `assets/models/v1/metadata.json`
- `assets/models/v1/caracteristicas_train.dat` (~75 MB)
- `assets/models/v1/caracteristicas_test.dat` (~75 MB)

**pubspec.yaml:**
```yaml
flutter:
  assets:
    - assets/models/v1/
```

#### 8. Testing unitario de FFI
**Archivo:** `test/services/native_voice_service_test.dart`

**Tests:**
- `test_library_loads_successfully()`
- `test_version_returns_string()`
- `test_initialize_returns_zero()`
- `test_register_with_valid_audio()`
- `test_authenticate_with_valid_audio()`

### **Definición de Hecho (DoD):**

- ✅ Código commiteado y pusheado a rama `feature/biom-101-ffi-integration`
- ✅ Tests unitarios pasando (coverage >80% en `native_voice_service.dart`)
- ✅ Build APK exitoso sin warnings de símbolos faltantes
- ✅ Probado en dispositivo físico Android (arm64-v8a)
- ✅ Documentación actualizada en `docs/FFI_VOICE_MFCC_NATIVO.md`
- ✅ Code review aprobado por al menos 1 dev senior
- ✅ No hay memory leaks (validado con `malloc.free()` en todos los paths)

### **Notas Técnicas:**

- **NDK Requerido:** Android NDK 26.1.10909125 (para compatibilidad OpenMP)
- **Arquitectura:** Solo arm64-v8a (dispositivos modernos Android)
- **Gestión de Memoria:** Usar `malloc.allocate()` y `malloc.free()` de `package:ffi`
- **Conversión de Strings:** Siempre liberar memoria con `free()` después de `.toNativeUtf8()`
- **Buffer Size:** 4096 bytes para JSONs de respuesta (suficiente para all_scores map)

---

## 📝 HISTORIA DE USUARIO 2: BIOM-102

### **Título:** Sistema de captura de audio con frases dinámicas aleatorias

### **Descripción:**

**Como** usuario móvil  
**Quiero** grabar mi voz diciendo frases aleatorias diferentes en cada intento  
**Para** registrar 6 audios de entrenamiento y autenticarme con validación de texto coincidente

### **Prioridad:** 🔴 Alta

### **Story Points:** 5 SP

### **Labels:**
`Frontend` `Mobile` `Flutter` `Audio` `Voice-Capture` `Permissions`

### **Criterios de Aceptación:**

- ✅ Al seleccionar "Voz" en login/registro, se carga automáticamente una frase aleatoria
- ✅ Frase se obtiene desde:
  1. **Backend** (prioridad): `GET /auth/obtener-frase-aleatoria`
  2. **SQLite local** (fallback): tabla `textos_dinamicos_audio` si offline
  3. **Hardcoded** (último recurso): "Mi voz es mi contraseña"
- ✅ UI muestra la frase en un `Container` destacado con formato:
  - Icono 🎤
  - Texto: "Di la siguiente frase:"
  - Frase en **negrita cursiva** entre comillas
- ✅ Botón circular "Grabar" inicia grabación al presionar
- ✅ Durante grabación:
  - Botón cambia a rojo con texto "Grabando"
  - Icono cambia a `Icons.stop`
  - Usuario puede detener presionando nuevamente
- ✅ Audio grabado en formato **WAV 16kHz mono** (compatible con backend C++)
- ✅ Después de grabar, mostrar:
  - Mensaje "✅ Voz grabada"
  - Botón "Escuchar grabación" para reproducir
- ✅ Validación: audio debe durar **al menos 1 segundo** (1000 bytes mínimo)
- ✅ Permisos de micrófono solicitados automáticamente con mensaje descriptivo
- ✅ En registro: cargar 6 frases **diferentes** para los 6 audios

### **Tareas Técnicas:**

#### 1. Configurar dependencias de audio
**Archivo:** `pubspec.yaml` (líneas 41-43)

**Código:**
```yaml
dependencies:
  flutter_sound: ^9.2.13
  record: ^6.1.2
  permission_handler: ^11.0.1
```

#### 2. Crear AudioService con grabación WAV 16kHz
**Archivo:** `lib/services/audio_service.dart` (líneas 9-200)

**Código:**
```dart
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isInitialized = false;
  
  Future<void> initialize() async {
    await _recorder.hasPermission();
    _isInitialized = true;
  }
  
  Future<void> startRecording() async {
    final hasPermission = await Permission.microphone.request();
    if (!hasPermission.isGranted) {
      throw Exception('Permiso de micrófono denegado');
    }
    
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1, // mono
        bitRate: 128000,
      ),
      path: path,
    );
  }
  
  Future<Uint8List> stopRecording() async {
    final path = await _recorder.stop();
    final file = File(path!);
    final bytes = await file.readAsBytes();
    
    // Validar duración mínima
    if (bytes.length < 1000) {
      throw Exception('Audio muy corto');
    }
    
    return bytes;
  }
  
  Future<bool> get isRecording => _recorder.isRecording();
}
```

#### 3. Implementar carga de frase aleatoria en LoginScreen
**Archivo:** `lib/screens/login_screen.dart` (líneas 272-350)

**Código:**
```dart
String? _currentPhrase;
int? _currentPhraseId;
bool _isLoadingPhrase = false;

Future<void> _loadRandomPhrase() async {
  setState(() {
    _isLoadingPhrase = true;
    _currentPhrase = null;
  });
  
  try {
    final backendService = BiometricBackendService();
    final isOnline = await backendService.isOnline();
    
    if (isOnline) {
      // Prioridad 1: Backend
      final phraseData = await backendService.obtenerFraseAleatoria();
      setState(() {
        _currentPhraseId = phraseData['id_texto'];
        _currentPhrase = phraseData['frase'];
      });
    } else {
      // Fallback: SQLite local
      final localDb = LocalDatabaseService();
      final localPhrase = await localDb.getRandomAudioPhrase(1);
      
      if (localPhrase != null) {
        setState(() {
          _currentPhrase = localPhrase.frase;
          _currentPhraseId = localPhrase.id;
        });
      } else {
        // Último recurso: hardcoded
        setState(() {
          _currentPhrase = 'Mi voz es mi contraseña';
          _currentPhraseId = 1;
        });
      }
    }
  } finally {
    setState(() => _isLoadingPhrase = false);
  }
}
```

#### 4. Diseñar UI para mostrar frase
**Archivo:** `lib/screens/login_screen.dart` (líneas 1020-1060)

**Código:**
```dart
if (_currentPhrase != null)
  Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.blue.shade300, width: 2),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(Icons.record_voice_over, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              'Di la siguiente frase:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(height: 12),
        Text(
          '"$_currentPhrase"',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    ),
  )
```

#### 5. Implementar botón de grabación circular
**Archivo:** `lib/screens/login_screen.dart` (líneas 1062-1110)

**Código:**
```dart
Center(
  child: Container(
    width: 100,
    height: 100,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: _isRecordingNow ? Colors.red.shade100 : Colors.blue.shade100,
      border: Border.all(
        color: _isRecordingNow ? Colors.red : Colors.blue,
        width: 3,
      ),
    ),
    child: InkWell(
      onTap: _recordVoiceForAuth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isRecordingNow ? Icons.stop : Icons.mic,
            size: 40,
            color: _isRecordingNow ? Colors.red : Colors.blue,
          ),
          SizedBox(height: 8),
          Text(_isRecordingNow ? 'Grabando' : 'Grabar'),
        ],
      ),
    ),
  ),
)
```

#### 6. Agregar reproducción de audio grabado
**Archivo:** `lib/services/audio_service.dart` (líneas 180-220)

**Código:**
```dart
import 'package:flutter_sound/flutter_sound.dart';

class AudioService {
  FlutterSoundPlayer? _player;
  
  Future<void> playAudioFromBytes(Uint8List audioBytes) async {
    _player ??= FlutterSoundPlayer();
    await _player!.openPlayer();
    
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/playback.wav');
    await tempFile.writeAsBytes(audioBytes);
    
    await _player!.startPlayer(
      fromURI: tempFile.path,
      codec: Codec.pcm16WAV,
    );
  }
}
```

#### 7. Validar duración mínima de audio
**Archivo:** `lib/screens/login_screen.dart` (líneas 216-240)

**Código:**
```dart
final audioBytes = await _audioService.stopRecording();

// Validación
if (audioBytes.length < 1000) {
  throw Exception('Audio demasiado corto. Graba al menos 1 segundo.');
}

setState(() {
  _recordedAudio = audioBytes;
  _isRecordingNow = false;
});
```

#### 8. Integrar con base de datos local (frases)
**Archivo:** `lib/config/database_config.dart` (líneas 169-189)

**20 Frases predefinidas:**
```dart
final defaultPhrases = [
  'La biometria de voz es una tecnologia innovadora...',
  'Tu voz es tan unica como tu huella digital...',
  // ... (18 frases más)
];

for (int i = 0; i < defaultPhrases.length; i++) {
  await db.insert('textos_dinamicos_audio', {
    'frase': defaultPhrases[i],
    'estado_texto': 'activo',
    'contador_usos': 0,
    'limite_usos': 150,
  });
}
```

### **Definición de Hecho (DoD):**

- ✅ Usuario puede grabar audio en formato WAV 16kHz mono
- ✅ Frase aleatoria se carga desde backend/local/hardcoded (fallback en cascada)
- ✅ Botón de grabación cambia de estado visual correctamente
- ✅ Audio se puede reproducir después de grabar
- ✅ Validación de duración mínima funciona
- ✅ Permisos de micrófono se solicitan automáticamente
- ✅ Tests unitarios para `AudioService` (start, stop, validate duration)
- ✅ Tests de integración en registro con 6 frases diferentes
- ✅ Documentación actualizada en `docs/IMPLEMENTACION_FRASES_VOZ_LOGIN.md`

---

## 📝 HISTORIA DE USUARIO 3: BIOM-103

### **Título:** Sincronización bidireccional offline/online con cola de pendientes

### **Descripción:**

**Como** usuario móvil  
**Quiero** que mis registros y validaciones biométricas se guarden localmente cuando no tengo Internet  
**Para** poder usar la app offline y que los datos se sincronicen automáticamente al recuperar conexión sin perder información

### **Prioridad:** 🟡 Media

### **Story Points:** 13 SP

### **Labels:**
`Backend` `Mobile` `Flutter` `Offline-First` `Sync` `SQLite` `HTTP`

### **Criterios de Aceptación:**

- ✅ Toda operación crítica se guarda primero en SQLite local
- ✅ Cola de sincronización (`cola_sincronizacion` table) almacena operaciones pendientes:
  - `tipo_entidad`: 'usuario', 'credencial_biometrica', 'validacion_biometrica'
  - `operacion`: 'insert', 'update', 'delete'
  - `datos_json`: Payload completo serializado
  - `local_uuid`: UUID único para evitar duplicados
  - `estado`: 'pendiente', 'sincronizado', 'error'
- ✅ Al detectar conexión, `HybridAuthService` ejecuta `syncPendingData()` automáticamente
- ✅ Sincronización con **cooldown de 30 minutos** (no sincronizar cada cambio de red)
- ✅ Rastreo de usuarios sincronizados con `Set<String> _syncedUsers` (no re-sincronizar mismo usuario)
- ✅ Endpoints HTTP:
  - `POST /users/sync` - Sincronizar usuario nuevo
  - `POST /biometric/sync-credentials` - Sincronizar credenciales
  - `POST /biometric/sync-validations` - Sincronizar validaciones
- ✅ Manejo de errores: si sync falla, incrementar `intentos_sync` y marcar `ultimo_error`
- ✅ Retry automático hasta 3 intentos, luego marcar como `error` permanente
- ✅ UI muestra indicador "Sincronizando..." cuando hay operaciones pendientes
- ✅ Validaciones biométricas registran `modo_validacion`: 'online_cloud', 'offline', 'hybrid'

### **Tareas Técnicas:**

#### 1. Crear tabla cola_sincronizacion en SQLite
**Archivo:** `lib/config/database_config.dart` (líneas 110-130)

**Schema SQL:**
```sql
CREATE TABLE cola_sincronizacion (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  id_usuario INTEGER,
  tipo_entidad TEXT NOT NULL,
  operacion TEXT NOT NULL,
  datos_json TEXT,
  local_uuid TEXT UNIQUE,
  estado TEXT DEFAULT 'pendiente',
  fecha_creacion TEXT DEFAULT CURRENT_TIMESTAMP,
  intentos_sync INTEGER DEFAULT 0,
  ultimo_error TEXT,
  FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
);
```

#### 2. Implementar insertToSyncQueue en LocalDatabaseService
**Archivo:** `lib/services/local_database_service.dart` (líneas 450-490)

**Código:**
```dart
Future<void> insertToSyncQueue(
  int idUsuario,
  String tipoEntidad,
  String operacion,
  Map<String, dynamic> datosJson,
) async {
  final db = await database;
  final uuid = Uuid().v4();
  
  await db.insert('cola_sincronizacion', {
    'id_usuario': idUsuario,
    'tipo_entidad': tipoEntidad,
    'operacion': operacion,
    'datos_json': jsonEncode(datosJson),
    'local_uuid': uuid,
    'estado': 'pendiente',
    'fecha_creacion': DateTime.now().toIso8601String(),
  });
  
  print('[LocalDB] ✅ Item encolado para sync: $tipoEntidad ($uuid)');
}
```

#### 3. Crear HybridAuthService con detección de conectividad
**Archivo:** `lib/services/hybrid_auth_service.dart` (líneas 1-100)

**Código:**
```dart
import 'package:connectivity_plus/connectivity_plus.dart';

class HybridAuthService {
  final Connectivity _connectivity = Connectivity();
  DateTime? _lastSyncTime;
  static const Duration _syncCooldown = Duration(minutes: 30);
  final Set<String> _syncedUsers = {};
  
  Future<void> initialize() async {
    // Listener de conectividad
    _connectivity.onConnectivityChanged.listen((result) {
      _onConnectivityChanged(result.first);
    });
  }
  
  void _onConnectivityChanged(ConnectivityResult result) async {
    final isOnline = await _backend.isOnline();
    
    if (isOnline) {
      final now = DateTime.now();
      final shouldSync = _lastSyncTime == null ||
          now.difference(_lastSyncTime!) > _syncCooldown;
      
      if (shouldSync) {
        await syncPendingData();
        _lastSyncTime = now;
      }
    }
  }
}
```

#### 4. Implementar syncPendingData con retry logic
**Archivo:** `lib/services/hybrid_auth_service.dart` (líneas 380-450)

**Código:**
```dart
Future<void> syncPendingData() async {
  print('[HybridAuthService] 🔄 Iniciando sincronización...');
  
  final localDb = LocalDatabaseService();
  final pendingItems = await localDb.getPendingSyncItems();
  
  print('[HybridAuthService] 📦 Items pendientes: ${pendingItems.length}');
  
  for (final item in pendingItems) {
    try {
      // Verificar si usuario ya fue sincronizado
      final identificador = item['identificador'];
      if (_syncedUsers.contains(identificador)) {
        print('[HybridAuthService] ⏭️ Usuario $identificador ya sincronizado');
        continue;
      }
      
      // Sincronizar según tipo
      if (item['tipo_entidad'] == 'usuario') {
        await _syncUser(item);
      } else if (item['tipo_entidad'] == 'credencial_biometrica') {
        await _syncCredential(item);
      } else if (item['tipo_entidad'] == 'validacion_biometrica') {
        await _syncValidation(item);
      }
      
      // Marcar como sincronizado
      await localDb.updateSyncStatus(item['id'], 'sincronizado');
      _syncedUsers.add(identificador);
      
    } catch (e) {
      // Incrementar intentos
      final intentos = (item['intentos_sync'] ?? 0) + 1;
      
      if (intentos >= 3) {
        await localDb.updateSyncStatus(item['id'], 'error', e.toString());
      } else {
        await localDb.incrementSyncAttempts(item['id'], e.toString());
      }
    }
  }
}
```

#### 5. Crear endpoints de sincronización en BackendService
**Archivo:** `lib/services/backend_service.dart` (líneas 200-300)

**Código:**
```dart
Future<Map<String, dynamic>> syncUser(Map<String, dynamic> userData) async {
  final response = await http.post(
    Uri.parse('$baseUrl/users/sync'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(userData),
  );
  
  if (response.statusCode == 200 || response.statusCode == 201) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Error sync user: ${response.statusCode}');
  }
}

Future<void> syncBiometricCredentials(List<Map<String, dynamic>> credentials) async {
  await http.post(
    Uri.parse('$baseUrl/biometric/sync-credentials'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'credentials': credentials}),
  );
}

Future<void> syncValidations(List<Map<String, dynamic>> validations) async {
  await http.post(
    Uri.parse('$baseUrl/biometric/sync-validations'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'validations': validations}),
  );
}
```

#### 6. Agregar indicador visual de sincronización en UI
**Archivo:** `lib/screens/home_screen.dart` (líneas 50-80)

**Código:**
```dart
FutureBuilder<int>(
  future: LocalDatabaseService().getPendingSyncCount(),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data! > 0) {
      return Container(
        padding: EdgeInsets.all(8),
        color: Colors.orange,
        child: Row(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Sincronizando ${snapshot.data} elementos...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }
    return SizedBox.shrink();
  },
)
```

#### 7. Implementar registro de validaciones con modo_validacion
**Archivo:** `lib/services/local_database_service.dart` (líneas 300-330)

**Código:**
```dart
Future<void> insertValidation(BiometricValidation validation) async {
  final db = await database;
  
  await db.insert('validaciones_biometricas', {
    'id_usuario': validation.idUsuario,
    'tipo_biometria': validation.tipoBiometria,
    'resultado': validation.resultado,
    'modo_validacion': validation.modoValidacion, // 'online_cloud', 'offline', 'hybrid'
    'timestamp': validation.timestamp.toIso8601String(),
    'puntuacion_confianza': validation.puntuacionConfianza,
    'duracion_validacion': validation.duracionValidacion,
  });
}
```

#### 8. Testing de sincronización con mock backend
**Archivo:** `test/services/hybrid_auth_service_test.dart`

**Tests:**
- `test_sync_triggers_on_connectivity_change()`
- `test_sync_respects_cooldown()`
- `test_sync_skips_already_synced_users()`
- `test_sync_retries_up_to_3_times()`
- `test_sync_marks_error_after_max_retries()`

### **Definición de Hecho (DoD):**

- ✅ Cola de sincronización funciona correctamente
- ✅ Sincronización se ejecuta automáticamente al recuperar conexión
- ✅ Cooldown de 30 minutos implementado
- ✅ Set de usuarios sincronizados evita duplicados
- ✅ Retry logic con máximo 3 intentos
- ✅ UI muestra indicador de sincronización en progreso
- ✅ Tests de integración con mock backend
- ✅ Documentación actualizada en `docs/GUIA_SINCRONIZACION_REACTIVA.md`
- ✅ No hay memory leaks en listener de conectividad

---

## 📝 HISTORIA DE USUARIO 4: BIOM-104

### **Título:** Base de datos SQLite local con schema compatible PostgreSQL

### **Descripción:**

**Como** desarrollador backend  
**Quiero** que la base de datos SQLite local use el mismo schema que PostgreSQL en la nube  
**Para** garantizar sincronización bidireccional sin conflictos de tipos de datos o constraints

### **Prioridad:** 🔴 Alta

### **Story Points:** 8 SP

### **Labels:**
`Backend` `Mobile` `Database` `SQLite` `PostgreSQL` `Schema`

### **Criterios de Aceptación:**

- ✅ Base de datos SQLite con **versión 12** actualizada
- ✅ 8 tablas principales con esquema compatible PostgreSQL:
  1. `usuarios` - Datos personales + campos de completitud
  2. `credenciales_biometricas` - Templates binarios (oreja/voz)
  3. `validaciones_biometricas` - Auditoría de autenticaciones
  4. `textos_dinamicos_audio` - Frases para voz (20 predefinidas)
  5. `cola_sincronizacion` - Queue de operaciones pendientes
  6. `sincronizaciones` - Historial de syncs por usuario
  7. `sesiones_locales` - Sesiones activas offline
  8. `errores_sync` - Log de errores de sincronización
- ✅ Foreign keys con `ON DELETE CASCADE` correctamente definidas
- ✅ Migraciones versionadas en `_upgradeTables()` (v4 → v5 → v12)
- ✅ Seeds de datos: 20 frases predefinidas insertadas al crear DB
- ✅ Métodos CRUD completos en `LocalDatabaseService`:
  - `getUserByIdentifier()`
  - `insertUser()`
  - `getCredentialsByUserAndType()`
  - `insertCredential()`
  - `insertValidation()`
  - `getRandomAudioPhrase()`
  - `insertToSyncQueue()`
- ✅ Queries optimizadas con índices en:
  - `usuarios.identificador_unico` (UNIQUE)
  - `cola_sincronizacion.local_uuid` (UNIQUE)
  - `validaciones_biometricas.timestamp` (para reportes)

### **Tareas Técnicas:**

#### 1. Definir schema completo en database_config.dart
**Archivo:** `lib/config/database_config.dart` (líneas 30-150)

**Código:**
```dart
Future<void> _createTables(Database db, int version) async {
  // Tabla usuarios
  await db.execute('''
    CREATE TABLE usuarios (
      id_usuario INTEGER PRIMARY KEY AUTOINCREMENT,
      nombres TEXT,
      apellidos TEXT,
      fecha_nacimiento TEXT,
      sexo TEXT,
      identificador_unico TEXT UNIQUE NOT NULL,
      estado TEXT DEFAULT 'activo',
      fecha_registro TEXT,
      datos_completos INTEGER DEFAULT 0,
      orejas_completas INTEGER DEFAULT 0,
      voz_completa INTEGER DEFAULT 0
    )
  ''');
  
  // Tabla credenciales_biometricas
  await db.execute('''
    CREATE TABLE credenciales_biometricas (
      id_credencial INTEGER PRIMARY KEY AUTOINCREMENT,
      id_usuario INTEGER NOT NULL,
      tipo_biometria TEXT NOT NULL,
      template BLOB NOT NULL,
      fecha_registro TEXT,
      estado_credencial TEXT DEFAULT 'activo',
      FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
    )
  ''');
  
  // Tabla validaciones_biometricas
  await db.execute('''
    CREATE TABLE validaciones_biometricas (
      id_validacion INTEGER PRIMARY KEY AUTOINCREMENT,
      id_usuario INTEGER NOT NULL,
      tipo_biometria TEXT NOT NULL,
      resultado TEXT NOT NULL,
      modo_validacion TEXT,
      timestamp TEXT,
      puntuacion_confianza REAL,
      duracion_validacion INTEGER,
      FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
    )
  ''');
  
  // Tabla textos_dinamicos_audio (20 frases)
  await db.execute('''
    CREATE TABLE textos_dinamicos_audio (
      id_texto INTEGER PRIMARY KEY AUTOINCREMENT,
      frase TEXT NOT NULL,
      estado_texto TEXT DEFAULT 'activo',
      contador_usos INTEGER DEFAULT 0,
      limite_usos INTEGER DEFAULT 150,
      fecha_creacion TEXT,
      fecha_ultima_modificacion TEXT
    )
  ''');
  
  // Tabla cola_sincronizacion
  await db.execute('''
    CREATE TABLE cola_sincronizacion (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      id_usuario INTEGER,
      tipo_entidad TEXT NOT NULL,
      operacion TEXT NOT NULL,
      datos_json TEXT,
      local_uuid TEXT UNIQUE,
      estado TEXT DEFAULT 'pendiente',
      fecha_creacion TEXT DEFAULT CURRENT_TIMESTAMP,
      intentos_sync INTEGER DEFAULT 0,
      ultimo_error TEXT,
      FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
    )
  ''');
  
  // ... (otras 3 tablas)
}
```

#### 2. Implementar migraciones versionadas
**Archivo:** `lib/config/database_config.dart` (líneas 210-280)

**Código:**
```dart
Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
  print('🔄 Migrando de v$oldVersion a v$newVersion');
  
  if (oldVersion < 4) {
    // Drop all tables
    await db.execute('DROP TABLE IF EXISTS cola_sincronizacion');
    // ... (drop todas)
    
    // Recrear con nuevo schema
    await _createTables(db, newVersion);
  }
  
  if (oldVersion < 5) {
    // Agregar campos de completitud si no existen
    final tableInfo = await db.rawQuery('PRAGMA table_info(usuarios)');
    final columnNames = tableInfo.map((col) => col['name'] as String).toList();
    
    if (!columnNames.contains('datos_completos')) {
      await db.execute('ALTER TABLE usuarios ADD COLUMN datos_completos INTEGER DEFAULT 0');
    }
    
    if (!columnNames.contains('orejas_completas')) {
      await db.execute('ALTER TABLE usuarios ADD COLUMN orejas_completas INTEGER DEFAULT 0');
    }
    
    if (!columnNames.contains('voz_completa')) {
      await db.execute('ALTER TABLE usuarios ADD COLUMN voz_completa INTEGER DEFAULT 0');
    }
  }
}
```

#### 3. Crear seed de 20 frases predefinidas
**Archivo:** `lib/config/database_config.dart` (líneas 159-189)

**Código:**
```dart
Future<void> _seedDefaultPhrases(Database db) async {
  final count = Sqflite.firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM textos_dinamicos_audio'),
  );
  
  if (count == null || count == 0) {
    final defaultPhrases = [
      'La biometria de voz es una tecnologia innovadora que protege tu identidad de manera unica y segura',
      'Tu voz es tan unica como tu huella digital y representa la mejor forma de autenticacion personal',
      // ... (18 frases más)
    ];
    
    for (int i = 0; i < defaultPhrases.length; i++) {
      await db.insert('textos_dinamicos_audio', {
        'frase': defaultPhrases[i],
        'estado_texto': 'activo',
        'contador_usos': 0,
        'limite_usos': 150,
      });
    }
    
    print('✅ ${defaultPhrases.length} frases insertadas');
  }
}
```

#### 4. Implementar LocalDatabaseService con CRUD
**Archivo:** `lib/services/local_database_service.dart` (líneas 1-600)

**Métodos principales:**
```dart
class LocalDatabaseService {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await DatabaseConfig.initDatabase();
    return _database!;
  }
  
  // USUARIOS
  Future<Map<String, dynamic>?> getUserByIdentifier(String identificador) async {
    final db = await database;
    final results = await db.query(
      'usuarios',
      where: 'identificador_unico = ?',
      whereArgs: [identificador],
    );
    return results.isNotEmpty ? results.first : null;
  }
  
  Future<int> insertUser(Map<String, dynamic> userData) async {
    final db = await database;
    return await db.insert('usuarios', userData);
  }
  
  // CREDENCIALES
  Future<List<BiometricCredential>> getCredentialsByUserAndType(
    int idUsuario,
    String tipoBiometria,
  ) async {
    final db = await database;
    final results = await db.query(
      'credenciales_biometricas',
      where: 'id_usuario = ? AND tipo_biometria = ?',
      whereArgs: [idUsuario, tipoBiometria],
    );
    
    return results.map((row) => BiometricCredential.fromMap(row)).toList();
  }
  
  // VALIDACIONES
  Future<void> insertValidation(BiometricValidation validation) async {
    final db = await database;
    await db.insert('validaciones_biometricas', validation.toMap());
  }
  
  // FRASES ALEATORIAS
  Future<AudioPhrase?> getRandomAudioPhrase(int idUsuario) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT * FROM textos_dinamicos_audio
      WHERE estado_texto = 'activo'
      ORDER BY RANDOM()
      LIMIT 1
    ''');
    
    return results.isNotEmpty ? AudioPhrase.fromMap(results.first) : null;
  }
}
```

#### 5. Crear modelos de datos compatibles
**Archivo:** `lib/models/biometric_models.dart` (líneas 1-150)

**Código:**
```dart
class BiometricCredential {
  final int id;
  final int idUsuario;
  final String tipoBiometria;
  final Uint8List template;
  final DateTime fechaRegistro;
  
  BiometricCredential({
    required this.id,
    required this.idUsuario,
    required this.tipoBiometria,
    required this.template,
    required this.fechaRegistro,
  });
  
  factory BiometricCredential.fromMap(Map<String, dynamic> map) {
    return BiometricCredential(
      id: map['id_credencial'],
      idUsuario: map['id_usuario'],
      tipoBiometria: map['tipo_biometria'],
      template: map['template'],
      fechaRegistro: DateTime.parse(map['fecha_registro']),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'tipo_biometria': tipoBiometria,
      'template': template,
      'fecha_registro': fechaRegistro.toIso8601String(),
    };
  }
}

class BiometricValidation {
  final int id;
  final int idUsuario;
  final String tipoBiometria;
  final String resultado;
  final String modoValidacion;
  final DateTime timestamp;
  final double puntuacionConfianza;
  final int duracionValidacion;
  
  // Similar constructor, fromMap, toMap
}
```

#### 6. Testing de migraciones
**Archivo:** `test/config/database_config_test.dart`

**Tests:**
- `test_database_creates_all_tables()`
- `test_migration_v4_to_v12()`
- `test_seed_phrases_inserts_20_items()`
- `test_foreign_keys_cascade_delete()`

### **Definición de Hecho (DoD):**

- ✅ Base de datos SQLite v12 creada correctamente
- ✅ 8 tablas con schema PostgreSQL compatible
- ✅ Migraciones funcionan sin pérdida de datos
- ✅ 20 frases predefinidas insertadas automáticamente
- ✅ CRUD completo implementado en LocalDatabaseService
- ✅ Tests unitarios para todas las operaciones CRUD
- ✅ Foreign keys validadas con cascade delete
- ✅ Documentación actualizada en `docs/DB_SYNC_MAPPING.md`

---

## 📝 HISTORIA DE USUARIO 5: BIOM-105

### **Título:** UI Flutter con flujo de registro multi-paso y login biométrico

### **Descripción:**

**Como** usuario móvil  
**Quiero** registrarme en 3 pasos claros (datos personales, 7 fotos oreja, 6 audios voz)  
**Para** completar mi perfil biométrico de forma guiada y luego autenticarme con oreja O voz

### **Prioridad:** 🟡 Media

### **Story Points:** 10 SP

### **Labels:**
`Frontend` `Mobile` `Flutter` `UI/UX` `Forms` `Camera` `Audio`

### **Criterios de Aceptación:**

- ✅ **RegisterScreen** con 3 pasos usando `PageView`:
  - **Paso 1:** Formulario datos personales (nombres, apellidos, fecha nacimiento, sexo, cédula)
  - **Paso 2:** Captura de 7 fotos de oreja con preview y validación TFLite
  - **Paso 3:** Grabación de 6 audios de voz con frases diferentes
- ✅ Indicador de progreso visual (1/3, 2/3, 3/3)
- ✅ Botones "Siguiente" / "Anterior" para navegación
- ✅ Validación reactiva de campos (no permite siguiente si incompleto)
- ✅ Botón "Finalizar Registro" envía todo al backend/local según conectividad
- ✅ **LoginScreen** con toggle "Contraseña" / "Biometría"
- ✅ Si selecciona "Biometría", mostrar chips "Oreja" | "Voz"
- ✅ Captura de foto/audio según selección
- ✅ Botón "Autenticarse" ejecuta validación híbrida (cloud-first → local fallback)
- ✅ Mensajes de error descriptivos (ej: "Oreja no válida", "Audio muy corto", "Usuario no encontrado")
- ✅ **HomeScreen** muestra menú post-login con opciones:
  - Ver perfil
  - Historial de validaciones
  - Cerrar sesión
- ✅ Logo de la app en todas las pantallas (AppLogo widget)

### **Tareas Técnicas:**

#### 1. Crear RegisterScreen con PageView
**Archivo:** `lib/screens/register_screen.dart` (líneas 1-1200)

**Código:**
```dart
class RegisterScreen extends StatefulWidget {
  final String? identificadorInicial;
  final int pasoInicial;
  
  RegisterScreen({this.identificadorInicial, this.pasoInicial = 0});
  
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  
  // Controladores de formulario
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _cedulaController = TextEditingController();
  
  // Datos capturados
  List<Uint8List> _capturedEarPhotos = [];
  List<Uint8List> _recordedAudios = [];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registro ($_currentStep + 1)/3'),
      ),
      body: PageView(
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(),
        children: [
          _buildStep1PersonalData(),
          _buildStep2EarPhotos(),
          _buildStep3VoiceAudios(),
        ],
      ),
      bottomNavigationBar: _buildNavigationButtons(),
    );
  }
  
  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 0)
          ElevatedButton(
            onPressed: () {
              _pageController.previousPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              setState(() => _currentStep--);
            },
            child: Text('Anterior'),
          ),
        Spacer(),
        ElevatedButton(
          onPressed: _canProceed() ? _handleNext : null,
          child: Text(_currentStep == 2 ? 'Finalizar' : 'Siguiente'),
        ),
      ],
    );
  }
  
  bool _canProceed() {
    if (_currentStep == 0) {
      return _nombresController.text.isNotEmpty &&
             _apellidosController.text.isNotEmpty &&
             _cedulaController.text.length >= 10;
    } else if (_currentStep == 1) {
      return _capturedEarPhotos.length == 7;
    } else {
      return _recordedAudios.length == 6;
    }
  }
}
```

#### 2. Implementar Paso 1: Formulario datos personales
**Archivo:** `lib/screens/register_screen.dart` (líneas 200-350)

**Código:**
```dart
Widget _buildStep1PersonalData() {
  return SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        TextField(
          controller: _nombresController,
          decoration: InputDecoration(
            labelText: 'Nombres *',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _apellidosController,
          decoration: InputDecoration(
            labelText: 'Apellidos *',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _cedulaController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Cédula / Identificador *',
            border: OutlineInputBorder(),
          ),
        ),
        // ... fecha nacimiento, sexo
      ],
    ),
  );
}
```

#### 3. Implementar Paso 2: Captura 7 fotos oreja
**Archivo:** `lib/screens/register_screen.dart` (líneas 400-600)

**Código:**
```dart
Widget _buildStep2EarPhotos() {
  return Column(
    children: [
      Text('Captura 7 fotos de tu oreja (${_capturedEarPhotos.length}/7)'),
      SizedBox(height: 16),
      
      // Grid de fotos capturadas
      Expanded(
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _capturedEarPhotos.length,
          itemBuilder: (context, index) {
            return Stack(
              children: [
                Image.memory(_capturedEarPhotos[index], fit: BoxFit.cover),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() => _capturedEarPhotos.removeAt(index));
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      
      // Botón capturar nueva foto
      if (_capturedEarPhotos.length < 7)
        ElevatedButton.icon(
          onPressed: _captureEarPhoto,
          icon: Icon(Icons.camera),
          label: Text('Capturar Foto ${_capturedEarPhotos.length + 1}'),
        ),
    ],
  );
}

Future<void> _captureEarPhoto() async {
  final photoBytes = await Navigator.of(context).push<Uint8List?>(
    MaterialPageRoute(builder: (_) => CameraCaptureScreen()),
  );
  
  if (photoBytes != null) {
    // Validar con TFLite
    final validationResult = await _earValidator.validateEar(photoBytes);
    
    if (validationResult.isValid) {
      setState(() => _capturedEarPhotos.add(photoBytes));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ No es una oreja válida')),
      );
    }
  }
}
```

#### 4. Implementar Paso 3: Grabación 6 audios voz
**Archivo:** `lib/screens/register_screen.dart` (líneas 700-900)

**Código:**
```dart
Widget _buildStep3VoiceAudios() {
  return Column(
    children: [
      Text('Graba 6 audios de voz (${_recordedAudios.length}/6)'),
      
      // Frase actual
      if (_currentPhrase != null)
        Container(
          padding: EdgeInsets.all(16),
          child: Text(
            '"$_currentPhrase"',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      
      // Botón grabar
      if (_recordedAudios.length < 6)
        ElevatedButton.icon(
          onPressed: _recordVoiceForRegistration,
          icon: Icon(_isRecording ? Icons.stop : Icons.mic),
          label: Text(_isRecording ? 'Detener' : 'Grabar Audio ${_recordedAudios.length + 1}'),
        ),
      
      // Lista de audios grabados
      Expanded(
        child: ListView.builder(
          itemCount: _recordedAudios.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: Icon(Icons.audiotrack),
              title: Text('Audio ${index + 1}'),
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() => _recordedAudios.removeAt(index));
                },
              ),
            );
          },
        ),
      ),
    ],
  );
}
```

#### 5. Crear LoginScreen con toggle biometría
**Archivo:** `lib/screens/login_screen.dart` (líneas 1-1100)

**Código:**
```dart
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _usingBiometrics = true;
  int _selectedBiometricType = 1; // 1: Oreja, 2: Voz
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Column(
        children: [
          // Logo
          AppLogo(size: 100, showText: true),
          
          // Toggle Contraseña/Biometría
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text('Contraseña')),
              ButtonSegment(value: true, label: Text('Biometría')),
            ],
            selected: {_usingBiometrics},
            onSelectionChanged: (selected) {
              setState(() => _usingBiometrics = selected.first);
            },
          ),
          
          if (_usingBiometrics) ...[
            // Chips Oreja/Voz
            Row(
              children: [
                ChoiceChip(
                  label: Text('Oreja'),
                  selected: _selectedBiometricType == 1,
                  onSelected: (_) => setState(() => _selectedBiometricType = 1),
                ),
                ChoiceChip(
                  label: Text('Voz'),
                  selected: _selectedBiometricType == 2,
                  onSelected: (_) {
                    setState(() => _selectedBiometricType = 2);
                    _loadRandomPhrase();
                  },
                ),
              ],
            ),
            
            // Captura según tipo
            if (_selectedBiometricType == 1)
              _buildEarCapture()
            else
              _buildVoiceCapture(),
          ] else
            _buildPasswordForm(),
          
          // Botón autenticar
          ElevatedButton(
            onPressed: _performAuth,
            child: Text('Autenticarse'),
          ),
        ],
      ),
    );
  }
}
```

#### 6. Crear HomeScreen con menú post-login
**Archivo:** `lib/screens/home_screen.dart` (líneas 1-200)

**Código:**
```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menú Principal'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        children: [
          _buildMenuCard(
            icon: Icons.person,
            title: 'Mi Perfil',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ProfileScreen(),
            )),
          ),
          _buildMenuCard(
            icon: Icons.history,
            title: 'Historial',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ValidationHistoryScreen(),
            )),
          ),
          // Más opciones...
        ],
      ),
    );
  }
  
  Widget _buildMenuCard({required IconData icon, required String title, required VoidCallback onTap}) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64),
            SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
```

#### 7. Crear AppLogo widget reutilizable
**Archivo:** `lib/widgets/app_logo.dart` (líneas 1-50)

**Código:**
```dart
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  
  const AppLogo({this.size = 80, this.showText = false});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
            ),
          ),
          child: Icon(Icons.fingerprint, size: size * 0.6, color: Colors.white),
        ),
        if (showText) ...[
          SizedBox(height: 8),
          Text(
            'Sistema Biométrico',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }
}
```

#### 8. Testing de UI
**Archivo:** `test/screens/register_screen_test.dart`

**Tests:**
- `test_navigation_between_steps()`
- `test_next_button_disabled_if_incomplete()`
- `test_ear_photos_validation_with_tflite()`
- `test_voice_audios_load_different_phrases()`
- `test_final_registration_sends_to_backend()`

### **Definición de Hecho (DoD):**

- ✅ RegisterScreen con 3 pasos funcionales
- ✅ LoginScreen con toggle biometría/contraseña
- ✅ HomeScreen con menú post-login
- ✅ Validación reactiva de campos
- ✅ Navegación entre pasos sin bugs
- ✅ UI responsiva en diferentes tamaños de pantalla
- ✅ Tests de widgets para todos los screens
- ✅ Documentación actualizada en `docs/ESTRUCTURA_VISUAL.md`

---

## 📊 Resumen del EPIC

| Historia | Título | Story Points | Prioridad | Estado |
|----------|--------|--------------|-----------|--------|
| BIOM-101 | Integración FFI libvoz_mobile.so | 8 SP | 🔴 Alta | ✅ Completado |
| BIOM-102 | Sistema captura audio con frases | 5 SP | 🔴 Alta | ✅ Completado |
| BIOM-103 | Sincronización bidireccional | 13 SP | 🟡 Media | ✅ Completado |
| BIOM-104 | SQLite con PostgreSQL schema | 8 SP | 🔴 Alta | ✅ Completado |
| BIOM-105 | UI Flutter registro y login | 10 SP | 🟡 Media | ✅ Completado |
| **TOTAL** | | **44 SP** | | **100%** |

---

## 🎯 Criterios de Aceptación del EPIC

### Funcionales
- ✅ Usuario puede registrarse 100% offline
- ✅ Usuario puede autenticarse con oreja O voz offline
- ✅ Sistema prioriza cloud-first cuando hay conexión
- ✅ Cola de sincronización procesa pendientes automáticamente
- ✅ Frases aleatorias se cargan desde backend/local/hardcoded

### Técnicos
- ✅ FFI carga libvoz_mobile.so sin errores
- ✅ Audio en WAV 16kHz mono compatible con backend
- ✅ Imágenes recortadas a 224x224 para TFLite
- ✅ Threshold configurable (actual: 99%)
- ✅ Base de datos SQLite v12 con PostgreSQL schema

### No Funcionales
- ✅ Respuesta de autenticación < 3 segundos (offline)
- ✅ Sin memory leaks en FFI bindings
- ✅ Coverage de tests > 80% en servicios críticos
- ✅ App funciona sin crashear en dispositivos Android 8+

---

## 📦 Entregables

1. **Código Fuente:**
   - `lib/services/native_voice_service.dart` (FFI bindings)
   - `lib/services/audio_service.dart` (captura audio)
   - `lib/services/hybrid_auth_service.dart` (sincronización)
   - `lib/config/database_config.dart` (SQLite schema)
   - `lib/screens/register_screen.dart` (UI registro)
   - `lib/screens/login_screen.dart` (UI login)

2. **Assets:**
   - `android/app/src/main/jniLibs/arm64-v8a/libvoz_mobile.so` (25.85 MB)
   - `android/app/src/main/jniLibs/arm64-v8a/libomp.so` (1.15 MB)
   - `android/app/src/main/jniLibs/arm64-v8a/libc++_shared.so` (1.74 MB)
   - `assets/models/v1/metadata.json`

3. **Documentación:**
   - `docs/FFI_VOICE_MFCC_NATIVO.md`
   - `docs/IMPLEMENTACION_FRASES_VOZ_LOGIN.md`
   - `docs/GUIA_SINCRONIZACION_REACTIVA.md`
   - `docs/DB_SYNC_MAPPING.md`
   - `docs/ESTRUCTURA_VISUAL.md`

4. **Tests:**
   - Tests unitarios (>80% coverage)
   - Tests de integración para sync
   - Tests de widgets para UI

---

## 🚀 Deployment

**APK Generado:**
```bash
flutter build apk --release
```

**Ubicación:**
```
build/app/outputs/flutter-apk/app-release.apk
```

**Instalación en dispositivo:**
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

**Generado por:** Equipo Móvil Flutter  
**Fecha:** 24 de Enero de 2026  
**Versión:** 1.0.0  
**Epic ID:** BIOM-001
