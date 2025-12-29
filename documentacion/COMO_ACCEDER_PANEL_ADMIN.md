# 🚀 Guía Rápida: Acceder al Panel de Administración

## 📍 Ya está integrado en tu LoginScreen

El botón de acceso secreto ya está agregado a tu pantalla de login.

---

## 🎯 Cómo Acceder (Paso a Paso)

### **1. Ejecuta la app**

```powershell
cd C:\Users\User\Downloads\biometrias\mobile_app
flutter run
```

### **2. En la pantalla de Login**

Verás el icono ⚙️ (configuración) en la esquina superior derecha del AppBar:

```
┌─────────────────────────────────────────┐
│ Autenticación Biométrica          ⚙️   │ ← Aquí está el botón
├─────────────────────────────────────────┤
│                                         │
│         🛡️  Login                       │
│                                         │
```

### **3. Haz 7 taps rápidos en el icono ⚙️**

- Tap 1: "6 taps más..."
- Tap 2: "5 taps más..."
- Tap 3: "4 taps más..."
- Tap 4: "3 taps más..."
- Tap 5: "2 taps más..."
- Tap 6: "1 tap más..."
- Tap 7: **¡Se abre el login de admin!** 🎉

⚠️ **Importante:** Los 7 taps deben hacerse en **menos de 3 segundos**.

### **4. Ingresa las credenciales**

```
Contraseña Maestra: admin
Clave Secreta: password
```

### **5. ¡Estás en el Panel de Administración!**

Ahora puedes:
- ✅ Cambiar el tema a oscuro/claro
- ✅ Ajustar el intervalo de sincronización
- ✅ Modificar la URL de la API
- ✅ Configurar parámetros de seguridad
- ✅ Activar/desactivar logs de debug
- ✅ Y mucho más...

---

## 🎨 Ejemplo de Uso: Activar Modo Oscuro

1. Accede al panel (7 taps + credenciales)
2. En la sección **"🎨 Apariencia"**
3. Activa el switch **"Modo Oscuro"**
4. Presiona el icono 💾 en el AppBar (guardar)
5. ¡Listo! La app ahora tiene tema oscuro

---

## 🔧 Configuraciones Útiles

### Cambiar intervalo de sincronización a 10 minutos:
1. Panel → **"🔄 Sincronización"**
2. **"Intervalo de sincronización"** → Presiona [+] hasta llegar a 10
3. Guarda con 💾

### Cambiar URL de la API de desarrollo a producción:
1. Panel → **"🌐 Red y API"**
2. **"URL de la API"** → Presiona el icono ✏️
3. Cambia a: `https://tu-servidor-produccion.com/api`
4. Guarda con 💾

### Desactivar logs en producción:
1. Panel → **"🐛 Debug y Desarrollo"**
2. Desactiva **"Logs de debug"**
3. Guarda con 💾

---

## 🆘 Troubleshooting

### "No pasa nada cuando hago tap"
- Asegúrate de hacer los 7 taps **rápidamente** (menos de 3 segundos)
- Observa la pantalla: deben aparecer mensajes "X taps más..."

### "No puedo entrar con admin/password"
- Verifica que escribes exactamente: `admin` (minúsculas)
- Clave secreta: `password` (minúsculas)
- Si fallas 5 veces, espera 1 minuto

### "El tema no cambia"
- Asegúrate de presionar 💾 (guardar) después de cambiar
- Reinicia la app para ver los cambios

---

## 🔐 Cambiar Contraseñas (Producción)

### Para generar nuevas contraseñas:

1. Accede al panel
2. Ve a **"⚙️ Acciones"**
3. Presiona **"Generar hash de contraseña"**
4. Ingresa tu nueva contraseña
5. Copia el hash generado
6. Edita `lib/services/admin_settings_service.dart`:

```dart
static const String _masterPasswordHash = 'TU_HASH_AQUI';
static const String _secretKeyHash = 'TU_OTRO_HASH_AQUI';
```

---

## 📱 Vista del Botón Secreto

El botón se ve así en tu LoginScreen:

```
AppBar:
┌────────────────────────────────────┐
│ Autenticación Biométrica      ⚙️  │ ← Este es el botón
└────────────────────────────────────┘
                                  ↑
                     Haz 7 taps aquí
```

Es **discreto** para que los usuarios normales no lo noten, pero los administradores saben que existe.

---

## ✅ Checklist de Primer Uso

- [ ] Ejecuta `flutter run`
- [ ] Ve a la pantalla de Login
- [ ] Localiza el icono ⚙️ en la esquina superior derecha
- [ ] Haz 7 taps rápidos
- [ ] Verifica que aparecen mensajes "X taps más..."
- [ ] Ingresa: `admin` y `password`
- [ ] ¡Explora el panel de administración!

---

## 🎉 ¡Listo para Usar!

Ahora tienes un panel de administración completo y seguro integrado en tu app.

**Para acceder:** 7 taps rápidos en ⚙️ → `admin` / `password`

🚀 **¡Disfruta del panel de administración!**
