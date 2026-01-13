# 📋 Validación de Campos en Registro

## ✅ Cambios Implementados

### 1. **Campo Email Eliminado** 
**Razón**: El campo `correoElectronico` no existe en la tabla `usuarios` de PostgreSQL

**Archivos modificados**:
- ✅ `register_screen.dart`:
  - Eliminado `_emailController`
  - Eliminado TextField de email del formulario
  - Actualizado registro: `email: ''` (vacío por compatibilidad)
  - Actualizado sync queue sin email
  - Agregados campos: `fecha_nacimiento`, `sexo` al sync

### 2. **Validación de Campos Obligatorios**
**Funcionalidad**: Bloquear botón "Siguiente" hasta que se completen los campos requeridos

**Lógica implementada** (`_canProceedToNextStep()`):

```dart
bool _canProceedToNextStep() {
  final settings = _adminService.currentSettings;
  final requireAllFields = settings?.requireAllFieldsInRegistration ?? true;

  // Si está deshabilitado desde admin, permitir avanzar
  if (!requireAllFields) return true;

  switch (_currentStep) {
    case 0: // Datos personales
      return _nombresController.text.trim().isNotEmpty &&
             _apellidosController.text.trim().isNotEmpty &&
             _identificadorController.text.trim().isNotEmpty;
    
    case 1: // 7 fotos de oreja
      return earPhotos.every((photo) => photo != null);
    
    default:
      return true;
  }
}
```

**Comportamiento**:
- **Paso 0 (Datos)**: Requiere `nombres`, `apellidos`, `identificador único`
- **Paso 1 (Fotos)**: Requiere las 7 fotos de oreja capturadas
- **Paso 2 (Audios)**: No hay validación (puede avanzar con audios parciales)

### 3. **Toggle en Panel de Administración**
**Ubicación**: Panel Admin → Configuraciones de Biometría

**Nuevo switch**:
```dart
SwitchListTile(
  title: Text('Validación de campos en registro'),
  subtitle: Text('Bloquear el botón "Siguiente" hasta llenar campos obligatorios'),
  secondary: Icon(Icons.fact_check, color: Colors.orange),
  value: _settings!.requireAllFieldsInRegistration,
  onChanged: (value) {
    setState(() {
      _settings = _settings!.copyWith(requireAllFieldsInRegistration: value);
    });
  },
)
```

**Opciones**:
- ✅ **Activado (por defecto)**: Bloquea el botón "Siguiente" si faltan campos
- ❌ **Desactivado**: Permite avanzar sin restricciones

---

## 📊 Estructura de Base de Datos

### Tabla `usuarios` (PostgreSQL)
```sql
CREATE TABLE usuarios (
  id_usuario SERIAL PRIMARY KEY,
  nombres VARCHAR(100) NOT NULL,
  apellidos VARCHAR(100) NOT NULL,
  fecha_nacimiento DATE,               -- OPCIONAL
  sexo VARCHAR(10),                    -- OPCIONAL (M/F/Otro)
  identificador_unico VARCHAR(20) UNIQUE NOT NULL,
  estado VARCHAR(20) DEFAULT 'activo',
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Campos en formulario de registro**:
- ✅ **Obligatorios**: `nombres`, `apellidos`, `identificador_unico`
- 🔵 **Opcionales**: `fecha_nacimiento`, `sexo`
- ❌ **Eliminados**: `correoElectronico` (no está en DB)

---

## 🔧 Archivos Modificados

### `lib/models/admin_settings.dart`
```dart
class AdminSettings {
  // ... otros campos ...
  bool requireAllFieldsInRegistration; // NUEVO

  AdminSettings({
    // ... otros parámetros ...
    this.requireAllFieldsInRegistration = true, // Por defecto ACTIVADO
  });

  Map<String, dynamic> toJson() {
    return {
      // ... otros campos ...
      'requireAllFieldsInRegistration': requireAllFieldsInRegistration,
    };
  }

  factory AdminSettings.fromJson(Map<String, dynamic> json) {
    return AdminSettings(
      // ... otros campos ...
      requireAllFieldsInRegistration: json['requireAllFieldsInRegistration'] ?? true,
    );
  }

  AdminSettings copyWith({
    // ... otros parámetros ...
    bool? requireAllFieldsInRegistration,
  }) {
    return AdminSettings(
      // ... otros campos ...
      requireAllFieldsInRegistration: requireAllFieldsInRegistration ?? this.requireAllFieldsInRegistration,
    );
  }
}
```

### `lib/screens/register_screen.dart`
```dart
// ❌ ELIMINADO
// final _emailController = TextEditingController();

