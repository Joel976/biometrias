# 🚀 Guía Rápida de Inicio

## En 5 Minutos

### **Terminal 1: Backend**
```bash
cd backend
npm run migrate  # Ejecutar migraciones Postgres
npm run start    # Escucha en http://localhost:3000
```

**Verificar que está corriendo:**
```bash
curl http://localhost:3000/api/sync/ping
# Respuesta esperada: {"success":true,"timestamp":"...","servidor":"disponible"}
```

---

### **Terminal 2: Mobile App**
```bash
cd mobile_app
flutter clean
flutter pub get
flutter run
```

**Si el simulador/device no está conectado:**
```bash
# Listar devices
flutter devices

# Conectar a un device específico
flutter run -d <device_id>
```

---

## 🧪 Test Rápido: Registro Offline → Sync

### **Test 1: Registro Sin Internet**

1. **Desconecta el device del WiFi:**
   - Settings → WiFi → Turn Off
   - Settings → Mobile Data → Turn Off

2. **Abre la app y ve a RegisterScreen:**
   - Click "¿No tienes cuenta? Regístrate"

3. **Completa el formulario:**
   - Nombres: `Juan`
   - Apellidos: `Pérez`
   - Email: `juan@example.com`
   - ID Único (Cédula): `12345678`
   - Contraseña: `password123`

4. **Paso 2: Captura 3 fotos de oreja:**
   - Click "Capturar Oreja 1" → Abre cámara → Toma foto
   - Repite para Oreja 2 y 3

5. **Paso 3: Graba audio de voz:**
   - Click micrófono → Graba frase: "Mi contraseña es segura"
   - Click micrófono nuevamente para detener

6. **Click "Registrarse":**
   - Debe mostrar: **"✗ Sin internet. Registro guardado localmente. Se sincronizará cuando recuperes conexión."**
   - Vuelve automáticamente a Login tras 2 segundos

### **Verificar que se guardó en SQLite local:**

```bash
# En otra terminal, conectado al device
adb shell sqlite3 /data/data/com.example.biometrics_app/databases/biometrics_local.db

# Dentro de sqlite3:
SELECT id_usuario, nombres, apellidos, local_uuid, remote_id FROM usuarios;
-- Resultado esperado:
-- 1|Juan|Pérez|local-1699500000000-9999|null

SELECT id_cola, tipo_entidad, estado FROM cola_sincronizacion;
-- Resultado esperado:
-- 1|usuario|pendiente
-- 2|credencial|pendiente
-- 3|credencial|pendiente
-- 4|credencial|pendiente
-- 5|credencial|pendiente

.exit
```

### **Test 2: Sync Cuando Reconectes a Internet**

1. **Reconecta el WiFi:**
   - Settings → WiFi → Select your_wifi → Connect

2. **La app debe disparar automáticamente SyncManager:**
   - Observa logs en terminal (flutter run):
     ```
     I/flutter: Sincronización exitosa
     I/flutter: Mappings recibidos del backend
     ```

3. **Backend debe mostrar logs:**
   ```
   POST /api/sync/subida
   Insertados 1 usuarios, 5 credenciales
   Retornando 6 mappings...
   ```

4. **Verifica SQLite nuevamente:**
   ```bash
   adb shell sqlite3 /data/data/com.example.biometrics_app/databases/biometrics_local.db
   SELECT id_usuario, nombres, apellidos, local_uuid, remote_id FROM usuarios;
   -- Resultado esperado (ahora con remote_id):
   -- 1|Juan|Pérez|local-1699500000000-9999|42
   
   SELECT id_cola, estado FROM cola_sincronizacion;
   -- Resultado esperado:
   -- 1|enviado
   -- 2|enviado
   -- ...
   ```

5. **Verifica Postgres remoto:**
   ```bash
   psql -U postgres -d biometrics_db -h localhost
   
   SELECT id_usuario, nombres, apellidos FROM usuarios WHERE nombres='Juan';
   -- Resultado esperado:
   -- 42|Juan|Pérez
   
   SELECT COUNT(*) FROM credenciales_biometricas WHERE id_usuario=42;
   -- Resultado esperado: 5
   ```

---

## ⚙️ Configuración Necesaria

