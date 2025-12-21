import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:ui';
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/models/simple_location.dart';
import '../../../../theme/app_colors.dart';
import '../../domain/models/trip_models.dart';
import '../widgets/trip_preview/trip_preview_top_overlay.dart';
import '../widgets/trip_preview/trip_vehicle_bottom_sheet.dart';
import '../widgets/trip_preview/trip_vehicle_detail_sheet.dart';
import 'pickup_selection_screen.dart';

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

  bool _isSheetHidden = false;

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

    // Listen to sheet size changes to show a handle when hidden
    _draggableController.addListener(_handleSheetSizeChange);
  }

  @override
  void dispose() {
    _draggableController.removeListener(_handleSheetSizeChange);
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
          TripPreviewTopOverlay(
            slideAnimation: _topPanelSlideAnimation,
            fadeAnimation: _topPanelFadeAnimation,
            isDark: isDark,
            quote: _quote,
            origin: widget.origin,
            destination: widget.destination,
            stops: widget.stops,
            onBack: () => Navigator.pop(context),
            onLocationTap: () => Navigator.pop(context),
          ),

          // Panel inferior con detalles y precio
          if (_quote != null)
            AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              offset: _isSheetHidden ? const Offset(0, 0.15) : Offset.zero,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                opacity: _isSheetHidden ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _isSheetHidden,
                  child: TripVehicleBottomSheet(
                    controller: _draggableController,
                    slideAnimation: _slideAnimation,
                    isDark: isDark,
                    vehicles: _vehicles,
                    vehicleQuotes: _vehicleQuotes,
                    selectedVehicleType: _selectedVehicleType,
                    selectedQuote: _quote,
                    selectedVehicleName: _getVehicleName(_selectedVehicleType),
                    onVehicleTap: (vehicle, quote, isSelected) {
                      if (!isSelected) {
                        _selectVehicle(vehicle.type);
                        return;
                      }
                      if (quote != null) {
                        showTripVehicleDetailSheet(
                          context: context,
                          vehicle: vehicle,
                          quote: quote,
                          isDark: isDark,
                        );
                      }
                    },
                    onConfirm: _confirmTrip,
                  ),
                ),
              ),
            ),

          // Indicador de carga
          if (_isLoadingRoute || _isLoadingQuote) _buildLoadingOverlay(isDark),

          // Mensaje de error
          if (_errorMessage != null) _buildErrorOverlay(isDark),

          // Floating handle that appears when sheet is hidden
          if (_isSheetHidden)
            Positioned(
              bottom: 16 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    final opacity = value.clamp(0.0, 1.0);
                    final scale = (0.9 + (0.15 * value)).clamp(0.9, 1.15);
                    return Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: child,
                      ),
                    );
                  },
                  child: _HiddenSheetHandle(
                    onTap: () => _openSheet(0.42),
                    controller: _draggableController,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
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

  void _handleSheetSizeChange() {
    if (!mounted) return;
    // Only update when crossing the visibility threshold to avoid jittery rebuilds
    final currentSize = _draggableController.size;
    final shouldBeHidden = currentSize <= 0.24;
    if (shouldBeHidden != _isSheetHidden) {
      setState(() {
        _isSheetHidden = shouldBeHidden;
      });
    }
  }

  void _openSheet([double size = 0.42]) {
    if (!mounted || !_draggableController.isAttached) return;
    if (_isSheetHidden) {
      setState(() {
        _isSheetHidden = false;
      });
    }
    _draggableController.animateTo(size,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }
}

class _HiddenSheetHandle extends StatelessWidget {
  const _HiddenSheetHandle({required this.onTap, required this.controller, required this.isDark});
  final VoidCallback onTap;
  final DraggableScrollableController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta == null || !controller.isAttached) return;
        final delta = -details.primaryDelta! / 600;
        final newSize = (controller.size + delta).clamp(0.2, 0.65);
        controller.jumpTo(newSize);
      },
      onVerticalDragEnd: (details) {
        if (!controller.isAttached) return;
        final current = controller.size;
        double target;
        if (current < 0.28) {
          target = 0.2;
        } else if (current > 0.53) {
          target = 0.65;
        } else {
          target = 0.42;
        }
        controller.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      },
      child: Container(
        width: 160,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isDark ? Colors.white24 : Colors.black12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Elige tu viaje',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
