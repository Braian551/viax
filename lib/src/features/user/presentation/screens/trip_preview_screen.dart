import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:ui';
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/models/simple_location.dart';
import '../../../../theme/app_colors.dart';
import '../../domain/models/trip_models.dart';
import '../../domain/models/company_vehicle_models.dart';
import '../../data/services/company_vehicle_service.dart';
import '../widgets/trip_preview/trip_preview_top_overlay.dart';
import '../widgets/trip_preview/trip_vehicle_bottom_sheet.dart';
import '../widgets/trip_preview/company_picker_sheet.dart';
import '../widgets/trip_preview/trip_vehicle_detail_sheet.dart';
import '../widgets/trip_preview/company_selector_widget.dart';
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

  // Estado de carga y datos
  bool _isLoading = true;
  CompanyVehicleResponse? _companyResponse;

  // Estado para indicar que no hay vehículos disponibles
  bool _noVehiclesAvailable = false;
  String? _noVehiclesMessage;

  // Vehículo seleccionado
  String? _selectedVehicleType;

  // Lista de vehículos disponibles (cargada del backend)
  List<VehicleInfo> _vehicles = [];

  // Mapa para rastrear empresa seleccionada por tipo de vehículo
  // Key: vehicleType, Value: empresaId
  final Map<String, int> _selectedCompanyPerVehicle = {};

  // Mapa de empresas disponibles por tipo de vehículo
  Map<String, List<CompanyVehicleOption>> _companiesPerVehicle = {};

  // Quotes calculados por tipo (para mostrar precios)
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
  // ignore: unused_field
  // late AnimationController _vehicleChangeController;
  // late Animation<double> _vehicleChangeAnimation;

  // Animación para el precio
  late AnimationController _priceAnimationController;
  late Animation<double> _priceAnimation;

  // Animación shimmer para efecto glass
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  final DraggableScrollableController _draggableController =
      DraggableScrollableController();

  bool _isSheetHidden = false;
  Timer? _sheetSizeDebounceTimer;
  bool _sheetListenerAttached = false;

  List<LatLng> _animatedRoutePoints = [];

  // Valores animados del precio
  double _animatedPrice = 0;
  double _targetPrice = 0;
  double _startPrice = 0;
  bool _priceListenerAttached = false;

  @override
  void initState() {
    super.initState();
    _selectedVehicleType = widget.vehicleType;

    try {
      _setupAnimations();
    } catch (e) {
      debugPrint('Error setting up animations: $e');
    }

    // Defer listener setup and route loading to after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        if (_draggableController.isAttached && !_sheetListenerAttached) {
          _draggableController.addListener(_handleSheetSizeChange);
          _sheetListenerAttached = true;
        }
      } catch (e) {
        debugPrint('Error adding sheet listener: $e');
      }

      _loadRouteAndQuote();
    });
  }

  @override
  void dispose() {
    _sheetSizeDebounceTimer?.cancel();
    if (_sheetListenerAttached) {
      _draggableController.removeListener(_handleSheetSizeChange);
    }
    if (_priceListenerAttached) {
      _priceAnimationController.removeListener(_onPriceAnimationTick);
    }
    _draggableController.dispose();
    _slideAnimationController.dispose();
    _routeAnimationController.dispose();
    _topPanelAnimationController.dispose();
    _markerAnimationController.dispose();
    _pulseAnimationController.dispose();
    // _vehicleChangeController.dispose();
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
  // _vehicleChangeController = AnimationController(
  //   duration: const Duration(milliseconds: 400),
  //   vsync: this,
  // );

  // _vehicleChangeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
  //   CurvedAnimation(
  //     parent: _vehicleChangeController,
  //     curve: Curves.easeOutCubic,
  //   ),
  // );

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
    
    // Listener único para animación de precio
    _priceAnimationController.addListener(_onPriceAnimationTick);
    _priceListenerAttached = true;

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

      // Obtener ruta de Mapbox con timeout para evitar spinner infinito
      final route = await MapboxService.getRoute(waypoints: waypoints).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          debugPrint('Mapbox routing timeout after 12s');
          return null;
        },
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

      // Calcular cotización para todos los vehículos (Backend)
      await _loadCompanyVehicles(route);

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
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('Timeout loading route/quote: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudo calcular la ruta (timeout). Intenta de nuevo.';
        _isLoadingRoute = false;
        _isLoadingQuote = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading route and quote: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoadingRoute = false;
        _isLoadingQuote = false;
      });
    }
  }

  Future<void> _loadCompanyVehicles(MapboxRoute route) async {
    final start = widget.origin;

    // Calor estimado
    final double distanciaKm = route.distanceKm;
    final int duracionMin = route.durationMinutes.ceil();

    // Extraer municipio
    String municipio =
        CompanyVehicleService.extractMunicipalityFromAddress(
          widget.origin.address,
        ) ??
        'Medellín';

    try {
      final response = await CompanyVehicleService.getCompaniesByMunicipality(
        latitud: start.latitude,
        longitud: start.longitude,
        municipio: municipio,
        distanciaKm: distanciaKm,
        duracionMinutos: duracionMin,
      );

      if (!mounted) return;

      if (response.success && response.vehiculosDisponibles.isNotEmpty) {
        _companyResponse = response;
        // Actualizar lista de vehículos
        _vehicles = _mapToVehicleInfo(response.vehiculosDisponibles);

        debugPrint('🚗 Vehículos mapeados: ${_vehicles.length}');
        for (var v in _vehicles) {
          debugPrint('   - ${v.type}: ${v.name}');
        }

        _companiesPerVehicle = {};

        // Limpiar quotes anteriores
        _vehicleQuotes.clear();

        // Pre-seleccionar empresas y llenar mapa
        for (var v in response.vehiculosDisponibles) {
          _companiesPerVehicle[v.tipo] = v.empresas;

          if (v.empresaRecomendada != null) {
            _selectedCompanyPerVehicle[v.tipo] = v.empresaRecomendada!.id;
            _updateQuoteForVehicle(v.tipo, v.empresaRecomendada!);
            debugPrint(
              '💰 Quote para ${v.tipo}: \$${v.empresaRecomendada!.tarifaTotal}',
            );
          }
        }

        debugPrint(
          '📊 VehicleQuotes generados: ${_vehicleQuotes.keys.toList()}',
        );
        debugPrint(
          '👥 Total conductores cerca: ${response.totalConductoresCerca}',
        );

        // Verificar si el vehículo seleccionado está disponible
        if (_vehicles.isNotEmpty &&
            !_vehicles.any((v) => v.type == _selectedVehicleType)) {
          debugPrint(
            '⚠️ Vehículo seleccionado $_selectedVehicleType no disponible, cambiando a ${_vehicles.first.type}',
          );
          _selectedVehicleType = _vehicles.first.type;
        }

        setState(() {
          _noVehiclesAvailable = false;
          _noVehiclesMessage = null;
        });
      } else {
        // No hay vehículos disponibles - determinar mensaje según la situación
        String message;
        if (!response.hasEmpresas) {
          // No hay empresas en el municipio
          message = 'No hay empresas de transporte en esta zona';
        } else if (!response.hasVehicles) {
          // Hay empresas pero no tienen vehículos configurados
          message = 'No hay vehículos disponibles en esta zona';
        } else {
          // Fallback
          message =
              response.message ?? 'No hay conductores disponibles en esta zona';
        }

        setState(() {
          _noVehiclesAvailable = true;
          _noVehiclesMessage = message;
          _vehicles = [];
          _vehicleQuotes.clear();
        });
      }
    } catch (e) {
      debugPrint('Error loading company vehicles: $e');
      // Marcar como sin vehículos en caso de error
      setState(() {
        _noVehiclesAvailable = true;
        _noVehiclesMessage = 'Error al buscar vehículos disponibles';
        _vehicles = [];
      });
    }
  }

  List<VehicleInfo> _mapToVehicleInfo(List<AvailableVehicleType> types) {
    return types.map((t) {
      IconData icon;
      String imagePath;
      String desc;
      String? pinPath;

      switch (t.tipo) {
        case 'moto':
          icon = Icons.two_wheeler;
          imagePath = 'assets/images/vehicles/moto3d.png';
          desc = 'Rápido y económico';
          break;
        case 'auto':
          icon = Icons.directions_car;
          imagePath = 'assets/images/vehicles/auto3d.png';
          desc = 'Cómodo y seguro';
          break;
        case 'motocarro':
          icon = Icons.electric_moped;
          imagePath = 'assets/images/vehicles/motocarro3d.png';
          desc = 'Ideal para cargas';
          break;
        case 'taxi':
          icon = Icons.local_taxi;
          imagePath = 'assets/images/vehicles/taxi3d.png';
          desc = 'Tradicional y confiable';
          pinPath = 'assets/images/vehicles/iconvehicles/taxiicon.png';
          break;
        default:
          icon = Icons.directions_car;
          imagePath = 'assets/images/vehicles/auto3d.png';
          desc = 'Servicio de transporte';
      }

      return VehicleInfo(
        type: t.tipo,
        name: t.nombre,
        description: desc,
        icon: icon,
        imagePath: imagePath,
        pinIconPath: pinPath,
        config: {},
      );
    }).toList();
  }

  void _updateQuoteForVehicle(String type, CompanyVehicleOption option) {
    // Usar datos de la ruta si está disponible
    final distKm = _route?.distanceKm ?? 0;
    final durMin = _route?.durationMinutes.ceil() ?? 0;

    _vehicleQuotes[type] = TripQuote(
      distanceKm: distKm,
      durationMinutes: durMin,
      basePrice: 0,
      distancePrice: 0,
      timePrice: 0,
      surchargePrice: 0,
      totalPrice: option.tarifaTotal,
      periodType: option.periodo,
      surchargePercentage: option.recargoPorcentaje,
    );
  }

  void _onCompanyChanged(String vehicleType, int newCompanyId) {
    final typeData = _companyResponse?.vehiculosDisponibles.firstWhere(
      (v) => v.tipo == vehicleType,
    );
    if (typeData == null) return;

    final newOption = typeData.empresas.firstWhere((e) => e.id == newCompanyId);

    setState(() {
      _selectedCompanyPerVehicle[vehicleType] = newCompanyId;
      _updateQuoteForVehicle(vehicleType, newOption);

      if (_selectedVehicleType == vehicleType) {
        _quote = _vehicleQuotes[vehicleType];
        if (_quote != null) {
          _targetPrice = _quote!.totalPrice;
          _animatePriceChange();
        }
      }
    });
  }

  /// Cambia el vehículo seleccionado con animación
  void _selectVehicle(String vehicleType) {
    if (vehicleType == _selectedVehicleType) return;
    
    // Check if the current price is valid before setting it as start
    if (_quote != null) {
      _startPrice = _animatedPrice;
    }

    // _vehicleChangeController.forward(from: 0); // Commented out to debug freeze

    setState(() {
      _selectedVehicleType = vehicleType;
      _quote = _vehicleQuotes[vehicleType];
      if (_quote != null) {
        _targetPrice = _quote!.totalPrice;
        
        // Removed aggressive map manipulation here if any
      }
      
      // Reset selected company for this type if necessary (cleaner logic)
      // _selectedCompanyPerVehicle.remove(vehicleType); // Is this needed? 
    });

    // Animar el precio
    _animatePriceChange();
  }

  /// Muestra el selector de empresas en un bottom sheet
  void _showCompanyPicker(BuildContext context, String vehicleType, List<CompanyVehicleOption> companies) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CompanyPickerSheet(
        companies: companies,
        selectedCompanyId: _selectedCompanyPerVehicle[vehicleType],
        isDark: Theme.of(context).brightness == Brightness.dark,
        onCompanySelected: (newId) {
          _onCompanyChanged(vehicleType, newId);
        },
      ),
    );
  }

  /// Anima el cambio de precio
  void _animatePriceChange() {
    _startPrice = _animatedPrice;
    _priceAnimationController.reset();
    _priceAnimationController.forward();
  }
  
  /// Callback para la animación de precio (listener único)
  void _onPriceAnimationTick() {
    if (!mounted) return;
    setState(() {
      _animatedPrice = _startPrice + (_targetPrice - _startPrice) * _priceAnimation.value;
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
    if (_vehicles.isEmpty) return '';

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
            onBack: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(context)) Navigator.pop(context);
              });
            },
            onLocationTap: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(context)) Navigator.pop(context);
              });
            },
          ),

          // Panel inferior con detalles y precio (siempre mostrar después de cargar)
          if (!_isLoadingRoute && !_isLoadingQuote)
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
                  child: Builder(
                    builder: (context) {
                      // Attach listener once the sheet is built and controller is ready
                      if (_draggableController.isAttached &&
                          !_sheetListenerAttached) {
                        _draggableController.addListener(
                          _handleSheetSizeChange,
                        );
                        _sheetListenerAttached = true;
                      }

                      return TripVehicleBottomSheet(
                        controller: _draggableController,
                        slideAnimation: _slideAnimation,
                        isDark: isDark,
                        vehicles: _vehicles,
                        vehicleQuotes: _vehicleQuotes,
                        selectedVehicleType: _selectedVehicleType ?? '',
                        selectedQuote: _quote,
                        selectedVehicleName: _selectedVehicleType != null
                            ? _getVehicleName(_selectedVehicleType!)
                            : '',
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
                        companiesPerVehicle: _companiesPerVehicle,
                        selectedCompanyIds: _selectedCompanyPerVehicle,
                        onCompanyChanged: _onCompanyChanged,
                        onOpenCompanyPicker: (type, companies) => _showCompanyPicker(context, type, companies),
                        noVehiclesAvailable: _noVehiclesAvailable,
                        noVehiclesMessage: _noVehiclesMessage,
                      );
                    },
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
                      child: Opacity(opacity: opacity, child: child),
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
                color: Colors.black.withValues(alpha: 0.3),
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
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.3 / _pulseAnimation.value,
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
                            color: AppColors.primary.withValues(alpha: 0.4),
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
                                color: Colors.black.withValues(alpha: 0.4),
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
                        color: Colors.black.withValues(alpha: 0.3),
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
    return _RouteLoader(isDark: isDark);
  }

  Widget _buildErrorOverlay(bool isDark) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
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
                    ? Colors.black.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.15),
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
                      color: Colors.red.withValues(alpha: 0.1),
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
                        backgroundColor: Colors.red.withValues(alpha: 0.15),
                        foregroundColor: Colors.red,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
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
              vehicleType: _selectedVehicleType ?? '',
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
    if (!mounted || !_draggableController.isAttached) return;

    // Debounce to avoid excessive rebuilds during drag
    _sheetSizeDebounceTimer?.cancel();
    _sheetSizeDebounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (!mounted || !_draggableController.isAttached) return;

      try {
        final currentSize = _draggableController.size;
        final shouldBeHidden = currentSize <= 0.24;

        // Only update when crossing the visibility threshold
        if (shouldBeHidden != _isSheetHidden) {
          if (mounted) {
            setState(() {
              _isSheetHidden = shouldBeHidden;
            });
          }
        }
      } catch (e) {
        // Ignore errors if controller is not ready
        debugPrint('Sheet size change error: $e');
      }
    });
  }

  void _openSheet([double size = 0.42]) {
    if (!mounted || !_draggableController.isAttached) return;

    try {
      if (_isSheetHidden && mounted) {
        setState(() {
          _isSheetHidden = false;
        });
      }
      _draggableController.animateTo(
        size,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      debugPrint('Error opening sheet: $e');
    }
  }
}

