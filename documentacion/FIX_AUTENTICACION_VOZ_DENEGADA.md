# Diagnóstico: Autenticación de Voz Denegada

## 📋 Problema Identificado

El backend respondió con `"access": false`, lo que significa **autenticación denegada**.

### Logs del Error:
```
[BiometricBackend] 🔐 Autenticando voz para: 0503096083 (frase: 7)
[BiometricBackend] ✅ Autenticación voz exitosa: {
  "access": false,  ← ❌ DENEGADO
  "all_scores": {
    "5168": 5.961144536176045,  ← Usuario con score más alto
    "0503096083": ???  ← No aparece en la lista o score muy bajo
  }
}
```

---

## 🔍 Diagnóstico

### 1. **¿El usuario está registrado en el backend de voz?**

**Verificar:**
```bash
# Endpoint: GET /listar/usuarios (si existe)
curl http://167.71.155.9:8081/listar/usuarios
```

O revisar los logs del backend de voz para ver usuarios registrados.

**Si NO está registrado:**
- ❌ El backend no tiene plantillas de voz para `0503096083`
- ✅ **Solución:** Registrar el usuario con 6 audios

```bash
# Registrar biometría de voz
POST http://167.71.155.9:8081/voz/registrar_biometria
Content-Type: multipart/form-data

identificador=0503096083
audios=[archivo1.wav, archivo2.wav, ..., archivo6.wav]
```

### 2. **¿La voz coincide?**

El backend compara tu audio contra todos los usuarios registrados:

```json
"all_scores": {
  "5168": 5.96,     ← Usuario 5168 tiene score más alto
  "6447": 2.68,
  "0503096083": ??? ← ¿Qué score tiene tu usuario?
}
```

**Posibilidades:**
- a) `0503096083` no aparece → **Usuario no registrado**
- b) `0503096083` tiene score bajo (ej: -10.5) → **Voz no coincide**
- c) Otro usuario tiene score más alto → **Falso positivo**

### 3. **¿Dijiste la frase correcta?**

El backend valida:
1. ✅ Que la voz coincida (comparación de embeddings)
2. ✅ Que digas la frase correcta (transcripción)

**Frase ID 7:**
- ¿Cuál es el texto de la frase 7?
- Verifica: `GET http://167.71.155.9:8081/listar/frases?id=7`

**Si dijiste algo diferente:**
- ❌ El backend rechaza aunque la voz coincida
- ✅ **Solución:** Di exactamente la frase mostrada en la app

---

## 🛠️ Pasos para Resolver

### Paso 1: Verificar si el usuario está registrado

**En la app móvil:**
1. Ir al **Panel de Administración**
2. Ver lista de usuarios sincronizados
3. Buscar `0503096083`

**En el backend:**
```bash
# Si tienes acceso al servidor
docker logs backend_voz | grep 0503096083
```

### Paso 2: Registrar usuario si es necesario

**Opción A: Desde la app móvil**
1. Ir a pantalla de **Registro**
2. Ingresar identificador: `0503096083`
3. Completar datos personales
4. **Registrar 7 fotos de oreja** (para biometría de oreja)
5. **Registrar 6 audios de voz** (para biometría de voz)
6. Verificar que el registro se sincronice con el backend

**Opción B: Desde Postman/curl**
```bash
# 1. Registrar usuario (datos básicos)
POST http://167.71.155.9:8080/registrar_usuario
Content-Type: application/json
{
  "identificador_unico": "0503096083",
  "nombres": "Test",
  "apellidos": "Usuario",
  "fecha_nacimiento": "1990-01-01",
  "sexo": "M"
}

# 2. Registrar biometría de voz (6 audios)
POST http://167.71.155.9:8081/voz/registrar_biometria
Content-Type: multipart/form-data

identificador=0503096083
audios=[audio1.wav, audio2.wav, audio3.wav, audio4.wav, audio5.wav, audio6.wav]
```

### Paso 3: Probar autenticación nuevamente

1. En la app, ir a **Login**
2. Ingresar identificador: `0503096083`
3. Seleccionar **Voz**
4. Esperar a que cargue la frase (ej: "Acceso seguro mediante biometría vocal")
5. **IMPORTANTE:** Leer la frase en voz alta claramente
6. Grabar audio
7. Intentar login

