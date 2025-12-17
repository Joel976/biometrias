import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AudioService {
  FlutterSoundRecorder? _recorder;
  String? _recordingPath;
  bool _isInitialized = false;

  /// Inicializar el grabador de audio
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error inicializando grabador: $e');
      throw Exception('No se pudo inicializar el grabador de audio: $e');
    }
  }

  /// Solicitar permisos de micrófono
  Future<bool> requestMicrophonePermission() async {
    // Flutter Sound maneja permisos internamente
    // Este es un placeholder para futuras integraciones con permission_handler
    return true;
  }

  /// Comenzar grabación de audio
  Future<void> startRecording() async {
    if (_recorder == null) {
      await initialize();
    }

    try {
      // Verificar permisos
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('Permiso de micrófono denegado');
      }

      // Generar nombre único para el archivo
      final tmpDir = await getTemporaryDirectory();
      _recordingPath =
          '${tmpDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      // Asegurar que el directorio existe
      final parentDir = Directory(tmpDir.path);
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }

      await _recorder!.startRecorder(
        toFile: _recordingPath,
        codec: Codec.pcm16WAV,
      );

      debugPrint('Grabación iniciada: $_recordingPath');
    } catch (e) {
      debugPrint('Error iniciando grabación: $e');
      throw Exception('Error al iniciar grabación: $e');
    }
  }

  /// Detener grabación y obtener bytes de audio
  Future<Uint8List> stopRecording() async {
    if (_recorder == null || !_recorder!.isRecording) {
      throw Exception('No hay grabación en proceso');
    }

    try {
      final path = await _recorder!.stopRecorder();
      debugPrint('Grabación detenida: $path');

      final actualPath = path ?? _recordingPath;
      if (actualPath == null) {
        throw Exception('No se pudo obtener archivo de grabación');
      }

      // Leer archivo y convertir a bytes
      final file = File(actualPath);
      if (!file.existsSync()) {
        throw Exception('Archivo de grabación no encontrado: $actualPath');
      }

      final bytes = await file.readAsBytes();

      // Opcional: eliminar archivo temporal
      try {
        await file.delete();
      } catch (_) {}

      return bytes;
    } catch (e) {
      debugPrint('Error deteniendo grabación: $e');
      throw Exception('Error al detener grabación: $e');
    }
  }

  /// Obtener duración de grabación actual (en milisegundos)
  int getRecordingDuration() {
    // Nota: FlutterSoundRecorder no expone directamente recordingTime
    // Esto es un placeholder; puedes implementar tu propio contador usando un Timer
    return 0;
  }

  /// Verificar si hay grabación activa
  bool get isRecording => _recorder?.isRecording ?? false;

  /// Liberar recursos
  Future<void> dispose() async {
    await _recorder?.closeRecorder();
    _recorder = null;
    _isInitialized = false;
  }
}
