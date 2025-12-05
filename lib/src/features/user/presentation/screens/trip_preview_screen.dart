import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:ui';
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/models/simple_location.dart';
import '../../../../theme/app_colors.dart';
import 'pickup_selection_screen.dart';

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

  /// Crea una copia del quote con nuevos valores
  TripQuote copyWith({
    double? distanceKm,
    int? durationMinutes,
    double? basePrice,
    double? distancePrice,
    double? timePrice,
    double? surchargePrice,
    double? totalPrice,
    String? periodType,
    double? surchargePercentage,
  }) {
    return TripQuote(
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      basePrice: basePrice ?? this.basePrice,
      distancePrice: distancePrice ?? this.distancePrice,
      timePrice: timePrice ?? this.timePrice,
      surchargePrice: surchargePrice ?? this.surchargePrice,
      totalPrice: totalPrice ?? this.totalPrice,
      periodType: periodType ?? this.periodType,
      surchargePercentage: surchargePercentage ?? this.surchargePercentage,
    );
  }

  String get formattedTotal => '\$${totalPrice.toStringAsFixed(0)}';
  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';
  String get formattedDuration => '$durationMinutes min';
}

/// Modelo para información de vehículo
class VehicleInfo {
  final String type;
  final String name;
  final String description;
  final IconData icon;
  final String imagePath;
  final Map<String, double> config;

  const VehicleInfo({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.imagePath,
    required this.config,
  });
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

class _TripPreviewScreenState extends State<TripPreviewScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  MapboxRoute? _route;
  TripQuote? _quote;
  bool _isLoadingRoute = true;
  bool _isLoadingQuote = true;
  String? _errorMessage;

  // Vehículo seleccionado
  late String _selectedVehicleType;

  // Lista de vehículos disponibles
  final List<VehicleInfo> _vehicles = [
    VehicleInfo(
      type: 'moto',
      name: 'Moto',
      description: 'Rápido y económico',
      icon: Icons.two_wheeler,
      imagePath: 'assets/images/vehicles/moto3d.png',
      config: {
        'tarifa_base': 4000.0,
        'costo_por_km': 2000.0,
        'costo_por_minuto': 250.0,
        'tarifa_minima': 6000.0,
        'recargo_hora_pico': 15.0,
        'recargo_nocturno': 20.0,
      },
    ),
    VehicleInfo(
      type: 'auto',
      name: 'Auto',
      description: 'Cómodo y espacioso',
      icon: Icons.directions_car,
      imagePath: 'assets/images/vehicles/auto3d.png',
      config: {
        'tarifa_base': 6000.0,
        'costo_por_km': 3000.0,
        'costo_por_minuto': 400.0,
        'tarifa_minima': 9000.0,
        'recargo_hora_pico': 20.0,
        'recargo_nocturno': 25.0,
      },
    ),
    VehicleInfo(
      type: 'motocarro',
      name: 'Motocarro',
      description: 'Ideal para cargas',
      icon: Icons.electric_moped,
      imagePath: 'assets/images/vehicles/motocarro3d.png',
      config: {
        'tarifa_base': 5500.0,
        'costo_por_km': 2500.0,
        'costo_por_minuto': 350.0,
        'tarifa_minima': 8000.0,
        'recargo_hora_pico': 18.0,
        'recargo_nocturno': 22.0,
      },
    ),
  ];

  // Quotes por cada vehículo (para mostrar precios)
  final Map<String, TripQuote> _vehicleQuotes = {};

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

  // Animación para cambio de vehículo
  late AnimationController _vehicleChangeController;
  late Animation<double> _vehicleChangeAnimation;

  // Animación para el precio
  late AnimationController _priceAnimationController;
  late Animation<double> _priceAnimation;

  // Animación shimmer para efecto glass
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  final DraggableScrollableController _draggableController =
      DraggableScrollableController();
  bool _isPanelExpanded = false;

  bool _showDetails = false;
  List<LatLng> _animatedRoutePoints = [];

  // Valores animados del precio
  double _animatedPrice = 0;
  double _targetPrice = 0;

