import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/auth_service_fix.dart';
import '../services/camera_service.dart';
import '../services/audio_service.dart';
import '../services/sync_manager.dart';
import '../services/local_database_service.dart';
import '../services/ear_validator_service.dart';
import '../services/admin_settings_service.dart';
import '../widgets/app_logo.dart';
import 'login_screen.dart';
import 'camera_capture_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with WidgetsBindingObserver {
  final _authService = AuthServiceFix.instance;
  final _cameraService = CameraService();
  final _audioService = AudioService();
  final _syncManager = SyncManager();
  final _localDb = LocalDatabaseService();
  final _connectivity = Connectivity();
  final _earValidator = EarValidatorService();
  final _adminService = AdminSettingsService();

  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _emailController = TextEditingController();
  final _identificadorController = TextEditingController();

  List<Uint8List?> earPhotos = [null, null, null]; // 3 fotos de oreja
  Uint8List? voiceAudio;

  int _currentStep = 0; // 0: datos, 1: fotos oreja, 2: audio voz
  bool _isLoading = false;
  String? _errorMessage;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _checkConnectivity();
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
    WidgetsBinding.instance.removeObserver(this);
    _nombresController.dispose();
    _apellidosController.dispose();
    _emailController.dispose();
    _identificadorController.dispose();
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
            setState(() {
              _isLoading = false;
              _errorMessage =
                  validationResult.error ??
                  '⚠️ La imagen no parece ser una oreja válida. '
                      'Confianza: ${validationResult.confidencePercentage}. '
                      'Por favor, intenta de nuevo asegurándote de capturar tu oreja claramente.';
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
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error capturando foto: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _recordVoice() async {
    try {
      if (_audioService.isRecording) {
        // Detener grabación
        setState(() => _isLoading = true);
        final audioBytes = await _audioService.stopRecording();

        setState(() {
          voiceAudio = audioBytes;
          _isLoading = false;
          _errorMessage = null;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Grabación completada')));
      } else {
        // Iniciar grabación
        await _audioService.startRecording();
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grabando... presiona nuevamente para detener'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error en grabación de audio: $e';
      });
    }
  }

  Future<void> _submitRegistration() async {
    // Cargar configuraciones de admin
    final settings = await _adminService.loadSettings();

    if (_nombresController.text.isEmpty ||
        _apellidosController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _identificadorController.text.isEmpty) {
      setState(() => _errorMessage = 'Por favor completa todos los campos');
      return;
    }

    // Verificar si se permiten múltiples registros
    if (!settings.allowMultipleRegistrations) {
      final existingUser = await _localDb.getUserByIdentifier(
        _identificadorController.text,
      );
      if (existingUser != null) {
        setState(() {
          _errorMessage =
              '❌ Este usuario ya está registrado. '
              'No se permiten múltiples registros.';
        });
        return;
      }
    }

    if (earPhotos.any((p) => p == null)) {
      setState(() => _errorMessage = 'Por favor captura las 3 fotos de oreja');
      return;
    }

    if (voiceAudio == null) {
      setState(() => _errorMessage = 'Por favor graba el audio de voz');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Verificar conectividad
      await _checkConnectivity();

      if (!_isOnline) {
        // Sin internet: guardar offline
        await _saveRegistrationOffline();
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✗ Sin internet. Registro guardado localmente.\n'
                'Se sincronizará cuando recuperes conexión.',
              ),
              duration: Duration(seconds: 4),
              backgroundColor: Colors.orange.shade700,
            ),
          );
          // Volver a login después de 2 segundos
          Future.delayed(Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => LoginScreen()),
              );
            }
          });
        }
        return;
      }

      // Con internet: registrar online
      // Registrar usuario
      await _authService.register(
        nombres: _nombresController.text,
        apellidos: _apellidosController.text,
        email: _emailController.text,
        identificadorUnico: _identificadorController.text,
      );

      // Guardar usuario en SQLite local DESPUÉS del registro exitoso
      await _localDb.insertUser(
        nombres: _nombresController.text,
        apellidos: _apellidosController.text,
        identificadorUnico: _identificadorController.text,
      );

      // Registrar fotos de oreja
      for (int i = 0; i < earPhotos.length; i++) {
        await _authService.registerEarPhoto(
          _identificadorController.text,
          earPhotos[i]!,
          i + 1,
        );
      }

      // Registrar audio de voz
      await _authService.registerVoiceAudio(
        _identificadorController.text,
        voiceAudio!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(' exitoso!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error en registro: $e';
      });
    }
  }

  /// Guardar registro de forma offline (SQLite)
  Future<void> _saveRegistrationOffline() async {
    try {
      // Insertar usuario en SQLite local primero
      await _localDb.insertUser(
        nombres: _nombresController.text,
        apellidos: _apellidosController.text,
        identificadorUnico: _identificadorController.text,
      );

      // Además de la cola offline general, insertar en cola_sincronizacion local
      await _localDb.insertToSyncQueue(1, 'usuario', 'insert', {
        'nombres': _nombresController.text,
        'apellidos': _apellidosController.text,
        'identificador_unico': _identificadorController.text,
        'correoElectronico': _emailController.text,
        'estado': 'activo',
      });

      // Guardar registro principal para sincronización (fallback en offline DB también)
      await _syncManager.saveDataForOfflineSync(
        endpoint: '/auth/register',
        data: {
          'nombres': _nombresController.text,
          'apellidos': _apellidosController.text,
          'correoElectronico': _emailController.text,
          'identificadorUnico': _identificadorController.text,
          'estado': 'activo',
        },
      );

      // Guardar fotos de oreja
      for (int i = 0; i < earPhotos.length; i++) {
        if (earPhotos[i] != null) {
          // Insertar en cola_sincronizacion para credencial
          await _localDb.insertToSyncQueue(1, 'credencial', 'insert', {
            'identificador_unico': _identificadorController.text,
            'numero': i + 1,
            'tipo_biometria': 'oreja',
            'template': earPhotos[i]!.toString(),
          });

          await _syncManager.saveDataForOfflineSync(
            endpoint: '/biometria/registrar-oreja',
            data: {
              'identificadorUnico': _identificadorController.text,
              'numero': i + 1,
            },
            photoBase64: earPhotos[i]!.toString(),
          );
        }
      }

      // Guardar audio de voz
      if (voiceAudio != null) {
        await _localDb.insertToSyncQueue(1, 'credencial', 'insert', {
          'identificador_unico': _identificadorController.text,
          'tipo_biometria': 'voz',
          'template_audio': voiceAudio!.toString(),
        });

        await _syncManager.saveDataForOfflineSync(
          endpoint: '/biometria/registrar-voz',
          data: {'identificadorUnico': _identificadorController.text},
          audioBase64: voiceAudio!.toString(),
        );
      }

      debugPrint(
        'Registro guardado offline para: ${_identificadorController.text}',
      );
    } catch (e) {
      debugPrint('Error guardando registro offline: $e');
      rethrow;
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
          ? const Center(child: CircularProgressIndicator())
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
                          onPressed: () => setState(() => _currentStep++),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Siguiente'),
                        ),
                      if (_currentStep == 2)
                        ElevatedButton.icon(
                          onPressed: _submitRegistration,
                          icon: const Icon(Icons.check),
                          label: const Text('Registrarse'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                    ],
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
        const SizedBox(height: 16),
        TextField(
          controller: _nombresController,
          decoration: InputDecoration(
            labelText: 'Nombres',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apellidosController,
          decoration: InputDecoration(
            labelText: 'Apellidos',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Correo Electrónico',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.email),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _identificadorController,
          decoration: InputDecoration(
            labelText: 'Identificador Único (ej: cédula)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.badge),
          ),
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
          'Paso 2: Captura 3 Fotos de tu Oreja',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Asegúrate de que la oreja sea visible y bien iluminada',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildPhotoCard(i),
          ),
      ],
    );
  }

  Widget _buildPhotoCard(int index) {
    final hasPhoto = earPhotos[index] != null;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (hasPhoto)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  earPhotos[index]!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.contain, // Cambiado de cover a contain
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
                    Text('Foto ${index + 1}'),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _captureEarPhoto(index + 1),
              icon: const Icon(Icons.camera),
              label: Text(hasPhoto ? 'Retomar foto' : 'Capturar foto'),
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
          'Paso 3: Graba tu Voz',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Presiona el botón para grabar. Habla claramente durante 5-10 segundos.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _audioService.isRecording
                      ? Colors.red.shade100
                      : Colors.blue.shade100,
                  border: Border.all(
                    color: _audioService.isRecording ? Colors.red : Colors.blue,
                    width: 3,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _recordVoice,
                    customBorder: const CircleBorder(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _audioService.isRecording ? Icons.stop : Icons.mic,
                          size: 48,
                          color: _audioService.isRecording
                              ? Colors.red
                              : Colors.blue,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _audioService.isRecording ? 'Grabando...' : 'Grabar',
                          style: TextStyle(
                            color: _audioService.isRecording
                                ? Colors.red
                                : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (voiceAudio != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      const Text('Audio grabado exitosamente'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
