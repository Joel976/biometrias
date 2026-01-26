import 'package:flutter/material.dart';
import '../services/auth_service_fix.dart';
import '../services/camera_service.dart';
import '../services/audio_service.dart';
import '../services/local_database_service.dart';
import '../services/ear_validator_service.dart';
import '../services/admin_settings_service.dart';
import '../services/biometric_backend_service.dart';
import '../services/native_voice_mobile_service.dart';
import '../services/native_ear_mobile_service.dart';
import '../models/biometric_models.dart';
import '../widgets/app_logo.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'camera_capture_screen.dart';
import 'admin_access_button.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthServiceFix.instance;
  final _cameraService = CameraService();
  final _audioService = AudioService();
  final _earValidator = EarValidatorService();
  final _adminService = AdminSettingsService();

  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  int _selectedBiometricType = 1; // 1: Oreja, 2: Voz
  bool _isLoading = false;
  String? _errorMessage;
  Uint8List? _capturedPhoto;
  Uint8List? _recordedAudio;
  bool _usingBiometrics = true;
  bool _isRecordingNow = false;
  int _loginAttempts = 0; // Contador de intentos
  DateTime? _lockoutUntil; // Bloqueo temporal

  // 🔐 NUEVO: Sistema de autenticación dual (oreja + voz)
  bool _earAuthCompleted = false; // ✅ Si se validó con éxito la oreja
  bool _voiceAuthCompleted = false; // ✅ Si se validó con éxito la voz

  // 🎤 Variables para autenticación de voz (2 frases)
  final List<String> _voicePhrases = []; // Lista de 2 frases
  final List<int> _voicePhraseIds = []; // Lista de 2 IDs
  String?
  _currentPhrase; // Frase actual mostrada (no se usa, pero se mantiene por compatibilidad)
  int?
  _currentPhraseId; // ID de frase actual (no se usa, pero se mantiene por compatibilidad)
  bool _isLoadingPhrase = false; // Cargando frase desde backend
  bool _isPlayingAudio = false; // Estado de reproducción de audio

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _checkBiometricRequirement(); // Verificar si biometría es obligatoria
  }

  Future<void> _checkBiometricRequirement() async {
    final settings = await _adminService.loadSettings();

    // Si biometría es obligatoria, forzar el uso
    if (settings.biometricRequired) {
      setState(() {
        _usingBiometrics = true;
      });
    }
  }

  Future<void> _initializeServices() async {
    try {
      await _cameraService.initializeCameras();
      await _audioService.initialize();
      await _earValidator.initialize(); // Inicializar validador de orejas
    } catch (e) {
      setState(() {
        _errorMessage = 'Error inicializando servicios: $e';
      });
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _cameraService.dispose();
    _audioService.dispose();
    _earValidator.dispose(); // Liberar recursos del validador
    super.dispose();
  }

  /// 📶 Mostrar mensaje de "sin conexión" controlado por intervalo configurable
  Future<void> _capturePhotoForAuth() async {
    try {
      setState(() => _isLoading = true);

      // Usar CameraCaptureScreen con preview y validación
      final photoBytes = await Navigator.of(context).push<Uint8List?>(
        MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
      );

      if (photoBytes == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 🧠 VALIDAR QUE SEA UNA OREJA con TensorFlow Lite (si está habilitado)
      final settings = await _adminService.loadSettings();

      if (settings.enableEarValidation) {
        final validationResult = await _earValidator.validateEar(photoBytes);

        if (!validationResult.isValid) {
          final errorMsg =
              validationResult.error ??
              '⚠️ La imagen no parece ser una oreja válida. '
                  'Confianza: ${validationResult.confidencePercentage}. '
                  'Por favor, intenta de nuevo.';

          setState(() {
            _isLoading = false;
            _errorMessage = errorMsg;
          });

          // ⏱️ Limpiar el mensaje después de 5 segundos
          Future.delayed(Duration(seconds: 5), () {
            if (mounted && _errorMessage == errorMsg) {
              setState(() {
                _errorMessage = null;
              });
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ No es una oreja válida (${validationResult.confidencePercentage})',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }

        // ✅ Es una oreja válida con IA
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Foto capturada (${validationResult.confidencePercentage})',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Validación deshabilitada
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Foto capturada'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // ✅ Recortar solo la zona de la oreja antes de guardar
      final croppedImage = CameraService.cropEarRegion(photoBytes);

      debugPrint(
        '[Login] 📸 Imagen recortada: ${photoBytes.length} bytes → ${croppedImage.length} bytes',
      );

      // ✅ Guardar foto recortada
      setState(() {
        _capturedPhoto = croppedImage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error capturando foto: $e';
      });
    }
  }

  Future<void> _recordVoiceForAuth() async {
    try {
      // Verificar si está grabando (ahora es async)
      final isCurrentlyRecording = await _audioService.isRecording;
      print('[Login] 🎤 Estado isRecording: $isCurrentlyRecording');

      if (isCurrentlyRecording) {
        print('[Login] ⏹️ Deteniendo grabación...');
        setState(() => _isLoading = true);

        final audioBytes = await _audioService.stopRecording();
        print('[Login] ✅ Audio grabado: ${audioBytes.length} bytes');

        // Verificar que el audio tenga contenido (no solo encabezado WAV)
        if (audioBytes.length < 1000) {
          print('[Login] ⚠️ Audio muy corto: ${audioBytes.length} bytes');
          throw Exception(
            'Audio demasiado corto. Graba por al menos 1 segundo.',
          );
        }

        setState(() {
          _recordedAudio = audioBytes;
          _isLoading = false;
          _isRecordingNow = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Grabación completada (${audioBytes.length} bytes)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // ▶️ Iniciar grabación (el permiso se solicita dentro de AudioService)
        print('[Login] ▶️ Iniciando grabación...');

        await _audioService.startRecording();

        setState(() {
          _isRecordingNow = true;
        });

        print('[Login] 🔴 Grabación en curso...');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎤 Grabando... presiona nuevamente para detener'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('[Login] ❌ Error en grabación: $e');
      setState(() {
        _isLoading = false;
        _isRecordingNow = false;
        _errorMessage = 'Error en grabación: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// 🎤 Cargar 2 frases aleatorias desde el backend para autenticación de voz
  Future<void> _loadRandomPhrase() async {
    setState(() {
      _isLoadingPhrase = true;
      _voicePhrases.clear();
      _voicePhraseIds.clear();
      _currentPhrase = null;
      _currentPhraseId = null;
    });

    try {
      final backendService = BiometricBackendService();
      final isOnline = await backendService.isOnline();

      if (isOnline) {
        print('[Login] 🌐 Obteniendo 2 frases aleatorias del backend...');

        // Cargar 2 frases diferentes
        for (int i = 0; i < 2; i++) {
          final phraseData = await backendService.obtenerFraseAleatoria();
          _voicePhrases.add(phraseData['frase']);
          _voicePhraseIds.add(phraseData['id_texto'] ?? phraseData['id']);
          print('[Login] ✅ Frase ${i + 1}/2 cargada: ${phraseData['frase']}');
        }
      } else {
        // 📱 Modo OFFLINE: leer 2 frases de SQLite local
        print('[Login] 📱 Modo OFFLINE - leyendo 2 frases de SQLite local...');

        final nativeService = NativeVoiceMobileService();

        // 🔥 Frases largas por defecto (50 frases del registro)
        final frasesLargas = [
          "La biometria de voz es una tecnologia innovadora que protege tu identidad de manera unica y segura",
          "Tu voz es tan unica como tu huella digital y representa la mejor forma de autenticacion personal",
          "Cada vez que hablas, tu voz crea un patron biometrico imposible de replicar por otra persona",
          "La seguridad de tus datos personales comienza con la autenticacion biometrica basada en tu voz natural",
          "Proteger tu identidad digital nunca fue tan facil gracias a la tecnologia de reconocimiento de voz avanzada",
          "La biometria vocal analiza caracteristicas unicas de tu voz que son imposibles de falsificar completamente",
          "Tu voz contiene miles de caracteristicas acusticas que te identifican de forma precisa y confiable",
          "El futuro de la seguridad digital esta en la autenticacion multimodal que incluye tu voz personal",
          "Cada palabra que pronuncias genera un patron espectral unico que funciona como tu firma digital personal",
          "La tecnologia de reconocimiento de voz hace que tus conversaciones sean la llave de tu seguridad digital",
          "Confiar en tu voz para autenticarte es confiar en la tecnologia mas avanzada de seguridad biometrica actual",
          "Los sistemas biometricos de voz analizan frecuencias y resonancias que son exclusivas de cada ser humano",
          "Tu voz es la contrasena mas segura porque combina aspectos fisicos y comportamentales unicos de tu persona",
          "La autenticacion por voz elimina la necesidad de recordar contrasenas complejas y dificiles de memorizar siempre",
          "Cada tono y modulacion de tu voz cuenta una historia unica que solo tu puedes narrar autentica",
          "La biometria vocal representa un avance tecnologico que revoluciona la forma en que protegemos nuestra identidad digital",
          "Tu voz es un instrumento biometrico natural que te seguira siempre sin necesidad de dispositivos adicionales externos",
          "Los algoritmos de procesamiento de voz extraen caracteristicas que hacen tu perfil vocal completamente irrepetible y seguro",
          "La seguridad biometrica basada en voz ofrece comodidad y proteccion sin comprometer la privacidad de los usuarios",
          "Cada registro de tu voz fortalece el modelo biometrico que garantiza una autenticacion mas precisa y confiable",
          "La tecnologia de texto dinamico asegura que cada autenticacion sea diferente evitando ataques de reproduccion de audio",
          "Tu voz es la manifestacion sonora de tu identidad fisica que ningun impostor puede replicar fielmente completa",
          "Los sistemas multimodales combinan voz con otras biometrias para crear capas de seguridad practicamente impenetrables hoy",
          "Autenticarte con tu voz es tan natural como hablar porque utilizas algo que siempre llevas contigo",
          "La precision de los sistemas de reconocimiento de voz modernos supera el noventa y nueve por ciento garantizado",
          "Cada frecuencia fundamental de tu voz es determinada por la estructura unica de tu aparato fonador personal",
          "La biometria de voz funciona incluso cuando tienes un resfriado leve porque analiza multiples caracteristicas acusticas complementarias",
          "Tu patron vocal es tan distintivo que puede identificarte entre millones de personas con exactitud impresionante cientifica",
          "Los coeficientes MFCC extraidos de tu voz capturan la esencia acustica que define tu identidad vocal unica",
          "La autenticacion biometrica de voz es el equilibrio perfecto entre seguridad robusta y facilidad de uso cotidiano",
          "Cada ves que pronuncias una frase el sistema aprende mas sobre tu perfil vocal mejorando continuamente",
          "La tecnologia de reconocimiento de locutor distingue tu voz de imitaciones y grabaciones fraudulentas con precision notable",
          "Tu voz transporta informacion biometrica en cada fonema que pronuncias creando una firma acustica personal inigualable siempre",
          "Los algoritmos de aprendizaje automatico transforman tu voz en vectores numericos que representan tu identidad digital segura",
          "La biometria vocal democratiza el acceso a sistemas seguros sin requerir hardware especializado costoso o complicado para usuarios",
          "Cada caracteristica espectral de tu voz es un elemento del rompecabezas que forma tu perfil biometrico completo",
          "La autenticacion por voz con texto dinamico garantiza que cada validacion sea un desafio nuevo e irrepetible siempre",
          "Tu voz es el resultado de la combinacion unica de tu anatomia vocal y tus patrones de habla aprendidos",
          "Los sistemas biometricos de voz protegen contra el fraude utilizando analisis en tiempo real de multiples parametros acusticos",
          "Cada autenticacion exitosa con tu voz refuerza la confianza del sistema en tu identidad legitima y autentica",
          "La biometria de voz es una tecnologia no invasiva que respeta tu privacidad mientras protege tu seguridad digital",
          "Tu tracto vocal actua como un filtro acustico unico que modula el sonido de manera irrepetible para otros",
          "Los sistemas modernos de reconocimiento de voz son robustos ante ruido ambiental y variaciones en el canal de transmision",
          "Cada muestra de audio que proporcionas contribuye a crear un modelo biometrico mas preciso y confiable para ti",
          "La autenticacion multimodal que incluye voz ofrece seguridad en capas que es extremadamente dificil de comprometer totalmente",
          "Tu voz es una biometria comportamental que refleja no solo tu fisiologia sino tambien tu forma unica de expresarte",
          "Los vectores de caracteristicas extraidos de tu voz forman una representacion matematica unica de tu identidad vocal personal",
          "La tecnologia de texto dinamico evita ataques de repeticion obligando a pronunciar frases nuevas en cada autenticacion siempre",
          "Tu voz es la herramienta biometrica mas conveniente porque siempre esta disponible sin necesidad de dispositivos fisicos adicionales",
          "Cada parametro acustico de tu voz contribuye a la construccion de un perfil biometrico robusto y seguro definitivo",
        ];

        // Cargar 2 frases diferentes
        for (int i = 0; i < 2; i++) {
          final phraseData = await nativeService.obtenerFraseAleatoria();

          if (phraseData.containsKey('error')) {
            // Fallback: usar frases largas aleatorias
            final randomIndex =
                DateTime.now().millisecondsSinceEpoch % frasesLargas.length;
            final randomIndex2 = (randomIndex + 1) % frasesLargas.length;

            _voicePhrases.add(
              i == 0 ? frasesLargas[randomIndex] : frasesLargas[randomIndex2],
            );
            _voicePhraseIds.add(i + 1);
            print(
              '[Login] ⚠️ Frase ${i + 1}/2 (fallback): ${_voicePhrases[i].substring(0, 50)}...',
            );
          } else {
            _voicePhrases.add(phraseData['frase']);
            _voicePhraseIds.add(phraseData['id_frase']);
            print('[Login] ✅ Frase ${i + 1}/2 local: ${phraseData['frase']}');
          }
        }
      }

      // Mostrar la primera frase
      setState(() {
        _currentPhrase = _voicePhrases[0];
        _currentPhraseId = _voicePhraseIds[0];
        _isLoadingPhrase = false;
      });

      print(
        '[Login] 📋 2 frases cargadas. Mostrando frase 1/2: $_currentPhrase',
      );
    } catch (e) {
      print('[Login] ❌ Error cargando frases: $e');

      // Fallback: 2 frases largas aleatorias
      final frasesLargas = [
        "La biometria de voz es una tecnologia innovadora que protege tu identidad de manera unica y segura",
        "Tu voz es tan unica como tu huella digital y representa la mejor forma de autenticacion personal",
        "La seguridad de tus datos personales comienza con la autenticacion biometrica basada en tu voz natural",
        "La tecnologia de reconocimiento de voz hace que tus conversaciones sean la llave de tu seguridad digital",
      ];

      _voicePhrases.add(frasesLargas[0]);
      _voicePhrases.add(frasesLargas[1]);
      _voicePhraseIds.add(1);
      _voicePhraseIds.add(2);

      setState(() {
        _currentPhrase = _voicePhrases[0];
        _currentPhraseId = _voicePhraseIds[0];
        _isLoadingPhrase = false;
      });
    }
  }

  /// 🔊 Reproducir el audio grabado
  Future<void> _playRecordedAudio() async {
    if (_recordedAudio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay audio grabado para reproducir')),
      );
      return;
    }

    try {
      setState(() => _isPlayingAudio = true);

      print(
        '[Login] 🔊 Reproduciendo audio grabado (${_recordedAudio!.length} bytes)...',
      );

      // Usar el mismo método que el registro
      await _audioService.playAudioFromBytes(_recordedAudio!);

      // Esperar a que termine la reproducción (estimado 3 segundos)
      await Future.delayed(const Duration(seconds: 3));

      setState(() => _isPlayingAudio = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Reproducción completada'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('[Login] ❌ Error reproduciendo audio: $e');
      setState(() => _isPlayingAudio = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al reproducir audio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performBiometricAuth() async {
    // Verificar bloqueo temporal
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      setState(() {
        _errorMessage =
            '🔒 Demasiados intentos fallidos. Intenta en $remaining segundos.';
      });
      return;
    }

    // Cargar configuración de admin
    final settings = await _adminService.loadSettings();

    if (_identifierController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor ingrese el identificador';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final localDb = LocalDatabaseService();

    try {
      // Buscar usuario local por identificador
      final user = await localDb.getUserByIdentifier(
        _identifierController.text,
      );
      if (user == null) {
        throw Exception('Usuario no encontrado localmente');
      }

      final int idUsuario = user['id_usuario'] as int;

      // ✅ NUEVO: Verificar si el usuario completó todas las etapas del registro
      final completionStatus = await localDb.getUserCompletionStatus(
        _identifierController.text,
      );

      final datosCompletos = completionStatus['datosCompletos'] ?? false;
      final orejasCompletas = completionStatus['orejasCompletas'] ?? false;
      final vozCompleta = completionStatus['vozCompleta'] ?? false;

      // Si el usuario no completó todas las etapas, redirigir al paso pendiente
      if (!datosCompletos || !orejasCompletas || !vozCompleta) {
        setState(() => _isLoading = false);

        String mensajeIncompleto = '⚠️ Tu registro está incompleto.\n\n';
        int pasoInicial = 0;

        if (!datosCompletos) {
          mensajeIncompleto += '❌ Falta: Datos personales\n';
          pasoInicial = 0;
        } else if (!orejasCompletas) {
          mensajeIncompleto += '✅ Datos personales completos\n';
          mensajeIncompleto += '❌ Falta: 7 fotos de oreja\n';
          pasoInicial = 1;
        } else if (!vozCompleta) {
          mensajeIncompleto += '✅ Datos personales completos\n';
          mensajeIncompleto += '✅ Fotos de oreja completas\n';
          mensajeIncompleto += '❌ Falta: 6 audios de voz\n';
          pasoInicial = 2;
        }

        mensajeIncompleto += '\nPor favor completa tu registro.';

        // Mostrar diálogo informativo
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text('📋 Registro Incompleto'),
            content: Text(mensajeIncompleto),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Redirigir a la pantalla de registro en el paso pendiente
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => RegisterScreen(
                        identificadorInicial: _identifierController.text,
                        pasoInicial: pasoInicial,
                      ),
                    ),
                  );
                },
                child: Text('Completar Registro'),
              ),
            ],
          ),
        );
        return;
      }

      // ✅ Usuario completo - continuar con autenticación biométrica

      // ==========================================
      // 🔥 PRIORIDAD 1: Intentar autenticación en la nube
      // ==========================================
      final backendService = BiometricBackendService();
      bool cloudAuthAttempted = false;
      bool cloudAuthSuccess = false;

      try {
        final isOnline = await backendService.isOnline();

        if (isOnline) {
          print('[Login] 🌐 Intentando autenticación en la nube...');

          if (_selectedBiometricType == 1) {
            // Oreja - Backend Cloud
            if (_capturedPhoto == null) {
              throw Exception('Por favor captura una foto primero');
            }

            final result = await backendService.autenticarOreja(
              imagenBytes: _capturedPhoto!,
              identificador: _identifierController.text,
            );

            cloudAuthAttempted = true;

            // 🔥 VERIFICACIÓN: Debe cumplir las condiciones del backend
            final authenticated = result['autenticado'] ?? false;
            final access = result['access'] ?? false;

            // ✅ Autenticado SOLO si ambas condiciones son verdaderas
            cloudAuthSuccess = authenticated && access;

            print('[Login] 📊 Resultado backend (oreja):');
            print('[Login]    - authenticated: $authenticated');
            print('[Login]    - access: $access');
            print(
              '[Login]    - Autenticación final: ${cloudAuthSuccess ? "✅ APROBADA" : "❌ RECHAZADA"}',
            );

            if (cloudAuthSuccess) {
              print('[Login] ✅ Autenticación en nube exitosa');

              // Registrar validación localmente para auditoría
              final validation = BiometricValidation(
                id: 0,
                idUsuario: idUsuario,
                tipoBiometria: 'oreja',
                resultado: 'exito',
                modoValidacion: 'online_cloud',
                timestamp: DateTime.now(),
                puntuacionConfianza: (result['margen'] ?? 0.0).toDouble(),
                duracionValidacion: 0,
              );
              await localDb.insertValidation(validation);

              // Login exitoso - ir al menú principal
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
              return;
            } else {
              // ❌ Autenticación en nube RECHAZADA - NO usar fallback local
              final mensaje = result['mensaje'] ?? 'Biometría no coincide';

              print('[Login] ❌ Autenticación en nube RECHAZADA: $mensaje');
              print(
                '[Login] ⛔ Backend respondió negativamente - NO usar fallback local',
              );

              // Registrar intento fallido en auditoría
              final validation = BiometricValidation(
                id: 0,
                idUsuario: idUsuario,
                tipoBiometria: 'oreja',
                resultado: 'fallido',
                modoValidacion: 'online_cloud',
                timestamp: DateTime.now(),
                puntuacionConfianza: (result['margen'] ?? 0.0).toDouble(),
                duracionValidacion: 0,
              );
              await localDb.insertValidation(validation);

              // ⛔ DETENER EL PROCESO - No continuar a fallback local
              throw Exception('❌ Autenticación rechazada: $mensaje');
            }
          } else {
            // Voz - Backend Cloud
            if (_recordedAudio == null) {
              throw Exception('Por favor graba tu voz primero');
            }

            // 🎤 Usar la frase que se mostró al usuario
            if (_currentPhraseId == null) {
              throw Exception(
                'No hay frase cargada. Por favor selecciona "Voz" nuevamente.',
              );
            }

            print(
              '[Login] 🎤 Autenticando voz con frase ID: $_currentPhraseId',
            );

            final result = await backendService.autenticarVoz(
              audioBytes: _recordedAudio!,
              identificador: _identifierController.text,
              idFrase: _currentPhraseId!,
            );

            cloudAuthAttempted = true;

            // 🔥 VERIFICACIÓN COMPLETA: Debe cumplir AMBAS condiciones
            final data = result['data'] ?? result;
            final authenticated =
                data['authenticated'] ?? data['autenticado'] ?? false;
            final textoCoincide = data['texto_coincide'] ?? false;
            final access = data['access'] ?? false;

            // ✅ Autenticado SOLO si: authenticated=true Y texto_coincide=true Y access=true
            cloudAuthSuccess = authenticated && textoCoincide && access;

            print('[Login] 📊 Resultado backend:');
            print('[Login]    - authenticated: $authenticated');
            print('[Login]    - texto_coincide: $textoCoincide');
            print('[Login]    - access: $access');
            print(
              '[Login]    - Autenticación final: ${cloudAuthSuccess ? "✅ APROBADA" : "❌ RECHAZADA"}',
            );

            if (cloudAuthSuccess) {
              print('[Login] ✅ Autenticación en nube exitosa');

              // Registrar validación localmente para auditoría
              final validation = BiometricValidation(
                id: 0,
                idUsuario: idUsuario,
                tipoBiometria: 'voz', // Cambiado de 'audio' a 'voz'
                resultado: 'exito',
                modoValidacion: 'online_cloud',
                timestamp: DateTime.now(),
                puntuacionConfianza: (result['margen'] ?? 0.0).toDouble(),
                duracionValidacion: 0,
              );
              await localDb.insertValidation(validation);

              // Login exitoso - ir al menú principal
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
              return;
            } else {
              // 🎤 Autenticación de voz RECHAZADA por backend - NO usar fallback local
              final data =
                  result['data'] ?? result; // Compatibilidad con ambos formatos

              final transcripcion = data['transcripcion'];
              final fraseEsperada = data['frase_esperada'];
              final userId = data['user_id'];
              final userName = data['user_name'];

              print('[Login] ❌ Autenticación en nube RECHAZADA');
              print('[Login] 📝 Frase esperada: $fraseEsperada');
              print('[Login] 🎙️ Transcripción: $transcripcion');
              print('[Login] 👤 Usuario identificado: $userName (ID: $userId)');
              print(
                '[Login] ⛔ Backend respondió negativamente - NO usar fallback local',
              );

              // Registrar intento fallido en auditoría
              final validation = BiometricValidation(
                id: 0,
                idUsuario: idUsuario,
                tipoBiometria: 'voz',
                resultado: 'fallido',
                modoValidacion: 'online_cloud',
                timestamp: DateTime.now(),
                puntuacionConfianza: (result['margen'] ?? 0.0).toDouble(),
                duracionValidacion: 0,
              );
              await localDb.insertValidation(validation);

              // ⛔ DETENER EL PROCESO - No continuar a fallback local
              throw Exception(
                '❌ Autenticación rechazada. Voz no coincide o texto incorrecto.',
              );
            }
          }
        }
      } catch (e) {
        print('[Login] ⚠️ Error en autenticación cloud: $e');

        // ⛔ Si el backend respondió (aunque rechazó), RE-LANZAR la excepción
        // NO permitir que continúe al fallback local
        if (cloudAuthAttempted) {
          print('[Login] ❌ Backend rechazó autenticación - Deteniendo proceso');
          print(
            '[Login] ⛔ NO se usará fallback local (backend tuvo la última palabra)',
          );
          rethrow; // Re-lanzar la excepción para detener el flujo
        }

        // Si llegamos aquí, el error fue por CONEXIÓN (no por rechazo del backend)
        print(
          '[Login] 🔌 Error de conexión al backend - Se permitirá fallback local',
        );
      }

      // ==========================================
      // 🔄 FALLBACK: Autenticación local (SOLO si backend NO respondió)
      // ==========================================
      // ✅ CORRECCIÓN: Solo usar fallback si NO se pudo contactar al backend
      // NO usar fallback si el backend respondió y rechazó la autenticación
      if (!cloudAuthAttempted) {
        print(
          '[Login] 🔄 Backend no disponible - Usando validación local como fallback...',
        );
        print('[Login] ℹ️ Razón: Sin Internet o backend no responde');

        // Ejecutar validación local según tipo biométrico
        if (_selectedBiometricType == 1) {
          // Oreja - Usando liboreja_mobile.so (LDA + KNN)
          if (_capturedPhoto == null) {
            throw Exception('Por favor captura una foto primero');
          }

          print('[Login] 📊 Buscando usuario en liboreja_mobile.so...');
          print(
            '[Login] 🎯 Usando liboreja_mobile.so completo para autenticación...',
          );

          // Inicializar servicio nativo con TIMEOUT de 10 segundos
          final nativeEarService = NativeEarMobileService();

          try {
            await nativeEarService.initialize().timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception(
                  'Timeout inicializando librería nativa. '
                  'El archivo templates_k1.csv puede ser muy grande o estar corrupto.',
                );
              },
            );
            print('[Login] ✅ Servicio nativo inicializado correctamente');

            // 🔄 RECARGAR templates_k1.csv SOLO si han pasado más de 5 minutos desde init
            // Evita bloquear el C++ con recargas innecesarias
            print(
              '[Login] ℹ️ Usando templates ya cargados en memoria (skip reload)',
            );

            /* DESHABILITADO: reloadTemplates() causa bloqueos en C++
            print('[Login] 🔄 Recargando templates desde disco...');
            try {
              await nativeEarService.reloadTemplates().timeout(
                const Duration(seconds: 5),
                onTimeout: () {
                  print(
                    '[Login] ⚠️ Timeout recargando templates (continuando...)',
                  );
                  return false;
                },
              );
            } catch (e) {
              print(
                '[Login] ⚠️ Error recargando templates: $e (continuando...)',
              );
            }
            */
          } catch (e) {
            print('[Login] ❌ Error inicializando servicio nativo: $e');
            throw Exception(
              'No se pudo inicializar el sistema de autenticación local. '
              'Por favor intenta conectarte a Internet o contacta al administrador.',
            );
          }

          // Obtener ID del usuario en el sistema local
          final userMap = await localDb.getUserByIdentifier(
            _identifierController.text.trim(),
          );

          if (userMap == null) {
            throw Exception('Usuario no encontrado en base de datos local');
          }

          final userId = userMap['id_usuario'] as int;
          print(
            '[Login] ✅ Usuario ${_identifierController.text.trim()} encontrado (ID: $userId)',
          );

          // Guardar foto temporalmente
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final photoPath = '${tempDir.path}/auth_ear_$timestamp.jpg';

          final photoFile = File(photoPath);
          await photoFile.writeAsBytes(_capturedPhoto!);

          print('[Login] 💾 Foto guardada en: $photoPath');
          print('[Login] � Tamaño foto: ${_capturedPhoto!.length} bytes');

          // Autenticar con la librería nativa
          final resultado = await nativeEarService.authenticate(
            identificadorClaimed: userId,
            imagePath: photoPath,
            umbral: -1.0, // Usar umbral del modelo (EER)
          );

          // Limpiar archivo temporal
          try {
            await photoFile.delete();
          } catch (e) {
            print('[Login] ⚠️ No se pudo eliminar archivo temporal: $e');
          }

          print('[Login] 📊 Resultado de autenticación:');
          print('[Login] ${resultado.toString()}');

          // Verificar resultado
          if (resultado['success'] == false) {
            final error = resultado['error'] ?? 'Error desconocido';
            throw Exception('Error en autenticación: $error');
          }

          final autenticado = resultado['autenticado'] as bool? ?? false;
          final coincide = resultado['coincide'] as bool? ?? false;
          final scoreClaimed = resultado['score_claimed'] as double? ?? 0.0;
          final umbralUsado = resultado['umbral'] as double? ?? 0.0;

          print('[Login] 🔐 Autenticado: $autenticado');
          print('[Login] 🎯 Coincide: $coincide');
          print('[Login] 📊 Score: ${scoreClaimed.toStringAsFixed(4)}');
          print('[Login] 📏 Umbral: ${umbralUsado.toStringAsFixed(4)}');

          if (autenticado && coincide) {
            print('[Login] ✅ AUTENTICACIÓN OREJA EXITOSA (LDA+KNN)');
          } else {
            print('[Login] ❌ AUTENTICACIÓN OREJA FALLIDA');
            print(
              '[Login] ⚠️ Distancia ($scoreClaimed) > Umbral ($umbralUsado)',
            );
          }

          // Registrar validación local
          final validation = BiometricValidation(
            id: 0,
            idUsuario: userId,
            tipoBiometria: 'oreja',
            resultado: (autenticado && coincide) ? 'exito' : 'fallo',
            modoValidacion: 'offline_lda',
            timestamp: DateTime.now(),
            puntuacionConfianza: scoreClaimed, // Convertir distancia a score
            duracionValidacion: 0,
          );

          await localDb.insertValidation(validation);

          // Encolar para sincronización
          await localDb
              .insertToSyncQueue(userId, 'validacion_biometrica', 'insert', {
                'tipo_biometria': 'oreja',
                'resultado': validation.resultado,
                'puntuacion_confianza': validation.puntuacionConfianza,
                'timestamp': validation.timestamp.toIso8601String(),
              });

          if (!autenticado || !coincide) {
            throw Exception('Autenticación fallida: oreja no coincide');
          }
        } else {
          // Voz - Validación local
          if (_recordedAudio == null) {
            throw Exception('Por favor graba tu voz primero');
          }

          print(
            '[Login] 📊 Buscando plantillas de voz para usuario ID: $idUsuario',
          );

          // ✅ USAR libvoz_mobile.so COMPLETO para autenticación real con SVM
          print(
            '[Login] 🎯 Usando libvoz_mobile.so completo para autenticación...',
          );

          final nativeService = NativeVoiceMobileService();

          try {
            final initialized = await nativeService.initialize().timeout(
              const Duration(seconds: 10),
              onTimeout: () => false,
            );

            if (!initialized) {
              throw Exception(
                'Error inicializando libvoz_mobile.so. Verifica que los modelos SVM estén copiados.',
              );
            }
            print('[Login] ✅ Servicio de voz inicializado correctamente');

            // ⚠️ NO hacer cleanup() + re-init porque eso BORRA los modelos SVM
            // Los modelos ya están cargados en memoria y permanecen hasta que se cierre la app
            print('[Login] ℹ️ Usando modelos SVM ya cargados en memoria');
          } catch (e) {
            print('[Login] ❌ Error inicializando servicio de voz: $e');
            throw Exception(
              'No se pudo inicializar el sistema de voz local. '
              'Por favor intenta conectarte a Internet.',
            );
          } // 🔍 VERIFICAR SI EL USUARIO EXISTE EN LA BIBLIOTECA
          final identificador = _identifierController.text.trim();
          final userExists = nativeService.usuarioExiste(identificador);

          if (!userExists) {
            print(
              '[Login] ⚠️ Usuario $identificador NO tiene modelo entrenado',
            );
            throw Exception(
              'Usuario no registrado. Por favor regístrate primero con 6 audios de voz.',
            );
          }
          print(
            '[Login] ✅ Usuario $identificador encontrado en libvoz_mobile.so',
          );

          // Guardar audio en archivo temporal
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final audioPath = '${tempDir.path}/auth_voice_$timestamp.wav';

          final audioFile = File(audioPath);
          await audioFile.writeAsBytes(_recordedAudio!);

          print('[Login] 💾 Audio guardado en: $audioPath');
          print('[Login] � Tamaño audio: ${_recordedAudio!.length} bytes');

          // Autenticar con la librería nativa
          final resultado = await nativeService.authenticate(
            identificador: _identifierController.text.trim(),
            audioPath: audioPath,
            idFrase: _currentPhraseId ?? 1,
          );

          // Limpiar archivo temporal
          try {
            await audioFile.delete();
          } catch (e) {
            print('[Login] ⚠️ No se pudo eliminar archivo temporal: $e');
          }

          print('[Login] 📊 Resultado de autenticación:');
          print('[Login] ${resultado.toString()}');

          // � VERIFICAR NÚMERO DE CLASES EN EL MODELO
          final allScoresMap =
              resultado['all_scores'] as Map<dynamic, dynamic>?;
          if (allScoresMap != null && allScoresMap.length == 1) {
            print('[Login] ⚠️⚠️⚠️ ADVERTENCIA CRÍTICA ⚠️⚠️⚠️');
            print('[Login] 🔴 El modelo SVM solo tiene 1 clase (1 usuario)');
            print(
              '[Login] 🔴 No se puede validar correctamente con 1 solo usuario',
            );
            print(
              '[Login] 💡 Solución: Registra al menos 2 usuarios diferentes',
            );

            throw Exception(
              'El sistema necesita al menos 2 usuarios registrados para funcionar.\n\n'
              'Actualmente solo hay 1 usuario en el modelo SVM.\n'
              'Por favor registra otro usuario para habilitar la autenticación.',
            );
          }

          // 🔍 VERIFICAR SI HAY ERROR DE MODELO NO CARGADO
          if (resultado['success'] == false) {
            final error = resultado['error'] ?? 'Error desconocido';
            if (error.toString().contains('Modelo no cargado') ||
                error.toString().contains('No se pudo cargar el modelo')) {
              print(
                '[Login] ⚠️ El usuario existe en SQLite pero no tiene modelo SVM entrenado',
              );
              print('[Login] 🔍 Posibles causas:');
              print('[Login]    1. Los archivos class_*.bin no existen');
              print(
                '[Login]    2. El entrenamiento SVM falló durante el registro',
              );
              print('[Login]    3. Los modelos fueron borrados por cleanup()');

              throw Exception(
                'Modelo de voz no encontrado. Esto puede ocurrir porque:\n\n'
                '• Los archivos de entrenamiento (class_*.bin) no existen\n'
                '• El registro no se completó correctamente\n\n'
                'Solución: Vuelve a registrarte completando los 6 audios de voz.\n'
                'Si el problema persiste, contacta al administrador.',
              );
            } else {
              throw Exception('Error en autenticación: $error');
            }
          }

          // 🔍 OBTENER ID DEL USUARIO ESPERADO en libvoz_mobile.so
          final expectedUserId = nativeService.obtenerIdUsuario(identificador);
          if (expectedUserId < 0) {
            throw Exception(
              'No se pudo obtener ID del usuario $identificador en libvoz_mobile.so',
            );
          }
          print(
            '[Login] 🎯 Usuario esperado en SVM: ID $expectedUserId ($identificador)',
          );

          // 🏆 NUEVA LÓGICA: Obtener el usuario con el SCORE MÁS ALTO
          int? highestScoreUserId;
          double highestScore = double.negativeInfinity;

          if (resultado['all_scores'] != null) {
            final allScores = resultado['all_scores'] as Map<dynamic, dynamic>;

            print(
              '[Login] 📊 Analizando scores de ${allScores.length} usuarios...',
            );

            // Encontrar el usuario con el score más alto
            allScores.forEach((userId, score) {
              final scoreValue = (score as num).toDouble();
              if (scoreValue > highestScore) {
                highestScore = scoreValue;
                // Normalizar el userId a int (puede venir como String)
                highestScoreUserId = userId is int
                    ? userId
                    : int.tryParse(userId.toString());
              }
            });

            print(
              '[Login] 🏆 Usuario con mayor score: ID $highestScoreUserId (${(highestScore * 100).toStringAsFixed(2)}%)',
            );
            print('[Login] 🎯 Usuario esperado: ID $expectedUserId');
          }

          // ✅ VALIDACIÓN ESTRICTA: El usuario con el score MÁS ALTO debe ser el esperado
          final bool isCorrectUser = highestScoreUserId == expectedUserId;
          final bool success = isCorrectUser && highestScore > 0;

          if (!isCorrectUser) {
            print(
              '[Login] ❌ RECHAZO: La voz pertenece al usuario ID $highestScoreUserId (score: ${(highestScore * 100).toStringAsFixed(2)}%), no al ID $expectedUserId',
            );
          } else {
            print(
              '[Login] ✅ MATCH: El usuario con el score más alto ($highestScoreUserId) coincide con el esperado ($expectedUserId)',
            );
          }

          print(
            '[Login] ${success ? "✅ AUTENTICACIÓN VOZ EXITOSA (SVM)" : "❌ AUTENTICACIÓN VOZ FALLIDA (SVM)"}',
          );
          print('[Login] 👤 Usuario correcto: ${isCorrectUser ? "SÍ" : "NO"}');
          print(
            '[Login] � Score final: ${(highestScore * 100).toStringAsFixed(2)}%',
          );

          final validation = BiometricValidation(
            id: 0,
            idUsuario: idUsuario,
            tipoBiometria: 'voz',
            resultado: success ? 'exito' : 'fallo',
            modoValidacion: 'offline',
            timestamp: DateTime.now(),
            puntuacionConfianza: highestScore,
            duracionValidacion: 0,
          );

          await localDb.insertValidation(validation);

          await localDb
              .insertToSyncQueue(idUsuario, 'validacion_biometrica', 'insert', {
                'tipo_biometria': 'voz',
                'resultado': validation.resultado,
                'puntuacion_confianza': validation.puntuacionConfianza,
                'timestamp': validation.timestamp.toIso8601String(),
              });

          if (!success) {
            throw Exception(
              'Autenticación fallida: ${resultado['mensaje'] ?? 'voz no coincide con SVM'}',
            );
          }
        }
      } // Cierre del bloque fallback

      if (!mounted) return;

      // ✅ Autenticación biométrica exitosa - reiniciar contador de intentos
      _loginAttempts = 0;
      _lockoutUntil = null;

      // 🔐 NUEVO: Sistema de autenticación dual (si está habilitado)
      if (settings.requireBothBiometricsInLogin == true) {
        // Marcar la biometría actual como completada
        if (_selectedBiometricType == 1) {
          _earAuthCompleted = true;
          print('[Login] ✅ Autenticación de OREJA completada (1/2)');
        } else {
          _voiceAuthCompleted = true;
          print('[Login] ✅ Autenticación de VOZ completada (1/2)');
        }

        // Verificar si AMBAS biometrías están completadas
        if (_earAuthCompleted && _voiceAuthCompleted) {
          print('[Login] 🎉 AMBAS biometrías validadas - Acceso permitido');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 ¡Autenticación completa! (Oreja ✅ + Voz ✅)'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          // Aún falta una biometría
          final String pendiente = _earAuthCompleted ? 'VOZ' : 'OREJA';
          print('[Login] ⏳ Falta autenticación de $pendiente');

          setState(() {
            _isLoading = false;
            _errorMessage = null;
            // Cambiar automáticamente al otro tipo de biometría
            _selectedBiometricType = _earAuthCompleted ? 2 : 1;

            // Limpiar captura previa
            _capturedPhoto = null;
            _recordedAudio = null;
          });

          // Cargar frase si cambiamos a voz
          if (_selectedBiometricType == 2) {
            _loadRandomPhrase();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ ${_earAuthCompleted ? "Oreja" : "Voz"} validada. Ahora autentica con $pendiente',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        // Modo normal: UNA sola biometría es suficiente
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedBiometricType == 1
                  ? '¡Autenticación con oreja exitosa!'
                  : '¡Autenticación con voz exitosa!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (error) {
      if (!mounted) return;

      // ❌ Autenticación fallida - incrementar contador
      _loginAttempts++;

      // Verificar si se alcanzó el máximo de intentos
      if (_loginAttempts >= settings.maxLoginAttempts) {
        _lockoutUntil = DateTime.now().add(Duration(minutes: 5));
        setState(() {
          _errorMessage =
              '🔒 Máximo de intentos alcanzado (${settings.maxLoginAttempts}). '
              'Cuenta bloqueada por 5 minutos.';
        });
      } else {
        final remaining = settings.maxLoginAttempts - _loginAttempts;
        setState(() {
          _errorMessage =
              'Error en autenticación: $error\n'
              'Intentos restantes: $remaining';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _performPasswordAuth() async {
    if (_identifierController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor completa todos los campos';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.login(
        identificadorUnico: _identifierController.text,
        contrasena: _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Login exitoso!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error en login: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Nota: selección de tipo se maneja inline desde los ChoiceChips

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _adminService.loadSettings(),
      builder: (context, snapshot) {
        final settings = snapshot.data;
        final biometricRequired = settings?.biometricRequired ?? false;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Autenticación Biométrica'),
            backgroundColor: Colors.blue,
            elevation: 0,
            actions: [
              // Botón secreto: 7 taps para acceder al panel de admin
              AdminAccessButton(),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      // Logo de la aplicación
                      Center(child: AppLogo(size: 100, showText: true)),
                      const SizedBox(height: 32),
                      // Error message
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade900),
                          ),
                        ),
                      const SizedBox(height: 24),
                      // Identificador (Cédula)
                      TextField(
                        controller: _identifierController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Cédula / Identificador Único',
                          hintText: 'Ej: 0102030405',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.badge),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Toggle: Contraseña vs Biometría (deshabilitado si biometría es obligatoria)
                      if (biometricRequired)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock, color: Colors.blue),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '🔐 Autenticación biométrica obligatoria',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: SegmentedButton<bool>(
                                segments: const <ButtonSegment<bool>>[
                                  ButtonSegment<bool>(
                                    value: false,
                                    label: Text('Contraseña'),
                                    icon: Icon(Icons.lock),
                                  ),
                                  ButtonSegment<bool>(
                                    value: true,
                                    label: Text('Biometría'),
                                    icon: Icon(Icons.fingerprint),
                                  ),
                                ],
                                selected: <bool>{_usingBiometrics},
                                onSelectionChanged: (Set<bool> newSelection) {
                                  setState(() {
                                    _usingBiometrics = newSelection.first;
                                    _errorMessage = null;
                                    _capturedPhoto = null;
                                    _recordedAudio = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      if (!_usingBiometrics) ...[
                        // Contraseña
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.lock),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _performPasswordAuth,
                          icon: const Icon(Icons.login),
                          label: const Text('Iniciar Sesión'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      ] else ...[
                        // 🔐 NUEVO: Indicador de autenticación dual (si está habilitado)
                        if (biometricRequired &&
                            settings?.requireBothBiometricsInLogin == true)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.deepPurple,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.security,
                                      color: Colors.deepPurple,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '🔐 Autenticación Dual Obligatoria',
                                        style: TextStyle(
                                          color: Colors.deepPurple.shade900,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildBiometricStatusChip(
                                      label: 'Oreja',
                                      icon: Icons.hearing,
                                      completed: _earAuthCompleted,
                                    ),
                                    Icon(Icons.add, color: Colors.deepPurple),
                                    _buildBiometricStatusChip(
                                      label: 'Voz',
                                      icon: Icons.mic,
                                      completed: _voiceAuthCompleted,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                        // Seleccionar tipo biométrico
                        const Text(
                          'Selecciona método de autenticación:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Oreja'),
                                selected: _selectedBiometricType == 1,
                                onSelected: (_) =>
                                    setState(() => _selectedBiometricType = 1),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Voz'),
                                selected: _selectedBiometricType == 2,
                                onSelected: (_) {
                                  setState(() => _selectedBiometricType = 2);
                                  _loadRandomPhrase(); // 🎤 Cargar frase cuando selecciona voz
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Captura biométrica
                        if (_selectedBiometricType == 1) ...[
                          const Text(
                            'Captura una foto de tu oreja:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (_capturedPhoto != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: 200,
                                width: double.infinity,
                                color: Colors.grey.shade200,
                                child: Image.memory(
                                  _capturedPhoto!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(Icons.camera_alt, size: 48),
                              ),
                            ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _capturePhotoForAuth,
                            icon: const Icon(Icons.camera),
                            label: Text(
                              _capturedPhoto == null
                                  ? 'Capturar Foto'
                                  : 'Retomar Foto',
                            ),
                          ),
                        ] else if (_selectedBiometricType == 2) ...[
                          const Text(
                            'Graba tu voz:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),

                          // 🎤 Mostrar LAS 2 FRASES que debe decir el usuario
                          if (_isLoadingPhrase)
                            const Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 8),
                                  Text('Cargando frases...'),
                                ],
                              ),
                            )
                          else if (_voicePhrases.length == 2)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.shade300,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.record_voice_over,
                                        color: Colors.blue,
                                        size: 24,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Di las siguientes 2 frases:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Frase 1
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '1. ',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '"${_voicePhrases[0]}"',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Frase 2
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '2. ',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '"${_voicePhrases[1]}"',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.shade300,
                                  width: 2,
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No se pudo cargar la frase. Verifica tu conexión.',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 24),
                          Center(
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isRecordingNow
                                    ? Colors.red.shade100
                                    : Colors.blue.shade100,
                                border: Border.all(
                                  color: _isRecordingNow
                                      ? Colors.red
                                      : Colors.blue,
                                  width: 3,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _recordVoiceForAuth,
                                  customBorder: const CircleBorder(),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isRecordingNow
                                            ? Icons.stop
                                            : Icons.mic,
                                        size: 40,
                                        color: _isRecordingNow
                                            ? Colors.red
                                            : Colors.blue,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _isRecordingNow ? 'Grabando' : 'Grabar',
                                        style: TextStyle(
                                          color: _isRecordingNow
                                              ? Colors.red
                                              : Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_recordedAudio != null)
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      ),
                                      SizedBox(width: 12),
                                      Text('Voz grabada'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: _isPlayingAudio
                                      ? null
                                      : _playRecordedAudio,
                                  icon: Icon(
                                    _isPlayingAudio
                                        ? Icons.volume_up
                                        : Icons.play_arrow,
                                  ),
                                  label: Text(
                                    _isPlayingAudio
                                        ? 'Reproduciendo...'
                                        : 'Escuchar grabación',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _performBiometricAuth,
                          icon: const Icon(Icons.login),
                          label: const Text('Autenticarse'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RegisterScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            '¿No tienes cuenta? Registrate aquí',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  /// 🔐 Widget para mostrar el estado de cada biometría en autenticación dual
  Widget _buildBiometricStatusChip({
    required String label,
    required IconData icon,
    required bool completed,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: completed ? Colors.green.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: completed ? Colors.green : Colors.grey.shade400,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: completed ? Colors.green.shade700 : Colors.grey.shade600,
          ),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: completed ? Colors.green.shade900 : Colors.grey.shade700,
              fontWeight: completed ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          SizedBox(width: 6),
          Icon(
            completed ? Icons.check_circle : Icons.circle_outlined,
            size: 18,
            color: completed ? Colors.green.shade700 : Colors.grey.shade400,
          ),
        ],
      ),
    );
  }
}
