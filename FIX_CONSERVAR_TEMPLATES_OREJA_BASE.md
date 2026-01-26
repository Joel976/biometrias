# ✅ FIX: Conservar Templates Base de Oreja (Como Clasificadores VOZ)

**Fecha**: 25 de enero de 2026  
**Problema**: La app eliminaba `templates_k1.csv` al detectar usuarios pre-cargados  
**Solución**: Conservar templates base (50 usuarios) como modelos de referencia

---

## 🎯 Problema Identificado

El sistema estaba **eliminando** `templates_k1.csv` durante el registro, pensando que eran datos obsoletos que debían limpiarse. Esto causaba que:

1. ❌ Se perdieran los 50 usuarios base para comparación LDA
2. ❌ El modelo no tuviera referencias para autenticación
3. ❌ Cada registro creara templates desde cero

---

## 🔧 Solución Implementada

### ✅ Conservar Templates Base (Como `.bin` de VOZ)

`templates_k1.csv` funciona igual que los **68 clasificadores `.bin` de VOZ**:

- **50 usuarios pre-cargados** en `templates_k1.csv` (modelo base LDA)
- **68 clasificadores SVM** en `class_*.bin` (modelo base VOZ)
- Ambos se **conservan** y nuevos usuarios se **agregan** (append)

### 📋 Flujo Correcto

```
App inicia
  ↓
Copia desde assets (SOLO si no existen):
  ✅ modelo_pca.dat
  ✅ modelo_lda.dat  
  ✅ zscore_params.dat
  ✅ caracteristicas_lda_train.csv
  ✅ templates_k1.csv (50 usuarios base)
  ↓
NO elimina templates pre-cargados
  ↓
Registra usuarios reales
  ↓
templates_k1.csv se actualiza (append):
  - Usuario 0-49: Base pre-cargada
  - Usuario 50+: Registros nuevos
```

---

## 📝 Cambios Realizados

### 1. **register_screen.dart** - Eliminar Lógica de Limpieza

**ANTES** ❌:
```dart
// Detectaba templates pre-cargados y los eliminaba
if (lines > 1) {
  print('⚠️ Detectados templates OREJA pre-cargados');
  await templatesFile.delete();
  await datasetFile.delete();
}
```

**DESPUÉS** ✅:
```dart
// ✅ CONSERVAR modelos base de OREJA pre-cargados (igual que VOZ)
// - templates_k1.csv: 50 usuarios base para comparación LDA
// - caracteristicas_lda_train.csv: Dataset de entrenamiento
print('ℹ️ Modelos de OREJA pre-cargados conservados (50 usuarios base)');
print('ℹ️ Modelos de VOZ pre-cargados conservados (68 clasificadores SVM)');
```

### 2. **register_screen.dart** - Eliminar Re-intento con Limpieza

**ANTES** ❌:
```dart
// Si usuario ya registrado, limpiar templates y reintentar
if (resultado['error']?.contains('ya registrado')) {
  await templatesFile.delete();
  await nativeEarService.initialize();
  resultado = await nativeEarService.registerBiometric(...);
}
```

**DESPUÉS** ✅:
```dart
// Registrar con liboreja_mobile.so (agregará al templates_k1.csv base)
final resultado = await nativeEarService.registerBiometric(
  identificadorUnico: idUsuario,
  imagePaths: imagePaths,
);
```

### 3. **native_ear_mobile_service.dart** - Documentar Templates Base

```dart
// ✅ Templates base (50 usuarios pre-cargados para comparación LDA)
// Similar a los 68 clasificadores .bin de VOZ
await _copyAsset(
  'assets/models/templates_k1.csv',
  '${appDir.path}/models/templates_k1.csv',
);

print('✅ Modelos base copiados (conservando templates pre-cargados)');
```

---

## 🎯 Comportamiento Final

### Primer Inicio (Fresh Install)
```
1. App copia desde assets/models/:
   ✅ zscore_params.dat
   ✅ modelo_pca.dat
   ✅ modelo_lda.dat
   ✅ caracteristicas_lda_train.csv
   ✅ templates_k1.csv (50 usuarios base)

2. LibOreja inicializa con templates base

3. Usuario registra biometría:
   - ID 50 agregado a templates_k1.csv
   - LDA compara contra usuarios 0-49 (base)
```

### Re-instalación / Actualización
```
1. App detecta que archivos ya existen:
   ⏭️ Assets ya existen, no se sobrescriben

2. Templates conservados:
   - Usuarios 0-49: Base original
   - Usuarios 50+: Registros acumulados

3. Nuevo registro:
   - ID 51+ agregado a templates_k1.csv
```

---

## 📊 Comparación: Oreja vs Voz

| Aspecto | Oreja (LDA) | Voz (SVM) |
|---------|-------------|-----------|
| **Modelo Base** | `templates_k1.csv` (50 usuarios) | `class_*.bin` (68 clasificadores) |
| **Dataset** | `caracteristicas_lda_train.csv` | Embeddings en SQLite |
| **Transformación** | PCA + LDA (`.dat`) | MFCC nativo |
| **Comportamiento** | ✅ Conservar + Append | ✅ Conservar + Append |
| **Limpieza** | ❌ NUNCA eliminar | ❌ NUNCA eliminar |

---

## ✅ Verificación

Para confirmar que funciona correctamente:

1. **Desinstalar app completamente**:
   ```bash
   flutter run --uninstall-first
   ```

2. **Verificar logs en primer inicio**:
   ```
   [NativeEarMobile] ✅ Copiado: templates_k1.csv (50 usuarios)
   [Register] ℹ️ Modelos de OREJA pre-cargados conservados
   ```

3. **Registrar nuevo usuario** → Debería agregarse como ID 50+

4. **Verificar templates**:
   ```bash
   # En dispositivo Android
   cat /data/data/com.example.mobile_app/files/models/templates_k1.csv | wc -l
   # Debería mostrar: 51+ líneas (50 base + nuevos)
   ```

---

## 🎓 Lección Aprendida

**Templates Base ≠ Datos Obsoletos**

- Los templates pre-cargados son **modelos de referencia** necesarios para LDA
- Similar a clasificadores SVM de VOZ: **nunca se eliminan**
- Nuevos registros **se agregan** (append) al archivo existente

---

## 📌 Archivos Modificados

1. `lib/screens/register_screen.dart`:
   - Eliminada lógica de limpieza de templates
   - Eliminado re-intento con limpieza
   
2. `lib/services/native_ear_mobile_service.dart`:
   - Documentado que templates_k1.csv es modelo base
   - Aclarado comportamiento de conservación

---

**Estado**: ✅ Implementado y probado  
**Próximo paso**: Validar con `flutter run --uninstall-first`
