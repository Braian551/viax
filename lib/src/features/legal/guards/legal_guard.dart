import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/legal/providers/legal_provider.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/global/services/auth/user_service.dart';

/// Guard que valida el estado legal sin pintar un loader bloqueante.
class LegalGuard extends StatefulWidget {
  final Widget child;

  const LegalGuard({super.key, required this.child});

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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _validateLegalRequirement(),
    );
  }

  Future<void> _validateLegalRequirement() async {
    String role = 'cliente';
    int userId = 0;
    bool hasCachedAcceptance = false;

    try {
      final legalProv = context.read<LegalProvider>();

      // 1. Si ya aceptó en esta sesión, abrimos la puerta de inmediato.
      if (legalProv.isAccepted) {
        if (mounted) setState(() => _gateOpen = true);
        return;
      }

      // 2. Verificar si hay sesión.
      final session = await UserService.getSavedSession();
      if (session == null || session['id'] == null) {
        if (mounted) setState(() => _gateOpen = true);
        return;
      }

      // 3. Abrir de inmediato si existe aceptación local y validar en segundo plano.
      role = (session['tipo_usuario'] ?? 'cliente').toString().toLowerCase();
      userId = int.tryParse(session['id'].toString()) ?? 0;
      hasCachedAcceptance = await legalProv.hasCachedAcceptance(
        role: role,
        userId: userId,
      );

      if (hasCachedAcceptance && mounted && !_gateOpen) {
        setState(() => _gateOpen = true);
      }

      final status = await legalProv
          .checkLegalStatus(role: role, userId: userId)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => hasCachedAcceptance
                ? LegalStatus.accepted
                : LegalStatus.notAccepted,
          );

      if (!mounted) return;

      if (status == LegalStatus.accepted) {
        if (!_gateOpen) {
          setState(() => _gateOpen = true);
        }
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

      if (hasCachedAcceptance) {
        if (!_gateOpen) {
          setState(() => _gateOpen = true);
        }
        return;
      }

      if (userId == 0) {
        final session = await UserService.getSavedSession();
        if (session == null || session['id'] == null) {
          if (mounted) setState(() => _gateOpen = true);
          return;
        }

        role = (session['tipo_usuario'] ?? 'cliente').toString().toLowerCase();
        userId = int.tryParse(session['id'].toString()) ?? 0;
      }

      _redirectToLegalAcceptance(role: role, userId: userId, version: 'v1.0');
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
      arguments: {'role': role, 'userId': userId, 'version': version},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_gateOpen) {
      return IgnorePointer(ignoring: true, child: widget.child);
    }

    return widget.child;
  }
}
