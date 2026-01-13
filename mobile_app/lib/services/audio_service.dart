import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart'; // ✅ Usar paquete 'record' para grabar
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AudioService {
  AudioRecorder? _recorder; // ✅ Cambio a AudioRecorder del paquete 'record'
  FlutterSoundPlayer? _player; // ✅ Mantener FlutterSound solo para reproducción
  String? _recordingPath;
  bool _isInitialized = false;
  DateTime? _recordingStartTime;
  double _lastRecordingDuration = 0.0;

  /// Inicializar el servicio de audio
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _recorder = AudioRecorder(); // ✅ Inicializar AudioRecorder

      _player = FlutterSoundPlayer();
      await _player!.openPlayer();

      _isInitialized = true;
      debugPrint(
        '✅ AudioService inicializado correctamente (record + flutter_sound)',
      );
    } catch (e) {
      debugPrint('❌ Error inicializando AudioService: $e');
      throw Exception('No se pudo inicializar el servicio de audio: $e');
    }
  }

  /// Solicitar permisos de micrófono
  Future<bool> requestMicrophonePermission() async {
    debugPrint('🔍 [AudioService] Verificando permiso de micrófono...');

    final status = await Permission.microphone.status;
    debugPrint('🔍 [AudioService] Estado actual: $status');

    if (status.isGranted) {
      debugPrint('✅ [AudioService] Permiso ya concedido');
      return true;
    }

    if (status.isDenied || status.isPermanentlyDenied) {
      debugPrint('⚠️ [AudioService] Solicitando permiso...');
      final result = await Permission.microphone.request();
      debugPrint('📋 [AudioService] Resultado: $result');
      return result.isGranted;
    }

    return false;
  }

  /// Comenzar grabación de audio usando 'record'
  Future<void> startRecording() async {
    if (_recorder == null) {
      await initialize();
    }

    try {
      // Verificar permisos
      final micStatus = await Permission.microphone.status;

      if (!micStatus.isGranted) {
        debugPrint('⚠️ [AudioService] Solicitando permiso de micrófono...');
        final result = await Permission.microphone.request();

        if (!result.isGranted) {
          debugPrint('❌ [AudioService] Permiso de micrófono denegado');
          throw Exception('Permiso de micrófono denegado');
        }
      }

      // Generar nombre único para el archivo
      final tmpDir = await getTemporaryDirectory();
      _recordingPath =
          '${tmpDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      debugPrint('🎤 [AudioService] Iniciando grabación...');

      // Configuración para WAV PCM16
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          bitRate: 128000,
          numChannels: 1,
        ),
        path: _recordingPath!,
      );

      _recordingStartTime = DateTime.now();
      debugPrint('✅ [AudioService] Grabación iniciada');
    } catch (e) {
      debugPrint('❌ [AudioService] Error: $e');
      rethrow;
    }
  }

  /// Detener grabación y obtener bytes de audio en WAV usando 'record'
  Future<Uint8List> stopRecording() async {
    if (_recorder == null) {
      debugPrint('⚠️ [AudioService] Recorder no inicializado');
      throw Exception('Recorder no inicializado');
    }

    try {
      debugPrint('⏹️ [AudioService] Deteniendo grabación...');

      // Calcular duración antes de detener
      if (_recordingStartTime != null) {
        final duration = DateTime.now().difference(_recordingStartTime!);
        _lastRecordingDuration = duration.inMilliseconds / 1000.0;
        debugPrint(
          '⏹️ [AudioService] Duración: ${_lastRecordingDuration.toStringAsFixed(1)}s',
        );
      }

      // Detener grabación
      final path = await _recorder!.stop();
      debugPrint('⏹️ [AudioService] Path: $path');

      if (path == null) {
        throw Exception('No se pudo obtener archivo de grabación');
      }

      // Leer archivo y convertir a bytes
      final file = File(path);
      if (!file.existsSync()) {
        throw Exception('Archivo de grabación no encontrado: $path');
      }

      final bytes = await file.readAsBytes();
      debugPrint('✅ [AudioService] Audio grabado: ${bytes.length} bytes');

      // Eliminar archivo temporal
      try {
        await file.delete();
      } catch (e) {
        debugPrint('⚠️ [AudioService] No se pudo eliminar archivo: $e');
      }

      return bytes;
    } catch (e) {
      debugPrint('❌ [AudioService] Error: $e');
      rethrow;
    }
  }

  /// Obtener duración de grabación actual (en segundos)
  Future<double> getRecordingDuration() async {
    if (_recordingStartTime == null || _recorder == null) {
      return 0.0;
    }

    final isCurrentlyRecording = await _recorder!.isRecording();
    if (!isCurrentlyRecording) {
      return 0.0;
    }

    final duration = DateTime.now().difference(_recordingStartTime!);
    return duration.inMilliseconds / 1000.0;
  }

  /// Obtener duración de la última grabación (en segundos)
  double getLastRecordingDuration() {
    return _lastRecordingDuration;
  }

  /// Reproducir audio desde bytes
  Future<void> playAudioFromBytes(Uint8List audioBytes) async {
    try {
      // ✅ IMPORTANTE: Reinicializar el player para evitar estados inconsistentes
      if (_player != null) {
        debugPrint('🔊 [AudioService] Cerrando player existente...');
        try {
          if (_player!.isPlaying) {
            await _player!.stopPlayer();
          }
          await _player!.closePlayer();
        } catch (e) {
          debugPrint('🔊 [AudioService] ⚠️ Error cerrando player: $e');
        }
        _player = null;
      }

      // Reinicializar player
      debugPrint('🔊 [AudioService] Reinicializando player...');
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();

      debugPrint('🔊 [AudioService] Iniciando reproducción...');
      debugPrint('🔊 [AudioService] Bytes recibidos: ${audioBytes.length}');

      // Guardar bytes en archivo temporal
      final tmpDir = await getTemporaryDirectory();
      final tmpPath =
          '${tmpDir.path}/temp_playback_${DateTime.now().millisecondsSinceEpoch}.wav';
      final file = File(tmpPath);
      await file.writeAsBytes(audioBytes);

      final fileSize = await file.length();
      debugPrint('🔊 [AudioService] Archivo creado: $tmpPath');
      debugPrint('🔊 [AudioService] Tamaño archivo: $fileSize bytes');

      // ✅ Configurar volumen al máximo
      await _player!.setVolume(1.0);
      debugPrint('🔊 [AudioService] Volumen configurado: 1.0');

      // ✅ Reproducir SIN especificar codec (auto-detección)
      debugPrint('🔊 [AudioService] Iniciando reproducción desde archivo...');
      await _player!.startPlayer(
        fromURI: tmpPath,
        // NO especificar codec - dejar que Flutter Sound lo detecte automáticamente
        whenFinished: () {
          debugPrint('🔊 [AudioService] ✅ Reproducción finalizada');
          // Limpiar archivo temporal
          try {
            file.deleteSync();
            debugPrint('🔊 [AudioService] Archivo temporal eliminado');
          } catch (e) {
            debugPrint('🔊 [AudioService] ⚠️ Error eliminando archivo: $e');
          }
        },
      );

      debugPrint('🔊 [AudioService] ▶️ Reproducción iniciada correctamente');
    } catch (e) {
      debugPrint('🔊 [AudioService] ❌ Error reproduciendo audio: $e');
      rethrow;
    }
  }

  /// Detener reproducción
  Future<void> stopPlayer() async {
    if (_player != null && _player!.isPlaying) {
      await _player!.stopPlayer();
      debugPrint('Reproducción detenida');
    }
  }

  /// Verificar si se está reproduciendo audio
  bool get isPlaying => _player?.isPlaying ?? false;

  /// Verificar si hay grabación activa (usando 'record')
  Future<bool> get isRecording async {
    if (_recorder == null) return false;
    return await _recorder!.isRecording();
  }

  /// Liberar recursos
  Future<void> dispose() async {
    await stopPlayer();
    await _player?.closePlayer();

    // Detener grabación si está activa (usando 'record')
    if (_recorder != null) {
      try {
        if (await _recorder!.isRecording()) {
          await _recorder!.stop();
        }
        await _recorder!.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing recorder: $e');
      }
    }

    _player = null;
    _recorder = null;
    _isInitialized = false;
  }
}
