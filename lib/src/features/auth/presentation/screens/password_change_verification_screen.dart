import 'package:flutter/material.dart';
import 'package:viax/src/features/auth/presentation/widgets/verification_action_intro_view.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/routes/route_names.dart';
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
    return VerificationActionIntroView(
      title: 'Cambiar contraseña',
      description:
          'Primero verifica tu identidad con el código enviado a tu correo. Luego crearás tu nueva contraseña.',
      infoText: 'Te enviaremos un código de 4 dígitos para autorizar el cambio.',
      buttonLabel: 'Verificar correo',
      infoIcon: Icons.mark_email_read_rounded,
      isSubmitting: _isSubmitting,
      onPressed: _startVerification,
    );
  }
}
