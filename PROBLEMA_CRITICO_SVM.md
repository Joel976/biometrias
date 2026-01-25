# ⚠️ LIMITACIÓN: SVM Requiere Mínimo 2 Usuarios

**Fecha:** 24 de enero de 2026  
**Estado:** ⚠️ **LIMITACIÓN CONOCIDA** - Comportamiento esperado de SVM

---

## 🔍 El Problema

**Clasificador SVM con 1 clase:**
```
Modelo SVM: Solo 1 usuario registrado
Entrada: CUALQUIER audio (voz A, voz B, ruido, etc.)
Predicción: SIEMPRE "Usuario 1" (100%)
Confianza: 1,211,456,799 (sin sentido)
Resultado: ✅ ACEPTA TODO ← INCORRECTO
```

**Por qué pasa esto:**
- SVM es un clasificador **multiclase**
- Necesita **mínimo 2 clases** para comparar
- Con 1 clase no hay alternativas → siempre predice esa clase

---

## ✅ Solución Implementada

### **Validación en Login:**

```dart
// login_screen.dart - Líneas 914-928

if (allScoresMap.length == 1) {
  throw Exception(
    'El sistema necesita al menos 2 usuarios registrados.\n'
    'Actualmente solo hay 1 usuario en el modelo SVM.\n'
    'Por favor registra otro usuario para habilitar la autenticación.'
  );
}
```

**Ahora el sistema:**
1. ✅ Detecta cuando solo hay 1 usuario
2. ✅ Rechaza autenticación con mensaje claro
3. ✅ Instruye al usuario a registrar otro usuario

---

## � Comparación

| Escenario | Comportamiento | Estado |
|-----------|----------------|--------|
| **1 usuario** | Acepta cualquier audio | ❌ No válido |
| **2+ usuarios** | Compara y valida correctamente | ✅ Funciona |

**Logs con 1 usuario:**
```
all_scores: {1: 0.825}  ← Solo 1 clase
confidence: 1211456799  ← Sin sentido
authenticated: true     ← Siempre true
```

**Logs con 2+ usuarios:**
```
all_scores: {1: 0.85, 2: -0.3}  ← 2 clases
confidence: 1.35                ← (0.85 - (-0.3)) / 0.85
authenticated: true si score > umbral
```

---

## 🎯 Recomendaciones

1. **Para desarrollo:** Crea 2 usuarios de prueba con voces diferentes
2. **Para producción:** Considera pre-cargar modelo con usuarios genéricos
3. **Alternativa:** Usar umbral de confianza absoluto (ej: score > 0.8)

---

Modificar `libvoz_mobile.so` para re-entrenar SVM después de registro.

### Opción 3: Workaround (30 min)

Deshabilitar autenticación offline hasta tener modelo actualizado.

---

## 🚨 Acción Requerida

**Habla con tu compañero para decidir:**
1. ¿Backend de re-entrenamiento? (Recomendado)
2. ¿Modificar librería C++?
3. ¿Solo auth online por ahora?

**NO USES EN PRODUCCIÓN** sin resolver esto.
