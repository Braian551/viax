import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/widgets/dialogs/logout_dialog.dart';
import 'package:viax/src/features/user/presentation/widgets/profile/user_profile_shimmer.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  String? _userName;
  String? _userEmail;
  int? _userId;
  String? _firstName;
  String? _lastName;
  String? _photoKey;
  String? _phone;
  double _rating = 5.0; // Default rating
  bool _isLoading = true;
  bool _isLoggingOut = false;
  
  // Driver registration status: null = not checked, 'none' = not registered, 'pendiente' = pending, 'activo' = approved
  // Driver registration status: null = not checked, 'none' = not registered, 'pendiente' = pending, 'activo' = approved
  String? _driverStatus;
  String? _rejectionReason;
  
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
        final userId = sess['id'];
        _userId = userId is int ? userId : int.tryParse(userId.toString());
        
        if (_userId != null) {
          // 1. Check driver status
          final driverProfile = await UserService.getDriverProfile(userId: _userId!);
          if (driverProfile != null && driverProfile['success'] == true) {
            final profile = driverProfile['profile'];
            if (profile != null) {
              _driverStatus = profile['estado_aprobacion'] ?? 'pendiente';
              _rejectionReason = profile['razon_rechazo'];
            }
          }
          
          // 2. Fetch full user profile for editing (nombre, apellido, foto)
           final userProfile = await UserService.getProfile(userId: _userId!);
           if (userProfile != null && userProfile['success'] == true) {
             final userData = userProfile['user'] ?? userProfile['data']; // Adapt to backend response structure
             if (userData != null) {
                _firstName = userData['nombre'];
                _lastName = userData['apellido'];
                _photoKey = userData['foto_perfil'];
                _phone = userData['telefono'];
                // Parse rating safely
                final rawRating = userData['calificacion_promedio'];
                if (rawRating != null) {
                  _rating = double.tryParse(rawRating.toString()) ?? 5.0;
                }
                _userName = '$_firstName $_lastName'.trim();
                _userEmail = userData['email'] ?? sess['email'];
              }
           } else {
             // Fallback to session data
             _userName = sess['nombre'] ?? 'Usuario';
             _userEmail = sess['email'] ?? 'usuario@viax.com';
           }
        }
        
        if (mounted) {
          setState(() {
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
    final confirmed = await LogoutDialog.show(context);

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
                ? const UserProfileShimmer()
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

                            const SizedBox(height: 24),

                            // Opción para ser conductor (Novedad)
                            _buildBecomeDriverCard(isDark),

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
                              onTap: () async {
                                final result = await Navigator.pushNamed(
                                  context,
                                  RouteNames.editProfile,
                                  arguments: {
                                    'userId': _userId,
                                    'nombre': _firstName,
                                    'apellido': _lastName,
                                    'email': _userEmail,
                                    'foto_perfil': _photoKey,
                                    'telefono': _phone,
                                  },
                                );
                                
                                if (result == true) {
                                  setState(() => _isLoading = true);
                                  _loadUserData();
                                }
                              },
                            ),
                            /* _buildOptionTile(
                              icon: Icons.location_on_outlined,
                              title: 'Mis Direcciones',
                              subtitle: 'Casa, trabajo y favoritos',
                              isDark: isDark,
                              onTap: () {},
                            ), */
                            _buildInfoTile(
                              icon: Icons.payments_rounded,
                              title: 'Método de Pago',
                              subtitle: 'Solo efectivo',
                              isDark: isDark,
                            ),
                              _buildOptionTile(
                              icon: Icons.notifications_none_rounded,
                              title: 'Notificaciones',
                              subtitle: 'Promociones, estado del viaje',
                              isDark: isDark,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  RouteNames.notifications,
                                  arguments: {'userId': _userId},
                                );
                              },
                            ),
/*                              _buildOptionTile(
                              icon: Icons.help_outline_rounded,
                              title: 'Ayuda y Soporte',
                              subtitle: 'Centro de ayuda, contactar',
                              isDark: isDark,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  RouteNames.help,
                                  arguments: {
                                    'userType': 'user',
                                    'userId': _userId,
                                  },
                                );
                              },
                            ), */
                            
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
            child: _photoKey != null && _photoKey!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      UserService.getR2ImageUrl(_photoKey!),
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person_rounded,
                          size: 40,
                          color: AppColors.primary,
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Icon(
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

  void _showRejectionDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Solicitud Rechazada'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tu solicitud para ser conductor ha sido rechazada por el siguiente motivo:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Text(
                _rejectionReason ?? 'No se especificó un motivo.',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Puedes corregir tu información y enviar la solicitud nuevamente.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.pushNamed(context, RouteNames.driverRegistration);
              _loadUserData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Corregir'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildBecomeDriverCard(bool isDark) {
    // Check if user has pending/approved driver registration
    final bool hasPendingRequest = _driverStatus == 'pendiente';
    final bool isRejected = _driverStatus == 'rechazado';
    final bool isApproved = _driverStatus == 'aprobado' || _driverStatus == 'activo';
    
    // If approved, show switch to driver mode
    if (isApproved) {
      return _buildSwitchToDriverCard(isDark);
    }
    
    // Helper to configure card appearance
    Color getStartColor() {
      if (isRejected) return AppColors.error;
      if (hasPendingRequest) return Colors.orange;
      return AppColors.primary;
    }

    Color getEndColor() {
      if (isRejected) return AppColors.error.withValues(alpha: 0.8);
      if (hasPendingRequest) return Colors.orange.shade700;
      return AppColors.primary.withValues(alpha: 0.8);
    }
    
    final startColor = getStartColor();
    final endColor = getEndColor();
    // Pending or new registration or rejected
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [startColor, endColor],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: startColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
            onTap: isRejected ? () => _showRejectionDetails() : (hasPendingRequest ? null : () async {
            await Navigator.pushNamed(context, RouteNames.driverRegistration);
            _loadUserData(); // Refresh profile after return
          }),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icono decorativo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRejected ? Icons.warning_amber_rounded : (hasPendingRequest ? Icons.hourglass_top_rounded : Icons.directions_car_filled_rounded),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Texto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRejected ? 'Solicitud Rechazada' : (hasPendingRequest ? 'Solicitud en Proceso' : 'Genera Ingresos Extra'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isRejected 
                          ? 'Tu solicitud ha sido rechazada. Toca para ver los detalles.'
                          : (hasPendingRequest 
                            ? 'Tu solicitud está siendo revisada. Te notificaremos cuando sea aprobada.'
                            : 'Conviértete en conductor de Viax y maneja tu propio tiempo.'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!hasPendingRequest || isRejected)
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white70,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSwitchToDriverCard(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green, Colors.green.shade700],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(context, RouteNames.conductorHome);
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modo Conductor',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Cambiar a tu cuenta de conductor',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
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
                    _rating.toStringAsFixed(2),
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

  /// Widget informativo (sin interacción)
  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
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
                color: AppColors.success,
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
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
