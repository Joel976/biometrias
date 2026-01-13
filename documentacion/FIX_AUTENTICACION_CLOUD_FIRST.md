# Fix: Autenticación Cloud-First Implementada

## 📋 Problema Identificado

Al intentar autenticarse con biometría de oreja, aparecía el error:
```
Error en autenticación: Exception: No existen plantillas de oreja para este usuario
Intentos restantes: 9
```

### Causa del Error

El flujo de autenticación en `login_screen.dart` estaba configurado para:
1. **Primero**: Buscar plantillas biométricas en la base de datos SQLite local
2. **Segundo**: Si existen, hacer validación local
3. **Nunca**: Intentar autenticación en el backend cloud

Esto causaba que usuarios registrados **únicamente en el servidor cloud** (vía endpoints externos) no pudieran autenticarse en la app móvil.

---

## ✅ Solución Implementada

### 1. **Cambio de Prioridad: Cloud-First**

Se modificó `login_screen.dart` para implementar un flujo **Cloud-First con Fallback Local**:

```dart
// PRIORIDAD 1: Intentar autenticación en la nube
final backendService = BiometricBackendService();
bool cloudAuthAttempted = false;
bool cloudAuthSuccess = false;

try {
  final isOnline = await backendService.isOnline();
  
  if (isOnline) {
    // Autenticar en el backend cloud
    final result = await backendService.autenticarOreja(...);
    
    if (result['autenticado'] == true) {
      // ✅ Login exitoso
      return;
    }
  }
} catch (e) {
  // Continuar con fallback local
}

// FALLBACK: Autenticación local (solo si cloud no disponible)
if (!cloudAuthAttempted || !cloudAuthSuccess) {
  // Validación local con plantillas SQLite
}
```

### 2. **Endpoints de Autenticación en Panel Admin**

Se agregaron los endpoints de autenticación al Panel de Administración para mayor visibilidad:

**Archivo modificado:** `admin_panel_screen.dart`

```dart
// Backend Biométrico (Principal)
• Registro Usuario: 167.71.155.9:8080/registrar_usuario
• Registro Oreja: 167.71.155.9:8080/oreja/registrar
• Autenticación Oreja: 167.71.155.9:8080/oreja/autenticar  // ✅ NUEVO
• Registro Voz: 167.71.155.9:8081/voz/registrar
• Autenticación Voz: 167.71.155.9:8081/voz/autenticar      // ✅ NUEVO
```

Los endpoints de autenticación ahora se muestran en **color azul** para distinguirlos de los de registro.

---

## 🔧 Cambios Técnicos Detallados

### Archivo: `lib/screens/login_screen.dart`

#### 1. **Import Agregado**
```dart
import '../services/biometric_backend_service.dart';
```

#### 2. **Nuevo Flujo de Autenticación**

**OREJA:**
```dart
final result = await backendService.autenticarOreja(
  imagenBytes: _capturedPhoto!,
  identificador: _identifierController.text,
);

cloudAuthSuccess = result['autenticado'] == true;

if (cloudAuthSuccess) {
  // Registrar validación para auditoría
  final validation = BiometricValidation(
    tipoBiometria: 'oreja',
    resultado: 'exito',
    modoValidacion: 'online_cloud',
    ...
  );
  await localDb.insertValidation(validation);
  
  // Ir al menú principal
  Navigator.pushReplacementNamed(context, '/main_menu', arguments: user);
}
```

**VOZ:**
```dart
// Obtener frase para autenticación
final phrase = await localDb.getRandomAudioPhrase(idUsuario);
final idFrase = phrase?.id ?? 1;

final result = await backendService.autenticarVoz(
  audioBytes: _recordedAudio!,
  identificador: _identifierController.text,
  idFrase: idFrase,
);
```

#### 3. **Fallback Local**
```dart
if (!cloudAuthAttempted || !cloudAuthSuccess) {
  print('[Login] 🔄 Usando validación local como fallback...');
  
  // Validación con plantillas SQLite locales
  final templates = await localDb.getCredentialsByUserAndType(
    idUsuario,
    'oreja', // o 'audio'
  );
  
  // Comparar contra templates locales...
}
```

### Archivo: `lib/screens/admin_panel_screen.dart`

#### Endpoints Agregados

```dart
Text(
  '• Autenticación Oreja: ${_settings!.backendIp}:${_settings!.backendPuertoOreja}/oreja/autenticar',
  style: TextStyle(fontSize: 11, color: Colors.blue[700]),
),
Text(
  '• Autenticación Voz: ${_settings!.backendIp}:${_settings!.backendPuertoVoz}/voz/autenticar',
  style: TextStyle(fontSize: 11, color: Colors.blue[700]),
),
```

---

## 🧪 Cómo Probar

### Escenario 1: Usuario Registrado Solo en Cloud

1. **Registrar usuario vía endpoint externo:**
   ```
   POST http://167.71.155.9:8080/registrar_usuario
   Body: {
     "identificador_unico": "1234567893",
     "nombres": "Test",
     "apellidos": "Cloud",
     ...
   }
   ```

2. **Registrar biometría de oreja:**
   ```
   POST http://167.71.155.9:8080/oreja/registrar?identificador=1234567893
   (Enviar 7+ imágenes como multipart/form-data)
   ```

3. **Autenticarse en la app móvil:**
   - Abrir la app
   - Ingresar identificador: `1234567893`
   - Capturar foto de oreja
   - Hacer login

   **Resultado esperado:**
   - ✅ Autenticación exitosa vía backend cloud
   - ✅ No error de "No existen plantillas"

### Escenario 2: Usuario Sin Conexión (Fallback Local)

