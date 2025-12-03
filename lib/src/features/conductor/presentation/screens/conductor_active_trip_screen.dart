import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../../../global/services/mapbox_service.dart';
import '../../../../theme/app_colors.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'dart:convert';

/// Pantalla de viaje activo para el conductor - UI profesional de navegación 3D
/// Usa Mapbox Maps Flutter SDK nativo con pitch, bearing y location puck
class ConductorActiveTripScreen extends StatefulWidget {
  final int conductorId;
  final int? solicitudId;
  final int? viajeId;
  final double origenLat;
  final double origenLng;
  final double destinoLat;
  final double destinoLng;
  final String direccionOrigen;
  final String direccionDestino;
  final String? clienteNombre;

  const ConductorActiveTripScreen({
    super.key,
    required this.conductorId,
    this.solicitudId,
    this.viajeId,
    required this.origenLat,
    required this.origenLng,
    required this.destinoLat,
    required this.destinoLng,
    required this.direccionOrigen,
    required this.direccionDestino,
    this.clienteNombre,
  });

  @override
  State<ConductorActiveTripScreen> createState() => _ConductorActiveTripScreenState();
}

class _ConductorActiveTripScreenState extends State<ConductorActiveTripScreen> {
  MapboxMap? _mapboxMap;
  StreamSubscription<geo.Position>? _positionStream;
  bool _isDisposed = false;
  bool _mapReady = false;

  Point? _driverLocation;
  late final Point _pickup;
  late final Point _dropoff;

  bool _toPickup = true;
  bool _loadingRoute = false;
  String? _error;
  
  double _distanceKm = 0;
  int _etaMinutes = 0;
  double _currentSpeed = 0;
  double _currentBearing = 0;

  // IDs para capas de ruta
  static const String _routeSourceId = 'route-source';
  static const String _routeLayerId = 'route-layer';
  static const String _routeOutlineLayerId = 'route-outline-layer';

  @override
  void initState() {
    super.initState();
    _pickup = Point(coordinates: Position(widget.origenLng, widget.origenLat));
    _dropoff = Point(coordinates: Position(widget.destinoLng, widget.destinoLat));
  }

  @override
  void dispose() {
    _isDisposed = true;
    _positionStream?.cancel();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) setState(fn);
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _mapReady = true;
    
    // Habilitar location puck con bearing del dispositivo (giroscopio)
    await _enableLocationPuck();
    
