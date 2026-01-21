# Sistema Híbrido de Autenticación Biométrica
## Online/Offline con FFI (libvoz_mobile.so)

Este documento explica cómo usar el sistema híbrido de autenticación biométrica que funciona tanto **ONLINE** como **OFFLINE**.

---

## 📋 Índice

1. [Arquitectura del Sistema](#arquitectura-del-sistema)
2. [Instalación y Configuración](#instalación-y-configuración)
3. [Uso del Servicio Híbrido](#uso-del-servicio-híbrido)
4. [Ejemplos de Implementación](#ejemplos-de-implementación)
5. [Sincronización de Datos](#sincronización-de-datos)
6. [Troubleshooting](#troubleshooting)

---

## 🏗️ Arquitectura del Sistema

### Flujo de Funcionamiento

```
┌─────────────────────────────────────────────────────────────────┐
│                      APLICACIÓN FLUTTER                         │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │           HybridAuthService (Dart)                       │  │
│  │  • Detecta conectividad automáticamente                  │  │
│  │  • Decide entre ONLINE/OFFLINE                           │  │
│  │  • Sincroniza datos pendientes                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│           ↓                              ↓                      │
│  ┌─────────────────────┐    ┌──────────────────────────────┐  │
│  │ NativeVoiceService  │    │ BiometricBackendService      │  │
│  │ (FFI - Offline)     │    │ (HTTP - Online)              │  │
│  └─────────────────────┘    └──────────────────────────────┘  │
│           ↓                              ↓                      │
│  ┌─────────────────────┐    ┌──────────────────────────────┐  │
│  │ libvoz_mobile.so    │    │ Servidor en la Nube         │  │
│  │ • Modelo SVM Local  │    │ • PostgreSQL                 │  │
│  │ • SQLite Local      │    │ • Modelo Global              │  │
│  │ • MFCC Nativo       │    │ • 167.71.155.9:8081          │  │
│  └─────────────────────┘    └──────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Modos de Operación

#### 1. **Modo ONLINE** 🌐
- Valida contra servidor en la nube
- Usa modelo SVM global actualizado
- Registra en PostgreSQL
- Mayor precisión (datos de todos los usuarios)

#### 2. **Modo OFFLINE** 📱
- Valida con librería nativa (.so)
- Usa modelo SVM local
- Guarda en SQLite local
- Funciona sin conexión a internet

#### 3. **Sincronización Automática** 🔄
- Detecta cuando recupera conexión
- Envía datos pendientes al servidor
- Actualiza modelo local con versión del servidor
- Mantiene consistencia de datos

---

## 🔧 Instalación y Configuración

### Paso 1: Copiar Archivos Nativos

Los archivos necesarios están en `mobile_app/lib/config/entrega_flutter_mobile/`:

```bash
# 1. Copiar librería nativa
cp entrega_flutter_mobile/libraries/android/arm64-v8a/libvoz_mobile.so \
   android/app/src/main/jniLibs/arm64-v8a/

# 2. Verificar que la carpeta jniLibs existe
mkdir -p android/app/src/main/jniLibs/arm64-v8a
```

### Paso 2: Copiar Assets al Proyecto

Los modelos y datasets ya están en:
- `entrega_flutter_mobile/assets/models/v1/` - 68 archivos class_*.bin + metadata.json
- `entrega_flutter_mobile/assets/caracteristicas/v1/` - Datasets MFCC

**Configurar en `pubspec.yaml`:**

```yaml
dependencies:
  flutter:
    sdk: flutter
  ffi: ^2.1.0
  path_provider: ^2.1.0
  connectivity_plus: ^5.0.0
  dio: ^5.4.0
  record: ^5.0.0
  shared_preferences: ^2.2.0

flutter:
  assets:
    - assets/models/v1/
    - assets/caracteristicas/v1/
```

### Paso 3: Inicializar el Servicio

```dart
import 'package:mobile_app/services/hybrid_auth_service.dart';

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _hybridAuth = HybridAuthService();

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    final success = await _hybridAuth.initialize();
    if (success) {
      print('✅ Sistema híbrido inicializado');
      final info = _hybridAuth.getServiceInfo();
      print('📶 Modo: ${info['is_online'] ? "ONLINE" : "OFFLINE"}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginHibridoScreen(),
    );
  }
}
```

---

## 🚀 Uso del Servicio Híbrido

### Registro de Usuario

```dart
Future<void> registrarUsuario() async {
  final result = await HybridAuthService().registerUser(
    identificador: '1234567890',
    nombres: 'Juan',
    apellidos: 'Pérez',
    audioPath: '/path/to/audio.wav',
    email: 'juan@example.com',
  );

  if (result['success'] == true) {
    final mode = result['mode']; // 'online' o 'offline'
    final pendingSync = result['pending_sync']; // true si está en cola
    
    if (mode == 'online') {
      print('✅ Registrado en servidor');
    } else {
      print('📱 Registrado localmente');
      if (pendingSync == true) {
        print('⏳ Se sincronizará cuando haya conexión');
      }
    }
  }
}
```

### Autenticación de Usuario

```dart
Future<void> autenticarUsuario() async {
  final result = await HybridAuthService().authenticate(
    identificador: '1234567890',
    audioPath: '/path/to/audio_login.wav',
  );

  if (result['success'] == true) {
    if (result['authenticated'] == true) {
      final confidence = result['confidence'];
      final mode = result['mode'];
      
      print('✅ Autenticación exitosa');
      print('📊 Confianza: ${(confidence * 100).toStringAsFixed(1)}%');
      print('📶 Modo: $mode');
      
      // Navegar a pantalla principal
    } else {
      print('❌ Autenticación rechazada');
      print('📊 Confianza: ${result['confidence']}');
    }
  }
}
```

### Sincronización Manual

```dart
Future<void> sincronizarDatos() async {
  // Verificar si hay conexión
  final canSync = await HybridAuthService().checkConnectivity();
  
  if (!canSync) {
    print('⚠️ Sin conexión a internet');
    return;
  }

  // Sincronizar datos pendientes
  final result = await HybridAuthService().syncPendingData();
  
  if (result['success'] == true) {
    print('✅ Sincronizados: ${result['synced']} registros');
    print('❌ Fallidos: ${result['failed']} registros');
    print('⏳ Pendientes: ${result['pending']} registros');
  }
}
```

### Obtener Estado de Sincronización

```dart
Future<void> verificarEstadoSync() async {
  final status = await HybridAuthService().getSyncStatus();
  
  print('📋 Items pendientes: ${status['pending_count']}');
  print('📶 Online: ${status['is_online']}');
  print('🔄 Puede sincronizar: ${status['can_sync']}');
  
  // Ver items individuales
  final items = status['pending_items'] as List;
  for (var item in items) {
    print('  - ID: ${item['id_sync']}');
    print('    Tabla: ${item['tabla']}');
    print('    Acción: ${item['accion']}');
  }
}
```

---

## 📱 Ejemplos de Implementación

### Ejemplo 1: Pantalla de Registro

Ver archivo completo en: `lib/examples/registro_hibrido_screen.dart`

```dart
// Código simplificado
class RegistroScreen extends StatefulWidget {
  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _hybridAuth = HybridAuthService();
  
  @override
  void initState() {
    super.initState();
    _hybridAuth.initialize();
  }
  
  Future<void> _registrar() async {
    final result = await _hybridAuth.registerUser(
      identificador: _cedulaController.text,
      nombres: _nombresController.text,
      apellidos: _apellidosController.text,
      audioPath: _audioPath!,
    );
    
    // Manejar resultado...
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        child: Column(
          children: [
            TextFormField(/* cédula */),
            TextFormField(/* nombres */),
            TextFormField(/* apellidos */),
            RecordButton(onRecorded: (path) => _audioPath = path),
            ElevatedButton(
              onPressed: _registrar,
              child: Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Ejemplo 2: Pantalla de Login

Ver archivo completo en: `lib/examples/login_hibrido_screen.dart`

```dart
class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _hybridAuth = HybridAuthService();
  
  Future<void> _login() async {
    final result = await _hybridAuth.authenticate(
      identificador: _cedulaController.text,
      audioPath: _audioPath!,
    );
    
    if (result['authenticated'] == true) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      showDialog(/* error */);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextFormField(/* cédula */),
          RecordButton(onRecorded: (path) => _audioPath = path),
          ElevatedButton(
            onPressed: _login,
            child: Text('Iniciar Sesión'),
          ),
        ],
      ),
    );
  }
}
```

---

## 🔄 Sincronización de Datos

### Sincronización Automática

El servicio detecta automáticamente cuando recupera conexión a internet:

```dart
// Esto ya está implementado en HybridAuthService
void _onConnectivityChanged(ConnectivityResult result) async {
  final wasOffline = !_isOnline;
  _isOnline = await _backend.isOnline();

  if (wasOffline && _isOnline) {
    // Recuperó conexión → Sincronizar automáticamente
    await syncPendingData();
  }
}
```

### Cola de Sincronización

Tabla SQLite: `cola_sincronizacion`

```sql
CREATE TABLE cola_sincronizacion (
    id_sync INTEGER PRIMARY KEY AUTOINCREMENT,
    tabla TEXT NOT NULL,              -- 'usuarios', 'credenciales_biometricas'
    accion TEXT NOT NULL,             -- 'INSERT', 'UPDATE', 'DELETE'
    datos_json TEXT NOT NULL,         -- JSON con los datos
    sincronizado INTEGER DEFAULT 0,   -- 0=pendiente, 1=sincronizado
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_sincronizacion DATETIME,
    error_sincronizacion TEXT
);
```

### Proceso de Sincronización

1. **Usuario registra biometría offline**
   - Se guarda en SQLite local
   - Se entrena modelo SVM local
   - Se agrega a `cola_sincronizacion`

2. **App detecta conexión**
   - Lee todos los registros con `sincronizado=0`
   - Envía cada uno al servidor (PostgREST)
   - Marca como `sincronizado=1`

3. **Actualización del modelo**
   - Descarga modelo actualizado del servidor
   - Importa usando `voz_mobile_importar_modelo()`
   - Actualiza dataset local

---

## 🔍 Troubleshooting

### Error: "Servicio no inicializado"

**Causa:** No se llamó a `initialize()` antes de usar el servicio.

**Solución:**
```dart
final _hybridAuth = HybridAuthService();

@override
void initState() {
  super.initState();
  _initService();
}

Future<void> _initService() async {
  await _hybridAuth.initialize();
}
```

### Error: "Librería no encontrada: libvoz_mobile.so"

**Causa:** La librería nativa no está en la ubicación correcta.

**Solución:**
```bash
# Verificar que existe
ls android/app/src/main/jniLibs/arm64-v8a/libvoz_mobile.so

# Si no existe, copiarla
cp entrega_flutter_mobile/libraries/android/arm64-v8a/libvoz_mobile.so \
   android/app/src/main/jniLibs/arm64-v8a/
```

### Error: "Modelo SVM no encontrado"

**Causa:** Los archivos `class_*.bin` no se copiaron correctamente.

**Solución:**
1. Verificar que en `pubspec.yaml` estén declarados:
   ```yaml
   flutter:
     assets:
       - assets/models/v1/
       - assets/caracteristicas/v1/
   ```

2. Ejecutar:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### Datos no se sincronizan

**Diagnóstico:**
```dart
final status = await _hybridAuth.getSyncStatus();
print('Pendientes: ${status['pending_count']}');
print('Online: ${status['is_online']}');

if (status['is_online'] == false) {
  print('⚠️ Sin conexión a internet');
} else if (status['pending_count'] == 0) {
  print('✅ No hay datos pendientes');
}
```

**Solución:**
```dart
// Forzar sincronización manual
await _hybridAuth.syncPendingData();
```

---

## 📊 Métricas y Monitoreo

### Ver Información del Servicio

```dart
final info = _hybridAuth.getServiceInfo();
print('Inicializado: ${info['initialized']}');
print('Online: ${info['is_online']}');
print('Versión nativa: ${info['native_version']}');
print('Último error: ${info['last_error']}');
```

### Mostrar Estado en UI

```dart
Widget buildStatusBadge() {
  final info = _hybridAuth.getServiceInfo();
  final isOnline = info['is_online'] == true;
  
  return Chip(
    avatar: Icon(isOnline ? Icons.cloud_done : Icons.cloud_off),
    label: Text(isOnline ? 'ONLINE' : 'OFFLINE'),
    backgroundColor: isOnline ? Colors.green : Colors.orange,
  );
}
```

---

## 🎯 Mejores Prácticas

1. **Inicializar temprano**: Llamar a `initialize()` en el `initState()` del widget principal.

2. **Manejar errores**: Siempre verificar `result['success']` antes de procesar resultados.

3. **Feedback al usuario**: Mostrar claramente si está en modo ONLINE u OFFLINE.

4. **Sincronización automática**: Confiar en la detección automática de conectividad.

5. **Grabar audio correctamente**:
   - Formato: WAV
   - Sample rate: 16000 Hz
   - Canales: 1 (mono)
   - Duración: 2-5 segundos

6. **Limpiar recursos**:
   ```dart
   @override
   void dispose() {
     _hybridAuth.cleanup();
     super.dispose();
   }
   ```

---

## 📚 Referencias

- **Documentación completa**: `entrega_flutter_mobile/documentation/ENTREGA_EQUIPO_FLUTTER.md`
- **API nativa**: `entrega_flutter_mobile/documentation/mobile_api.h`
- **Ejemplos de código**:
  - `lib/examples/registro_hibrido_screen.dart`
  - `lib/examples/login_hibrido_screen.dart`
- **Servicios**:
  - `lib/services/native_voice_service.dart` - FFI wrapper
  - `lib/services/hybrid_auth_service.dart` - Lógica híbrida
  - `lib/services/biometric_backend_service.dart` - Backend en nube

---

## ✅ Checklist de Implementación

- [ ] Copiar `libvoz_mobile.so` a `jniLibs/arm64-v8a/`
- [ ] Declarar assets en `pubspec.yaml`
- [ ] Inicializar `HybridAuthService` en la app
- [ ] Implementar pantalla de registro
- [ ] Implementar pantalla de login
- [ ] Mostrar estado online/offline en UI
- [ ] Implementar botón de sincronización manual
- [ ] Probar en modo offline (sin WiFi)
- [ ] Probar sincronización al recuperar conexión
- [ ] Manejar errores correctamente

---

**Fecha:** 19 de enero de 2026  
**Versión:** 1.0.0  
**Librería Nativa:** libvoz_mobile.so v1.0.0-mobile