// ❌ ELIMINADO
// TextField(
//   controller: _emailController,
//   keyboardType: TextInputType.emailAddress,
//   decoration: InputDecoration(
//     labelText: 'Correo Electrónico',
//     ...
//   ),
// )

// ✅ AGREGADO
bool _canProceedToNextStep() {
  final settings = _adminService.currentSettings;
  final requireAllFields = settings?.requireAllFieldsInRegistration ?? true;

  if (!requireAllFields) return true;

  switch (_currentStep) {
    case 0: // Validar campos de texto
      return _nombresController.text.trim().isNotEmpty &&
             _apellidosController.text.trim().isNotEmpty &&
             _identificadorController.text.trim().isNotEmpty;
    case 1: // Validar 7 fotos
      return earPhotos.every((photo) => photo != null);
    default:
      return true;
  }
}

// ✅ MODIFICADO: Botón "Siguiente" con validación
ElevatedButton.icon(
  onPressed: _canProceedToNextStep()
      ? () => setState(() => _currentStep++)
      : null, // Deshabilitado si no cumple validación
  icon: const Icon(Icons.arrow_forward),
  label: const Text('Siguiente'),
)
```

### `lib/screens/admin_panel_screen.dart`
```dart
// ✅ AGREGADO: Nuevo switch en sección de Biometría
SwitchListTile(
  title: Text('Validación de campos en registro'),
  subtitle: Text(
    'Bloquear el botón "Siguiente" hasta llenar todos los campos obligatorios',
  ),
  secondary: Icon(Icons.fact_check, color: Colors.orange),
  value: _settings!.requireAllFieldsInRegistration,
  onChanged: (value) {
    setState(() {
      _settings = _settings!.copyWith(requireAllFieldsInRegistration: value);
    });
  },
)
```

---

## 🧪 Pruebas

### **Escenario 1: Validación Activada (por defecto)**
1. Abrir pantalla de registro
2. Intentar presionar "Siguiente" sin llenar campos
   - **Resultado esperado**: Botón deshabilitado (gris)
3. Llenar `nombres`, `apellidos`, `identificador`
   - **Resultado esperado**: Botón habilitado (azul)
4. Presionar "Siguiente"
   - **Resultado esperado**: Avanza a Paso 2 (Fotos)
5. Intentar presionar "Siguiente" sin capturar las 7 fotos
   - **Resultado esperado**: Botón deshabilitado
6. Capturar 7 fotos de oreja
   - **Resultado esperado**: Botón habilitado
7. Avanzar a Paso 3 (Audios)
   - **Resultado esperado**: No requiere validación (puede continuar)

### **Escenario 2: Validación Desactivada (desde Admin Panel)**
1. Ir a Panel de Administración
2. Desactivar "Validación de campos en registro"
3. Guardar configuración
4. Volver a pantalla de registro
5. Intentar presionar "Siguiente" sin llenar campos
   - **Resultado esperado**: Botón HABILITADO (permite avanzar sin validar)

### **Escenario 3: Campo Email Eliminado**
1. Abrir registro
2. Verificar que NO aparece campo "Correo Electrónico"
   - **Resultado esperado**: Solo aparecen campos: Nombres, Apellidos, Fecha Nacimiento, Sexo, Cédula
3. Completar registro exitosamente
4. Verificar en base de datos:
   ```sql
   SELECT * FROM usuarios ORDER BY id_usuario DESC LIMIT 1;
   ```
   - **Resultado esperado**: Registro sin campo `correoElectronico`

---

## 📝 Resumen de Cambios

| Acción | Archivo | Descripción |
|--------|---------|-------------|
| ❌ **Eliminado** | `register_screen.dart` | Campo `_emailController` y TextField de email |
| ✅ **Agregado** | `register_screen.dart` | Método `_canProceedToNextStep()` con validación |
| ✅ **Modificado** | `register_screen.dart` | Botón "Siguiente" con `onPressed: _canProceedToNextStep() ? ... : null` |
| ✅ **Agregado** | `admin_settings.dart` | Campo `requireAllFieldsInRegistration` |
| ✅ **Agregado** | `admin_panel_screen.dart` | Switch para activar/desactivar validación |
| ✅ **Actualizado** | Sync queue | Removido email, agregado `fecha_nacimiento` y `sexo` |

---

## 🎯 Conclusión

✅ **Campo email eliminado** (no existe en DB PostgreSQL)  
✅ **Validación de campos implementada** (bloquea botón "Siguiente")  
✅ **Toggle de admin agregado** (control desde panel de administración)  
✅ **Sin errores de compilación**  
✅ **Compatible con sincronización offline**  

**Estado**: ✅ **COMPLETADO Y OPERACIONAL**
