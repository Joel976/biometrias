# Guia de Implementacion - Sistema Biometrico Mobile con Sincronizacion

**Fecha:** 24 de enero de 2026  
**Version:** 1.0.0-mobile  
**Equipo:** Flutter Mobile

---

## Tabla de Contenidos

1. [Introduccion](#introduccion)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Estructura de la Base de Datos SQLite](#estructura-de-la-base-de-datos-sqlite)
4. [API FFI Completa](#api-ffi-completa)
5. [Flujos de Sincronizacion](#flujos-de-sincronizacion)
6. [Implementacion en Flutter](#implementacion-en-flutter)
7. [Manejo de Offline/Online](#manejo-de-offlineonline)
8. [Casos de Uso](#casos-de-uso)
9. [Troubleshooting](#troubleshooting)

---

## Introduccion

Este documento describe la implementacion completa del modulo mobile de biometria de voz con capacidades offline/online y sincronizacion bidireccional con el servidor backend.

### Principios Fundamentales

1. **Los vectores son los DATOS, el modelo SVM es DERIVADO**
   - Se sincronizan vectores de caracteristicas (MFCC), no el modelo
   - El modelo se reconstruye desde los vectores
   - El modelo local es temporal hasta que el servidor devuelve uno mejor

2. **El servidor siempre tiene la verdad completa**
   - Todos los vectores se consolidan en el servidor
   - El servidor re-entrena modelos con TODOS los datos disponibles
   - El mobile puede autenticar localmente, pero sincroniza cuando puede

3. **La prediccion siempre es local**
   - No requiere internet para autenticar
   - Usa el mejor modelo disponible (local temporal o del servidor)

---

## Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                    APLICACION FLUTTER                        │
│  (UI, Grabacion Audio, Interfaz Usuario)                    │
└───────────────────────┬─────────────────────────────────────┘
                        │ FFI (Dart ↔ C)
┌───────────────────────▼─────────────────────────────────────┐
│              LIBRERIA MOBILE (libvoz_mobile.so)             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Pipeline    │  │     SVM      │  │    SQLite    │      │
│  │  (MFCC)      │  │ Clasificador │  │   Adapter    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└───────────────────────┬─────────────────────────────────────┘
                        │ Sincronizacion HTTP
┌───────────────────────▼─────────────────────────────────────┐
│                    SERVIDOR BACKEND                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Sync         │  │  PostgreSQL  │  │  Reentrenar  │      │
│  │ Controller   │  │  (Vectores)  │  │     SVM      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

---

## Estructura de la Base de Datos SQLite

### Tabla: `usuarios`

```sql
CREATE TABLE usuarios (
    id_usuario INTEGER PRIMARY KEY AUTOINCREMENT,
    identificador_unico TEXT UNIQUE NOT NULL,  -- Cedula
    estado TEXT DEFAULT 'activo',
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### Tabla: `credenciales_biometricas`

```sql
CREATE TABLE credenciales_biometricas (
    id_credencial INTEGER PRIMARY KEY AUTOINCREMENT,
    id_usuario INTEGER NOT NULL,
    tipo_biometria TEXT NOT NULL,  -- 'voz'
    estado TEXT DEFAULT 'activo',
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);
```

### Tabla: `frases_dinamicas`

```sql
CREATE TABLE frases_dinamicas (
    id_frase INTEGER PRIMARY KEY AUTOINCREMENT,
    frase TEXT NOT NULL,
    categoria TEXT DEFAULT 'general',
    activa INTEGER DEFAULT 1,
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### Tabla: `validaciones_biometricas`

```sql
CREATE TABLE validaciones_biometricas (
    id_validacion INTEGER PRIMARY KEY AUTOINCREMENT,
    id_credencial INTEGER NOT NULL,
    resultado TEXT NOT NULL,  -- 'exitoso', 'fallido'
    confianza REAL,
    fecha_validacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_credencial) REFERENCES credenciales_biometricas(id_credencial)
);
```

### **NUEVA** Tabla: `config_sync`

```sql
CREATE TABLE config_sync (
    clave TEXT PRIMARY KEY,
    valor TEXT NOT NULL
);
```

Almacena:
- `uuid_dispositivo` - Identificador unico del dispositivo
- `ultimo_sync_timestamp` - Ultima sincronizacion exitosa

### **NUEVA** Tabla: `caracteristicas_hablantes`

```sql
CREATE TABLE caracteristicas_hablantes (
    id_caracteristica INTEGER PRIMARY KEY AUTOINCREMENT,
    id_usuario INTEGER NOT NULL,
    id_credencial INTEGER,
    vector_features BLOB NOT NULL,        -- Vector MFCC serializado
    dimension INTEGER NOT NULL,           -- Numero de features
    origen TEXT DEFAULT 'mobile',         -- 'mobile' o 'server'
    uuid_dispositivo TEXT,
    fecha_captura DATETIME DEFAULT CURRENT_TIMESTAMP,
    sincronizado INTEGER DEFAULT 0,       -- 0=pendiente, 1=sincronizado
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    FOREIGN KEY (id_credencial) REFERENCES credenciales_biometricas(id_credencial)
);
```

---

## API FFI Completa

### Inicializacion

```dart
/// Inicializar libreria
/// @return 0 si exito, -1 si error
int voz_mobile_init(
  String db_path,        // "/data/data/.../biometria.db"
  String model_path,     // "/data/data/.../models/v1/"
  String dataset_path    // "/data/data/.../caracteristicas/v1/caracteristicas_train.dat"
);

/// Liberar recursos
void voz_mobile_cleanup();

/// Obtener version de la libreria
String voz_mobile_version();  // "1.0.0-mobile"
```

### Usuarios

```dart
/// Obtener ID de usuario por cedula
/// @return ID del usuario, -1 si no existe
int voz_mobile_obtener_id_usuario(String identificador);

/// Crear nuevo usuario
/// @return ID del usuario creado, -1 si error
int voz_mobile_crear_usuario(String identificador);

/// Verificar si usuario existe
/// @return 1 si existe, 0 si no existe
int voz_mobile_usuario_existe(String identificador);
```

### Frases Dinamicas

```dart
/// Obtener frase aleatoria activa
/// @return ID de la frase seleccionada, -1 si error
int voz_mobile_obtener_frase_aleatoria(StringBuffer frase);

/// Obtener frase por ID
/// @return 0 si exito, -1 si error
int voz_mobile_obtener_frase_por_id(int id_frase, StringBuffer frase);

/// Insertar nuevas frases (JSON array)
/// @return Cantidad de frases insertadas, -1 si error
int voz_mobile_insertar_frases(String frases_json);
```

### Registro Biometrico

```dart
/// Registrar biometria de voz
/// @return 0 si exito, -1 si error
int voz_mobile_registrar_biometria(
  String identificador,
  String audio_path,      // Ruta temporal del WAV grabado
  int id_frase,
  StringBuffer resultado_json
);
```

**Respuesta JSON:**

```json
{
  "success": true,
  "user_id": 123,
  "credential_id": 456,
  "features_extracted": 39,
  "model_updated": true,
  "num_classes": 10
}
```

### Autenticacion

```dart
/// Autenticar usuario por voz
/// @return 1 si autenticado, 0 si rechazado, -1 si error
int voz_mobile_autenticar(
  String identificador,
  String audio_path,
  int id_frase,
  StringBuffer resultado_json
);
```

**Respuesta JSON:**

```json
{
  "success": true,
  "authenticated": true,
  "user_id": 123,
  "predicted_class": 123,
  "confidence": 0.87,
  "all_scores": {
    "123": 0.87,
    "124": 0.05,
    "125": 0.03
  }
}
```

### **NUEVAS** Funciones de Sincronizacion

```dart
/// Push: enviar vectores pendientes al servidor
/// @return 0 si exito, -1 si error
int voz_mobile_sync_push(
  String server_url,           // "http://192.168.1.100:8080"
  StringBuffer resultado_json
);

/// Pull: descargar cambios del servidor
/// @return 0 si exito, -1 si error
int voz_mobile_sync_pull(
  String server_url,
  String desde,               // Timestamp o "" para todos
  StringBuffer resultado_json
);

/// Pull modelo: descargar modelo re-entrenado
/// @return 0 si exito, -1 si error
int voz_mobile_sync_modelo(
  String server_url,
  String identificador,       // Cedula del usuario
  StringBuffer resultado_json
);

/// Obtener UUID del dispositivo
/// @return 0 si exito, -1 si error
int voz_mobile_obtener_uuid_dispositivo(StringBuffer uuid);

/// Establecer UUID del dispositivo
/// @return 0 si exito, -1 si error
int voz_mobile_establecer_uuid_dispositivo(String uuid);
```

### Utilidades

```dart
/// Obtener ultimo error
void voz_mobile_obtener_ultimo_error(StringBuffer error);

/// Obtener estadisticas del modelo
/// @return 0 si exito, -1 si error
int voz_mobile_obtener_estadisticas(StringBuffer stats_json);
```

**Respuesta JSON:**

```json
{
  "usuarios_registrados": 50,
  "frases_activas": 120,
  "pendientes_sincronizacion": 5,
  "modelo_cargado": true,
  "num_clases": 50,
  "num_features": 39
}
```

---

## Flujos de Sincronizacion

### Flujo 1: Registro OFFLINE

```
1. Usuario graba audio en mobile
2. Pipeline extrae vector MFCC [ dims]
3. Guardar en caracteristicas_hablantes (sincronizado=0)
4. Entrenar modelo SVM LOCAL (temporal, solo datos locales)
5. Usuario puede autenticar localmente
6. Vectores quedan en cola para sincronizar
```

### Flujo 2: Registro ONLINE

```
1. Usuario graba audio en mobile
2. Pipeline extrae vector MFCC [39 dims]
3. Guardar en caracteristicas_hablantes (sincronizado=0)
4. Inmediatamente: voz_mobile_sync_push() → servidor recibe vector
5. Servidor inserta en caracteristicas_hablantes (PostgreSQL)
6. Servidor re-entrena SVM con TODOS los vectores del usuario
7. Mobile: voz_mobile_sync_modelo() → recibe modelo robusto
8. Reemplazar modelo local con el del servidor
9. Marcar caracteristica como sincronizada
```

### Flujo 3: Offline → Online

```
1. Mobile tiene registros offline pendientes (sincronizado=0)
2. Detecta conexion a internet
3. voz_mobile_sync_push() → envia todos los vectores pendientes
4. voz_mobile_sync_modelo() → recibe modelo re-entrenado
5. voz_mobile_sync_pull() → recibe frases nuevas, cambios
6. Reemplazar modelo local
7. Marcar todo como sincronizado
```

### Flujo 4: Autenticacion (siempre local)

```
1. Audio → Pipeline MFCC → vector
2. Predecir con modelo local (temporal o del servidor)
3. Resultado: confianza >= 0.6 → autenticado
4. Guardar validacion en validaciones_biometricas
5. (Opcional) Encolar validacion para sincronizar
```

---

## Implementacion en Flutter

### 1. Configurar FFI

```dart
// lib/services/biometric_native.dart

import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef InitC = ffi.Int32 Function(
  ffi.Pointer<Utf8> dbPath,
  ffi.Pointer<Utf8> modelPath,
  ffi.Pointer<Utf8> datasetPath
);
typedef InitDart = int Function(
  ffi.Pointer<Utf8> dbPath,
  ffi.Pointer<Utf8> modelPath,
  ffi.Pointer<Utf8> datasetPath
);

class BiometricNative {
  late ffi.DynamicLibrary _lib;
  late InitDart _init;
  
  BiometricNative() {
    _lib = ffi.DynamicLibrary.open('libvoz_mobile.so');
    _init = _lib.lookup<ffi.NativeFunction<InitC>>('voz_mobile_init')
                .asFunction<InitDart>();
    // ... cargar otras funciones
  }
  
  Future<bool> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    
    final dbPath = '${appDir.path}/biometria.db';
    final modelPath = '${appDir.path}/models/v1/';
    final datasetPath = '${appDir.path}/caracteristicas/v1/caracteristicas_train.dat';
    
    final result = _init(
      dbPath.toNativeUtf8(),
      modelPath.toNativeUtf8(),
      datasetPath.toNativeUtf8()
    );
    
    return result == 0;
  }
}
```

### 2. Servicio de Sincronizacion

```dart
// lib/services/sync_service.dart

class SyncService {
  final BiometricNative _native;
  final String _serverUrl;
  
  SyncService(this._native, this._serverUrl);
  
  // Sincronizar vectores pendientes
  Future<SyncPushResult> syncPush() async {
    final buffer = calloc<Utf8>(4096);
    
    try {
      final result = _native.syncPush(
        _serverUrl.toNativeUtf8(),
        buffer
      );
      
      if (result == 0) {
        final json = jsonDecode(buffer.toDartString());
        return SyncPushResult.fromJson(json);
      }
      
      throw Exception('Error en sync push');
      
    } finally {
      calloc.free(buffer);
    }
  }
  
  // Descargar cambios del servidor
  Future<SyncPullResult> syncPull({String? desde}) async {
    final buffer = calloc<Utf8>(8192);
    
    try {
      final result = _native.syncPull(
        _serverUrl.toNativeUtf8(),
        (desde ?? '').toNativeUtf8(),
        buffer
      );
      
      if (result == 0) {
        final json = jsonDecode(buffer.toDartString());
        return SyncPullResult.fromJson(json);
      }
      
      throw Exception('Error en sync pull');
      
    } finally {
      calloc.free(buffer);
    }
  }
  
  // Descargar modelo actualizado
  Future<bool> syncModelo(String cedula) async {
    final buffer = calloc<Utf8>(4096);
    
    try {
      final result = _native.syncModelo(
        _serverUrl.toNativeUtf8(),
        cedula.toNativeUtf8(),
        buffer
      );
      
      return result == 0;
      
    } finally {
      calloc.free(buffer);
    }
  }
}
```

### 3. Detectar Conectividad

```dart
// lib/services/connectivity_manager.dart

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityManager {
  final SyncService _syncService;
  final Connectivity _connectivity = Connectivity();
  
  ConnectivityManager(this._syncService) {
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _onConnected();
      }
    });
  }
  
  Future<void> _onConnected() async {
    print('# Conexion detectada, iniciando sincronizacion...');
    
    try {
      // 1. Push vectores pendientes
      final pushResult = await _syncService.syncPush();
      print('-> Sincronizados ${pushResult.enviados} vectores');
      
      // 2. Pull cambios del servidor
      final pullResult = await _syncService.syncPull();
      print('-> Descargadas ${pullResult.frases.length} frases nuevas');
      
      // 3. Pull modelo actualizado (si hay vectores nuevos)
      if (pushResult.enviados > 0) {
        await _syncService.syncModelo(getCurrentUserCedula());
        print('-> Modelo actualizado descargado');
      }
      
    } catch (e) {
      print('! Error sincronizando: $e');
    }
  }
}
```

---

## Manejo de Offline/Online

### Estado del Sistema

```dart
enum BiometricState {
  offline,        // Sin internet, solo operaciones locales
  syncing,        // Sincronizando con servidor
  online          // Conectado y sincronizado
}

class BiometricStateManager {
  BiometricState _state = BiometricState.offline;
  
  BiometricState get state => _state;
  
  void updateState(BiometricState newState) {
    _state = newState;
    notifyListeners();
  }
}
```

### Estrategia de Registro

```dart
Future<RegistroResult> registrarBiometria({
  required String cedula,
  required String audioPath,
  required int idFrase
}) async {
  // 1. Siempre registrar localmente
  final result = await _native.registrarBiometria(
    cedula, audioPath, idFrase
  );
  
  if (!result.success) {
    throw Exception(result.error);
  }
  
  // 2. Intentar sincronizar si hay conexion
  if (await _hasConnection()) {
    try {
      await _syncService.syncPush();
      await _syncService.syncModelo(cedula);
      _stateManager.updateState(BiometricState.online);
    } catch (e) {
      // No critico, se sincronizara despues
      print('# Sincronizacion diferida: $e');
    }
  } else {
    _stateManager.updateState(BiometricState.offline);
  }
  
  return result;
}
```

---

## Casos de Uso

### Caso 1: Primera Instalacion (Offline)

```dart
void primeraInstalacion() async {
  // 1. Inicializar libreria
  await biometricNative.initialize();
  
  // 2. Generar UUID unico
  final uuid = Uuid().v4();
  await biometricNative.establecerUUID(uuid);
  
  // 3. Copiar assets (modelos, datasets, frases)
  await copyAssetsToLocal();
  
  // 4. Insertar frases predefinidas
  await biometricNative.insertarFrases(frasesJson);
  
  // 5. Listo para usar offline
  print('@ Sistema listo para uso offline');
}
```

### Caso 2: Registro con Conexion

```dart
void registroOnline() async {
  // 1. Grabar audio
  final audioPath = await AudioRecorder.record();
  
  // 2. Obtener frase
  final frase = await biometricNative.obtenerFraseAleatoria();
  
  // 3. Registrar biometria
  final result = await biometricNative.registrarBiometria(
    cedula, audioPath, frase.id
  );
  
  // 4. Sincronizar inmediatamente
  await syncService.syncPush();
  await syncService.syncModelo(cedula);
  
  print('@ Registro completado y sincronizado');
}
```

### Caso 3: Autenticacion Offline

```dart
void autenticarOffline() async {
  // 1. Grabar audio
  final audioPath = await AudioRecorder.record();
  
  // 2. Obtener frase
  final frase = await biometricNative.obtenerFraseAleatoria();
  
  // 3. Autenticar localmente
  final result = await biometricNative.autenticar(
    cedula, audioPath, frase.id
  );
  
  if (result.authenticated) {
    print('@ Usuario autenticado (offline)');
    // Guardar validacion para sincronizar despues
  } else {
    print('# Autenticacion fallida');
  }
}
```

---

## Troubleshooting

### Problema: "Modelo no cargado"

**Sintoma:** `modelo_cargado: false` en estadisticas

**Solucion:**
1. Verificar que `models/v1/metadata.json` exista
2. Verificar que `models/v1/class_*.bin` existan (68 archivos)
3. Revisar logs de inicializacion

```dart
final stats = await biometricNative.obtenerEstadisticas();
print(stats);  // {"modelo_cargado": true, "num_clases": 68}
```

### Problema: "Dataset no encontrado"

**Sintoma:** Warnings al inicializar

**Solucion:**
1. Copiar `caracteristicas/v1/caracteristicas_train.dat` a assets
2. Verificar permisos de lectura
3. Logs deben mostrar: `-> Dataset encontrado: ... (150 MB)`

### Problema: "Sincronizacion falla"

**Sintoma:** `sync_push` retorna error

**Solucion:**
1. Verificar URL del servidor: `http://IP:8080` (no HTTPS si es local)
2. Verificar que servidor este corriendo: `docker ps`
3. Verificar que endpoint `/sync/push` este disponible
4. Revisar logs del servidor

### Problema: "Base de datos corrupta"

**Sintoma:** Crashes al inicializar

**Solucion:**
1. Borrar `biometria.db`
2. Reiniciar app (se recreara automaticamente)
3. Sincronizar datos desde servidor si es posible

---

## Endpoints del Servidor

### POST `/sync/push`

**Request:**

```json
{
  "uuid_dispositivo": "abc-123-def",
  "caracteristicas": [
    {
      "id_usuario": 1,
      "id_credencial": 5,
      "vector_features": [0.1, 0.2, ..., 0.39],
      "dimension": 39
    }
  ]
}
```

**Response:**

```json
{
  "ok": true,
  "ids_procesados": [1, 2, 3],
  "procesados": 3,
  "total": 3
}
```

### GET `/sync/pull?desde=2026-01-24T10:00:00Z`

**Response:**

```json
{
  "ok": true,
  "frases": [
    {
      "id_frase": 101,
      "frase": "El cielo esta despejado hoy",
      "updated_at": "2026-01-24T12:00:00Z"
    }
  ],
  "usuarios": [
    {
      "id_usuario": 123,
      "identificador_unico": "1234567890",
      "estado": "activo",
      "updated_at": "2026-01-24T11:30:00Z"
    }
  ],
  "timestamp_actual": "2026-01-24T15:00:00Z"
}
```

### GET `/sync/modelo?cedula=1234567890`

**Response:** Binario del modelo SVM serializado

---

## Resumen de Cambios Implementados

### Base de Datos

✅ Tabla `caracteristicas_hablantes` en PostgreSQL  
✅ Tabla `config_sync` en SQLite  
✅ Tabla `caracteristicas_hablantes` en SQLite  
✅ Columna `updated_at` en tablas principales  
✅ Indices para sincronizacion

### API Mobile

✅ `voz_mobile_sync_push()`  
✅ `voz_mobile_sync_pull()`  
✅ `voz_mobile_sync_modelo()`  
✅ `voz_mobile_obtener_uuid_dispositivo()`  
✅ `voz_mobile_establecer_uuid_dispositivo()`

### Backend

✅ `SincronizacionService` (service layer)  
✅ `SyncController` (HTTP endpoints)  
✅ `/sync/push`, `/sync/pull`, `/sync/modelo`

### Logs y Debugging

✅ Logs detallados en inicializacion  
✅ Logs de carga de modelo y dataset  
✅ Logs de sincronizacion

---

## Proximos Pasos para Flutter

1. **Implementar FFI completo** usando `mobile_api.h` y `sqlite_adapter.h`
2. **Copiar assets** (modelos, datasets, frases) a local storage
3. **Implementar SyncService** con los 3 metodos de sincronizacion
4. **Detectar conectividad** y sincronizar automaticamente
5. **Manejar estados** offline/online en UI
6. **Testear flujos** de registro y autenticacion offline/online

---

**Contacto:** Equipo Backend  
**Ultima actualizacion:** 24 de enero de 2026
