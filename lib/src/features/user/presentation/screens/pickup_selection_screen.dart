import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/services/auth/user_service.dart';
import '../../../../global/models/simple_location.dart';
import '../../../../theme/app_colors.dart';
import '../../services/trip_request_service.dart';
import 'trip_preview_screen.dart';
import 'searching_driver_screen.dart';

/// Pantalla para seleccionar el punto de encuentro
/// Similar a Didi: muestra un pin arrastrable sobre el mapa
/// El pin se ajusta automáticamente a la calle/vía más cercana
/// Muestra la ubicación del cliente en tiempo real
class PickupSelectionScreen extends StatefulWidget {
  final SimpleLocation origin;
  final SimpleLocation destination;
  final List<SimpleLocation> stops;
  final String vehicleType;
  final TripQuote quote;

  const PickupSelectionScreen({
    super.key,
    required this.origin,
    required this.destination,
    this.stops = const [],
    required this.vehicleType,
    required this.quote,
  });

  @override
  State<PickupSelectionScreen> createState() => _PickupSelectionScreenState();
}

class _PickupSelectionScreenState extends State<PickupSelectionScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Ubicación del cliente
  LatLng? _clientLocation;
  double _clientHeading = 0.0;
  StreamSubscription<geo.Position>? _positionStream;

  // Punto de encuentro (pin arrastrable)
  LatLng? _pickupLocation;
  String _pickupAddress = 'Cargando dirección...';
  bool _isDraggingPin = false;
  bool _isLoadingAddress = false;
  bool _isSnappingToRoad = false;

  // Key para el mapa
  final GlobalKey _mapKey = GlobalKey();

  // Animaciones
  late AnimationController _pulseController;
  late AnimationController _pinBounceController;
  late AnimationController _panelController;
  late Animation<Offset> _panelSlideAnimation;

  // Estado
  bool _isLoading = true;
  bool _isRequestingTrip = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startLocationTracking();
  }

  void _initAnimations() {
    // Animación de pulso para el punto del cliente
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Animación de rebote del pin al soltar
    _pinBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Animación del panel inferior
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _panelSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(parent: _panelController, curve: Curves.easeOutCubic),
        );
  }

  Future<void> _startLocationTracking() async {
    try {
      // Obtener ubicación inicial
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );

      if (mounted) {
        final clientPos = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _clientLocation = clientPos;
          _clientHeading = pos.heading;
          _isLoading = false;
        });

        // Generar punto de encuentro inicial (en calle cercana)
        await _generateInitialPickupPoint(clientPos);

        // Mover mapa y mostrar panel
        _mapController.move(_pickupLocation ?? clientPos, 17.0);
        _panelController.forward();
      }

      // Iniciar stream de posición con heading
      _positionStream = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(_onPositionUpdate);
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        // Usar ubicación del origen como fallback
        final fallback = LatLng(
          widget.origin.latitude,
          widget.origin.longitude,
        );
        await _generateInitialPickupPoint(fallback);
        _mapController.move(_pickupLocation ?? fallback, 17.0);
        _panelController.forward();
      }
    }
  }

  void _onPositionUpdate(geo.Position pos) {
    if (!mounted) return;
    setState(() {
      _clientLocation = LatLng(pos.latitude, pos.longitude);
      _clientHeading = pos.heading;
    });
  }

  /// Generar punto de encuentro inicial en la calle más cercana
  Future<void> _generateInitialPickupPoint(LatLng clientPos) async {
    setState(() => _isSnappingToRoad = true);

    try {
      // Usar la API de snap-to-road de Mapbox (Map Matching API)
      final snappedPoint = await _snapToNearestRoad(clientPos);

      if (mounted) {
        setState(() {
          _pickupLocation = snappedPoint ?? clientPos;
          _isSnappingToRoad = false;
        });

        // Obtener dirección del punto
        await _updatePickupAddress();
      }
    } catch (e) {
      debugPrint('Error snapping to road: $e');
      if (mounted) {
        setState(() {
          _pickupLocation = clientPos;
          _isSnappingToRoad = false;
        });
        await _updatePickupAddress();
      }
    }
  }

  /// Ajustar coordenadas a la vía/calle más cercana usando Mapbox
  Future<LatLng?> _snapToNearestRoad(LatLng point) async {
    try {
      // Usar geocodificación inversa solo para calles/direcciones
      final place = await MapboxService.reverseGeocodeStreetOnly(
        position: point,
      );

      if (place != null && place.placeType == 'address') {
        // Tenemos una dirección de calle, usar sus coordenadas
        return place.coordinates;
      }

      // Si no encontramos una calle cercana, buscar en un radio mayor
      // intentando diferentes puntos alrededor
      final offsets = [
        const LatLng(0.0002, 0.0), // Norte
        const LatLng(-0.0002, 0.0), // Sur
        const LatLng(0.0, 0.0002), // Este
        const LatLng(0.0, -0.0002), // Oeste
        const LatLng(0.00015, 0.00015), // Noreste
        const LatLng(-0.00015, 0.00015), // Sureste
        const LatLng(0.00015, -0.00015), // Noroeste
        const LatLng(-0.00015, -0.00015), // Suroeste
      ];

      for (final offset in offsets) {
        final nearbyPoint = LatLng(
          point.latitude + offset.latitude,
          point.longitude + offset.longitude,
        );

        final nearbyPlace = await MapboxService.reverseGeocodeStreetOnly(
          position: nearbyPoint,
        );

        if (nearbyPlace != null && nearbyPlace.placeType == 'address') {
          return nearbyPlace.coordinates;
        }
      }

      // Si no encontramos nada, devolver el punto original
      // pero intentar obtener al menos una dirección
      if (place != null) {
        return place.coordinates;
      }

      return null;
    } catch (e) {
      debugPrint('Error in snap to road: $e');
      return null;
    }
  }

  /// Actualizar la dirección del punto de encuentro
  Future<void> _updatePickupAddress() async {
    if (_pickupLocation == null) return;

    setState(() => _isLoadingAddress = true);

    try {
      final place = await MapboxService.reverseGeocode(
        position: _pickupLocation!,
      );

      if (mounted) {
        setState(() {
          _pickupAddress = place?.placeName ?? 'Ubicación seleccionada';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pickupAddress = 'Ubicación seleccionada';
          _isLoadingAddress = false;
        });
      }
    }
  }

  /// Manejar cuando el usuario mueve el mapa (arrastra el pin virtualmente)
  void _onMapMove(MapCamera camera, bool hasGesture) {
    if (hasGesture && !_isDraggingPin) {
      setState(() => _isDraggingPin = true);
    }
  }

  /// Manejar cuando el usuario suelta el mapa
  Future<void> _onMapMoveEnd(MapCamera camera) async {
    if (!_isDraggingPin) return;

    setState(() {
      _isDraggingPin = false;
      _pickupLocation = camera.center;
    });

    // Animar rebote del pin
    _pinBounceController.forward(from: 0);

    // Ajustar a la calle más cercana
    await _snapAndUpdateAddress();
  }

  /// Ajustar el punto a la calle y actualizar dirección
  Future<void> _snapAndUpdateAddress() async {
    if (_pickupLocation == null) return;

    setState(() => _isSnappingToRoad = true);

    try {
      final snappedPoint = await _snapToNearestRoad(_pickupLocation!);

      if (mounted && snappedPoint != null) {
        // Mover el mapa para que el pin quede centrado en la nueva posición
        _mapController.move(snappedPoint, _mapController.camera.zoom);

        setState(() {
          _pickupLocation = snappedPoint;
          _isSnappingToRoad = false;
        });
      } else {
        setState(() => _isSnappingToRoad = false);
      }

      await _updatePickupAddress();
    } catch (e) {
      setState(() => _isSnappingToRoad = false);
      await _updatePickupAddress();
    }
  }

  /// Centrar mapa en la ubicación del cliente
  void _centerOnClient() {
    if (_clientLocation != null) {
      _mapController.move(_clientLocation!, 17.0);
    }
  }

  /// Solicitar el viaje
  Future<void> _requestTrip() async {
    if (_pickupLocation == null) return;

    setState(() => _isRequestingTrip = true);

    try {
      final user = await UserService.getSavedSession();

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Usuario no autenticado')),
          );
          setState(() => _isRequestingTrip = false);
        }
        return;
      }

      final userId = user['id'] is int
          ? (user['id'] as int)
          : int.tryParse(user['id'].toString()) ?? 0;

      // Crear solicitud con el punto de encuentro seleccionado
      final result = await TripRequestService.createTripRequest(
        userId: userId,
        latitudOrigen: _pickupLocation!.latitude,
        longitudOrigen: _pickupLocation!.longitude,
        direccionOrigen: _pickupAddress,
        latitudDestino: widget.destination.latitude,
        longitudDestino: widget.destination.longitude,
        direccionDestino: widget.destination.address,
        tipoServicio: 'viaje',
        tipoVehiculo: widget.vehicleType,
        distanciaKm: widget.quote.distanceKm,
        duracionMinutos: widget.quote.durationMinutes,
        precioEstimado: widget.quote.totalPrice,
        stops: widget.stops,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final solicitudId = result['solicitud_id'];

        // Navegar a pantalla de búsqueda de conductor
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SearchingDriverScreen(
              solicitudId: solicitudId,
              latitudOrigen: _pickupLocation!.latitude,
              longitudOrigen: _pickupLocation!.longitude,
              direccionOrigen: _pickupAddress,
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
        setState(() => _isRequestingTrip = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _pulseController.dispose();
    _pinBounceController.dispose();
    _panelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: Stack(
        children: [
          // Mapa
          _buildMap(isDark),

          // Pin CENTRADO en la pantalla (estilo Uber/Didi)
          _buildCenteredPin(isDark),

          // Indicador de ajustando a calle
          if (_isSnappingToRoad) _buildSnappingIndicator(isDark),

          // Header con botón de volver
          _buildHeader(isDark),

          // Botón para centrar en cliente
          _buildCenterButton(isDark),

          // Panel inferior con dirección y botón solicitar
          _buildBottomPanel(isDark, bottomPadding),

          // Loading overlay
          if (_isLoading) _buildLoadingOverlay(isDark),
        ],
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    return FlutterMap(
      key: _mapKey,
      mapController: _mapController,
      options: MapOptions(
        initialCenter:
            _pickupLocation ??
            LatLng(widget.origin.latitude, widget.origin.longitude),
        initialZoom: 17.0,
        minZoom: 10,
        maxZoom: 19,
        onPositionChanged: _onMapMove,
        onMapEvent: (event) {
          if (event is MapEventMoveEnd) {
            _onMapMoveEnd(_mapController.camera);
          }
        },
      ),
      children: [
        // Tiles de Mapbox
        TileLayer(
          urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
          userAgentPackageName: 'com.viax.app',
        ),

        // Marcador del cliente (punto azul con linterna)
        if (_clientLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _clientLocation!,
                width: 70,
                height: 70,
                child: _buildClientMarker(),
              ),
            ],
          ),
      ],
    );
  }

  /// Pin CENTRADO en la pantalla (estilo Uber/Didi)
  /// El usuario mueve el mapa, el pin siempre está en el centro
  Widget _buildCenteredPin(bool isDark) {
    return Center(
      child: Padding(
        // Offset para que el pin quede un poco arriba del centro (por el panel)
        padding: const EdgeInsets.only(bottom: 180),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Etiqueta con dirección
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isDraggingPin ? 0.0 : 1.0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoadingAddress)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white70,
                          ),
                        ),
                      )
                    else
                      const Icon(Icons.place, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        _getShortAddress(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Triángulo
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isDraggingPin ? 0.0 : 1.0,
              child: CustomPaint(
                size: const Size(16, 8),
                painter: _TrianglePainter(color: const Color(0xFF00C853)),
              ),
            ),

            const SizedBox(height: 2),

            // Pin con animación de rebote y elevación al arrastrar
            AnimatedBuilder(
              animation: _pinBounceController,
              builder: (context, child) {
                final bounce =
                    math.sin(_pinBounceController.value * math.pi) * 8;
                return Transform.translate(
                  // Elevar el pin cuando está arrastrando
                  offset: Offset(0, _isDraggingPin ? -20 : -bounce),
                  child: Transform.scale(
                    scale: _isDraggingPin ? 1.1 : 1.0,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cabeza del pin
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF00E676), Color(0xFF00C853)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF00C853,
                          ).withOpacity(_isDraggingPin ? 0.6 : 0.4),
                          blurRadius: _isDraggingPin ? 20 : 12,
                          spreadRadius: _isDraggingPin ? 4 : 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_pin_circle,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),

                  // Aguja del pin
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF00C853),
                          const Color(0xFF00C853).withOpacity(0.3),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(2),
                        bottomRight: Radius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sombra en el suelo
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isDraggingPin ? 30 : 16,
              height: _isDraggingPin ? 12 : 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(_isDraggingPin ? 0.15 : 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Obtener dirección corta para el label
  String _getShortAddress() {
    if (_pickupAddress.isEmpty || _pickupAddress == 'Cargando dirección...') {
      return 'Punto de encuentro';
    }
    // Tomar solo la primera parte de la dirección
    final parts = _pickupAddress.split(',');
    if (parts.isNotEmpty) {
      final firstPart = parts[0].trim();
      if (firstPart.length > 25) {
        return '${firstPart.substring(0, 22)}...';
      }
      return firstPart;
    }
    return 'Punto de encuentro';
  }

  /// Indicador de ajustando a calle
  Widget _buildSnappingIndicator(bool isDark) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Ajustando a la calle más cercana...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Marcador del cliente (punto azul con linterna)
  Widget _buildClientMarker() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return SizedBox(
          width: 70,
          height: 70,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Cono de luz/linterna
              Positioned(
                top: 0,
                child: Transform.rotate(
                  angle: (_clientHeading) * (math.pi / 180),
                  alignment: Alignment.bottomCenter,
                  child: ClipPath(
                    clipper: _BeamClipper(),
                    child: Container(
                      width: 50,
                      height: 35,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.primary.withOpacity(0.5),
                            AppColors.primary.withOpacity(0.15),
                            AppColors.primary.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Círculo de precisión GPS
              Container(
                width: 28 + (_pulseController.value * 6),
                height: 28 + (_pulseController.value * 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(
                    0.15 * (1 - _pulseController.value),
                  ),
                ),
              ),

              // Punto central azul
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Botón volver
              Material(
                color: isDark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: 2,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.arrow_back,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Título
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    'Selecciona punto de encuentro',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton(bool isDark) {
    return Positioned(
      right: 16,
      bottom: 220,
      child: Material(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 3,
        child: InkWell(
          onTap: _centerOnClient,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.my_location, color: AppColors.primary, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(bool isDark, double bottomPadding) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SlideTransition(
        position: _panelSlideAnimation,
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[600] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Título
              Text(
                'Punto de encuentro sugerido',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Otros pasajeros han usado este punto de encuentro',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),

              // Dirección con botón cambiar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isLoadingAddress)
                            Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDark ? Colors.white54 : Colors.black54,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Obteniendo dirección...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              _pickupAddress,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // El usuario puede mover el mapa para cambiar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Mueve el mapa para cambiar el punto',
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      child: Text(
                        'Cambiar',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Botón Solicitar
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isRequestingTrip || _isLoadingAddress
                      ? null
                      : _requestTrip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isRequestingTrip
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Solicitar',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(bool isDark) {
    return Container(
      color: isDark ? Colors.black54 : Colors.white70,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Obteniendo ubicación...',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CustomClipper para el cono de luz estilo linterna
class _BeamClipper extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size size) {
    final path = ui.Path();
    path.moveTo(size.width / 2, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<ui.Path> oldClipper) => false;
}

/// CustomPainter para dibujar un triángulo (flecha del tooltip)
class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
