# 🧪 GUÍA RÁPIDA DE PRUEBAS - Backend en la Nube

## 🚀 Comandos Rápidos

### 1. Ejecutar la App
```bash
cd mobile_app
flutter run
```

### 2. Verificar Backend con cURL (desde PowerShell)

#### Probar Backend de Oreja (puerto 8080):
```powershell
# Test básico de conectividad
Invoke-WebRequest -Uri "http://167.71.155.9:8080/" -Method GET
```

#### Probar Backend de Voz (puerto 8081):
```powershell
# Listar frases disponibles
Invoke-WebRequest -Uri "http://167.71.155.9:8081/listar/frases" -Method GET

# Obtener frase aleatoria
Invoke-WebRequest -Uri "http://167.71.155.9:8081/frases/aleatoria" -Method GET
```

---

## 📝 Orden de Pruebas Recomendado

### FASE 1: Conectividad
1. ✅ Verificar que backend responde (cURL)
2. ✅ Abrir `cloud_backend_example.dart`
3. ✅ Presionar botón "11. Verificar Conectividad"
4. ✅ Debería mostrar "BACKEND EN LÍNEA"

### FASE 2: Usuarios
5. ✅ Presionar "1. Registrar Usuario"
6. ✅ Verificar mensaje de éxito
7. ✅ Presionar "2. Eliminar Usuario" (soft delete)
8. ✅ Presionar "3. Restaurar Usuario"

### FASE 3: Biometría de Oreja
9. ⚠️ Modificar código para capturar fotos reales (7+)
10. ✅ Presionar "4. Registrar Biometría Oreja"
11. ⚠️ Modificar código para capturar 1 foto real
12. ✅ Presionar "5. Autenticar con Oreja"
13. ✅ Verificar logs: debe pasar TFLite primero

### FASE 4: Biometría de Voz
14. ⚠️ Modificar código para grabar audios reales (6)
15. ✅ Presionar "6. Registrar Biometría Voz"
16. ✅ Presionar "9. Obtener Frase Aleatoria"
17. ⚠️ Modificar código para grabar audio de la frase
18. ✅ Presionar "7. Autenticar con Voz"

### FASE 5: Frases Dinámicas
19. ✅ Presionar "8. Listar Frases"
20. ✅ Presionar "10. Agregar Nueva Frase"
21. ✅ Verificar que aparece en la lista

---

## 🔧 Modificaciones Necesarias para Pruebas Reales

### Capturar Fotos de Oreja

En `cloud_backend_example.dart`, buscar `_testRegistrarOreja()` y reemplazar:

```dart
// ANTES (dummy data):
List<Uint8List> fotos = [];
for (int i = 0; i < 7; i++) {
  fotos.add(Uint8List(100)); // Dummy data
}

// DESPUÉS (fotos reales):
List<Uint8List> fotos = [];
for (int i = 0; i < 7; i++) {
  // Usar tu servicio de cámara
  final XFile? image = await ImagePicker().pickImage(
    source: ImageSource.camera,
  );
  if (image != null) {
    final bytes = await image.readAsBytes();
    fotos.add(bytes);
  }
}
```

### Capturar Audios de Voz

En `cloud_backend_example.dart`, buscar `_testRegistrarVoz()` y reemplazar:

```dart
// ANTES (dummy data):
List<Uint8List> audios = [];
for (int i = 0; i < 6; i++) {
  audios.add(Uint8List(100)); // Dummy data
}

// DESPUÉS (audios reales):
List<Uint8List> audios = [];
for (int i = 0; i < 6; i++) {
  // Usar tu servicio de grabación
  final audioPath = await grabarAudio(duracion: 5); // 5 segundos
  final audioBytes = await File(audioPath).readAsBytes();
  audios.add(Uint8List.fromList(audioBytes));
}
```

---

## 📊 Logs Esperados

### Login Exitoso (Oreja):
```
[AuthService] 🔍 Validando imagen con TFLite antes de login...
[AuthService] 📊 TFLite Result:
[AuthService]   - Confianza: 87.3%
[AuthService]   - Es válida: true
[AuthService] ✅ Imagen aprobada por TFLite - procediendo con backend...
[AuthService] 🌐 Autenticando con backend en la nube...
[BiometricBackend] 🔐 Autenticando oreja para: 0102030405
[BiometricBackend] ✅ Autenticación exitosa: {autenticado: true, margen: 0.31, ...}
```

### Login Rechazado (TFLite):
```
[AuthService] 🔍 Validando imagen con TFLite antes de login...
[AuthService] 📊 TFLite Result:
[AuthService]   - Confianza: 45.2%
[AuthService]   - Es válida: false
[AuthService] ❌ Imagen rechazada por TFLite: No es oreja clara
```

