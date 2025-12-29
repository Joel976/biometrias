```
biometrias/                                    # Raíz del proyecto
│
├── 📖 README.md                               # Documentación principal
├── 📋 PROYECTO_COMPLETADO.md                  # Resumen de entrega
├── 🚀 init.sh                                 # Script de inicialización
├── .gitignore                                 # Configuración Git
│
├── backend/                                   # 🔙 Servidor Backend
│   ├── package.json                           # Dependencias y scripts
│   ├── .env.example                           # Plantilla de variables de entorno
│   │
│   ├── src/
│   │   ├── index.js                           # Punto de entrada del servidor
│   │   │
│   │   ├── config/
│   │   │   └── database.js                    # Configuración PostgreSQL
│   │   │
│   │   ├── controllers/
│   │   │   ├── AuthController.js              # Lógica de autenticación biométrica
│   │   │   │   ├── loginBiometrico()          # Login con voz/oreja/palma
│   │   │   │   ├── loginBasico()              # Login usuario/contraseña
│   │   │   │   └── logout()                   # Cerrar sesión
│   │   │   │
│   │   │   └── SincronizacionController.js    # Gestión de sincronización
│   │   │       ├── obtenerDatosDescarga()    # Descargar del backend
│   │   │       ├── recibirDatosSubida()      # Subir desde app
│   │   │       └── obtenerEstadoSync()       # Ver estado
│   │   │
│   │   ├── models/
│   │   │   ├── Usuario.js                     # Modelo de Usuario
│   │   │   │   ├── crear()
│   │   │   │   ├── obtenerPorId()
│   │   │   │   └── actualizar()
│   │   │   │
│   │   │   ├── CredencialBiometrica.js        # Gestión de templates biométricos
│   │   │   │   ├── crear()
│   │   │   │   ├── obtenerPorUsuarioYTipo()
│   │   │   │   └── verificarIntegridad()
│   │   │   │
│   │   │   └── ValidacionBiometrica.js        # Registro de validaciones
│   │   │       ├── registrar()
│   │   │       ├── obtenerPorUsuario()
│   │   │       └── obtenerEstadisticas()
│   │   │
│   │   ├── middleware/
│   │   │   └── auth.js                        # JWT y autenticación
│   │   │       ├── authenticateToken()
│   │   │       └── refreshToken()
│   │   │
│   │   └── routes/
│   │       ├── authRoutes.js                  # Rutas de autenticación
│   │       │   ├── POST /login
│   │       │   ├── POST /login-basico
│   │       │   └── POST /logout
│   │       │
│   │       └── syncRoutes.js                  # Rutas de sincronización
│   │           ├── POST /descarga
│   │           ├── POST /subida
│   │           └── GET /estado
│   │
│   └── migrations/
│       └── 001_init_schema.sql                # Esquema PostgreSQL completo
│           ├── usuarios
│           ├── credenciales_biometricas
│           ├── textos_dinamicos_audio
│           ├── validaciones_biometricas
│           ├── dispositivos_app
│           ├── sincronizaciones
│           ├── cola_sincronizacion
│           ├── errores_sync
│           ├── sesiones
│           └── logs_auditoria
│
├── mobile_app/                                # 📱 Aplicación Móvil Flutter
│   ├── pubspec.yaml                           # Dependencias y configuración
│   │
│   ├── lib/
│   │   ├── main.dart                          # Punto de entrada
│   │   │
│   │   ├── config/
│   │   │   ├── api_config.dart                # Configuración de API REST
│   │   │   │   ├── inicializarDio()
│   │   │   │   ├── saveTokens()
│   │   │   │   └── interceptores
│   │   │   │
│   │   │   └── database_config.dart           # SQLite cifrado con SQLCipher
│   │   │       ├── _initDatabase()
│   │   │       ├── _createTables()
│   │   │       └── encryptData()
│   │   │
│   │   ├── models/
│   │   │   ├── user.dart                      # Modelo de usuario (Freezed)
│   │   │   │
│   │   │   └── biometric_models.dart          # Modelos biométricos
│   │   │       ├── BiometricCredential        # Template de credencial
│   │   │       ├── AudioPhrase                # Frase para validación
│   │   │       ├── BiometricValidation       # Resultado de validación
│   │   │       └── SyncState                  # Estado de sincronización
│   │   │
│   │   ├── services/
│   │   │   ├── local_database_service.dart    # Acceso a BD local
│   │   │   │   ├── insertBiometricCredential()
│   │   │   │   ├── getCredentialsByUserAndType()
│   │   │   │   ├── insertValidation()
│   │   │   │   └── getPendingSyncQueue()
│   │   │   │
│   │   │   ├── sync_manager.dart              # Gestor de sincronización automático
│   │   │   │   ├── startAutoSync()
│   │   │   │   ├── performSync()
│   │   │   │   ├── _uploadData()
│   │   │   │   ├── _downloadData()
│   │   │   │   └── _retryWithBackoff()
│   │   │   │
│   │   │   └── biometric_service.dart         # Procesamiento biométrico
│   │   │       ├── validateVoice()            # Validación de voz
│   │   │       │   ├── extractMFCC()
│   │   │       │   └── compareAudioFeatures()
│   │   │       ├── validateEar()              # Validación de oreja
│   │   │       │   ├── detectEar()
│   │   │       │   └── extractEarFeatures()
│   │   │       └── validatePalm()             # Validación de palma
│   │   │           ├── detectPalm()
│   │   │           └── extractPalmFeatures()
│   │   │
│   │   ├── screens/
│   │   │   └── login_screen.dart              # Pantalla de autenticación
│   │   │       ├── Selector de tipo biométrico
│   │   │       ├── Captura de identificador
│   │   │       └── Botón de autenticación
│   │   │
│   │   ├── widgets/                           # Componentes reutilizables
│   │   │   └── (expandible)
│   │   │
│   │   ├── providers/                         # State management (expandible)
│   │   │   └── (expandible)
│   │   │
│   │   └── utils/                             # Utilidades
│   │       └── (expandible)
│   │
│   ├── android/
│   │   └── app/src/main/cpp/                 # Código nativo C++
│   │       ├── biometric_manager.h            # Cabecera principal
│   │       ├── biometric_manager.cpp          # Implementación
│   │       ├── extractor_voice.cpp            # Extractor de voz
│   │       ├── extractor_ear.cpp              # Detector de oreja
│   │       └── extractor_palm.cpp             # Extractor de palma
│   │
│   ├── test/                                  # Tests unitarios
│   │   └── (expandible)
│   │
│   └── docs/                                  # Documentación de app
│       └── (expandible)
│
├── docs/                                      # 📚 Documentación del Proyecto
│   ├── API.md                                 # Referencia completa de endpoints
│   │   ├── Autenticación
│   │   ├── Sincronización
│   │   ├── Códigos de error
│   │   └── Ejemplos en múltiples lenguajes
│   │
│   ├── BIOMETRIC_INTEGRATION.md               # Integración de biometría
│   │   ├── Reconocimiento de voz
│   │   │   ├── Microsoft Azure
│   │   │   └── DeepSpeech
│   │   ├── Reconocimiento de oreja
│   │   │   ├── OpenCV
│   │   │   └── TensorFlow Lite
│   │   ├── Reconocimiento de palma
│   │   │   ├── MegaMatcher
│   │   │   └── Extractor personalizado
│   │   ├── Código C++
│   │   └── CMakeLists.txt
│   │
│   └── SETUP_RAPIDO.md                       # Guía rápida de instalación
│       ├── Setup Backend
│       ├── Setup Mobile
│       └── Testing
│
└── init.sh                                    # Script de inicialización automática
```

