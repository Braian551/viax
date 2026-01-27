// lib/src/features/auth/presentation/screens/password_recovery_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:viax/src/global/services/email_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/widgets/entrance_fader.dart';
import 'package:viax/src/widgets/dialogs/dialog_helper.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'dart:async';

/// Pantalla de verificación de código para recuperación de contraseña
/// Reutiliza la lógica visual de EmailVerificationScreen con mensajes adaptados
class PasswordRecoveryVerificationScreen extends StatefulWidget {
  final String email;
  final String userName;

  const PasswordRecoveryVerificationScreen({
    super.key,
    required this.email,
    required this.userName,
  });

  @override
  State<PasswordRecoveryVerificationScreen> createState() => _PasswordRecoveryVerificationScreenState();
}

class _PasswordRecoveryVerificationScreenState extends State<PasswordRecoveryVerificationScreen>
    with TickerProviderStateMixin {
  late final List<TextEditingController> _digitControllers;
  late final List<FocusNode> _focusNodes;
  String _verificationCode = '';
  bool _isLoading = false;
  bool _isResending = false;
  bool _isVerifying = false;
  bool _isProgrammaticFill = false;
  late List<String> _previousValues;
  int _resendCountdown = 60;
  Timer? _countdownTimer;
  bool _isDisposed = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late List<AnimationController> _pinControllers;
  late List<Animation<double>> _pinAnimations;

  @override
  void initState() {
    super.initState();
    _digitControllers = List.generate(4, (_) => TextEditingController());
    _focusNodes = List.generate(4, (_) => FocusNode());
    _previousValues = List.filled(4, '');

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _pinControllers = List.generate(4, (index) => AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    ));

    _pinAnimations = _pinControllers.map((controller) => Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic))).toList();

    _animationController.forward();
    _sendRecoveryCode();
    _startResendCountdown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _focusNodes.first.requestFocus();
      }
    });
  }

  void _triggerPinPulse(int index) {
    if (index >= 0 && index < _pinControllers.length) {
      final controller = _pinControllers[index];
      controller.stop();
      controller.forward(from: 0.0).then((_) {
        if (mounted && !_isDisposed) {
          controller.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _countdownTimer?.cancel();
    _animationController.dispose();
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (final controller in _digitControllers) {
      controller.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendCountdown() {
    _countdownTimer?.cancel();
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isDisposed) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendRecoveryCode() async {
    if (!mounted || _isDisposed) return;
    
    setState(() => _isLoading = true);
    
    try {
      _verificationCode = EmailService.generateVerificationCode();
      
      bool success = await EmailService.sendPasswordRecoveryCodeWithFallback(
        email: widget.email,
        code: _verificationCode,
        userName: widget.userName,
        useMock: false,
      );

      if (!mounted || _isDisposed) return;
      
      setState(() => _isLoading = false);

      if (!success && mounted && !_isDisposed) {
        _showErrorDialog('Error al enviar el código de recuperación');
      }
    } catch (e) {
      if (!mounted || _isDisposed) return;
      setState(() => _isLoading = false);
      _showErrorDialog('Error al enviar el código de recuperación');
    }
  }

  Future<void> _resendCode() async {
    if (_resendCountdown > 0 || !mounted || _isResending || _isDisposed) return;

    setState(() => _isResending = true);
    
    try {
      await _sendRecoveryCode();
      
      if (!mounted || _isDisposed) return;
      
      setState(() {
        _isResending = false;
        _resendCountdown = 60;
      });
      
      _startResendCountdown();
    } catch (e) {
      if (!mounted || _isDisposed) return;
      setState(() => _isResending = false);
    }
  }

  Future<void> _verifyCode() async {
    if (!mounted || _isDisposed) return;

    final inputCode = _enteredCode;
    
    if (inputCode == _verificationCode) {
      _countdownTimer?.cancel();
      
      setState(() => _isVerifying = true);
      
      try {
        if (!mounted || _isDisposed) return;
        
        // Navegar a la pantalla de nueva contraseña
        Navigator.pushReplacementNamed(
          context,
          RouteNames.resetPassword,
          arguments: {
            'email': widget.email,
            'userName': widget.userName,
          },
        );
      } catch (e) {
        if (!mounted || _isDisposed) return;
        print('Error en verificación: $e');
        _showErrorDialog('Error al verificar el código');
      } finally {
        if (mounted && !_isDisposed) {
          setState(() => _isVerifying = false);
        }
      }
    } else {
      await DialogHelper.showError(
        context,
        title: 'Código Incorrecto',
        message: 'El código de verificación que ingresaste no es válido. Por favor, verifica e intenta nuevamente.',
        primaryButtonText: 'Reintentar',
      );
    }
  }

  String get _enteredCode => _digitControllers.map((c) => c.text).join();

  void _showErrorDialog(String message) {
    if (!mounted || _isDisposed) return;
    
    DialogHelper.showError(
      context,
      title: 'Error',
      message: message,
      primaryButtonText: 'Entendido',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded, 
              color: Theme.of(context).textTheme.bodyLarge?.color,
              size: 20
            ),
            onPressed: () {
              _countdownTimer?.cancel();
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            padding: EdgeInsets.zero,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: EntranceFader(
                  delay: const Duration(milliseconds: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),

                      Text(
                        'Recupera tu contraseña',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.displayLarge?.color,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Hemos enviado un código de 4 dígitos a\n${widget.email}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                      ),

                      const SizedBox(height: 40),

                      _buildPinFields(isDark),

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (_isLoading || _isResending || _isVerifying)
                              ? null
                              : () async {
                                  if (_enteredCode.length < 4) {
                                    await DialogHelper.showWarning(
                                      context,
                                      title: 'Código incompleto',
                                      message: 'Ingresa los 4 dígitos para continuar.',
                                      primaryButtonText: 'Entendido',
                                    );
                                    return;
                                  }
                                  await _verifyCode();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isVerifying || _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                )
                              : const Text(
                                  'Verificar',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Center(
                        child: TextButton(
                          onPressed: (_resendCountdown > 0 || _isResending || _isVerifying) ? null : _resendCode,
                          child: _isResending
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _resendCountdown > 0
                                      ? 'Reenviar código en ${_resendCountdown}s'
                                      : 'Reenviar código',
                                  style: TextStyle(
                                    color: (_resendCountdown > 0 || _isVerifying)
                                      ? Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5)
                                      : AppColors.primary,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      if (_verificationCode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Para desarrollo:',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Código: $_verificationCode',
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPinFields(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const count = 4;
          double gap = 8;
          const double maxCellWidth = 54;
          const double minCellWidth = 44;
          final available = constraints.maxWidth;

          double cellWidth = (available - gap * (count - 1)) / count;
          if (cellWidth > maxCellWidth) {
            cellWidth = maxCellWidth;
          } else if (cellWidth < minCellWidth) {
            gap = 4;
            cellWidth = (available - gap * (count - 1)) / count;
            if (cellWidth < minCellWidth) {
              gap = 2;
              cellWidth = (available - gap * (count - 1)) / count;
              if (cellWidth < minCellWidth) {
                cellWidth = minCellWidth;
              }
            }
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(count, (index) {
              return AnimatedBuilder(
                animation: _pinControllers[index],
                builder: (context, child) {
                  final isFocused = _focusNodes[index].hasFocus;
                  final isFilled = _digitControllers[index].text.isNotEmpty;
                  final isDarkMode = isDark;
                  final tilt = isFilled ? 0.01 : 0.0;
                  final transform = Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateX(-tilt)
                    ..rotateY(tilt);

                  final box = Transform.scale(
                    scale: _pinAnimations[index].value,
                    child: Transform(
                      transform: transform,
                      alignment: Alignment.center,
                      child: Container(
                        width: cellWidth,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: isDarkMode
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.darkSurface.withValues(alpha: 0.95),
                                    AppColors.darkCard.withValues(alpha: 0.9),
                                  ],
                                )
                              : const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFF7F8FA),
                                    Color(0xFFFFFFFF),
                                  ],
                                ),
                          border: Border.all(
                            color: isFilled
                                ? AppColors.primary
                                : (isDarkMode ? AppColors.darkDivider : AppColors.lightDivider),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isDarkMode
                                      ? Colors.black.withValues(alpha: isFocused ? 0.45 : 0.35)
                                      : Colors.black.withValues(alpha: isFocused ? 0.10 : 0.07)),
                              blurRadius: isFocused ? 18 : 12,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color: (isDarkMode
                                      ? Colors.white.withValues(alpha: isFocused ? 0.06 : 0.04)
                                      : Colors.white.withValues(alpha: isFocused ? 0.9 : 0.7)),
                              blurRadius: isFocused ? 12 : 8,
                              offset: const Offset(-2, -2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _digitControllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          textInputAction: index < 3 ? TextInputAction.next : TextInputAction.done,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                          cursorColor: AppColors.primary,
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 18),
                          ),
                          onChanged: (value) => _handlePinChange(value, index),
                        ),
                      ),
                    ),
                  );
                  return index < count - 1
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [box, SizedBox(width: gap)],
                        )
                      : box;
                },
              );
            }),
          );
        },
      ),
    );
  }

  void _handlePinChange(String value, int index) async {
    if (!mounted || _isDisposed) return;

    if (_isProgrammaticFill) return;

    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.length > 1) {
      final limited = digitsOnly.length > _digitControllers.length
          ? digitsOnly.substring(0, _digitControllers.length)
          : digitsOnly;
      final chars = limited.split('');
      _isProgrammaticFill = true;
      try {
        for (int i = 0; i < _digitControllers.length; i++) {
          final char = i < chars.length ? chars[i] : '';
          _digitControllers[i].text = char;
          _previousValues[i] = char;
          if (char.isNotEmpty) {
            _triggerPinPulse(i);
          }
        }
      } finally {
        _isProgrammaticFill = false;
      }

      Future.microtask(() async {
        if (!mounted || _isDisposed) return;
        final filled = chars.length > _digitControllers.length
            ? _digitControllers.length
            : chars.length;
        final targetIndex = filled == 0 ? 0 : filled - 1;
        _focusNodes[targetIndex].requestFocus();

        final current = _enteredCode;
        if (current.length == 4 &&
            !current.contains(RegExp(r'[^0-9]')) &&
            !_isLoading &&
            !_isVerifying) {
          await _verifyCode();
        }
      });
      return;
    }

    if (digitsOnly.isEmpty) {
      final hadValue = _previousValues[index].isNotEmpty;
      _previousValues[index] = '';

      if (index == 0) return;

      Future.microtask(() {
        if (!mounted || _isDisposed) return;
        final previousIndex = index - 1;
        _focusNodes[previousIndex].requestFocus();

        if (!hadValue) {
          _isProgrammaticFill = true;
          try {
            _digitControllers[previousIndex].text = '';
            _previousValues[previousIndex] = '';
          } finally {
            _isProgrammaticFill = false;
          }
        }

        final previousText = _digitControllers[previousIndex].text;
        _digitControllers[previousIndex].selection = TextSelection.collapsed(
          offset: previousText.length,
        );
      });
      return;
    }

    final digit = digitsOnly[0];
    _previousValues[index] = digit;
    _triggerPinPulse(index);

    if (index < 3) {
      Future.microtask(() {
        if (!mounted || _isDisposed) return;
        _focusNodes[index + 1].requestFocus();
      });
    }

    final current = _enteredCode;
    if (current.length == 4 &&
        !current.contains(RegExp(r'[^0-9]')) &&
        !_isLoading &&
        !_isVerifying) {
      await _verifyCode();
    }
  }
}
