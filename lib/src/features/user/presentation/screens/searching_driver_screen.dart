import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/trip_request_service.dart';
import '../../../../global/services/mapbox_service.dart';
import '../../../../theme/app_colors.dart';
import 'dart:ui';

class SearchingDriverScreen extends StatefulWidget {
  final int solicitudId;
  final double latitudOrigen;
  final double longitudOrigen;
  final String direccionOrigen;
  final double latitudDestino;
  final double longitudDestino;
  final String direccionDestino;
  final String tipoVehiculo;

  const SearchingDriverScreen({
    super.key,
    required this.solicitudId,
    required this.latitudOrigen,
    required this.longitudOrigen,
    required this.direccionOrigen,
    required this.latitudDestino,
    required this.longitudDestino,
    required this.direccionDestino,
    required this.tipoVehiculo,
  });

  @override
  State<SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends State<SearchingDriverScreen> with TickerProviderStateMixin {
  Timer? _searchTimer;
  List<Map<String, dynamic>> _nearbyDrivers = [];
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  bool _isCancelling = false;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSearching();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  void _startSearching() {
    // Buscar conductores cada 3 segundos
    _searchTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _searchDrivers();
    });
    // BÃºsqueda inicial
    _searchDrivers();
  }

  Future<void> _searchDrivers() async {
    if (!mounted) return;

    final drivers = await TripRequestService.findNearbyDrivers(
      latitude: widget.latitudOrigen,
      longitude: widget.longitudOrigen,
      vehicleType: widget.tipoVehiculo,
      radiusKm: 5.0,
    );

    if (mounted) {
      setState(() {
        _nearbyDrivers = drivers;
      });

      // Si no hay conductores despuÃ©s de 30 segundos, mostrar mensaje
      if (_nearbyDrivers.isEmpty) {
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted && _nearbyDrivers.isEmpty) {
            _showNoDriversDialog();
          }
        });
      }
    }
  }

  void _showNoDriversDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => _CustomAlertDialog(
        icon: Icons.search_off_rounded,
        iconColor: AppColors.warning,
        title: 'No hay conductores disponibles',
        titleColor: AppColors.warning,
        message: 'Lo sentimos, no hay conductores disponibles en este momento. ¿Deseas seguir esperando?',
        primaryButtonText: 'Seguir esperando',
        primaryButtonColor: AppColors.primary,
        secondaryButtonText: 'Cancelar viaje',
        isDark: isDark,
        onPrimaryPressed: () => Navigator.of(context).pop(),
        onSecondaryPressed: () {
          Navigator.of(context).pop();
          _cancelTrip();
        },
      ),
    );
  }

  Future<void> _cancelTrip() async {
    if (_isCancelling) return;
    
    setState(() => _isCancelling = true);
    
    try {
      final success = await TripRequestService.cancelTripRequest(widget.solicitudId);
      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Viaje cancelado exitosamente'),
                ],
              ),
              backgroundColor: const Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        
        // Extraer el mensaje de error
        String errorMessage = e.toString().replaceFirst('Exception: ', '');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: const Color(0xFFFF5252),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // Mapa de fondo
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(widget.latitudOrigen, widget.longitudOrigen),
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
                userAgentPackageName: 'com.example.ping_go',
              ),
              // Marcador de origen
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(widget.latitudOrigen, widget.longitudOrigen),
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Overlay con información
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isDark 
                              ? AppColors.darkSurface.withOpacity(0.9) 
                              : AppColors.lightSurface.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.close, 
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                          onPressed: () {
                            _showCancelDialog(isDark);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Panel de búsqueda
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark 
                        ? AppColors.darkSurface.withOpacity(0.95) 
                        : AppColors.lightSurface.withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.1),
                        blurRadius: 30,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 32),
                      
                      // AnimaciÃ³n de bÃºsqueda con ondas expansivas
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ondas expansivas
                            ...List.generate(3, (index) {
                              return AnimatedBuilder(
                                animation: _rippleController,
                                builder: (context, child) {
                                  final delay = index * 0.33;
                                  final progress = (_rippleController.value + delay) % 1.0;
                                  return Container(
                                    width: 140 * progress,
                                    height: 140 * progress,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(0.4 * (1 - progress)),
                                        width: 2,
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
                            // Círculo central con pulso
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Container(
                                  width: 80 + (_pulseController.value * 10),
                                  height: 80 + (_pulseController.value * 10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withOpacity(0.2),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primary,
                                      ),
                                      child: Icon(
                                        Icons.person_search_rounded,
                                        size: 32,
                                        color: isDark ? AppColors.darkBackground : Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Buscando conductor',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _nearbyDrivers.isEmpty 
                              ? 'Buscando conductores disponibles cerca de ti...'
                              : '${_nearbyDrivers.length} ${_nearbyDrivers.length == 1 ? "conductor encontrado" : "conductores encontrados"}',
                          style: TextStyle(
                            color: isDark 
                                ? Colors.white.withOpacity(0.7) 
                                : AppColors.lightTextSecondary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Información del viaje
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? Colors.white.withOpacity(0.05) 
                                : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark 
                                  ? Colors.white.withOpacity(0.1) 
                                  : Colors.black.withOpacity(0.05),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildInfoRow(
                                Icons.radio_button_checked,
                                'Origen',
                                widget.direccionOrigen,
                                isDark,
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                Icons.location_on,
                                'Destino',
                                widget.direccionDestino,
                                isDark,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Botón cancelar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _isCancelling ? null : () => _showCancelDialog(isDark),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(
                                color: _isCancelling 
                                    ? Colors.grey.withOpacity(0.3)
                                    : AppColors.error.withOpacity(0.5),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              disabledForegroundColor: Colors.grey,
                            ),
                            child: _isCancelling
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                    ),
                                  )
                                : const Text(
                                    'Cancelar búsqueda',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark 
                      ? Colors.white.withOpacity(0.5) 
                      : AppColors.lightTextHint,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCancelDialog(bool isDark) {
    if (_isCancelling) return;
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => _CustomAlertDialog(
        icon: Icons.cancel_outlined,
        iconColor: AppColors.error,
        title: '¿Cancelar búsqueda?',
        titleColor: AppColors.error,
        message: '¿Estás seguro de que deseas cancelar la búsqueda de conductor? Esta acción no se puede deshacer.',
        primaryButtonText: 'Sí, cancelar',
        primaryButtonColor: AppColors.error,
        secondaryButtonText: 'Seguir buscando',
        isDark: isDark,
        onPrimaryPressed: () {
          Navigator.of(context).pop();
          _cancelTrip();
        },
        onSecondaryPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// Custom Alert Dialog siguiendo el estilo del proyecto
class _CustomAlertDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final String message;
  final String primaryButtonText;
  final Color primaryButtonColor;
  final String secondaryButtonText;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;
  final bool isDark;

  const _CustomAlertDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    required this.message,
    required this.primaryButtonText,
    required this.primaryButtonColor,
    required this.secondaryButtonText,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: iconColor.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: iconColor.withOpacity(0.15),
              blurRadius: 30,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con icono
            Container(
              padding: const EdgeInsets.only(top: 32, bottom: 20),
              child: Column(
                children: [
                  // Icono con efecto glow (sin gradiente, solo opacity)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: iconColor.withOpacity(0.15),
                    ),
                    child: Center(
                      child: Icon(icon, size: 44, color: iconColor),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Título
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Mensaje
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withOpacity(0.05) 
                      : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark 
                        ? Colors.white.withOpacity(0.1) 
                        : Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    color: isDark 
                        ? Colors.white.withOpacity(0.85) 
                        : AppColors.lightTextPrimary,
                    fontSize: 15,
                    height: 1.5,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botones
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Column(
                children: [
                  // Botón primario
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: onPrimaryPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryButtonColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        primaryButtonText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Botón secundario
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: onSecondaryPressed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                        side: BorderSide(
                          color: isDark 
                              ? Colors.white.withOpacity(0.2) 
                              : Colors.black.withOpacity(0.1),
                          width: 1.5,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        secondaryButtonText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
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
}
