# 🔐 Aplicación Biométrica Multiplataforma

Sistema completo de autenticación biométrica con sincronización offline/online, reconocimiento de voz, oreja y huella palmar.

## 🎯 Características Principales

### 1. **Autenticación Biométrica Multimodal**
- ✅ **Reconocimiento de Voz**: Con frases dinámicas
- ✅ **Reconocimiento de Oreja**: Análisis de características faciales
- ✅ **Huella Palmar**: Extracción de características palmares

### 2. **Sistema de Sincronización Inteligente**
- 📱 **Modo Offline Completo**: Funciona sin conexión
- 🔄 **Sincronización Automática**: Cuando hay conexión disponible
- ⚡ **Reintentos Automáticos**: Con backoff exponencial
- 🔒 **Base de Datos Cifrada**: AES-256 con SQLCipher

### 3. **Seguridad Avanzada**
- 🔐 **Cifrado End-to-End**: HTTPS + TLS 1.2+
- 🎫 **JWT + Refresh Tokens**: Autenticación segura
- 🛡️ **Templates Biométricos Protegidos**: Nunca se envían en crudo
- 📍 **Rastreo de Ubicación**: Registro de validaciones con GPS

### 4. **Gestión de Errores Robusta**
- Detección de conectividad en tiempo real
- Manejo de fallos de sincronización
- Cola persistente de operaciones pendientes
- Logs detallados de errores

---

## 📦 Estructura del Proyecto

```
biometrias/
├── backend/                          # Servidor Node.js + Express
│   ├── src/
│   │   ├── index.js                 # Punto de entrada
│   │   ├── config/
│   │   │   └── database.js          # Configuración PostgreSQL
│   │   ├── controllers/
│   │   │   ├── AuthController.js    # Lógica de autenticación
│   │   │   └── SincronizacionController.js
│   │   ├── models/
│   │   │   ├── Usuario.js
│   │   │   ├── CredencialBiometrica.js
│   │   │   └── ValidacionBiometrica.js
│   │   ├── middleware/
│   │   │   └── auth.js              # Middleware JWT
│   │   └── routes/
│   │       ├── authRoutes.js
│   │       └── syncRoutes.js
│   ├── migrations/
│   │   └── 001_init_schema.sql      # Esquema PostgreSQL
│   ├── package.json
│   └── .env.example
│
├── mobile_app/                       # App Flutter
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config/
│   │   │   ├── api_config.dart      # Configuración API REST
│   │   │   └── database_config.dart # SQLite cifrado
│   │   ├── models/
│   │   │   ├── user.dart
│   │   │   └── biometric_models.dart
│   │   ├── services/
│   │   │   ├── local_database_service.dart
│   │   │   ├── sync_manager.dart    # Gestor de sincronización
│   │   │   └── biometric_service.dart
│   │   ├── screens/
│   │   │   └── login_screen.dart
│   │   ├── widgets/
│   │   ├── providers/
│   │   └── utils/
│   ├── android/app/src/main/cpp/    # Código nativo C++
│   ├── pubspec.yaml                 # Dependencias Flutter
│   └── docs/
│
└── docs/                             # Documentación
    ├── SETUP.md
    ├── API.md
    ├── ARCHITECTURE.md
    └── BIOMETRIC_INTEGRATION.md
```

---

## 🚀 Instalación y Setup

### Backend (Node.js + PostgreSQL)

#### Requisitos
- Node.js v18+
- PostgreSQL 12+
- npm o yarn

#### Pasos

1. **Navegar al directorio del backend**
```bash
cd backend
```

2. **Instalar dependencias**
```bash
npm install
```

3. **Configurar variables de entorno**
```bash
cp .env.example .env
# Editar .env con tus valores
```

4. **Crear base de datos PostgreSQL**
```bash
createdb biometrics_db
```

5. **Ejecutar migraciones**
```bash
npm run migrate
```

6. **Iniciar el servidor**
```bash
npm run dev        # Desarrollo con nodemon
npm start          # Producción
```

El servidor estará disponible en `http://localhost:3000`

---

### Aplicación Móvil (Flutter)

#### Requisitos
- Flutter SDK 3.0+
- Dart SDK 3.0+
- Android SDK 21+ (para Android)
- Xcode 12+ (para iOS)

#### Pasos

1. **Navegar al directorio de la app móvil**
```bash
cd mobile_app
```

2. **Obtener dependencias**
```bash
flutter pub get
```

3. **Generar archivos de código**
```bash
flutter pub run build_runner build
```

4. **Actualizar URL del servidor en `lib/config/api_config.dart`**
```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:3000/api';
```

5. **Compilar para Android**
```bash
flutter build apk --release
# o para app bundle
flutter build appbundle --release
```

6. **Compilar para iOS**
```bash
flutter build ios --release
```

---

## 🔐 Flujo de Autenticación Biométrica

### 1. **Captura de Biometría**
```
┌─────────────┐
│   Usuario   │
└──────┬──────┘
       │ Selecciona tipo de biometría
       ▼
┌────────────────────┐
│  Captura de datos  │
│  (Voz/Oreja/Palma) │
└────────┬───────────┘
         │
         ▼
┌──────────────────────────┐
│  Extracción de Features  │
│  (MFCC/CNN/SIFT/SURF)    │
└────────┬─────────────────┘
         │
         ▼
┌────────────────────────┐
│  Comparación con       │
│  Template local (BD)   │
└────────┬───────────────┘
         │
         ▼
    ┌────────────┐
    │ ¿Coincide? │
    └────┬──────┬┘
         │      │
         ▼      ▼
      SÍ       NO
       │        │
       ▼        ▼
    Genera   Registra
    JWT      Error
     │        │
     ▼        ▼
   Login    Reintento
```

