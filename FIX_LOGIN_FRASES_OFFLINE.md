# 🔧 FIX: Sistema de Frases en Login (Offline/Online)

## 📋 Problema
En el login, el sistema intentaba cargar frases desde la base de datos local en modo offline, generando dependencia innecesaria de SQLite y complejidad adicional.

## ✅ Solución Implementada

### **Modo OFFLINE** 📱
Se usan **2 frases hardcodeadas** que se seleccionan aleatoriamente:

```dart
final offlinePhrases = [
  {'id': 1, 'frase': 'Mi voz es mi contraseña'},
  {'id': 2, 'frase': 'Autorizo esta transacción'},
];
```

**Ventajas:**
- ✅ Sin dependencia de base de datos SQLite
- ✅ Funciona 100% offline sin configuración
- ✅ Más rápido (no hay consultas a disco)
- ✅ Código más simple y mantenible

### **Modo ONLINE** 🌐
Se consulta el backend para obtener frases dinámicas desde la base de datos PostgreSQL:

```dart
final phraseData = await backendService.obtenerFraseAleatoria();
```

**Ventajas:**
- ✅ Frases dinámicas y actualizables desde el backend
- ✅ Mayor variedad de frases para autenticación
- ✅ Sincronización con el servidor central

## 📊 Comparación

| Característica | ANTES (SQLite local) | AHORA (Hardcoded/Backend) |
|---------------|---------------------|---------------------------|
| Modo Offline | Consulta SQLite | 2 frases hardcodeadas |
| Modo Online | Backend | Backend |
| Complejidad | Alta (3 fallbacks) | Baja (2 modos claros) |
| Dependencias | SQLite + Backend | Solo Backend (online) |
| Velocidad Offline | Lenta (I/O disco) | Instantánea (memoria) |

## 🔍 Código Modificado

**Archivo:** `lib/screens/login_screen.dart`

### Función `_loadRandomPhrase()`

```dart
Future<void> _loadRandomPhrase() async {
  setState(() {
    _isLoadingPhrase = true;
    _currentPhrase = null;
    _currentPhraseId = null;
  });

  try {
    final backendService = BiometricBackendService();
    final isOnline = await backendService.isOnline();

    if (isOnline) {
      // 🌐 Modo ONLINE: Backend
      print('[Login] 🌐 Obteniendo frase aleatoria del backend...');

      final phraseData = await backendService.obtenerFraseAleatoria();

      setState(() {
        _currentPhraseId = phraseData['id_texto'] ?? phraseData['id'];
        _currentPhrase = phraseData['frase'];
        _isLoadingPhrase = false;
      });

      print('[Login] ✅ Frase cargada: $_currentPhrase (ID: $_currentPhraseId)');
    } else {
      // 📱 Modo OFFLINE: 2 frases hardcodeadas
      print('[Login] 📱 Modo OFFLINE - usando frases predefinidas...');

      final offlinePhrases = [
        {'id': 1, 'frase': 'Mi voz es mi contraseña'},
        {'id': 2, 'frase': 'Autorizo esta transacción'},
      ];

      // Seleccionar una frase aleatoria de las 2 disponibles
      final random = DateTime.now().millisecondsSinceEpoch % 2;
      final selectedPhrase = offlinePhrases[random];

      setState(() {
        _currentPhrase = selectedPhrase['frase'] as String;
        _currentPhraseId = selectedPhrase['id'] as int;
        _isLoadingPhrase = false;
      });

      print('[Login] ✅ Frase offline cargada: $_currentPhrase (ID: $_currentPhraseId)');
    }
  } catch (e) {
    print('[Login] ❌ Error cargando frase: $e');

    // Fallback: usar frases offline predefinidas
    final offlinePhrases = [
      {'id': 1, 'frase': 'Mi voz es mi contraseña'},
      {'id': 2, 'frase': 'Autorizo esta transacción'},
    ];

    final random = DateTime.now().millisecondsSinceEpoch % 2;
    final selectedPhrase = offlinePhrases[random];

    setState(() {
      _currentPhrase = selectedPhrase['frase'] as String;
      _currentPhraseId = selectedPhrase['id'] as int;
      _isLoadingPhrase = false;
    });

    print('[Login] ✅ Frase offline cargada (fallback): $_currentPhrase (ID: $_currentPhraseId)');
  }
}
```

## 🧹 Código Eliminado

Se eliminaron las siguientes funciones y variables no utilizadas:

1. **Función `_showOfflineMessage()`** - Ya no se necesita
2. **Variable `_lastOfflineMessageTime`** - Ya no se usa

## 🎯 Casos de Uso

### Caso 1: Usuario sin conexión
```
1. Usuario abre app sin WiFi/datos
2. Selecciona "Voz" como método de login
3. Sistema carga instantáneamente: "Mi voz es mi contraseña" o "Autorizo esta transacción"
4. Usuario graba audio y se autentica localmente con libvoz_mobile.so
```

### Caso 2: Usuario con conexión
```
1. Usuario abre app con WiFi/datos
2. Selecciona "Voz" como método de login
3. Sistema consulta backend → obtiene frase dinámica (ej: "La seguridad es prioridad")
4. Usuario graba audio y se autentica (cloud-first, luego local fallback)
```

## 📝 Logs Esperados

### Modo Offline:
```
[Login] 📱 Modo OFFLINE - usando frases predefinidas...
[Login] ✅ Frase offline cargada: Mi voz es mi contraseña (ID: 1)
```

### Modo Online:
```
[Login] 🌐 Obteniendo frase aleatoria del backend...
[Login] ✅ Frase cargada: La seguridad es prioridad (ID: 42)
```

### Error con Fallback:
```
[Login] ❌ Error cargando frase: Connection refused
[Login] ✅ Frase offline cargada (fallback): Autorizo esta transacción (ID: 2)
```

## ✅ Validación

- [x] Código compila sin errores
- [x] Eliminadas funciones no utilizadas (`_showOfflineMessage`)
- [x] Eliminadas variables no utilizadas (`_lastOfflineMessageTime`)
- [x] Modo offline usa frases hardcodeadas (2 opciones)
- [x] Modo online consulta backend
- [x] Fallback en caso de error usa frases hardcodeadas

## 🚀 Próximos Pasos

1. **Probar modo offline**: Deshabilitar WiFi/datos y verificar que use frases hardcodeadas
2. **Probar modo online**: Verificar que consulte backend correctamente
3. **Validar autenticación**: Confirmar que ambos modos autentican exitosamente

---

**Fecha:** 25 de enero de 2026  
**Archivo Modificado:** `lib/screens/login_screen.dart`  
**Líneas Modificadas:** ~285-350
