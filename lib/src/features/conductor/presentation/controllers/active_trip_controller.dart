import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:viax/src/global/services/mapbox_service.dart';
import 'package:viax/src/core/config/env_config.dart';

/// Controlador para la lógica de negocio del viaje activo.
/// 
/// Separa la lógica del mapa y geolocalización de la UI para
/// mejor mantenimiento y testing.
class ActiveTripController {
  // =========================================================================
  // CONSTANTES
  // =========================================================================
  
  static bool _mapboxInitialized = false;
  static const Duration _cameraUpdateThrottle = Duration(milliseconds: 1500);
  
  // IDs de capas del mapa
  static const String _routeSourceId = 'route-source';
  static const String _routeLayerId = 'route-layer';
  static const String _routeOutlineLayerId = 'route-outline-layer';

  // =========================================================================
  // ESTADO
  // =========================================================================
  
  bool isDisposed = false;
  bool mapReady = false;
  bool mapError = false;
  // Arrancamos en 2D para evitar shader/link issues en GPUs débiles; el 3D se activa manualmente
  bool is3DMode = false;
  bool toPickup = true;           // En camino al punto de recogida
  bool arrivedAtPickup = false;   // Llegó al punto, esperando iniciar viaje
  bool loadingRoute = false;
  String? error;

  // Datos de navegación
  double distanceKm = 0;
  int etaMinutes = 0;
  double currentSpeed = 0;
  double currentBearing = 0;

  // Ubicaciones
  Point? driverLocation;
  late final Point pickup;
  late final Point dropoff;

  // Mapa y geolocalización
  MapboxMap? mapboxMap;
  StreamSubscription<geo.Position>? positionStream;
  
  // Managers separados para cada marcador (permite control individual)
  CircleAnnotationManager? _pickupAnnotationManager;
  CircleAnnotationManager? _dropoffAnnotationManager;

  // Throttling
  DateTime _lastCameraUpdate = DateTime.now();
  bool _shouldUpdateCamera = true;
  bool _locationTrackingStarted = false;

  // Callback
  final VoidCallback onStateChanged;

  // =========================================================================
  // CONSTRUCTOR
  // =========================================================================

  ActiveTripController({
    required double origenLat,
    required double origenLng,
    required double destinoLat,
    required double destinoLng,
    required this.onStateChanged,
  }) {
    pickup = Point(coordinates: Position(origenLng, origenLat));
    dropoff = Point(coordinates: Position(destinoLng, destinoLat));
  }

  // =========================================================================
  // CICLO DE VIDA
  // =========================================================================

  void dispose() {
    isDisposed = true;
    _stopLocationTracking();
    _cleanupMapResources();
    mapboxMap = null;
  }

  void _stopLocationTracking() {
    positionStream?.pause();
    positionStream?.cancel();
    positionStream = null;
  }

  void _cleanupMapResources() {
    try {
      _pickupAnnotationManager?.deleteAll();
      _pickupAnnotationManager = null;
    } catch (_) {}

    try {
      _dropoffAnnotationManager?.deleteAll();
      _dropoffAnnotationManager = null;
    } catch (_) {}

    try {
      mapboxMap?.location.updateSettings(
        LocationComponentSettings(enabled: false),
      );
    } catch (_) {}
  }

  // =========================================================================
  // MAPA - INICIALIZACIÓN
  // =========================================================================

  Future<void> onMapCreated(MapboxMap map) async {
    if (isDisposed) return;

    await _ensureMapboxInitialized();
    mapboxMap = map;
    await _hideMapOrnaments();
  }

  Future<void> _ensureMapboxInitialized() async {
    if (_mapboxInitialized) return;

    try {
      MapboxOptions.setAccessToken(EnvConfig.mapboxPublicToken);
      _mapboxInitialized = true;
      debugPrint('✅ Mapbox inicializado');
    } catch (e) {
      debugPrint('⚠️ Error inicializando Mapbox: $e');
      mapError = true;
      error = 'Error de configuración del mapa';
      onStateChanged();
    }
  }

  Future<void> _hideMapOrnaments() async {
    if (mapboxMap == null || isDisposed) return;

    try {
      await Future.wait([
        mapboxMap!.compass.updateSettings(CompassSettings(enabled: false)),
        mapboxMap!.scaleBar.updateSettings(ScaleBarSettings(enabled: false)),
        mapboxMap!.logo.updateSettings(
          LogoSettings(marginLeft: -100, marginBottom: -100),
        ),
        mapboxMap!.attribution.updateSettings(
          AttributionSettings(marginLeft: -100, marginBottom: -100),
        ),
      ]);
    } catch (e) {
      debugPrint('⚠️ Error ocultando ornamentos: $e');
    }
  }

