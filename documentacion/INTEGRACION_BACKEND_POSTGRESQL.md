# 🚀 GUÍA DE INTEGRACIÓN CON BACKEND POSTGRESQL

## 📋 ÍNDICE
1. [Resumen de Cambios](#resumen-de-cambios)
2. [Configuración Actual](#configuración-actual)
3. [Cómo Integrar con Backend Oficial](#integrar-backend-oficial)
4. [Endpoints del Backend](#endpoints-del-backend)
5. [Arquitectura del Sistema](#arquitectura-del-sistema)
6. [Flujo de Datos](#flujo-de-datos)
7. [Solución de Problemas](#solución-de-problemas)

---

## 📌 RESUMEN DE CAMBIOS

### ✅ Lo que se ha hecho:

1. **Base de Datos SQLite Actualizada** (`database_config.dart`)
   - Esquema **IDÉNTICO** al PostgreSQL de tus compañeros
   - Tablas: `usuarios`, `credenciales_biometricas`, `textos_dinamicos_audio`, `validaciones_biometricas`
   - Compatibilidad 100% con estructura del backend

2. **Servicio Híbrido Backend** (`backend_service.dart`)
   - Detecta automáticamente conexión a internet
   - Si hay conexión → usa backend PostgreSQL remoto
   - Si no hay conexión → fallback a SQLite local
   - Endpoints listos para entrenamiento y verificación biométrica

3. **Configuración de Ambiente** (`environment_config.dart`)
   - Maneja URLs de desarrollo, staging y producción
   - Switch fácil entre ambientes
   - **AQUÍ VAS A PONER LA URL OFICIAL DE TUS COMPAÑEROS**

4. **Pipeline de Machine Learning** (`ml_pipeline_service.dart`)
   - Preprocesamiento de imágenes (oreja)
   - Preprocesamiento de audio (voz)
   - Extracción de características
   - Normalización de datos
   - Validación de calidad

---

## ⚙️ CONFIGURACIÓN ACTUAL

### Esquema de Base de Datos (SQLite ≈ PostgreSQL)

```sql
-- 📌 Tabla de usuarios
CREATE TABLE usuarios (
    id_usuario INTEGER PRIMARY KEY AUTOINCREMENT,
    nombres TEXT,
    apellidos TEXT,
    fecha_nacimiento TEXT,
    sexo TEXT,
    identificador_unico TEXT UNIQUE NOT NULL,
    estado TEXT DEFAULT 'activo',
    fecha_registro TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 📌 Tabla de credenciales biométricas
CREATE TABLE credenciales_biometricas (
    id_credencial INTEGER PRIMARY KEY AUTOINCREMENT,
    id_usuario INTEGER NOT NULL,
    tipo_biometria TEXT CHECK (tipo_biometria IN ('oreja', 'voz')),
    fecha_captura TEXT DEFAULT CURRENT_TIMESTAMP,
    estado TEXT DEFAULT 'activo',
    FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
);

-- 📌 Tabla de frases dinámicas
CREATE TABLE textos_dinamicos_audio (
    id_texto INTEGER PRIMARY KEY AUTOINCREMENT,
    frase TEXT NOT NULL,
    estado_texto TEXT DEFAULT 'activo'
);

-- 📌 Tabla de validaciones
CREATE TABLE validaciones_biometricas (
    id_validacion INTEGER PRIMARY KEY AUTOINCREMENT,
    id_usuario INTEGER,
    tipo_biometria TEXT,
    resultado TEXT,
    timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario) ON DELETE SET NULL
);
```

### Endpoints Configurados

El sistema está preparado para trabajar con estos endpoints:

#### **Usuarios**
- `POST /usuarios` - Registrar nuevo usuario
- `GET /usuarios/:identificador` - Obtener usuario

#### **Biometría - Oreja**
- `POST /biometria/registrar-oreja` - Registrar foto (entrenamiento)
- `POST /biometria/verificar-oreja` - Verificar autenticación

#### **Biometría - Voz**
- `POST /biometria/registrar-voz` - Registrar audio (entrenamiento)
- `POST /biometria/verificar-voz` - Verificar autenticación

#### **Frases Dinámicas**
- `GET /frases/obtener-activa` - Obtener frase para anti-spoofing

---

## 🔧 CÓMO INTEGRAR CON BACKEND OFICIAL

### Paso 1: Actualizar URL del Backend

**Archivo:** `lib/config/environment_config.dart`

```dart
/// URL del backend según el ambiente
static String get backendUrl {
  switch (environment) {
    case 'production':
      // 🔴 REEMPLAZA ESTA URL CON LA DE TUS COMPAÑEROS
      return 'https://tu-backend-oficial.com/api';  // ← CAMBIAR AQUÍ
    
    case 'development':
    default:
      return 'http://10.52.41.36:3000/api';
  }
}
```

**O desde la app (dinámicamente):**

```dart
import 'package:biometric_auth/config/environment_config.dart';

// Cuando te den la URL oficial:
EnvironmentConfig.setProductionUrl('https://backend-oficial.com/api');
```

### Paso 2: Configurar Credenciales (si aplica)

Si el backend requiere API keys o autenticación:

**Archivo:** `lib/config/api_config.dart`

```dart
void _setupInterceptors() {
  _dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Agregar API key si es necesario
        options.headers['X-API-Key'] = 'TU_API_KEY_AQUI';
        
        // O token de autenticación
        final token = await _secureStorage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        return handler.next(options);
      },
    ),
  );
}
```

### Paso 3: Verificar Estructura de Respuestas

El backend debe responder con este formato:

**Registro de Oreja:**
```json
POST /biometria/registrar-oreja
{
  "id_usuario": 123,
  "imagen_base64": "iVBORw0KGgoAAAANS...",
  "numero_foto": 1
}

Respuesta:
{
  "success": true,
  "mensaje": "Foto 1/3 registrada",
  "id_credencial": 456
}
```

**Verificación de Oreja:**
```json
POST /biometria/verificar-oreja
{
  "id_usuario": 123,
  "imagen_base64": "iVBORw0KGgoAAAANS..."
}

Respuesta:
{
  "verified": true,
  "confidence": 0.92,
  "mensaje": "Autenticación exitosa"
}
```

**Registro de Voz:**
```json
POST /biometria/registrar-voz
{
  "id_usuario": 123,
  "audio_base64": "UklGRiQAAABXQVZF..."
}

Respuesta:
{
  "success": true,
  "mensaje": "Audio registrado correctamente",
  "id_credencial": 789
}
```

**Verificación de Voz:**
```json
POST /biometria/verificar-voz
{
  "id_usuario": 123,
  "audio_base64": "UklGRiQAAABXQVZF..."
}

Respuesta:
{
  "verified": true,
  "confidence": 0.88,
  "mensaje": "Autenticación exitosa"
}
```

### Paso 4: Probar Conexión

```dart
import 'package:biometric_auth/services/backend_service.dart';

final backend = BackendService();

// Verificar si el backend está disponible
final online = await backend.isOnline();
print('Backend disponible: $online');

if (online) {
  print('✅ Conexión establecida con backend PostgreSQL');
} else {
  print('❌ Backend no responde - usando SQLite local');
}
```

---

## 🏗️ ARQUITECTURA DEL SISTEMA

```
┌─────────────────────────────────────────────────┐
│          MOBILE APP (Flutter)                   │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌──────────────┐        ┌──────────────┐      │
│  │ UI Screens   │◄──────►│ Auth Service │      │
│  └──────────────┘        └──────┬───────┘      │
│                                 │              │
│  ┌──────────────┐        ┌──────▼───────┐      │
│  │ TFLite Model │        │   Backend    │      │
│  │ (Validación  │        │   Service    │      │
│  │  de Oreja)   │        │  (Híbrido)   │      │
│  └──────────────┘        └──────┬───────┘      │
│                                 │              │
│  ┌──────────────┐        ┌──────▼───────┐      │
│  │ ML Pipeline  │◄──────►│  API Config  │      │
│  │   Service    │        │              │      │
│  └──────────────┘        └──────┬───────┘      │
│                                 │              │
│  ┌──────────────┐               │              │
│  │ SQLite Local │               │              │
│  └──────────────┘               │              │
└─────────────────────────────────┼──────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │   BACKEND (PostgreSQL)     │
                    ├────────────────────────────┤
                    │                            │
                    │  ┌──────────────────────┐  │
                    │  │ PostgreSQL Database  │  │
                    │  │  - usuarios          │  │
                    │  │  - credenciales_bio  │  │
                    │  │  - textos_dinamicos  │  │
                    │  │  - validaciones_bio  │  │
                    │  └──────────────────────┘  │
                    │                            │
                    │  ┌──────────────────────┐  │
                    │  │ Modelos ML (Python)  │  │
                    │  │  - Entrenamiento     │  │
                    │  │  - Preprocesamiento  │  │
                    │  │  - Extracción        │  │
                    │  │  - Normalización     │  │
                    │  │  - Clasificación     │  │
                    │  └──────────────────────┘  │
                    │                            │
                    └────────────────────────────┘
```

---

## 🔄 FLUJO DE DATOS

### Registro de Usuario con Biometría de Oreja

```
1. Usuario captura 3 fotos de oreja en la app
   ↓
2. ML Pipeline preprocessa cada imagen:
   - Redimensiona a 224x224
   - Normaliza píxeles [0,1]
   - Ecualiza histograma
   - Reduce ruido
   ↓
3. TFLite valida localmente (oreja clara >= 65%)
   ↓
4. Si válida → Backend Service envía a PostgreSQL:
   POST /biometria/registrar-oreja
   {
     "id_usuario": 123,
     "imagen_base64": "...",
     "numero_foto": 1
   }
   ↓
5. Backend Python:
   - Extrae características (features)
   - Entrena modelo de reconocimiento
   - Guarda modelo en DB
   ↓
6. Backend responde: {"success": true}
   ↓
7. App guarda credencial en SQLite local
```

### Login con Biometría de Oreja

```
1. Usuario captura foto de oreja
   ↓
2. ML Pipeline preprocessa imagen
   ↓
3. TFLite valida localmente (oreja clara >= 65%)
   ↓
4. Si válida → Backend Service verifica:
   POST /biometria/verificar-oreja
   {
     "id_usuario": 123,
     "imagen_base64": "..."
   }
   ↓
5. Backend Python:
   - Extrae características
   - Compara con modelo entrenado
   - Calcula similarity score
   ↓
6. Backend responde:
   {
     "verified": true,
     "confidence": 0.92
   }
   ↓
7. Si confidence >= 75% → Login exitoso
   ↓
8. App registra validación en SQLite local
```

---

## ⚡ CARACTERÍSTICAS DEL SISTEMA

### Preprocesamiento de Imágenes (ML Pipeline)

- ✅ Redimensionamiento a 224×224
- ✅ Conversión a RGB
- ✅ Ecualización de histograma (mejor contraste)
- ✅ Filtro gaussiano (reducción de ruido)
- ✅ Normalización de píxeles [0, 1]
- ✅ Extracción de características:
  - Brillo promedio
  - Contraste (desviación estándar)
  - Nitidez (detección de bordes Sobel)

### Preprocesamiento de Audio (ML Pipeline)

- ✅ Verificación de formato WAV
- ✅ Validación 16kHz mono
- ✅ Duración mínima 5 segundos
- ✅ Extracción de características:
  - Sample rate
  - Número de canales
  - Duración
  - Tamaño de archivo

### Validación de Calidad

**Imágenes:**
- Brillo: 50-200
- Contraste: >= 20
- Nitidez: >= 5

**Audio:**
- Sample rate: 16000 Hz
- Canales: 1 (mono)
- Duración: >= 5 segundos

---

## 🧪 PRUEBAS DE INTEGRACIÓN

### Test Manual

```dart
import 'package:biometric_auth/services/backend_service.dart';
import 'package:biometric_auth/services/ml_pipeline_service.dart';

void testBackendIntegration() async {
  final backend = BackendService();
  final mlPipeline = MLPipelineService();

  // 1. Verificar conexión
  final online = await backend.isOnline();
  print('Backend online: $online');

  // 2. Registrar usuario de prueba
  try {
    final user = await backend.registerUser(
      nombres: 'Test',
      apellidos: 'Usuario',
      identificadorUnico: 'test@example.com',
    );
    print('Usuario creado: ${user['id_usuario']}');
  } catch (e) {
    print('Error: $e');
  }

  // 3. Probar preprocesamiento de imagen
  final imageBytes = /* ... cargar imagen de prueba ... */;
  final preprocessed = await mlPipeline.preprocessEarImage(imageBytes);
  final quality = mlPipeline.validateEarImageQuality(preprocessed);
  print('Calidad de imagen: ${quality['is_valid']}');

  // 4. Registrar biometría de oreja
  try {
    final result = await backend.registerEarPhoto(
      idUsuario: user['id_usuario'],
      imageBytes: preprocessed,
      photoNumber: 1,
    );
    print('Oreja registrada: $result');
  } catch (e) {
    print('Error: $e');
  }
}
```

---

## 🐛 SOLUCIÓN DE PROBLEMAS

### Problema: "Backend no responde"

**Soluciones:**
1. Verificar URL en `environment_config.dart`
2. Verificar firewall/red
3. Revisar logs del backend
4. Intentar con Postman/curl directamente

```bash
# Test con curl
curl -X GET https://tu-backend.com/api/health
```

### Problema: "Error 401 Unauthorized"

**Soluciones:**
1. Verificar que el token JWT se está enviando
2. Revisar interceptor en `api_config.dart`
3. Verificar que el backend acepta el formato del token

### Problema: "Imagen rechazada por calidad"

**Soluciones:**
1. Mejorar iluminación
2. Evitar fotos borrosas
3. Ajustar umbrales en `ml_pipeline_service.dart`:

```dart
final isValid = brightness >= 40 &&  // Reducir umbral
                brightness <= 220 &&
                contrast >= 15 &&     // Reducir umbral
                sharpness >= 3;       // Reducir umbral
```

### Problema: "Audio no válido"

**Soluciones:**
1. Verificar formato WAV 16kHz mono
2. Verificar duración >= 5 segundos
3. Revisar permisos de micrófono

```dart
// En audio_service.dart
final config = RecordConfig(
  encoder: AudioEncoder.wav,
  bitRate: 128000,
  sampleRate: 16000,  // ← Debe ser 16000
  numChannels: 1,     // ← Debe ser 1 (mono)
);
```

---

## 📞 CONTACTO Y SOPORTE

Si tienes problemas con la integración:

1. **Revisar logs:** Todos los servicios imprimen logs con emojis (`🔄`, `✅`, `❌`)
2. **Debugging:** Habilitar modo verbose en `environment_config.dart`
3. **Tests:** Ejecutar test suite completo:

```bash
flutter test
```

4. **Documentación adicional:** Ver carpeta `/documentacion/`

---

## ✅ CHECKLIST DE INTEGRACIÓN

- [ ] Actualizar URL del backend en `environment_config.dart`
- [ ] Configurar API keys/tokens si es necesario
- [ ] Probar endpoint `/health` del backend
- [ ] Verificar formato de respuestas JSON
- [ ] Probar registro de usuario
- [ ] Probar registro de oreja (3 fotos)
- [ ] Probar verificación de oreja
- [ ] Probar registro de voz
- [ ] Probar verificación de voz
- [ ] Verificar sincronización SQLite ↔ PostgreSQL
- [ ] Probar modo offline
- [ ] Ejecutar tests automatizados
- [ ] Validar flujo completo de registro + login

---

## 🎯 PRÓXIMOS PASOS

1. **Recibir URL oficial** de tus compañeros
2. **Actualizar `environment_config.dart`** con la URL
3. **Probar conexión** con `backend.isOnline()`
4. **Validar endpoints** uno por uno
5. **Ajustar formatos** si es necesario
6. **Ejecutar tests** para confirmar funcionamiento
7. **Deploy a producción** 🚀

---

**¡Todo está listo para conectarse con el backend PostgreSQL!** 🎉
