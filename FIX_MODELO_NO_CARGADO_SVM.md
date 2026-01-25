# 🐛 FIX: "Modelo no cargado" en Autenticación por Voz

**Fecha:** 24 de enero de 2026  
**Problema:** Error "Modelo no cargado" al intentar autenticar, aunque el usuario existe

---

## 🔍 Problema Detectado

### Logs del Error:
```
[Login] ✅ Usuario 0503096083 encontrado en libvoz_mobile.so
[NativeVoiceMobile] 🔐 Autenticando...
[NativeVoiceMobile] ❌ Rechazado: {
  authenticated: false, 
  error: Modelo no cargado, 
  success: false
}
[Login] 📊 Resultado de autenticación:
[Login] {authenticated: false, error: Modelo no cargado, success: false}
```

### Análisis:
- **Usuario existe:** `usuarioExiste()` retorna `true` ✅
- **ID Usuario:** 1 (encontrado en SQLite de libvoz_mobile.so) ✅
- **Modelo SVM:** ❌ NO CARGADO (no se puede autenticar)

---

## 🔍 Causa Raíz

El error "Modelo no cargado" ocurre cuando:

1. **Usuario existe en DB pero sin modelo entrenado:**
   - Se creó el usuario (`crearUsuario()`) ✅
   - NO se entrenó el SVM (`registerBiometric()`) ❌

2. **Registro incompleto:**
   - Se registraron < 3 audios de voz
   - El SVM necesita al menos 3 muestras para entrenar

3. **Errores silenciosos en registro:**
   - `registerBiometric()` falló pero no se validó
   - El proceso continuó sin verificar éxito

---

## ✅ Soluciones Implementadas

### 1. **Validación en Login** (login_screen.dart)

#### Detección de Modelo No Entrenado:
```dart
// 🔍 VERIFICAR SI HAY ERROR DE MODELO NO CARGADO
if (resultado['success'] == false) {
  final error = resultado['error'] ?? 'Error desconocido';
  
  if (error.toString().contains('Modelo no cargado') ||
      error.toString().contains('No se pudo cargar el modelo')) {
    
    print('[Login] ⚠️ El usuario existe pero no tiene modelo SVM entrenado');
    
    throw Exception(
      'Modelo de voz no entrenado. Por favor:\n'
      '1. Elimina tu cuenta actual\n'
      '2. Regístrate nuevamente con 6 audios de voz\n'
      '3. Asegúrate de completar TODO el proceso de registro',
    );
  } else {
    throw Exception('Error en autenticación: $error');
  }
}
```

**Beneficio:** Muestra mensaje claro al usuario sobre qué hacer.

---

### 2. **Validación en Registro** (register_screen.dart)

#### Verificación de Audios Mínimos:
```dart
int plantillasGuardadas = 0;

for (int i = 0; i < voiceAudios.length; i++) {
  final audio = voiceAudios[i];
  if (audio != null) {
    final resultado = await nativeService.registerBiometric(
      identificador: identificador,
      audioPath: audioPath,
      idFrase: (i % 2) + 1,
    );

    if (resultado['success'] == true) {
      plantillasGuardadas++;  // ✅ Contador de éxitos
    } else {
      print('[Register] ! Audio #${i + 1}: ${resultado['error']}');
    }
  }
}

// ✅ VALIDACIÓN DE MÍNIMO 3 AUDIOS
const int minAudios = 3;
if (plantillasGuardadas < minAudios) {
  throw Exception(
    'Error en registro de voz: Solo se registraron $plantillasGuardadas de 6 audios.\n'
    'Se necesitan al menos $minAudios audios para entrenar el modelo.\n'
    'Por favor intenta registrarte nuevamente.',
  );
}

print('[Register] ✅ Modelo SVM entrenado con $plantillasGuardadas audios');
```

**Beneficio:** Garantiza que el SVM se entrene correctamente antes de completar registro.

---

## 📊 Flujo Correcto Ahora

### Registro:
```
1. Usuario graba 6 audios de voz
   ↓
2. Para cada audio:
   - Llamar registerBiometric()
   - Verificar resultado['success'] == true
   - Incrementar contador si éxito
   ↓
3. Validar plantillasGuardadas >= 3
   - Si < 3: Lanzar error, cancelar registro
   - Si >= 3: Continuar ✅
   ↓
4. Guardar en SQLite y cola de sincronización
   ↓
5. Mensaje: "✅ Modelo SVM entrenado con X audios"
```

