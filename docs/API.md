# 🔌 Documentación de API REST

API RESTful para sistema de autenticación biométrica.

---

## 📋 Base URL

```
Desarrollo:  http://localhost:3000/api
Producción:  https://api.example.com/api
```

---

## 🔐 Autenticación

Todos los endpoints (excepto `/auth/login` y `/auth/login-basico`) requieren:

```http
Authorization: Bearer {accessToken}
Content-Type: application/json
```

---

## 📌 Endpoints de Autenticación

### 1. Login Biométrico

```http
POST /auth/login
Content-Type: application/json
```

**Request Body:**
```json
{
  "identificador_unico": "user@example.com",
  "tipo_biometria": "audio",
  "puntuacion_confianza": 0.92,
  "dispositivo_id": "device_abc123",
  "ubicacion_gps": "40.7128,-74.0060"
}
```

**Response (200 OK):**
```json
{
  "mensaje": "Autenticación exitosa",
  "usuario": {
    "id_usuario": 1,
    "nombres": "Juan",
    "apellidos": "Pérez",
    "identificador_unico": "user@example.com"
  },
  "tokens": {
    "accessToken": "eyJhbGciOiJIUzI1NiIs...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
    "expiresIn": 3600
  }
}
```

**Response (401 Unauthorized):**
```json
{
  "error": "Credenciales inválidas"
}
```

---

### 2. Login Básico

```http
POST /auth/login-basico
Content-Type: application/json
```

**Request Body:**
```json
{
  "identificador_unico": "user@example.com",
  "password": "contraseña_segura",
  "dispositivo_id": "device_abc123"
}
```

**Response (200 OK):**
```json
{
  "mensaje": "Autenticación exitosa",
  "usuario": {
    "id_usuario": 1,
    "nombres": "Juan",
    "apellidos": "Pérez"
  },
  "tokens": {
    "accessToken": "...",
    "refreshToken": "...",
    "expiresIn": 3600
  }
}
```

---

### 3. Refrescar Token

```http
POST /auth/refresh-token
Content-Type: application/json
```

**Request Body:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
}
```

**Response (200 OK):**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "expiresIn": 3600
}
```

---

### 4. Logout

```http
POST /auth/logout
Authorization: Bearer {accessToken}
```

**Response (200 OK):**
```json
{
  "mensaje": "Sesión cerrada correctamente"
}
```

---

### 5. Verificar Sesión

```http
GET /auth/verify
Authorization: Bearer {accessToken}
```

**Response (200 OK):**
```json
{
  "valido": true,
  "usuario": {
    "id_usuario": 1,
    "nombres": "Juan",
    "apellidos": "Pérez",
    "estado": "activo"
  }
}
```

---

## 📡 Endpoints de Sincronización

### 1. Ping/Health Check

```http
GET /sync/ping
```

**Response (200 OK):**
```json
{
  "success": true,
  "timestamp": "2025-11-25T15:30:45.123Z",
  "servidor": "disponible",
  "version_api": "1.0.0"
}
```

---

### 2. Descargar Datos (Backend → App)

```http
POST /sync/descarga
Authorization: Bearer {accessToken}
Content-Type: application/json
```

**Request Body:**
```json
{
  "id_usuario": 1,
  "ultima_sync": "2025-11-25T14:00:00Z",
  "dispositivo_id": "device_abc123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "timestamp": "2025-11-25T15:30:45.123Z",
  "datos": {
    "usuarios": [
      {
        "id_usuario": 1,
        "nombres": "Juan",
        "apellidos": "Pérez",
        "identificador_unico": "user@example.com",
        "estado": "activo"
      }
    ],
    "credenciales_biometricas": [
      {
        "id_credencial": 1,
        "tipo_biometria": "audio",
        "version_algoritmo": "v1.0",
        "validez_hasta": "2026-11-25",
        "estado": "activo",
        "hash_integridad": "abc123..."
      }
    ],
    "textos_audio": [
      {
        "id_texto": 1,
        "frase": "Por favor diga su frase de seguridad",
        "estado_texto": "activo"
      }
    ]
  }
}
```

---

### 3. Subir Datos (App → Backend)

```http
POST /sync/subida
Authorization: Bearer {accessToken}
Content-Type: application/json
```

**Request Body:**
```json
{
  "dispositivo_id": "device_abc123",
  "validaciones": [
    {
      "tipo_biometria": "audio",
      "resultado": "exito",
      "modo_validacion": "offline",
      "puntuacion_confianza": 0.92,
      "ubicacion_gps": "40.7128,-74.0060",
      "timestamp": "2025-11-25T15:20:00Z"
    }
  ],
  "eventos": [
    {
      "tipo": "app_iniciada",
      "timestamp": "2025-11-25T15:00:00Z"
    }
  ]
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "exitosas": 1,
  "timestamp": "2025-11-25T15:30:45.123Z",
  "errores": []
}
```

**Response (200 OK con errores):**
```json
{
  "success": true,
  "exitosas": 0,
  "timestamp": "2025-11-25T15:30:45.123Z",
  "errores": [
    {
      "validacion": {...},
      "error": "Usuario no encontrado"
    }
  ]
}
```

---

### 4. Obtener Estado de Sincronización

```http
GET /sync/estado
Authorization: Bearer {accessToken}
```