### 2. **Sincronización Offline/Online**

```
┌──────────────────────┐
│  Validación realizada│
│  (Offline/Online)    │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────┐
│  Guardar en Base de Datos│
│  Local (SQLCipher)       │
└──────────┬───────────────┘
           │
           ▼
┌─────────────────────────────┐
│  Monitor de Conectividad    │
│  (Cada 5 minutos)           │
└──────────┬──────────────────┘
           │
           ▼
    ┌─────────────┐
    │ ¿Conexión?  │
    └────┬───┬────┘
         │   │
         ▼   ▼
        SÍ   NO
         │    │
         ▼    ▼
      Ping  Esperar
        │    │
        ▼    ▼
    Servidor  (Buffer local)
    Disponible
        │
        ▼
   Sincronizar
```

---

## 📚 Endpoints de API

### Autenticación

```http
POST /api/auth/login
Content-Type: application/json

{
  "identificador_unico": "user@example.com",
  "tipo_biometria": "audio",
  "puntuacion_confianza": 0.92,
  "dispositivo_id": "device_123",
  "ubicacion_gps": "40.7128,-74.0060"
}

Response: 200 OK
{
  "mensaje": "Autenticación exitosa",
  "usuario": {...},
  "tokens": {
    "accessToken": "jwt_token...",
    "refreshToken": "refresh_token...",
    "expiresIn": 3600
  }
}
```

### Sincronización

```http
POST /api/sync/descarga
Authorization: Bearer {accessToken}
Content-Type: application/json

{
  "id_usuario": 1,
  "ultima_sync": "2025-11-25T10:30:00Z",
  "dispositivo_id": "device_123"
}

Response: 200 OK
{
  "success": true,
  "datos": {
    "usuarios": [...],
    "credenciales_biometricas": [...],
    "textos_audio": [...]
  }
}
```

---

## 🧪 Testing

### Backend
```bash
npm test                 # Ejecutar todos los tests
npm test -- --coverage  # Con cobertura
npm test -- --watch    # Watch mode
```

### Mobile
```bash
flutter test                    # Todos los tests
flutter test --coverage        # Con cobertura
flutter test -v                # Verbose mode
```

---

## 🔧 Configuración Avanzada

### Variables de Entorno (.env)

```env
# Servidor
PORT=3000
NODE_ENV=production

# Base de datos
DB_HOST=postgres.example.com
DB_PORT=5432
DB_USER=biometrics_user
DB_PASSWORD=secure_password
DB_NAME=biometrics_db

# Seguridad
JWT_SECRET=your_super_secret_jwt_key_here
REFRESH_TOKEN_SECRET=your_refresh_token_secret

# Librerías Biométricas
AZURE_SPEECH_KEY=your_azure_key
AZURE_SPEECH_REGION=eastus

# Sincronización
SYNC_RETRY_INTERVAL=300
MAX_SYNC_RETRIES=5
SYNC_TIMEOUT=30000
```

---

## 📊 Monitoreo y Logs

### Backend Logs
```bash
# Logs en tiempo real
tail -f logs/app.log

# Filtrar por nivel
grep "ERROR" logs/app.log
grep "WARN" logs/app.log
```

### Mobile Logs
```bash
flutter logs                    # Logs en tiempo real
flutter logs --clear            # Limpiar logs anteriores
flutter logs | grep "YOUR_TAG" # Filtrar por tag
```

---

## 🚨 Troubleshooting

### Backend

**Error: "ENOENT: no such file or directory, open '.env'"**
```bash
cp .env.example .env
# Editar .env con valores correctos
```

**Error: "Connection refused" a PostgreSQL**
- Verificar que PostgreSQL está corriendo
- Verificar credenciales en .env
- Verificar puerto 5432

**Error: "CORS issue"**
- Actualizar CORS_ORIGIN en .env
- Reiniciar servidor

### Mobile

**Error: "Packages out of date"**
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

**Error: "Build failed on Android"**
```bash
flutter clean
./gradlew clean  # En android/
flutter build apk
```

**Error: "Packages cannot be imported"**
```bash
flutter pub get
flutter pub run build_runner build
flutter pub upgrade
```

---

## 📈 Performance y Optimización

### Backend
- Connection pooling configurado
- Índices en tablas principales
- Compresión gzip habilitada
- Timeouts configurados

### Mobile
- Base de datos local cifrada (SQLCipher)
- Sync automático cada 5 minutos
- Backoff exponencial en reintentos
- Limpieza de datos antiguos

---

## 🔒 Seguridad

### Medidas Implementadas
✅ Cifrado AES-256 en base de datos local
✅ HTTPS/TLS 1.2+ en comunicaciones
✅ JWT con tokens cortos (1 hora)
✅ Refresh tokens (7 días)
✅ Validación de integridad de templates
✅ Never log sensitive biometric data

### Best Practices
- Cambiar JWT_SECRET en producción
- Usar HTTPS en producción
- Habilitar CORS solo para dominios autorizados
- Implementar rate limiting
- Auditar logs regularmente

---

## 📞 Soporte

Para reportar problemas o sugerencias:
1. Abrir issue en GitHub
2. Incluir logs y stacktrace
3. Especificar versión de OS y SDK
4. Incluir pasos para reproducir

---

## 📄 Licencia

MIT License - Ver archivo LICENSE

---

## 👥 Contribuciones

Las contribuciones son bienvenidas. Por favor:
1. Fork el proyecto
2. Crear rama feature (`git checkout -b feature/AmazingFeature`)
3. Commit cambios (`git commit -m 'Add AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abrir Pull Request

---

**Última actualización**: 25 de Noviembre de 2025
