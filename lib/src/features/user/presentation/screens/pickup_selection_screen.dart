import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../../../global/services/auth/user_service.dart';
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/models/simple_location.dart';
import '../../../../theme/app_colors.dart';
import '../../domain/models/trip_models.dart';
import '../../services/trip_request_service.dart';
import 'searching_driver_screen.dart';
import '../widgets/pickup/pickup_bottom_panel.dart';
import '../widgets/pickup/pickup_center_button.dart';
import '../widgets/pickup/pickup_center_pin.dart';
import '../widgets/pickup/pickup_header.dart';
import '../widgets/pickup/pickup_loading_overlay.dart';
import '../widgets/pickup/pickup_map.dart';
import '../widgets/pickup/pickup_snapping_indicator.dart';

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
  final int? empresaId; // ID de la empresa seleccionada para las tarifas
  final String? selectedCompanyName;
  final String? selectedCompanyLogoUrl;
  final List<Map<String, dynamic>> companyCandidates;

  const PickupSelectionScreen({
    super.key,
    required this.origin,
    required this.destination,
    this.stops = const [],
    required this.vehicleType,
    required this.quote,
    this.empresaId,
    this.selectedCompanyName,
    this.selectedCompanyLogoUrl,
    this.companyCandidates = const [],
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

  // Punto de encuentro (centro del mapa)
  LatLng? _pickupLocation;
  String _pickupAddress = 'Cargando dirección...';
  bool _isLoadingAddress = false;
  bool _isSnappingToRoad = false;

  // Estado del mapa
  bool _isMapMoving = false;
  Timer? _addressUpdateTimer;

  // Animaciones
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

  /// Ajustar coordenadas a la vía/calle más cercana usando Mapbox Map Matching
  Future<LatLng?> _snapToNearestRoad(LatLng point) async {
    try {
      // Usar el nuevo método snapToStreet que usa Map Matching API
      // Este método proyecta el punto directamente a una calle/carretera
      final snappedPoint = await MapboxService.snapToStreet(point: point);

      if (snappedPoint != null) {
        return snappedPoint;
      }

      // Si el Map Matching falla, intentar con puntos cercanos
      final offsets = [
        const LatLng(0.0003, 0.0), // Norte (~30m)
        const LatLng(-0.0003, 0.0), // Sur
        const LatLng(0.0, 0.0003), // Este
        const LatLng(0.0, -0.0003), // Oeste
      ];

      for (final offset in offsets) {
        final nearbyPoint = LatLng(
          point.latitude + offset.latitude,
          point.longitude + offset.longitude,
        );

        final nearbySnapped = await MapboxService.snapToStreet(
          point: nearbyPoint,
        );

        if (nearbySnapped != null) {
          return nearbySnapped;
        }
      }

      // Si todo falla, devolver null para indicar que no se pudo ajustar
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
      // Usar reverseGeocodeStreetOnly para solo obtener direcciones de calles, NO casas
      final place = await MapboxService.reverseGeocodeStreetOnly(
        position: _pickupLocation!,
      );

      if (mounted) {
        setState(() {
          _pickupAddress = place?.placeName ?? 'Punto de encuentro en la vía';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pickupAddress = 'Punto de encuentro en la vía';
          _isLoadingAddress = false;
        });
      }
    }
  }

  /// Convertir posición de pantalla a coordenadas geográficas
  LatLng _screenToLatLng(Offset screenPosition) {
    final camera = _mapController.camera;
    final screenSize = MediaQuery.of(context).size;

    // Centro de la pantalla
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;

    // Offset desde el centro
    final offsetX = screenPosition.dx - centerX;
    final offsetY = screenPosition.dy - centerY;

    // Convertir píxeles a coordenadas basado en el zoom
    final zoom = camera.zoom;
    final metersPerPixel =
        156543.03392 *
        math.cos(camera.center.latitude * math.pi / 180) /
        math.pow(2, zoom);

    // Calcular delta en grados
    final deltaLat = -offsetY * metersPerPixel / 111320;
    final deltaLng =
        offsetX *
        metersPerPixel /
        (111320 * math.cos(camera.center.latitude * math.pi / 180));

    return LatLng(
      camera.center.latitude + deltaLat,
      camera.center.longitude + deltaLng,
    );
  }

  /// Ajustar el punto a la calle y actualizar dirección
  Future<void> _snapAndUpdateAddress() async {
    if (_pickupLocation == null) return;

    setState(() => _isSnappingToRoad = true);

    try {
      final snappedPoint = await _snapToNearestRoad(_pickupLocation!);

      if (mounted && snappedPoint != null) {
        // Calcular si hubo movimiento significativo
        final distance = const Distance().as(
          LengthUnit.Meter,
          _pickupLocation!,
          snappedPoint,
        );

        // Solo mover si hay diferencia significativa (más de 3 metros)
        if (distance > 3) {
          // Mover el mapa para que el pin quede en la calle
          _mapController.move(snappedPoint, _mapController.camera.zoom);

          // Feedback de vibración
          HapticFeedback.lightImpact();
        }

        setState(() {
          _pickupLocation = snappedPoint;
          _isSnappingToRoad = false;
        });
      } else {
        // No se pudo ajustar a una calle - mostrar mensaje
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Intenta colocar el punto más cerca de una calle'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
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
        empresaId: widget.empresaId,
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
              clienteId: userId,
              latitudOrigen: _pickupLocation!.latitude,
              longitudOrigen: _pickupLocation!.longitude,
              direccionOrigen: _pickupAddress,
              latitudDestino: widget.destination.latitude,
              longitudDestino: widget.destination.longitude,
              direccionDestino: widget.destination.address,
              tipoVehiculo: widget.vehicleType,
              initialEmpresaId: widget.empresaId,
              initialCompanyName: widget.selectedCompanyName,
              initialCompanyLogoUrl: widget.selectedCompanyLogoUrl,
              companyCandidates: widget.companyCandidates,
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
    _addressUpdateTimer?.cancel();
    _pinBounceController.dispose();
    _panelController.dispose();
    super.dispose();
  }

  /// Callback cuando el mapa empieza a moverse
  void _onMapMoveStart() {
    if (!_isMapMoving) {
      setState(() => _isMapMoving = true);
    }
  }

  /// Callback cuando el mapa termina de moverse
  void _onMapMoveEnd() {
    _addressUpdateTimer?.cancel();
    _addressUpdateTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      // Obtener el centro actual del mapa
      final center = _mapController.camera.center;

      setState(() {
        _pickupLocation = center;
        _isMapMoving = false;
      });

      // Animar el pin y actualizar la dirección
      _pinBounceController.forward(from: 0);
      HapticFeedback.lightImpact();
      _snapAndUpdateAddress();
    });
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
          // Mapa interactivo
          PickupMap(
            mapController: _mapController,
            initialCenter: _pickupLocation ?? LatLng(widget.origin.latitude, widget.origin.longitude),
            clientLocation: _clientLocation,
            clientHeading: _clientHeading,
            isDark: isDark,
            onMapMoveStart: _onMapMoveStart,
            onMapMoveEnd: _onMapMoveEnd,
          ),

          // Pin fijo en el centro de la pantalla (no se mueve, el mapa se mueve debajo)
          PickupCenterPin(
            isMapMoving: _isMapMoving,
            pinBounceController: _pinBounceController,
            label: _isMapMoving ? 'Suelta en la calle' : _getShortAddress(),
          ),

          // Indicador de ajustando a calle
          if (_isSnappingToRoad) PickupSnappingIndicator(isDark: isDark),

          // Header con botón de volver
          PickupHeader(
            isDark: isDark,
            onBack: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(context)) Navigator.pop(context);
              });
            },
          ),

          // Botón para centrar en cliente
          PickupCenterButton(
            isDark: isDark,
            onTap: _centerOnClient,
          ),

          // Panel inferior con dirección y botón solicitar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _panelSlideAnimation,
              child: PickupBottomPanel(
                isDark: isDark,
                bottomPadding: bottomPadding,
                isLoadingAddress: _isLoadingAddress,
                isRequestingTrip: _isRequestingTrip,
                pickupAddress: _pickupAddress,
                onChangeHint: _showChangeHint,
                onRequestTrip: _requestTrip,
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading) PickupLoadingOverlay(isDark: isDark),
        ],
      ),
    );
  }

  String _getShortAddress() {
    if (_pickupAddress.isEmpty || _pickupAddress == 'Cargando dirección...') {
      return 'Punto de encuentro';
    }

    final parts = _pickupAddress.split(',');
    if (parts.isNotEmpty) {
      final firstPart = parts[0].trim();
      if (firstPart.length > 25) return '${firstPart.substring(0, 22)}...';
      return firstPart;
    }

    return 'Punto de encuentro';
  }

  void _showChangeHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mueve el mapa para cambiar el punto'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