class _HiddenSheetHandle extends StatelessWidget {
  const _HiddenSheetHandle({
    required this.onTap,
    required this.controller,
    required this.isDark,
  });
  final VoidCallback onTap;
  final DraggableScrollableController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final current = controller.isAttached ? controller.size : 0.42;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta == null || !controller.isAttached) return;
        try {
          final delta = -details.primaryDelta! / 600;
          final newSize = (controller.size + delta).clamp(0.2, 0.65);
          controller.jumpTo(newSize);
        } catch (e) {
          // Ignore if controller not ready
        }
      },
      onVerticalDragEnd: (details) {
        if (!controller.isAttached) return;
        try {
          double target;
          final currentSize = controller.isAttached ? controller.size : current;

          if (currentSize < 0.28) {
            target = 0.2;
          } else if (currentSize > 0.53) {
            target = 0.65;
          } else {
            target = 0.42;
          }
          controller.animateTo(
            target,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } catch (e) {
          // Ignore if controller not ready
        }
      },
      child: Container(
        width: 160,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bar centered at the top of the handle
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
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

class _RouteLoader extends StatefulWidget {
  final bool isDark;

  const _RouteLoader({super.key, required this.isDark});

  @override
  State<_RouteLoader> createState() => _RouteLoaderState();
}

class _RouteLoaderState extends State<_RouteLoader>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Slower, more elegant rotation
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Elegant Glass Card Design
    return Container(
      color: Colors.black.withValues(alpha: 0.3), // Clearer background
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2), // Subtle blur
        child: Center(
          child: RepaintBoundary(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: widget.isDark 
                    ? const Color(0xFF1E1E1E).withValues(alpha: 0.9) 
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.isDark 
                      ? Colors.white.withValues(alpha: 0.1) 
                      : Colors.black.withValues(alpha: 0.05),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animation Container
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Subtle breathing glow
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 60 + (_pulseController.value * 20),
                              height: 60 + (_pulseController.value * 20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(
                                  alpha: 0.15 * (1 - _pulseController.value),
                                ),
                              ),
                            );
                          },
                        ),
                        
                        // Thin Radar Ring
                        RotationTransition(
                          turns: _radarController,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.primary.withValues(alpha: 0.1),
                                  AppColors.primary,
                                ],
                                stops: const [0.0, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                        
                        // Center Icon
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_car_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // App-consistent Typography
                  Text(
                    'Calculando ruta...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.white : AppColors.lightTextPrimary,
                      letterSpacing: -0.2, // Matches app standard
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Buscando las mejores opciones',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: widget.isDark 
                          ? Colors.white.withValues(alpha: 0.6) 
                          : AppColors.lightTextSecondary,
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

  // Removed _buildRipple as we switched to a simpler breathing effect
}
