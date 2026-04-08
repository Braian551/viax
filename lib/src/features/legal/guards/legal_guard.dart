import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/legal/providers/legal_provider.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Un Guard que envuelve pantallas protegidas. 
/// Evita la navegación si el estado legal no es 'accepted' o 'errorFallback'.
class LegalGuard extends StatefulWidget {
  final Widget child;
  const LegalGuard({Key? key, required this.child}) : super(key: key);

  @override
  State<LegalGuard> createState() => _LegalGuardState();
}

class _LegalGuardState extends State<LegalGuard> {
  bool _gateOpen = false;
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    // Ejecutamos la validación después del primer frame para evitar conflictos de BuildContext
    WidgetsBinding.instance.addPostFrameCallback((_) => _validateLegalRequirement());
  }

  Future<void> _validateLegalRequirement() async {
    try {
      final legalProv = context.read<LegalProvider>();

      // 1. Si ya aceptó en esta sesión, abrimos la puerta de inmediato.
      if (legalProv.isAccepted) {
        if (mounted) setState(() => _gateOpen = true);
        return;
      }

      // 2. Verificar si hay sesión
      final session = await UserService.getSavedSession();
      if (session == null || session['id'] == null) {
        if (mounted) setState(() => _gateOpen = true);
        return;
      }

      // 3. Consultar al backend. Si no está aceptado, bloquear acceso y redirigir.
      final role = (session['tipo_usuario'] ?? 'cliente').toString().toLowerCase();
      final userId = int.tryParse(session['id'].toString()) ?? 0;
      final status = await legalProv
          .checkLegalStatus(role: role, userId: userId)
          .timeout(const Duration(seconds: 8), onTimeout: () => LegalStatus.notAccepted);

      if (!mounted) return;

      if (status == LegalStatus.accepted) {
        setState(() => _gateOpen = true);
        return;
      }

      _redirectToLegalAcceptance(
        role: role,
        userId: userId,
        version: legalProv.currentRequiredVersion ?? 'v1.0',
      );
    } catch (e) {
      debugPrint('[LegalGuard] Error validando estado legal: $e');
      if (!mounted) return;

      final session = await UserService.getSavedSession();
      final role = (session?['tipo_usuario'] ?? 'cliente').toString().toLowerCase();
      final userId = int.tryParse((session?['id'] ?? 0).toString()) ?? 0;

      _redirectToLegalAcceptance(
        role: role,
        userId: userId,
        version: 'v1.0',
      );
    }
  }

  void _redirectToLegalAcceptance({
    required String role,
    required int userId,
    required String version,
  }) {
    if (!mounted || _isRedirecting) return;
    _isRedirecting = true;

    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.legalAcceptance,
      (route) => false,
      arguments: {
        'role': role,
        'userId': userId,
        'version': version,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_gateOpen) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}
