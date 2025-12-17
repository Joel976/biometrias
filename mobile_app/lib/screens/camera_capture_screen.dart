import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Pantalla que abre la cámara (preview) y devuelve la foto tomada como bytes (Uint8List).
class CameraCaptureScreen extends StatefulWidget {
  /// Si se proporciona [preferredCamera], se usará esa cámara. Si no, se buscará la frontal.
  final CameraDescription? preferredCamera;

  const CameraCaptureScreen({Key? key, this.preferredCamera}) : super(key: key);

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isTaking = false;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        throw Exception('No hay cámaras disponibles');
      }

      CameraDescription? camera;

      // Si hay una cámara preferida, buscarla
      if (widget.preferredCamera != null) {
        camera = widget.preferredCamera;
        // Encontrar el índice de esta cámara
        _currentCameraIndex = _cameras.indexWhere(
          (c) => c.name == widget.preferredCamera!.name,
        );
        if (_currentCameraIndex == -1) _currentCameraIndex = 0;
      } else {
        // Por defecto, buscar cámara frontal
        try {
          _currentCameraIndex = _cameras.indexWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
          );
          if (_currentCameraIndex == -1) _currentCameraIndex = 0;
        } catch (_) {
          _currentCameraIndex = 0;
        }
      }

      camera = _cameras[_currentCameraIndex];

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inicializando cámara: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  /// Cambiar entre cámaras (frontal/trasera)
  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay otra cámara disponible'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isInitializing = true;
    });

    try {
      // Cambiar al siguiente índice
      _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;

      // Disponer del controlador anterior
      await _controller?.dispose();

      // Inicializar nueva cámara
      _controller = CameraController(
        _cameras[_currentCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cambiando cámara: $e')));
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _takePictureAndReturn() async {
    if (_controller == null || !_controller!.value.isInitialized || _isTaking)
      return;
    setState(() => _isTaking = true);
    try {
      final xfile = await _controller!.takePicture();
      final bytes = await xfile.readAsBytes();

      // Validar calidad de la imagen (brillo y enfoque)
      final validationResult = _validateImageQuality(bytes);

      if (!validationResult['isValid']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                validationResult['message'] ?? 'Imagen de baja calidad',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() => _isTaking = false);
        }
        return;
      }

      if (mounted) Navigator.of(context).pop<Uint8List>(bytes);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al tomar foto: $e')));
    } finally {
      if (mounted) setState(() => _isTaking = false);
    }
  }

  /// Validar calidad de imagen (brillo básico)
  Map<String, dynamic> _validateImageQuality(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return {'isValid': false, 'message': 'No se pudo procesar la imagen'};
      }

      // Calcular brillo promedio (0-255)
      int totalBrightness = 0;
      int pixelCount = 0;

      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          // Calcular luminosidad (aproximación rápida)
          final brightness = (pixel.r + pixel.g + pixel.b) / 3;
          totalBrightness += brightness.toInt();
          pixelCount++;
        }
      }

      final avgBrightness = totalBrightness / pixelCount;

      // Validar brillo
      if (avgBrightness < 40) {
        return {
          'isValid': false,
          'message': '⚠️ Imagen muy oscura. Mejora la iluminación.',
        };
      }
      if (avgBrightness > 240) {
        return {
          'isValid': false,
          'message': '⚠️ Imagen muy brillante. Reduce la luz directa.',
        };
      }

      // Validación exitosa
      return {'isValid': true, 'message': 'Imagen válida'};
    } catch (e) {
      // En caso de error, permitir la imagen (no bloquear el flujo)
      return {'isValid': true, 'message': 'Validación omitida'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isInitializing
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  // Previsualización de cámara que llena toda la pantalla
                  if (_controller != null && _controller!.value.isInitialized)
                    SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller!.value.previewSize!.height,
                          height: _controller!.value.previewSize!.width,
                          child: CameraPreview(_controller!),
                        ),
                      ),
                    ),

                  // Overlay con guía de oreja (óvalo vertical)
                  Center(
                    child: CustomPaint(
                      size: Size(
                        MediaQuery.of(context).size.width,
                        MediaQuery.of(context).size.height,
                      ),
                      painter: EarGuidePainter(),
                    ),
                  ),

                  // Instrucciones
                  Positioned(
                    top: 60,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '📸 Coloca tu oreja dentro del óvalo\n💡 Asegúrate de buena iluminación',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_cameras.length > 1) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _cameras[_currentCameraIndex].lensDirection ==
                                          CameraLensDirection.front
                                      ? Icons.camera_front
                                      : Icons.camera_rear,
                                  color: Colors.greenAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _cameras[_currentCameraIndex].lensDirection ==
                                          CameraLensDirection.front
                                      ? 'Cámara Frontal'
                                      : 'Cámara Trasera',
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    left: 12,
                    top: 12,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  // Botón para voltear cámara
                  if (_cameras.length > 1)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _switchCamera,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.greenAccent.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.flip_camera_android,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),

                  Positioned(
                    bottom: 32,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _isTaking ? null : _takePictureAndReturn,
                          child: Container(
                            width: 78,
                            height: 78,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Center(
                              child: _isTaking
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Container(
                                      width: 54,
                                      height: 54,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// CustomPainter para dibujar el overlay de guía de oreja (óvalo vertical)
class EarGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Definir óvalo vertical en el centro (para oreja)
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final ovalWidth = size.width * 0.55; // 55% del ancho (un poco más grande)
    final ovalHeight = size.height * 0.45; // 45% del alto (un poco más grande)

    final ovalRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: ovalWidth,
      height: ovalHeight,
    );

    // Dibujar fondo oscuro semi-transparente fuera del óvalo
    final outerPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, outerPaint);

    // Dibujar borde del óvalo con efecto de brillo
    final ovalPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawOval(ovalRect, ovalPaint);

    // Agregar líneas de guía en las 4 esquinas del óvalo
    final cornerPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final cornerLength = 30.0;

    // Esquina superior izquierda
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.top + cornerLength),
      Offset(ovalRect.left, ovalRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.top),
      Offset(ovalRect.left + cornerLength, ovalRect.top),
      cornerPaint,
    );

    // Esquina superior derecha
    canvas.drawLine(
      Offset(ovalRect.right - cornerLength, ovalRect.top),
      Offset(ovalRect.right, ovalRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.right, ovalRect.top),
      Offset(ovalRect.right, ovalRect.top + cornerLength),
      cornerPaint,
    );

    // Esquina inferior izquierda
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.bottom - cornerLength),
      Offset(ovalRect.left, ovalRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.bottom),
      Offset(ovalRect.left + cornerLength, ovalRect.bottom),
      cornerPaint,
    );

    // Esquina inferior derecha
    canvas.drawLine(
      Offset(ovalRect.right - cornerLength, ovalRect.bottom),
      Offset(ovalRect.right, ovalRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.right, ovalRect.bottom - cornerLength),
      Offset(ovalRect.right, ovalRect.bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
