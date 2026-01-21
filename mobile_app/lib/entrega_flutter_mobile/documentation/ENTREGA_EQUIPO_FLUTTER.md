# Entrega: Libreria Nativa para App Flutter

**Proyecto:** Sistema Biometrico Multimodal - Modulo Movil  
**Fecha:** 19 de enero de 2026  
**Version:** 1.0.0-mobile  
**Para:** Equipo de Desarrollo Flutter

---

## Resumen Ejecutivo

Se ha compilado exitosamente la libreria nativa `libvoz_mobile.so` que permite integrar el sistema biometrico de voz directamente en la app Flutter mediante FFI (Foreign Function Interface).

**Ventajas de esta arquitectura:**
- ✅ Funcionamiento 100% offline (sin servidor HTTP local)
- ✅ Menor consumo de bateria
- ✅ Mayor seguridad (datos nunca salen del dispositivo)
- ✅ Rendimiento nativo C++ optimizado
- ✅ Sincronizacion automatica cuando hay internet

---

## Archivos a Entregar

### 1. Librerias Compiladas

```
📦 Archivos Binarios (Android arm64-v8a)
├── libvoz_mobile.so         [25.89 MB] - Libreria principal FFI
└── libsqlite3_local.a       [1.5 MB]   - SQLite embebido (ya incluido en .so)
```

**Ubicacion Backend:**
```
D:\server\biometria_voz\build-android-arm64-v8a\voz\
├── libvoz_mobile.so         ← COPIAR A FLUTTER
└── libsqlite3_local.a       ← (opcional, ya incluido)
```

**Ubicacion Flutter:**
```
tu-proyecto-flutter/
└── android/app/src/main/jniLibs/arm64-v8a/
    └── libvoz_mobile.so
```

---

### 2. Modelos SVM y Datasets Pre-entrenados

**CRITICO:** La libreria necesita estos archivos para funcionar:

```
📦 Modelos y Características (obligatorios)
├── models/v1/                    [~25 MB total]
│   ├── class_*.bin              [68 archivos] - Pesos SVM por clase
│   └── metadata.json            - Metadatos del modelo
│
└── caracteristicas/v1/          [~150 MB total]
    ├── caracteristicas_train.dat - Dataset MFCC de entrenamiento
    └── caracteristicas_test.dat  - Dataset MFCC de validacion
```

**Ubicacion Backend:**
```
D:\server\biometria_voz\
├── models/v1/
│   ├── class_10013.bin, class_101.bin, ... (68 archivos)
│   └── metadata.json
└── caracteristicas/v1/
    ├── caracteristicas_train.dat
    └── caracteristicas_test.dat
```

**Ubicacion Flutter (Android Assets):**
```
tu-proyecto-flutter/
└── android/app/src/main/assets/
    ├── models/v1/
    │   ├── class_*.bin (68 archivos)
    │   └── metadata.json
    └── caracteristicas/v1/
        ├── caracteristicas_train.dat
        └── caracteristicas_test.dat
```

**Script de Copia Automatica:**
```bash
# Crear directorios en Flutter
cd /ruta/tu-proyecto-flutter
mkdir -p android/app/src/main/assets/models/v1
mkdir -p android/app/src/main/assets/caracteristicas/v1

# Copiar modelos
cp D:/server/biometria_voz/models/v1/* android/app/src/main/assets/models/v1/

# Copiar características
cp D:/server/biometria_voz/caracteristicas/v1/* android/app/src/main/assets/caracteristicas/v1/

# Copiar librería
mkdir -p android/app/src/main/jniLibs/arm64-v8a
cp D:/server/biometria_voz/build-android-arm64-v8a/voz/libvoz_mobile.so android/app/src/main/jniLibs/arm64-v8a/
```

**Acceso en Runtime:**
```dart
// Obtener ruta de assets en Flutter
String modelsPath = await getApplicationDocumentsDirectory().then(
  (dir) => '${dir.path}/models/v1'
);
String datasetPath = await getApplicationDocumentsDirectory().then(
  (dir) => '${dir.path}/caracteristicas/v1'
);

// Inicializar librería con rutas correctas
VozMobile.instance.initialize(
  dbPath: dbPath,
  modelPath: modelsPath,
  datasetPath: datasetPath,
);
```

**Notas Importantes:**
- ⚠️ Tamaño total de assets: ~175 MB (considerar al publicar en Play Store)
- ⚠️ Los archivos `class_*.bin` son pesos del SVM entrenado con 68 usuarios
- ⚠️ `metadata.json` contiene parámetros críticos (C, kernel, gamma)
- ⚠️ Características `.dat` son archivos binarios con vectores MFCC

---

### 3. Headers C (Interfaz FFI)

