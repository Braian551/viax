import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';
import '../../../../global/services/auth/user_service.dart';

/// Menú hamburguesa del conductor con diseño moderno
class ConductorDrawer extends StatelessWidget {
  final Map<String, dynamic> conductorUser;

  const ConductorDrawer({
    super.key,
    required this.conductorUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark 
                  ? AppColors.darkBackground.withOpacity(0.95)
                  : Colors.white.withOpacity(0.95),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header del drawer con información del conductor
                  _buildDrawerHeader(context, isDark),
                  
                  const SizedBox(height: 8),
                  
                  // Opciones del menú
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _buildMenuItem(
                          context: context,
                          icon: Icons.home_rounded,
                          title: 'Inicio',
                          onTap: () {
                            Navigator.pop(context);
                          },
                          isDark: isDark,
                        ),
                        
                        _buildMenuItem(
                          context: context,
                          icon: Icons.person_rounded,
                          title: 'Mi Perfil',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(
                              context, 
                              '/conductor/profile',
                              arguments: conductorUser,
                            );
                          },
                          isDark: isDark,
                        ),
                        
                        _buildMenuItem(
                          context: context,
                          icon: Icons.history_rounded,
                          title: 'Historial de Viajes',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(
                              context, 
                              '/conductor/trips',
                              arguments: conductorUser,
                            );
                          },
                          isDark: isDark,
                        ),
                        
                        _buildMenuItem(
                          context: context,
                          icon: Icons.payments_rounded,
                          title: 'Mis Ganancias',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(
                              context, 
                              '/conductor/earnings',
                              arguments: conductorUser,
                            );
                          },
                          isDark: isDark,
                        ),
                        
                        _buildDivider(isDark),
                        
                        _buildMenuItem(
                          context: context,
                          icon: Icons.directions_car_rounded,
                          title: 'Mi Vehículo',
                          onTap: () {
                            Navigator.pop(context);
                            // TODO: Navegar a pantalla de vehículo
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Próximamente: Gestión de vehículo'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          isDark: isDark,
                        ),
                        
                        _buildMenuItem(
                          context: context,
                          icon: Icons.verified_user_rounded,
                          title: 'Documentos',
                          onTap: () {
                            Navigator.pop(context);
                            // TODO: Navegar a pantalla de documentos
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Próximamente: Gestión de documentos'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          isDark: isDark,
                        ),
                        
                        _buildDivider(isDark),
                        
                        _buildMenuItem(
                          context: context,
                          icon: Icons.settings_rounded,
                          title: 'Configuración',
                          onTap: () {
                            Navigator.pop(context);
                            // TODO: Navegar a configuración
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Próximamente: Configuración'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          isDark: isDark,
                        ),
                        
                        _buildMenuItem(
                          context: context,
                          icon: Icons.help_outline_rounded,
                          title: 'Ayuda y Soporte',
                          onTap: () {
                            Navigator.pop(context);
                            // TODO: Navegar a ayuda
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Próximamente: Centro de ayuda'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          isDark: isDark,
                        ),
                        
                        _buildDivider(isDark),
                        
                        _buildMenuItem(
                          context: context,
                          icon: Icons.logout_rounded,
                          title: 'Cerrar Sesión',
                          isDestructive: true,
                          onTap: () {
                            _showLogoutDialog(context, isDark);
                          },
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  
                  // Footer con versión
                  _buildDrawerFooter(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, bool isDark) {
    final nombre = conductorUser['nombre']?.toString() ?? 'Conductor';
    final tipoVehiculo = conductorUser['tipo_vehiculo']?.toString() ?? 'Vehículo';
    final placa = conductorUser['placa']?.toString() ?? '';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : 'C',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Nombre del conductor
          Text(
            nombre,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Información del vehículo
          Row(
            children: [
              Icon(
                Icons.directions_car,
                color: Colors.white.withOpacity(0.9),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                tipoVehiculo,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (placa.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    placa,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
    bool isDestructive = false,
  }) {
    final color = isDestructive 
        ? Colors.red 
        : (isDark ? Colors.white : Colors.grey[800]!);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: color.withOpacity(0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDark 
            ? Colors.white.withOpacity(0.1)
            : Colors.grey.withOpacity(0.2),
      ),
    );
  }

  Widget _buildDrawerFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Divider(
            height: 1,
            thickness: 1,
            color: isDark 
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.2),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 20,
                height: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Viax Driver v1.0.0',
                style: TextStyle(
                  color: isDark 
                      ? Colors.white.withOpacity(0.5)
                      : Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: Colors.red,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Text(
            '¿Estás seguro que deseas cerrar sesión?',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey[700],
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Cerrar dialog
                Navigator.of(dialogContext).pop();
                // Cerrar drawer
                Navigator.of(context).pop();
                
                // Cerrar sesión
                await UserService.clearSession();
                
                // Navegar a login
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
