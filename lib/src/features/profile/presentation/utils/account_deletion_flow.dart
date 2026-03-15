import 'package:flutter/material.dart';
import 'package:viax/src/features/auth/presentation/widgets/verification_code_widget.dart';
import 'package:viax/src/features/profile/presentation/widgets/account_deletion/deletion_confirmation_dialog.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

class AccountDeletionFlow {
  static Future<void> start({
    required BuildContext context,
    required int userId,
    required String email,
    required String userName,
    required String userType,
  }) async {
    final confirmed = await DeletionConfirmationDialog.show(context);
    if (!confirmed || !context.mounted) {
      return;
    }

    final sendCodeResp = await UserService.requestAccountDeletionCode(
      userId: userId,
      email: email,
    );

    if (!context.mounted) {
      return;
    }

    if (sendCodeResp['success'] != true) {
      CustomSnackbar.showError(
        context,
        message: sendCodeResp['message']?.toString() ?? 'No se pudo enviar el código de verificación.',
      );
      return;
    }

    String verificationCode = '';
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    final bool? approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Verifica tu identidad'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola $userName, ingresa el código de 4 dígitos enviado a $email para confirmar la eliminación segura de tu cuenta.',
                  ),
                  const SizedBox(height: 14),
                  VerificationCodeWidget(
                    onCodeChanged: (value) {
                      verificationCode = value;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Motivo (opcional)',
                      hintText: 'Cuéntanos por qué deseas eliminar tu cuenta',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: (verificationCode.length != 4 || isSubmitting)
                      ? null
                      : () async {
                          setState(() => isSubmitting = true);

                          final response = await UserService.confirmAccountDeletion(
                            userId: userId,
                            email: email,
                            verificationCode: verificationCode,
                            userType: userType,
                            reason: reasonController.text.trim(),
                          );

                          if (!dialogContext.mounted) {
                            return;
                          }

                          if (response['success'] == true) {
                            Navigator.pop(dialogContext, true);
                            return;
                          }

                          setState(() => isSubmitting = false);
                          CustomSnackbar.showError(
                            dialogContext,
                            message: response['message']?.toString() ?? 'No se pudo confirmar la eliminación.',
                          );
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirmar eliminación'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonController.dispose();

    if (approved != true || !context.mounted) {
      return;
    }

    await UserService.clearSession();

    if (!context.mounted) {
      return;
    }

    CustomSnackbar.showSuccess(
      context,
      message: 'Cuenta programada para eliminación. Puedes reactivarla iniciando sesión antes de 15 días.',
    );

    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }
}
