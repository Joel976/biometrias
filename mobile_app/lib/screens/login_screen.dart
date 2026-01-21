import 'package:flutter/material.dart';
import '../services/auth_service_fix.dart';
import '../services/camera_service.dart';
import '../services/audio_service.dart';
import '../services/local_database_service.dart';
import '../services/biometric_service.dart';
import '../services/ear_validator_service.dart';
import '../services/admin_settings_service.dart';
import '../services/biometric_backend_service.dart';
import '../services/native_voice_service.dart';
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

  // 🎤 Variables para autenticación de voz
  String? _currentPhrase; // Frase que el usuario debe decir
  int? _currentPhraseId; // ID de la frase actual
  bool _isLoadingPhrase = false; // Cargando frase desde backend
  bool _isPlayingAudio = false; // Estado de reproducción de audio

  // 📶 Control de mensajes de conectividad
  DateTime? _lastOfflineMessageTime; // Última vez que se mostró el mensaje

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
  Future<void> _showOfflineMessage(String message) async {
    final settings = await _adminService.loadSettings();
    final intervalMinutes = settings.offlineMessageIntervalMinutes;

    // Verificar si ha pasado suficiente tiempo desde el último mensaje
    final now = DateTime.now();
    if (_lastOfflineMessageTime != null) {
      final difference = now.difference(_lastOfflineMessageTime!);
      if (difference.inMinutes < intervalMinutes) {
        // No mostrar el mensaje si no ha pasado el intervalo configurado
        print(
          '[Login] ⏳ Mensaje offline omitido (faltan ${intervalMinutes - difference.inMinutes} min)',
        );
        return;
      }
    }

    // Mostrar el mensaje y actualizar el timestamp
    _lastOfflineMessageTime = now;
    setState(() {
      _errorMessage = message;
    });
    print('[Login] 📱 Mensaje offline mostrado: $message');
  }

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

  /// 🎤 Cargar frase aleatoria desde el backend para autenticación de voz
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
        print('[Login] 🌐 Obteniendo frase aleatoria del backend...');

        final phraseData = await backendService.obtenerFraseAleatoria();

        setState(() {
          _currentPhraseId = phraseData['id_texto'] ?? phraseData['id'];
          _currentPhrase = phraseData['frase'];
          _isLoadingPhrase = false;
        });

        print(
          '[Login] ✅ Frase cargada: $_currentPhrase (ID: $_currentPhraseId)',
        );
      } else {
        // 📱 Fallback: usar frase aleatoria de la base de datos local
        print(
          '[Login] 📱 Sin conexión, buscando frase en base de datos local...',
        );

        final localDb = LocalDatabaseService();
        final localPhrase = await localDb.getRandomAudioPhrase(
          1,
        ); // idUsuario no se usa realmente

        if (localPhrase != null) {
          setState(() {
            _currentPhrase = localPhrase.frase;
            _currentPhraseId = localPhrase.id;
            _isLoadingPhrase = false;
          });

          print(
            '[Login] ✅ Frase local cargada: $_currentPhrase (ID: $_currentPhraseId)',
          );
        } else {
          // ⚠️ Última opción: frase hardcodeada
          print(
            '[Login] ⚠️ No hay frases en base de datos local, usando frase por defecto',
          );
          setState(() {
            _currentPhrase = 'Mi voz es mi contraseña';
            _currentPhraseId = 1;
            _isLoadingPhrase = false;
          });
        }
      }
    } catch (e) {
      print('[Login] ❌ Error cargando frase: $e');

      // Intentar cargar desde base de datos local como fallback
      try {
        final localDb = LocalDatabaseService();
        final localPhrase = await localDb.getRandomAudioPhrase(1);

        if (localPhrase != null) {
          setState(() {
            _currentPhrase = localPhrase.frase;
            _currentPhraseId = localPhrase.id;
            _isLoadingPhrase = false;
          });
          await _showOfflineMessage(
            'Usando frase almacenada localmente (sin conexión)',
          );
          print('[Login] ✅ Frase local cargada (fallback): $_currentPhrase');
        } else {
          // Última opción: frase hardcodeada
          setState(() {
            _currentPhrase = 'Mi voz es mi contraseña';
            _currentPhraseId = 1;
            _isLoadingPhrase = false;
            _errorMessage =
                'No se pudo cargar frase del servidor, usando frase por defecto';
          });
        }
      } catch (dbError) {
        print('[Login] ❌ Error accediendo a base de datos local: $dbError');
        // Última opción: frase hardcodeada
        setState(() {
          _currentPhrase = 'Mi voz es mi contraseña';
          _currentPhraseId = 1;
          _isLoadingPhrase = false;
          _errorMessage = 'Error cargando frase, usando frase por defecto';
        });
      }
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
    final biometricSvc = BiometricService();

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
            print('[Login]    - autenticado: $authenticated');
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
          // Oreja
          if (_capturedPhoto == null) {
            throw Exception('Por favor captura una foto primero');
          }

          print(
            '[Login] 📊 Buscando plantillas de oreja para usuario ID: $idUsuario',
          );
          final templates = await localDb.getCredentialsByUserAndType(
            idUsuario,
            'oreja',
          );

          print('[Login] 📦 Plantillas encontradas: ${templates.length}');

          if (templates.isEmpty) {
            print('[Login] ❌ ERROR: No hay plantillas de oreja registradas');
            print(
              '[Login] 💡 SOLUCIÓN: El usuario debe REGISTRARSE primero con sus 7 fotos de oreja',
            );
            throw Exception(
              'No existen plantillas de oreja registradas para este usuario.\n'
              'Por favor, registra tus fotos de oreja primero en la pantalla de Registro.',
            );
          }

          print(
            '[Login] 🔍 Comparando foto capturada contra ${templates.length} plantillas...',
          );

          // Comparar contra cada template y escoger mejor confianza
          double bestConfidence = 0.0;
          EarValidationResult? bestResult;
          int templateIndex = 0;

          for (final tpl in templates) {
            templateIndex++;
            print(
              '[Login] 🔄 Comparando contra plantilla #$templateIndex/${templates.length}...',
            );

            final result = await biometricSvc.validateEar(
              imageData: _capturedPhoto!,
              templateData: Uint8List.fromList(tpl.template),
            );

            print(
              '[Login] 📊 Plantilla #$templateIndex: Confianza = ${(result.confidence * 100).toStringAsFixed(2)}%',
            );

            if (result.confidence > bestConfidence) {
              bestConfidence = result.confidence;
              bestResult = result;
            }
          }

          print(
            '[Login] 🏆 MEJOR RESULTADO: Confianza = ${(bestConfidence * 100).toStringAsFixed(2)}%',
          );
          print('[Login] 📏 Threshold requerido: 90% (algoritmo robusto 512D)');

          final bool success = bestResult?.isValid ?? false;

          print(
            '[Login] ${success ? "✅ AUTENTICACIÓN EXITOSA" : "❌ AUTENTICACIÓN FALLIDA"}',
          );

          // Registrar validación local
          final Duration? _proc = bestResult?.processingTime;
          final int durMs = _proc != null ? _proc.inMilliseconds : 0;

          final validation = BiometricValidation(
            id: 0,
            idUsuario: idUsuario,
            tipoBiometria: 'oreja',
            resultado: success ? 'exito' : 'fallo',
            modoValidacion: 'offline',
            timestamp: DateTime.now(),
            puntuacionConfianza: bestConfidence,
            duracionValidacion: durMs,
          );

          await localDb.insertValidation(validation);

          // Encolar para sincronización
          await localDb
              .insertToSyncQueue(idUsuario, 'validacion_biometrica', 'insert', {
                'tipo_biometria': 'oreja',
                'resultado': validation.resultado,
                'puntuacion_confianza': validation.puntuacionConfianza,
                'timestamp': validation.timestamp.toIso8601String(),
              });

          if (!success)
            throw Exception('Autenticación fallida: oreja no coincide');
        } else {
          // Voz - Validación local
          if (_recordedAudio == null) {
            throw Exception('Por favor graba tu voz primero');
          }

          print(
            '[Login] 📊 Buscando plantillas de voz para usuario ID: $idUsuario',
          );

          // ✅ USAR libvoz_mobile.so para autenticación real con SVM
          print('[Login] 🎯 Usando libvoz_mobile.so para autenticación...');

          final nativeService = NativeVoiceService();
          final initialized = await nativeService.initialize();

          if (!initialized) {
            throw Exception(
              'Error inicializando libvoz_mobile.so. Verifica que los modelos SVM estén copiados.',
            );
          }

          // 🔍 VERIFICAR SI EL USUARIO EXISTE EN LA BIBLIOTECA
          final identificador = _identifierController.text.trim();
          final userExists = nativeService.userExists(identificador);

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

          // 🔍 EXTRAER SCORE NORMALIZADO de all_scores
          double normalizedScore = 0.0;
          if (resultado['all_scores'] != null) {
            final allScores = resultado['all_scores'] as Map<dynamic, dynamic>;
            if (allScores.isNotEmpty) {
              // Obtener el score del usuario predicho
              final predictedClass = resultado['predicted_class'];
              if (predictedClass != null &&
                  allScores.containsKey(predictedClass)) {
                normalizedScore = (allScores[predictedClass] as num).toDouble();
              } else {
                // Si no hay predicted_class, usar el score más alto
                normalizedScore = allScores.values
                    .map((v) => (v as num).toDouble())
                    .reduce((a, b) => a > b ? a : b);
              }
            }
          }

          // ⚖️ APLICAR THRESHOLD MANUALMENTE (0.99 = 99%)
          const double threshold = 0.99;
          final bool success = normalizedScore >= threshold;

          print(
            '[Login] 🏆 Score Normalizado: ${(normalizedScore * 100).toStringAsFixed(2)}%',
          );
          print(
            '[Login] 📏 Threshold SVM: ${(threshold * 100).toStringAsFixed(0)}%',
          );
          print(
            '[Login] ${success ? "✅ AUTENTICACIÓN VOZ EXITOSA (SVM)" : "❌ AUTENTICACIÓN VOZ FALLIDA (SVM)"}',
          );

          final validation = BiometricValidation(
            id: 0,
            idUsuario: idUsuario,
            tipoBiometria: 'voz',
            resultado: success ? 'exito' : 'fallo',
            modoValidacion: 'offline',
            timestamp: DateTime.now(),
            puntuacionConfianza: normalizedScore,
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

      // ✅ Autenticación exitosa - reiniciar contador de intentos
      _loginAttempts = 0;
      _lockoutUntil = null;

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

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
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

                          // 🎤 Mostrar frase que debe decir el usuario
                          if (_isLoadingPhrase)
                            const Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 8),
                                  Text('Cargando frase...'),
                                ],
                              ),
                            )
                          else if (_currentPhrase != null)
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
                                        'Di la siguiente frase:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '"$_currentPhrase"',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.black87,
                                    ),
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
}