**Response (200 OK):**
```json
{
  "success": true,
  "sincronizaciones": [
    {
      "id_sync": 1,
      "fecha_ultima_sync": "2025-11-25T15:30:00Z",
      "estado_sync": "completo",
      "cantidad_items": 5,
      "tipo_sync": "bidireccional",
      "codigo_error": null
    }
  ]
}
```

---

### 5. Obtener Cola Pendiente

```http
GET /sync/cola-pendiente
Authorization: Bearer {accessToken}
```

**Response (200 OK):**
```json
{
  "success": true,
  "cola": [
    {
      "id_cola": 1,
      "tipo_entidad": "validacion",
      "operacion": "INSERT",
      "datos_json": "{...}",
      "intentos_envio": 0,
      "proximo_reintento": null
    }
  ],
  "pendientes": 1
}
```

---

### 6. Confirmar Sincronización

```http
POST /sync/confirmar
Authorization: Bearer {accessToken}
Content-Type: application/json
```

**Request Body:**
```json
{
  "ids_cola": [1, 2, 3]
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "confirmados": 3
}
```

---

### 7. Reintentar Sincronización

```http
POST /sync/reintento/:id_sync
Authorization: Bearer {accessToken}
```

**Response (200 OK):**
```json
{
  "success": true,
  "mensaje": "Reintento programado"
}
```

---

## ⚠️ Códigos de Error

| Código | Significado | Solución |
|--------|-------------|----------|
| 400 | Bad Request | Verificar formato del request |
| 401 | Unauthorized | Token inválido o expirado |
| 403 | Forbidden | Acceso denegado |
| 404 | Not Found | Recurso no encontrado |
| 409 | Conflict | Identificador duplicado |
| 500 | Server Error | Error interno del servidor |
| 503 | Service Unavailable | Servidor no disponible |

---

## 🔄 Flujo de Sincronización Típico

```
1. App obtiene conectividad
   ↓
2. Envía GET /sync/ping
   ├─ 200 → Continuar
   └─ Timeout → Esperar
   ↓
3. Envía POST /sync/subida (datos offline)
   ├─ 200 → Continuar
   └─ Error → Reintentar con backoff
   ↓
4. Envía POST /sync/descarga (obtener nuevos datos)
   ├─ 200 → Procesar datos
   └─ 401 → Refrescar token y reintentar
   ↓
5. Envía POST /sync/confirmar (marcar como enviado)
   ├─ 200 → Completar
   └─ Error → Mantener en cola
```

---

## 📊 Ejemplos en diferentes lenguajes

### cURL

```bash
# Login
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "identificador_unico": "user@example.com",
    "tipo_biometria": "audio",
    "puntuacion_confianza": 0.92,
    "dispositivo_id": "device_123"
  }'

# Sincronizar
curl -X POST http://localhost:3000/api/sync/subida \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "dispositivo_id": "device_123",
    "validaciones": [...]
  }'
```

### JavaScript/Fetch

```javascript
// Login
const response = await fetch('http://localhost:3000/api/auth/login', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    identificador_unico: 'user@example.com',
    tipo_biometria: 'audio',
    puntuacion_confianza: 0.92,
    dispositivo_id: 'device_123'
  })
});

const data = await response.json();
const accessToken = data.tokens.accessToken;

// Usar token en requests posteriores
const syncResponse = await fetch('http://localhost:3000/api/sync/descarga', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${accessToken}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    id_usuario: data.usuario.id_usuario,
    ultima_sync: new Date().toISOString(),
    dispositivo_id: 'device_123'
  })
});
```

### Python

```python
import requests

BASE_URL = 'http://localhost:3000/api'

# Login
response = requests.post(f'{BASE_URL}/auth/login', json={
    'identificador_unico': 'user@example.com',
    'tipo_biometria': 'audio',
    'puntuacion_confianza': 0.92,
    'dispositivo_id': 'device_123'
})

data = response.json()
token = data['tokens']['accessToken']

# Sincronizar
headers = {'Authorization': f'Bearer {token}'}
sync_response = requests.post(
    f'{BASE_URL}/sync/descarga',
    headers=headers,
    json={
        'id_usuario': data['usuario']['id_usuario'],
        'ultima_sync': '2025-11-25T15:00:00Z',
        'dispositivo_id': 'device_123'
    }
)

print(sync_response.json())
```

### Dart/Flutter

```dart
import 'package:http/http.dart' as http;

final baseUrl = 'http://localhost:3000/api';

// Login
final loginResponse = await http.post(
  Uri.parse('$baseUrl/auth/login'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'identificador_unico': 'user@example.com',
    'tipo_biometria': 'audio',
    'puntuacion_confianza': 0.92,
    'dispositivo_id': 'device_123',
  }),
);

final userData = jsonDecode(loginResponse.body);
final token = userData['tokens']['accessToken'];

// Sincronizar
final syncResponse = await http.post(
  Uri.parse('$baseUrl/sync/descarga'),
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'id_usuario': userData['usuario']['id_usuario'],
    'ultima_sync': DateTime.now().toIso8601String(),
    'dispositivo_id': 'device_123',
  }),
);

print(jsonDecode(syncResponse.body));
```

---

## 🧪 Testing con Postman

1. Importar colección: `postman_collection.json`
2. Configurar variable `{{baseUrl}}` = `http://localhost:3000/api`
3. Ejecutar tests en orden:
   - Login
   - Ping
   - Descarga
   - Subida
   - Estado
   - Logout

---

**Última actualización**: 25 de Noviembre de 2025
