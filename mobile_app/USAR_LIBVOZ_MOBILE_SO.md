# 🎯 GUÍA RÁPIDA: Usar libvoz_mobile.so para Registro y Login

## ❌ Problema Actual

El sistema está usando `BiometricService` que:
- ❌ Solo extrae 13 MFCCs (insuficiente)
- ❌ Acepta cualquier voz con 99%+ de similitud (no discrimina)
- ❌ No usa el clasificador SVM de `libvoz_mobile.so`

## ✅ Solución: Usar libvoz_mobile.so Directamente

La librería `libvoz_mobile.so` **YA HACE TODO**:
- ✅ Extrae **143 coeficientes MFCC** (robusto)
- ✅ Usa **Whisper** para verificar que la frase es correcta
- ✅ Clasifica con **SVM de 68 clases** entrenado
- ✅ Retorna **usuario predicho + confianza real**

---

## 📋 Pasos de Implementación

### 1. Copiar Assets (Solo Primera Vez)

```bash
# Ya hecho - libvoz_mobile.so está en:
# android/app/src/main/jniLibs/arm64-v8a/libvoz_mobile.so

# Ahora copiar los modelos SVM (68 archivos):
cd mobile_app
mkdir -p assets/models/v1
cp lib/config/entrega_flutter_mobile/assets/models/v1/* assets/models/v1/

# Copiar datasets:
mkdir -p assets/caracteristicas/v1
cp lib/config/entrega_flutter_mobile/assets/caracteristicas/v1/* assets/caracteristicas/v1/
```

### 2. Actualizar pubspec.yaml

```yaml
flutter:
  assets:
    - assets/models/v1/
    - assets/caracteristicas/v1/
```

### 3. Crear Servicio FFI Simplificado

Ya existe `NativeVoiceService` que tiene las funciones correctas.

### 4. Modificar Flujo de Login/Registro

**ANTES (incorrecto):**
```dart
// ❌ Usaba BiometricService que solo compara 13 MFCCs
final result = await bioService.validateVoice(
  audioData: audioBytes,
  targetPhrase: '',
  templateData: templateBytes,
);
```

**AHORA (correcto):**
```dart
// ✅ Usar libvoz_mobile.so que clasifica con SVM
final nativeService = NativeVoiceService();
await nativeService.initialize();

// Guardar audio en archivo temporal
final audioPath = await _saveAudioToTemp(audioBytes);

// AUTENTICAR con libvoz_mobile.so
final result = await nativeService.authenticate(
  identificador: cedula,
  audioPath: audioPath,
  idFrase: 1,
);

// result contiene:
// {
//   "authenticated": true/false,
//   "user_id": 29,
//   "confidence": 0.92,
//   "predicted_class": 29,
//   "message": "Autenticación exitosa"
// }
```

---

## 🔧 Actualización Necesaria

### Archivo: `lib/screens/login_screen.dart`

**Línea ~900-1000** (función `_loginConVoz`)

**REEMPLAZAR:**
```dart
// ❌ CÓDIGO VIEJO (usando BiometricService)
for (final tpl in plantillas) {
  final result = await bio.validateVoice(
    audioData: audioData,
    targetPhrase: '',
    templateData: Uint8List.fromList(tpl.template),
  );
  // ...
}
```

**POR:**
```dart
// ✅ CÓDIGO NUEVO (usando libvoz_mobile.so)
final nativeService = NativeVoiceService();
await nativeService.initialize();

// Guardar audio temporal
final tempDir = await getTemporaryDirectory();
final audioPath = '${tempDir.path}/auth_${DateTime.now().millisecondsSinceEpoch}.wav';
await File(audioPath).writeAsBytes(audioData);

// Autenticar con SVM
final resultado = await nativeService.authenticate(
  identificador: _cedulaController.text,
  audioPath: audioPath,
  idFrase: 1,
);

// Limpiar archivo temporal
await File(audioPath).delete();

if (resultado['authenticated'] == true) {
  // ✅ USUARIO AUTENTICADO
  final confidence = resultado['confidence'] as double;
  print('[Login] ✅ VOZ AUTENTICADA: ${(confidence * 100).toStringAsFixed(2)}%');
  
  setState(() {
    _statusMessage = 'Autenticación exitosa';
  });
  
  // Navegar a home
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => HomeScreen(userId: idUsuario)),
  );
} else {
  // ❌ VOZ NO RECONOCIDA
  print('[Login] ❌ VOZ RECHAZADA: ${resultado['message']}');
  
  setState(() {
    _statusMessage = 'Voz no reconocida. Intenta nuevamente.';
  });
}
```

---

## 🎯 Diferencias Clave

| Característica | BiometricService (VIEJO) | libvoz_mobile.so (NUEVO) |
|---|---|---|
| **MFCCs extraídos** | 13 coeficientes | 143 coeficientes |
| **Clasificador** | Similitud coseno simple | SVM con 68 clases |
| **Verificación de frase** | ❌ No verifica | ✅ Usa Whisper ASR |
| **Confianza** | 99%+ (demasiado alta) | 75-95% (realista) |
| **Discriminación** | ❌ Acepta cualquier voz | ✅ Solo voz registrada |
| **Procesamiento** | Dart (lento) | C++ nativo (rápido) |

---

## 📊 Resultado Esperado

### ANTES (Problema):
```
[Login] Comparando contra 6 plantillas...
[BiometricService] Similitud: 99.87% ✅ ACEPTADO
[BiometricService] Similitud: 99.89% ✅ ACEPTADO
[BiometricService] Similitud: 99.91% ✅ ACEPTADO
→ ❌ ACEPTA CUALQUIER VOZ
```

### DESPUÉS (Correcto):
```
[NativeVoice] Inicializando libvoz_mobile.so...
[NativeVoice] Cargando modelo SVM (68 clases)...
[NativeVoice] Extrayendo 143 MFCCs...
[NativeVoice] Clasificando con SVM...
[NativeVoice] Usuario predicho: 29, Confianza: 87.5%
→ ✅ SOLO ACEPTA VOZ REGISTRADA (Usuario 29)
```

---

## 🚀 Implementar Ahora

1. **Copiar modelos SVM a assets** (comando arriba)
2. **Actualizar pubspec.yaml** con assets
3. **Modificar login_screen.dart** línea ~900
4. **Modificar registro_screen.dart** si es necesario
5. **Recompilar:** `flutter build apk --debug`

---

## ⚠️ Notas Importantes

### Tamaño de Assets

Los modelos SVM pesan **~200 MB**. Para producción, considera:
```dart
// Descargar modelos en primer inicio en lugar de incluirlos en APK
Future<void> downloadModelsIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.getBool('models_downloaded') ?? false) {
    await downloadFromServer('models/v1/', localPath);
    await prefs.setBool('models_downloaded', true);
  }
}
```

### Inicialización

Solo inicializar `NativeVoiceService` **UNA VEZ** al inicio de la app:
```dart
// En main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final nativeService = NativeVoiceService();
  await nativeService.initialize();
  
  runApp(MyApp());
}
```

---

**Estado:** ✅ Solución lista para implementar  
**Siguiente paso:** Actualizar login_screen.dart y recompilar
