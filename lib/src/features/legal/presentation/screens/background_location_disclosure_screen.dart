import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/app_colors.dart';

class BackgroundLocationDisclosureScreen extends StatefulWidget {
  final String role;

  const BackgroundLocationDisclosureScreen({
    super.key,
    this.role = '',
  });

  @override
  State<BackgroundLocationDisclosureScreen> createState() =>
      _BackgroundLocationDisclosureScreenState();
}

class _BackgroundLocationDisclosureScreenState
    extends State<BackgroundLocationDisclosureScreen> {
  bool _isContinuing = false;

  String _resolveRole(Map<String, dynamic> session) {
    final routeRole = widget.role.trim().toLowerCase();
    if (routeRole.isNotEmpty) return routeRole;
    return (session['tipo_usuario']?.toString().toLowerCase() ?? 'cliente');
  }

  Future<void> _continueToNextScreen() async {
    if (_isContinuing) return;

    setState(() => _isContinuing = true);

    try {
      final session = await UserService.getSavedSession();
      if (!mounted) return;

      if (session == null) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.authWrapper,
          (route) => false,
        );
        return;
      }

      final role = _resolveRole(session);

      switch (role) {
        case 'conductor':
          Navigator.of(context).pushNamedAndRemoveUntil(
            RouteNames.conductorHome,
            (route) => false,
            arguments: {'conductor_user': session},
          );
          break;
        case 'empresa':
          Navigator.of(context).pushNamedAndRemoveUntil(
            RouteNames.companyHome,
            (route) => false,
            arguments: {'user': session},
          );
          break;
        case 'administrador':
        case 'admin':
          Navigator.of(context).pushNamedAndRemoveUntil(
            RouteNames.adminHome,
            (route) => false,
            arguments: {'admin_user': session},
          );
          break;
        case 'soporte_tecnico':
          Navigator.of(context).pushNamedAndRemoveUntil(
            RouteNames.supportHome,
            (route) => false,
            arguments: {'support_user': session},
          );
          break;
        default:
          Navigator.of(context).pushNamedAndRemoveUntil(
            RouteNames.home,
            (route) => false,
            arguments: {'email': session['email'], 'user': session},
          );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        RouteNames.authWrapper,
        (route) => false,
      );
    }
  }

  Widget _buildGradientBlob(Size size, Color color) {
    return Container(
      width: size.width * 0.8,
      height: size.width * 0.8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildFeatureItem(String text, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtitleColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -120,
            child: _buildGradientBlob(size, AppColors.primary.withValues(alpha: 0.20)),
          ),
          Positioned(
            bottom: -120,
            left: -120,
            child: _buildGradientBlob(size, AppColors.accent.withValues(alpha: 0.14)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 28,
                        height: 28,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.flash_on,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Viax',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.16),
                                    AppColors.primary.withValues(alpha: 0.08),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.primary,
                                size: 46,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Text(
                              'Uso de Ubicación en Segundo Plano',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                height: 1.15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Este aviso es informativo para conductores. La ubicación en segundo plano nos ayuda a mejorar el seguimiento de viajes activos y la asignación de servicios cercanos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: subtitleColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildFeatureItem(
                            'Seguimiento en tiempo real para mayor seguridad durante viajes activos.',
                            isDark,
                          ),
                          _buildFeatureItem(
                            'Asignación más eficiente de servicios según tu zona operativa.',
                            isDark,
                          ),
                          _buildFeatureItem(
                            'Solo se usa cuando estás en funciones de conductor; no permanece activo de forma permanente.',
                            isDark,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Importante: al continuar no se solicitará el permiso todavía. La app lo pedirá únicamente cuando llegues al punto del flujo donde sea necesario para operar como conductor.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Cuando la solicitud aparezca más adelante, selecciona "Permitir todo el tiempo" para habilitar correctamente las funciones que dependen de ubicación en segundo plano.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: subtitleColor,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _isContinuing ? null : _continueToNextScreen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 10,
                        shadowColor: AppColors.primary.withValues(alpha: 0.35),
                      ),
                      child: _isContinuing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'ENTENDIDO Y CONTINUAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
