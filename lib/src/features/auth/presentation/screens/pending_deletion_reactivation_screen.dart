import 'package:flutter/material.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

class PendingDeletionReactivationScreen extends StatefulWidget {
  final String email;
  final String? password;
  final String? deletionScheduledAt;
  final String? authProvider;
  final String? idToken;
  final String? accessToken;

  const PendingDeletionReactivationScreen({
    super.key,
    required this.email,
    this.password,
    this.deletionScheduledAt,
    this.authProvider,
    this.idToken,
    this.accessToken,
  });

  @override
  State<PendingDeletionReactivationScreen> createState() => _PendingDeletionReactivationScreenState();
}

class _PendingDeletionReactivationScreenState extends State<PendingDeletionReactivationScreen> {
  bool _isLoading = false;

  bool get _isGoogleFlow => (widget.authProvider ?? '').toLowerCase() == 'google';

  Future<void> _navigateByRole(Map<String, dynamic> user) async {
    final tipoUsuario = (user['tipo_usuario'] ?? 'cliente').toString();

    if (tipoUsuario == 'soporte_tecnico') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.supportHome,
        (route) => false,
        arguments: {'support_user': user},
      );
      return;
    }

    if (tipoUsuario == 'administrador' || tipoUsuario == 'admin') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.adminHome,
        (route) => false,
        arguments: {'admin_user': user},
      );
      return;
    }

    if (tipoUsuario == 'conductor') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.conductorHome,
        (route) => false,
        arguments: {'conductor_user': user},
      );
      return;
    }

    if (tipoUsuario == 'empresa') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.companyHome,
        (route) => false,
        arguments: {'user': user},
      );
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      RouteNames.home,
      (route) => false,
      arguments: {'email': user['email'], 'user': user},
    );
  }

  Future<void> _reactivate() async {
    setState(() => _isLoading = true);

    final response = await UserService.reactivateAccount(
      email: widget.email,
      password: _isGoogleFlow ? null : widget.password,
      idToken: _isGoogleFlow ? widget.idToken : null,
      accessToken: _isGoogleFlow ? widget.accessToken : null,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isLoading = false);

    if (response['success'] != true) {
      CustomSnackbar.showError(
        context,
        message: response['message']?.toString() ?? 'No se pudo reactivar la cuenta.',
      );
      return;
    }

    final user = response['data'] is Map<String, dynamic>
        ? (response['data'] as Map<String, dynamic>)['user'] as Map<String, dynamic>?
        : null;

    if (user == null) {
      CustomSnackbar.showError(
        context,
        message: 'No se pudo recuperar la sesión después de reactivar.',
      );
      return;
    }

    await UserService.saveActiveSession(user);

    if (!mounted) {
      return;
    }

    CustomSnackbar.showSuccess(
      context,
      message: 'Cuenta reactivada correctamente.',
    );

    await _navigateByRole(user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta en eliminación pendiente')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu cuenta está programada para eliminación.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Si deseas conservarla, reactivaremos la cuenta para: ${widget.email}. Después del plazo de 15 días, la eliminación será irreversible.',
                    ),
                    if (widget.deletionScheduledAt != null) ...[
                      const SizedBox(height: 8),
                      Text('Fecha programada de eliminación: ${widget.deletionScheduledAt}'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _reactivate,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reactivar cuenta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
