## ⚠️ ACCIÓN REQUERIDA: REINICIAR EL SERVIDOR BACKEND

---

## 📋 CAMBIOS COMPLETADOS:

### Base de Datos ✅
```sql
✅ ALTER TABLE sincronizaciones ALTER COLUMN id_usuario DROP NOT NULL;
✅ ALTER TABLE cola_sincronizacion ALTER COLUMN id_usuario DROP NOT NULL;
✅ ALTER TABLE errores_sync ALTER COLUMN id_usuario DROP NOT NULL;
```

**Verificado con**:
```
\d sincronizaciones
→ id_usuario | integer | | (sin 'not null')  ✅
```

### Backend - Código ✅
```
✅ AuthController.js - Removido password_hash insert (línea 278)
✅ SincronizacionController.js - id_sincronizacion → id_sync (línea 195)
✅ biometriaRoutes.js - NUEVO archivo para rutas /api/biometria/
✅ index.js - Agregado require y app.use para biometriaRoutes
```

---

## 🚀 CÓMO REINICIAR:

### Opción A: Usando PowerShell (Recomendado)

```powershell
# Abrir PowerShell y ejecutar:

# 1. Navegar a la carpeta backend
cd c:\Users\User\Downloads\biometrias\backend

# 2. Matar procesos node existentes
Get-Process -Name node -ErrorAction SilentlyContinue | Stop-Process -Force

# 3. Esperar 2 segundos
Start-Sleep 2

# 4. Reiniciar el servidor
npm run dev
```

**Esperado en pantalla**:
```
> biometrics-backend@1.0.0 dev
> nodemon src/index.js

[nodemon] 3.1.11
[nodemon] watching path(s): *.*
[nodemon] starting `node src/index.js`

╔════════════════════════════════════════════╗
║   Servidor Biométrico iniciado              ║
║   Puerto: 3000                              ║
║   Entorno: development                      ║
║   Timestamp: 2025-12-01T11:XX:XX.XXXZ       ║
╚════════════════════════════════════════════╝
```

---

### Opción B: Detener manualmente

Si ya está ejecutándose `npm run dev`:

1. **En el terminal del backend**, presionar: **Ctrl + C**
2. Esperar a que se cierre
3. Ejecutar nuevamente: `npm run dev`

---

## ✅ VERIFICACIÓN POST-REINICIO:

Una vez que el servidor se reinicie, probar los siguientes endpoints:

### Test 1: Health Check
```powershell
curl http://localhost:3000/api/sync/ping
```
**Esperado**: HTTP 200, JSON response

### Test 2: Biometría (Oreja)
```powershell
$body = @{
    identificadorUnico = "TEST_USER_001"
    foto = "iVBORw0KGgoAAAANSUhEUgAAAAUA"
    numero = 1
} | ConvertTo-Json

curl -X POST http://localhost:3000/api/biometria/registrar-oreja `
  -ContentType "application/json" `
  -Body $body
```
**Esperado**: HTTP 400, 404 o 500, pero NO por ruta inexistente
- Antes: HTTP 404 "not found" ❌ (ruta no existe)
- Ahora: HTTP 400, 404 usuario no encontrado, o 500 de BD ✅ (ruta existe)

### Test 3: Sincronización Offline
```powershell
$body = @{
    dispositivo_id = "device_final_test"
    creaciones = @(@{
        local_uuid = "uuid-final-test"
        tipo_entidad = "usuario"
        id_cola = 1
        datos = @{
            nombres = "Test"
            apellidos = "Final"
            identificador_unico = "ID_FINAL_NEW_$(Get-Random)"
            estado = "activo"
        }
    })
} | ConvertTo-Json -Depth 5

curl -X POST http://localhost:3000/api/sync/subida `
  -ContentType "application/json" `
  -Body $body
```
**Esperado**: HTTP 200 con JSON response
```json
{
  "success": true,
  "id_sync": X,
  "exitosas": 1,
  "mappings": [...]
}
```

**NO debería tener error** de:
- ❌ "error: el valor nulo en la columna id_usuario" (CORREGIDO en BD)
- ❌ "error: no existe la columna id_sincronizacion" (CORREGIDO en código)

---

## 📊 CHECKLIST DE REINICIO:

Después de reiniciar, verificar:

- [ ] Servidor inicia sin errores
- [ ] Puerto 3000 responde a requests
- [ ] `/api/sync/ping` retorna HTTP 200
- [ ] `/api/biometria/registrar-oreja` retorna algo diferente a 404 not found
- [ ] `/api/sync/subida` NO tira error de NOT NULL o columna inexistente
- [ ] Terminal muestra logs de requests sin "restarting"

---

## 🔍 SI HAY PROBLEMAS:

### Error: "EADDRINUSE: address already in use :::3000"
```powershell
# Puerto ocupado, matar procesos node
Get-Process -Name node | Stop-Process -Force
Start-Sleep 2
npm run dev
```

### Error: "Cannot find module biometriaRoutes"
```powershell
# El archivo no existe, crear:
# backend/src/routes/biometriaRoutes.js
# (Ya fue creado, pero verificar que exista)
```

### Error: "syncResult.rows[0] is undefined"
```powershell
# El RETURNING en SQL no retorna datos
# Verificar que el INSERT fue exitoso
# Probable causa: constraints en base de datos
```

---

## 📋 RESUMEN DE CAMBIOS APLICADOS:

| Componente | Antes | Después | Status |
|-----------|-------|---------|--------|
| **Tabla sincronizaciones** | id_usuario NOT NULL | id_usuario nullable | ✅ BD |
| **AuthController** | INSERT password_hash | Sin password_hash | ✅ Código |
| **SincronizacionController** | id_sincronizacion | id_sync | ✅ Código |
| **Rutas biometría** | /api/auth/biometria/... | /api/biometria/... | ✅ Código |

---

## ⏱️ TIEMPO ESTIMADO:

- Reinicio: **5 segundos**
- Tests: **30 segundos**
- Total: **1 minuto**

---

**Estado**: 🟡 PENDIENTE REINICIO  
**Acción requerida**: Ejecutar `npm run dev` en terminal backend  
**Fecha**: 01 de Diciembre 2025 11:55 UTC
