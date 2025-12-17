# 🔐 Guía del Panel de Administración

## 📋 Tabla de Contenidos
1. [Descripción General](#descripción-general)
2. [Credenciales por Defecto](#credenciales-por-defecto)
3. [Cómo Acceder](#cómo-acceder)
4. [Configuraciones Disponibles](#configuraciones-disponibles)
5. [Cómo Integrar](#cómo-integrar)
6. [Cambiar Contraseñas](#cambiar-contraseñas)
7. [Seguridad](#seguridad)

---

## 📱 Descripción General

El **Panel de Administración** permite controlar configuraciones críticas de la app sin necesidad de modificar código:

✅ **Tema oscuro/claro**  
✅ **Configuración de sincronización**  
✅ **Parámetros de seguridad**  
✅ **URL de la API**  
✅ **Configuraciones de debug**  
✅ **Parámetros de biometría**  

Todo se guarda de forma **segura y encriptada** usando `flutter_secure_storage`.

---

## 🔑 Credenciales por Defecto

### Para Modo Desarrollo/Testing:

```
Contraseña Maestra: admin
Clave Secreta: password
```

⚠️ **IMPORTANTE:** Cambiar estas credenciales en producción (ver sección [Cambiar Contraseñas](#cambiar-contraseñas))

---

## 🚪 Cómo Acceder

### Opción 1: Botón Visible (para desarrollo)

Agrega el botón en cualquier pantalla:

```dart
import 'package:tu_app/screens/admin_access_button.dart';

// En tu pantalla (ej: HomeScreen):
Scaffold(
  body: Column(
    children: [
      // ... tu contenido
      
      // Botón visible con etiqueta
      AdminAccessButton(showLabel: true),
    ],
  ),
)
```

### Opción 2: Botón Secreto (para producción)

Requiere hacer **7 taps** en el icono de configuración en menos de 3 segundos:

```dart
import 'package:tu_app/screens/admin_access_button.dart';

// En tu AppBar o Drawer:
AppBar(
  actions: [
    AdminAccessButton(), // Sin showLabel = botón discreto
  ],
)
```

**Cómo usarlo:**
1. Haz tap 7 veces rápidamente en el icono ⚙️
2. Verás mensajes: "6 taps más...", "5 taps más..."
3. Al llegar a 7 taps se abre el login de admin

### Opción 3: Navegación Directa

```dart
import 'package:tu_app/screens/admin_login_screen.dart';

// Navegar directamente
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => AdminLoginScreen(),
  ),
);
```

---

## ⚙️ Configuraciones Disponibles

### 🎨 1. Apariencia
- **Modo Oscuro**: Activar/desactivar tema oscuro

### 🔄 2. Sincronización
- **Auto-sincronización**: Activar/desactivar sync automático
- **Intervalo de sincronización**: 1-60 minutos (default: 5)
- **Máximo de reintentos**: 1-10 intentos (default: 5)

### 🔒 3. Seguridad
- **Requerir biometría**: Solicitar huella/face en login
- **Timeout de sesión**: 5-120 minutos (default: 30)
- **Intentos máximos de login**: 1-10 intentos (default: 3)

### 🌐 4. Red y API
- **URL de la API**: Cambiar endpoint del backend
- **Timeout de peticiones**: 10-120 segundos (default: 30)
- **Permitir HTTP**: Solo para desarrollo (inseguro)

### 🐛 5. Debug y Desarrollo
- **Logs de debug**: Mostrar logs detallados
- **Indicador de red**: Mostrar badge WiFi
- **Estado de sincronización**: Mostrar banner de sync

### 📸 6. Biometría
- **Calidad mínima de foto**: 10-100% (default: 70)
- **Duración de audio**: 3-10 segundos (default: 5)
- **Múltiples registros**: Permitir mismo usuario varias veces

---

## 🔧 Cómo Integrar

### Paso 1: Agregar dependencias en `pubspec.yaml`

Ya están incluidas:
```yaml
dependencies:
  flutter_secure_storage: ^9.0.0
  crypto: ^3.0.3
```

### Paso 2: Usar AdminAccessButton en LoginScreen

```dart
// lib/screens/login_screen.dart
import 'admin_access_button.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
        actions: [
          // Botón secreto (7 taps para acceder)
          AdminAccessButton(),
        ],
      ),
      body: // ... tu contenido de login
    );
  }
}
```

### Paso 3: Aplicar tema dinámico en `main.dart`

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'services/admin_settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargar configuraciones de admin
  final adminService = AdminSettingsService();
  final settings = await adminService.loadSettings();
  
  runApp(MyApp(isDarkMode: settings.isDarkMode));
}

class MyApp extends StatefulWidget {
  final bool isDarkMode;
  
  MyApp({required this.isDarkMode});
  
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _isDarkMode;
  final _adminService = AdminSettingsService();
  
  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    
    // Escuchar cambios de configuración
    _listenToSettingsChanges();
  }
  
  void _listenToSettingsChanges() {
    // Recargar settings cada 5 segundos (o usar Stream)
    Future.delayed(Duration(seconds: 5), () {
      _adminService.loadSettings().then((settings) {
        if (mounted && settings.isDarkMode != _isDarkMode) {
          setState(() {
            _isDarkMode = settings.isDarkMode;
          });
        }
      });
      _listenToSettingsChanges();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biometric App',
      
      // Tema claro
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      
      // Tema oscuro
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      
      // Aplicar tema según configuración
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      home: LoginScreen(),
    );
  }
}
```

### Paso 4: Usar configuraciones en otros servicios

```dart
// En cualquier servicio
import '../services/admin_settings_service.dart';

class MiServicio {
  final _adminService = AdminSettingsService();
  
  Future<void> configurar() async {
    final settings = await _adminService.loadSettings();
    
    // Usar configuraciones
    final apiUrl = settings.apiBaseUrl;
    final timeout = settings.requestTimeoutSeconds;
    final enableLogs = settings.enableDebugLogs;
    
    if (enableLogs) {
      print('Configurando servicio con API: $apiUrl');
    }
  }
}
```

---

## 🔐 Cambiar Contraseñas

### Generar Hash de Nueva Contraseña

1. Abre el Panel de Administración
2. Ve a **"Acciones"** → **"Generar hash de contraseña"**
3. Ingresa tu nueva contraseña
4. Copia el hash generado

### Actualizar en el Código

Edita `lib/services/admin_settings_service.dart`:

```dart
class AdminSettingsService {
  // Cambiar estos hashes:
  
  // Para "admin" → reemplazar con tu hash
  static const String _masterPasswordHash = 
      'TU_NUEVO_HASH_AQUI';
  
  // Para "password" → reemplazar con tu hash
  static const String _secretKeyHash =
      'TU_NUEVO_HASH_AQUI';
}
```

**Ejemplo:**

Si quieres usar `miContraseña123` y `claveSecreta456`:

1. Genera hash de `miContraseña123`: 
   ```
   a1b2c3d4e5f6...
   ```

2. Genera hash de `claveSecreta456`:
   ```
   x7y8z9w0v1u2...
   ```

3. Actualiza el código:
   ```dart
   static const String _masterPasswordHash = 'a1b2c3d4e5f6...';
   static const String _secretKeyHash = 'x7y8z9w0v1u2...';
   ```

---

## 🛡️ Seguridad

### Medidas de Seguridad Implementadas

✅ **Doble autenticación**: Requiere contraseña + clave secreta  
✅ **Hashing SHA-256**: Contraseñas nunca se guardan en texto plano  
✅ **Rate limiting**: Máximo 5 intentos fallidos (1 minuto de espera)  
✅ **Secure Storage**: Configuraciones encriptadas  
✅ **Acceso secreto**: Requiere 7 taps rápidos (opcional)  

### Recomendaciones para Producción

⚠️ **IMPORTANTE:**

1. **Cambiar credenciales por defecto** antes de publicar
2. **No compartir** el hash de contraseñas en el repositorio público
3. **Usar variables de entorno** para credenciales sensibles
4. **Deshabilitar botón visible** de admin en producción
5. **Habilitar solo acceso secreto** (7 taps)
6. **Logs de acceso**: Registrar quién accede al panel

### Variables de Entorno (Opcional)

Para máxima seguridad, usar `flutter_dotenv`:

```dart
// .env
ADMIN_PASSWORD_HASH=a1b2c3d4e5f6...
ADMIN_SECRET_HASH=x7y8z9w0v1u2...

// admin_settings_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

static final String _masterPasswordHash = 
    dotenv.env['ADMIN_PASSWORD_HASH']!;
static final String _secretKeyHash = 
    dotenv.env['ADMIN_SECRET_HASH']!;
```

---

## 📤 Exportar/Importar Configuraciones

### Exportar

1. Abre el Panel de Administración
2. Ve a **"Acciones"** → **"Exportar configuraciones"**
3. Las configuraciones se copian al portapapeles como JSON
4. Pégalas en un archivo seguro

### Importar

1. Copia el JSON de configuraciones
2. Ve a **"Acciones"** → **"Importar configuraciones"**
3. Pega el JSON
4. Las configuraciones se aplicarán inmediatamente

**Formato JSON:**
```json
{
  "isDarkMode": true,
  "syncIntervalMinutes": 10,
  "apiBaseUrl": "https://mi-api.com/api",
  "enableDebugLogs": false,
  ...
}
```

---

## 🎯 Ejemplo Completo de Uso

```dart
// 1. Usuario hace 7 taps en el icono de settings
// 2. Se abre AdminLoginScreen
// 3. Ingresa: "admin" + "password"
// 4. Accede al AdminPanelScreen
// 5. Activa "Modo Oscuro"
// 6. Cambia intervalo de sync a 10 minutos
// 7. Actualiza URL de API a producción
// 8. Presiona 💾 "Guardar"
// 9. La app se reinicia con tema oscuro
// 10. Sync ocurre cada 10 minutos
```

---

## 🆘 Troubleshooting

### No puedo acceder al panel
- Verifica credenciales: `admin` y `password` (default)
- Revisa que no hayas excedido 5 intentos (espera 1 minuto)

### El tema no cambia
- Asegúrate de llamar `setState()` en `main.dart`
- Verifica que `themeMode` esté configurado correctamente

### Configuraciones no se guardan
- Revisa permisos de `flutter_secure_storage`
- Verifica logs en consola: `[Admin] 💾 Configuraciones guardadas`

### Botón secreto no funciona
- Haz los 7 taps **rápidamente** (menos de 3 segundos)
- Observa los mensajes: "6 taps más...", "5 taps más..."

---

## 📚 Archivos Relacionados

- `lib/models/admin_settings.dart` - Modelo de configuraciones
- `lib/services/admin_settings_service.dart` - Lógica de negocio
- `lib/screens/admin_panel_screen.dart` - UI del panel
- `lib/screens/admin_login_screen.dart` - Autenticación
- `lib/screens/admin_access_button.dart` - Botón de acceso

---

## ✅ Checklist de Implementación

- [ ] Agregar `AdminAccessButton` en LoginScreen
- [ ] Configurar tema dinámico en `main.dart`
- [ ] Cambiar credenciales por defecto
- [ ] Probar acceso con 7 taps
- [ ] Verificar que el tema oscuro funciona
- [ ] Configurar URL de API de producción
- [ ] Deshabilitar logs en producción
- [ ] Exportar configuraciones de respaldo

---

## 🎉 ¡Listo!

Ahora tienes un panel de administración completo y seguro. Los administradores pueden controlar la app sin tocar código.

**Credenciales de prueba:**
- Contraseña: `admin`
- Clave Secreta: `password`

**Para acceder:** Haz 7 taps rápidos en el icono ⚙️

🚀 **¡Disfruta de tu panel de administración!**
