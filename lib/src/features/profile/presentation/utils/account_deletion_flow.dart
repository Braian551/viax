import 'package:flutter/material.dart';
import 'package:viax/src/features/profile/presentation/screens/account_deletion_verification_screen.dart';
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

    final approved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccountDeletionRequestCodeScreen(
          userId: userId,
          email: email,
          userName: userName,
          userType: userType,
        ),
      ),
    );

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