    // Iniciar tracking de ubicación
    await _startLocationTracking();
  }

  Future<void> _enableLocationPuck() async {
    if (_mapboxMap == null) return;
    
    // Configurar el location component con el puck 2D estilo navegación
    await _mapboxMap!.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: AppColors.primary.toARGB32(),
      pulsingMaxRadius: 30,
      showAccuracyRing: false,
      // El puck rotará según el bearing del dispositivo (giroscopio/brújula)
      puckBearingEnabled: true,
      puckBearing: PuckBearing.HEADING, // Usa el sensor de orientación del dispositivo
    ));
  }

  Future<void> _startLocationTracking() async {
    if (_isDisposed) return;
    
    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (_isDisposed) return;
      
      if (!serviceEnabled) {
        _safeSetState(() {
          _driverLocation = Point(coordinates: Position(-74.0817, 4.6097));
          _error = 'Activa el GPS para navegación';
        });
        await _loadRoute();
        return;
      }

      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (_isDisposed) return;
      
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (_isDisposed) return;
      }
      
      if (permission == geo.LocationPermission.deniedForever ||
          permission == geo.LocationPermission.denied) {
        _safeSetState(() {
          _driverLocation = Point(coordinates: Position(-74.0817, 4.6097));
          _error = 'Permisos de ubicación requeridos';
        });
        await _loadRoute();
        return;
      }

      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      
      if (_isDisposed) return;
      _safeSetState(() {
        _driverLocation = Point(coordinates: Position(pos.longitude, pos.latitude));
        _currentBearing = pos.heading;
      });
      
      await _loadRoute();
      await _moveCameraToDriver();
      
      if (_isDisposed) return;
      
      // Stream de posición con actualización continua
      _positionStream = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 5, // Actualizar cada 5 metros
        ),
      ).listen(
        (pos) async {
          if (_isDisposed) return;
          
          _safeSetState(() {
            _driverLocation = Point(coordinates: Position(pos.longitude, pos.latitude));
            _currentSpeed = pos.speed * 3.6; // m/s a km/h
            _currentBearing = pos.heading;
          });
          
          // En modo pickup, seguir al conductor con cámara 3D
          if (_toPickup && _mapboxMap != null) {
            await _updateCamera3D(pos.latitude, pos.longitude, pos.heading);
          }
        },
        onError: (e) {
          debugPrint('Error en stream de posición: $e');
        },
      );
    } catch (e) {
      if (_isDisposed) return;
      _safeSetState(() {
        _driverLocation = Point(coordinates: Position(-74.0817, 4.6097));
        _error = 'No se pudo obtener tu ubicación.';
      });
      await _loadRoute();
    }
  }

  /// Actualiza la cámara en modo 3D de navegación (pitch + bearing + follow)
  Future<void> _updateCamera3D(double lat, double lng, double bearing) async {
    if (_mapboxMap == null || _isDisposed) return;
    
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: 17.5,
        pitch: 60, // Inclinación 3D como Google Maps/Uber
        bearing: bearing, // Rotación según dirección del conductor
      ),
      MapAnimationOptions(duration: 1000, startDelay: 0),
    );
  }

  Future<void> _moveCameraToDriver() async {
    if (_mapboxMap == null || _driverLocation == null || _isDisposed) return;
    
    if (_toPickup) {
      // En modo pickup, vista 3D centrada en el conductor
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: _driverLocation,
          zoom: 17.5,
          pitch: 60, // Vista 3D inclinada
          bearing: _currentBearing,
        ),
        MapAnimationOptions(duration: 1500, startDelay: 0),
      );
    } else {
      // En modo destino, vista 2D que muestre toda la ruta
      await _fitRouteInView();
    }
  }

  Future<void> _fitRouteInView() async {
    if (_mapboxMap == null || _driverLocation == null || _isDisposed) return;
    
    final target = _toPickup ? _pickup : _dropoff;
    
    // Calcular bounds para mostrar conductor y destino
    final southwest = Point(coordinates: Position(
      math.min(_driverLocation!.coordinates.lng.toDouble(), target.coordinates.lng.toDouble()),
      math.min(_driverLocation!.coordinates.lat.toDouble(), target.coordinates.lat.toDouble()),
    ));
    final northeast = Point(coordinates: Position(
      math.max(_driverLocation!.coordinates.lng.toDouble(), target.coordinates.lng.toDouble()),
      math.max(_driverLocation!.coordinates.lat.toDouble(), target.coordinates.lat.toDouble()),
    ));
    
    final camera = await _mapboxMap!.cameraForCoordinateBounds(
      CoordinateBounds(southwest: southwest, northeast: northeast, infiniteBounds: false),
      MbxEdgeInsets(top: 200, left: 60, bottom: 350, right: 60),
      null, null, null, null,
    );
    
    if (!_isDisposed) {
      await _mapboxMap!.flyTo(camera, MapAnimationOptions(duration: 1500, startDelay: 0));
    }
  }

  Future<void> _loadRoute() async {
    if (_driverLocation == null || _isDisposed) return;
    _safeSetState(() { _loadingRoute = true; _error = null; });

    final target = _toPickup ? _pickup : _dropoff;
    
    // Convertir a LatLng para el servicio de rutas
    final waypoints = [
      ll.LatLng(_driverLocation!.coordinates.lat.toDouble(), _driverLocation!.coordinates.lng.toDouble()),
      ll.LatLng(target.coordinates.lat.toDouble(), target.coordinates.lng.toDouble()),
    ];

    try {
      final route = await MapboxService.getRoute(waypoints: waypoints);
      if (_isDisposed) return;
      
      if (route == null) {
        _safeSetState(() { _loadingRoute = false; _error = 'No se pudo calcular la ruta'; });
        return;
      }

      _safeSetState(() {
        _distanceKm = route.distanceKm;
        _etaMinutes = route.durationMinutes.ceil();
        _loadingRoute = false;
      });
      
      // Dibujar la ruta en el mapa
      await _drawRoute(route.geometry);
      
    } catch (e) {
      if (_isDisposed) return;
      _safeSetState(() { _loadingRoute = false; _error = 'Error al calcular la ruta'; });
    }
  }

  Future<void> _drawRoute(List<ll.LatLng> geometry) async {
    if (_mapboxMap == null || _isDisposed || !_mapReady) return;
    
    try {
      // Convertir geometría a lista de coordenadas
      final coordinates = geometry.map((point) {
        return Position(point.longitude, point.latitude);
      }).toList();
      
      // Verificar si la fuente ya existe y eliminarla
      final style = _mapboxMap!.style;
      
      try { await style.removeStyleLayer(_routeLayerId); } catch (_) {}
      try { await style.removeStyleLayer(_routeOutlineLayerId); } catch (_) {}
      try { await style.removeStyleSource(_routeSourceId); } catch (_) {}
      
      // Añadir la fuente de la ruta - construir GeoJSON manualmente
      final geoJsonData = jsonEncode({
        'type': 'Feature',
        'properties': {},
        'geometry': {
          'type': 'LineString',
          'coordinates': coordinates.map((c) => [c.lng.toDouble(), c.lat.toDouble()]).toList(),
        }
      });
      
      await style.addSource(GeoJsonSource(
        id: _routeSourceId,
        data: geoJsonData,
      ));
      
      // Capa de borde/sombra de la ruta (más gruesa)
      await style.addLayer(LineLayer(
        id: _routeOutlineLayerId,
        sourceId: _routeSourceId,
        lineColor: AppColors.blue800.toARGB32(),
        lineWidth: 10.0,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
      ));
      
      // Capa principal de la ruta
      await style.addLayer(LineLayer(
        id: _routeLayerId,
        sourceId: _routeSourceId,
        lineColor: AppColors.primary.toARGB32(),
        lineWidth: 6.0,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
      ));
      
    } catch (e) {
      debugPrint('Error dibujando ruta: $e');
    }
  }

  double _calculateDistance(Point p1, Point p2) {
    const r = 6371000.0;
    final lat1 = p1.coordinates.lat.toDouble() * math.pi / 180;
    final lat2 = p2.coordinates.lat.toDouble() * math.pi / 180;
    final dLat = (p2.coordinates.lat.toDouble() - p1.coordinates.lat.toDouble()) * math.pi / 180;
    final dLng = (p2.coordinates.lng.toDouble() - p1.coordinates.lng.toDouble()) * math.pi / 180;
    final a = math.sin(dLat/2)*math.sin(dLat/2) +
        math.cos(lat1)*math.cos(lat2)*
        math.sin(dLng/2)*math.sin(dLng/2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
  }

  void _onArrivedPickup() async {
    if (!_toPickup || _isDisposed) return;
    _safeSetState(() => _toPickup = false);
    await _loadRoute();
    await _fitRouteInView();
    if (_isDisposed || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('¡Cliente recogido! Navegando al destino'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _centerOnDriver() async {
    if (_driverLocation == null || _mapboxMap == null) return;
    
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: _driverLocation,
        zoom: _toPickup ? 17.5 : 15,
        pitch: _toPickup ? 60 : 0,
        bearing: _toPickup ? _currentBearing : 0,
      ),
      MapAnimationOptions(duration: 1000, startDelay: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.grey[100],
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(isDark),
      body: Stack(
        children: [
          // Mapa Mapbox con soporte 3D nativo
          MapWidget(
            key: const ValueKey('mapWidget'),
            cameraOptions: CameraOptions(
              center: _pickup,
              zoom: 15,
              pitch: 0,
              bearing: 0,
            ),
            styleUri: isDark 
                ? 'mapbox://styles/mapbox/navigation-night-v1'
                : 'mapbox://styles/mapbox/navigation-day-v1',
            onMapCreated: _onMapCreated,
          ),
          // Indicador de velocidad
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 16,
            child: _buildSpeedIndicator(isDark),
          ),
          // Botón de centrar
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            right: 16,
            child: _buildMapControlButton(Icons.my_location, _centerOnDriver, isDark),
          ),
          // Tarjeta de próxima maniobra
          Positioned(
            top: MediaQuery.of(context).padding.top + 145,
            left: 16, right: 16,
            child: _buildNextManeuverCard(isDark),
          ),
          // Panel inferior
          _toPickup ? _build3DGoToClientPanel(isDark) : _buildBottomPanel(isDark),
          // Loading
          if (_loadingRoute) Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkCard : Colors.white).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          // Error
          if (_error != null) Positioned(
            top: kToolbarHeight + MediaQuery.of(context).padding.top + 16,
            left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white))),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkCard : Colors.white).withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: () => Navigator.pop(context, true),
              child: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.grey[800], size: 20),
            ),
          ),
        ),
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.darkCard : Colors.white).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _toPickup ? 'Ir a recoger' : 'Ir al destino',
          style: TextStyle(color: isDark ? Colors.white : Colors.grey[800], fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      centerTitle: true,
    );
  }
  
  Widget _buildMapControlButton(IconData icon, VoidCallback onTap, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap, borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkCard : Colors.white).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSpeedIndicator(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkCard : Colors.white).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${_currentSpeed.toInt()}', style: TextStyle(color: isDark ? Colors.white : Colors.grey[800], fontSize: 22, fontWeight: FontWeight.bold)),
            Text('km/h', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600], fontSize: 10, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
  
  Widget _buildNextManeuverCard(bool isDark) {
    final target = _toPickup ? _pickup : _dropoff;
    double dist = _driverLocation != null ? _calculateDistance(_driverLocation!, target) : 0;
    String distText = dist < 1000 ? '${dist.toInt()} m' : '${(dist/1000).toStringAsFixed(1)} km';
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary, AppColors.blue600]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.straight, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(distText, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Text(_toPickup ? 'hacia el punto de recogida' : 'hacia el destino',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.schedule, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text('$_etaMinutes min', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  /// Panel inferior estilo Google Maps/Uber para ir al cliente
  Widget _build3DGoToClientPanel(bool isDark) {
    final passengerName = (widget.clienteNombre?.trim().isNotEmpty ?? false)
        ? widget.clienteNombre!.trim()
        : 'Pasajero';
    final fallbackDistance = _driverLocation != null
        ? _calculateDistance(_driverLocation!, _pickup) / 1000
        : 0.0;
    final displayDistance = _distanceKm > 0 ? _distanceKm : fallbackDistance;
    final distanceLabel = displayDistance <= 0
        ? '--'
        : displayDistance < 1
            ? '${(displayDistance * 1000).round()} m'
            : '${displayDistance.toStringAsFixed(1)} km';
    final arrivalTime = _etaMinutes > 0 ? DateTime.now().add(Duration(minutes: _etaMinutes)) : null;
    final arrivalLabel = arrivalTime != null
        ? '${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_pin_circle_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.direccionOrigen,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.grey[900],
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '¡Vamos! • $passengerName',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.15)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            '$_etaMinutes min',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.grey[900],
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• $distanceLabel',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: isDark ? Colors.white54 : Colors.grey[500],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Llega antes de la(s) $arrivalLabel',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loadingRoute ? null : _onArrivedPickup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_upward_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Llegué por el pasajero',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ],
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

  Widget _buildBottomPanel(bool isDark) {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: isDark
                    ? [AppColors.darkCard.withValues(alpha: 0.85), AppColors.darkCard.withValues(alpha: 0.95)]
                    : [Colors.white.withValues(alpha: 0.85), Colors.white.withValues(alpha: 0.95)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  )),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _buildInfoCard(Icons.schedule_rounded, '$_etaMinutes min', 'Tiempo est.', isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInfoCard(Icons.route_rounded, '${_distanceKm.toStringAsFixed(1)} km', 'Distancia', isDark)),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.grey).withValues(alpha: isDark ? 0.05 : 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: (isDark ? Colors.white : Colors.grey).withValues(alpha: isDark ? 0.1 : 0.2)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.blue700.withValues(alpha: 0.1)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_toPickup ? Icons.person_pin_circle : Icons.location_on, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_toPickup ? 'Recoger en' : 'Destino',
                          style: TextStyle(color: (isDark ? Colors.white : Colors.grey[600])!.withValues(alpha: isDark ? 0.6 : 1), fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(_toPickup ? widget.direccionOrigen : widget.direccionDestino,
                          style: TextStyle(color: isDark ? Colors.white : Colors.grey[800], fontWeight: FontWeight.w600, fontSize: 14, height: 1.3),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: _toPickup ? _onArrivedPickup : () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8, shadowColor: AppColors.primary.withValues(alpha: 0.5),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(_toPickup ? Icons.check_circle_outline : Icons.flag_outlined, size: 22),
                        const SizedBox(width: 10),
                        Text(_toPickup ? 'He llegado al origen' : 'Finalizar viaje',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String value, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.blue700.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.grey[800], fontWeight: FontWeight.w700, fontSize: 16)),
          Text(label, style: TextStyle(color: (isDark ? Colors.white : Colors.grey[600])!.withValues(alpha: isDark ? 0.6 : 1), fontSize: 11)),
        ]),
      ]),
    );
  }
}
