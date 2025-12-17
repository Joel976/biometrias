import 'package:record/record.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SimpleAudioService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;
  bool _isInitialized = false;

  /// Inicializar el grabador de audio
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Verificar permisos
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw Exception('Permiso de micrófono denegado');
      }

      _isInitialized = true;
      debugPrint('AudioRecorder inicializado correctamente');
    } catch (e) {
      debugPrint('Error inicializando AudioRecorder: $e');
      throw Exception('No se pudo inicializar el grabador de audio: $e');
    }
  }

  /// Comenzar grabación de audio
  Future<void> startRecording() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Obtener directorio temporal
      final tempDir = await getTemporaryDirectory();
      _recordingPath =
          '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      // Iniciar grabación
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 16000,
        ),
        path: _recordingPath!,
      );

      debugPrint('Grabación iniciada: $_recordingPath');
    } catch (e) {
      debugPrint('Error iniciando grabación: $e');
      throw Exception('Error al iniciar grabación: $e');
    }
  }

  /// Detener grabación y obtener bytes de audio
  Future<Uint8List> stopRecording() async {
    if (!_isInitialized) {
      throw Exception('AudioRecorder no inicializado');
    }

    try {
      final path = await _recorder.stop();
      debugPrint('Grabación detenida: $path');

      if (path == null) {
        throw Exception('No se pudo obtener archivo de grabación');
      }

      // Leer archivo y convertir a bytes
      final file = File(path);
      if (!file.existsSync()) {
        throw Exception('Archivo de grabación no existe');
      }

      final bytes = await file.readAsBytes();

      // Opcional: eliminar archivo temporal
      try {
        await file.delete();
      } catch (e) {
        debugPrint('No se pudo eliminar archivo temporal: $e');
      }

      return bytes;
    } catch (e) {
      debugPrint('Error deteniendo grabación: $e');
      throw Exception('Error al detener grabación: $e');
    }
  }

  /// Verificar si hay grabación activa
  Future<bool> get isRecording async {
    try {
      final state = await _recorder.isRecording();
      return state;
    } catch (e) {
      debugPrint('Error verificando estado: $e');
      return false;
    }
  }

  /// Liberar recursos
  Future<void> dispose() async {
    try {
      await _recorder.dispose();
      _isInitialized = false;
    } catch (e) {
      debugPrint('Error liberando recursos: $e');
    }
  }
}