  @override
  void initState() {
    super.initState();
    _selectedVehicleType = widget.vehicleType;
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
    _vehicleChangeController.dispose();
    _priceAnimationController.dispose();
    _shimmerController.dispose();
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
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Animación de la línea de ruta (más suave y prolongada)
    _routeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _routeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _routeAnimationController,
        curve: Curves.easeInOutCubic,
      ),
    );
    _routeAnimation = _routeAnimation
      ..addListener(() {
        if (!mounted) return;
        if (_route != null) {
          final totalPoints = _route!.geometry.length;
          final animatedCount = (totalPoints * _routeAnimation.value).round();
          setState(() {
            _animatedRoutePoints = _route!.geometry.sublist(0, animatedCount);
          });
        }
      });

    // Animación del panel superior
    _topPanelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _topPanelSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _topPanelAnimationController,
            curve: Curves.easeOutBack,
          ),
        );

    _topPanelFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _topPanelAnimationController,
        curve: Curves.easeOut,
      ),
    );

    // Animación de marcadores
    _markerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _markerScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _markerAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _markerBounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _markerAnimationController,
        curve: Curves.bounceOut,
      ),
    );

    // Animación de pulso para marcadores
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Animación para cambio de vehículo
    _vehicleChangeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _vehicleChangeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _vehicleChangeController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Animación para el precio
    _priceAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _priceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _priceAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Animación shimmer
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
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
      final route = await MapboxService.getRoute(waypoints: waypoints);

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

      // Calcular cotización para todos los vehículos
      _calculateAllQuotes(route);

      if (!mounted) return;
      setState(() {
        _quote = _vehicleQuotes[_selectedVehicleType];
        _isLoadingQuote = false;
        if (_quote != null) {
          _targetPrice = _quote!.totalPrice;
          _animatedPrice = _quote!.totalPrice;
        }
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

  /// Calcula las cotizaciones para todos los vehículos
  void _calculateAllQuotes(MapboxRoute route) {
    for (var vehicle in _vehicles) {
      final quote = _calculateQuoteForVehicle(route, vehicle);
      _vehicleQuotes[vehicle.type] = quote;
    }
  }

  /// Calcula la cotización para un vehículo específico
  TripQuote _calculateQuoteForVehicle(MapboxRoute route, VehicleInfo vehicle) {
    final hour = DateTime.now().hour;
    final distanceKm = route.distanceKm;
    final durationMinutes = route.durationMinutes.ceil();

    final config = vehicle.config;

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
    final finalTotal = total < config['tarifa_minima']!
        ? config['tarifa_minima']!
        : total;

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

  /// Cambia el vehículo seleccionado con animación
  void _selectVehicle(String vehicleType) {
    if (vehicleType == _selectedVehicleType) return;

    _vehicleChangeController.forward(from: 0);

    setState(() {
      _selectedVehicleType = vehicleType;
      _quote = _vehicleQuotes[vehicleType];
      if (_quote != null) {
        _targetPrice = _quote!.totalPrice;
      }
    });

    // Animar el precio
    _animatePriceChange();
  }

  /// Anima el cambio de precio
  void _animatePriceChange() {
    final startPrice = _animatedPrice;
    final endPrice = _targetPrice;

    _priceAnimationController.reset();
    _priceAnimationController.forward();

    _priceAnimationController.addListener(() {
      if (!mounted) return;
      setState(() {
        _animatedPrice =
            startPrice + (endPrice - startPrice) * _priceAnimation.value;
      });
    });
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

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

    // Ajustar el mapa con padding generoso para mostrar toda la ruta
    final camera = CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.only(
        top: 220, // Espacio para el panel superior
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

  String _getVehicleName(String type) {
    final vehicle = _vehicles.firstWhere(
      (v) => v.type == type,
      orElse: () => _vehicles.first,
    );
    return vehicle.name;
  }

  IconData _getVehicleIcon(String type) {
    final vehicle = _vehicles.firstWhere(
      (v) => v.type == type,
      orElse: () => _vehicles.first,
    );
    return vehicle.icon;
  }

  String _getVehicleDescription(String type) {
    final vehicle = _vehicles.firstWhere(
      (v) => v.type == type,
      orElse: () => _vehicles.first,
    );
    return vehicle.description;
  }

  /// Obtiene la ruta de la imagen 3D del vehículo
  String _getVehicleImagePath(String type) {
    final vehicle = _vehicles.firstWhere(
      (v) => v.type == type,
      orElse: () => _vehicles.first,
    );
    return vehicle.imagePath;
  }

  /// Widget que muestra la imagen 3D del vehículo
  Widget _buildVehicleImage(String type, {double size = 60}) {
    return Image.asset(
      _getVehicleImagePath(type),
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback al icono si la imagen no carga
        return Icon(
          _getVehicleIcon(type),
          size: size * 0.6,
          color: AppColors.primary,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
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
                        border: Border.all(color: AppColors.primary, width: 3),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
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
                    offset: Offset(0, -15 * (1 - _markerBounceAnimation.value)),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withOpacity(0.6)
                          : Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : AppColors.primary.withOpacity(0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.08),
                          blurRadius: 25,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header con botón de regresar y badge de info
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: Row(
                            children: [
                              // Botón de regresar con efecto glass
                              _buildGlassBackButton(isDark),
                              const SizedBox(width: 12),
                              // Badge de tiempo y distancia animado
                              if (_quote != null)
                                Expanded(child: _buildInfoBadge(isDark)),
                            ],
                          ),
                        ),

                        // Divider con gradiente
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  isDark
                                      ? Colors.white.withOpacity(0.15)
                                      : Colors.black.withOpacity(0.1),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Información de ubicaciones con animación
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              // Origen
                              _buildLocationRow(
                                icon: Icons.my_location,
                                iconSize: 14,
                                color: AppColors.primary,
                                text: widget.origin.address,
                                isOrigin: true,
                                isDark: isDark,
                              ),

                              // Paradas intermedias
                              for (var i = 0; i < widget.stops.length; i++) ...[
                                _buildConnectorLine(isDark),
                                _buildLocationRow(
                                  icon: Icons.stop_circle_outlined,
                                  iconSize: 12,
                                  color: AppColors.accent,
                                  text: widget.stops[i].address,
                                  isOrigin: false,
                                  isDark: isDark,
                                ),
                              ],

                              // Línea conectora punteada
                              _buildDottedConnector(isDark),

                              // Destino
                              _buildLocationRow(
                                icon: Icons.location_on,
                                iconSize: 16,
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
          ),
        ),
      ),
    );
  }

  Widget _buildGlassBackButton(bool isDark) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pop(context),
          child: Icon(
            Icons.arrow_back_ios_new,
            size: 16,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(isDark ? 0.2 : 0.12),
              AppColors.primaryDark.withOpacity(isDark ? 0.15 : 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoChip(
              icon: Icons.access_time_rounded,
              value: _quote!.formattedDuration,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            _buildInfoChip(
              icon: Icons.straighten,
              value: _quote!.formattedDistance,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String value}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow({
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
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pop(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icono con efecto glass
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.2), width: 1),
                ),
                child: Center(
                  child: Icon(icon, size: iconSize, color: color),
                ),
              ),
              const SizedBox(width: 12),
              // Texto con animación
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isOrigin ? FontWeight.w600 : FontWeight.w500,
                    color: isDark
                        ? Colors.white.withOpacity(0.9)
                        : AppColors.lightTextPrimary,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Indicador de edición
              Icon(
                Icons.edit_outlined,
                size: 14,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectorLine(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Container(
            width: 2,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDottedConnector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 14),
          SizedBox(
            height: 22,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                4,
                (index) => Container(
                  width: 2,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.4 - (index * 0.05)),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(bool isDark) {
    return DraggableScrollableSheet(
      controller: _draggableController,
      initialChildSize: 0.42,
      minChildSize: 0.42,
      maxChildSize: 0.65,
      snap: true,
      snapSizes: const [0.42, 0.65],
      builder: (BuildContext context, ScrollController scrollController) {
        return SlideTransition(
          position: _slideAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag handle
                _buildDragHandle(isDark),

                // Título
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Elige tu viaje',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),

                // Lista de vehículos vertical
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      ..._vehicles.asMap().entries.map((entry) {
                        final index = entry.key;
                        final vehicle = entry.value;
                        return _buildVehicleListItem(vehicle, index, isDark);
                      }),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                // Botón confirmar fijo abajo
                _buildFixedConfirmButton(isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDragHandle(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: isDark ? Colors.white24 : Colors.black12,
        ),
      ),
    );
  }

  /// Item de vehículo en lista vertical (estilo DiDi/Uber)
  Widget _buildVehicleListItem(VehicleInfo vehicle, int index, bool isDark) {
    final isSelected = _selectedVehicleType == vehicle.type;
    final quote = _vehicleQuotes[vehicle.type];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          _selectVehicle(vehicle.type);
          // Si ya está seleccionado, abrir modal de detalles
          if (isSelected) {
            _showVehicleDetailsModal(vehicle, quote, isDark);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isSelected
                ? (isDark
                      ? AppColors.primary.withOpacity(0.15)
                      : AppColors.primary.withOpacity(0.08))
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.shade50),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Imagen del vehículo
              SizedBox(
                width: 60,
                height: 40,
                child: Image.asset(
                  vehicle.imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      vehicle.icon,
                      size: 32,
                      color: isDark ? Colors.white60 : Colors.black45,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Info del vehículo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          vehicle.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppColors.primary.withOpacity(0.7),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      quote != null
                          ? '${quote.formattedDuration} · ${vehicle.description}'
                          : vehicle.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),

              // Precio
              if (quote != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${quote.totalPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    if (quote.surchargePercentage > 0)
                      Text(
                        '+${quote.surchargePercentage.toInt()}% ${quote.periodType == 'nocturno' ? 'noct.' : 'pico'}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Modal de detalles del vehículo (estilo DiDi)
  void _showVehicleDetailsModal(
    VehicleInfo vehicle,
    TripQuote? quote,
    bool isDark,
  ) {
    if (quote == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle y botón cerrar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white12
                              : Colors.black.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Contenido del modal
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info del vehículo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.name,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vehicle.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Llegada: ${quote.formattedDuration}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Imagen grande del vehículo
                    Image.asset(
                      vehicle.imagePath,
                      width: 120,
                      height: 80,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          vehicle.icon,
                          size: 60,
                          color: isDark ? Colors.white38 : Colors.black26,
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Desglose de tarifas
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    // Precio total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tarifa estimada',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          '\$${quote.totalPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        color: isDark
                            ? Colors.white12
                            : Colors.black.withOpacity(0.06),
                        height: 1,
                      ),
                    ),

                    // Detalles
                    _buildDetailRow('Tarifa base', quote.basePrice, isDark),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Distancia (${quote.formattedDistance})',
                      quote.distancePrice,
                      isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Tiempo (${quote.formattedDuration})',
                      quote.timePrice,
                      isDark,
                    ),
                    if (quote.surchargePrice > 0) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        quote.periodType == 'nocturno'
                            ? 'Recargo nocturno'
                            : 'Recargo hora pico',
                        quote.surchargePrice,
                        isDark,
                        isHighlight: true,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Nota explicativa
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'El precio final puede variar según las condiciones del tráfico y la ruta tomada por el conductor.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Botón entendido
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  20,
                  24,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Fila de detalle de precio en el modal
  Widget _buildDetailRow(
    String label,
    double amount,
    bool isDark, {
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isHighlight
                ? Colors.orange
                : (isDark ? Colors.white54 : Colors.black54),
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isHighlight
                ? Colors.orange
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ],
    );
  }

  /// Botón de confirmar fijo en la parte inferior
  Widget _buildFixedConfirmButton(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Info del vehículo seleccionado
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getVehicleName(_selectedVehicleType),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  _quote != null ? _quote!.formattedTotal : '',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),

          // Botón confirmar
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _confirmTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Confirmar ${_getVehicleName(_selectedVehicleType)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.local_taxi, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Selecciona tu vehículo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSelector(bool isDark) {
    return Container(
      height: 140,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _vehicles.length,
        itemBuilder: (context, index) {
          final vehicle = _vehicles[index];
          final isSelected = _selectedVehicleType == vehicle.type;
          final quote = _vehicleQuotes[vehicle.type];

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 100)),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              final clampedOpacity = value.clamp(0.0, 1.0).toDouble();
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Opacity(opacity: clampedOpacity, child: child),
              );
            },
            child: _buildVehicleCard(vehicle, isSelected, quote, isDark),
          );
        },
      ),
    );
  }

  Widget _buildVehicleCard(
    VehicleInfo vehicle,
    bool isSelected,
    TripQuote? quote,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => _selectVehicle(vehicle.type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: 115,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.08)),
            width: isSelected ? 2.5 : 1,
          ),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(isDark ? 0.3 : 0.15),
                    AppColors.primaryDark.withOpacity(isDark ? 0.2 : 0.1),
                  ],
                )
              : null,
          color: isSelected
              ? null
              : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Imagen del vehículo con animación
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    transform: Matrix4.identity()
                      ..scale(isSelected ? 1.1 : 1.0),
                    child: Hero(
                      tag: 'vehicle_${vehicle.type}',
                      child: Image.asset(
                        vehicle.imagePath,
                        width: 50,
                        height: 35,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            vehicle.icon,
                            size: 32,
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? Colors.white70 : Colors.black54),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Nombre del vehículo
                  Text(
                    vehicle.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                                ? Colors.white
                                : AppColors.lightTextPrimary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Precio
                  if (quote != null)
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: isSelected ? 16 : 14,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                  ? Colors.white70
                                  : AppColors.lightTextSecondary),
                      ),
                      child: Text(
                        '\$${quote.totalPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                      ),
                    ),
                  // Indicador de selección
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
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

  Widget _buildPriceSection(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.9),
              isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.white.withOpacity(0.7),
            ],
          ),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Imagen del vehículo seleccionado
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: Image.asset(
                      _getVehicleImagePath(_selectedVehicleType),
                      key: ValueKey(_selectedVehicleType),
                      width: 50,
                      height: 35,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          _getVehicleIcon(_selectedVehicleType),
                          size: 35,
                          color: AppColors.primary,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Info del vehículo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _getVehicleName(_selectedVehicleType),
                          key: ValueKey('name_$_selectedVehicleType'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : AppColors.lightTextPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: isDark
                                ? Colors.white60
                                : AppColors.lightTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Llegada: ${_quote!.formattedDuration}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white60
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _getVehicleDescription(_selectedVehicleType),
                          key: ValueKey('desc_$_selectedVehicleType'),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white38
                                : AppColors.lightTextHint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Precio con animación
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      key: ValueKey('price_$_selectedVehicleType'),
                      tween: Tween(
                        begin: _animatedPrice,
                        end: _quote!.totalPrice,
                      ),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Text(
                          '\$${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: -0.5,
                          ),
                        );
                      },
                    ),
                    Text(
                      'COP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white38
                            : AppColors.lightTextHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurchargeChip(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: 0.9 + (0.1 * value), child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: InkWell(
          onTap: () => setState(() => _showDetails = !_showDetails),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.orange.withOpacity(isDark ? 0.15 : 0.1),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _quote!.periodType == 'nocturno'
                        ? Icons.nightlight_round
                        : Icons.trending_up,
                    color: Colors.orange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _quote!.periodType == 'nocturno'
                            ? 'Tarifa nocturna'
                            : 'Hora pico',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                      Text(
                        '+${_quote!.surchargePercentage.toInt()}% de recargo',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white60
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _showDetails ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withOpacity(isDark ? 0.15 : 0.08),
                AppColors.primaryDark.withOpacity(isDark ? 0.1 : 0.05),
              ],
            ),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Más servicios próximamente',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Estamos trabajando para ofrecerte más opciones',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          final clampedOpacity = value.clamp(0.0, 1.0).toDouble();
          return Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: Opacity(opacity: clampedOpacity, child: child),
          );
        },
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -5,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _confirmTrip,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Confirmar viaje',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 18,
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

  // Removed _getShortAddress: unused helper causing analyzer error

  Widget _buildPriceBreakdown(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.white.withOpacity(0.8),
              isDark
                  ? Colors.white.withOpacity(0.02)
                  : Colors.white.withOpacity(0.6),
            ],
          ),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.15)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildPriceRow('Tarifa base', _quote!.basePrice, isDark: isDark),
            const SizedBox(height: 10),
            _buildPriceRow(
              'Distancia (${_quote!.formattedDistance})',
              _quote!.distancePrice,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildPriceRow(
              'Tiempo (${_quote!.formattedDuration})',
              _quote!.timePrice,
              isDark: isDark,
            ),
            if (_quote!.surchargePrice > 0) ...[
              const SizedBox(height: 10),
              _buildPriceRow(
                'Recargo ${_quote!.periodType == 'nocturno' ? 'nocturno' : 'hora pico'}',
                _quote!.surchargePrice,
                isHighlight: true,
                isDark: isDark,
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      isDark
                          ? Colors.white.withOpacity(0.15)
                          : Colors.black.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            _buildPriceRow(
              'Total estimado',
              _quote!.totalPrice,
              isBold: true,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isHighlight = false,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (isBold)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: isBold ? 15 : 13,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  color: isHighlight
                      ? Colors.orange
                      : (isDark
                            ? Colors.white70
                            : AppColors.lightTextSecondary),
                  letterSpacing: isBold ? -0.2 : 0,
                ),
              ),
            ],
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: amount),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Text(
                '\$${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                style: TextStyle(
                  fontSize: isBold ? 16 : 13,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                  color: isHighlight
                      ? Colors.orange
                      : (isBold
                            ? AppColors.primary
                            : (isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary)),
                  letterSpacing: isBold ? -0.3 : 0,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay(bool isDark) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.8)
                    : Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
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
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(bool isDark) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.85)
                    : Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.15),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Error al calcular ruta',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage ?? 'Ocurrió un error inesperado',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white60
                          : AppColors.lightTextSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.15),
                        foregroundColor: Colors.red,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.red.withOpacity(0.3)),
                        ),
                      ),
                      child: const Text(
                        'Volver',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
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

  Future<void> _confirmTrip() async {
    if (_quote == null) return;

    // Navegar a pantalla de selección de punto de encuentro con el vehículo seleccionado
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PickupSelectionScreen(
              origin: widget.origin,
              destination: widget.destination,
              stops: widget.stops,
              vehicleType: _selectedVehicleType,
              quote: _quote!,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}
