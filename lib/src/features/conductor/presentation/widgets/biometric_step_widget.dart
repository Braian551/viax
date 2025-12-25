import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'dart:io';
import 'dart:async';

// Enum for Liveness Steps
enum LivenessStep {
  centerFace,
  turnRight,
  turnLeft,
  smile,
  completed,
}

class BiometricStepWidget extends StatefulWidget {
  final Function(File) onVerificationComplete;
  final bool isDark;

  const BiometricStepWidget({
    super.key, 
    required this.onVerificationComplete,
    required this.isDark,
  });

  @override
  State<BiometricStepWidget> createState() => _BiometricStepWidgetState();
}

class _BiometricStepWidgetState extends State<BiometricStepWidget> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String? _errorMessage;
  
  // ML Kit
  late final FaceDetector _faceDetector;
  
  // State
  LivenessStep _currentStep = LivenessStep.centerFace;
  String _instructionText = "Centra tu rostro";
  IconData _instructionIcon = Icons.face;
  double _progress = 0.0;
  
  int _consecutiveSuccessFrames = 0;
  final int _requiredSuccessFrames = 3; // Faster interaction

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    
    // Low latency mode, tracking enabled
    final options = FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast, 
    );
    _faceDetector = FaceDetector(options: options);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-initialize camera on resume if needed (simplified for now)
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied) {
      if (mounted) setState(() => _errorMessage = "Permiso de cámara denegado.");
      return;
    }

    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium, // Medium is enough for liveness
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      
      if (!mounted) return;

      _controller!.startImageStream(_processImage);
      
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error al iniciar cámara: $e");
    }
  }

  Future<void> _processImage(CameraImage image) async {
    if (_isProcessing || _currentStep == LivenessStep.completed) return;
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      
      if (faces.isEmpty) {
        if (mounted) {
          setState(() {
             // Reset slightly if face lost
            _consecutiveSuccessFrames = 0;
          });
        }
      } else {
        _validateLiveness(faces.first);
      }
    } catch (e) {
      print("Error processing face: $e");
    } finally {
      _isProcessing = false;
    }
  }

  void _validateLiveness(Face face) {
    bool stepSuccess = false;
    String nextInstruction = _instructionText;
    IconData nextIcon = _instructionIcon;

    switch (_currentStep) {
      case LivenessStep.centerFace:
        final rotY = face.headEulerAngleY ?? 0;
        final rotZ = face.headEulerAngleZ ?? 0;
        
        if (rotY.abs() < 12 && rotZ.abs() < 12) {
          stepSuccess = true;
          nextInstruction = "Gira lentamente a la DERECHA";
          nextIcon = Icons.turn_right_rounded;
        } else {
           nextInstruction = "Mira de frente";
           nextIcon = Icons.face;
        }
        break;

      case LivenessStep.turnRight:
         final rotY = face.headEulerAngleY ?? 0;
         // Android front cam mirror issue: sometimes Left is positive, Right is negative
         if (rotY.abs() > 15) { // Just check for significant turn
           stepSuccess = true;
           nextInstruction = "Ahora gira a la IZQUIERDA";
           nextIcon = Icons.turn_left_rounded;
         }
         break;
         
       case LivenessStep.turnLeft:
          final rotY = face.headEulerAngleY ?? 0;
          if (rotY.abs() > 15) {
             stepSuccess = true;
             nextInstruction = "¡Sonríe!";
             nextIcon = Icons.sentiment_satisfied_rounded;
          }
         break;

       case LivenessStep.smile:
         final smileProb = face.smilingProbability ?? 0;
         if (smileProb > 0.3) { // Low threshold for easier passing
           stepSuccess = true;
           nextInstruction = "¡Validado!";
           nextIcon = Icons.check_circle_rounded;
         }
         break;
         
       case LivenessStep.completed:
         break;
    }

    if (!mounted) return;

    if (stepSuccess) {
      _consecutiveSuccessFrames++;
      setState(() {
        _progress = (_currentStep.index + (_consecutiveSuccessFrames / _requiredSuccessFrames)) / 4.0;
        
         if (_consecutiveSuccessFrames >= _requiredSuccessFrames) {
             // Move to next step
             if (_currentStep == LivenessStep.centerFace) {
               _currentStep = LivenessStep.turnRight;
             } else if (_currentStep == LivenessStep.turnRight) {
               _currentStep = LivenessStep.turnLeft;
             } else if (_currentStep == LivenessStep.turnLeft) {
               _currentStep = LivenessStep.smile;
             } else if (_currentStep == LivenessStep.smile) {
               _completeVerification();
               return; // Stop update
             }
             
             _instructionText = nextInstruction;
             _instructionIcon = nextIcon;
             _consecutiveSuccessFrames = 0;
         }
      });
    }
  }

  Future<void> _completeVerification() async {
    if (_currentStep == LivenessStep.completed) return;
    
    setState(() {
      _currentStep = LivenessStep.completed;
      _instructionText = "Verificación Exitosa";
      _instructionIcon = Icons.check_circle;
      _progress = 1.0;
    });

    try {
      await _controller!.stopImageStream();
      await Future.delayed(const Duration(milliseconds: 200));
      final XFile image = await _controller!.takePicture();
      widget.onVerificationComplete(File(image.path));
    } catch (e) {
      print("Error capturing image: $e");
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;
    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }
  
  static final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red)));
    }

    if (!_isCameraInitialized || _controller == null) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    // Explicitly handle aspect ratio to "COVER" the 280x280 circle
    final size = MediaQuery.of(context).size;
    // Calculate scale to ensure the camera preview covers the circle completely
    // CameraPreview preserves aspect ratio. We scale it up.
    var scale = 1.0;
    if (_controller!.value.aspectRatio < 1) {
       // Portrait aspect ratio (e.g. 9/16)
       scale = 1 / _controller!.value.aspectRatio; 
    } else {
       // Landscape aspect ratio (shouldn't happen often for front cam in portrait app, but safety)
       scale = _controller!.value.aspectRatio;
    }


    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Camera Circle with Scanner Effect
         Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _currentStep == LivenessStep.completed ? Colors.green : AppColors.primary,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 25,
                spreadRadius: 5,
              )
            ],
          ),
          // IMPORTANT: ClipOval here to clip BOTH Camera and Scanner Overlay
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Camera Preview (Scaled to Cover)
                Transform.scale(
                  scale: scale * 1.2, // Slight extra zoom to avoid any edges
                  child: Center(
                    child: CameraPreview(_controller!),
                  ),
                ),
                
                // 2. Scanner Animation Overlay (Now clipped inside circle)
                if (_currentStep != LivenessStep.completed)
                  _ScannerOverlay(),
                  
                // 3. Success Overlay
                if (_currentStep == LivenessStep.completed)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 80),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 30),
        
        // Dynamic Instruction Card
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: Offset(0, 0.2), end: Offset.zero).animate(anim), child: child)),
          child: Container(
            key: ValueKey(_instructionText),
            margin: const EdgeInsets.symmetric(horizontal: 20), // Prevent edge touching
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.grey.shade900.withOpacity(0.9) : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Prevent height overflow
              children: [
                Icon(_instructionIcon, size: 48, color: AppColors.primary),
                const SizedBox(height: 12),
                Flexible( // Handle long text
                  child: Text(
                    _instructionText,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Modern Segmented Progress Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
             double threshold = (index + 1) / 4.0;
             bool active = _progress >= (index / 4.0);
             bool completed = _progress >= threshold;
             
             return AnimatedContainer(
               duration: const Duration(milliseconds: 300),
               margin: const EdgeInsets.symmetric(horizontal: 4),
               height: 6,
               width: completed ? 20 : (active ? 40 : 12),
               decoration: BoxDecoration(
                 color: completed ? Colors.green : (active ? AppColors.primary : Colors.grey.withOpacity(0.3)),
                 borderRadius: BorderRadius.circular(3),
               ),
             );
          }),
        ),
      ],
    );
  }
}

class _ScannerOverlay extends StatefulWidget {
  @override
  __ScannerOverlayState createState() => __ScannerOverlayState();
}

class __ScannerOverlayState extends State<_ScannerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
         return CustomPaint(
           painter: _ScannerPainter(_controller.value),
         );
      },
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final double value;
  _ScannerPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final y = value * size.height;
    
    // Draw scanning line
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    
    // Draw gradient glow
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.primary.withOpacity(0.0), AppColors.primary.withOpacity(0.3)],
    );
    
    final rect = Rect.fromLTWH(0, y - 40, size.width, 40);
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}