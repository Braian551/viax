import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:viax/src/global/services/mapbox_service.dart';
import 'package:viax/src/global/services/app_secrets_service.dart';
import 'package:viax/src/global/services/trip_persistence_service.dart';
import 'package:viax/src/features/conductor/services/trip_tracking_service.dart';

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
  // Inicia en 3D por defecto para mejor experiencia de navegación tipo Waze/Google Maps
  bool is3DMode = true;
  bool toPickup = true;           // En camino al punto de recogida
  bool arrivedAtPickup = false;   // Llegó al punto, esperando iniciar viaje
  bool loadingRoute = false;
  String? error;

  // Datos de navegación
  double distanceKm = 0;          // Distancia ESTIMADA de la ruta
  double distanciaRecorridaKm = 0; // Distancia REAL recorrida (tracking)
  int etaMinutes = 0;
  double currentSpeed = 0;
  double currentBearing = 0;
  
  // Datos de tracking en tiempo real
  double precioActual = 0;
  int tiempoTranscurridoSeg = 0;
  bool trackingActivo = false;

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

  // Persistencia y GPS acumulativo
  double _accumulatedDistance = 0.0;
  Point? _lastSavedLocation;
  DateTime? _startTime;
  
  // Servicio de tracking en tiempo real
  final TripTrackingService _trackingService = TripTrackingService();

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
    _cleanupTrackingService();
    mapboxMap = null;
  }

  void _stopLocationTracking() {
    positionStream?.pause();
    positionStream?.cancel();
    positionStream = null;
  }
  
  void _cleanupTrackingService() {
    _trackingService.onTrackingUpdate = null;
    _trackingService.onError = null;
    // No detenemos el tracking aquí porque puede ser que el usuario
    // esté navegando fuera temporalmente. El tracking se detiene
    // explícitamente al finalizar o cancelar el viaje.
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
      final token = AppSecretsService.instance.mapboxToken;
      if (token.isNotEmpty) {
        MapboxOptions.setAccessToken(token);
        _mapboxInitialized = true;
        debugPrint('✅ Mapbox inicializado');
      } else {
        debugPrint('⚠️ Mapbox token no disponible');
      }
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
      // =====================================================================
      // MARCADOR DE PICKUP (punto de recogida) - Estilo Pin Verde tipo Waze
      // Múltiples capas para crear efecto de pin con sombra
      // =====================================================================
      if (toPickup) {
        _pickupAnnotationManager ??= await mapboxMap!.annotations
            .createCircleAnnotationManager();

        if (_pickupAnnotationManager != null && !isDisposed) {
          // Capa 1: Sombra/Glow exterior (efecto de profundidad)
          await _pickupAnnotationManager!.create(CircleAnnotationOptions(
            geometry: pickup,
            circleRadius: 28.0,
            circleColor: 0xFF1B5E20,      // Verde muy oscuro para sombra
            circleOpacity: 0.25,
            circleStrokeWidth: 0,
          ));
          
          // Capa 2: Halo medio
          await _pickupAnnotationManager!.create(CircleAnnotationOptions(
            geometry: pickup,
            circleRadius: 22.0,
            circleColor: 0xFF2E7D32,      // Verde oscuro
            circleOpacity: 0.5,
            circleStrokeWidth: 0,
          ));
          
          // Capa 3: Círculo principal (pin body)
          await _pickupAnnotationManager!.create(CircleAnnotationOptions(
            geometry: pickup,
            circleRadius: 16.0,
            circleColor: 0xFF4CAF50,      // Verde brillante
            circleStrokeColor: 0xFFFFFFFF,
            circleStrokeWidth: 3.0,
            circleOpacity: 1.0,
            circleStrokeOpacity: 1.0,
          ));
          
          // Capa 4: Punto central blanco (como Google Maps pin)
          await _pickupAnnotationManager!.create(CircleAnnotationOptions(
            geometry: pickup,
            circleRadius: 6.0,
            circleColor: 0xFFFFFFFF,      // Blanco centro
            circleOpacity: 1.0,
            circleStrokeWidth: 0,
          ));
          
          debugPrint('✅ Marcador PIN de pickup agregado');
        }
      }

      // =====================================================================
      // MARCADOR DE DESTINO - Estilo Pin Rojo tipo Google Maps
      // =====================================================================
      _dropoffAnnotationManager ??= await mapboxMap!.annotations
          .createCircleAnnotationManager();

      if (_dropoffAnnotationManager != null && !isDisposed) {
        // Capa 1: Sombra exterior
        await _dropoffAnnotationManager!.create(CircleAnnotationOptions(
          geometry: dropoff,
          circleRadius: 26.0,
          circleColor: 0xFFB71C1C,        // Rojo muy oscuro para sombra
          circleOpacity: 0.25,
          circleStrokeWidth: 0,
        ));
        
        // Capa 2: Halo medio
        await _dropoffAnnotationManager!.create(CircleAnnotationOptions(
          geometry: dropoff,
          circleRadius: 20.0,
          circleColor: 0xFFC62828,        // Rojo oscuro
          circleOpacity: 0.5,
          circleStrokeWidth: 0,
        ));
        
        // Capa 3: Círculo principal (pin body)
        await _dropoffAnnotationManager!.create(CircleAnnotationOptions(
          geometry: dropoff,
          circleRadius: 14.0,
          circleColor: 0xFFE53935,        // Rojo brillante
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 3.0,
          circleOpacity: 1.0,
          circleStrokeOpacity: 1.0,
        ));
        
        // Capa 4: Punto central blanco
        await _dropoffAnnotationManager!.create(CircleAnnotationOptions(
          geometry: dropoff,
          circleRadius: 5.0,
          circleColor: 0xFFFFFFFF,        // Blanco centro
          circleOpacity: 1.0,
          circleStrokeWidth: 0,
        ));
        
        debugPrint('✅ Marcador PIN de destino agregado');
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
    
    // --- LÓGICA DE ACUMULACIÓN GPS (Durante el viaje) ---
    if (!toPickup && !arrivedAtPickup) {
      _processGpsAccumulation(pos, now);
    }

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

  void _processGpsAccumulation(geo.Position pos, DateTime now) {
    // Si es la primera vez
    if (_lastSavedLocation == null) {
      _lastSavedLocation = Point(coordinates: Position(pos.longitude, pos.latitude));
      return;
    }

    if (_lastSavedLocation == null) return; // Paranoia check

    // Calcular distancia desde último punto guardado
    final currentPoint = Point(coordinates: Position(pos.longitude, pos.latitude));
    final dist = calculateDistance(_lastSavedLocation!, currentPoint);

    // Filtrar jitter: Solo acumular si se movió > 30 metros
    if (dist > 30) {
      _accumulatedDistance += (dist / 1000.0); // Convertir a KM
      _lastSavedLocation = currentPoint;

      // Actualizar UI
      distanceKm = _accumulatedDistance;
      
      // Persistir progreso
      TripPersistenceService().updateTripProgress(
        distanceKm: _accumulatedDistance,
      );
      
      onStateChanged();
    }
  }

  Future<void> _enableLocationPuck() async {
    if (mapboxMap == null || isDisposed) return;

    try {
      // Configurar el puck de ubicación del conductor
      // Sin pulsing para evitar artefactos visuales (espacios blancos)
      await mapboxMap!.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: false,         // Desactivado para evitar artefactos
          showAccuracyRing: false,
          puckBearingEnabled: true,      // Muestra dirección del conductor
          puckBearing: PuckBearing.HEADING,
        ),
      );
      debugPrint('✅ Location puck habilitado');
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
      // Iniciar con vista 3D por defecto para experiencia de navegación inmersiva
      await mapboxMap!.setCamera(CameraOptions(
        center: center,
        zoom: 17.5,
        pitch: is3DMode ? 55 : 0,
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
  /// Recalcula la ruta hacia el destino e inicia tracking en tiempo real.
  Future<void> onStartTrip() async {
    if (!arrivedAtPickup || isDisposed) return;
    
    // Cambiar estado: viaje en curso hacia destino
    arrivedAtPickup = false;
    onStateChanged();
    
    // Recalcular ruta hacia el destino
    await loadRoute();
    await fitRouteInView();

    // INICIAR PERSISTENCIA LOCAL
    _startTime = DateTime.now();
    _accumulatedDistance = 0.0;
    _lastSavedLocation = driverLocation;
  }
  
  /// Inicia el tracking en tiempo real hacia el servidor
  /// Llamar desde la pantalla con los IDs del viaje
  /// [startTime] - Tiempo de inicio del viaje (para sincronizar cronómetro)
  Future<void> startRealTimeTracking({
    required int solicitudId,
    required int conductorId,
    DateTime? startTime,
  }) async {
    debugPrint('🚀 [Controller] Iniciando tracking en tiempo real para viaje $solicitudId');
    
    // Usar el tiempo proporcionado o crear uno nuevo
    _startTime = startTime ?? DateTime.now();
    trackingActivo = true;
    
    // Configurar callbacks del servicio de tracking
    _trackingService.onTrackingUpdate = (data) {
      distanciaRecorridaKm = data.distanciaKm; // Distancia REAL recorrida
      tiempoTranscurridoSeg = data.tiempoSegundos;
      precioActual = data.precioActual;
      currentSpeed = data.velocidadKmh;
      onStateChanged();
    };
    
    _trackingService.onError = (error) {
      debugPrint('⚠️ [Controller] Error de tracking: $error');
    };
    
    // Iniciar tracking con el servicio - SINCRONIZADO con el tiempo de la pantalla
    await _trackingService.startTracking(
      solicitudId: solicitudId,
      conductorId: conductorId,
      faseViaje: 'hacia_destino',
      startTime: _startTime,
    );
    
    // También guardar en persistencia local
    await TripPersistenceService().saveActiveTrip(
      tripId: solicitudId,
      role: 'conductor',
      startTime: _startTime!,
      initialDistance: 0.0,
    );
    
    onStateChanged();
  }
  
  /// Finaliza el tracking y obtiene el precio final
  /// [tiempoRealSegundos] - Tiempo real medido desde inicio hasta fin del viaje
  Future<TrackingFinalResult?> finalizeTracking({int? tiempoRealSegundos}) async {
    if (!trackingActivo) {
      debugPrint('⚠️ [Controller] Tracking no estaba activo al finalizar');
      // Retornar resultado con la distancia acumulada local
      final tiempoFinal = tiempoRealSegundos ?? tiempoTranscurridoSeg;
      return TrackingFinalResult(
        success: true,
        precioFinal: precioActual,
        distanciaRealKm: distanciaRecorridaKm,
        tiempoRealMin: (tiempoFinal / 60).ceil(),
        tiempoRealSeg: tiempoFinal,
        diferenciaPrecio: 0,
        mensaje: 'Datos locales (tracking no activo)',
      );
    }
    
    debugPrint('📊 [Controller] Finalizando tracking con tiempo real: ${tiempoRealSegundos}s');
    
    final result = await _trackingService.finalizeTracking(tiempoRealSegundos: tiempoRealSegundos);
    
    if (result != null && result.success) {
      precioActual = result.precioFinal;
      distanciaRecorridaKm = result.distanciaRealKm;
      trackingActivo = false;
      onStateChanged();
      
      // Limpiar persistencia local
      await TripPersistenceService().clearActiveTrip();
    }
    
    return result;
  }
  
  /// Detiene el tracking sin finalizar (para cancelaciones)
  Future<void> stopTracking() async {
    await _trackingService.stopTracking();
    trackingActivo = false;
    await TripPersistenceService().clearActiveTrip();
    onStateChanged();
  }
  
  /// Inicia el rastreo persistente (llamado desde la pantalla con los IDs)
  /// @deprecated Usar startRealTimeTracking en su lugar
  Future<void> startPersistentTracking({
    required int tripId,
    required String role,
  }) async {
    _startTime = DateTime.now();
    await TripPersistenceService().saveActiveTrip(
      tripId: tripId,
      role: role,
      startTime: _startTime!,
      initialDistance: 0.0,
    );
  }

  /// Restaura estado desde persistencia
  void restoreState(double restoredDistance) {
    _accumulatedDistance = restoredDistance;
    distanceKm = restoredDistance;
    onStateChanged();
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
