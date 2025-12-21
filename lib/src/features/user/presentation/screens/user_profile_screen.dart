import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'package:viax/src/widgets/dialogs/dialog_helper.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  String? _userName;
  String? _userEmail;
  bool _isLoading = true;
  bool _isLoggingOut = false;
  
  // Animaciones
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadUserData();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
  }

  Future<void> _loadUserData() async {
    try {
      final sess = await UserService.getSavedSession();
      if (sess != null) {
        if (mounted) {
          setState(() {
            _userName = sess['nombre'] ?? 'Usuario';
            _userEmail = sess['email'] ?? 'usuario@viax.com';
            _isLoading = false;
          });
          _animationController.forward();
        }
      } else {
         if (mounted) {
          setState(() {
            _userName = 'Invitado';
            _userEmail = 'Inicia sesión';
            _isLoading = false;
          });
          _animationController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.forward();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _performLogout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await UserService.clearSession();
      if (!mounted) return;
      CustomSnackbar.showSuccess(context, message: 'Sesión cerrada correctamente');
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(context, message: 'No se pudo cerrar la sesión');
      setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _confirmLogout() async {
    if (_isLoggingOut) return;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'Cerrar sesión',
      message: '¿Estás seguro de que deseas cerrar sesión?',
      confirmText: 'Sí, cerrar',
      cancelText: 'Cancelar',
    );

    if (confirmed == true) await _performLogout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // Fondo decorativo (opcional, similar a HomeUser)
          Positioned(
            top: -100,
            right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),

          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Título
                            Text(
                              'Mi Perfil',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Tarjeta de Usuario
                            _buildUserCard(isDark),
                            
                            const SizedBox(height: 24),

                            // Calificación (Mocked)
                            _buildRatingSection(isDark),

                            const SizedBox(height: 32),

                            // Opciones
                            Text(
                              'Configuración',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            _buildOptionTile(
                              icon: Icons.person_outline_rounded,
                              title: 'Editar Perfil',
                              subtitle: 'Nombre, teléfono, foto',
                              isDark: isDark,
                              onTap: () {},
                            ),
                            _buildOptionTile(
                              icon: Icons.location_on_outlined,
                              title: 'Mis Direcciones',
                              subtitle: 'Casa, trabajo y favoritos',
                              isDark: isDark,
                              onTap: () {},
                            ),
                            _buildOptionTile(
                              icon: Icons.credit_card_rounded,
                              title: 'Métodos de Pago',
                              subtitle: 'Tarjetas, efectivo',
                              isDark: isDark,
                              onTap: () {},
                            ),
                            _buildOptionTile(
                              icon: Icons.notifications_none_rounded,
                              title: 'Notificaciones',
                              subtitle: 'Promociones, estado del viaje',
                              isDark: isDark,
                              onTap: () {},
                            ),
                             _buildOptionTile(
                              icon: Icons.help_outline_rounded,
                              title: 'Ayuda y Soporte',
                              subtitle: 'Centro de ayuda, contactar',
                              isDark: isDark,
                              onTap: () {},
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Botón Cerrar Sesión
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 20),
                              child: TextButton(
                                onPressed: _confirmLogout,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                                ),
                                child: _isLoggingOut
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2))
                                    : Text(
                                        'Cerrar Sesión',
                                        style: TextStyle(
                                          color: AppColors.error,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            // Espacio extra para el bottom nav
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.person_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName ?? 'Usuario',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard.withValues(alpha: 0.5) : AppColors.lightCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu Calificación',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '4.95',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Excelente',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isDark ? Colors.white70 : Colors.black54,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
