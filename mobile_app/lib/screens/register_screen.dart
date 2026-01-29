import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../services/auth_service_fix.dart';
import '../services/camera_service.dart';
import '../services/audio_service.dart';
import '../services/local_database_service.dart';
import '../services/ear_validator_service.dart';
import '../services/admin_settings_service.dart';
import '../services/biometric_backend_service.dart';
import '../services/biometric_service.dart';
import '../services/native_voice_mobile_service.dart';
import '../services/native_ear_mobile_service.dart';
import '../widgets/app_logo.dart';
import 'login_screen.dart';
import 'camera_capture_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class RegisterScreen extends StatefulWidget {
  final String? identificadorInicial; // Para continuar registro incompleto
  final int? pasoInicial; // A qué paso ir directamente

  const RegisterScreen({Key? key, this.identificadorInicial, this.pasoInicial})
    : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with WidgetsBindingObserver {
  final _authService = AuthServiceFix.instance;
  final _cameraService = CameraService();
  final _audioService = AudioService();
  final _localDb = LocalDatabaseService();
  final _connectivity = Connectivity();
  final _earValidator = EarValidatorService();
  final _adminService = AdminSettingsService();
  final _biometricService = BiometricService();

  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _identificadorController = TextEditingController();
  final _fechaNacimientoController = TextEditingController();
  String? _sexoSeleccionado; // 'M', 'F', 'Otro'

  List<Uint8List?> earPhotos = List.filled(5, null); // 5 fotos de oreja
  List<Uint8List?> voiceAudios = List.filled(
    6,
    null,
  ); // 6 audios de voz (DOS frases por cada audio)
  Map<int, double> _audioDurations = {}; // Duraciones de audios en segundos
  int?
  _recordingAudioIndex; // Índice del audio que se está grabando ACTUALMENTE

  // 🎤 FRASES que el usuario debe decir en cada grabación (2 frases × 6 audios = 12 frases seleccionadas al azar)
  // Se intentan cargar de la BD/servidor (cuando hay Internet), o se usan estas 50 por defecto
  List<String> _voicePhrases = [
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

  int _currentStep = 0; // 0: datos, 1: fotos oreja, 2: audio voz
  bool _isLoading = false;
  String? _errorMessage;
  bool _isOnline = true;
  int? _playingAudioIndex; // Índice del audio que se está reproduciendo
  String _processingMessage =
      ''; // Mensaje de progreso durante procesamiento pesado

  /// Verifica si se puede avanzar al siguiente paso (según configuración de admin)
  bool _canProceedToNextStep() {
    // Obtener configuración de validación desde admin settings
    final settings = _adminService.currentSettings;
    final requireAllFields = settings?.requireAllFieldsInRegistration ?? true;

    // ✅ DEBUG: Ver qué configuración tiene el panel de admin
    debugPrint(
      '[Register] 🔧 requireAllFieldsInRegistration = $requireAllFields (Step: $_currentStep)',
    );

    // Si la validación está deshabilitada desde el panel de admin, permitir avanzar
    if (!requireAllFields) {
      debugPrint(
        '[Register] ✅ Validación deshabilitada - Permitir avanzar sin restricciones',
      );
      return true;
    }

    // Si la validación está habilitada, validar según el paso actual
    switch (_currentStep) {
      case 0: // Paso 1: Datos personales
        // Campos obligatorios: nombres, apellidos, identificador único, fecha nacimiento, sexo
        return _nombresController.text.trim().isNotEmpty &&
            _apellidosController.text.trim().isNotEmpty &&
            _identificadorController.text.trim().isNotEmpty &&
            _fechaNacimientoController.text.trim().isNotEmpty &&
            _sexoSeleccionado != null &&
            _sexoSeleccionado!.isNotEmpty;

      case 1: // Paso 2: 5 fotos de oreja
        // Verificar que todas las 5 fotos estén capturadas
        return earPhotos.every((photo) => photo != null);

      case 2: // Paso 3: 6 audios de voz (2 frases cada uno)
        // Verificar que todos los 6 audios estén grabados
        return voiceAudios.every((audio) => audio != null);

      default:
        return true;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _checkConnectivity();
    _loadVoicePhrases(); // 🎤 Cargar frases de voz de la BD
    _loadExistingUserData(); // Cargar datos si viene de un registro incompleto

    // ✅ Agregar listeners para actualizar el estado cuando cambian los campos
    _nombresController.addListener(_updateButtonState);
    _apellidosController.addListener(_updateButtonState);
    _identificadorController.addListener(_updateButtonState);
    _fechaNacimientoController.addListener(_updateButtonState); // ✅ NUEVO
  }

  /// Cargar datos existentes si el usuario viene a completar su registro
  Future<void> _loadExistingUserData() async {
    if (widget.identificadorInicial != null) {
      final userData = await _localDb.getUserByIdentifier(
        widget.identificadorInicial!,
      );

      if (userData != null) {
        setState(() {
          _nombresController.text = userData['nombres'] ?? '';
          _apellidosController.text = userData['apellidos'] ?? '';
          _identificadorController.text = userData['identificador_unico'] ?? '';
          _fechaNacimientoController.text = userData['fecha_nacimiento'] ?? '';
          _sexoSeleccionado = userData['sexo'];

          // Ir al paso inicial si se especifica
          if (widget.pasoInicial != null) {
            _currentStep = widget.pasoInicial!;
          }
        });
      }
    }
  }

  /// Actualiza el estado del botón cuando cambian los campos de texto
  void _updateButtonState() {
    setState(() {
      // Solo fuerza rebuild para actualizar el estado del botón
    });
  }

  /// Obtiene el mensaje que indica qué falta para poder continuar
  String _getRequirementMessage() {
    switch (_currentStep) {
      case 0: // Datos personales
        final faltantes = <String>[];
        if (_nombresController.text.trim().isEmpty) faltantes.add('Nombres');
        if (_apellidosController.text.trim().isEmpty)
          faltantes.add('Apellidos');
        if (_identificadorController.text.trim().isEmpty)
          faltantes.add('Cédula');
        if (_fechaNacimientoController.text.trim().isEmpty)
          faltantes.add('Fecha de nacimiento');
        if (_sexoSeleccionado == null || _sexoSeleccionado!.isEmpty)
          faltantes.add('Sexo');

        if (faltantes.isEmpty) return '';
        return '⚠️ Completa: ${faltantes.join(', ')}';

      case 1: // Fotos de oreja
        final fotosFaltantes = earPhotos.where((photo) => photo == null).length;
        if (fotosFaltantes == 0) return '';
        return '⚠️ Faltan $fotosFaltantes foto${fotosFaltantes > 1 ? 's' : ''} de oreja (5 requeridas)';

      case 2: // Audios de voz
        final audiosFaltantes = voiceAudios
            .where((audio) => audio == null)
            .length;
        if (audiosFaltantes == 0) return '';
        return '⚠️ Faltan $audiosFaltantes audio${audiosFaltantes > 1 ? 's' : ''} de voz (6 requeridos)';

      default:
        return '';
    }
  }

  /// Detecta cuando la app vuelve del background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      debugPrint('[Register] 📱 App resumida - verificando conectividad...');
      _checkConnectivity();
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity().timeout(
        Duration(seconds: 3),
        onTimeout: () {
          return [ConnectivityResult.none];
        },
      );

      if (mounted) {
        setState(() {
          _isOnline =
              result.isNotEmpty && result.first != ConnectivityResult.none;
        });
        debugPrint(
          '[Register] 📡 Conectividad: ${_isOnline ? "ONLINE" : "OFFLINE"}',
        );
      }
    } catch (e) {
      debugPrint('[Register] ⚠️ Error verificando conectividad: $e');
      if (mounted) {
        setState(() {
          _isOnline = false;
        });
      }
    }
  }

  /// 🎤 Cargar frases de voz desde la BD (si hay Internet) o usar las locales
  Future<void> _loadVoicePhrases() async {
    try {
      // Intentar cargar frases desde la base de datos local (sincronizadas)
      final phrasesFromDb = await _localDb.getVoicePhrases();

      if (phrasesFromDb.isNotEmpty && phrasesFromDb.length >= 6) {
        setState(() {
          _voicePhrases = phrasesFromDb.take(6).toList();
        });
        debugPrint(
          '[Register] 🎤 Frases cargadas de BD local: ${_voicePhrases.length} frases',
        );
      } else {
        // ✅ Seleccionar 12 frases ALEATORIAS de las 50 disponibles
        final allPhrases = List<String>.from(
          _voicePhrases,
        ); // Copiar lista completa
        allPhrases.shuffle(); // Barajar aleatoriamente
        setState(() {
          _voicePhrases = allPhrases.take(12).toList(); // Tomar solo 12
        });
        debugPrint(
          '[Register] � Usando 12 frases aleatorias de las 50 por defecto',
        );
      }

      // Si hay Internet, intentar sincronizar frases nuevas del servidor
      if (_isOnline) {
        _syncVoicePhrasesFromServer();
      }
    } catch (e) {
      debugPrint('[Register] ⚠️ Error cargando frases de voz: $e');
      // Continuar con frases por defecto aleatorias
      final allPhrases = List<String>.from(_voicePhrases);
      allPhrases.shuffle();
      setState(() {
        _voicePhrases = allPhrases.take(12).toList();
      });
    }
  }

  /// 🌐 Sincronizar frases de voz desde el servidor (background, no bloquea UI)
  Future<void> _syncVoicePhrasesFromServer() async {
    try {
      // TODO: Implementar endpoint en backend para obtener frases aleatorias
      // Por ahora, las frases por defecto son suficientes
      debugPrint(
        '[Register] 🌐 Sync de frases desde servidor (pendiente implementar endpoint)',
      );
    } catch (e) {
      debugPrint('[Register] ⚠️ Error sincronizando frases desde servidor: $e');
    }
  }

  Future<void> _initializeServices() async {
    try {
      // ✅ IMPORTANTE: Cargar configuración de admin PRIMERO
      await _adminService.loadSettings();
      debugPrint(
        '[Register] ⚙️ Configuración de admin cargada: requireAllFields=${_adminService.currentSettings?.requireAllFieldsInRegistration}',
      );

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
    WidgetsBinding.instance.removeObserver(this);

    // ✅ Remover listeners antes de dispose
    _nombresController.removeListener(_updateButtonState);
    _apellidosController.removeListener(_updateButtonState);
    _identificadorController.removeListener(_updateButtonState);
    _fechaNacimientoController.removeListener(_updateButtonState); // ✅ NUEVO

    _nombresController.dispose();
    _apellidosController.dispose();
    _identificadorController.dispose();
    _fechaNacimientoController.dispose();
    _cameraService.dispose();
    _audioService.dispose();
    _earValidator.dispose(); // Liberar recursos del validador
    super.dispose();
  }

  Future<void> _captureEarPhoto(int photoNumber) async {
    // Abrir pantalla de vista previa de cámara para que el usuario pueda verse
    try {
      setState(() => _isLoading = true);

      final result = await Navigator.of(context).push<Uint8List?>(
        MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
      );

      if (result != null) {
        // 🧠 VALIDAR QUE SEA UNA OREJA con TensorFlow Lite (si está habilitado)
        final settings = await _adminService.loadSettings();

        if (settings.enableEarValidation) {
          final validationResult = await _earValidator.validateEar(result);

          if (!validationResult.isValid) {
            final errorMsg =
                validationResult.error ??
                '⚠️ La imagen no parece ser una oreja válida. '
                    'Confianza: ${validationResult.confidencePercentage}. '
                    'Por favor, intenta de nuevo asegurándote de capturar tu oreja claramente.';

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
                '✅ Foto $photoNumber de oreja capturada (${validationResult.confidencePercentage})',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Validación deshabilitada, aceptar cualquier foto
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Foto $photoNumber de oreja capturada'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // ✅ Recortar solo la zona de la oreja antes de guardar
        final croppedImage = CameraService.cropEarRegion(result);

        debugPrint(
          '[Register] 📸 Imagen recortada: ${result.length} bytes → ${croppedImage.length} bytes',
        );

        // ✅ Guardar foto recortada
        setState(() {
          earPhotos[photoNumber - 1] = croppedImage;
          _errorMessage = null;
        });

        // ✅ NUEVO: Verificar si ya se completaron todas las fotos
        final fotosCompletas = earPhotos.every((photo) => photo != null);
        debugPrint(
          '[Register] 📸 Foto $photoNumber guardada. Total: ${earPhotos.where((p) => p != null).length}/5. Puede avanzar: $fotosCompletas',
        );

        // ✅ NUEVO: Si ya completamos las 5 fotos, mostrar mensaje
        if (fotosCompletas) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '🎉 ¡Todas las fotos de oreja completadas! Presiona "Siguiente"',
              ),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error capturando foto: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _recordVoice(int audioNumber) async {
    try {
      // Verificar si está grabando (ahora es async)
      final isCurrentlyRecording = await _audioService.isRecording;

      if (isCurrentlyRecording) {
        // Detener grabación (WAV sin compresión)
        setState(() {
          _isLoading = true;
          _recordingAudioIndex = null; // ✅ Limpiar índice de grabación
        });

        debugPrint('[Register] 🎤 Deteniendo grabación WAV...');
        final audioBytes = await _audioService.stopRecording(); // ✅ WAV
        final duration = _audioService.getLastRecordingDuration();

        // 🔍 VALIDAR CALIDAD DE AUDIO
        final validationError = _biometricService.validateAudioQuality(
          audioBytes,
          duration,
        );

        if (validationError != null) {
          // ❌ Audio no válido
          setState(() {
            _isLoading = false;
            _errorMessage = validationError;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(validationError),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          return; // ⛔ No guardar el audio
        }

        // ✅ Audio válido - guardar
        setState(() {
          voiceAudios[audioNumber - 1] = audioBytes;
          _audioDurations[audioNumber - 1] = duration;
          _isLoading = false;
          _errorMessage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Audio $audioNumber grabado en WAV (${duration.toStringAsFixed(1)}s)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // ▶️ Iniciar grabación (el permiso se solicita dentro de AudioService)
        debugPrint('[Register] ▶️ Iniciando grabación audio $audioNumber...');
        await _audioService.startRecording();

        setState(() {
          _recordingAudioIndex =
              audioNumber - 1; // ✅ Marcar SOLO este índice como grabando
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎤 Grabando audio $audioNumber... presiona nuevamente para detener',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _recordingAudioIndex = null; // ✅ Limpiar índice de grabación
        _errorMessage = 'Error en grabación de audio: $e';
      });
    }
  }

  /// Reproducir audio grabado
  Future<void> _playAudio(int audioIndex) async {
    final audio = voiceAudios[audioIndex];
    if (audio == null) return;

    try {
      setState(() {
        _playingAudioIndex = audioIndex;
      });

      await _audioService.playAudioFromBytes(audio);

      // Esperar a que termine la reproducción
      await Future.delayed(
        Duration(seconds: _audioDurations[audioIndex]?.ceil() ?? 3),
      );

      setState(() {
        _playingAudioIndex = null;
      });
    } catch (e) {
      setState(() {
        _playingAudioIndex = null;
        _errorMessage = 'Error reproduciendo audio: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al reproducir audio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Detener reproducción de audio
  Future<void> _stopAudio() async {
    await _audioService.stopPlayer();
    setState(() {
      _playingAudioIndex = null;
    });
  }

  Future<void> _submitRegistration() async {
    // Guardar la etapa final (voz) antes de completar el registro
    await _saveCurrentStepAndProceed();
  }

  /// Guardar el paso actual y avanzar al siguiente
  Future<void> _saveCurrentStepAndProceed() async {
    setState(() => _isLoading = true);

    try {
      switch (_currentStep) {
        case 0: // Guardar datos personales
          await _saveDatosPersonales();
          break;
        case 1: // Guardar fotos de oreja
          await _saveFotosOreja();
          break;
        case 2: // Guardar audios de voz y completar registro
          await _saveAudiosVoz();
          break;
      }

      setState(() {
        _isLoading = false;
        if (_currentStep < 2) {
          _currentStep++; // Avanzar al siguiente paso
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al guardar: $e';
      });
    }
  }

  /// Guardar datos personales (Paso 0)
  Future<void> _saveDatosPersonales() async {
    print('[Register] ═══════════════════════════════════════');
    print('[Register] 📋 PASO 1: GUARDANDO DATOS PERSONALES');
    print('[Register] ═══════════════════════════════════════');

    // Verificar conectividad
    await _checkConnectivity();
    print(
      '[Register] 🌐 Estado de conexión: ${_isOnline ? "ONLINE" : "OFFLINE"}',
    );

    // ✅ Actualizar URLs del backend desde configuración de admin
    await _authService.updateBackendUrls();

    final identificador = _identificadorController.text.trim();
    print('[Register] 🆔 Identificador: $identificador');

    // Verificar si el usuario ya existe localmente
    final userExists = await _localDb.userExists(identificador);
    print(
      '[Register] 📱 Usuario existe localmente: ${userExists ? "SÍ" : "NO"}',
    );

    int idUsuario = 0;
    if (!userExists) {
      // Crear nuevo usuario localmente PRIMERO
      print('[Register] 💾 Creando usuario en SQLite local...');
      idUsuario = await _localDb.insertUser(
        nombres: _nombresController.text.trim(),
        apellidos: _apellidosController.text.trim(),
        identificadorUnico: identificador,
        fechaNacimiento: _fechaNacimientoController.text.trim().isNotEmpty
            ? _fechaNacimientoController.text.trim()
            : null,
        sexo: _sexoSeleccionado,
      );
      print('[Register] ✅ Usuario creado en SQLite local con ID: $idUsuario');
    } else {
      print('[Register] ⚠️ Usuario ya existe localmente');
      // Obtener el ID del usuario existente
      final userMap = await _localDb.getUserByIdentifier(identificador);
      idUsuario = userMap?['id_usuario'] as int? ?? 0;
      print('[Register] 👤 ID Usuario existente: $idUsuario');
    }

    // Si hay internet, registrar en el backend de Python (puerto 8080)
    // SIEMPRE intentar registrar en backend (aunque ya exista localmente)
    if (_isOnline) {
      try {
        final biometricBackend = BiometricBackendService();

        print('[Register] ═══════════════════════════════════════');
        print('[Register] 🌐 SINCRONIZANDO CON BACKEND...');
        print('[Register] ═══════════════════════════════════════');
        print('[Register] 📝 Datos a enviar:');
        print('  - identificador: $identificador');
        print('  - nombres: ${_nombresController.text.trim()}');
        print('  - apellidos: ${_apellidosController.text.trim()}');
        print('  - fechaNacimiento: ${_fechaNacimientoController.text.trim()}');
        print('  - sexo: $_sexoSeleccionado');

        // ✅ Enviar a http://167.71.155.9:8080/registrar_usuario
        final result = await biometricBackend.registrarUsuario(
          identificadorUnico: identificador,
          nombres: _nombresController.text.trim(),
          apellidos: _apellidosController.text.trim(),
          fechaNacimiento: _fechaNacimientoController.text.trim().isNotEmpty
              ? _fechaNacimientoController.text.trim()
              : null,
          sexo: _sexoSeleccionado,
        );

        print('[Register] ✅✅✅ Usuario registrado en BACKEND exitosamente');
        print('[Register] 📦 Respuesta del servidor: $result');
      } catch (e) {
        print('[Register] ═══════════════════════════════════════');
        print('[Register] ❌ ERROR SINCRONIZANDO CON BACKEND');
        print('[Register] ═══════════════════════════════════════');
        print('[Register] 🔴 Tipo de error: ${e.runtimeType}');
        if (e is DioException) {
          print('[Register] 🔴 Status HTTP: ${e.response?.statusCode}');
          print('[Register] 🔴 Response: ${e.response?.data}');
          print('[Register] 🔴 URL: ${e.requestOptions.uri}');
        }
        print(
          '[Register] ⚠️ Continuando con registro local (se sincronizará después)',
        );
        // Continuar aunque falle el backend (se sincronizará después)
      }
    } else {
      print('[Register] 📴 Sin conexión - registro solo local');
      print('[Register] ℹ️ Usuario ya agregado a cola por insertUser()');

      // ✅ NO es necesario agregar a cola aquí - insertUser() ya lo hizo automáticamente
    }

    // Actualizar bandera de datos completos
    print('[Register] 🏁 Actualizando estado de completitud...');
    await _localDb.updateUserCompletionStatus(
      identificadorUnico: identificador,
      datosCompletos: true,
    );
    print('[Register] ✅ Estado actualizado: datosCompletos = true');
    print('[Register] ═══════════════════════════════════════\n');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isOnline
                ? '✅ Datos personales guardados en backend y localmente'
                : '📴 Datos guardados localmente (sin conexión)',
          ),
          backgroundColor: _isOnline ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  /// Guardar fotos de oreja (Paso 1)
  Future<void> _saveFotosOreja() async {
    print('[Register] ═══════════════════════════════════════');
    print('[Register] 📸 PASO 2: GUARDANDO FOTOS DE OREJA');
    print('[Register] ═══════════════════════════════════════');

    // ✅ IMPORTANTE: Solo validar si la configuración lo requiere
    final settings = _adminService.currentSettings;
    final requireAllFields = settings?.requireAllFieldsInRegistration ?? true;
    print(
      '[Register] ⚙️ Validación obligatoria: ${requireAllFields ? "SÍ" : "NO"}',
    );

    final fotosCapturadas = earPhotos.where((p) => p != null).length;
    print('[Register] 📷 Fotos capturadas: $fotosCapturadas/5');

    if (requireAllFields && earPhotos.any((p) => p == null)) {
      throw Exception('Por favor captura las 5 fotos de oreja');
    }

    // ✅ Si no se requieren todos los campos, permitir guardar sin fotos
    if (!requireAllFields && earPhotos.every((p) => p == null)) {
      debugPrint(
        '[Register] ⚠️ No hay fotos de oreja pero validación deshabilitada - Continuar',
      );
      return; // No hay nada que guardar pero permitir avanzar
    }

    await _checkConnectivity();
    print(
      '[Register] 🌐 Estado de conexión: ${_isOnline ? "ONLINE" : "OFFLINE"}',
    );

    final identificador = _identificadorController.text.trim();

    // 📱 GUARDAR PLANTILLAS LOCALMENTE PRIMERO (para validación offline)
    print('[Register] ═══════════════════════════════════════');
    print('[Register] 💾 GUARDANDO EN SQLITE LOCAL');
    print('[Register] ═══════════════════════════════════════');

    // Obtener ID del usuario local
    final userMap = await _localDb.getUserByIdentifier(identificador);
    if (userMap == null) {
      throw Exception('Usuario no encontrado en base de datos local');
    }

    final idUsuario = userMap['id_usuario'] as int;
    print('[Register] 👤 ID Usuario SQLite: $idUsuario');

    // 🔥 PROCESAR FOTOS CON liboreja_mobile.so (LDA + KNN)
    print('[Register] ═══════════════════════════════════════');
    print('[Register] 💾 REGISTRANDO OREJAS CON liboreja_mobile.so');
    print('[Register] ═══════════════════════════════════════');

    try {
      // ✅ CONSERVAR modelos base de OREJA pre-cargados (igual que VOZ)
      // - templates_k1.csv: 50 usuarios base para comparación LDA
      // - caracteristicas_lda_train.csv: Dataset de entrenamiento
      // - modelo_pca.dat, modelo_lda.dat, zscore_params.dat: Modelos ML

      print(
        '[Register] ℹ️ Modelos de OREJA pre-cargados conservados (50 usuarios base)',
      );
      print(
        '[Register] ℹ️ Modelos de VOZ pre-cargados conservados (68 clasificadores SVM)',
      );

      // Inicializar servicio nativo (copiará modelos desde assets si no existen)
      final nativeEarService = NativeEarMobileService();
      await nativeEarService.initialize();

      // Guardar fotos temporalmente en disco
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePaths = <String>[];

      for (int i = 0; i < 5; i++) {
        if (i < earPhotos.length && earPhotos[i] != null) {
          final photoPath = '${tempDir.path}/register_ear_${i}_$timestamp.jpg';
          final photoFile = File(photoPath);
          await photoFile.writeAsBytes(earPhotos[i]!);
          imagePaths.add(photoPath);
        }
      }

      print(
        '[Register] 📸 Procesando ${imagePaths.length} fotos de oreja con LDA...',
      );

      // Registrar con liboreja_mobile.so (agregará al templates_k1.csv base)
      final resultado = await nativeEarService.registerBiometric(
        identificadorUnico: idUsuario,
        imagePaths: imagePaths,
      );

      // Limpiar archivos temporales
      for (final path in imagePaths) {
        try {
          await File(path).delete();
        } catch (e) {
          print('[Register] ⚠️ No se pudo eliminar archivo temporal: $e');
        }
      }

      if (resultado['success'] == true) {
        print('[Register] ✅ Orejas registradas con LDA exitosamente');
        print('[Register] 📊 Resultado: $resultado');
      } else {
        print('[Register] ❌ Error registrando orejas: ${resultado['error']}');
      }
    } catch (e) {
      print('[Register] ❌ Error procesando orejas con .so: $e');
      print('[Register] ⚠️ Continuando con sincronización al backend...');
    }

    // 🔥 AGREGAR A COLA DE SINCRONIZACIÓN
    // El SyncManager se encargará de procesarlas y enviarlas al backend
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
      print(
        '[Register] ✅ ${imagenesParaEnviar.length} fotos agregadas a cola de sincronización',
      );
    } catch (e) {
      print('[Register] ⚠️ Error agregando fotos a cola: $e');
    }

    // Si hay internet, enviar al backend Python (puerto 8080) INMEDIATAMENTE
    if (_isOnline) {
      try {
        print('[Register] ═══════════════════════════════════════');
        print('[Register] 🌐 SINCRONIZANDO CON BACKEND (OREJA)');
        print('[Register] ═══════════════════════════════════════');

        final biometricBackend = BiometricBackendService();
        final imagenesParaEnviar = earPhotos.whereType<Uint8List>().toList();
        print(
          '[Register] 📤 Enviando ${imagenesParaEnviar.length} imágenes al backend...',
        );

        // ✅ Enviar a http://167.71.155.9:8080/oreja/registrar
        await biometricBackend.registrarBiometriaOreja(
          identificador: identificador,
          imagenes: imagenesParaEnviar,
        );

        print(
          '[Register] ✅✅✅ Fotos de oreja registradas en BACKEND exitosamente',
        );

        // Marcar items en cola como enviados
        print('[Register] 📝 Marcando fotos como sincronizadas en cola...');
        // TODO: Implementar markeo en cola cuando se agregue el método
      } catch (e) {
        print('[Register] ═══════════════════════════════════════');
        print('[Register] ❌ ERROR SINCRONIZANDO OREJA CON BACKEND');
        print('[Register] ═══════════════════════════════════════');
        print('[Register] 🔴 Error: $e');
        print('[Register] ⚠️ Quedará en cola para sincronización posterior');
      }
    } else {
      print('[Register] 📴 Sin conexión - quedará en cola para sincronización');
    }

    // Actualizar bandera de orejas completas
    print('[Register] 🏁 Actualizando estado de completitud...');
    await _localDb.updateUserCompletionStatus(
      identificadorUnico: identificador,
      orejasCompletas: true,
    );
    print('[Register] ✅ Estado actualizado: orejasCompletas = true');
    print('[Register] ═══════════════════════════════════════\n');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isOnline
                ? '✅ Fotos de oreja guardadas (local + backend)'
                : '📴 Fotos guardadas localmente (sin conexión)',
          ),
          backgroundColor: _isOnline ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  /// Guardar audios de voz (Paso 2) y completar registro
  Future<void> _saveAudiosVoz() async {
    print('[Register] ═══════════════════════════════════════');
    print('[Register] 🎤 PASO 3: GUARDANDO AUDIOS DE VOZ');
    print('[Register] ═══════════════════════════════════════');

    // ✅ IMPORTANTE: Solo validar si la configuración lo requiere
    final settings = _adminService.currentSettings;
    final requireAllFields = settings?.requireAllFieldsInRegistration ?? true;
    print(
      '[Register] ⚙️ Validación obligatoria: ${requireAllFields ? "SÍ" : "NO"}',
    );

    final audiosCapturados = voiceAudios.where((a) => a != null).length;
    print('[Register] 🎙️ Audios capturados: $audiosCapturados/6');

    if (requireAllFields && voiceAudios.any((a) => a == null)) {
      throw Exception('Por favor graba los 6 audios de voz requeridos');
    }

    // ✅ Si no se requieren todos los campos, permitir guardar sin audios
    if (!requireAllFields && voiceAudios.every((a) => a == null)) {
      debugPrint(
        '[Register] ⚠️ No hay audios de voz pero validación deshabilitada - Continuar',
      );
      return; // No hay nada que guardar pero permitir completar registro
    }

    await _checkConnectivity();
    print(
      '[Register] 🌐 Estado de conexión: ${_isOnline ? "ONLINE" : "OFFLINE"}',
    );

    final identificador = _identificadorController.text.trim();

    // 📱 REGISTRAR BIOMETRÍA DE VOZ USANDO libvoz_mobile.so (SVM INCREMENTAL)
    print('[Register] ═══════════════════════════════════════');
    print(
      '[Register] 💾 REGISTRANDO VOZ CON libvoz_mobile.so (SVM INCREMENTAL)',
    );
    print('[Register] ⚡ Modo: Entrenamiento incremental optimizado (batch)');
    print('[Register] ═══════════════════════════════════════');

    final nativeService = NativeVoiceMobileService();
    final initialized = await nativeService.initialize();

    if (!initialized) {
      throw Exception(
        'Error inicializando libvoz_mobile.so. Verifica que los modelos SVM estén copiados.',
      );
    }

    // Obtener directorio temporal para guardar audios
    final tempDir = await getTemporaryDirectory();

    // 🚀 PASO 1: Guardar TODOS los audios en archivos temporales primero
    print('[Register] 📁 Guardando 6 audios en archivos temporales...');
    final List<String> audioPaths = [];

    setState(() {
      _processingMessage = '📁 Preparando audios para entrenamiento...';
    });

    for (int i = 0; i < voiceAudios.length; i++) {
      final audio = voiceAudios[i];
      if (audio != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final audioPath = '${tempDir.path}/register_voice_${i}_$timestamp.wav';
        final audioFile = File(audioPath);
        await audioFile.writeAsBytes(audio);
        audioPaths.add(audioPath);
        print(
          '[Register] 💾 Audio #${i + 1} guardado: $audioPath (${audio.length} bytes)',
        );
      }
    }

    print('[Register] ✅ ${audioPaths.length} audios listos para entrenamiento');

    // 🚀 PASO 2: Entrenar TODOS los audios EN BATCH (UNA SOLA VEZ)
    print('[Register] ═══════════════════════════════════════');
    print('[Register] 🧠 ENTRENAMIENTO BATCH SVM (OPTIMIZADO)');
    print('[Register] ═══════════════════════════════════════');

    setState(() {
      _processingMessage =
          '🧠 Entrenando modelo SVM en batch (${audioPaths.length} audios)...';
    });

    int plantillasGuardadas = 0;
    try {
      print(
        '[Register] 📤 Enviando ${audioPaths.length} audios al .so en batch...',
      );

      final stopwatch = Stopwatch()..start();

      // 🚀 LLAMADA BATCH: Entrena UNA SOLA VEZ con todos los audios
      final resultado = await nativeService.registerBiometricBatch(
        identificador: identificador,
        audioPaths: audioPaths,
      );

      stopwatch.stop();

      print(
        '[Register] ⏱️ Tiempo total de entrenamiento: ${stopwatch.elapsedMilliseconds}ms',
      );

      if (resultado['success'] == true) {
        print('[Register] ✅✅✅ BATCH completado exitosamente');
        print('[Register] 📊 Resultado: $resultado');

        if (resultado.containsKey('samples_trained')) {
          print(
            '[Register] 🧠 SVM entrenado con ${resultado['samples_trained']} muestras totales',
          );
        }

        plantillasGuardadas = audioPaths.length;
      } else {
        throw Exception(resultado['error'] ?? 'Error en entrenamiento batch');
      }
    } catch (e) {
      print('[Register] ❌ Error en entrenamiento batch: $e');

      // FALLBACK: Si batch falla, intentar uno por uno (compatibilidad)
      print(
        '[Register] ⚠️ Intentando entrenamiento secuencial como fallback...',
      );

      for (int i = 0; i < audioPaths.length; i++) {
        try {
          print(
            '[Register] 🎤 Entrenando audio #${i + 1}/${audioPaths.length}...',
          );

          final resultado = await nativeService.registerBiometric(
            identificador: identificador,
            audioPath: audioPaths[i],
            idFrase: (i % 2) + 1,
          );

          if (resultado['success'] == true) {
            plantillasGuardadas++;
            print('[Register] ✅ Audio #${i + 1} registrado');
          }
        } catch (fallbackError) {
          print('[Register] ❌ Error en audio #${i + 1}: $fallbackError');
        }
      }
    }

    // 🚀 PASO 3: Limpiar archivos temporales
    print('[Register] 🧹 Limpiando archivos temporales...');
    for (final audioPath in audioPaths) {
      try {
        await File(audioPath).delete();
      } catch (e) {
        print('[Register] ⚠️ No se pudo eliminar $audioPath: $e');
      }
    }

    print(
      '[Register] 💾 Total plantillas registradas con SVM: $plantillasGuardadas/${audioPaths.length}',
    );

    // ✅ VALIDAR QUE SE HAYAN REGISTRADO SUFICIENTES AUDIOS
    const int minAudios = 3; // Mínimo 3 audios para entrenar SVM
    if (plantillasGuardadas < minAudios) {
      print(
        '[Register] ❌ ERROR: Solo se registraron $plantillasGuardadas audios, se necesitan al menos $minAudios',
      );
      throw Exception(
        'Error en registro de voz: Solo se registraron $plantillasGuardadas de ${audioPaths.length} audios.\n'
        'Se necesitan al menos $minAudios audios para entrenar el modelo.\n'
        'Por favor intenta registrarte nuevamente.',
      );
    }

    print(
      '[Register] ✅ Modelo SVM entrenado localmente con $plantillasGuardadas audios',
    );

    // Limpiar mensaje de progreso
    setState(() {
      _processingMessage = '';
    });

    print(
      '[Register] 🎯 Autenticación OFFLINE ahora disponible para este usuario',
    );

    // Obtener ID del usuario para cola de sincronización
    final userMap = await _localDb.getUserByIdentifier(identificador);
    final idUsuario = userMap?['id_usuario'] as int? ?? 0;

    // 🔥 AGREGAR A COLA DE SINCRONIZACIÓN (si es necesario)
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
      print(
        '[Register] ✅ ${audiosParaEnviar.length} audios agregados a cola de sincronización',
      );
    } catch (e) {
      print('[Register] ⚠️ Error agregando audios a cola: $e');
    }

    // Si hay internet, enviar al backend Python (puerto 8081) INMEDIATAMENTE
    if (_isOnline) {
      try {
        print('[Register] ═══════════════════════════════════════');
        print('[Register] 🌐 SINCRONIZANDO CON BACKEND (VOZ)');
        print('[Register] ═══════════════════════════════════════');

        final biometricBackend = BiometricBackendService();
        final audiosParaEnviar = voiceAudios.whereType<Uint8List>().toList();
        print(
          '[Register] 📤 Enviando ${audiosParaEnviar.length} audios al backend...',
        );

        // ✅ Enviar a http://167.71.155.9:8081/voz/registrar_biometria
        await biometricBackend.registrarBiometriaVoz(
          identificador: identificador,
          audios: audiosParaEnviar,
        );

        print(
          '[Register] ✅✅✅ Audios de voz registrados en BACKEND exitosamente',
        );
        print(
          '[Register] 📊 Backup en nube completado (opcional para analytics)',
        );

        // Marcar items en cola como enviados
        print('[Register] 📝 Marcando audios como sincronizados en cola...');
        // TODO: Implementar markeo en cola cuando se agregue el método
      } catch (e) {
        print('[Register] ═══════════════════════════════════════');
        print('[Register] ❌ ERROR SINCRONIZANDO VOZ CON BACKEND');
        print('[Register] ═══════════════════════════════════════');
        print('[Register] 🔴 Error: $e');
        print('[Register] ⚠️ Quedará en cola para sincronización posterior');
      }
    } else {
      print('[Register] 📴 Sin conexión - quedará en cola para sincronización');
    }

    // Actualizar bandera de voz completa
    print('[Register] 🏁 Actualizando estado de completitud...');
    await _localDb.updateUserCompletionStatus(
      identificadorUnico: identificador,
      vozCompleta: true,
    );
    print('[Register] ✅ Estado actualizado: vozCompleta = true');
    print('[Register] ═══════════════════════════════════════');
    print('[Register] 🎉 REGISTRO COMPLETO - RESUMEN FINAL');
    print('[Register] ═══════════════════════════════════════');
    print('[Register] 📊 Plantillas en SQLite:');
    print('[Register]    - Orejas: guardadas');
    print('[Register]    - Voz: $plantillasGuardadas templates');
    print(
      '[Register] 🌐 Sincronización backend: ${_isOnline ? "EXITOSA" : "PENDIENTE (offline)"}',
    );
    print('[Register] ═══════════════════════════════════════\n');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isOnline
                ? '✅ Registro completo! Puedes iniciar sesión'
                : '📴 Registro guardado localmente (se sincronizará con conexión)',
          ),
          backgroundColor: _isOnline ? Colors.green : Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );

      // Volver a login después de 2 segundos
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Biometría'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  if (_processingMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _processingMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo de la aplicación
                  const Center(child: AppLogo(size: 80, showText: true)),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  // Stepper
                  _buildStepper(),
                  const SizedBox(height: 24),
                  // Contenido por paso
                  if (_currentStep == 0) _buildStep0DatosPersonales(),
                  if (_currentStep == 1) _buildStep1FotosOreja(),
                  if (_currentStep == 2) _buildStep2VoiceRecording(),
                  const SizedBox(height: 24),
                  // Botones de navegación
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 0)
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _currentStep--),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Atrás'),
                        ),
                      if (_currentStep < 2)
                        ElevatedButton.icon(
                          onPressed: _canProceedToNextStep()
                              ? _saveCurrentStepAndProceed
                              : null, // Deshabilitar botón si no puede avanzar
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Siguiente'),
                        ),
                      if (_currentStep == 2)
                        ElevatedButton.icon(
                          onPressed: _canProceedToNextStep()
                              ? _submitRegistration
                              : null, // Deshabilitar si faltan audios
                          icon: const Icon(Icons.check),
                          label: const Text('Registrarse'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _canProceedToNextStep()
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Mensaje de ayuda cuando el botón está deshabilitado
                  if (!_canProceedToNextStep())
                    Center(
                      child: Text(
                        _getRequirementMessage(),
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Link para ir a login
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => LoginScreen()),
                        );
                      },
                      child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStepper() {
    return Row(
      children: [
        _buildStepIndicator(0, 'Datos'),
        const Expanded(child: Divider(height: 2, color: Colors.blue)),
        _buildStepIndicator(1, 'Oreja'),
        const Expanded(child: Divider(height: 2, color: Colors.blue)),
        _buildStepIndicator(2, 'Voz'),
      ],
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: isActive ? Colors.blue : Colors.grey,
          child: Text(
            '${step + 1}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildStep0DatosPersonales() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paso 1: Datos Personales',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // ✅ NUEVO: Mensaje informativo sobre campos obligatorios
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Los campos marcados con * son obligatorios',
                  style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nombresController,
          decoration: InputDecoration(
            labelText: 'Nombres *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apellidosController,
          decoration: InputDecoration(
            labelText: 'Apellidos *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _identificadorController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Cédula / Identificador Único *',
            hintText: 'Ej: 0102030405',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.badge),
          ),
        ),
        const SizedBox(height: 12),
        // Fecha de nacimiento
        TextField(
          controller: _fechaNacimientoController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Fecha de Nacimiento *',
            hintText: 'Toca para seleccionar',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.calendar_today),
            suffixIcon: _fechaNacimientoController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _fechaNacimientoController.clear();
                      });
                    },
                  )
                : null,
          ),
          onTap: () async {
            try {
              final now = DateTime.now();
              final fecha = await showDatePicker(
                context: context,
                initialDate: DateTime(now.year - 25), // 25 años por defecto
                firstDate: DateTime(1900),
                lastDate: now,
                helpText: 'Selecciona tu fecha de nacimiento',
                cancelText: 'Cancelar',
                confirmText: 'OK',
                // Sin locale para evitar crash
              );
              if (fecha != null) {
                setState(() {
                  _fechaNacimientoController.text =
                      '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
                });
              }
            } catch (e) {
              debugPrint('[Register] ⚠️ Error al abrir DatePicker: $e');
              // Mostrar mensaje de error al usuario
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al abrir calendario: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
        const SizedBox(height: 12),
        // Sexo
        DropdownButtonFormField<String>(
          value: _sexoSeleccionado,
          decoration: InputDecoration(
            labelText: 'Sexo *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.person_outline),
          ),
          items: const [
            DropdownMenuItem(value: 'M', child: Text('Masculino')),
            DropdownMenuItem(value: 'F', child: Text('Femenino')),
            DropdownMenuItem(value: 'Otro', child: Text('Otro')),
          ],
          onChanged: (value) {
            setState(() {
              _sexoSeleccionado = value;
            });
          },
        ),
        const SizedBox(height: 12),
        // Campo de contraseña removido: autenticación solo por biometría
      ],
    );
  }

  Widget _buildStep1FotosOreja() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paso 2: Captura 7 Fotos de tu Oreja',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Asegúrate de que la oreja sea visible y bien iluminada. Captura desde diferentes ángulos.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        for (int i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildPhotoCard(i),
          ),
      ],
    );
  }

  Widget _buildPhotoCard(int index) {
    final hasPhoto = earPhotos[index] != null;

    // Indicaciones específicas para cada foto (REDUCIDO A 5 FOTOS)
    final Map<int, Map<String, String>> photoInstructions = {
      0: {
        'title': '📸 Foto 1: FRONT (Cámara Trasera)',
        'instruction': 'Mira al frente con la cabeza recta',
      },
      1: {
        'title': '📸 Foto 2: UP (Cámara Trasera)',
        'instruction': 'Mira hacia arriba como viendo el techo (ligeramente)',
      },
      2: {
        'title': '📸 Foto 3: DOWN (Cámara Trasera)',
        'instruction': 'Mira hacia abajo como viendo el suelo (ligeramente)',
      },
      3: {
        'title': '📸 Foto 4: LEFT (Cámara Trasera)',
        'instruction': 'Gira la cabeza a la izquierda SOLO 10-15 grados',
      },
      4: {
        'title': '📸 Foto 5: RIGHT (Cámara Trasera)',
        'instruction': 'Gira la cabeza a la derecha SOLO 10-15 grados',
      },
    };

    final instruction = photoInstructions[index]!;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título e instrucción
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasPhoto ? Colors.green.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasPhoto
                      ? Colors.green.shade200
                      : Colors.blue.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instruction['title']!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hasPhoto
                          ? Colors.green.shade900
                          : Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: hasPhoto
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          instruction['instruction']!,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasPhoto
                                ? Colors.green.shade800
                                : Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (hasPhoto)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  earPhotos[index]!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              )
            else
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      'Sin capturar',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _captureEarPhoto(index + 1),
              icon: Icon(hasPhoto ? Icons.refresh : Icons.camera),
              label: Text(hasPhoto ? 'Retomar foto' : 'Capturar foto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasPhoto ? Colors.orange : Colors.blue,
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2VoiceRecording() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paso 3: Graba 6 Audios de tu Voz',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Di cada frase claramente. Presiona el botón para grabar y presiona nuevamente para detener.',
                  style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        for (int i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildAudioCard(i),
          ),
      ],
    );
  }

  Widget _buildAudioCard(int index) {
    final hasAudio = voiceAudios[index] != null;
    final isRecordingThisAudio =
        _recordingAudioIndex == index; // ✅ Solo este audio está grabando

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎤 FRASE QUE DEBE DECIR EL USUARIO
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isRecordingThisAudio
                    ? Colors.red.shade50
                    : (hasAudio ? Colors.green.shade50 : Colors.amber.shade50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isRecordingThisAudio
                      ? Colors.red.shade300
                      : (hasAudio
                            ? Colors.green.shade300
                            : Colors.amber.shade300),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.record_voice_over,
                        color: isRecordingThisAudio
                            ? Colors.red.shade700
                            : (hasAudio
                                  ? Colors.green.shade700
                                  : Colors.amber.shade700),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isRecordingThisAudio
                              ? '🎤 GRABANDO - Di la frase:'
                              : (hasAudio
                                    ? '✅ Frase grabada:'
                                    : '📝 Di esta frase:'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isRecordingThisAudio
                                ? Colors.red.shade900
                                : (hasAudio
                                      ? Colors.green.shade900
                                      : Colors.amber.shade900),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 🎤 FRASE
                  Text(
                    '1️⃣ "${_voicePhrases[index * 2]}"',
                    style: TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: isRecordingThisAudio
                          ? Colors.red.shade800
                          : (hasAudio
                                ? Colors.green.shade800
                                : Colors.amber.shade900),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Botón de grabación
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasAudio
                        ? Colors.green.shade100
                        : (isRecordingThisAudio // ✅ SOLO este botón en rojo
                              ? Colors.red.shade100
                              : Colors.blue.shade100),
                    border: Border.all(
                      color: hasAudio
                          ? Colors.green
                          : (isRecordingThisAudio ? Colors.red : Colors.blue),
                      width: 2,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _recordVoice(index + 1),
                      customBorder: const CircleBorder(),
                      child: Icon(
                        hasAudio
                            ? Icons.check
                            : (isRecordingThisAudio ? Icons.stop : Icons.mic),
                        size: 30,
                        color: hasAudio
                            ? Colors.green
                            : (isRecordingThisAudio ? Colors.red : Colors.blue),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audio ${index + 1}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasAudio
                            ? '✅ Grabado (${_audioDurations[index]?.toStringAsFixed(1) ?? '0.0'}s)'
                            : (isRecordingThisAudio
                                  ? '🎤 Grabando...'
                                  : 'Presiona para grabar'),
                        style: TextStyle(
                          color: hasAudio
                              ? Colors.green
                              : (isRecordingThisAudio
                                    ? Colors.red
                                    : Colors.grey),
                          fontSize: 14,
                        ),
                      ),
                      // ✅ Mostrar tamaño del archivo
                      if (hasAudio && voiceAudios[index] != null)
                        Text(
                          'Tamaño: ${(voiceAudios[index]!.length / 1024).toStringAsFixed(1)} KB',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                // ✅ Botón de reproducción
                if (hasAudio &&
                    _playingAudioIndex != index &&
                    !isRecordingThisAudio)
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.blue),
                    tooltip: 'Reproducir',
                    onPressed: () => _playAudio(index),
                  ),
                // ✅ Botón de detener reproducción
                if (_playingAudioIndex == index)
                  IconButton(
                    icon: const Icon(Icons.stop, color: Colors.orange),
                    tooltip: 'Detener',
                    onPressed: _stopAudio,
                  ),
                // Botón de eliminar
                if (hasAudio &&
                    _playingAudioIndex != index &&
                    !isRecordingThisAudio)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Eliminar',
                    onPressed: () {
                      setState(() {
                        voiceAudios[index] = null;
                        _audioDurations.remove(index);
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
