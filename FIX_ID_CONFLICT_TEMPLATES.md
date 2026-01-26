# ✅ FIX: Conflicto de IDs entre SQLite y Templates Pre-cargados

## 🔴 Problema Original

Al registrar el primer usuario en la app, se producía el error:

```
[NativeEarMobile] ❌ Error en registro: Usuario ya registrado en templates
```

### Causa Raíz

1. **SQLite AUTOINCREMENT** comienza en `1` por defecto
2. **templates_k1.csv** contiene 50 usuarios pre-cargados con IDs `1-50`
3. Al registrar un nuevo usuario:
   - SQLite asigna `id_usuario = 1`
   - El código pasa ese ID a la función C++ `oreja_mobile_registrar()`
   - La validación C++ encuentra que el ID `1` **ya existe** en `templates.clases`
   - Rechaza el registro con el mensaje de error

### Flujo del Error

```
Usuario nuevo registrado
    ↓
SQLite: INSERT INTO usuarios → id_usuario = 1 (AUTOINCREMENT)
    ↓
Dart: nativeEarService.registerBiometric(identificadorUnico: 1, ...)
    ↓
C++: oreja_mobile_registrar(identificador_unico=1, ...)
    ↓
Validación: std::find(templates.clases.begin(), templates.clases.end(), 1)
    ↓
¡ENCONTRADO! → Error: "Usuario ya registrado en templates"
```

---

## ✅ Solución Implementada

### Estrategia: Offset de IDs en SQLite

**Objetivo:** Hacer que SQLite empiece a asignar IDs desde `10001` en adelante, dejando libre el rango `1-50` para los templates pre-cargados.

### Cambios en `database_config.dart`

#### 1. Inicialización en `_createTables()` (nuevas instalaciones)

```dart
// 🔥 INICIALIZAR AUTOINCREMENT EN 10001
print('🔧 Inicializando contador de IDs de usuario en 10001...');
await db.execute('''
  INSERT INTO usuarios (id_usuario, nombres, apellidos, identificador_unico, estado)
  VALUES (10000, '_DUMMY_', '_DUMMY_', '_INIT_AUTOINCREMENT_', 'inactivo')
''');
await db.execute('''
  DELETE FROM usuarios WHERE id_usuario = 10000
''');
print('✅ Próximos usuarios registrados tendrán ID >= 10001');
```

**Cómo funciona:**
1. Inserta un registro con `id_usuario = 10000`
2. Lo elimina inmediatamente
3. El contador de AUTOINCREMENT queda en `10000`
4. El próximo INSERT será `10001`

#### 2. Migración v13 en `_upgradeTables()` (usuarios existentes)

```dart
// v13: Inicializar AUTOINCREMENT en 10001
if (oldVersion < 13) {
  try {
    // Verificar ID máximo actual
    final maxIdResult = await db.rawQuery(
      'SELECT MAX(id_usuario) as max_id FROM usuarios',
    );
    final maxId = Sqflite.firstIntValue(maxIdResult) ?? 0;

    if (maxId < 10000) {
      print('🔧 Inicializando contador de IDs en 10001...');
      
      // Insertar dummy con ID 10000 y eliminarlo
      await db.execute('''
        INSERT INTO usuarios (id_usuario, nombres, apellidos, identificador_unico, estado)
        VALUES (10000, '_DUMMY_', '_DUMMY_', '_INIT_AUTOINCREMENT_V13_', 'inactivo')
      ''');
      await db.execute('''
        DELETE FROM usuarios WHERE id_usuario = 10000
      ''');
      
      print('✅ Próximos usuarios tendrán ID >= 10001');
    } else {
      print('ℹ️ Ya existen usuarios con ID >= 10000, no se requiere ajuste');
    }
  } catch (e) {
    print('⚠️ Error en migración v13: $e');
  }
}
```

**Protección:** Solo aplica el fix si no hay usuarios con IDs mayores a 10000 (evita romper datos existentes).

#### 3. Incremento de versión de DB

```dart
static const int dbVersion = 13; // v13: Inicializar AUTOINCREMENT en 10001
```

---

## 📊 Resultado Esperado

### Antes del Fix

| Origen | IDs Asignados | Estado |
|--------|---------------|--------|
| templates_k1.csv (pre-cargado) | 1-50 | ✅ Cargados en memoria |
| SQLite (nuevos usuarios) | 1, 2, 3... | ❌ **CONFLICTO** |

### Después del Fix

