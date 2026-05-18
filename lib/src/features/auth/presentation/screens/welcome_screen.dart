// lib/src/features/auth/presentation/screens/welcome_screen.dart
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:viax/src/features/legal/providers/legal_provider.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/global/services/device_id_service.dart';
import 'package:viax/src/global/services/legal/legal_links_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/widgets/entrance_fader.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/global/services/auth/google_auth_service.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Solo una sesión activa y completa puede saltarse la bienvenida.
    final session = await UserService.getActiveSession();
    if (session != null && mounted) {
      // Verificar si necesita ingresar teléfono
      final requiresPhone = await GoogleAuthService.checkRequiresPhone();
        if (requiresPhone && mounted) {
        Navigator.of(
          context,
        ).pushReplacementNamed(RouteNames.phoneRequired, arguments: session);
      } else if (mounted) {
          final tipoUsuario = UserService.normalizeUserRole(session['tipo_usuario']) ?? 'cliente';
          if (tipoUsuario == 'soporte_tecnico') {
            Navigator.of(context).pushReplacementNamed(
              RouteNames.supportHome,
              arguments: {'support_user': session},
            );
          } else if (tipoUsuario == 'administrador' || tipoUsuario == 'admin') {
            Navigator.of(context).pushReplacementNamed(
              RouteNames.adminHome,
              arguments: {'admin_user': session},
            );
          } else if (tipoUsuario == 'conductor') {
            Navigator.of(context).pushReplacementNamed(
              RouteNames.conductorHome,
              arguments: {'conductor_user': session},
            );
          } else if (tipoUsuario == 'empresa') {
            Navigator.of(context).pushReplacementNamed(
              RouteNames.companyHome,
              arguments: {'user': session},
            );
          } else {
            Navigator.of(context).pushReplacementNamed(RouteNames.home);
          }
      }
    }
  }

  /// Inicia sesión con Google usando el SDK nativo
  Future<void> _signInWithGoogle() async {
    if (_isGoogleLoading) return;

    setState(() {
      _isGoogleLoading = true;
    });

    try {
      final deviceUuid = await DeviceIdService.getOrCreateDeviceUuid();

      // Usar el SDK de Google Sign-In directamente
      final result = await GoogleAuthService.signInWithGoogle(
        deviceUuid: deviceUuid,
      );

      if (!mounted) return;

      if (result['cancelled'] == true) {
        // Usuario canceló, no mostrar error
        return;
      }

      if (result['success'] == true) {
        final user = (result['user'] as Map?)?.cast<String, dynamic>();
        final isNewUser = result['is_new_user'] == true;

        if (isNewUser && user != null) {
          final allowed = await _ensureLegalAcceptedForUser(user);
          if (!mounted) return;
          if (!allowed) {
            // Si el alta por Google era nueva y el usuario rechaza el flujo legal, revertimos ese registro efímero.
            await _rollbackRejectedGoogleUser(
              user: user,
              deviceUuid: deviceUuid,
            );
            await GoogleAuthService.signOut();
            await UserService.clearSession();
            if (!mounted) return;
            _showErrorSnackBar('Debes aceptar terminos y privacidad para continuar.');
            return;
          }
        }

        // Verificar si necesita teléfono
        if (result['requires_phone'] == true) {
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed(
            RouteNames.phoneRequired,
            arguments: user,
          );
        } else {
          // Determinar redirección basada en rol
          final tipoUsuario = user?['tipo_usuario'] ?? 'cliente';

          if (tipoUsuario == 'soporte_tecnico') {
            if (!mounted) return;
            Navigator.pushNamedAndRemoveUntil(
              context,
              RouteNames.supportHome,
              (route) => false,
              arguments: {'support_user': user},
            );
          } else if (tipoUsuario == 'administrador' || tipoUsuario == 'admin') {
            if (!mounted) return;
            Navigator.pushNamedAndRemoveUntil(
              context,
              RouteNames.adminHome,
              (route) => false,
              arguments: {'admin_user': user},
            );
          } else if (tipoUsuario == 'conductor') {
            if (!mounted) return;
            Navigator.pushNamedAndRemoveUntil(
              context,
              RouteNames.conductorHome,
              (route) => false,
              arguments: {'conductor_user': user},
            );
          } else if (tipoUsuario == 'empresa') {
            if (!mounted) return;
            Navigator.pushNamedAndRemoveUntil(
              context,
              RouteNames.companyHome,
              (route) => false,
              arguments: {'user': user},
            );
          } else {
            // Cliente
            if (!mounted) return;
            Navigator.pushNamedAndRemoveUntil(
              context,
              RouteNames.home,
              (route) => false,
            );
          }
        }
      } else {
        final errorCode = result['error_code']?.toString();
        final data = result['data'] is Map<String, dynamic>
            ? result['data'] as Map<String, dynamic>
            : null;

        if (errorCode == 'ACCOUNT_PENDING_DELETION' || data?['pending_deletion'] == true) {
          final pendingEmail = data?['email']?.toString() ?? result['email']?.toString() ?? '';
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            RouteNames.pendingDeletionReactivation,
            arguments: {
              'email': pendingEmail,
              'deletionScheduledAt': data?['deletion_scheduled_at']?.toString(),
              'authProvider': 'google',
              'idToken': result['id_token']?.toString(),
              'accessToken': result['access_token']?.toString(),
            },
          );
          return;
        }

        _showErrorSnackBar(
          (result['message'] ??
                  'No pudimos completar el inicio de sesión con Google')
              .toString(),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(
          'No pudimos iniciar sesión con Google. Verifica tu conexión e inténtalo nuevamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  Future<bool> _ensureLegalAcceptedForUser(Map<String, dynamic> user) async {
    final role = (user['tipo_usuario'] ?? 'cliente').toString().toLowerCase();
    final userId = int.tryParse(user['id']?.toString() ?? '0') ?? 0;
    if (userId <= 0) return false;

    final legalProvider = context.read<LegalProvider>();
    final status = await legalProvider.checkLegalStatus(role: role, userId: userId);
    if (status == LegalStatus.accepted) {
      return true;
    }

    final version = await legalProvider.fetchCurrentVersion(role: role);
    if (!mounted) return false;
    if (version == null || version.isEmpty) {
      return false;
    }

    final accepted = await Navigator.of(context).pushNamed(
      RouteNames.legalAcceptance,
      arguments: {
        'role': role,
        'userId': userId,
        'version': version,
        'returnResultOnAccept': true,
        'isBlocking': false,
      },
    );

    return accepted == true;
  }

  Future<void> _openTerms() async {
    final opened = await LegalLinksService.openTerms(role: LegalRole.cliente);
    if (!opened && mounted) {
      CustomSnackbar.showError(
        context,
        message: 'No se pudo abrir Términos de Servicio',
      );
    }
  }

  Future<void> _openPrivacy() async {
    final opened = await LegalLinksService.openPrivacy(role: LegalRole.cliente);
    if (!opened && mounted) {
      CustomSnackbar.showError(
        context,
        message: 'No se pudo abrir Política de Privacidad',
      );
    }
  }

  void _showErrorSnackBar(String message) {
    CustomSnackbar.showError(
      context,
      message: message,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _rollbackRejectedGoogleUser({
    required Map<String, dynamic> user,
    required String deviceUuid,
  }) async {
    final userId = int.tryParse(user['id']?.toString() ?? '') ?? 0;
    if (userId <= 0 || deviceUuid.trim().isEmpty) {
      return;
    }

    try {
      await http.post(
        Uri.parse('${AppConfig.authServiceUrl}/google/cancel_new_user.php'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'device_uuid': deviceUuid,
        }),
      );
    } catch (error) {
      debugPrint('No se pudo revertir el alta nueva de Google: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: SizedBox(
          height: size.height,
          child: Column(
            children: [
              SizedBox(height: size.height * 0.12),

              // Icono de auto moderno con efecto de profundidad (entrance animation)
              EntranceFader(
                delay: const Duration(milliseconds: 80),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(
                          alpha: isDark ? 0.25 : 0.15,
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0.1, 0.8],
                    ),
                  ),
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ).createShader(bounds);
                    },
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 85,
                      height: 85,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              EntranceFader(
                delay: const Duration(milliseconds: 160),
                child: Text(
                  'Bienvenido a Viax',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.displayMedium?.color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              EntranceFader(
                delay: const Duration(milliseconds: 240),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Viaja fácil, llega rápido',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      height: 1.4,
                    ),
                  ),
                ),
              ),

              SizedBox(height: size.height * 0.07),

              // Botones de autenticación
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Iniciar con Google
                    _buildSocialButton(
                      icon: _isGoogleLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black54,
                                ),
                              ),
                            )
                          : Image.asset(
                              'assets/images/google_logo.png',
                              height: 24,
                              width: 24,
                            ),
                      text: _isGoogleLoading
                          ? 'Conectando...'
                          : 'Continuar con Google',
                      backgroundColor: Colors.white,
                      textColor: Colors.black,
                      borderColor: isDark
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.2),
                      onPressed: _isGoogleLoading ? () {} : _signInWithGoogle,
                    ),

                    const SizedBox(height: 14),

                    /*
                    // Iniciar con Apple
                    _buildSocialButton(
                      icon: Icon(
                        Icons.apple,
                        color: Colors.white,
                        size: 24,
                      ),
                      text: 'Continuar con Apple',
                      backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFF000000),
                      textColor: Colors.white,
                        borderColor: isDark
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.transparent,
                      onPressed: () {
                        // TODO: Integrar Apple Sign-In
                      },
                    ),                    const SizedBox(height: 14),
                    */

                    // Iniciar con correo
                    _buildSocialButton(
                      icon: const Icon(
                        Icons.email_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      text: 'Continuar con correo',
                      backgroundColor: Colors.transparent,
                      textColor: AppColors.primary,
                      borderColor: AppColors.primary.withValues(alpha: 0.5),
                      onPressed: () {
                        Navigator.pushNamed(context, RouteNames.emailAuth);
                      },
                    ),

                    const SizedBox(height: 28),

                    // Divider con texto
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '¿Tienes una empresa?',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Botón de registro de empresa
                    _buildSocialButton(
                      icon: Icon(
                        Icons.business_outlined,
                        color: isDark ? Colors.white70 : Colors.black54,
                        size: 24,
                      ),
                      text: 'Registrar empresa de transporte',
                      backgroundColor: Colors.transparent,
                      textColor: isDark ? Colors.white70 : Colors.black54,
                      borderColor: isDark ? Colors.white24 : Colors.black26,
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          RouteNames.empresaRegister,
                        );
                      },
                    ),

                    /*
                    const SizedBox(height: 14),
                    
                    // Iniciar con teléfono
                    _buildSocialButton(
                      icon: const Icon(
                        Icons.phone_iphone_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      text: 'Continuar con teléfono',
                      backgroundColor: AppColors.primary,
                      textColor: Colors.white,
                      onPressed: () {
                        Navigator.pushNamed(context, RouteNames.phoneAuth);
                      },
                    ),
                    */
                    const SizedBox(height: 28),

                    // Términos y condiciones
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text: 'Al continuar, aceptas nuestros ',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.7),
                            fontSize: 12,
                            height: 1.5,
                          ),
                          children: [
                            TextSpan(
                              text: 'Términos de Servicio',
                              style: TextStyle(
                                color: AppColors.primary.withValues(alpha: 0.9),
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = _openTerms,
                            ),
                            const TextSpan(text: ' y '),
                            TextSpan(
                              text: 'Política de Privacidad',
                              style: TextStyle(
                                color: AppColors.primary.withValues(alpha: 0.9),
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = _openPrivacy,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required Widget icon,
    required String text,
    required Color backgroundColor,
    required Color textColor,
    Color borderColor = Colors.transparent,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: 1.2),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
