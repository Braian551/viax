import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/services/sound_service.dart';
import '../../../../theme/app_colors.dart';
import '../../services/trip_request_service.dart';

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

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _conductor = widget.conductorInfo;
    _startLocationTracking();
    _startStatusPolling();
    _playAcceptedSound();
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
        _animatedRoute = _conductorRoute.sublist(0, pointCount.clamp(0, _conductorRoute.length));
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
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(80),
        ),
      );
    } catch (e) {
      debugPrint('Error fitting bounds: $e');
    }
  }

  /// Calcular distancia entre dos puntos en km (Haversine)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Radio de la Tierra en km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) => degree * (math.pi / 180);

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
        LatLng(widget.latitudOrigen, widget.longitudOrigen), // Punto de encuentro
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
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(
            top: 150,
            bottom: 280,
            left: 50,
            right: 50,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error animating to show all: $e');
    }
  }

  /// Animar cámara para enfocar al cliente
  Future<void> _animateToClient() async {
    if (!mounted || _clientLocation == null) return;
    
    try {
      _mapController.move(_clientLocation!, 17.0);
    } catch (e) {
      debugPrint('Error animating to client: $e');
    }
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
            if (distance > 0.05) { // Más de 50 metros
              shouldUpdateRoute = true;
            }
          }
        }
        
        setState(() {
          _tripState = estado ?? 'aceptada';
          
          if (conductor != null) {
            _conductor = conductor;
            _conductorLocation = newConductorLocation;
            _conductorDistanceKm = (conductor['distancia_km'] as num?)?.toDouble();
            _conductorEtaMinutes = (conductor['eta_minutos'] as num?)?.toDouble();
          }
        });
        
        // Actualizar ruta si la ubicación cambió
        if (shouldUpdateRoute && newConductorLocation != null) {
          _lastConductorLocation = newConductorLocation;
          _updateConductorRoute(newConductorLocation);
        }
        
        // Verificar cambios de estado importantes
        if (estado == 'conductor_llego') {
          _showDriverArrivedDialog();
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

  void _showDriverArrivedDialog() {
    HapticFeedback.heavyImpact();
    showDialog(
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
              child: const Icon(Icons.check_circle, color: AppColors.success, size: 28),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
        content: const Text('El viaje ha sido cancelado. Por favor intenta solicitar otro.'),
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
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
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
      final success = await TripRequestService.cancelTripRequest(widget.solicitudId);
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
          _buildMap(isDark, pickupPoint),
          
          // HEADER
          _buildHeader(isDark),
          
          // BOTÓN DE ENFOQUE (toggle)
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 70,
            child: _buildFocusButton(isDark),
          ),
          
          // PANEL DE INFO DEL CONDUCTOR
          Positioned(
            bottom: bottomPadding + 16,
            left: 16,
            right: 16,
            child: _buildDriverPanel(isDark),
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

  /// Botón para alternar entre vista completa y vista del cliente
  Widget _buildFocusButton(bool isDark) {
    return Material(
      color: isDark ? Colors.grey[900] : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: _toggleFocus,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              _isFocusedOnClient ? Icons.zoom_out_map : Icons.my_location,
              key: ValueKey(_isFocusedOnClient),
              color: AppColors.primary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMap(bool isDark, LatLng pickupPoint) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: pickupPoint,
        initialZoom: 16.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // Capa de tiles
        TileLayer(
          urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
          userAgentPackageName: 'com.viax.app',
        ),
        
        // Sombra de la ruta (efecto de profundidad) - como en trip_preview
        if (_animatedRoute.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _animatedRoute,
                strokeWidth: 8.0,
                color: Colors.black.withOpacity(0.15),
              ),
            ],
          ),
        
        // Ruta del conductor al punto de encuentro (animada)
        if (_animatedRoute.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _animatedRoute,
                strokeWidth: 5.0,
                color: AppColors.primary,
                borderStrokeWidth: 1.5,
                borderColor: Colors.white,
              ),
            ],
          ),
        
        // Marcadores
        MarkerLayer(
          markers: [
            // Marcador del conductor (primero, para que quede debajo)
            if (_conductorLocation != null)
              Marker(
                point: _conductorLocation!,
                width: 56,
                height: 56,
                child: _buildDriverMarker(),
              ),
            
            // Punto de encuentro
            Marker(
              point: pickupPoint,
              width: 90,
              height: 90,
              child: _buildPickupMarker(),
            ),
            
            // Marcador del cliente con orientación (brújula) - encima de todo
            if (_clientLocation != null)
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

  /// Marcador del cliente con orientación (flecha que indica dirección)
  Widget _buildClientMarker() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Halo animado exterior
            Container(
              width: 55 + (_pulseController.value * 15),
              height: 55 + (_pulseController.value * 15),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.12 * (1 - _pulseController.value)),
              ),
            ),
            
            // Círculo de precisión GPS
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.15),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
            ),
            
            // Cono de dirección (hacia donde mira el usuario)
            Transform.rotate(
              angle: (_clientHeading - 90) * (math.pi / 180),
              child: CustomPaint(
                size: const Size(60, 60),
                painter: _DirectionConePainter(
                  color: AppColors.primary.withOpacity(0.25),
                ),
              ),
            ),
            
            // Punto central con flecha de orientación
            Transform.rotate(
              angle: _clientHeading * (math.pi / 180),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Flecha indicando la dirección
                    Positioned(
                      top: 0,
                      child: Icon(
                        Icons.navigation,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Marcador del punto de encuentro con animación de ondas
  Widget _buildPickupMarker() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Ondas expansivas (más sutiles)
            ...List.generate(2, (i) {
              final delay = i / 2;
              final progress = (_waveController.value + delay) % 1.0;
              final size = 35 + (40 * progress);
              final opacity = 0.4 * (1 - progress);
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.success.withOpacity(opacity),
                    width: 2 * (1 - progress),
                  ),
                ),
              );
            }),
            
            // Marcador central (más pequeño)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.location_on, color: Colors.white, size: 18),
            ),
            
            // Etiqueta "Punto de encuentro" (arriba del marcador)
            Positioned(
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Text(
                  'Punto de encuentro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Marcador del conductor
  Widget _buildDriverMarker() {
    final vehiculoTipo = _conductor?['vehiculo']?['tipo'] as String? ?? 'carro';
    final iconData = vehiculoTipo.contains('moto') 
        ? Icons.two_wheeler 
        : Icons.local_taxi;
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(iconData, color: Colors.white, size: 26),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (isDark ? Colors.black : Colors.white),
              (isDark ? Colors.black : Colors.white).withOpacity(0.8),
              (isDark ? Colors.black : Colors.white).withOpacity(0),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              children: [
                // Barra superior
                Row(
                  children: [
                    // Botón atrás
                    Material(
                      color: isDark ? Colors.white12 : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      elevation: isDark ? 0 : 2,
                      child: InkWell(
                        onTap: _cancelTrip,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Título
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _getStatusText(),
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Botón centrar mapa
                    Material(
                      color: isDark ? Colors.white12 : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      elevation: isDark ? 0 : 2,
                      child: InkWell(
                        onTap: _fitMapToBounds,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.my_location_rounded,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Card de instrucción
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.directions_walk, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dirígete al punto de encuentro',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.direccionOrigen,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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

  Widget _buildDriverPanel(bool isDark) {
    if (_conductor == null) {
      return const SizedBox.shrink();
    }
    
    final nombre = _conductor!['nombre'] as String? ?? 'Conductor';
    final foto = _conductor!['foto'] as String?;
    final calificacion = (_conductor!['calificacion'] as num?)?.toDouble() ?? 4.5;
    final vehiculo = _conductor!['vehiculo'] as Map<String, dynamic>?;
    final placa = vehiculo?['placa'] as String? ?? '---';
    final marca = vehiculo?['marca'] as String? ?? '';
    final modelo = vehiculo?['modelo'] as String? ?? '';
    final color = vehiculo?['color'] as String? ?? '';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
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
        children: [
          // Handle para arrastrar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Info del conductor
          Row(
            children: [
              // Foto del conductor
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.1),
                  border: Border.all(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: foto != null && foto.isNotEmpty
                      ? Image.network(
                          foto,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person,
                            color: AppColors.primary,
                            size: 30,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 30,
                        ),
                ),
              ),
              
              const SizedBox(width: 14),
              
              // Nombre y calificación
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: AppColors.accent, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          calificacion.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Botones de acción
              Row(
                children: [
                  // Botón llamar
                  Material(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _callDriver,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: const Icon(Icons.call, color: AppColors.success, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón mensaje
                  Material(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () {
                        // TODO: Implementar chat
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: const Icon(Icons.message, color: AppColors.primary, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Divider
          Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
          
          const SizedBox(height: 12),
          
          // Info del vehículo
          Row(
            children: [
              // Icono del vehículo
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  vehiculo?['tipo']?.toString().contains('moto') == true
                      ? Icons.two_wheeler
                      : Icons.directions_car,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 14),
              
              // Marca, modelo, color
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$marca $modelo',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (color.isNotEmpty)
                      Text(
                        color,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Placa
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  placa,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // ETA del conductor
          if (_conductorEtaMinutes != null || _conductorDistanceKm != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (_conductorEtaMinutes != null)
                    _buildEtaItem(
                      icon: Icons.access_time,
                      value: '${_conductorEtaMinutes!.round()} min',
                      label: 'Llegada aprox.',
                      isDark: isDark,
                    ),
                  if (_conductorEtaMinutes != null && _conductorDistanceKm != null)
                    Container(
                      width: 1,
                      height: 40,
                      color: isDark ? Colors.white12 : Colors.grey[300],
                    ),
                  if (_conductorDistanceKm != null)
                    _buildEtaItem(
                      icon: Icons.route,
                      value: '${_conductorDistanceKm!.toStringAsFixed(1)} km',
                      label: 'Distancia',
                      isDark: isDark,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEtaItem({
    required IconData icon,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }
}

/// CustomPainter para el cono de dirección del cliente (giroscopio)
class _DirectionConePainter extends CustomPainter {
  final Color color;
  
  _DirectionConePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final center = Offset(size.width / 2, size.height / 2);
    final path = ui.Path();
    
    // Dibujar un cono/triángulo que apunta hacia arriba
    path.moveTo(center.dx, center.dy - size.height * 0.4); // Punta
    path.lineTo(center.dx - size.width * 0.25, center.dy); // Esquina izquierda
    path.lineTo(center.dx + size.width * 0.25, center.dy); // Esquina derecha
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
