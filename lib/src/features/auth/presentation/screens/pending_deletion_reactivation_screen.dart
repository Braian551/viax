import 'package:flutter/material.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

class PendingDeletionReactivationScreen extends StatefulWidget {
  final String email;
  final String? password;
  final String? deletionScheduledAt;

  const PendingDeletionReactivationScreen({
    super.key,
    required this.email,
    this.password,
    this.deletionScheduledAt,
  });

  @override
  State<PendingDeletionReactivationScreen> createState() => _PendingDeletionReactivationScreenState();
}

class _PendingDeletionReactivationScreenState extends State<PendingDeletionReactivationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _passwordController;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController(text: widget.password ?? '');
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _reactivate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final response = await UserService.reactivateAccount(
      email: widget.email,
      password: _passwordController.text,
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

    CustomSnackbar.showSuccess(
      context,
      message: 'Cuenta reactivada. Ahora puedes iniciar sesión nuevamente.',
    );

    Navigator.pushNamedAndRemoveUntil(
      context,
      RouteNames.login,
      (route) => false,
      arguments: {
        'email': widget.email,
        'prefilled': true,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta en eliminación pendiente')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
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
                      const Text(
                        'Si deseas conservarla, reactívala ahora. Después del plazo de 15 días, la eliminación será irreversible.',
                      ),
                      if (widget.deletionScheduledAt != null) ...[
                        const SizedBox(height: 8),
                        Text('Fecha programada de eliminación: ${widget.deletionScheduledAt}'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  initialValue: widget.email,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa tu contraseña para reactivar';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
      ),
    );
  }
}
