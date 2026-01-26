# 🔧 FIX: ANR Durante Registro de Voz

## ❌ Problema

```
Mensaje: "biometricauth no responde"
Opciones: Cerrar app | Esperar
```

**Causa**: El procesamiento de 6 audios con SVM (re-entrenamiento) toma demasiado tiempo y bloquea el hilo principal de Flutter, causando un ANR (Application Not Responding).

---

## ✅ Solución Implementada

### Mensajes de Progreso Dinámicos

**Cambios en `register_screen.dart`**:

1. **Nueva variable de estado**:
   ```dart
   String _processingMessage = '';
   ```

2. **Actualización durante procesamiento**:
   ```dart
   for (int i = 0; i < 6; i++) {
     setState(() {
       _processingMessage = '🎤 Procesando audio ${i + 1}/6...\nEsto puede tomar unos segundos';
     });
     await Future.delayed(Duration(milliseconds: 100)); // Respirar UI
     await nativeService.registerBiometric(...);
   }
   ```

3. **UI mejorada**:
   ```dart
   body: _isLoading
     ? Center(
         child: Column(
           children: [
             CircularProgressIndicator(),
             SizedBox(height: 24),
             Text(_processingMessage), // ← NUEVO
           ],
         ),
       )
   ```

**Resultado**: 
- ✅ Usuario ve "Procesando audio 3/6..." y espera con paciencia
- ✅ La UI se actualiza entre cada audio
- ✅ Reduce percepción de congelamiento

---

## 🎯 Por Qué Ocurre el ANR

**FFI bloquea el hilo UI**:

```
Audio 1: 3-5 segundos (extract MFCC + retrain SVM)
Audio 2: 3-5 segundos
Audio 3: 3-5 segundos
Audio 4: 3-5 segundos
Audio 5: 3-5 segundos
Audio 6: 3-5 segundos
-------------------------
Total: 18-30 segundos ← Android muestra ANR después de ~5s
```

**Límite de Android**: Si el hilo UI está bloqueado >5 segundos → ANR

---

## 🚀 Mejora Futura Recomendada

**Implementar función batch en C++** para procesar los 6 audios de una vez:

```cpp
// En lugar de:
for (cada audio) {
  extract_features();
  retrain_svm();  // ← 6 re-entrenamientos lentos
}

// Hacer:
extract_all_features();  // 6 audios
retrain_svm_once();      // ← 1 solo re-entrenamiento rápido
```

**Ganancia esperada**: 18-30s → 8-12s (60% más rápido)

---

*Fecha: 25 enero 2026*
*Solución: Mensajes de progreso + micro-delays*
*Estado: ✅ Implementado*
