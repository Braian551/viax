import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/trip_request_service.dart';
import '../../../../global/services/mapbox_service.dart';
import '../../../../theme/app_colors.dart';

class SearchingDriverScreen extends StatefulWidget {
  final dynamic solicitudId; // Acepta int o String del backend
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

  /// Convierte solicitudId a int de manera segura
  int get solicitudIdAsInt {
    if (solicitudId is int) return solicitudId;
    if (solicitudId is String) return int.tryParse(solicitudId) ?? 0;
    return 0;
  }

  @override
  State<SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends State<SearchingDriverScreen> with TickerProviderStateMixin {
  Timer? _searchTimer;
  List<Map<String, dynamic>> _nearbyDrivers = [];
  bool _isCancelling = false;
  int _searchSeconds = 0;
  
  // Controladores de animación
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  
  // Animaciones
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSearching();
    
    // Iniciar animaciones de entrada
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
        _scaleController.forward();
      }
    });
  }

  void _setupAnimations() {
    // Pulso suave del círculo central
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Ondas expansivas
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    
    // Rotación sutil
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Fade de entrada
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    
    // Slide de entrada
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Scale de entrada
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    ));
  }

  void _startSearching() {
    // Actualizar contador y buscar conductores
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _searchSeconds++;
      if (_searchSeconds % 3 == 0) {
        _searchDrivers();
      }
      if (mounted) setState(() {});
    });
    // Búsqueda inicial
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

      // Si no hay conductores después de 45 segundos, mostrar mensaje
      if (_searchSeconds >= 45 && _nearbyDrivers.isEmpty) {
        _showNoDriversDialog();
      }
    }
  }

  void _showNoDriversDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.mediumImpact();
    
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ModernAlertDialog(
          icon: Icons.search_off_rounded,
          iconColor: AppColors.warning,
          title: 'Sin conductores disponibles',
          message: 'No encontramos conductores cerca de ti en este momento. ¿Deseas seguir esperando?',
          primaryButtonText: 'Seguir buscando',
          primaryButtonColor: AppColors.primary,
          secondaryButtonText: 'Cancelar viaje',
          isDark: isDark,
          onPrimaryPressed: () {
            _searchSeconds = 0;
            Navigator.of(context).pop();
          },
          onSecondaryPressed: () {
            Navigator.of(context).pop();
            _cancelTrip();
          },
        );
      },
    );
  }

  Future<void> _cancelTrip() async {
    if (_isCancelling) return;
    
    HapticFeedback.mediumImpact();
    setState(() => _isCancelling = true);
    
    try {
      final success = await TripRequestService.cancelTripRequest(widget.solicitudIdAsInt);
      if (mounted) {
        if (success) {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
          _showSuccessSnackBar('Viaje cancelado exitosamente');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        String errorMessage = e.toString().replaceFirst('Exception: ', '');
        _showErrorSnackBar(errorMessage);
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _pulseController.dispose();
    _rippleController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  String _formatSearchTime() {
    final minutes = _searchSeconds ~/ 60;
    final seconds = _searchSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // Mapa de fondo con efecto blur
          _buildMap(isDark),
          
          // Overlay gradient
          _buildGradientOverlay(isDark),

          // Contenido principal
          SafeArea(
            child: Column(
              children: [
                // Header con botón cerrar
                _buildHeader(isDark),
                
                const Spacer(),
                
                // Panel inferior con efecto glass
                _buildBottomPanel(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(widget.latitudOrigen, widget.longitudOrigen),
        initialZoom: 15,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
          userAgentPackageName: 'com.viax.app',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(widget.latitudOrigen, widget.longitudOrigen),
              width: 80,
              height: 80,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 60 + (_pulseController.value * 20),
                        height: 60 + (_pulseController.value * 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.2 * (1 - _pulseController.value)),
                        ),
                      ),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 24),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGradientOverlay(bool isDark) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (isDark ? AppColors.darkBackground : AppColors.lightBackground).withOpacity(0.3),
              (isDark ? AppColors.darkBackground : AppColors.lightBackground).withOpacity(0.0),
              (isDark ? AppColors.darkBackground : AppColors.lightBackground).withOpacity(0.0),
              (isDark ? AppColors.darkBackground : AppColors.lightBackground).withOpacity(0.95),
            ],
            stops: const [0.0, 0.2, 0.5, 0.85],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showCancelDialog(isDark);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.white.withOpacity(0.1) 
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark 
                              ? Colors.white.withOpacity(0.1) 
                              : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            const Spacer(),
            
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withOpacity(0.1) 
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark 
                          ? Colors.white.withOpacity(0.1) 
                          : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatSearchTime(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(bool isDark) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.black.withOpacity(0.6) 
                      : Colors.white.withOpacity(0.85),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(
                    color: isDark 
                        ? Colors.white.withOpacity(0.1) 
                        : Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 30,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.white.withOpacity(0.2) 
                            : Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildSearchAnimation(isDark),
                    const SizedBox(height: 24),
                    _buildStatusText(isDark),
                    const SizedBox(height: 24),
                    _buildTripInfo(isDark),
                    const SizedBox(height: 24),
                    _buildCancelButton(isDark),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAnimation(bool isDark) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_rippleController, _rotationController]),
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationController.value * 2 * 3.14159,
                child: Stack(
                  alignment: Alignment.center,
                  children: List.generate(4, (index) {
                    final delay = index * 0.25;
                    final progress = (_rippleController.value + delay) % 1.0;
                    return Container(
                      width: 160 * progress,
                      height: 160 * progress,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.5 * (1 - progress)),
                          width: 2 - progress,
                        ),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 100 + (_pulseController.value * 15),
                height: 100 + (_pulseController.value * 15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.3),
                      AppColors.primary.withOpacity(0.0),
                    ],
                  ),
                ),
              );
            },
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primaryDark,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.local_taxi_rounded,
              size: 36,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText(bool isDark) {
    return Column(
      children: [
        Text(
          'Buscando conductor',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _nearbyDrivers.isEmpty 
                ? 'Buscando conductores cerca de ti...'
                : '${_nearbyDrivers.length} conductor${_nearbyDrivers.length == 1 ? "" : "es"} disponible${_nearbyDrivers.length == 1 ? "" : "s"}',
            key: ValueKey(_nearbyDrivers.length),
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTripInfo(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark 
              ? Colors.white.withOpacity(0.05) 
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark 
                ? Colors.white.withOpacity(0.08) 
                : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Column(
          children: [
            _buildLocationRow(
              icon: Icons.circle,
              iconSize: 12,
              iconColor: AppColors.primary,
              label: 'Origen',
              value: widget.direccionOrigen,
              isDark: isDark,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Column(
                children: List.generate(3, (index) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  width: 2,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                )),
              ),
            ),
            _buildLocationRow(
              icon: Icons.location_on_rounded,
              iconSize: 18,
              iconColor: AppColors.error,
              label: 'Destino',
              value: widget.direccionDestino,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required double iconSize,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : AppColors.lightTextHint,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
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

  Widget _buildCancelButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isCancelling ? null : () {
              HapticFeedback.lightImpact();
              _showCancelDialog(isDark);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isCancelling 
                      ? Colors.grey.withOpacity(0.3)
                      : AppColors.error.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: _isCancelling
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? Colors.white54 : Colors.grey,
                          ),
                        ),
                      )
                    : Text(
                        'Cancelar búsqueda',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                          letterSpacing: -0.2,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(bool isDark) {
    if (_isCancelling) return;
    
    HapticFeedback.mediumImpact();
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ModernAlertDialog(
          icon: Icons.cancel_outlined,
          iconColor: AppColors.error,
          title: '¿Cancelar búsqueda?',
          message: 'Se cancelará tu solicitud de viaje. Esta acción no se puede deshacer.',
          primaryButtonText: 'Sí, cancelar',
          primaryButtonColor: AppColors.error,
          secondaryButtonText: 'Seguir buscando',
          isDark: isDark,
          onPrimaryPressed: () {
            Navigator.of(context).pop();
            _cancelTrip();
          },
          onSecondaryPressed: () => Navigator.of(context).pop(),
        );
      },
    );
  }
}

/// Diálogo moderno con efecto glass
class _ModernAlertDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String primaryButtonText;
  final Color primaryButtonColor;
  final String secondaryButtonText;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;
  final bool isDark;

  const _ModernAlertDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.black.withOpacity(0.7) 
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withOpacity(0.1) 
                      : Colors.black.withOpacity(0.05),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 32),
                    
                    // Icono con glow
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: iconColor.withOpacity(0.15),
                        boxShadow: [
                          BoxShadow(
                            color: iconColor.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(icon, size: 36, color: iconColor),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Título
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Mensaje
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 28),
                    
                    // Botones
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        children: [
                          // Botón primario
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                onPrimaryPressed();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryButtonColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                primaryButtonText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 10),
                          
                          // Botón secundario
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: TextButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                onSecondaryPressed();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                secondaryButtonText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
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
            ),
          ),
        ),
      ),
    );
  }
}