### Login Fallido (Backend):
```
[AuthService] 🔍 Validando imagen con TFLite antes de login...
[AuthService] ✅ Imagen aprobada por TFLite - procediendo con backend...
[BiometricBackend] 🔐 Autenticando oreja para: 0102030405
[BiometricBackend] ⚠️ Autenticación fallida (401)
```

### Modo Offline:
```
[AuthService] ⚠️ Backend no disponible: DioException
[AuthService] 🔄 Usando fallback local...
[LocalDatabase] 🔍 Comparando con 3 templates locales...
[BiometricService] ✅ Match encontrado: 82.5%
```

---

## 🐛 Troubleshooting

### Error: "Connection refused"
**Causa:** Backend no está corriendo o firewall bloqueando  
**Solución:**
1. Verificar que backend está up: `curl http://167.71.155.9:8080`
2. Verificar firewall del servidor
3. Verificar que el puerto está abierto

### Error: "Se requieren al menos 7 imágenes"
**Causa:** No estás enviando suficientes fotos  
**Solución:**
1. Verificar que `imagenes.length >= 7`
2. Capturar más fotos antes de enviar

### Error: "El usuario no tiene credencial biometrica de tipo oreja activa"
**Causa:** No has registrado biometría primero  
**Solución:**
1. Primero: Registrar usuario (`registrarUsuario()`)
2. Luego: Registrar biometría (`registrarBiometriaOreja()`)
3. Finalmente: Autenticar (`autenticarOreja()`)

### Error: "TFLite rechaza todas las imágenes"
**Causa:** Imágenes de baja calidad o no son orejas  
**Solución:**
1. Asegurar buena iluminación
2. Enfocar bien la oreja
3. Evitar sombras fuertes
4. Usar fondo uniforme

---

## 📈 Métricas de Éxito

### Registro de Oreja:
- ✅ 7+ fotos capturadas
- ✅ Backend responde 200
- ✅ Mensaje: "Credencial biométrica registrada correctamente"

### Autenticación de Oreja:
- ✅ TFLite aprueba (>=65%)
- ✅ Backend responde 200
- ✅ `autenticado: true`
- ✅ `margen >= 0.25`

### Registro de Voz:
- ✅ 6 audios grabados (.flac o .wav)
- ✅ Backend responde 200
- ✅ Mensaje: "Biometría de voz registrada"

### Autenticación de Voz:
- ✅ Frase aleatoria obtenida
- ✅ Audio contiene frase correcta
- ✅ Backend responde 200
- ✅ `autenticado: true`

---

## 🎯 Casos de Prueba Completos

### Test 1: Usuario Nuevo Completo
```
1. Registrar usuario (0102030405)
2. Capturar 7 fotos de oreja
3. Registrar biometría de oreja
4. Capturar 1 foto de autenticación
5. Autenticar → Debería ✅ ÉXITO
```

### Test 2: Validación TFLite Estricta
```
1. Registrar usuario (0102030405)
2. Capturar 7 fotos de oreja
3. Registrar biometría de oreja
4. Intentar autenticar con objeto random (no oreja)
5. TFLite debería rechazar → ❌ RECHAZO
```

### Test 3: Usuario Inexistente
```
1. Intentar autenticar con usuario que NO existe
2. Backend debería responder 404 → ❌ NO ENCONTRADO
```

### Test 4: Modo Offline
```
1. Desconectar WiFi/datos
2. Intentar autenticar
3. Debería usar fallback local → ⚠️ OFFLINE
4. Reconectar
5. Datos deberían sincronizarse → ✅ SYNC
```

---

## 💡 Tips

1. **Siempre registrar ANTES de autenticar**
2. **Capturar fotos con buena iluminación**
3. **Grabar audios en ambiente silencioso**
4. **Verificar logs en tiempo real** (`flutter run --verbose`)
5. **Probar primero con conectividad**, luego offline

---

## 📞 Comandos de Diagnóstico

### Ver estado de la app:
```bash
flutter doctor
```

### Ver logs en tiempo real:
```bash
flutter logs
```

### Limpiar y reconstruir:
```bash
flutter clean
flutter pub get
flutter run
```

### Verificar conectividad desde PowerShell:
```powershell
Test-NetConnection -ComputerName 167.71.155.9 -Port 8080
Test-NetConnection -ComputerName 167.71.155.9 -Port 8081
```

---

**¡Buena suerte con las pruebas! 🚀**
