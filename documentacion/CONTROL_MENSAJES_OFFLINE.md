# Control de Mensajes de "Sin Conexión" - Implementación Completa

## 📋 Resumen
Se ha implementado un sistema configurable para controlar la frecuencia de los mensajes de "sin conexión a internet" en la aplicación móvil.

## ✅ Cambios Realizados

### 1. Modelo de Configuración (`admin_settings.dart`)

**Nueva propiedad agregada:**
```dart
// Configuraciones de notificaciones
int offlineMessageIntervalMinutes; // Intervalo para mostrar mensaje de "sin conexión"
```

**Valor por defecto:**
- `offlineMessageIntervalMinutes = 1` (1 minuto)

**Integración completa:**
- ✅ Agregado en constructor con valor por defecto
- ✅ Incluido en método `toJson()` para persistencia
- ✅ Incluido en método `fromJson()` para carga
- ✅ Incluido en método `copyWith()` para modificaciones

---

### 2. Pantalla de Login (`login_screen.dart`)

**Nueva variable de estado:**
```dart
// 📶 Control de mensajes de conectividad
DateTime? _lastOfflineMessageTime; // Última vez que se mostró el mensaje
```

**Nueva función helper:**
```dart
/// 📶 Mostrar mensaje de "sin conexión" controlado por intervalo configurable
Future<void> _showOfflineMessage(String message) async {
  final settings = await _adminService.loadSettings();
  final intervalMinutes = settings.offlineMessageIntervalMinutes;

  // Verificar si ha pasado suficiente tiempo desde el último mensaje
  final now = DateTime.now();
  if (_lastOfflineMessageTime != null) {
    final difference = now.difference(_lastOfflineMessageTime!);
    if (difference.inMinutes < intervalMinutes) {
      // No mostrar el mensaje si no ha pasado el intervalo configurado
      print('[Login] ⏳ Mensaje offline omitido (faltan ${intervalMinutes - difference.inMinutes} min)');
      return;
    }
  }

  // Mostrar el mensaje y actualizar el timestamp
  _lastOfflineMessageTime = now;
  setState(() {
    _errorMessage = message;
  });
  print('[Login] 📱 Mensaje offline mostrado: $message');
}
```

**Uso actualizado:**
- Reemplazado `setState(() { _errorMessage = '...' })` 
- Por `await _showOfflineMessage('...')` en puntos clave

---

### 3. Panel de Administración (`admin_panel_screen.dart`)

**Nueva sección de configuración:**
```dart
ListTile(
  leading: Icon(Icons.wifi_off),
  title: Text('Intervalo mensaje "sin conexión"'),
  subtitle: Text('${_settings!.offlineMessageIntervalMinutes} minuto(s)'),
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: Icon(Icons.remove),
        onPressed: () {
          if (_settings!.offlineMessageIntervalMinutes > 1) {
            setState(() {
              _settings = _settings!.copyWith(
                offlineMessageIntervalMinutes:
                    _settings!.offlineMessageIntervalMinutes - 1,
              );
            });
          }
        },
      ),
      IconButton(
        icon: Icon(Icons.add),
        onPressed: () {
          setState(() {
            _settings = _settings!.copyWith(
              offlineMessageIntervalMinutes:
                  _settings!.offlineMessageIntervalMinutes + 1,
            );
          });
        },
      ),
    ],
  ),
),
```

**Ubicación:**
- Sección de "Seguridad"
- Entre "Timeout de sesión" e "Intentos máximos de login"

---

## 🎯 Funcionalidad

### Comportamiento Anterior
❌ **Problema:** Cada vez que se cargaba una frase de audio desde la base de datos local (sin conexión), se mostraba el mensaje "Usando frase almacenada localmente (sin conexión)" en la parte superior de la pantalla.

❌ **Resultado:** Mensajes repetitivos y molestos que aparecían constantemente.

### Comportamiento Nuevo
✅ **Solución:** El mensaje solo se muestra UNA VEZ cada X minutos (configurable).

✅ **Control inteligente:**
1. Primera vez que ocurre sin conexión → Mensaje se muestra inmediatamente
2. Siguiente intento dentro del intervalo → Mensaje se omite silenciosamente
3. Después de X minutos → Mensaje se vuelve a mostrar

✅ **Logs informativos:**
```
[Login] ⏳ Mensaje offline omitido (faltan 0 min)  // Dentro del intervalo
[Login] 📱 Mensaje offline mostrado: Usando frase almacenada localmente (sin conexión)  // Después del intervalo
```

---

## ⚙️ Configuración desde Panel de Administración

### Acceso
1. Abrir la app
2. Presionar el botón de "Configuración de Admin" (esquina superior derecha)
3. Ingresar credenciales:
   - **Contraseña:** `admin`
   - **Clave secreta:** `password`