### Login:
```
1. Verificar usuarioExiste()
   ↓
2. Llamar authenticate()
   ↓
3. Verificar resultado['success']
   - Si false y error = "Modelo no cargado":
     → Mostrar mensaje claro de re-registro
   - Si false por otra razón:
     → Mostrar error específico
   ↓
4. Si success = true:
   - Verificar predicted_class == expectedUserId
   - Solo autenticar si coinciden
```

---

## 🧪 Escenarios de Prueba

### Caso 1: Registro Exitoso (6 audios)
```
[Register] 🎤 Registrando audio de voz #1/6 con SVM...
[Register] ✅ Audio #1 registrado exitosamente con SVM
[Register] 🎤 Registrando audio de voz #2/6 con SVM...
[Register] ✅ Audio #2 registrado exitosamente con SVM
... (hasta 6)
[Register] 💾 Total plantillas registradas con SVM: 6/6
[Register] ✅ Modelo SVM entrenado con 6 audios
```

### Caso 2: Registro Parcial (< 3 audios)
```
[Register] 🎤 Registrando audio de voz #1/6 con SVM...
[Register] ✅ Audio #1 registrado exitosamente con SVM
[Register] 🎤 Registrando audio de voz #2/6 con SVM...
[Register] ! Audio #2: Error en extracción de MFCC
[Register] 💾 Total plantillas registradas con SVM: 2/6
[Register] ❌ ERROR: Solo se registraron 2 audios, se necesitan al menos 3

❌ Exception: Error en registro de voz: Solo se registraron 2 de 6 audios.
Se necesitan al menos 3 audios para entrenar el modelo.
Por favor intenta registrarte nuevamente.
```

### Caso 3: Login con Modelo No Entrenado
```
[Login] ✅ Usuario 0503096083 encontrado en libvoz_mobile.so
[NativeVoiceMobile] ❌ Rechazado: {error: Modelo no cargado, success: false}
[Login] ⚠️ El usuario existe pero no tiene modelo SVM entrenado

❌ Exception: Modelo de voz no entrenado. Por favor:
1. Elimina tu cuenta actual
2. Regístrate nuevamente con 6 audios de voz
3. Asegúrate de completar TODO el proceso de registro
```

---

## 🔧 Solución para Usuario Actual

Si tienes este error ahora, sigue estos pasos:

### Opción A: Re-registro (Recomendado)
```
1. Abre la app
2. (Si existe) Elimina la cuenta actual desde panel admin
3. Regístrate nuevamente:
   - Graba LOS 6 AUDIOS completos
   - No salgas del registro hasta ver "✅ Registro completo"
4. Intenta login nuevamente
```

### Opción B: Limpieza Manual (Desarrollador)
```bash
# 1. Desinstalar app (limpia SQLite)
flutter run --uninstall-first

# 2. O borrar datos manualmente
adb shell run-as com.example.biometrics_app
cd databases
rm -f biometric_auth.db*
```

---

## 📋 Cambios Técnicos

### Archivos Modificados:

1. **lib/screens/login_screen.dart**
   - Líneas ~915-933: Detección de "Modelo no cargado"
   - Mensaje de error mejorado con instrucciones

2. **lib/screens/register_screen.dart**
   - Líneas ~1003-1020: Validación de audios mínimos
   - Contador `plantillasGuardadas`
   - Excepción si < 3 audios registrados exitosamente

---

## 📊 Requisitos del SVM

### Mínimos para Entrenar:
- **3 audios** (mínimo absoluto)
- **6 audios** (recomendado para mejor precisión)

### Por qué 3 como mínimo:
- SVM necesita múltiples muestras para aprender patrones
- Con 1-2 audios: overfitting (memoriza, no generaliza)
- Con 3+ audios: puede entrenar modelo robusto

---

## ✅ Conclusión

**Problema:** ❌ Usuario existe pero modelo SVM no entrenado  
**Causa:** Registro incompleto o errores no validados  
**Solución:** 
- ✅ Validar >= 3 audios registrados exitosamente
- ✅ Mensaje claro en login si modelo no entrenado
- ✅ Bloquear registro si no hay suficientes audios

**Estado:** ✅ RESUELTO  
**Próximo paso:** Usuario debe **re-registrarse completamente** con 6 audios

¡Ahora el sistema garantiza que el modelo SVM esté entrenado antes de permitir login! 🎉
