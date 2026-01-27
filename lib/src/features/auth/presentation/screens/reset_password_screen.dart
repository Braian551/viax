// lib/src/features/auth/presentation/screens/reset_password_screen.dart
import 'package:flutter/material.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/widgets/entrance_fader.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'package:viax/src/widgets/dialogs/dialog_helper.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_field.dart';

/// Pantalla para establecer nueva contraseña después de verificar el código
class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String userName;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.userName,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final result = await UserService.resetPassword(
          email: widget.email,
          newPassword: _passwordController.text,
        );

        if (!mounted) return;

        if (result['success'] == true) {
          await DialogHelper.showSuccess(
            context,
            title: '¡Contraseña actualizada!',
            message: 'Tu contraseña ha sido cambiada exitosamente. Ahora puedes iniciar sesión con tu nueva contraseña.',
            primaryButtonText: 'Iniciar sesión',
          );

          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              RouteNames.login,
              (route) => route.settings.name == RouteNames.welcome || route.settings.name == RouteNames.authWrapper,
              arguments: {
                'email': widget.email,
                'prefilled': true,
              },
            );
          }
        } else {
          _showError(result['message'] ?? 'Error al cambiar la contraseña');
        }
      } catch (e) {
        print('Error resetting password: $e');
        _showError('Error al cambiar la contraseña. Por favor, intenta de nuevo.');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    CustomSnackbar.showError(
      context,
      message: message,
      duration: const Duration(seconds: 3),
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
              // Advertir al usuario antes de salir
              DialogHelper.showWarning(
                context,
                title: '¿Salir?',
                message: 'Si sales ahora, tendrás que verificar tu código nuevamente.',
                primaryButtonText: 'Cancelar',
                secondaryButtonText: 'Salir',
                onPrimaryPressed: () {
                  Navigator.pop(context); // Cerrar diálogo
                },
                onSecondaryPressed: () {
                  Navigator.pop(context); // Cerrar diálogo
                  Navigator.pop(context); // Salir de la pantalla
                },
              );
            },
            padding: EdgeInsets.zero,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: EntranceFader(
          delay: const Duration(milliseconds: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              Text(
                'Nueva contraseña',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.displayMedium?.color,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Crea una nueva contraseña segura para tu cuenta.',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),

              const SizedBox(height: 40),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    AuthTextField(
                      controller: _passwordController,
                      label: 'Nueva contraseña',
                      icon: Icons.lock_rounded,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu nueva contraseña';
                        }
                        if (value.length < 6) {
                          return 'La contraseña debe tener al menos 6 caracteres';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    AuthTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirmar contraseña',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor confirma tu contraseña';
                        }
                        if (value != _passwordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Cambiar contraseña',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
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
      ),
    );
  }
}