---

## 🗂️ Tamaño y Complejidad

| Componente | Archivos | Líneas | Complejidad |
|-----------|----------|--------|------------|
| Backend | 10 | ~2500 | Media |
| Mobile | 12 | ~3000 | Media-Alta |
| BD Schema | 1 | ~300 | Media |
| Documentación | 4 | ~2000 | Alta |
| **TOTAL** | **27** | **~7800** | **Media-Alta** |

---

## 📊 Flujo de Datos

```
┌─────────────────────────────────────────────────────────────┐
│                      USUARIO                                 │
└────────┬──────────────────────────────────────────┬──────────┘
         │                                          │
         ▼                                          ▼
    ┌─────────────┐                        ┌──────────────┐
    │ Captura de  │                        │  Login Básico │
    │  Biometría  │                        │              │
    │             │                        │ Usuario/Pass │
    └────┬────────┘                        └────┬─────────┘
         │                                      │
         ▼                                      ▼
    ┌──────────────────────────────────────────────┐
    │         AuthController                       │
    │  ├─ validateBiometric()                      │
    │  ├─ compareWithTemplate()                    │
    │  └─ generateJWT()                            │
    └────┬──────────────────────────────┬──────────┘
         │                              │
         ▼                              ▼
    ┌──────────────────────────────────────────────┐
    │     Sesión + Tokens (JWT + Refresh)          │
    │     Almacenados en BD (sesiones)             │
    └────┬──────────────────────────────┬──────────┘
         │                              │
         ▼                              ▼
    ┌──────────────────────────────────────────────┐
    │    SyncManager (Sincronización Auto)          │
    │  ├─ Monitoreo de conectividad                 │
    │  ├─ Upload de datos local                     │
    │  ├─ Download de datos nuevo                   │
    │  └─ Reintentos con backoff                    │
    └────┬──────────────────────────────┬──────────┘
         │                              │
         ▼                              ▼
    ┌──────────────────────────────────────────────┐
    │      Validaciones Registradas                 │
    │      (BD Local + BD Remota)                   │
    │  ├─ Timestamp                                 │
    │  ├─ Resultado                                 │
    │  ├─ Confianza                                 │
    │  └─ Ubicación GPS                             │
    └──────────────────────────────────────────────┘
```

