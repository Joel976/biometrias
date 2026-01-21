import 'package:flutter/material.dart';
import '../services/hybrid_auth_service.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Ejemplo de pantalla de login usando HybridAuthService
/// Funciona tanto ONLINE como OFFLINE
class LoginHibridoScreen extends StatefulWidget {
  const LoginHibridoScreen({Key? key}) : super(key: key);

  @override
  State<LoginHibridoScreen> createState() => _LoginHibridoScreenState();
}

class _LoginHibridoScreenState extends State<LoginHibridoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hybridAuth = HybridAuthService();
  final _audioRecorder = AudioRecorder();

  // Controllers
  final _identificadorController = TextEditingController();

  bool _isLoading = false;
  bool _isRecording = false;
  bool _isInitialized = false;
  String? _audioPath;

  Map<String, dynamic>? _serviceInfo;
  Map<String, dynamic>? _syncStatus;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    setState(() => _isLoading = true);

    try {
      final success = await _hybridAuth.initialize();
      if (success) {
        final info = _hybridAuth.getServiceInfo();
        final syncStatus = await _hybridAuth.getSyncStatus();

        setState(() {
          _isInitialized = true;
          _serviceInfo = info;
          _syncStatus = syncStatus;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Servicio inicializado (${info['is_online'] ? "ONLINE" : "OFFLINE"})',
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Mostrar advertencia si hay datos pendientes de sincronizar
          if (syncStatus['pending_count'] > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '⚠️ Hay ${syncStatus['pending_count']} registros pendientes de sincronizar',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Error inicializando servicio'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sincronizarDatos() async {
    setState(() => _isLoading = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔄 Sincronizando datos...'),
          duration: Duration(seconds: 2),
        ),
      );

      final result = await _hybridAuth.syncPendingData();

      if (!mounted) return;

      if (result['success'] == true) {
        final synced = result['synced'] ?? 0;
        final failed = result['failed'] ?? 0;
        final pending = result['pending'] ?? 0;

        // Actualizar estado de sincronización
        final syncStatus = await _hybridAuth.getSyncStatus();
        setState(() => _syncStatus = syncStatus);

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ Sincronización Completada'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Sincronizados: $synced'),
                Text('❌ Fallidos: $failed'),
                Text('⏳ Pendientes: $pending'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error en sincronización: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final audioPath =
            '${tempDir.path}/login_${DateTime.now().millisecondsSinceEpoch}.wav';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: audioPath,
        );

        setState(() {
          _isRecording = true;
          _audioPath = audioPath;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎤 Grabando... Di la frase mostrada'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al iniciar grabación: $e')));
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
        _audioPath = path;
      });

      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Audio grabado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al detener grabación: $e')));
    }
  }

  Future<void> _autenticarUsuario() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_audioPath == null || !File(_audioPath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Debes grabar un audio primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _hybridAuth.authenticate(
        identificador: _identificadorController.text,
        audioPath: _audioPath!,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final authenticated = result['authenticated'] == true;
        final mode = result['mode'] ?? 'unknown';
        final confidence = result['confidence'] ?? 0.0;

        if (authenticated) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 32),
                  SizedBox(width: 12),
                  Text('✅ Autenticación Exitosa'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Usuario: ${_identificadorController.text}'),
                  const SizedBox(height: 8),
                  Text(
                    'Modo: ${mode == "online" ? "🌐 ONLINE" : "📱 OFFLINE"}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: mode == "online" ? Colors.green : Colors.orange,
                    ),
                  ),
                  Text('Confianza: ${(confidence * 100).toStringAsFixed(1)}%'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Navegar a pantalla principal
                    // Navigator.pushReplacementNamed(context, '/home');
                  },
                  child: const Text('Continuar'),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.cancel, color: Colors.red, size: 32),
                  SizedBox(width: 12),
                  Text('❌ Autenticación Rechazada'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('La voz no coincide con el usuario registrado.'),
                  const SizedBox(height: 8),
                  Text('Confianza: ${(confidence * 100).toStringAsFixed(1)}%'),
                  const SizedBox(height: 8),
                  const Text(
                    'Por favor, intenta nuevamente.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${result['error'] ?? "Error desconocido"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al autenticar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Biométrico'),
        actions: [
          if (_serviceInfo != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Chip(
                label: Text(
                  _serviceInfo!['is_online'] == true
                      ? '🌐 ONLINE'
                      : '📱 OFFLINE',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: _serviceInfo!['is_online'] == true
                    ? Colors.green.withOpacity(0.3)
                    : Colors.orange.withOpacity(0.3),
              ),
            ),
          // Botón de sincronización
          if (_syncStatus != null && _syncStatus!['pending_count'] > 0)
            IconButton(
              icon: Badge(
                label: Text('${_syncStatus!['pending_count']}'),
                child: const Icon(Icons.sync),
              ),
              onPressed: _isLoading ? null : _sincronizarDatos,
              tooltip: 'Sincronizar datos pendientes',
            ),
        ],
      ),
      body: _isLoading && !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo o título
                    const Icon(Icons.fingerprint, size: 80, color: Colors.blue),
                    const SizedBox(height: 16),
                    Text(
                      'Autenticación Biométrica',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 32),

                    // Info del servicio
                    if (_serviceInfo != null) ...[
                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _serviceInfo!['is_online'] == true
                                        ? Icons.cloud_done
                                        : Icons.cloud_off,
                                    color: _serviceInfo!['is_online'] == true
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _serviceInfo!['is_online'] == true
                                        ? 'Conectado al servidor'
                                        : 'Modo offline',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Versión: ${_serviceInfo!['native_version']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Formulario
                    TextFormField(
                      controller: _identificadorController,
                      decoration: const InputDecoration(
                        labelText: 'Identificador/Cédula',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Campo requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Sección de audio
                    Card(
                      color: Colors.purple.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verificación por Voz',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),

                            const Text(
                              'Graba tu voz para autenticarte',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isRecording
                                        ? _stopRecording
                                        : _startRecording,
                                    icon: Icon(
                                      _isRecording ? Icons.stop : Icons.mic,
                                    ),
                                    label: Text(
                                      _isRecording ? 'Detener' : 'Grabar Audio',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.all(16),
                                      backgroundColor: _isRecording
                                          ? Colors.red
                                          : Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (_audioPath != null && !_isRecording) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Audio grabado correctamente',
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botón de login
                    ElevatedButton(
                      onPressed: _isLoading ? null : _autenticarUsuario,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(18),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Iniciar Sesión',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),

                    const SizedBox(height: 16),

                    // Botón de registro
                    TextButton(
                      onPressed: () {
                        // Navigator.pushNamed(context, '/registro');
                      },
                      child: const Text('¿No tienes cuenta? Regístrate aquí'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _identificadorController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }
}
