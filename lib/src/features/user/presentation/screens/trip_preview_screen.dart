import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/models/simple_location.dart';
import '../../../../global/services/auth/user_service.dart';
import '../../../../theme/app_colors.dart';
import '../../services/trip_request_service.dart';
import 'searching_driver_screen.dart';

/// Modelo para cotización del viaje
class TripQuote {
  final double distanceKm;
  final int durationMinutes;
  final double basePrice;
  final double distancePrice;
  final double timePrice;
  final double surchargePrice;
  final double totalPrice;
  final String periodType; // 'normal', 'hora_pico', 'nocturno'
  final double surchargePercentage;
  
  TripQuote({
    required this.distanceKm,
    required this.durationMinutes,
    required this.basePrice,
    required this.distancePrice,
    required this.timePrice,
    required this.surchargePrice,
    required this.totalPrice,
    required this.periodType,
    required this.surchargePercentage,
  });
  
  String get formattedTotal => '\$${totalPrice.toStringAsFixed(0)}';
  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';
  String get formattedDuration => '$durationMinutes min';
}

/// Segunda pantalla - Preview del viaje con mapa y cotización
/// Muestra el mapa con la ruta, información del viaje y precio calculado
class TripPreviewScreen extends StatefulWidget {
  final SimpleLocation origin;
  final SimpleLocation destination;
  final List<SimpleLocation> stops;
  final String vehicleType;
  
  const TripPreviewScreen({
    super.key,
    required this.origin,
    required this.destination,
    this.stops = const [],
    required this.vehicleType,
  });

  @override
  State<TripPreviewScreen> createState() => _TripPreviewScreenState();
}

