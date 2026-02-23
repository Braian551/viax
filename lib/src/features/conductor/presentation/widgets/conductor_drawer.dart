import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';
import '../../../../global/services/auth/user_service.dart';
import '../../../../routes/route_names.dart';
import '../../../../widgets/dialogs/logout_dialog.dart';
import '../../services/conductor_service.dart';
import '../../../../core/utils/colombian_plate_utils.dart';

/// Menú hamburguesa del conductor con diseño moderno
class ConductorDrawer extends StatefulWidget {
  final Map<String, dynamic> conductorUser;

  const ConductorDrawer({
    super.key,
    required this.conductorUser,
  });

  @override
  State<ConductorDrawer> createState() => _ConductorDrawerState();
}

class _ConductorDrawerState extends State<ConductorDrawer> {
  String? _fotoPerfil;
  String? _tipoVehiculo;
  String? _placaVehiculo;

  String? _extractVehicleType(Map<String, dynamic>? source) {
    if (source == null) return null;
    final candidates = [
      source['tipo_vehiculo'],
      source['vehiculo_tipo'],
      source['vehicle_type'],
      source['tipoVehiculo'],
      source['tipo'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _extractPlate(Map<String, dynamic>? source) {
    if (source == null) return null;
    final candidates = [
      source['placa'],
      source['vehiculo_placa'],
      source['plate'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String _formatVehicleTypeLabel(String? rawType) {
    final normalized = (rawType ?? '').toLowerCase().replaceAll('-', ' ').trim();
    if (normalized.isEmpty) return 'Vehículo';

    if (normalized.contains('mototaxi')) return 'Mototaxi';
    if (normalized.contains('moto')) return 'Moto';
    if (normalized.contains('taxi')) return 'Taxi';
    if (normalized.contains('bicicleta') || normalized.contains('bici')) {
      return 'Bicicleta';
    }
    if (normalized.contains('camioneta')) return 'Camioneta';
    if (normalized.contains('suv')) return 'SUV';
    if (normalized.contains('carro') ||
        normalized.contains('auto') ||
        normalized.contains('sedan')) {
      return 'Carro';
    }

    return rawType!.trim().isEmpty ? 'Vehículo' : rawType.trim();
  }

  IconData _vehicleIconForType(String? rawType) {
    final normalized = (rawType ?? '').toLowerCase().replaceAll('-', ' ').trim();

    if (normalized.contains('mototaxi')) return Icons.electric_rickshaw_rounded;
    if (normalized.contains('moto')) return Icons.two_wheeler_rounded;
    if (normalized.contains('taxi')) return Icons.local_taxi_rounded;
    if (normalized.contains('bicicleta') || normalized.contains('bici')) {
      return Icons.pedal_bike_rounded;
    }
    if (normalized.contains('camioneta') || normalized.contains('suv')) {
      return Icons.airport_shuttle_rounded;
    }

    return Icons.directions_car_rounded;
  }

  @override
  void initState() {
    super.initState();
    _fotoPerfil = widget.conductorUser['foto_perfil']?.toString();
    _tipoVehiculo = _extractVehicleType(widget.conductorUser);
    _placaVehiculo = _extractPlate(widget.conductorUser);
    
    // Si no hay foto en el conductorUser, intentar obtenerla del backend
    if (_fotoPerfil == null || _fotoPerfil!.isEmpty) {
      _fetchProfilePhoto();
    }
  }

  Future<void> _fetchProfilePhoto() async {
    final conductorId = widget.conductorUser['id'];
    if (conductorId == null) return;

    try {
      final info = await ConductorService.getConductorInfo(
        int.tryParse(conductorId.toString()) ?? 0,
      );
      if (info != null && mounted) {
        final conductor = info['conductor'] is Map<String, dynamic>
            ? info['conductor'] as Map<String, dynamic>
            : null;
        final vehiculo = info['vehiculo'] is Map<String, dynamic>
            ? info['vehiculo'] as Map<String, dynamic>
            : null;

        final foto = conductor?['foto_perfil']?.toString();
        final fetchedVehicleType = _extractVehicleType(vehiculo) ?? _extractVehicleType(conductor);
        final fetchedPlate = _extractPlate(vehiculo) ?? _extractPlate(conductor);

        setState(() {
          if (foto != null && foto.isNotEmpty) {
            _fotoPerfil = foto;
          }
          if (fetchedVehicleType != null && fetchedVehicleType.isNotEmpty) {
            _tipoVehiculo = fetchedVehicleType;
          }
          if (fetchedPlate != null && fetchedPlate.isNotEmpty) {
            _placaVehiculo = fetchedPlate;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile photo for drawer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rawTipoVehiculo = _tipoVehiculo ?? _extractVehicleType(widget.conductorUser);
    final iconoVehiculo = _vehicleIconForType(rawTipoVehiculo);
    
    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
                color: isDark 
                  ? AppColors.darkBackground.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
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
                            Navigator.pushNamedAndRemoveUntil(
                              context, 
                              RouteNames.conductorHome,
                              (route) => false,
                              arguments: {'conductor_user': widget.conductorUser},
                            );
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
                              RouteNames.conductorProfile,
                              arguments: widget.conductorUser,
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
                              RouteNames.conductorTrips,
                              arguments: widget.conductorUser,
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
                              RouteNames.conductorEarnings,
                              arguments: widget.conductorUser,
                            );
                          },
                          isDark: isDark,
                        ),

                        _buildMenuItem(
                          context: context,
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'Comisiones',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(
                              context,
                              RouteNames.conductorCommissions,
                              arguments: widget.conductorUser,
                            );
                          },
                          isDark: isDark,
                        ),

                        _buildMenuItem(
                          context: context,
                          icon: Icons.notifications_rounded,
                          title: 'Notificaciones',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(
                              context,
                              RouteNames.notifications,
                              arguments: {
                                'userId': widget.conductorUser['id'],
                                'currentUser': widget.conductorUser,
                                'userType': 'conductor',
                              },
                            );
                          },
                          isDark: isDark,
                        ),
                        
                        _buildDivider(isDark),
                        
                        _buildMenuItem(
                          context: context,
                          icon: iconoVehiculo,
                          title: 'Mi Vehículo',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(
                              context,
                              RouteNames.conductorVehicle,
                              arguments: widget.conductorUser,
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
                            Navigator.pushNamed(
                              context,
                              RouteNames.conductorDocuments,
                              arguments: widget.conductorUser,
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
                            Navigator.pushNamed(
                              context,
                              RouteNames.conductorSettings,
                              arguments: widget.conductorUser,
                            );
                          },
                          isDark: isDark,
                        ),
                        
/*                         _buildMenuItem(
                           context: context,
                           icon: Icons.help_outline_rounded,
                           title: 'Ayuda y Soporte',
                           onTap: () {
                             Navigator.pop(context);
                             Navigator.pushNamed(
                               context,
                               RouteNames.conductorHelp,
                               arguments: widget.conductorUser,
                             );
                           },
                           isDark: isDark,
                         ), */
                        
                        _buildDivider(isDark),
                        
                        _buildMenuItem(
                          context: context,
                          icon: Icons.logout_rounded,
                          title: 'Cerrar Sesión',
                          isDestructive: true,
                          onTap: () async {
                            // Capturar el navigator antes de cerrar el drawer (que desmonta el widget)
                            final navigator = Navigator.of(context);
                            navigator.pop(); 
                            
                            debugPrint('DEBUG: Mostrando diálogo de logout');
                            // Usamos el contexto original para el diálogo (funciona aunque se desmonte el widget)
                            final shouldLogout = await LogoutDialog.show(context);
                            debugPrint('DEBUG: Logout confirmado? $shouldLogout');
                            
                            // Ya no verificamos context.mounted porque sabemos que el drawer fue cerrado
                            if (shouldLogout == true) {
                              debugPrint('DEBUG: Limpiando sesión...');
                              await UserService.clearSession();
                              debugPrint('DEBUG: Sesión limpiada. Navegando a welcome...');
                              
                              navigator.pushNamedAndRemoveUntil(
                                RouteNames.welcome,
                                (route) => false,
                              );
                              debugPrint('DEBUG: Navegación solicitada');
                            }
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
    final nombre = widget.conductorUser['nombre']?.toString() ?? 'Conductor';
    final rawTipoVehiculo = _tipoVehiculo ?? _extractVehicleType(widget.conductorUser);
    final tipoVehiculo = _formatVehicleTypeLabel(rawTipoVehiculo);
    final iconoVehiculo = _vehicleIconForType(rawTipoVehiculo);
    final placa = ColombianPlateUtils.formatForDisplay(
      _placaVehiculo ?? _extractPlate(widget.conductorUser),
      fallback: '',
    );
    
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
            color: AppColors.primary.withValues(alpha: 0.3),
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
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
            ),
            child: CircleAvatar(
              backgroundColor: Colors.transparent,
              backgroundImage: _fotoPerfil != null && _fotoPerfil!.isNotEmpty
                  ? NetworkImage(UserService.getR2ImageUrl(_fotoPerfil!))
                  : null,
              child: _fotoPerfil == null || _fotoPerfil!.isEmpty
                  ? Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
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
                iconoVehiculo,
                color: Colors.white.withValues(alpha: 0.9),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                tipoVehiculo,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (placa.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
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
                  color: color.withValues(alpha: 0.5),
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
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.2),
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
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.2),
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
                      ? Colors.white.withValues(alpha: 0.5)
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

}