### **Backend: Variables de Entorno (.env)**

Crear archivo `backend/.env`:
```env
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=<tu_password>
DB_NAME=biometrics_db
PORT=3000
```

### **Mobile: API Base URL**

El archivo `lib/config/api_config.dart` ya tiene:
```dart
static const String baseUrl = 'http://192.168.0.6:3000/api';
```

**Si tu IP de backend es diferente:**
1. Descubre tu IP:
   ```bash
   # En la máquina del backend
   ipconfig  # Windows
   ifconfig  # Mac/Linux
   # Busca "IPv4 Address" o "inet" en la red local
   ```

2. Actualiza en `lib/config/api_config.dart`:
   ```dart
   static const String baseUrl = 'http://TU_IP:3000/api';
   ```

3. Reconstruye la app:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

---

## 📊 Flujo Visual

```
┌─────────────────────────────────────────────────────────┐
│ SIN INTERNET                                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  User abre RegisterScreen                              │
│       ↓                                                 │
│  Completa formulario + captura biometría              │
│       ↓                                                 │
│  Click "Registrar"                                    │
│       ↓                                                 │
│  App detecta sin conexión                            │
│       ↓                                                 │
│  INSERT usuarios en SQLite (con local_uuid)           │
│       ↓                                                 │
│  INSERT cola_sincronizacion (tipo=usuario/credencial) │
│       ↓                                                 │
│  Muestra: "Guardado localmente"                       │
│       ↓                                                 │
│  Vuelve a LoginScreen                                 │
│                                                         │
│  Estado: ✓ Usuario en SQLite, ✗ No en Postgres      │
│                                                         │
└─────────────────────────────────────────────────────────┘
              [Reconecta a Internet]
              ↓
┌─────────────────────────────────────────────────────────┐
│ CON INTERNET                                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  App dispara SyncManager.performSync()                │
│       ↓                                                 │
│  Lee cola_sincronizacion (estado=pendiente)           │
│       ↓                                                 │
│  POST /sync/subida con creaciones                     │
│       ↓                                                 │
│  Backend:                                              │
│    - INSERT usuarios → id=42                          │
│    - INSERT credenciales → id=99-103                  │
│    - Retorna mappings                                 │
│       ↓                                                 │
│  App actualiza SQLite:                                │
│    - UPDATE usuarios SET remote_id=42 WHERE local_uuid=... │
│    - UPDATE credenciales SET remote_id=99 WHERE ...  │
│    - UPDATE cola SET estado=enviado                   │
│       ↓                                                 │
│  Muestra: "✓ Sincronización exitosa"                 │
│                                                         │
│  Estado: ✓ Usuario en SQLite, ✓ Usuario en Postgres │
│          ✓ IDs mapeados, ✓ Cola enviada             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🔍 Comandos Útiles

### **SQLite Local (Desde ADB)**
```bash
# Conectar a device
adb shell

# Acceder a SQLite
sqlite3 /data/data/com.example.biometrics_app/databases/biometrics_local.db

# Queries útiles:
.schema usuarios                          # Ver estructura
SELECT * FROM usuarios;                   # Ver usuarios
SELECT * FROM cola_sincronizacion;        # Ver cola pendiente
SELECT * FROM cola_sincronizacion WHERE estado='enviado';  # Ver enviados

.exit                                     # Salir
```

### **PostgreSQL Remoto**
```bash
# Conectar
psql -U postgres -d biometrics_db -h 192.168.0.6

# Queries útiles:
SELECT * FROM usuarios;
SELECT * FROM credenciales_biometricas WHERE id_usuario=<id>;
SELECT * FROM validaciones_biometricas;
SELECT * FROM sincronizaciones;

\q  # Salir
```

### **Logs de Flutter**
```bash
# En terminal con flutter run:
flutter logs  # Ver todos los logs

