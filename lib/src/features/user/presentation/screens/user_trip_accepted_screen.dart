import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/services/sound_service.dart';
import '../../../../theme/app_colors.dart';
import '../../services/trip_request_service.dart';
import '../widgets/user_trip_accepted/user_trip_accepted_driver_panel.dart';
import '../widgets/user_trip_accepted/user_trip_accepted_focus_button.dart';
import '../widgets/user_trip_accepted/user_trip_accepted_header.dart';
import '../widgets/user_trip_accepted/user_trip_accepted_map.dart';

/// Pantalla que muestra cuando el conductor aceptó el viaje
/// El cliente debe dirigirse al punto de encuentro
/// Muestra:
/// - Mapa con ubicación en tiempo real del cliente (con giroscopio/brújula)
/// - Punto de encuentro (origen del viaje)
/// - Ubicación del conductor en tiempo real
/// - Info del conductor (nombre, vehículo, placa, calificación)
/// - Botones de llamar/mensaje
class UserTripAcceptedScreen extends StatefulWidget {
  final int solicitudId;
  final double latitudOrigen;
  final double longitudOrigen;
  final String direccionOrigen;
  final double latitudDestino;
  final double longitudDestino;
  final String direccionDestino;
  final Map<String, dynamic>? conductorInfo;

  const UserTripAcceptedScreen({
    super.key,
    required this.solicitudId,
    required this.latitudOrigen,
    required this.longitudOrigen,
    required this.direccionOrigen,
    required this.latitudDestino,
    required this.longitudDestino,
    required this.direccionDestino,
    this.conductorInfo,
  });

  @override
  State<UserTripAcceptedScreen> createState() => _UserTripAcceptedScreenState();
}

