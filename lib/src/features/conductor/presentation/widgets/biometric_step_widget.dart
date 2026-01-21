import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/features/conductor/presentation/widgets/components/scanner_overlay.dart';
import 'package:viax/src/features/conductor/presentation/widgets/components/biometric_instruction_card.dart';
import 'package:viax/src/features/conductor/presentation/widgets/components/biometric_progress_bar.dart';
import 'dart:io';
import 'dart:async';

// Simplified verification steps (no ML Kit required)
enum VerificationStep { ready, countdown, capturing, completed }

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

class _BiometricStepWidgetState extends State<BiometricStepWidget>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  String? _errorMessage;

  // State
  VerificationStep _currentStep = VerificationStep.ready;
  String _instructionText = "Centra tu rostro en el círculo";
  IconData _instructionIcon = Icons.face;
  double _progress = 0.0;

  // Countdown
  int _countdownValue = 3;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied) {
      if (mounted) {
        setState(() => _errorMessage = "Permiso de cámara denegado.");
      }
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
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = "Error al iniciar cámara: $e");
      }
    }
  }

  void _startCapture() {
    if (_currentStep != VerificationStep.ready) return;

    setState(() {
      _currentStep = VerificationStep.countdown;
      _countdownValue = 3;
      _instructionText = "Prepárate...";
      _instructionIcon = Icons.timer;
      _progress = 0.25;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdownValue--;
        _progress = 0.25 + (0.5 * (3 - _countdownValue) / 3);

        if (_countdownValue <= 0) {
          timer.cancel();
          _capturePhoto();
        } else {
          _instructionText = "$_countdownValue...";
        }
      });
    });
  }

  Future<void> _capturePhoto() async {
    setState(() {
      _currentStep = VerificationStep.capturing;
      _instructionText = "Capturando...";
      _instructionIcon = Icons.camera_alt;
      _progress = 0.75;
    });

    try {
      final XFile image = await _controller!.takePicture();

      setState(() {
        _currentStep = VerificationStep.completed;
        _instructionText = "¡Foto capturada!";
        _instructionIcon = Icons.check_circle;
        _progress = 1.0;
      });

      // Small delay to show success state
      await Future.delayed(const Duration(milliseconds: 500));

      widget.onVerificationComplete(File(image.path));
    } catch (e) {
      print("Error capturing image: $e");
      setState(() {
        _currentStep = VerificationStep.ready;
        _instructionText = "Error al capturar. Intenta de nuevo.";
        _instructionIcon = Icons.error_outline;
        _progress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => _errorMessage = null);
                _initializeCamera();
              },
              child: const Text("Reintentar"),
            ),
          ],
        ),
      );
    }

    if (!_isCameraInitialized || _controller == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              "Iniciando cámara...",
              style: TextStyle(
                color: widget.isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    // Calculate scale to ensure the camera preview covers the circle
    var scale = 1.0;
    if (_controller!.value.aspectRatio < 1) {
      scale = 1 / _controller!.value.aspectRatio;
    } else {
      scale = _controller!.value.aspectRatio;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Camera Circle with Scanner Effect
        GestureDetector(
          onTap: _currentStep == VerificationStep.ready ? _startCapture : null,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _getBorderColor(), width: 4),
              boxShadow: [
                BoxShadow(
                  color: _getBorderColor().withOpacity(0.3),
                  blurRadius: 25,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Camera Preview (Scaled to Cover)
                  Transform.scale(
                    scale: scale * 1.2,
                    child: Center(child: CameraPreview(_controller!)),
                  ),

                  // 2. Scanner Animation Overlay
                  if (_currentStep == VerificationStep.countdown)
                    const ScannerOverlay(),

                  // 3. Countdown Overlay
                  if (_currentStep == VerificationStep.countdown &&
                      _countdownValue > 0)
                    Container(
                      color: Colors.black38,
                      child: Center(
                        child: Text(
                          "$_countdownValue",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // 4. Success Overlay
                  if (_currentStep == VerificationStep.completed)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.greenAccent,
                          size: 80,
                        ),
                      ),
                    ),

                  // 5. Tap to start hint
                  if (_currentStep == VerificationStep.ready)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Toca para capturar",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 30),

        // Dynamic Instruction Card
        BiometricInstructionCard(
          text: _instructionText,
          icon: _instructionIcon,
          isDark: widget.isDark,
        ),

        const SizedBox(height: 24),

        // Progress Bar
        BiometricProgressBar(progress: _progress),

        const SizedBox(height: 24),

        // Action Buttons
        if (_currentStep == VerificationStep.ready)
          ElevatedButton.icon(
            onPressed: _startCapture,
            icon: const Icon(Icons.camera_alt),
            label: const Text("Tomar Selfie"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
      ],
    );
  }

  Color _getBorderColor() {
    switch (_currentStep) {
      case VerificationStep.ready:
        return AppColors.primary;
      case VerificationStep.countdown:
        return Colors.orange;
      case VerificationStep.capturing:
        return Colors.blue;
      case VerificationStep.completed:
        return Colors.green;
    }
  }
}
