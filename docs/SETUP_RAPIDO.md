# ⚡ Guía Rápida de Setup

Instalación y configuración en 10 minutos.

---

## 🏃 Setup Rápido Backend

### 1. Requisitos previos
```bash
# Verificar Node.js
node --version  # v18+
npm --version

# Verificar PostgreSQL
psql --version
```

### 2. Clonar e instalar
```bash
cd backend
npm install
```

### 3. Configurar Base de Datos
```bash
# Crear base de datos
createdb biometrics_db

# Ejecutar migraciones
npm run migrate
```

### 4. Configurar variables de entorno
```bash
cp .env.example .env

# Editar .env:
# PORT=3000
# DB_HOST=localhost
# DB_USER=postgres
# DB_PASSWORD=password
```

### 5. Iniciar servidor
```bash
npm run dev
```

✅ Backend corriendo en `http://localhost:3000`

---

## 📱 Setup Rápido Mobile (Flutter)

### 1. Requisitos previos
```bash
flutter --version    # 3.0+
dart --version       # 3.0+
```

### 2. Obtener dependencias
```bash
cd mobile_app
flutter pub get
```

### 3. Generar código
```bash
flutter pub run build_runner build
```

### 4. Actualizar URL del servidor
```dart
// lib/config/api_config.dart
static const String baseUrl = 'http://localhost:3000/api';
```

### 5. Compilar y ejecutar

**Para Android:**
```bash
flutter run
```

**Para iOS:**
```bash
flutter run -d ios
```

✅ App corriendo en tu dispositivo/emulador

---

## 🧪 Testing Rápido

### Probar Backend
```bash
# Verificar health
curl http://localhost:3000/health

# Login de prueba
curl -X POST http://localhost:3000/api/auth/login-basico \
  -H "Content-Type: application/json" \
  -d '{
    "identificador_unico": "test@example.com",
    "password": "test_password",
    "dispositivo_id": "test_device"
  }'

# Ping al sync
curl http://localhost:3000/api/sync/ping
```

### Probar Mobile
```bash
flutter test
```

---

## 📊 Verificar Setup

### Backend
- [ ] PostgreSQL conectada
- [ ] Migraciones ejecutadas
- [ ] Variables de entorno configuradas
- [ ] Servidor en puerto 3000
- [ ] Endpoints respondiendo

### Mobile
- [ ] Flutter version 3.0+
- [ ] Dependencias instaladas
- [ ] URL de servidor actualizada
- [ ] Código generado (build_runner)
- [ ] Emulador/dispositivo conectado

---

## 🔍 Troubleshooting Rápido

| Problema | Solución |
|----------|----------|
| `Module not found` | `npm install` o `flutter pub get` |
| `ECONNREFUSED` | Iniciar PostgreSQL: `pg_ctl start` |
| `Port 3000 in use` | `lsof -i :3000` y `kill` el proceso |
| `Flutter error` | `flutter clean && flutter pub get` |
| `Android build failed` | `cd android && ./gradlew clean` |

---

## ✨ Primeros pasos

1. **Crear usuario de prueba** (en BD)
```sql
INSERT INTO usuarios (nombres, apellidos, identificador_unico, estado)
VALUES ('Test', 'Usuario', 'test@example.com', 'activo');
```

2. **Agregar credencial biométrica** (simulada)
```sql
INSERT INTO credenciales_biometricas 
(id_usuario, tipo_biometria, template, version_algoritmo, estado)
VALUES (1, 'audio', '\x1234567890'::bytea, 'v1.0', 'activo');
```

3. **Hacer login desde la app**
   - ID: `test@example.com`
   - Tipo: Voz/Oreja/Palma
   - Confianza: 0.9

---

## 📚 Pasos Siguientes

1. Leer documentación completa en `README.md`
2. Revisar endpoints en `docs/API.md`
3. Implementar biometría real en `docs/BIOMETRIC_INTEGRATION.md`
4. Configurar producción en `.env`

---

**¿Listo para comenzar?** 🚀

```bash
# Terminal 1: Backend
cd backend && npm run dev

# Terminal 2: Mobile
cd mobile_app && flutter run
```

---

**Última actualización**: 25 de Noviembre de 2025
