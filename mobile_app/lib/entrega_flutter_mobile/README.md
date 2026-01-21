# Entrega: Libreria Biometrica para Flutter
**Fecha:** 20/01/2026 23:10
**Version:** 1.0.0-mobile

## Contenido del Paquete

```
entrega_flutter_mobile/
├── libraries/
│   └── android/
│       └── arm64-v8a/
│           ├── libvoz_mobile.so      [Libreria principal FFI]
│           └── libsqlite3_local.a    [SQLite estatica]
│
├── assets/
│   ├── models/v1/
│   │   ├── class_*.bin              [68 archivos - Pesos SVM]
│   │   └── metadata.json            [Metadatos del modelo]
│   │
│   └── caracteristicas/v1/
│       ├── caracteristicas_train.dat [Dataset entrenamiento]
│       └── caracteristicas_test.dat  [Dataset validacion]
│
├── documentation/
│   ├── mobile_api.h                 [Header C de la API]
│   ├── ENTREGA_EQUIPO_FLUTTER.md    [LEER PRIMERO]
│   ├── INTEGRACION_FLUTTER_FFI.md   [Guia de integracion]
│   ├── SINCRONIZACION_OFFLINE_ONLINE.md
│   └── RESUMEN_EJECUTIVO_MOBILE.md
│
└── README.md                         [Este archivo]
```

## Instrucciones de Instalacion

### 1. Copiar Libreria Nativa

```bash
# En tu proyecto Flutter
mkdir -p android/app/src/main/jniLibs/arm64-v8a
cp libraries/android/arm64-v8a/libvoz_mobile.so android/app/src/main/jniLibs/arm64-v8a/
```

### 2. Copiar Assets (Modelos y Datasets)

```bash
# Copiar modelos SVM
mkdir -p android/app/src/main/assets/models/v1
cp -r assets/models/v1/* android/app/src/main/assets/models/v1/

# Copiar caracteristicas
mkdir -p android/app/src/main/assets/caracteristicas/v1
cp -r assets/caracteristicas/v1/* android/app/src/main/assets/caracteristicas/v1/
```

### 3. Configurar pubspec.yaml

```yaml
dependencies:
  ffi: ^2.0.0
  path_provider: ^2.0.0
  shared_preferences: ^2.0.0

flutter:
  assets:
    - assets/models/v1/
    - assets/caracteristicas/v1/
```

### 4. Leer Documentacion

1. **ENTREGA_EQUIPO_FLUTTER.md** → Guia completa de integracion
2. **INTEGRACION_FLUTTER_FFI.md** → Codigo Dart detallado
3. **mobile_api.h** → Referencia de API C

## Tamaño Total

- Libreria: ~26 MB
- Modelos SVM: ~25 MB
- Datasets: ~150 MB
- **Total: ~201 MB**

## Soporte

Para preguntas o problemas, contactar al equipo de backend.

## Version

- **Libreria:** 1.0.0-mobile
- **Compilada:** 20/01/2026
- **NDK:** Android NDK 29.0.16803605
- **Arquitectura:** arm64-v8a (64-bit)