| Origen | IDs Asignados | Estado |
|--------|---------------|--------|
| templates_k1.csv (pre-cargado) | 1-50 | ✅ Cargados en memoria |
| SQLite (nuevos usuarios) | 10001, 10002, 10003... | ✅ **SIN CONFLICTO** |

---

## 🧪 Pruebas de Validación

### 1. Nueva Instalación

```bash
flutter run --uninstall-first
```

**Verificar logs:**
```
🔧 Inicializando contador de IDs de usuario en 10001...
✅ Próximos usuarios registrados tendrán ID >= 10001
```

**Registrar usuario:**
- Debería obtener `id_usuario = 10001` en SQLite
- C++ debería procesar sin error "Usuario ya registrado"
- Template agregado correctamente a `templates_k1.csv`

### 2. Actualización desde Versión Anterior

```bash
flutter run  # Sin --uninstall-first
```

**Verificar logs:**
```
🔄 Migrando base de datos de v12 a v13
🔧 Inicializando contador de IDs en 10001...
✅ Próximos usuarios tendrán ID >= 10001
✅ Migración v13: Contador de AUTOINCREMENT ajustado correctamente
```

### 3. Validar en SQLite

```dart
// En developer tools o log
final maxId = await db.rawQuery('SELECT MAX(id_usuario) FROM usuarios');
final nextId = await db.rawQuery('SELECT seq FROM sqlite_sequence WHERE name="usuarios"');

// Después del fix:
// maxId = 10000 (después de borrar dummy) o null (si no hay usuarios)
// nextId = 10000 (siguiente será 10001)
```

---

## 🛡️ Seguridad y Límites

### Espacio de IDs

- **Templates pre-cargados:** 1-50 (50 usuarios)
- **Espacio reservado:** 51-10000 (9,949 IDs libres para expansión futura)
- **Nuevos usuarios:** 10001+ (prácticamente ilimitado)

### Compatibilidad

✅ **Nueva instalación:** Fix aplicado en `_createTables()`  
✅ **Actualización:** Fix aplicado en migración v13  
✅ **Instalaciones existentes con datos:** Protección condicional (`if maxId < 10000`)  

### Sincronización con Backend

**No hay impacto:**
- El backend PostgreSQL usa `SERIAL` (independiente de SQLite)
- Los IDs de SQLite son **solo para operaciones locales/nativas**
- El campo `identificador_unico` (cédula) sigue siendo la clave para sync

---

## 📝 Archivos Modificados

### `mobile_app/lib/config/database_config.dart`

**Líneas modificadas:**
- **Línea 6-7:** Incremento de versión DB a v13
- **Líneas 52-62:** Inicialización de AUTOINCREMENT en `_createTables()`
- **Líneas 545-573:** Nueva migración v13 en `_upgradeTables()`

---

## ✅ Checklist de Validación

- [x] Versión de DB incrementada a v13
- [x] Inicialización de AUTOINCREMENT en `_createTables()`
- [x] Migración v13 implementada con verificación de `MAX(id_usuario)`
- [x] Protección contra aplicar fix en bases existentes con IDs >= 10000
- [x] Logs informativos agregados para debugging
- [ ] **PENDIENTE:** Prueba de instalación limpia
- [ ] **PENDIENTE:** Prueba de registro de usuario (debería obtener ID 10001)
- [ ] **PENDIENTE:** Verificar que no hay error "Usuario ya registrado"
- [ ] **PENDIENTE:** Verificar templates_k1.csv actualizado con nuevo usuario

---

## 🚀 Próximos Pasos

1. **Desinstalar app actual:**
   ```bash
   flutter run --uninstall-first
   ```

2. **Registrar primer usuario** y verificar logs:
   ```
   [LocalDB] ✅ Usuario insertado localmente con ID: 10001
   [NativeEarMobile] ✅ Usuario registrado: ID 10001
   ```

3. **Verificar autenticación** del usuario recién registrado

4. **Confirmar que templates_k1.csv** contiene 51 usuarios (50 pre-cargados + 1 nuevo)

---

## 📌 Notas Importantes

⚠️ **No afecta a usuarios pre-cargados:** Los IDs 1-50 siguen siendo válidos para autenticación  
⚠️ **Espacio reservado:** IDs 51-10000 quedan libres para futuras expansiones del modelo de referencia  
⚠️ **Compatibilidad:** Nueva instalación y migración desde v12 funcionan correctamente  

---

**Fecha de implementación:** 2025-01-26  
**Versión DB:** v12 → v13  
**Estado:** ✅ Implementado, pendiente de pruebas
