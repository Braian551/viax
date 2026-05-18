import 'dart:async';

import 'package:flutter/material.dart';
import 'package:viax/src/features/auth/presentation/widgets/verification_action_intro_view.dart';
import 'package:viax/src/features/auth/presentation/widgets/verification_code_widget.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

class AccountDeletionRequestCodeScreen extends StatefulWidget {
  final int userId;
  final String email;
  final String userName;
  final String userType;

  const AccountDeletionRequestCodeScreen({
    super.key,
    required this.userId,
    required this.email,
    required this.userName,
    required this.userType,
  });

  @override
  State<AccountDeletionRequestCodeScreen> createState() =>
      _AccountDeletionRequestCodeScreenState();
}

class _AccountDeletionRequestCodeScreenState
    extends State<AccountDeletionRequestCodeScreen> {
  bool _isSubmitting = false;

  Future<void> _startVerification() async {
    setState(() => _isSubmitting = true);

    final response = await UserService.requestAccountDeletionCode(
      userId: widget.userId,
      email: widget.email,
    );

    if (!mounted) return;

    if (response['success'] != true) {
      setState(() => _isSubmitting = false);
      CustomSnackbar.showError(
        context,
        message:
            response['message']?.toString() ??
            'No se pudo enviar el código de verificación.',
      );
      return;
    }

    final approved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccountDeletionCodeScreen(
          userId: widget.userId,
          email: widget.email,
          userName: widget.userName,
          userType: widget.userType,
        ),
      ),
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);
    if (approved == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return VerificationActionIntroView(
      title: 'Eliminar cuenta',
      description:
          'Primero verifica tu identidad con el código enviado a tu correo. Luego confirmaremos la programación de eliminación de tu cuenta.',
      infoText:
          'Te enviaremos un código de 4 dígitos para autorizar la eliminación segura.',
      buttonLabel: 'Verificar correo',
      infoIcon: Icons.mark_email_read_rounded,
      isSubmitting: _isSubmitting,
      onPressed: _startVerification,
    );
  }
}

class AccountDeletionCodeScreen extends StatefulWidget {
  final int userId;
  final String email;
  final String userName;
  final String userType;

  const AccountDeletionCodeScreen({
    super.key,
    required this.userId,
    required this.email,
    required this.userName,
    required this.userType,
  });

  @override
  State<AccountDeletionCodeScreen> createState() =>
      _AccountDeletionCodeScreenState();
}

class _AccountDeletionCodeScreenState extends State<AccountDeletionCodeScreen> {
  final TextEditingController _reasonController = TextEditingController();

  Timer? _countdownTimer;
  String _verificationCode = '';
  int _resendCountdown = 60;
  bool _isResending = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _reasonController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendCountdown <= 0) {
        timer.cancel();
        return;
      }

      setState(() => _resendCountdown--);
    });
  }

  Future<void> _resendCode() async {
    if (_resendCountdown > 0 || _isResending || _isSubmitting) {
      return;
    }

    setState(() => _isResending = true);

    final response = await UserService.requestAccountDeletionCode(
      userId: widget.userId,
      email: widget.email,
    );

    if (!mounted) return;

    if (response['success'] != true) {
      setState(() => _isResending = false);
      CustomSnackbar.showError(
        context,
        message:
            response['message']?.toString() ??
            'No se pudo reenviar el código de verificación.',
      );
      return;
    }

    setState(() {
      _isResending = false;
      _resendCountdown = 60;
    });
    _startResendCountdown();
    CustomSnackbar.showSuccess(context, message: 'Código reenviado');
  }

  Future<void> _confirmDeletion() async {
    if (_verificationCode.length != 4 || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    final response = await UserService.confirmAccountDeletion(
      userId: widget.userId,
      email: widget.email,
      verificationCode: _verificationCode,
      userType: widget.userType,
      reason: _reasonController.text.trim(),
    );

    if (!mounted) return;

    if (response['success'] == true) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _isSubmitting = false);
    CustomSnackbar.showError(
      context,
      message:
          response['message']?.toString() ??
          'No se pudo confirmar la eliminación.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: textTheme.bodyLarge?.color,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verifica tu correo',
              style: textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hola ${widget.userName}, ingresa el código de 4 dígitos enviado a ${widget.email} para confirmar la eliminación segura de tu cuenta.',
              style: textTheme.bodyLarge?.copyWith(
                color: textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 32),
            VerificationCodeWidget(
              onCodeChanged: (value) {
                setState(() => _verificationCode = value);
              },
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _reasonController,
              maxLength: 120,
              maxLines: 3,
              minLines: 3,
              decoration: InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Cuéntanos por qué deseas eliminar tu cuenta',
                alignLabelWithHint: true,
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed:
                    _verificationCode.length == 4 && !_isSubmitting
                        ? _confirmDeletion
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: colorScheme.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirmar eliminación',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _resendCountdown > 0 || _isResending || _isSubmitting
                    ? null
                    : _resendCode,
                child: _isResending
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: colorScheme.primary,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _resendCountdown > 0
                            ? 'Reenviar código en ${_resendCountdown}s'
                            : 'Reenviar código',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