**Resultado esperado:**
```json
{
  "access": true,  ← ✅ AUTENTICADO
  "autenticado": true,
  "usuario_identificado": "0503096083"
}
```

### Paso 4: Revisar logs del backend

Si sigue fallando, revisar logs del servidor:

```bash
# En el servidor cloud
docker logs backend_voz --tail 100 | grep 0503096083
```

Buscar:
- ✅ `Usuario registrado: 0503096083`
- ✅ `Plantillas de voz encontradas: 6`
- ✅ `Score de similitud: 12.5` (debe ser > umbral, generalmente 10)
- ❌ `Usuario no encontrado`
- ❌ `Plantillas insuficientes`

---

## 🔧 Fix SQL Aplicado

Además del problema de autenticación, había un error en la base de datos SQLite:

```
table validaciones_biometricas has no column named modo_validacion
```

### Solución Implementada:

1. **Actualizada la versión de BD a v7**
2. **Agregadas columnas faltantes:**
   - `modo_validacion` (TEXT, default 'offline')
   - `ubicacion_gps` (TEXT)
   - `dispositivo_id` (TEXT)
   - `puntuacion_confianza` (REAL)
   - `duracion_validacion` (INTEGER)

3. **Migración automática:**
   - Al abrir la app, se ejecutará la migración v7
   - Las columnas se agregarán sin perder datos
   - Logs mostrarán: `✅ Migración v7: Tabla validaciones_biometricas actualizada`

---

## 📊 Comparación: Registro vs Login

| Aspecto | Registro | Login |
|---------|----------|-------|
| **Oreja** | 7+ fotos | 1 foto |
| **Voz** | 6 audios | 1 audio |
| **Backend** | Guarda plantillas | Compara con plantillas |
| **Resultado** | Embeddings guardados | Score de similitud |

---

## 🎯 Checklist de Verificación

Antes de intentar login de voz nuevamente:

- [ ] Usuario `0503096083` existe en el backend
- [ ] Usuario tiene **6 audios de voz registrados**
- [ ] La app muestra una **frase del backend** (no error)
- [ ] Dices la frase **exactamente como aparece en pantalla**
- [ ] El audio se graba **claramente** (sin ruido de fondo)
- [ ] La base de datos SQLite está en **versión 7** (migración aplicada)

---

## 💡 Tips para Mejorar la Autenticación de Voz

### 1. **Calidad del audio:**
- Grabar en ambiente silencioso
- Hablar claro y con volumen normal
- Mantener distancia constante del micrófono

### 2. **Frase correcta:**
- Leer la frase completa
- No agregar palabras adicionales
- Pronunciar claramente cada palabra

### 3. **Consistencia:**
- Usar el mismo dispositivo que para registro
- Grabar en condiciones similares (ruido, distancia)
- Mantener tono de voz natural

---

## 🚨 Errores Comunes

### Error 1: `Usuario no encontrado`
**Causa:** No hay plantillas registradas para ese identificador  
**Solución:** Completar registro de 6 audios

### Error 2: `Score muy bajo (ej: -10.5)`
**Causa:** Voz no coincide con plantillas  
**Solución:** 
- Verificar que usas el mismo usuario que registraste
- Repetir registro si la voz ha cambiado
- Mejorar calidad del audio

### Error 3: `Frase incorrecta`
**Causa:** No dijiste la frase exacta del ID enviado  
**Solución:** Leer exactamente lo que aparece en pantalla

---

## 📞 Siguiente Paso

1. **Verificar registro:**
   ```bash
   # Opción 1: Desde Postman
   GET http://167.71.155.9:8081/listar/usuarios
   
   # Buscar: 0503096083
   ```

2. **Si no está registrado:**
   - Ir a la app móvil
   - Pantalla de Registro
   - Completar las 3 etapas (datos + 7 fotos oreja + 6 audios voz)

3. **Si está registrado:**
   - Revisar logs del backend para ver el score real
   - Probar con mejor calidad de audio
   - Verificar que dices la frase correcta

---

**Fecha:** 8 de enero de 2026  
**Estado:** ✅ Fix SQL aplicado | ⚠️ Autenticación requiere verificación de registro