class _UserTripAcceptedScreenState extends State<UserTripAcceptedScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Ubicación del cliente
  LatLng? _clientLocation;
  double _clientHeading = 0.0; // Orientación del dispositivo (brújula)
  StreamSubscription<geo.Position>? _positionStream;

  // Info del conductor (actualizada con polling)
  Map<String, dynamic>? _conductor;
  LatLng? _conductorLocation;
  LatLng? _lastConductorLocation; // Para detectar movimiento
  double _conductorHeading = 0.0; // Dirección del conductor calculada
  double? _conductorEtaMinutes;
  double? _conductorDistanceKm;

  // Ruta del conductor al punto de encuentro
  List<LatLng> _conductorRoute = [];
  List<LatLng> _animatedRoute = []; // Para animación de la ruta
  bool _isLoadingRoute = false;

  // Polling para actualizar estado
  Timer? _statusTimer;

  // Animaciones
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _panelController;
  late AnimationController _routeAnimationController;
  late AnimationController _cameraAnimationController;

  // Estado de la UI
  bool _isLoading = true;
  String _tripState = 'aceptada';
  bool _isFocusedOnClient = false; // Toggle para el botón de enfoque
  bool _initialAnimationDone = false;

  // Evitar repetir alertas
  bool _driverArrivedDialogShown = false;
  bool _driverArrivedDialogShowing = false;

  // Key y altura del panel para posicionar botones flotantes
  final GlobalKey _driverPanelKey = GlobalKey();
  double? _driverPanelHeight;
  // Offset extra para separar el botón de enfoque del panel (aumenta para subirlo más)
  double _focusButtonExtraOffset = 40.0;

  void _measureDriverPanel() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final ctx = _driverPanelKey.currentContext;
        if (ctx == null) return;
        final box = ctx.findRenderObject() as RenderBox?;
        if (box == null) return;
        final h = box.size.height;
        if (mounted && (_driverPanelHeight == null || (_driverPanelHeight! - h).abs() > 1)) {
          setState(() {
            _driverPanelHeight = h;
          });
        }
      } catch (e) {
        // no-op
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _conductor = widget.conductorInfo;
    _startLocationTracking();
    _startStatusPolling();
    _playAcceptedSound();

    // Medir panel después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureDriverPanel());
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Animación para dibujar la ruta progresivamente
    _routeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _routeAnimationController.addListener(_updateAnimatedRoute);

    // Animación para movimientos de cámara suaves
    _cameraAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  void _updateAnimatedRoute() {
    if (_conductorRoute.isEmpty) return;
    final progress = _routeAnimationController.value;
    final pointCount = (_conductorRoute.length * progress).round();
    if (mounted) {
      setState(() {
        _animatedRoute = _conductorRoute.sublist(
          0,
          pointCount.clamp(0, _conductorRoute.length),
        );
      });
    }
  }

  Future<void> _playAcceptedSound() async {
    try {
      await SoundService.playRequestNotification();
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
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
        setState(() {
          _clientLocation = LatLng(pos.latitude, pos.longitude);
          _clientHeading = pos.heading;
          _isLoading = false;
        });

        // Centrar mapa entre cliente y punto de encuentro
        _fitMapToBounds();
      }

      // Iniciar stream de posición con heading
      _positionStream = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.bestForNavigation,
          distanceFilter: 5, // Actualizar cada 5 metros
        ),
      ).listen(_onPositionUpdate);
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        setState(() => _isLoading = false);
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

  void _fitMapToBounds() {
    if (_clientLocation == null) return;

    try {
      final points = <LatLng>[
        _clientLocation!,
        LatLng(widget.latitudOrigen, widget.longitudOrigen),
      ];

      if (_conductorLocation != null) {
        points.add(_conductorLocation!);
      }

      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
      );
    } catch (e) {
      debugPrint('Error fitting bounds: $e');
    }
  }

  /// Calcular distancia entre dos puntos en km (Haversine)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371.0; // Radio de la Tierra en km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) => degree * (math.pi / 180);

  /// Calcular el bearing (ángulo de dirección) entre dos puntos
  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = math.atan2(y, x);
    return (bearing * 180 / math.pi + 360) % 360; // Convertir a grados (0-360)
  }

  /// Obtener ruta del conductor al punto de encuentro
  Future<void> _updateConductorRoute(LatLng conductorPos) async {
    if (_isLoadingRoute) return;

    _isLoadingRoute = true;

    try {
      final pickupPoint = LatLng(widget.latitudOrigen, widget.longitudOrigen);

      // Usar MapboxService para obtener la ruta
      final route = await MapboxService.getRoute(
        waypoints: [conductorPos, pickupPoint],
        profile: 'driving-traffic',
      );

      if (mounted && route != null && route.geometry.isNotEmpty) {
        final isFirstRoute = _conductorRoute.isEmpty;

        setState(() {
          _conductorRoute = route.geometry;
        });

        // Si es la primera vez que obtenemos la ruta, animar
        if (isFirstRoute && !_initialAnimationDone) {
          _initialAnimationDone = true;
          _routeAnimationController.forward(from: 0);

          // Animación inicial: mostrar todo, luego enfocar cliente
          await _animateToShowAll();
          await Future.delayed(const Duration(milliseconds: 2500));
          if (mounted && _clientLocation != null) {
            await _animateToClient();
          }
        } else {
          // Actualizar ruta sin animación
          setState(() {
            _animatedRoute = route.geometry;
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting conductor route: $e');
    } finally {
      _isLoadingRoute = false;
    }
  }

  /// Animar cámara para mostrar toda la ruta, conductor y punto de encuentro
  Future<void> _animateToShowAll() async {
    if (!mounted) return;

    try {
      final points = <LatLng>[
        LatLng(
          widget.latitudOrigen,
          widget.longitudOrigen,
        ), // Punto de encuentro
      ];

      if (_conductorLocation != null) {
        points.add(_conductorLocation!);
      }
      if (_clientLocation != null) {
        points.add(_clientLocation!);
      }

      // Agregar puntos de la ruta para mejor ajuste
      if (_conductorRoute.isNotEmpty) {
        points.addAll(_conductorRoute);
      }

      if (points.length < 2) return;

      final bounds = LatLngBounds.fromPoints(points);

      // Animación suave usando moveAndRotate con easing
      final targetCenter = LatLng(
        (bounds.north + bounds.south) / 2,
        (bounds.east + bounds.west) / 2,
      );

      // Calcular zoom apropiado basado en la distancia
      final latDiff = (bounds.north - bounds.south).abs();
      final lngDiff = (bounds.east - bounds.west).abs();
      final maxDiff = math.max(latDiff, lngDiff);

      // Zoom dinámico basado en la extensión
      double targetZoom = 14.0;
      if (maxDiff < 0.01)
        targetZoom = 16.0;
      else if (maxDiff < 0.02)
        targetZoom = 15.0;
      else if (maxDiff < 0.05)
        targetZoom = 14.0;
      else
        targetZoom = 13.0;

      _smoothCameraMove(targetCenter, targetZoom);
    } catch (e) {
      debugPrint('Error animating to show all: $e');
    }
  }

  /// Animar cámara para enfocar al cliente con zoom cercano
  Future<void> _animateToClient() async {
    if (!mounted || _clientLocation == null) return;

    try {
      // Zoom muy cercano (18.5) para ver bien al cliente
      _smoothCameraMove(_clientLocation!, 18.5);
    } catch (e) {
      debugPrint('Error animating to client: $e');
    }
  }

  /// Movimiento suave de cámara con interpolación
  void _smoothCameraMove(LatLng target, double targetZoom) {
    final startLat = _mapController.camera.center.latitude;
    final startLng = _mapController.camera.center.longitude;
    final startZoom = _mapController.camera.zoom;

    const duration = Duration(milliseconds: 800);
    const steps = 30;
    final stepDuration = duration ~/ steps;

    int currentStep = 0;

    Timer.periodic(Duration(milliseconds: stepDuration.inMilliseconds), (
      timer,
    ) {
      if (!mounted || currentStep >= steps) {
        timer.cancel();
        return;
      }

      currentStep++;
      final t = _easeInOutCubic(currentStep / steps);

      final lat = startLat + (target.latitude - startLat) * t;
      final lng = startLng + (target.longitude - startLng) * t;
      final zoom = startZoom + (targetZoom - startZoom) * t;

      _mapController.move(LatLng(lat, lng), zoom);
    });
  }

  /// Función de easing para animación suave
  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
  }

  /// Toggle entre vista completa y vista del cliente
  void _toggleFocus() {
    setState(() {
      _isFocusedOnClient = !_isFocusedOnClient;
    });

    if (_isFocusedOnClient) {
      _animateToClient();
    } else {
      _animateToShowAll();
    }
  }

  void _startStatusPolling() {
    // Consultar estado cada 5 segundos
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkTripStatus();
    });

    // Primera consulta inmediata
    _checkTripStatus();
  }

  Future<void> _checkTripStatus() async {
    if (!mounted) return;

    try {
      final result = await TripRequestService.getTripStatus(
        solicitudId: widget.solicitudId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final trip = result['trip'];
        final estado = trip['estado'] as String?;
        final conductor = trip['conductor'] as Map<String, dynamic>?;

        LatLng? newConductorLocation;

        if (conductor != null) {
          // Actualizar ubicación del conductor
          final ubicacion = conductor['ubicacion'] as Map<String, dynamic>?;
          if (ubicacion != null) {
            final lat = ubicacion['latitud'] as double?;
            final lng = ubicacion['longitud'] as double?;
            if (lat != null && lng != null) {
              newConductorLocation = LatLng(lat, lng);
            }
          }
        }

        // Verificar si la ubicación del conductor cambió significativamente (más de 50m)
        bool shouldUpdateRoute = false;
        double newHeading = _conductorHeading;
        if (newConductorLocation != null) {
          if (_lastConductorLocation == null) {
            shouldUpdateRoute = true;
          } else {
            final distance = _calculateDistance(
              _lastConductorLocation!.latitude,
              _lastConductorLocation!.longitude,
              newConductorLocation.latitude,
              newConductorLocation.longitude,
            );
            // Calcular heading basado en el movimiento (si se movió más de 10m)
            if (distance > 0.01) {
              newHeading = _calculateBearing(
                _lastConductorLocation!,
                newConductorLocation,
              );
            }
            if (distance > 0.05) {
              // Más de 50 metros
              shouldUpdateRoute = true;
            }
          }
        }

        setState(() {
          _tripState = estado ?? 'aceptada';
          _conductorHeading = newHeading;

          if (conductor != null) {
            _conductor = conductor;
            _conductorLocation = newConductorLocation;
            _conductorDistanceKm = (conductor['distancia_km'] as num?)
                ?.toDouble();
            _conductorEtaMinutes = (conductor['eta_minutos'] as num?)
                ?.toDouble();
          }
        });

        // Re-medir panel en caso de que su tamaño haya cambiado al actualizar datos
        _measureDriverPanel();

        // Actualizar ruta si la ubicación cambió
        if (shouldUpdateRoute && newConductorLocation != null) {
          _lastConductorLocation = newConductorLocation;
          _updateConductorRoute(newConductorLocation);
        }

        // Verificar cambios de estado importantes
        if (estado == 'conductor_llego') {
          unawaited(_showDriverArrivedDialog());
        } else if (estado == 'en_curso') {
          // Navegar a pantalla de viaje en curso
          _navigateToActiveTrip();
        } else if (estado == 'cancelada') {
          _showCancelledDialog();
        }
      }
    } catch (e) {
      debugPrint('Error checking trip status: $e');
    }
  }

  Future<void> _showDriverArrivedDialog() async {
    if (!mounted) return;
    if (_driverArrivedDialogShown || _driverArrivedDialogShowing) return;

    _driverArrivedDialogShowing = true;
    HapticFeedback.heavyImpact();

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('¡Tu conductor llegó!')),
          ],
        ),
        content: const Text(
          'Tu conductor está esperándote en el punto de encuentro.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Entendido',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      );
    } catch (e) {
      debugPrint('Error showing driver arrived dialog: $e');
    } finally {
      _driverArrivedDialogShown = true;
      _driverArrivedDialogShowing = false;
    }
  }

  void _navigateToActiveTrip() {
    // TODO: Navegar a pantalla de viaje activo para el cliente
    Navigator.pushReplacementNamed(
      context,
      '/user/active_trip',
      arguments: {
        'solicitud_id': widget.solicitudId,
        'conductor': _conductor,
        'origen': {
          'latitud': widget.latitudOrigen,
          'longitud': widget.longitudOrigen,
          'direccion': widget.direccionOrigen,
        },
        'destino': {
          'latitud': widget.latitudDestino,
          'longitud': widget.longitudDestino,
          'direccion': widget.direccionDestino,
        },
      },
    );
  }

  void _showCancelledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel, color: AppColors.error, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Viaje cancelado')),
          ],
        ),
        content: const Text(
          'El viaje ha sido cancelado. Por favor intenta solicitar otro.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _callDriver() async {
    final phone = _conductor?['telefono'] as String?;
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número de teléfono no disponible')),
      );
      return;
    }

    // Usar intent para llamar sin depender de url_launcher
    try {
      final channel = const MethodChannel('viax/phone');
      await channel.invokeMethod('call', {'phone': phone});
    } catch (e) {
      // Fallback: mostrar número para copiar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Llama al: $phone'),
            action: SnackBarAction(
              label: 'Copiar',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: phone));
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _cancelTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 28,
            ),
            SizedBox(width: 12),
            Text('¿Cancelar viaje?'),
          ],
        ),
        content: const Text(
          'Si cancelas ahora, es posible que se aplique una tarifa de cancelación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, continuar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await TripRequestService.cancelTripRequest(
        widget.solicitudId,
      );
      if (mounted && success) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _statusTimer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _panelController.dispose();
    _routeAnimationController.dispose();
    _cameraAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final pickupPoint = LatLng(widget.latitudOrigen, widget.longitudOrigen);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // MAPA
          UserTripAcceptedMap(
            mapController: _mapController,
            isDark: isDark,
            pickupPoint: pickupPoint,
            animatedRoute: _animatedRoute,
            conductorLocation: _conductorLocation,
            conductorHeading: _conductorHeading,
            conductorVehicleType: _conductor?['vehiculo']?['tipo'] as String?,
            clientLocation: _clientLocation,
            clientHeading: _clientHeading,
            pulseAnimation: _pulseController,
            waveAnimation: _waveController,
            pickupLabel: 'Punto de encuentro',
          ),

          // HEADER
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: UserTripAcceptedHeader(
              isDark: isDark,
              tripState: _tripState,
              statusText: _getStatusText(),
              direccionOrigen: widget.direccionOrigen,
              onClose: _cancelTrip,
            ),
          ),

          // PANEL DE INFO DEL CONDUCTOR
          Positioned(
            bottom: bottomPadding + 16,
            left: 16,
            right: 16,
            child: Container(
              key: _driverPanelKey,
              child: UserTripAcceptedDriverPanel(
                conductor: _conductor,
                conductorEtaMinutes: _conductorEtaMinutes,
                conductorDistanceKm: _conductorDistanceKm,
                onCall: _callDriver,
                onCancelChat: () {
                  // TODO: Implementar chat
                },
                isDark: isDark,
              ),
            ),
          ),

          // BOTÓN DE ENFOQUE (toggle) - arriba del panel (posicionado dinámicamente según altura del panel)
          Positioned(
            right: 16,
            bottom: bottomPadding + (_driverPanelHeight ?? 220) + _focusButtonExtraOffset,
            child: UserTripAcceptedFocusButton(
              isDark: isDark,
              isFocusedOnClient: _isFocusedOnClient,
              onTap: _toggleFocus,
            ),
          ),

          // LOADING
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  String _getStatusText() {
    switch (_tripState) {
      case 'conductor_llego':
        return '¡Tu conductor llegó!';
      case 'en_curso':
        return 'Viaje en curso';
      default:
        return 'Conductor en camino';
    }
  }

}
