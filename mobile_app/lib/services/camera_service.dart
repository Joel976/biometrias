import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;

  /// Inicializar cámaras disponibles
  Future<void> initializeCameras() async {
    if (_isInitialized) return;

    try {
      _cameras = await availableCameras();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error inicializando cámaras: $e');
      throw Exception('No se pudo inicializar las cámaras: $e');
    }
  }

  /// Obtener cámara frontal (para selfie/oreja)
  CameraDescription? getFrontCamera() {
    if (_cameras == null) return null;
    try {
      return _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
    } catch (e) {
      debugPrint('Cámara frontal no disponible');
      return null;
    }
  }

  /// Obtener cámara trasera (si es necesaria)
  CameraDescription? getRearCamera() {
    if (_cameras == null) return null;
    try {
      return _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
    } catch (e) {
      debugPrint('Cámara trasera no disponible');
      return null;
    }
  }

  /// Inicializar controlador de cámara
  Future<void> initializeCamera(CameraDescription camera) async {
    try {
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
    } catch (e) {
      debugPrint('Error inicializando CameraController: $e');
      throw Exception('No se pudo inicializar la cámara: $e');
    }
  }

  /// Obtener el controlador de cámara
  CameraController? get cameraController => _controller;

  /// Tomar foto
  Future<Uint8List> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Cámara no inicializada');
    }

    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();
      return bytes;
    } catch (e) {
      debugPrint('Error tomando foto: $e');
      throw Exception('Error al tomar foto: $e');
    }
  }

  /// Liberar recursos
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }

  /// Recortar la zona de la oreja (óvalo central)
  /// Extrae solo la región de interés para reducir tamaño y mejorar privacidad
  static Uint8List cropEarRegion(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      // Calcular dimensiones del óvalo (similar al overlay de la cámara)
      final centerX = image.width ~/ 2;
      final centerY = image.height ~/ 2;

      // Usar 55% del ancho y 45% del alto (como en EarGuidePainter)
      final ovalWidth = (image.width * 0.55).toInt();
      final ovalHeight = (image.height * 0.45).toInt();

      // Calcular área de recorte rectangular que contenga el óvalo
      final left = centerX - (ovalWidth ~/ 2);
      final top = centerY - (ovalHeight ~/ 2);
      final right = centerX + (ovalWidth ~/ 2);
      final bottom = centerY + (ovalHeight ~/ 2);

      // Asegurar que las coordenadas estén dentro de los límites
      final cropLeft = left.clamp(0, image.width);
      final cropTop = top.clamp(0, image.height);
      final cropWidth = (right - left).clamp(0, image.width - cropLeft);
      final cropHeight = (bottom - top).clamp(0, image.height - cropTop);

      // Recortar la imagen
      final cropped = img.copyCrop(
        image,
        x: cropLeft,
        y: cropTop,
        width: cropWidth,
        height: cropHeight,
      );

      // Redimensionar a tamaño estándar para optimizar almacenamiento
      final resized = img.copyResize(
        cropped,
        width: 300, // Tamaño estándar para orejas
        height: 400,
      );

      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    } catch (e) {
      debugPrint('Error recortando imagen: $e');
      // Si falla el recorte, devolver imagen original
      return imageBytes;
    }
  }

  /// Redimensionar imagen (opcional, para optimizar)
  static Uint8List resizeImage(
    Uint8List imageBytes,
    int maxWidth,
    int maxHeight,
  ) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    final resized = img.copyResize(image, width: maxWidth, height: maxHeight);

    return Uint8List.fromList(img.encodeJpg(resized));
  }
}