```
📄 Headers
└── mobile_api.h             [5 KB]    - API C para FFI con 20+ funciones
```

**Ubicacion:**
```
D:\server\biometria_voz\voz\apps\mobile\mobile_api.h
```

**Contiene:**
- Declaraciones de funciones exportadas
- Estructuras de datos
- Documentacion de parametros

---

### 3. Modelo Whisper (ASR - Reconocimiento de Voz)

```
📦 Modelo de IA
└── ggml-tiny.bin            [75 MB]   - Modelo Whisper Tiny para ASR
```

**Ubicacion:**
```
D:\server\biometria_voz\build-android-arm64-v8a\voz\ggml-tiny.bin
```

**Copiar a Flutter:**
```bash
# Debe ir en assets de la app
cp ggml-tiny.bin /tu-proyecto-flutter/assets/models/ggml-tiny.bin
```

**Configurar en `pubspec.yaml`:**
```yaml
flutter:
  assets:
    - assets/models/ggml-tiny.bin
```

---

### 4. Documentacion

```
📚 Documentacion Completa
├── INTEGRACION_FLUTTER_FFI.md           [69 KB] - Guia de integracion FFI
├── SINCRONIZACION_OFFLINE_ONLINE.md     [24 KB] - Estrategia de sync
└── ENTREGA_EQUIPO_FLUTTER.md            [este]  - Instrucciones de entrega
```

---

## Arquitectura de la Libreria

### Diagrama General

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER APP (Dart)                       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  lib/bindings/voz_mobile.dart                         │  │
│  │  • VozMobile.instance.initialize()                    │  │
│  │  • registrarBiometria()                               │  │
│  │  • autenticar()                                       │  │
│  │  • sincronizarConServidor()                           │  │
│  └───────────────────────────────────────────────────────┘  │
│              ↕ FFI (dart:ffi)                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  libvoz_mobile.so (C++ Nativo)                        │  │
│  │  ├─ mobile_api.cpp      (20+ funciones exportadas)   │  │
│  │  ├─ sqlite_adapter.cpp  (Base de datos local)        │  │
│  │  ├─ audio_pipeline.cpp  (Procesamiento de audio)     │  │
│  │  ├─ svm_core.cpp        (Clasificacion biometrica)   │  │
│  │  └─ whisper_asr.cpp     (Reconocimiento de voz)      │  │
│  └───────────────────────────────────────────────────────┘  │
│              ↓                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  SQLite Local (biometria.db)                          │  │
│  │  ├─ usuarios                                          │  │
│  │  ├─ credenciales_biometricas                          │  │
│  │  ├─ frases_dinamicas                                  │  │
│  │  ├─ validaciones_biometricas                          │  │
│  │  └─ cola_sincronizacion ← NUEVA TABLA                │  │
│  └───────────────────────────────────────────────────────┘  │
│              ↓                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Archivos Locales                                     │  │
│  │  ├─ models/v2/metadata.json                           │  │
│  │  ├─ models/v2/class_*.bin (modelos SVM)               │  │
│  │  ├─ dataset/train_data.bin (datos de entrenamiento)   │  │
│  │  └─ assets/models/ggml-tiny.bin (Whisper)             │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↕
          ┌────────────────────────────────┐
          │  SINCRONIZACION                │
          │  • Detectar WiFi/4G            │
          │  • Enviar cola_sincronizacion  │
          │  • Descargar modelo actualizado│
          └────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│                   SERVIDOR BACKEND                          │