  Future<void> onStyleLoaded() async {
    if (isDisposed) return;
    
    mapReady = true;
    // Eliminamos el modo 3D al inicio para estabilidad
    onStateChanged();

    // Ejecutar tareas de inicialización
    await _quickFocusOnDriver();
    _enableLocationPuck();
    _addMarkers();

    if (!_locationTrackingStarted) {
      _locationTrackingStarted = true;
      startLocationTracking();
    }
  }

  void onMapLoadError(MapLoadingErrorEventData eventData) {
    if (isDisposed) return;
    debugPrint('Error cargando mapa: ${eventData.type} -> ${eventData.message}');
    mapError = true;
    error = 'Error al cargar el mapa';
    onStateChanged();
  }

  // =========================================================================
  // MAPA - MARCADORES
  // =========================================================================

  Future<void> _addMarkers() async {
    if (mapboxMap == null || isDisposed || !mapReady) return;

    try {
      // Crear manager para pickup (solo si aún vamos al punto de recogida)
      if (toPickup) {
        _pickupAnnotationManager ??= await mapboxMap!.annotations
            .createCircleAnnotationManager();

        if (_pickupAnnotationManager != null && !isDisposed) {
          await _pickupAnnotationManager!.create(CircleAnnotationOptions(
            geometry: pickup,
            circleRadius: 14.0,
            circleColor: 0xFF2196F3,
            circleStrokeColor: 0xFFFFFFFF,
            circleStrokeWidth: 3.0,
            circleOpacity: 1.0,
            circleStrokeOpacity: 1.0,
          ));
          debugPrint('✅ Marcador de pickup agregado');
        }
      }

      // Crear manager para destino (siempre visible)
      _dropoffAnnotationManager ??= await mapboxMap!.annotations
          .createCircleAnnotationManager();

      if (_dropoffAnnotationManager != null && !isDisposed) {
        await _dropoffAnnotationManager!.create(CircleAnnotationOptions(
          geometry: dropoff,
          circleRadius: 12.0,
          circleColor: 0xFFF44336,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 3.0,
          circleOpacity: 1.0,
          circleStrokeOpacity: 1.0,
        ));
        debugPrint('✅ Marcador de destino agregado');
      }

    } catch (e) {
      debugPrint('⚠️ Error agregando marcadores: $e');
    }
  }

  /// Elimina el marcador del punto de recogida cuando el conductor llega
  Future<void> _removePickupMarker() async {
    if (_pickupAnnotationManager == null || isDisposed) return;

    try {
      await _pickupAnnotationManager!.deleteAll();
      _pickupAnnotationManager = null;
      debugPrint('✅ Marcador de pickup eliminado');
    } catch (e) {
      debugPrint('⚠️ Error eliminando marcador de pickup: $e');
    }
  }

  // =========================================================================
  // GEOLOCALIZACIÓN
  // =========================================================================