4. Navegar a la sección **"Seguridad"**

### Ajuste del Intervalo
- **Ícono:** 📶 WiFi desactivado
- **Título:** "Intervalo mensaje 'sin conexión'"
- **Controles:** 
  - Botón `-` para disminuir (mínimo: 1 minuto)
  - Botón `+` para aumentar (sin límite superior)
- **Valor actual:** Se muestra en tiempo real

### Valores Recomendados
- **1 minuto** (por defecto): Balance entre información y no ser intrusivo
- **2-3 minutos**: Para usuarios avanzados que saben cuándo están offline
- **5+ minutos**: Para entornos de prueba o desarrollo donde los mensajes molestan

---

## 🔍 Casos de Uso

### Caso 1: Usuario sin conexión intentando login
```
[T=0:00] Primer intento → "Usando frase almacenada localmente (sin conexión)" ✅
[T=0:30] Segundo intento → (mensaje omitido) ❌
[T=1:00] Tercer intento → "Usando frase almacenada localmente (sin conexión)" ✅
[T=1:15] Cuarto intento → (mensaje omitido) ❌
```

### Caso 2: Intervalo configurado a 3 minutos
```
[T=0:00] Primer intento → Mensaje mostrado ✅
[T=1:00] Segundo intento → Mensaje omitido ❌
[T=2:00] Tercer intento → Mensaje omitido ❌
[T=3:00] Cuarto intento → Mensaje mostrado ✅
```

---

## 🛡️ Persistencia
- La configuración se guarda automáticamente en `FlutterSecureStorage`
- Sobrevive al cierre de la app
- Se carga al iniciar la pantalla de login
- Valor por defecto: **1 minuto** (si no hay configuración guardada)

---

## 🧪 Testing

### Prueba Manual
1. Configurar intervalo a 1 minuto en panel de admin
2. Desconectar internet del dispositivo
3. Intentar login con voz varias veces seguidas
4. **Verificar:** Solo aparece mensaje cada 1 minuto
5. Cambiar intervalo a 2 minutos
6. **Verificar:** Ahora solo aparece cada 2 minutos

### Prueba de Logs
```bash
# Buscar en logs de Flutter
flutter logs | grep "Mensaje offline"

# Resultados esperados:
[Login] ⏳ Mensaje offline omitido (faltan 0 min)
[Login] 📱 Mensaje offline mostrado: Usando frase almacenada localmente (sin conexión)
```

---

## 📦 Archivos Modificados

1. **`lib/models/admin_settings.dart`**
   - Agregada propiedad `offlineMessageIntervalMinutes`
   - Actualizado constructor, toJson, fromJson, copyWith

2. **`lib/screens/login_screen.dart`**
   - Agregada variable `_lastOfflineMessageTime`
   - Agregada función `_showOfflineMessage()`
   - Reemplazado `setState({ _errorMessage = ... })` por `_showOfflineMessage()`

3. **`lib/screens/admin_panel_screen.dart`**
   - Agregada nueva sección en panel de seguridad
   - Controles +/- para ajustar intervalo
   - Ícono WiFi desactivado para identificación visual

---

## 🎓 Lecciones Aprendidas

### Problema Original
- Mensajes repetitivos molestaban al usuario
- No había forma de controlar la frecuencia
- La configuración estaba hardcodeada

### Solución Implementada
- ✅ Control basado en tiempo (DateTime)
- ✅ Configurable desde UI (no requiere código)
- ✅ Persistente (sobrevive reinicios)
- ✅ Logs informativos para debugging
- ✅ Mínimo de 1 minuto para evitar desactivación completa

---

## 🚀 Mejoras Futuras (Opcional)

### Posibles Extensiones
1. **Diferentes intervalos por tipo de mensaje:**
   - Mensaje de frase offline: 1 minuto
   - Mensaje de sincronización: 5 minutos
   - Mensaje de error de red: 2 minutos

2. **Modo silencioso:**
   - Opción para desactivar completamente los mensajes offline
   - Solo mostrar en logs (debug)

3. **Notificaciones toast:**
   - Usar SnackBar en lugar de `_errorMessage`
   - Menos intrusivo visualmente

4. **Estadísticas:**
   - Contar cuántos mensajes se omitieron
   - Mostrar en panel de admin

---

## ✅ Estado Actual
- ✅ Implementación completa
- ✅ Testing manual exitoso
- ✅ Documentación actualizada
- ✅ Sin errores de compilación
- ✅ Listo para producción

---

**Fecha de implementación:** 11 de enero de 2026
**Versión:** 1.0
**Desarrollador:** Sistema biométrico móvil
