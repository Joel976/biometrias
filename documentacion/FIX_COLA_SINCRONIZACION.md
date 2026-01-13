# Fix: Datos No Se Agregaban a Cola de Sincronización

## 🐛 Problema Identificado

Los datos de registro (usuario, fotos oreja, audios voz) **NO se estaban subiendo al backend** durante la sincronización manual, aunque el log mostraba "Subida EXITOSA ✅".

### Síntomas
```
[SyncManager] 📤 Subiendo datos locales al backend...
[SyncManager] 📤 Subida: EXITOSA ✅
```

Pero los datos (nombres, identificador único, etc.) **no llegaban al backend**.

## 🔍 Causa Raíz

El sistema tenía una lógica condicional problemática:

### Antes (❌ Incorrecto)
```dart
// Si HAY internet → enviar directamente al backend (NO agregar a cola)
if (_isOnline) {
  await backend.registrar(...);  // Envío directo
  // ❌ NO se agrega a cola_sincronizacion
}
// Si NO HAY internet → agregar a cola
else {
  await _localDb.insertToSyncQueue(...);  // ✅ SÍ se agrega
}
```

**Problema:** Cuando había conexión, los datos se enviaban directamente pero **no quedaban registrados en la cola**. Entonces cuando se ejecutaba `SyncManager.syncNow()` después, encontraba la cola vacía y retornaba éxito sin hacer nada.

## ✅ Solución Implementada

**SIEMPRE agregar a la cola de sincronización**, independientemente de si hay internet o no.

### Cambios Realizados

#### 1. `local_database_service.dart` - Método `insertUser`
```dart
Future<int> insertUser({...}) async {
  // ... código de inserción ...
  
  final userId = await db.insert('usuarios', userData, ...);
  
  // 🔥 NUEVO: SIEMPRE agregar a cola
  if (userId > 0) {
    print('[LocalDB] 📋 Agregando usuario a cola de sincronización...');
    await insertToSyncQueue(userId, 'usuario', 'crear', userData);
    print('[LocalDB] ✅ Usuario agregado a cola de sincronización');
  }
  
  return userId;
}
```

#### 2. `register_screen.dart` - Registro de Fotos de Oreja
```dart
// 🔥 SIEMPRE AGREGAR A COLA (online u offline)
print('[Register] 📋 Agregando fotos a cola de sincronización...');
try {
  final imagenesParaEnviar = earPhotos.whereType<Uint8List>().toList();
  for (int i = 0; i < imagenesParaEnviar.length; i++) {
    final photoBytes = imagenesParaEnviar[i];
    await _localDb.insertToSyncQueue(idUsuario, 'credencial', 'crear', {
      'identificador_unico': identificador,
      'tipo_biometria': 'oreja',
      'indice_foto': i,
      'template': photoBytes.toList(),
    });
  }
  print('[Register] ✅ ${imagenesParaEnviar.length} fotos agregadas a cola');
} catch (e) {
  print('[Register] ⚠️ Error agregando fotos a cola: $e');
}

// Si hay internet, enviar INMEDIATAMENTE
if (_isOnline) {
  try {
    await biometricBackend.registrarBiometriaOreja(...);
    print('[Register] ✅ Fotos enviadas al backend');
    // TODO: Marcar como 'enviado' en cola
  } catch (e) {
    print('[Register] ⚠️ Quedará en cola para reintento');
  }
}
```

#### 3. `register_screen.dart` - Registro de Audios de Voz
```dart
// 🔥 SIEMPRE AGREGAR A COLA (online u offline)
print('[Register] 📋 Agregando audios a cola de sincronización...');
try {
  final audiosParaEnviar = voiceAudios.whereType<Uint8List>().toList();
  for (int i = 0; i < audiosParaEnviar.length; i++) {
    final audioBytes = audiosParaEnviar[i];
    await _localDb.insertToSyncQueue(idUsuario, 'credencial', 'crear', {
      'identificador_unico': identificador,
      'tipo_biometria': 'voz',
      'indice_audio': i,
      'template': audioBytes.toList(),
    });
  }
  print('[Register] ✅ ${audiosParaEnviar.length} audios agregados a cola');
} catch (e) {
  print('[Register] ⚠️ Error agregando audios a cola: $e');
}

// Si hay internet, enviar INMEDIATAMENTE
if (_isOnline) {
  try {
    await biometricBackend.registrarBiometriaVoz(...);
    print('[Register] ✅ Audios enviados al backend');
    // TODO: Marcar como 'enviado' en cola
  } catch (e) {
    print('[Register] ⚠️ Quedará en cola para reintento');
  }
}
```

## 🎯 Resultado Esperado

Ahora cuando ejecutes una sincronización manual con `SyncManager.syncNow()`:

```
[SyncManager] 📤 Subiendo datos locales al backend...
[SyncManager] 📤 Subiendo 15 items pendientes...
[SyncManager] ✅ Usuario sincronizado: 1234567890
[SyncManager] ✅ Foto oreja sincronizada
[SyncManager] ✅ Foto oreja sincronizada
...
[SyncManager] ✅ Audio voz sincronizado
[SyncManager] 📊 Resultado: 15 exitosos, 0 fallidos
[SyncManager] 📤 Subida: EXITOSA ✅
```

## 📝 Archivos Modificados

1. `mobile_app/lib/services/local_database_service.dart`
   - Método `insertUser()` ahora agrega a cola automáticamente

2. `mobile_app/lib/screens/register_screen.dart`
   - Método `_saveFotosOreja()` siempre agrega fotos a cola
   - Método `_saveAudiosVoz()` siempre agrega audios a cola
   - Captura `idUsuario` correctamente en todos los flujos

## 🧪 Cómo Probar

1. **Limpiar base de datos local**:
   ```bash
   flutter run
   # En la app: Ir a Settings → Limpiar datos
   ```

2. **Registrar un nuevo usuario**:
   - Completar formulario
   - Capturar 7 fotos de oreja
   - Grabar 5 frases de voz
   - Finalizar registro

3. **Verificar cola de sincronización**:
   ```dart
   final pending = await _localDb.getPendingSyncQueue(idUsuario);
   print('Items en cola: ${pending.length}');
   // Debe mostrar: 1 usuario + 7 fotos + 5 audios = 13 items
   ```

4. **Ejecutar sincronización manual**:
   - Ir a Settings → Sincronizar ahora
   - Verificar logs en consola
   - Confirmar que los datos lleguen al backend

## ⚠️ Tareas Pendientes (TODO)

1. **Marcar items como 'enviado' en cola**: Cuando se envía exitosamente al backend durante el registro, marcar el item en la cola con estado 'enviado' para evitar duplicados.

2. **Deduplicación**: Implementar lógica para evitar enviar el mismo dato múltiples veces si ya fue sincronizado exitosamente.

3. **Limpieza de cola**: Agregar proceso para eliminar items antiguos con estado 'enviado' después de X días.

## 📅 Fecha
12 de enero de 2026

## 👤 Autor
Sistema de Autenticación Biométrica - Módulo de Sincronización