class _TripPreviewScreenState extends State<TripPreviewScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  
  MapboxRoute? _route;
  TripQuote? _quote;
  bool _isLoadingRoute = true;
  bool _isLoadingQuote = true;
  String? _errorMessage;
  
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;
  
  late AnimationController _routeAnimationController;
  late Animation<double> _routeAnimation;
  
  late AnimationController _topPanelAnimationController;
  late Animation<Offset> _topPanelSlideAnimation;
  late Animation<double> _topPanelFadeAnimation;
  
  late AnimationController _markerAnimationController;
  late Animation<double> _markerScaleAnimation;
  late Animation<double> _markerBounceAnimation;
  
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  
  final DraggableScrollableController _draggableController = DraggableScrollableController();
  bool _isPanelExpanded = false;
  
  bool _showDetails = false;
  List<LatLng> _animatedRoutePoints = [];
  double _currentRouteProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadRouteAndQuote();
    _draggableController.addListener(_onPanelDrag);
  }

  @override
  void dispose() {
    _draggableController.removeListener(_onPanelDrag);
    _draggableController.dispose();
    _slideAnimationController.dispose();
    _routeAnimationController.dispose();
    _topPanelAnimationController.dispose();
    _markerAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  void _onPanelDrag() {
    final size = _draggableController.size;
    if (size > 0.6 && !_isPanelExpanded) {
      setState(() => _isPanelExpanded = true);
    } else if (size <= 0.6 && _isPanelExpanded) {
      setState(() => _isPanelExpanded = false);
    }
  }

  void _setupAnimations() {
    // Animación del panel inferior
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    // Animación de la línea de ruta (más suave y prolongada)
    _routeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2500), // Más lento para efecto suave
      vsync: this,
    );
    
    _routeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _routeAnimationController,
      curve: Curves.easeInOutCubic, // Curva más suave
    ));
    _routeAnimation = _routeAnimation..addListener(() {
      if (!mounted) return; // Avoid setState on unmounted widget
      if (_route != null) {
        final totalPoints = _route!.geometry.length;
        final animatedCount = (totalPoints * _routeAnimation.value).round();
        setState(() {
          _animatedRoutePoints = _route!.geometry.sublist(0, animatedCount);
          _currentRouteProgress = _routeAnimation.value;
        });
      }
    });
    
    // Animación del panel superior
    _topPanelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _topPanelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _topPanelAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _topPanelFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _topPanelAnimationController,
      curve: Curves.easeOut,
    ));
    
    // Animación de marcadores
    _markerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _markerScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _markerAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _markerBounceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _markerAnimationController,
      curve: Curves.bounceOut,
    ));
    
    // Animación de pulso para marcadores
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _loadRouteAndQuote() async {
    setState(() {
      _isLoadingRoute = true;
      _isLoadingQuote = true;
      _errorMessage = null;
    });
    
    try {
      // Prepare waypoints: Origin -> Stops -> Destination
      final waypoints = [
        widget.origin.toLatLng(),
        ...widget.stops.map((s) => s.toLatLng()),
        widget.destination.toLatLng(),
      ];

      // Obtener ruta de Mapbox
      final route = await MapboxService.getRoute(
        waypoints: waypoints,
      );
      
      if (route == null) {
        throw Exception('No se pudo calcular la ruta');
      }
      
      if (!mounted) return;
      setState(() {
        _route = route;
        _isLoadingRoute = false;
      });
      
      // Ajustar el mapa para mostrar la ruta completa con animación suave
      await _fitMapToRouteAnimated();
      if (!mounted) return;
      
      // Animar el panel superior
      _topPanelAnimationController.forward();
      if (!mounted) return;
      
      // Animar los marcadores
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      _markerAnimationController.forward();
      
      // Animar la línea de ruta
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      _routeAnimationController.forward();
      
      // Calcular cotización (por ahora localmente, luego será desde el backend)
      final quote = _calculateQuote(route);
      
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _isLoadingQuote = false;
      });
      
      // Animar la aparición del panel de detalles
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      _slideAnimationController.forward();
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoadingRoute = false;
        _isLoadingQuote = false;
      });
    }
  }

  Future<void> _fitMapToRouteAnimated() async {
    if (_route == null) return;
    
    // Encontrar los límites de la ruta
    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLng = double.infinity;
    double maxLng = double.negativeInfinity;
    
    for (var point in _route!.geometry) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    
    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
    
    // Ajustar el mapa con padding generoso para mostrar toda la ruta
    final camera = CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.only(
        top: 220,  // Espacio para el panel superior
        bottom: 380, // Espacio para el panel inferior
        left: 70,
        right: 70,
      ),
    );
    
    // Usar animación de cámara suave
    _mapController.fitCamera(camera);
    
    // Pausa para que la cámara se ajuste antes de animar elementos
    await Future.delayed(const Duration(milliseconds: 400));
  }

  /// Calcular cotización localmente (temporal)
  /// TODO: Mover esta lógica al backend
  TripQuote _calculateQuote(MapboxRoute route) {
    final hour = DateTime.now().hour;
    final distanceKm = route.distanceKm;
    final durationMinutes = route.durationMinutes.ceil();
    
    // Configuración según tipo de vehículo (estos valores vendrán del backend)
    final config = _getVehicleConfig(widget.vehicleType);
    
    // Precios base
    final basePrice = config['tarifa_base']!;
    final distancePrice = distanceKm * config['costo_por_km']!;
    final timePrice = durationMinutes * config['costo_por_minuto']!;
    
    // Determinar período y recargo
    String periodType = 'normal';
    double surchargePercentage = 0.0;
    
    if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
      periodType = 'hora_pico';
      surchargePercentage = config['recargo_hora_pico']!;
    } else if (hour >= 22 || hour <= 6) {
      periodType = 'nocturno';
      surchargePercentage = config['recargo_nocturno']!;
    }
    
    final subtotal = basePrice + distancePrice + timePrice;
    final surchargePrice = subtotal * (surchargePercentage / 100);
    final total = subtotal + surchargePrice;
    
    // Aplicar tarifa mínima
    final finalTotal = total < config['tarifa_minima']! ? config['tarifa_minima']! : total;
    
    return TripQuote(
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      basePrice: basePrice,
      distancePrice: distancePrice,
      timePrice: timePrice,
      surchargePrice: surchargePrice,
      totalPrice: finalTotal,
      periodType: periodType,
      surchargePercentage: surchargePercentage,
    );
  }

  Map<String, double> _getVehicleConfig(String vehicleType) {
    // Valores de ejemplo - estos vendrán de la tabla configuracion_precios
    switch (vehicleType) {
      case 'moto':
        return {
          'tarifa_base': 4000.0,
          'costo_por_km': 2000.0,
          'costo_por_minuto': 250.0,
          'tarifa_minima': 6000.0,
          'recargo_hora_pico': 15.0,
          'recargo_nocturno': 20.0,
        };
      case 'carro':
        return {
          'tarifa_base': 6000.0,
          'costo_por_km': 3000.0,
          'costo_por_minuto': 400.0,
          'tarifa_minima': 9000.0,
          'recargo_hora_pico': 20.0,
          'recargo_nocturno': 25.0,
        };
      case 'moto_carga':
        return {
          'tarifa_base': 5000.0,
          'costo_por_km': 2500.0,
          'costo_por_minuto': 300.0,
          'tarifa_minima': 7500.0,
          'recargo_hora_pico': 15.0,
          'recargo_nocturno': 20.0,
        };
      case 'carro_carga':
        return {
          'tarifa_base': 8000.0,
          'costo_por_km': 3500.0,
          'costo_por_minuto': 450.0,
          'tarifa_minima': 12000.0,
          'recargo_hora_pico': 20.0,
          'recargo_nocturno': 25.0,
        };
      default:
        return {
          'tarifa_base': 4000.0,
          'costo_por_km': 2000.0,
          'costo_por_minuto': 250.0,
          'tarifa_minima': 6000.0,
          'recargo_hora_pico': 15.0,
          'recargo_nocturno': 20.0,
        };
    }
  }

  String _getVehicleName(String type) {
    switch (type) {
      case 'moto': return 'Moto';
      case 'carro': return 'Carro';
      case 'moto_carga': return 'Moto Carga';
      case 'carro_carga': return 'Carro Carga';
      default: return 'Vehículo';
    }
  }

  IconData _getVehicleIcon(String type) {
    switch (type) {
      case 'moto': return Icons.two_wheeler;
      case 'carro': return Icons.directions_car;
      case 'moto_carga': return Icons.delivery_dining;
      case 'carro_carga': return Icons.local_shipping;
      default: return Icons.two_wheeler;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // Mapa
          _buildMap(isDark),
          
          // Overlay superior con información compacta
          _buildTopOverlay(isDark),
          
          // Panel inferior con detalles y precio
          if (_quote != null) _buildBottomPanel(isDark),
          
          // Indicador de carga
          if (_isLoadingRoute || _isLoadingQuote) _buildLoadingOverlay(isDark),
          
          // Mensaje de error
          if (_errorMessage != null) _buildErrorOverlay(isDark),
        ],
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.origin.toLatLng(),
        initialZoom: 14,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        // Tiles de Mapbox con estilo según el tema
        TileLayer(
          urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
          userAgentPackageName: 'com.example.ping_go',
        ),
        
        // Sombra de la ruta (efecto de profundidad)
        if (_animatedRoutePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _animatedRoutePoints,
                strokeWidth: 12,
                color: Colors.black.withOpacity(0.3),
                borderStrokeWidth: 0,
              ),
            ],
          ),
        
        // Línea de ruta principal con tema azul
        if (_animatedRoutePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _animatedRoutePoints,
                strokeWidth: 8,
                color: AppColors.primary,
                borderStrokeWidth: 0,
                gradientColors: [
                  AppColors.primaryLight,
                  AppColors.primary,
                  AppColors.primaryDark,
                ],
              ),
            ],
          ),
        
        // Marcadores de origen, destino y paradas
        MarkerLayer(
          markers: [
            // Origen
            Marker(
              point: widget.origin.toLatLng(),
              width: 80,
              height: 80,
              child: AnimatedBuilder(
                animation: _markerScaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _markerScaleAnimation.value,
                    child: child,
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulso animado de fondo
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 60 * _pulseAnimation.value,
                          height: 60 * _pulseAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryLight.withOpacity(
                              0.3 / _pulseAnimation.value,
                            ),
                          ),
                        );
                      },
                    ),
                    // Círculo exterior
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    // Punto interior
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Paradas intermedias
            ...widget.stops.asMap().entries.map((entry) {
              final index = entry.key;
              final stop = entry.value;
              return Marker(
                point: stop.toLatLng(),
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              );
            }),

            // Destino con pin moderno
            Marker(
              point: widget.destination.toLatLng(),
              width: 50,
              height: 70,
              alignment: Alignment.topCenter,
              child: AnimatedBuilder(
                animation: _markerBounceAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      0,
                      -15 * (1 - _markerBounceAnimation.value),
                    ),
                    child: Transform.scale(
                      scale: 0.3 + (_markerBounceAnimation.value * 0.7),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pin de destino
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Sombra del pin
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 3,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                        ),
                        // Círculo exterior
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryDark,
                            shape: BoxShape.circle,
                          ),
                        ),
                        // Círculo azul claro interior
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryDark,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.primaryDark,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    // Sombra proyectada en el suelo
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 30,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopOverlay(bool isDark) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _topPanelSlideAnimation,
          child: FadeTransition(
            opacity: _topPanelFadeAnimation,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark 
                    ? AppColors.darkSurface.withOpacity(0.95) 
                    : AppColors.lightSurface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark 
                        ? Colors.black.withOpacity(0.3) 
                        : Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header minimalista
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        // Botón de regresar
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => Navigator.pop(context),
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Badge de tiempo y distancia
                        if (_quote != null)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _quote!.formattedDuration,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Container(
                                      width: 2,
                                      height: 12,
                                      color: AppColors.primary.withOpacity(0.3),
                                    ),
                                  ),
                                  Icon(
                                    Icons.straighten,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _quote!.formattedDistance,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Divider sutil
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 1,
                      color: isDark 
                          ? Colors.white.withOpacity(0.1) 
                          : Colors.black.withOpacity(0.1),
                    ),
                  ),
                  
                  // Información de ubicaciones compacta
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // Origen
                        _buildCompactLocationInfo(
                          icon: Icons.circle,
                          iconSize: 8,
                          color: AppColors.primaryLight,
                          text: widget.origin.address,
                          isOrigin: true,
                          isDark: isDark,
                        ),
                        
                        // Paradas intermedias
                        for (var i = 0; i < widget.stops.length; i++) ...[
                           Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const SizedBox(width: 14),
                                Container(
                                  width: 2,
                                  height: 10,
                                  color: AppColors.primary.withOpacity(0.4),
                                ),
                              ],
                            ),
                          ),
                          _buildCompactLocationInfo(
                            icon: Icons.stop_circle_outlined,
                            iconSize: 10,
                            color: AppColors.accent,
                            text: widget.stops[i].address,
                            isOrigin: false,
                            isDark: isDark,
                          ),
                        ],

                        // Línea conectora
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              const SizedBox(width: 14),
                              SizedBox(
                                height: 20,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: List.generate(
                                    3,
                                    (index) => Container(
                                      width: 2,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Destino
                        _buildCompactLocationInfo(
                          icon: Icons.location_on,
                          iconSize: 12,
                          color: AppColors.primaryDark,
                          text: widget.destination.address,
                          isOrigin: false,
                          isDark: isDark,
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
    );
  }

  Widget _buildCompactLocationInfo({
    required IconData icon,
    required double iconSize,
    required Color color,
    required String text,
    required bool isOrigin,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.pop(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icono compacto
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Texto compacto
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark 
                        ? Colors.white.withOpacity(0.9) 
                        : AppColors.lightTextPrimary,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(bool isDark) {
    return DraggableScrollableSheet(
      controller: _draggableController,
      initialChildSize: 0.42,
      minChildSize: 0.42,
      maxChildSize: 0.75,
      snap: true,
      snapSizes: const [0.42, 0.75],
      builder: (BuildContext context, ScrollController scrollController) {
        return SlideTransition(
          position: _slideAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: isDark 
                      ? Colors.black.withOpacity(0.3) 
                      : Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark 
                          ? Colors.white.withOpacity(0.3) 
                          : Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Título de sección
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    'Selecciona tu vehículo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                
                // Tarjeta de vehículo seleccionado con precio
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Icono del vehículo
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getVehicleIcon(widget.vehicleType),
                              size: 32,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Información del vehículo
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getVehicleName(widget.vehicleType),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                  ),
                                ),
                                Text(
                                  'Llegada: ${_quote!.formattedDuration}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey[400] : AppColors.lightTextSecondary,
                                  ),
                                ),
                                Text(
                                  _getVehicleDescription(widget.vehicleType),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[500] : AppColors.lightTextHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Precio destacado
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: _quote!.totalPrice),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return Text(
                                '\$${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Botón de recargo (opcional) - más compacto
                if (_quote!.surchargePercentage > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _showDetails = !_showDetails;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _quote!.periodType == 'nocturno'
                                    ? Icons.nightlight_round
                                    : Icons.trending_up,
                                color: Colors.orange,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _quote!.periodType == 'nocturno'
                                    ? 'Tarifa nocturna (+${_quote!.surchargePercentage.toInt()}%)'
                                    : 'Hora pico (+${_quote!.surchargePercentage.toInt()}%)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[300] : AppColors.lightTextSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              _showDetails ? Icons.expand_less : Icons.expand_more,
                              color: isDark ? Colors.grey[400] : AppColors.lightTextHint,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // Desglose de precios con animación (más compacto)
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showDetails ? _buildPriceBreakdown(isDark) : const SizedBox.shrink(),
                ),
                
                // Mensaje cuando está expandido
                if (_isPanelExpanded) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.primary,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Pronto habrá más servicios',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Estamos trabajando para ofrecerte más opciones de vehículos y servicios',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : AppColors.lightTextSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                
                // Botón de solicitar viaje - más arriba y visible
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _confirmTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Solicitar viaje',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        );
      },
    );
  }
  
  String _getVehicleDescription(String type) {
    switch (type) {
      case 'moto': return 'Rápido y económico';
      case 'carro': return 'Cómodo y espacioso';
      case 'moto_carga': return 'Para paquetes pequeños';
      case 'carro_carga': return 'Para mudanzas';
      default: return 'Vehículo disponible';
    }
  }

  String _getShortAddress(String address) {
    // Si la dirección es muy larga, mostrar solo las primeras partes
    if (address.isEmpty) {
      return 'Ubicación seleccionada';
    }
    
    // Dividir por comas y tomar las primeras 2 partes
    final parts = address.split(',');
    if (parts.length > 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    
    // Si es corta, devolver tal cual
    if (address.length <= 40) {
      return address;
    }
    
    // Si es muy larga, truncar
    return '${address.substring(0, 37)}...';
  }

  Widget _buildPriceBreakdown(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.95 + (0.05 * value),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : AppColors.lightDivider,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            _buildPriceRow('Tarifa base', _quote!.basePrice, isDark: isDark),
            const SizedBox(height: 8),
            _buildPriceRow('Distancia (${_quote!.formattedDistance})', _quote!.distancePrice, isDark: isDark),
            const SizedBox(height: 8),
            _buildPriceRow('Tiempo (${_quote!.formattedDuration})', _quote!.timePrice, isDark: isDark),
            if (_quote!.surchargePrice > 0) ...[
              const SizedBox(height: 8),
              _buildPriceRow('Recargo', _quote!.surchargePrice, isHighlight: true, isDark: isDark),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: isDark ? Colors.grey[700] : AppColors.lightDivider, thickness: 1),
            ),
            _buildPriceRow('Total', _quote!.totalPrice, isBold: true, isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isBold = false, bool isHighlight = false, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isHighlight 
                  ? Colors.orange 
                  : (isDark ? Colors.grey[300] : AppColors.lightTextSecondary),
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isHighlight 
                  ? Colors.orange 
                  : (isBold ? AppColors.primary : (isDark ? Colors.white : AppColors.lightTextPrimary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay(bool isDark) {
    return Container(
      color: isDark 
          ? Colors.black.withOpacity(0.7) 
          : Colors.black.withOpacity(0.4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Calculando ruta...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(bool isDark) {
    return Container(
      color: isDark 
          ? Colors.black.withOpacity(0.7) 
          : Colors.black.withOpacity(0.4),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.red.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error al calcular ruta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Ocurrió un error inesperado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : AppColors.lightTextSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.2),
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red.withOpacity(0.5)),
                  ),
                ),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmTrip() async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );

      final user = await UserService.getSavedSession();
      
      if (user == null) {
        if (mounted) {
          Navigator.pop(context); // Cerrar loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Usuario no autenticado')),
          );
        }
        return;
      }

      // Crear solicitud en backend
      final userId = user['id'] is int ? (user['id'] as int) : int.tryParse(user['id'].toString()) ?? 0;
      final result = await TripRequestService.createTripRequest(
        userId: userId,
        latitudOrigen: widget.origin.latitude,
        longitudOrigen: widget.origin.longitude,
        direccionOrigen: widget.origin.address,
        latitudDestino: widget.destination.latitude,
        longitudDestino: widget.destination.longitude,
        direccionDestino: widget.destination.address,
        tipoServicio: 'viaje',
        tipoVehiculo: widget.vehicleType,
        distanciaKm: _quote!.distanceKm,
        duracionMinutos: _quote!.durationMinutes,
        precioEstimado: _quote!.totalPrice,
        stops: widget.stops, // Pasar paradas
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      if (result['success'] == true) {
        final solicitudId = result['solicitud_id'];
        
        // Navegar a pantalla de búsqueda de conductor
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SearchingDriverScreen(
              solicitudId: solicitudId,
              latitudOrigen: widget.origin.latitude,
              longitudOrigen: widget.origin.longitude,
              direccionOrigen: widget.origin.address,
              latitudDestino: widget.destination.latitude,
              longitudDestino: widget.destination.longitude,
              direccionDestino: widget.destination.address,
              tipoVehiculo: widget.vehicleType,
            ),
          ),
        );
      } else {
        throw Exception(result['message'] ?? 'Error al crear solicitud');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
