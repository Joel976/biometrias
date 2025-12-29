import 'package:flutter/material.dart';
import '../services/auth_service_fix.dart';
import '../services/camera_service.dart';
import '../services/simple_audio_service.dart';
import '../services/local_database_service.dart';
import '../services/biometric_service.dart';
import '../services/ear_validator_service.dart';
import '../services/admin_settings_service.dart';
import '../models/biometric_models.dart';
import '../widgets/app_logo.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'camera_capture_screen.dart';
import 'admin_access_button.dart';
import 'dart:typed_data';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthServiceFix.instance;
  final _cameraService = CameraService();
  final _audioService = SimpleAudioService();
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
      if (_isRecordingNow) {
        setState(() => _isLoading = true);
        final audioBytes = await _audioService.stopRecording();

        setState(() {
          _recordedAudio = audioBytes;
          _isLoading = false;
          _isRecordingNow = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Grabación completada')));
      } else {
        await _audioService.startRecording();
        setState(() {
          _isRecordingNow = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grabando... presiona nuevamente para detener'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isRecordingNow = false;
        _errorMessage = 'Error en grabación: $e';
      });
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

      // Ejecutar validación local según tipo biométrico
      if (_selectedBiometricType == 1) {
        // Oreja
        if (_capturedPhoto == null) {
          throw Exception('Por favor captura una foto primero');
        }

        final templates = await localDb.getCredentialsByUserAndType(
          idUsuario,
          'oreja',
        );
        if (templates.isEmpty) {
          throw Exception('No existen plantillas de oreja para este usuario');
        }

        // Comparar contra cada template y escoger mejor confianza
        double bestConfidence = 0.0;
        EarValidationResult? bestResult;
        for (final tpl in templates) {
          final result = await biometricSvc.validateEar(
            imageData: _capturedPhoto!,
            templateData: Uint8List.fromList(tpl.template),
          );
          if (result.confidence > bestConfidence) {
            bestConfidence = result.confidence;
            bestResult = result;
          }
        }

        final bool success = bestResult?.isValid ?? false;

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
        // Voz
        if (_recordedAudio == null) {
          throw Exception('Por favor graba tu voz primero');
        }

        final templates = await localDb.getCredentialsByUserAndType(
          idUsuario,
          'audio',
        );
        if (templates.isEmpty) {
          throw Exception('No existen plantillas de voz para este usuario');
        }

        double bestConfidence = 0.0;
        VoiceValidationResult? bestResult;
        // Obtener frase objetivo (si aplica)
        final phrase = await localDb.getRandomAudioPhrase(idUsuario);
        final targetPhrase = phrase?.frase ?? '';

        for (final tpl in templates) {
          final result = await biometricSvc.validateVoice(
            audioData: _recordedAudio!,
            targetPhrase: targetPhrase,
            templateData: Uint8List.fromList(tpl.template),
          );
          if (result.confidence > bestConfidence) {
            bestConfidence = result.confidence;
            bestResult = result;
          }
        }

        final bool success = bestResult?.isValid ?? false;

        final Duration? _proc2 = bestResult?.processingTime;
        final int durMs = _proc2 != null ? _proc2.inMilliseconds : 0;

        final validation = BiometricValidation(
          id: 0,
          idUsuario: idUsuario,
          tipoBiometria: 'audio',
          resultado: success ? 'exito' : 'fallo',
          modoValidacion: 'offline',
          timestamp: DateTime.now(),
          puntuacionConfianza: bestConfidence,
          duracionValidacion: durMs,
        );

        await localDb.insertValidation(validation);

        await localDb
            .insertToSyncQueue(idUsuario, 'validacion_biometrica', 'insert', {
              'tipo_biometria': 'audio',
              'resultado': validation.resultado,
              'puntuacion_confianza': validation.puntuacionConfianza,
              'timestamp': validation.timestamp.toIso8601String(),
            });

        if (!success) throw Exception('Autenticación fallida: voz no coincide');
      }

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
                      // Identificador
                      TextField(
                        controller: _identifierController,
                        decoration: InputDecoration(
                          labelText: 'Identificador (cédula, pasaporte)',
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
                                onSelected: (_) =>
                                    setState(() => _selectedBiometricType = 2),
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
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 12),
                                  Text('Voz grabada'),
                                ],
                              ),
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