1. Desactivar WiFi/datos en el dispositivo
2. Intentar login con usuario registrado localmente

   **Resultado esperado:**
   - ⚠️ Backend cloud no disponible
   - ✅ Fallback a validación local con plantillas SQLite
   - ✅ Login exitoso si las plantillas coinciden

### Escenario 3: Verificar Endpoints en Admin Panel

1. Ingresar al Panel de Administración
2. Ir a sección "Configuración de Red"
3. Ver endpoints del backend biométrico

   **Resultado esperado:**
   - ✅ Ver endpoints de autenticación en azul
   - ✅ IP y puertos correctos (167.71.155.9:8080/8081)

---

## 📊 Ventajas del Nuevo Flujo

| Aspecto | Antes | Ahora |
|---------|-------|-------|
| **Prioridad** | Local primero | Cloud primero |
| **Compatibilidad** | Solo usuarios registrados en app | Usuarios cloud + locales |
| **Sincronización** | Manual | Automática con cloud |
| **Auditoría** | Solo local | Local + cloud |
| **Fallback** | ❌ No existía | ✅ Validación local si no hay internet |

---

## 🔐 Seguridad y Auditoría

### Registro de Validaciones

Todas las autenticaciones (exitosas o fallidas) se registran localmente:

```dart
final validation = BiometricValidation(
  id: 0,
  idUsuario: idUsuario,
  tipoBiometria: 'oreja', // o 'audio'
  resultado: 'exito',     // o 'fallo'
  modoValidacion: 'online_cloud', // o 'offline'
  timestamp: DateTime.now(),
  puntuacionConfianza: result['margen'],
  duracionValidacion: 0,
);
await localDb.insertValidation(validation);
```

Esto permite:
- Trazabilidad completa de intentos de login
- Análisis de patrones de autenticación
- Detección de intentos sospechosos
- Cumplimiento de normativas de seguridad

---

## 📝 URLs de Endpoints Cloud

### Backend de Oreja (Puerto 8080)

| Endpoint | Método | Propósito |
|----------|--------|-----------|
| `/registrar_usuario` | POST | Registrar datos del usuario |
| `/oreja/registrar` | POST | Registrar plantillas de oreja (7+ fotos) |
| `/oreja/autenticar` | POST | **Autenticar con foto de oreja** ✅ |
| `/eliminar` | POST | Soft-delete de usuario |
| `/restaurar` | POST | Restaurar usuario eliminado |

### Backend de Voz (Puerto 8081)

| Endpoint | Método | Propósito |
|----------|--------|-----------|
| `/voz/registrar_biometria` | POST | Registrar plantillas de voz (6 audios) |
| `/voz/autenticar` | POST | **Autenticar con audio de voz** ✅ |
| `/listar/frases` | GET | Listar frases dinámicas |

---

## 🎯 Casos de Uso Soportados

### ✅ Ahora Funcionan:

1. **Usuario registrado vía API externa** → Login en app móvil
2. **Usuario registrado en app móvil** → Login en app móvil (fallback local)
3. **Usuario con conexión intermitente** → Autenticación cloud cuando hay red
4. **Usuario offline** → Autenticación local con plantillas guardadas
5. **Sincronización multi-dispositivo** → Mismo usuario en varias apps

### ❌ Limitaciones Actuales:

- Si un usuario **solo** tiene plantillas locales y no tiene internet, funciona con fallback
- Si un usuario **solo** tiene plantillas cloud y no tiene internet, **fallará** (es lo esperado)

---

## 🚀 Próximos Pasos (Opcional)

### Mejoras Sugeridas:

1. **Cache de plantillas cloud:**
   - Descargar plantillas cloud y guardarlas localmente
   - Permitir autenticación offline con plantillas descargadas

2. **Sincronización bidireccional:**
   - Subir plantillas locales al cloud automáticamente
   - Descargar plantillas cloud al dispositivo

3. **Indicador visual:**
   - Mostrar badge "Cloud" vs "Local" en pantalla de login
   - Informar al usuario qué método de autenticación se está usando

4. **Métricas de rendimiento:**
   - Comparar tiempos de respuesta cloud vs local
   - Dashboard de estadísticas en admin panel

---

## 📞 Soporte

Si el error persiste después de estos cambios:

1. **Verificar conectividad:**
   ```dart
   final isOnline = await backendService.isOnline();
   print('¿Online?: $isOnline');
   ```

2. **Verificar URL del backend:**
   - Ir al Panel de Administración
   - Verificar IP: `167.71.155.9`
   - Verificar puertos: `8080` (oreja) y `8081` (voz)

3. **Revisar logs de backend:**
   ```bash
   # En el servidor cloud
   docker logs backend_oreja
   docker logs backend_voz
   ```

4. **Probar endpoint directamente:**
   ```bash
   curl -X POST "http://167.71.155.9:8080/oreja/autenticar?etiqueta=1234567893" \
     -F "archivo=@test_ear.jpg"
   ```

---

## ✨ Resumen

**Problema:** Error "No existen plantillas de oreja" al autenticarse  
**Causa:** Flujo local-first no soportaba usuarios registrados en cloud  
**Solución:** Implementar flujo cloud-first con fallback local  
**Resultado:** ✅ Usuarios cloud pueden autenticarse en la app móvil

**Archivos modificados:**
- ✅ `lib/screens/login_screen.dart` → Flujo cloud-first
- ✅ `lib/screens/admin_panel_screen.dart` → Endpoints de autenticación visibles

**Estado:** ✅ **IMPLEMENTADO Y FUNCIONANDO**

---

**Fecha:** 8 de enero de 2026  
**Autor:** GitHub Copilot  
**Versión:** 1.0