# Filtrar por app:
flutter logs | grep flutter
```

### **Network en Backend**
```bash
# Monitorear requests HTTP
# En logs de Node.js (ya configurado con console.log):
tail -f backend/logs/server.log  # Si existe
# O ver directamente en consola de `npm run start`
```

---

## ❌ Si Algo Falla

### **"Error: usuario no encontrado" en login**
```
→ Verifica que RegisterScreen ejecutó insertUser()
→ Verifica que apellidos no son vacíos (UNIQUE constraint en BD)
```

### **"Error de conexión en sync"**
```
→ Verifica backend está corriendo: curl http://192.168.0.6:3000/api/sync/ping
→ Verifica app tiene IP correcta en api_config.dart
→ Verifica teléfono está en misma red que backend
```

### **"JSON decode error"**
```
→ Verifica que cola_sincronizacion tiene datos_json como JSON válido
→ Verifica offline_sync_service.dart usa jsonEncode()
```

### **"remote_id sigue siendo NULL después de sync"**
```
→ Verifica backend retorna "mappings" en response
→ Verifica SyncManager procesa response.data['mappings']
→ Verifica updateUserRemoteIdByLocalUuid() se ejecuta
```

---

## 📱 Flujo de Usuario Final

```
┌──────────────────┐
│  App Inicia      │
└────────┬─────────┘
         │
         ├─ ¿Usuario registrado?
         │  ├─ SÍ → LoginScreen
         │  └─ NO → RegisterScreen
         │
┌────────┴──────────────────────────┐
│ RegisterScreen                    │
├───────────────────────────────────┤
│ Step 1: Datos Personales         │
│ Step 2: 3 Fotos de Oreja         │
│ Step 3: Grabación de Voz         │
│ → Click "Registrar"              │
│                                   │
│ ¿Hay conexión?                    │
│ ├─ SÍ: POST /auth/register       │
│ │      INSERT usuario remoto      │
│ │      → Success                  │
│ │                                  │
│ └─ NO: INSERT usuario local       │
│       INSERT cola_sincronizacion  │
│       → Guardado localmente       │
│                                   │
└────────┬──────────────────────────┘
         │ (Vuelve a LoginScreen)
         │
┌────────┴──────────────────────────┐
│ LoginScreen                       │
├───────────────────────────────────┤
│ Opción 1: Login Local             │
│   GET usuario_local               │
│   BiometricService.verify()       │
│   INSERT validacion_local         │
│   INSERT cola (validacion)        │
│                                   │
│ Opción 2: Login Remoto            │
│   POST /auth/verify-X             │
│   Backend valida                  │
│   → HomeScreen                    │
│                                   │
│ ¿Hay conexión?                    │
│ ├─ SÍ: Intenta remoto primero    │
│ │       If fail → fallback local   │
│ │                                  │
│ └─ NO: Usa local directamente     │
│                                   │
└────────┬──────────────────────────┘
         │
┌────────┴──────────────────────────┐
│ HomeScreen                        │
├───────────────────────────────────┤
│ Muestra conectividad              │
│ Muestra # de items pendientes     │
│ Auto-sync cada 5 min (si conectado)│
│ Manual sync (botón)               │
│                                   │
└───────────────────────────────────┘
```

---

## ✅ Checklist de Verificación

- [ ] Backend corre en terminal 1
- [ ] App corre en terminal 2 (o simulador)
- [ ] Teléfono/simulator tiene WiFi desconectado
- [ ] Completa registro offline
- [ ] Verifica SQLite local (usuario + cola)
- [ ] Reconecta WiFi
- [ ] Sync dispara automáticamente
- [ ] Verifica SQLite (remote_id poblado)
- [ ] Verifica Postgres (usuario existe)
- [ ] Verifica cola (estado=enviado)
- [ ] Login funciona offline
- [ ] Login funciona online

**Si todo está ✓, la sincronización está correctamente implementada.**

---

## 📞 Soporte Rápido

| Problema | Verificar |
|----------|-----------|
| App no conecta a backend | IP en `api_config.dart`, Backend corriendo |
| Usuario no se guarda localmente | `RegisterScreen._saveRegistrationOffline()` |
| Sync no procesa mappings | `SyncManager._uploadData()` response.data |
| remote_id sigue NULL | `updateUserRemoteIdByLocalUuid()` llamado |
| SQL errors | Migraciones ejecutadas (`npm run migrate`) |
| JSON decode errors | Verify `datos_json` es JSON válido en SQLite |

---

¡**Estás listo para empezar!** 🎉
