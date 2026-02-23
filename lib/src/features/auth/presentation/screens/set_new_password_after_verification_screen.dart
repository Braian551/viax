import 'package:flutter/material.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/widgets/entrance_fader.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

class SetNewPasswordAfterVerificationScreen extends StatefulWidget {
  final int userId;
  final String verificationCode;

  const SetNewPasswordAfterVerificationScreen({
    super.key,
    required this.userId,
    required this.verificationCode,
  });

  @override
  State<SetNewPasswordAfterVerificationScreen> createState() =>
      _SetNewPasswordAfterVerificationScreenState();
}

class _SetNewPasswordAfterVerificationScreenState
    extends State<SetNewPasswordAfterVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  String _resolveHomeRoute(String? userType) {
    if (userType == 'conductor') {
      return RouteNames.conductorHome;
    }
    return RouteNames.home;
  }

  Future<void> _showSuccessAlert() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            '¡Éxito!',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Tu contraseña se ha cambiado exitosamente.',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ir al inicio'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final result = await UserService.changePasswordWithCode(
      userId: widget.userId,
      newPassword: _newPasswordController.text.trim(),
      verificationCode: widget.verificationCode,
      isSettingNew: true,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      final session = await UserService.getSavedSession();
      final userType = session?['tipo_usuario']?.toString();
      final homeRoute = _resolveHomeRoute(userType);

      if (!mounted) return;

      await _showSuccessAlert();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        homeRoute,
        (route) => false,
      );
      return;
    }

    CustomSnackbar.showError(
      context,
      message: result['message']?.toString() ?? 'No se pudo cambiar la contraseña',
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
          child: Form(
            key: _formKey,
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
                  'Código verificado. Ahora crea tu nueva contraseña.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 30),
                AuthTextField(
                  controller: _newPasswordController,
                  label: 'Nueva contraseña',
                  icon: Icons.lock_rounded,
                  obscureText: _obscureNew,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                    onPressed: () {
                      setState(() => _obscureNew = !_obscureNew);
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa una nueva contraseña';
                    }
                    if (value.trim().length < 8) {
                      return 'Debe tener al menos 8 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirmar contraseña',
                  icon: Icons.lock_reset_rounded,
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                    onPressed: () {
                      setState(() => _obscureConfirm = !_obscureConfirm);
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Confirma tu nueva contraseña';
                    }
                    if (value.trim() != _newPasswordController.text.trim()) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
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
                            'Actualizar contraseña',
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
      ),
    );
  }
}