│  • PostgreSQL (via PostgREST)                               │
│  • Modelo SVM global                                        │
│  • Endpoints /sync/*                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## API Nativa Exportada

### Lista Completa de Funciones (mobile_api.h)

#### 1. Inicializacion y Configuracion

```c
// Inicializar la libreria (LLAMAR PRIMERO)
int voz_mobile_init(const char* db_path, 
                    const char* model_path,
                    const char* dataset_path);

// Liberar recursos
void voz_mobile_cleanup();

// Obtener version de la libreria
const char* voz_mobile_version();
```

**Ejemplo en Dart:**
```dart
import 'package:path_provider/path_provider.dart';

Future<bool> inicializarLibreria() async {
  // Obtener directorio de la app
  final appDir = await getApplicationDocumentsDirectory();
  
  // Rutas de archivos
  final dbPath = '${appDir.path}/biometria.db';
  final modelPath = '${appDir.path}/models/v1';  // Contiene class_*.bin
  final datasetPath = '${appDir.path}/caracteristicas/v1'; // Contiene .dat
  
  // IMPORTANTE: Copiar assets a directorio de la app en primer inicio
  await _copiarAssetsEnPrimeraEjecucion(appDir.path);
  
  // Inicializar librería
  final result = VozMobile.instance.initialize(
    dbPath: dbPath,
    modelPath: modelPath,
    datasetPath: datasetPath,
  );
  
  return result == 0;
}

// Copiar modelos y características desde assets a directorio de app
Future<void> _copiarAssetsEnPrimeraEjecucion(String appPath) async {
  final prefs = await SharedPreferences.getInstance();
  final yaCopiado = prefs.getBool('assets_copiados') ?? false;
  
  if (!yaCopiado) {
    print('-> Copiando modelos SVM y datasets...');
    
    // Crear directorios
    await Directory('$appPath/models/v1').create(recursive: true);
    await Directory('$appPath/caracteristicas/v1').create(recursive: true);
    
    // Copiar 68 archivos class_*.bin
    final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final modelFiles = assetManifest
        .listAssets()
        .where((key) => key.startsWith('assets/models/v1/'))
        .toList();
    
    for (final assetPath in modelFiles) {
      final fileName = assetPath.split('/').last;
      final data = await rootBundle.load(assetPath);
      final file = File('$appPath/models/v1/$fileName');
      await file.writeAsBytes(data.buffer.asUint8List());
    }
    
    // Copiar datasets
    await _copiarAsset('assets/caracteristicas/v1/caracteristicas_train.dat',
                       '$appPath/caracteristicas/v1/caracteristicas_train.dat');
    await _copiarAsset('assets/caracteristicas/v1/caracteristicas_test.dat',
                       '$appPath/caracteristicas/v1/caracteristicas_test.dat');
    
    await prefs.setBool('assets_copiados', true);
    print('-> Modelos y datasets copiados correctamente');
  }
}

Future<void> _copiarAsset(String assetPath, String targetPath) async {
  final data = await rootBundle.load(assetPath);
  final file = File(targetPath);
  await file.writeAsBytes(data.buffer.asUint8List());
}
```

**Que Hace `voz_mobile_init()`:**
1. Conecta a la base de datos SQLite (crea tablas si no existen)
2. Carga el modelo SVM desde `model_path/class_*.bin` (68 archivos)
3. Carga metadata desde `model_path/metadata.json`
4. Prepara el dataset de características desde `dataset_path/*.dat`
5. Configura rutas para guardar nuevas biometrías

**Parámetros:**
- `db_path`: Ruta completa a `biometria.db` (se crea si no existe)
- `model_path`: Directorio con archivos `class_*.bin` y `metadata.json`
- `dataset_path`: Directorio con `caracteristicas_train.dat` y `caracteristicas_test.dat`

**Retorna:**
- `0`: Inicialización exitosa
- `-1`: Error (llamar `voz_mobile_get_last_error()` para detalles)

**Errores Comunes:**
```
Error: "Modelo SVM no encontrado en /path/models/v1"
→ Verificar que existen los 68 archivos class_*.bin

Error: "Dataset no encontrado en /path/caracteristicas/v1"
→ Verificar que existen caracteristicas_train.dat y caracteristicas_test.dat

Error: "No se pudo conectar a base de datos"
→ Verificar permisos de escritura en directorio de la app
```

---

#### 2. Gestion de Usuarios

```c
// Obtener ID de usuario por identificador (cedula)
int voz_mobile_obtener_id_usuario(const char* identificador);

// Crear nuevo usuario
int voz_mobile_crear_usuario(const char* identificador);

// Verificar si usuario existe
int voz_mobile_usuario_existe(const char* identificador);
```

**Ejemplo en Dart:**
```dart
int getUserId(String cedula) {
  final cedulaPtr = cedula.toNativeUtf8().cast<Int8>();
  final userId = _vozMobileObtenerIdUsuario(cedulaPtr);
  malloc.free(cedulaPtr);
  return userId; // Retorna -1 si no existe
}
```

---

#### 3. Frases Dinamicas

```c
// Obtener frase aleatoria (retorna id_frase)
int voz_mobile_obtener_frase_aleatoria(char* buffer, size_t buffer_size);

// Obtener frase especifica por ID
int voz_mobile_obtener_frase_por_id(int id_frase, char* buffer, size_t buffer_size);

// Insertar multiples frases desde JSON
int voz_mobile_insertar_frases(const char* frases_json);
```

**Ejemplo en Dart:**
```dart
String obtenerFraseAleatoria() {
  final buffer = calloc<Int8>(512);
  final idFrase = _vozMobileObtenerFraseAleatoria(buffer, 512);
  
  final frase = buffer.cast<Utf8>().toDartString();
  calloc.free(buffer);
  
  return frase; // Ej: "el cielo esta azul hoy"
}
```

---

#### 4. Registro Biometrico (PRINCIPAL)

```c
// Registrar nueva biometria de voz
int voz_mobile_registrar_biometria(const char* identificador,
                                    const char* audio_path,
                                    int id_frase,
                                    char* resultado_json,
                                    size_t buffer_size);
```

**Que hace internamente:**
1. Verifica si usuario existe, si no lo crea
2. Carga y procesa el audio (normalizacion, VAD, denoise)
3. Extrae caracteristicas MFCC (143 dimensiones)
4. Usa Whisper para verificar que la frase es correcta
5. Entrena/actualiza modelo SVM
6. Guarda en SQLite y encola para sincronizacion
7. Retorna JSON con resultado

**Ejemplo en Dart:**
```dart
Map<String, dynamic> registrarBiometria({
  required String cedula,
  required String audioPath,
  required int idFrase,
}) {
  final cedulaPtr = cedula.toNativeUtf8().cast<Int8>();
  final audioPtr = audioPath.toNativeUtf8().cast<Int8>();
  final bufferResultado = calloc<Int8>(2048);
  
  final result = _vozMobileRegistrarBiometria(
    cedulaPtr,
    audioPtr,
    idFrase,
    bufferResultado,
    2048,
  );
  
  final jsonString = bufferResultado.cast<Utf8>().toDartString();
  
  malloc.free(cedulaPtr);
  malloc.free(audioPtr);
  calloc.free(bufferResultado);
  
  if (result == 0) {
    return json.decode(jsonString);
    // {
    //   "success": true,
    //   "user_id": 5,
    //   "credential_id": 12,
    //   "confidence": 1.0,
    //   "message": "Registro exitoso"
    // }
  } else {
    return {"success": false, "error": "Fallo registro"};
  }
}
```

---

#### 5. Autenticacion Biometrica (PRINCIPAL)

```c
// Autenticar usuario por voz
int voz_mobile_autenticar(const char* identificador,
                          const char* audio_path,
                          int id_frase,
                          char* resultado_json,
                          size_t buffer_size);
```

**Que hace internamente:**
1. Verifica que el usuario existe
2. Procesa el audio igual que en registro
3. Usa Whisper para verificar frase correcta
4. Compara con modelo SVM entrenado
5. Calcula confianza de autenticacion
6. Registra en validaciones_biometricas
7. Encola para sincronizacion

**Ejemplo en Dart:**
```dart
Map<String, dynamic> autenticar({
  required String cedula,
  required String audioPath,
  required int idFrase,
}) {
  final cedulaPtr = cedula.toNativeUtf8().cast<Int8>();
  final audioPtr = audioPath.toNativeUtf8().cast<Int8>();
  final bufferResultado = calloc<Int8>(2048);
  
  final result = _vozMobileAutenticar(
    cedulaPtr,
    audioPtr,
    idFrase,
    bufferResultado,
    2048,
  );
  
  final jsonString = bufferResultado.cast<Utf8>().toDartString();
  
  malloc.free(cedulaPtr);
  malloc.free(audioPtr);
  calloc.free(bufferResultado);
  
  if (result == 0) {
    return json.decode(jsonString);
    // {
    //   "success": true,
    //   "authenticated": true,
    //   "user_id": 5,
    //   "confidence": 0.92,
    //   "message": "Autenticacion exitosa"
    // }
  } else {
    return {"success": false, "authenticated": false};
  }
}
```

---

#### 6. Sincronizacion con Servidor

```c
// Obtener registros pendientes de sincronizacion
int voz_mobile_obtener_cola_sincronizacion(char* cola_json, size_t buffer_size);

// Marcar registro como sincronizado
int voz_mobile_marcar_sincronizado(int id_sync);

// Exportar modelo SVM a buffer binario
int voz_mobile_exportar_modelo(uint8_t* buffer, size_t* buffer_size);

// Importar modelo SVM desde buffer binario
int voz_mobile_importar_modelo(const uint8_t* buffer, size_t buffer_size);

// Exportar dataset a buffer binario
int voz_mobile_exportar_dataset(uint8_t* buffer, size_t* buffer_size);

// Importar dataset desde buffer binario
int voz_mobile_importar_dataset(const uint8_t* buffer, size_t buffer_size);
```

**Ejemplo de Sincronizacion en Dart:**
```dart
Future<void> sincronizarConServidor() async {
  // 1. Obtener cola de sincronizacion
  final buffer = calloc<Int8>(10240);
  _vozMobileObtenerColaSincronizacion(buffer, 10240);
  
  final colaJson = buffer.cast<Utf8>().toDartString();
  calloc.free(buffer);
  
  final cola = json.decode(colaJson) as List;
  
  // 2. Enviar cada item al servidor
  for (var item in cola) {
    try {
      await enviarAlServidor(item);
      
      // 3. Marcar como sincronizado
      _vozMobileMarcarSincronizado(item['id_sync']);
    } catch (e) {
      print('Error sincronizando item ${item['id_sync']}: $e');
    }
  }
  
  // 4. Descargar modelo actualizado del servidor
  await descargarModeloActualizado();
}
```

---

## Esquema de Base de Datos SQLite

### Tablas Automaticas (se crean al inicializar)

```sql
-- 1. Usuarios
CREATE TABLE usuarios (
    id_usuario INTEGER PRIMARY KEY AUTOINCREMENT,
    identificador_unico TEXT UNIQUE NOT NULL,  -- Cedula
    estado TEXT DEFAULT 'activo',
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2. Credenciales Biometricas
CREATE TABLE credenciales_biometricas (
    id_credencial INTEGER PRIMARY KEY AUTOINCREMENT,
    id_usuario INTEGER NOT NULL,
    tipo_biometria TEXT DEFAULT 'voz',
    estado TEXT DEFAULT 'activo',
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

-- 3. Frases Dinamicas
CREATE TABLE frases_dinamicas (
    id_frase INTEGER PRIMARY KEY AUTOINCREMENT,
    frase TEXT NOT NULL,
    categoria TEXT,
    activa BOOLEAN DEFAULT 1
);

-- 4. Validaciones Biometricas
CREATE TABLE validaciones_biometricas (
    id_validacion INTEGER PRIMARY KEY AUTOINCREMENT,
    id_credencial INTEGER NOT NULL,
    resultado TEXT NOT NULL,  -- 'registro_exitoso', 'autenticacion_exitosa', etc.
    confianza REAL,
    fecha_validacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_credencial) REFERENCES credenciales_biometricas(id_credencial)
);

-- 5. Cola de Sincronizacion (NUEVA)
CREATE TABLE cola_sincronizacion (
    id_sync INTEGER PRIMARY KEY AUTOINCREMENT,
    tabla TEXT NOT NULL,              -- 'usuarios', 'credenciales_biometricas', etc.
    accion TEXT NOT NULL,             -- 'INSERT', 'UPDATE', 'DELETE'
    datos_json TEXT NOT NULL,         -- JSON con los datos
    sincronizado INTEGER DEFAULT 0,   -- 0 = pendiente, 1 = sincronizado
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_sincronizacion DATETIME,
    error_sincronizacion TEXT
);

CREATE INDEX idx_sincronizado ON cola_sincronizacion(sincronizado);
```

---

## Sistema de Sincronizacion Offline/Online

### Flujo de Sincronizacion

```
┌─────────────────────────────────────────────────────────────┐
│                   FASE 1: OFFLINE                           │
│                                                             │
│  Usuario registra biometria                                 │
│         ↓                                                   │
│  Guarda en SQLite local                                     │
│         ↓                                                   │
│  Entrena modelo SVM local                                   │
│         ↓                                                   │
│  Agrega a cola_sincronizacion (sincronizado=0)              │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    [Espera conexion]
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   FASE 2: DETECTA WIFI                      │
│                                                             │
│  WorkManager ejecuta cada 15 minutos                        │
│         ↓                                                   │
│  Lee cola_sincronizacion WHERE sincronizado=0               │
│         ↓                                                   │
│  Envia cada registro al servidor (PostgREST)                │
│         ↓                                                   │
│  Marca sincronizado=1                                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   FASE 3: SINCRONIZA MODELO                 │
│                                                             │
│  Consulta version del modelo servidor                       │
│         ↓                                                   │
│  Si version_servidor > version_local:                       │
│         ↓                                                   │
│  Descarga modelo actualizado                                │
│         ↓                                                   │
│  Importa con voz_mobile_importar_modelo()                   │
└─────────────────────────────────────────────────────────────┘
```

### Ejemplo de Item en Cola de Sincronizacion

```json
{
  "id_sync": 1,
  "tabla": "usuarios",
  "accion": "INSERT",
  "datos_json": "{\"identificador_unico\":\"1234567890\",\"estado\":\"activo\"}",
  "sincronizado": 0,
  "fecha_creacion": "2026-01-19 10:30:00",
  "fecha_sincronizacion": null,
  "error_sincronizacion": null
}
```

---

## Estructura de Archivos en App Flutter

### Organizacion Recomendada

```
tu-proyecto-flutter/
├── android/
│   └── app/
│       └── src/
│           └── main/
│               └── jniLibs/
│                   ├── arm64-v8a/
│                   │   └── libvoz_mobile.so    ← COPIAR AQUI
│                   └── armeabi-v7a/
│                       └── libvoz_mobile.so    ← (Compilar para 32-bit)
│
├── assets/
│   └── models/
│       └── ggml-tiny.bin                       ← COPIAR AQUI
│
├── lib/
│   ├── bindings/
│   │   └── voz_mobile.dart                     ← Wrapper FFI (crear)
│   ├── services/
│   │   ├── sync_service.dart                   ← Sincronizacion (crear)
│   │   └── background_sync_service.dart        ← WorkManager (crear)
│   ├── screens/
│   │   ├── registro_screen.dart
│   │   └── autenticacion_screen.dart
│   └── main.dart
│
└── pubspec.yaml
```

---

## Guia de Integracion Rapida

### Paso 1: Copiar Archivos

```bash
# En el servidor backend (ya compilado)
cd D:\server\biometria_voz\build-android-arm64-v8a\voz

# Copiar libreria
cp libvoz_mobile.so /tu-proyecto-flutter/android/app/src/main/jniLibs/arm64-v8a/

# Copiar modelo Whisper
cp ggml-tiny.bin /tu-proyecto-flutter/assets/models/
```

---

### Paso 2: Configurar pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  ffi: ^2.1.0
  path_provider: ^2.1.0
  shared_preferences: ^2.2.0
  http: ^1.1.0
  connectivity_plus: ^5.0.0
  workmanager: ^0.5.1
  record: ^5.0.0
  permission_handler: ^11.0.0

flutter:
  assets:
    - assets/models/ggml-tiny.bin
```

---

### Paso 3: Crear Wrapper FFI (lib/bindings/voz_mobile.dart)

```dart
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

// Typedefs FFI
typedef VozMobileInitNative = Int32 Function(
  Pointer<Int8> dbPath,
  Pointer<Int8> modelPath,
  Pointer<Int8> datasetPath,
);
typedef VozMobileInitDart = int Function(
  Pointer<Int8> dbPath,
  Pointer<Int8> modelPath,
  Pointer<Int8> datasetPath,
);

typedef VozMobileRegistrarNative = Int32 Function(
  Pointer<Int8> identificador,
  Pointer<Int8> audioPath,
  Int32 idFrase,
  Pointer<Int8> resultadoJson,
  IntPtr bufferSize,
);
typedef VozMobileRegistrarDart = int Function(
  Pointer<Int8> identificador,
  Pointer<Int8> audioPath,
  int idFrase,
  Pointer<Int8> resultadoJson,
  int bufferSize,
);

// ... (definir todos los typedefs)

class VozMobile {
  static VozMobile? _instance;
  late DynamicLibrary _lib;
  
  // Funciones nativas
  late VozMobileInitDart _init;
  late VozMobileRegistrarDart _registrar;
  // ... (vincular todas las funciones)
  
  VozMobile._() {
    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libvoz_mobile.so');
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process();
    } else {
      throw UnsupportedError('Plataforma no soportada');
    }
    
    _vincularFunciones();
  }
  
  void _vincularFunciones() {
    _init = _lib
        .lookup<NativeFunction<VozMobileInitNative>>('voz_mobile_init')
        .asFunction();
    
    _registrar = _lib
        .lookup<NativeFunction<VozMobileRegistrarNative>>('voz_mobile_registrar_biometria')
        .asFunction();
    
    // ... (vincular todas)
  }
  
  static VozMobile get instance => _instance ??= VozMobile._();
  
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    
    final dbPath = '${appDir.path}/biometria.db';
    final modelPath = '${appDir.path}/models/v2';
    final datasetPath = '${appDir.path}/dataset';
    
    // Crear directorios
    await Directory(modelPath).create(recursive: true);
    await Directory(datasetPath).create(recursive: true);
    
    final dbPathPtr = dbPath.toNativeUtf8().cast<Int8>();
    final modelPathPtr = modelPath.toNativeUtf8().cast<Int8>();
    final datasetPathPtr = datasetPath.toNativeUtf8().cast<Int8>();
    
    final result = _init(dbPathPtr, modelPathPtr, datasetPathPtr);
    
    malloc.free(dbPathPtr);
    malloc.free(modelPathPtr);
    malloc.free(datasetPathPtr);
    
    if (result != 0) {
      throw Exception('Error inicializando libreria: $result');
    }
  }
  
  Map<String, dynamic> registrarBiometria({
    required String cedula,
    required String audioPath,
    required int idFrase,
  }) {
    final cedulaPtr = cedula.toNativeUtf8().cast<Int8>();
    final audioPtr = audioPath.toNativeUtf8().cast<Int8>();
    final bufferResultado = calloc<Int8>(2048);
    
    final result = _registrar(
      cedulaPtr,
      audioPtr,
      idFrase,
      bufferResultado,
      2048,
    );
    
    final jsonString = bufferResultado.cast<Utf8>().toDartString();
    
    malloc.free(cedulaPtr);
    malloc.free(audioPtr);
    calloc.free(bufferResultado);
    
    if (result == 0) {
      return json.decode(jsonString);
    } else {
      return {
        "success": false,
        "error": "Error en registro biometrico: $result"
      };
    }
  }
}
```

---

### Paso 4: Inicializar en main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar libreria nativa
  await VozMobile.instance.initialize();
  
  // Configurar sincronizacion en background
  BackgroundSyncService.initialize();
  
  runApp(MyApp());
}
```

---

### Paso 5: Usar en Pantallas

```dart
class RegistroScreen extends StatefulWidget {
  @override
  _RegistroScreenState createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _cedulaController = TextEditingController();
  String _frase = '';
  int _idFrase = 0;
  bool _grabando = false;
  String? _audioPath;
  
  @override
  void initState() {
    super.initState();
    _cargarFraseAleatoria();
  }
  
  void _cargarFraseAleatoria() {
    final frase = VozMobile.instance.obtenerFraseAleatoria();
    setState(() {
      _frase = frase['frase'];
      _idFrase = frase['id_frase'];
    });
  }
  
  Future<void> _grabarAudio() async {
    setState(() => _grabando = true);
    
    // Implementar grabacion con package 'record'
    // ...
    
    setState(() {
      _grabando = false;
      _audioPath = '/path/to/audio.wav';
    });
  }
  
  Future<void> _registrar() async {
    if (_audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Graba tu voz primero')),
      );
      return;
    }
    
    final resultado = VozMobile.instance.registrarBiometria(
      cedula: _cedulaController.text,
      audioPath: _audioPath!,
      idFrase: _idFrase,
    );
    
    if (resultado['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registro exitoso!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${resultado['error']}')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Registro Biometrico')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _cedulaController,
              decoration: InputDecoration(labelText: 'Cedula'),
            ),
            SizedBox(height: 20),
            Text('Di la siguiente frase:', style: TextStyle(fontSize: 16)),
            SizedBox(height: 10),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(_frase, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _grabando ? null : _grabarAudio,
              icon: Icon(_grabando ? Icons.stop : Icons.mic),
              label: Text(_grabando ? 'Grabando...' : 'Grabar Voz'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _audioPath == null ? null : _registrar,
              child: Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Sincronizacion con Backend

### Endpoints del Servidor (Ya Implementados)

```
POST http://tu-servidor:3000/usuarios
POST http://tu-servidor:3000/credenciales_biometricas
POST http://tu-servidor:3000/validaciones_biometricas

GET  http://tu-servidor:8081/sync/modelo/metadata
GET  http://tu-servidor:8081/sync/modelo/class_0.bin
POST http://tu-servidor:8081/sync/modelo/metadata
POST http://tu-servidor:8081/sync/dataset/train
```

### Implementar Sincronizacion en Flutter

```dart
class SyncService {
  final String postgrestUrl = 'http://tu-servidor:3000';
  final String backendUrl = 'http://tu-servidor:8081';
  
  Future<void> sincronizarTodo() async {
    print('-> Iniciando sincronizacion...');
    
    // 1. Sincronizar registros pendientes
    await sincronizarColaPendiente();
    
    // 2. Verificar modelo
    if (await necesitaActualizarModelo()) {
      await descargarModeloActualizado();
    }
    
    print('-> Sincronizacion completada');
  }
  
  Future<void> sincronizarColaPendiente() async {
    final cola = VozMobile.instance.obtenerColaSincronizacion();
    
    for (var item in cola) {
      try {
        final tabla = item['tabla'];
        final datos = json.decode(item['datos_json']);
        
        // Enviar a PostgREST
        await http.post(
          Uri.parse('$postgrestUrl/$tabla'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(datos),
        );
        
        // Marcar como sincronizado
        VozMobile.instance.marcarSincronizado(item['id_sync']);
        
        print('-> Sincronizado: ${item['tabla']} #${item['id_sync']}');
      } catch (e) {
        print('# Error sincronizando item ${item['id_sync']}: $e');
      }
    }
  }
  
  Future<bool> necesitaActualizarModelo() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/sync/modelo/metadata'),
      );
      
      final serverMetadata = json.decode(response.body);
      final localMetadata = VozMobile.instance.obtenerMetadataModelo();
      
      return serverMetadata['version'] != localMetadata['version'];
    } catch (e) {
      print('# Error verificando modelo: $e');
      return false;
    }
  }
  
  Future<void> descargarModeloActualizado() async {
    print('-> Descargando modelo actualizado...');
    
    // Descargar modelo completo
    final response = await http.get(
      Uri.parse('$backendUrl/sync/modelo/export'),
    );
    
    // Importar en libreria nativa
    VozMobile.instance.importarModelo(response.bodyBytes);
    
    print('-> Modelo actualizado correctamente');
  }
}
```

---

## Checklist de Implementacion

### Backend (Ya Completado ✅)

- [x] Compilar libvoz_mobile.so para Android arm64-v8a
- [x] Implementar 20+ funciones FFI en mobile_api.cpp
- [x] Integrar SQLite local con esquema automatico
- [x] Implementar cola_sincronizacion
- [x] Copiar modelo Whisper (ggml-tiny.bin)
- [x] Generar documentacion completa

---

### Flutter (Pendiente ⏳)

- [ ] Copiar libvoz_mobile.so a android/app/src/main/jniLibs/
- [ ] Copiar ggml-tiny.bin a assets/models/
- [ ] Configurar pubspec.yaml con dependencias
- [ ] Crear lib/bindings/voz_mobile.dart (wrapper FFI)
- [ ] Vincular todas las funciones nativas
- [ ] Implementar VozMobile.initialize()
- [ ] Crear pantallas de registro y autenticacion
- [ ] Implementar grabacion de audio (package 'record')
- [ ] Solicitar permisos de microfono
- [ ] Implementar SyncService
- [ ] Configurar WorkManager para sync automatica
- [ ] Probar en dispositivo real (NO emulador)
- [ ] Manejar casos de error
- [ ] Implementar UI de estado de sincronizacion

---

## Notas Tecnicas Importantes

### 1. Arquitectura ARM

La libreria esta compilada para **arm64-v8a** (64-bit). Si necesitas soportar dispositivos de 32-bit, debes compilar tambien para **armeabi-v7a**.

**Para compilar 32-bit:**
```bash
cd D:\server\biometria_voz
mkdir build-android-armeabi-v7a
cd build-android-armeabi-v7a

cmake .. \
  -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=armeabi-v7a \
  -DANDROID_PLATFORM=android-24 \
  -DCMAKE_BUILD_TYPE=Release

cmake --build . --target voz_mobile
```

---

### 2. Modelo Whisper

El modelo `ggml-tiny.bin` (75 MB) se usa para **ASR (Automatic Speech Recognition)** y verifica que el usuario diga la frase correcta.

**Importante:** Debe estar en `assets/` y copiarse a storage interno al inicializar.

```dart
Future<void> _copiarModeloWhisper() async {
  final appDir = await getApplicationDocumentsDirectory();
  final modelPath = '${appDir.path}/models/ggml-tiny.bin';
  
  if (!File(modelPath).existsSync()) {
    final ByteData data = await rootBundle.load('assets/models/ggml-tiny.bin');
    await File(modelPath).writeAsBytes(data.buffer.asUint8List());
  }
}
```

---

### 3. Permisos de Android

Agregar en `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

---

### 4. Grabacion de Audio

Usar formato **WAV 16kHz mono** para compatibilidad:

```dart
import 'package:record/record.dart';

final record = AudioRecorder();

// Iniciar grabacion
await record.start(
  const RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
  ),
  path: '/path/to/output.wav',
);

// Detener
final path = await record.stop();
```

---

### 5. Testing en Dispositivo Real

**NO USAR EMULADOR** - El emulador tiene problemas con:
- Grabacion de audio
- Procesamiento intensivo (SVM, MFCC)
- FFI nativo

**Probar en dispositivo fisico:**
```bash
flutter run --release
```

---

## Resolucion de Problemas

### Error: "Failed to load dynamic library 'libvoz_mobile.so'"

**Solucion:**
- Verificar que libvoz_mobile.so esta en `android/app/src/main/jniLibs/arm64-v8a/`
- Rebuild completo: `flutter clean && flutter build apk`

---

### Error: "voz_mobile_init returned -1"

**Posibles causas:**
- Rutas incorrectas (db_path, model_path, dataset_path)
- Directorios no existen (crearlos con `Directory.create(recursive: true)`)
- Permisos insuficientes

---

### Error: "Whisper model not found"

**Solucion:**
- Verificar que ggml-tiny.bin esta en assets/
- Copiar a storage interno al inicializar
- Verificar ruta en voz_mobile_init()

---

## Contacto y Soporte

**Equipo Backend:**
- Archivos compilados en: `D:\server\biometria_voz\build-android-arm64-v8a\voz\`
- Documentacion en: `D:\server\biometria_voz\`

**Archivos de Referencia:**
- `mobile_api.h` - API completa C
- `INTEGRACION_FLUTTER_FFI.md` - Guia detallada
- `SINCRONIZACION_OFFLINE_ONLINE.md` - Estrategia de sync

---

**Fecha de Entrega:** 19 de enero de 2026  
**Version Libreria:** 1.0.0-mobile  
**Estado:** ✅ Listo para Integracion