  Future<void> startLocationTracking() async {
    if (isDisposed) return;

    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (isDisposed) return;

      if (!serviceEnabled) {
        _setDefaultLocation('Activa el GPS para navegación');
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (isDisposed) return;

      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (isDisposed) return;
      }

      if (permission == geo.LocationPermission.deniedForever ||
          permission == geo.LocationPermission.denied) {
        _setDefaultLocation('Permisos de ubicación requeridos');
        return;
      }

      // Obtener posición actual
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (isDisposed) return;
      
      _updateDriverPosition(pos);
      await loadRoute();
      await moveCameraToDriver();

      if (isDisposed) return;

      // Iniciar stream de posición
      positionStream = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.bestForNavigation,
          distanceFilter: 15,
        ),
      ).listen(
        _onPositionUpdate,
        onError: (e) => debugPrint('Error en stream: $e'),
        cancelOnError: true,
      );
    } catch (e) {
      if (isDisposed) return;
      _setDefaultLocation('No se pudo obtener tu ubicación');
    }
  }

  void _setDefaultLocation(String errorMessage) {
    driverLocation = Point(coordinates: Position(-74.0817, 4.6097));
    error = errorMessage;
    onStateChanged();
    loadRoute();
  }

  void _updateDriverPosition(geo.Position pos) {
    driverLocation = Point(coordinates: Position(pos.longitude, pos.latitude));
    currentSpeed = pos.speed * 3.6;
    currentBearing = pos.heading;
    onStateChanged();
  }

  void _onPositionUpdate(geo.Position pos) async {
    if (isDisposed) return;

    _updateDriverPosition(pos);

    if (!_shouldUpdateCamera) return;

    final now = DateTime.now();
    if (now.difference(_lastCameraUpdate) < _cameraUpdateThrottle) return;

    if (is3DMode && toPickup && mapboxMap != null && mapReady) {
      _shouldUpdateCamera = false;
      _lastCameraUpdate = now;

      await _updateCamera3D(pos.latitude, pos.longitude, pos.heading);

      Future.delayed(const Duration(milliseconds: 2000), () {
        _shouldUpdateCamera = true;
      });
    }
  }

  Future<void> _enableLocationPuck() async {
    if (mapboxMap == null || isDisposed) return;

    try {
      await mapboxMap!.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: false,
          showAccuracyRing: false,
          puckBearingEnabled: true,
          puckBearing: PuckBearing.HEADING,
        ),
      );
    } catch (e) {
      debugPrint('Error en location settings: $e');
    }
  }

  // =========================================================================
  // CÁMARA
  // =========================================================================

  Future<void> _quickFocusOnDriver() async {
    if (mapboxMap == null || isDisposed) return;

    final center = driverLocation ?? pickup;

    try {
      await mapboxMap!.setCamera(CameraOptions(
        center: center,
        zoom: 18.0,
        // Sin pitch para evitar shaders 3D en dispositivos con drivers inestables
        pitch: 0,
        bearing: currentBearing,
      ));
    } catch (e) {
      debugPrint('Error en enfoque rápido: $e');
    }
  }

  Future<void> _updateCamera3D(double lat, double lng, double bearing) async {
    if (mapboxMap == null || isDisposed || !mapReady) return;

    try {
      await mapboxMap!.easeTo(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: 17.5,
          pitch: 55,
          bearing: bearing,
        ),
        MapAnimationOptions(duration: 800, startDelay: 0),
      );
    } catch (e) {
      debugPrint('Error actualizando cámara 3D: $e');
      is3DMode = false;
      onStateChanged();
    }
  }

  Future<void> moveCameraToDriver() async {
    if (mapboxMap == null || driverLocation == null || isDisposed || !mapReady) {
      return;
    }

    try {
      final options = is3DMode
          ? CameraOptions(
              center: driverLocation,
              zoom: 17.5,
              pitch: 55,
              bearing: currentBearing,
            )
          : CameraOptions(
              center: driverLocation,
              zoom: 16.5,
              pitch: 0,
              bearing: 0,
            );

      await mapboxMap!.easeTo(
        options,
        MapAnimationOptions(duration: 800, startDelay: 0),
      );
    } catch (e) {
      debugPrint('Error moviendo cámara: $e');
    }
  }

  Future<void> fitRouteInView() async {
    if (mapboxMap == null || driverLocation == null || isDisposed || !mapReady) {
      return;
    }

    try {
      final target = toPickup ? pickup : dropoff;
      
      final bounds = _calculateBounds(driverLocation!, target);
      final camera = await mapboxMap!.cameraForCoordinateBounds(
        bounds,
        MbxEdgeInsets(top: 200, left: 60, bottom: 350, right: 60),
        null, null, null, null,
      );

      if (!isDisposed && mapReady) {
        await mapboxMap!.easeTo(
          camera,
          MapAnimationOptions(duration: 1200, startDelay: 0),
        );
      }
    } catch (e) {
      debugPrint('Error ajustando vista: $e');
    }
  }

  CoordinateBounds _calculateBounds(Point p1, Point p2) {
    return CoordinateBounds(
      southwest: Point(
        coordinates: Position(
          math.min(p1.coordinates.lng.toDouble(), p2.coordinates.lng.toDouble()),
          math.min(p1.coordinates.lat.toDouble(), p2.coordinates.lat.toDouble()),
        ),
      ),
      northeast: Point(
        coordinates: Position(
          math.max(p1.coordinates.lng.toDouble(), p2.coordinates.lng.toDouble()),
          math.max(p1.coordinates.lat.toDouble(), p2.coordinates.lat.toDouble()),
        ),
      ),
      infiniteBounds: false,
    );
  }

  // =========================================================================
  // RUTA
  // =========================================================================

  Future<void> loadRoute() async {
    if (driverLocation == null || isDisposed) return;
    
    loadingRoute = true;
    error = null;
    onStateChanged();

    final target = toPickup ? pickup : dropoff;
    final waypoints = [
      ll.LatLng(
        driverLocation!.coordinates.lat.toDouble(),
        driverLocation!.coordinates.lng.toDouble(),
      ),
      ll.LatLng(
        target.coordinates.lat.toDouble(),
        target.coordinates.lng.toDouble(),
      ),
    ];

    try {
      final route = await MapboxService.getRoute(waypoints: waypoints);
      if (isDisposed) return;

      if (route == null) {
        loadingRoute = false;
        error = 'No se pudo calcular la ruta';
        onStateChanged();
        return;
      }

      distanceKm = route.distanceKm;
      etaMinutes = route.durationMinutes.ceil();
      loadingRoute = false;
      onStateChanged();

      await _drawRoute(route.geometry);
    } catch (e) {
      if (isDisposed) return;
      loadingRoute = false;
      error = 'Error al calcular la ruta';
      onStateChanged();
    }
  }

  Future<void> _drawRoute(List<ll.LatLng> geometry) async {
    if (mapboxMap == null || isDisposed || !mapReady) return;

    try {
      final style = mapboxMap!.style;

      // Limpiar capas anteriores
      await _safeRemoveLayer(style, _routeLayerId);
      await _safeRemoveLayer(style, _routeOutlineLayerId);
      await _safeRemoveSource(style, _routeSourceId);

      await Future.delayed(const Duration(milliseconds: 100));
      if (isDisposed || !mapReady) return;

      // Crear GeoJSON de la ruta
      final coordinates = geometry
          .map((p) => [p.longitude, p.latitude])
          .toList();
      final geoJsonData = '{"type":"Feature","properties":{},"geometry":'
          '{"type":"LineString","coordinates":$coordinates}}';

      // Agregar source y capas
      await style.addSource(GeoJsonSource(id: _routeSourceId, data: geoJsonData));
      
      if (isDisposed) return;

      await style.addLayer(LineLayer(
        id: _routeOutlineLayerId,
        sourceId: _routeSourceId,
        lineColor: 0xFF1565C0,
        lineWidth: 8.0,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
      ));

      if (isDisposed) return;

      await style.addLayer(LineLayer(
        id: _routeLayerId,
        sourceId: _routeSourceId,
        lineColor: 0xFF2196F3,
        lineWidth: 5.0,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
      ));
    } catch (e) {
      debugPrint('Error dibujando ruta: $e');
      mapError = true;
      onStateChanged();
    }
  }

  Future<void> _safeRemoveLayer(StyleManager style, String layerId) async {
    try {
      await style.removeStyleLayer(layerId);
    } catch (_) {}
  }

  Future<void> _safeRemoveSource(StyleManager style, String sourceId) async {
    try {
      await style.removeStyleSource(sourceId);
    } catch (_) {}
  }

  // =========================================================================
  // ACCIONES PÚBLICAS
  // =========================================================================

  Future<void> toggle3DMode() async {
    is3DMode = !is3DMode;
    onStateChanged();

    if (mapboxMap == null || !mapReady) return;

    try {
      if (is3DMode) {
        await Future.delayed(const Duration(milliseconds: 200));
        final center = driverLocation ?? pickup;
        await mapboxMap!.easeTo(
          CameraOptions(center: center, zoom: 17.5, pitch: 55, bearing: currentBearing),
          MapAnimationOptions(duration: 1000, startDelay: 0),
        );
      } else {
        await fitRouteInView();
      }
    } catch (e) {
      debugPrint('Error toggle 3D: $e');
      is3DMode = false;
      onStateChanged();
    }
  }

  Future<void> centerOnDriver() async {
    if (driverLocation == null || mapboxMap == null || !mapReady) return;

    try {
      final options = is3DMode
          ? CameraOptions(
              center: driverLocation,
              zoom: 17.5,
              pitch: 55,
              bearing: currentBearing,
            )
          : CameraOptions(
              center: driverLocation,
              zoom: 16.5,
              pitch: 0,
              bearing: 0,
            );

      await mapboxMap!.easeTo(
        options,
        MapAnimationOptions(duration: 800, startDelay: 0),
      );
    } catch (e) {
      debugPrint('Error centrando: $e');
    }
  }

  /// Marca que el conductor llegó al punto de recogida.
  /// Ahora espera que el cliente se suba antes de iniciar el viaje.
  Future<void> onArrivedPickup() async {
    if (!toPickup || isDisposed) return;
    
    // Cambiar estado: llegó al punto, espera al cliente
    toPickup = false;
    arrivedAtPickup = true;
    onStateChanged();
    
    // Eliminar el marcador del punto de recogida
    await _removePickupMarker();
  }

  /// Inicia el viaje una vez que el cliente se subió.
  /// Recalcula la ruta hacia el destino.
  Future<void> onStartTrip() async {
    if (!arrivedAtPickup || isDisposed) return;
    
    // Cambiar estado: viaje en curso hacia destino
    arrivedAtPickup = false;
    onStateChanged();
    
    // Recalcular ruta hacia el destino
    await loadRoute();
    await fitRouteInView();
  }

  // =========================================================================
  // UTILIDADES
  // =========================================================================

  double calculateDistance(Point p1, Point p2) {
    const r = 6371000.0;
    final lat1 = p1.coordinates.lat.toDouble() * math.pi / 180;
    final lat2 = p2.coordinates.lat.toDouble() * math.pi / 180;
    final dLat = (p2.coordinates.lat.toDouble() - p1.coordinates.lat.toDouble()) *
        math.pi / 180;
    final dLng = (p2.coordinates.lng.toDouble() - p1.coordinates.lng.toDouble()) *
        math.pi / 180;
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
