import 'package:flutter/material.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/entrance_fader.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

class PasswordChangeVerificationScreen extends StatefulWidget {
  final int userId;

  const PasswordChangeVerificationScreen({
    super.key,
    required this.userId,
  });

  @override
  State<PasswordChangeVerificationScreen> createState() =>
      _PasswordChangeVerificationScreenState();
}

class _PasswordChangeVerificationScreenState
    extends State<PasswordChangeVerificationScreen> {
  bool _isSubmitting = false;

  Future<void> _startVerification() async {
    setState(() => _isSubmitting = true);

    final session = await UserService.getSavedSession();
    final email = session?['email']?.toString() ?? '';
    final firstName = session?['nombre']?.toString() ?? '';
    final lastName = session?['apellido']?.toString() ?? '';
    final userName = '$firstName $lastName'.trim().isEmpty
        ? 'Usuario'
        : '$firstName $lastName'.trim();

    if (!mounted) return;

    if (email.isEmpty) {
      setState(() => _isSubmitting = false);
      CustomSnackbar.showError(
        context,
        message: 'No se pudo obtener tu correo para la verificación',
      );
      return;
    }

    final changed = await Navigator.pushNamed(
      context,
      RouteNames.passwordRecoveryVerification,
      arguments: {
        'email': email,
        'userName': userName,
        'passwordChangeUserId': widget.userId,
      },
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (changed == true) {
      CustomSnackbar.showSuccess(
        context,
        message: 'Contraseña actualizada correctamente',
      );
      Navigator.pop(context);
    }
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
            color: isDark
                ? AppColors.darkSurface
                : AppColors.lightSurface.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: Theme.of(context).textTheme.bodyLarge?.color,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
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
                'Cambiar contraseña',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.displayMedium?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Primero verifica tu identidad con el código enviado a tu correo. Luego crearás tu nueva contraseña.',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Te enviaremos un código de 4 dígitos para autorizar el cambio.',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _startVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Verificar correo',
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
      ),
    );
  }
}