---

## 🔄 Ciclo de Sincronización

```
OFFLINE              ONLINE              SYNC COMPLETE
┌────────┐          ┌────────┐          ┌────────┐
│ Upload │ ─────→ │ Ping   │ ─────→ │ Verify │
│ Local  │        │ Server │        │        │
└────────┘        └────────┘        └────────┘
     ▲                                    │
     │                                    ▼
     │            ┌────────┐         ┌────────┐
     └─ Retry ── │ Upload │ ─────→ │Download│
                 │ Data   │        │ Data   │
                 └────────┘        └────────┘
                                        │
                                        ▼
                                   ┌────────┐
                                   │Update  │
                                   │  DB    │
                                   └────────┘
```

---

## 🔐 Capas de Seguridad

```
┌─────────────────────────────────────────────┐
│         APLICACIÓN MÓVIL                     │
├─────────────────────────────────────────────┤
│  Biometric Extraction + Local Comparison     │
│  (Templates nunca se envían en crudo)       │
├─────────────────────────────────────────────┤
│  SQLCipher (Cifrado AES-256)                │
│  (BD Local cifrada)                         │
├─────────────────────────────────────────────┤
│  Flutter Secure Storage                      │
│  (Tokens almacenados seguramente)           │
├─────────────────────────────────────────────┤
│             HTTPS / TLS 1.2+                │
│         (Comunicación cifrada)              │
├─────────────────────────────────────────────┤
│         BACKEND (SERVIDOR)                   │
├─────────────────────────────────────────────┤
│  JWT Authentication (Tokens cortos)         │
│  (1 hora accessToken, 7 días refreshToken)  │
├─────────────────────────────────────────────┤
│  CORS + Rate Limiting (Ready)               │
├─────────────────────────────────────────────┤
│  PostgreSQL (BD robusta)                    │
│  con validación de integridad               │
└─────────────────────────────────────────────┘
```

---

**¡Proyecto completo y documentado!** ✨
```
