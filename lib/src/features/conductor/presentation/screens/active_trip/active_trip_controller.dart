import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../../../global/services/mapbox_service.dart';
import '../../../../../core/config/env_config.dart';

/// Controlador para la lógica de negocio del viaje activo
/// Separa la lógica del mapa de la UI para mejor mantenimiento
class ActiveTripController {
  // Estado de inicialización de Mapbox
  static bool _mapboxInitialized = false;

  // Estado del viaje
  bool isDisposed = false;
  bool mapReady = false;
  bool mapError = false;
  bool is3DMode = false;
  bool locationTrackingStarted = false;
  bool toPickup = true;
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

  // Mapa
  MapboxMap? mapboxMap;
  StreamSubscription<geo.Position>? positionStream;

  // Throttling para actualizaciones de cámara - MÁS AGRESIVO
  DateTime _lastCameraUpdate = DateTime.now();
  static const Duration cameraUpdateThrottle = Duration(milliseconds: 1500);
  bool _shouldUpdateCamera = true;

  // IDs de capas
  static const String routeSourceId = 'route-source';
  static const String routeLayerId = 'route-layer';
  static const String routeOutlineLayerId = 'route-outline-layer';

  // IDs de marcadores
  static const String pickupMarkerId = 'pickup-marker';
  static const String dropoffMarkerId = 'dropoff-marker';

  // Point annotation manager para marcadores
  PointAnnotationManager? _pointAnnotationManager;
  PointAnnotation? _pickupAnnotation;
  PointAnnotation? _dropoffAnnotation;

  // Callbacks
  final VoidCallback onStateChanged;

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

  /// Limpieza completa de recursos
  void dispose() {
    isDisposed = true;

    // Cancelar stream de forma agresiva
    if (positionStream != null) {
      positionStream!.pause();
      positionStream!.cancel();
      positionStream = null;
    }

    // Limpiar annotation manager
    try {
      if (_pointAnnotationManager != null) {
        _pointAnnotationManager!.deleteAll();
        _pointAnnotationManager = null;
      }
      _pickupAnnotation = null;
      _dropoffAnnotation = null;
    } catch (_) {}

    // Deshabilitar location component antes de destruir
    try {
      mapboxMap?.location.updateSettings(
        LocationComponentSettings(enabled: false),
      );
    } catch (_) {}

    mapboxMap = null;
  }

  /// Maneja la creación del mapa
  void onMapCreated(MapboxMap map) async {
    if (isDisposed) return;

    // Verificar y configurar Mapbox si no está inicializado
    await _ensureMapboxInitialized();

    mapboxMap = map;
  }

  /// Asegura que Mapbox esté inicializado con el token correcto
  Future<void> _ensureMapboxInitialized() async {
    if (_mapboxInitialized) return;

    try {
      // Configurar token programáticamente como respaldo
      MapboxOptions.setAccessToken(EnvConfig.mapboxPublicToken);
      _mapboxInitialized = true;
      debugPrint('✅ Mapbox inicializado en ActiveTripController');
    } catch (e) {
      debugPrint('⚠️ Error inicializando Mapbox en controller: $e');
      mapError = true;
      error = 'Error de configuración del mapa';
      onStateChanged();
    }
  }

  /// Inicialización diferida después de que el estilo cargue
  Future<void> onStyleLoaded() async {
    if (isDisposed) return;
    mapReady = true;

    // Enfocar inmediatamente en la ubicación del conductor
    is3DMode = true;
    onStateChanged();

    // Mover cámara INMEDIATAMENTE sin esperar
    _quickFocusOnDriver();

    // Habilitar location puck en paralelo
    _enableLocationPuck().catchError((e) {
      debugPrint('Error habilitando location puck: $e');
    });

    // Agregar marcadores de pickup y destino
    _addMarkers();

    // Iniciar tracking de ubicación
    if (!locationTrackingStarted) {
      locationTrackingStarted = true;
      startLocationTracking();
    }
  }

  /// Agrega los marcadores de punto de recogida y destino
  Future<void> _addMarkers() async {
    if (mapboxMap == null || isDisposed || !mapReady) return;

    try {
      // Crear el annotation manager si no existe
      _pointAnnotationManager ??= await mapboxMap!.annotations
          .createPointAnnotationManager();

      if (_pointAnnotationManager == null || isDisposed) return;

      // Crear marcador de pickup (cliente) - punto azul estilo Uber
      final pickupOptions = PointAnnotationOptions(
        geometry: pickup,
        iconSize: 1.3,
        iconAnchor: IconAnchor.CENTER,
        textField: '●', // Círculo sólido para pickup
        textSize: 32.0,
        textColor: 0xFF2196F3, // Azul
        textHaloColor: 0xFFFFFFFF, // Borde blanco
        textHaloWidth: 2.0,
      );

      _pickupAnnotation = await _pointAnnotationManager!.create(pickupOptions);

      // Crear marcador de destino - punto rojo
      final dropoffOptions = PointAnnotationOptions(
        geometry: dropoff,
        iconSize: 1.3,
        iconAnchor: IconAnchor.CENTER,
        textField: '◆', // Diamante para destino
        textSize: 28.0,
        textColor: 0xFFF44336, // Rojo
        textHaloColor: 0xFFFFFFFF, // Borde blanco
        textHaloWidth: 2.0,
      );

      _dropoffAnnotation = await _pointAnnotationManager!.create(
        dropoffOptions,
      );

      debugPrint('✅ Marcadores agregados correctamente');
    } catch (e) {
      debugPrint('⚠️ Error agregando marcadores: $e');
    }
  }

  /// Enfoque rápido inicial en el conductor
  Future<void> _quickFocusOnDriver() async {
    if (mapboxMap == null || isDisposed) return;

    final center = driverLocation ?? pickup;

    try {
      await mapboxMap!.setCamera(
        CameraOptions(
          center: center,
          zoom: 18.0, // Zoom más cercano para mejor visualización
          pitch: 60,
          bearing: currentBearing,
        ),
      );
    } catch (e) {
      debugPrint('Error en enfoque rápido: $e');
    }
  }

  /// Maneja errores de carga del mapa
  void onMapLoadError(MapLoadingErrorEventData eventData) {
    if (isDisposed) return;
    debugPrint(
      'Error cargando mapa: ${eventData.type} -> ${eventData.message}',
    );
    mapError = true;
    error = 'Error al cargar el mapa';
    onStateChanged();
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

  Future<void> startLocationTracking() async {
    if (isDisposed) return;

    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (isDisposed) return;

      if (!serviceEnabled) {
        driverLocation = Point(coordinates: Position(-74.0817, 4.6097));
        error = 'Activa el GPS para navegación';
        onStateChanged();
        await loadRoute();
        return;
      }

      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (isDisposed) return;

      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (isDisposed) return;
      }

      if (permission == geo.LocationPermission.deniedForever ||
          permission == geo.LocationPermission.denied) {
        driverLocation = Point(coordinates: Position(-74.0817, 4.6097));
        error = 'Permisos de ubicación requeridos';
        onStateChanged();
        await loadRoute();
        return;
      }

      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (isDisposed) return;
      driverLocation = Point(
        coordinates: Position(pos.longitude, pos.latitude),
      );
      currentBearing = pos.heading;
      onStateChanged();

      await loadRoute();
      await moveCameraToDriver();

      if (isDisposed) return;

      // Stream de posición con configuración más liviana
      positionStream =
          geo.Geolocator.getPositionStream(
            locationSettings: const geo.LocationSettings(
              accuracy: geo.LocationAccuracy.bestForNavigation,
              distanceFilter: 15, // Cada 15 metros
            ),
          ).listen(
            _onPositionUpdate,
            onError: (e) => debugPrint('Error en stream de posición: $e'),
            cancelOnError: true,
          );
    } catch (e) {
      if (isDisposed) return;
      driverLocation = Point(coordinates: Position(-74.0817, 4.6097));
      error = 'No se pudo obtener tu ubicación.';
      onStateChanged();
      await loadRoute();
    }
  }

  void _onPositionUpdate(geo.Position pos) async {
    if (isDisposed) return;

    driverLocation = Point(coordinates: Position(pos.longitude, pos.latitude));
    currentSpeed = pos.speed * 3.6;
    currentBearing = pos.heading;
    onStateChanged();

    // Throttle más agresivo para actualizaciones de cámara
    if (!_shouldUpdateCamera) return;

    final now = DateTime.now();
    if (now.difference(_lastCameraUpdate) < cameraUpdateThrottle) return;

    // Solo actualizar cámara si está activo el modo 3D
    if (is3DMode && toPickup && mapboxMap != null && mapReady) {
      _shouldUpdateCamera = false;
      _lastCameraUpdate = now;

      await updateCamera3DSafe(pos.latitude, pos.longitude, pos.heading);

      // Re-habilitar después de un tiempo
      Future.delayed(const Duration(milliseconds: 2000), () {
        _shouldUpdateCamera = true;
      });
    }
  }

  /// Actualiza la cámara en modo 3D con protección contra errores
  Future<void> updateCamera3DSafe(
    double lat,
    double lng,
    double bearing,
  ) async {
    if (mapboxMap == null || isDisposed || !mapReady) return;

    try {
      await mapboxMap!.easeTo(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: 17.5, // Zoom más cercano para navegación
          pitch: 55, // Pitch más inclinado estilo DiDi/Uber
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
    if (mapboxMap == null ||
        driverLocation == null ||
        isDisposed ||
        !mapReady) {
      return;
    }

    try {
      if (is3DMode) {
        // Vista de navegación 3D enfocada en el conductor
        await mapboxMap!.easeTo(
          CameraOptions(
            center: driverLocation,
            zoom: 17.5, // Zoom aumentado
            pitch: 55,
            bearing: currentBearing,
          ),
          MapAnimationOptions(duration: 1000, startDelay: 0),
        );
      } else {
        // Vista 2D centrada en conductor
        await mapboxMap!.easeTo(
          CameraOptions(
            center: driverLocation,
            zoom: 16.5, // Zoom aumentado
            pitch: 0,
            bearing: 0,
          ),
          MapAnimationOptions(duration: 800, startDelay: 0),
        );
      }
    } catch (e) {
      debugPrint('Error moviendo cámara: $e');
    }
  }

  Future<void> fitRouteInView() async {
    if (mapboxMap == null ||
        driverLocation == null ||
        isDisposed ||
        !mapReady) {
      return;
    }

    try {
      final target = toPickup ? pickup : dropoff;

      final southwest = Point(
        coordinates: Position(
          math.min(
            driverLocation!.coordinates.lng.toDouble(),
            target.coordinates.lng.toDouble(),
          ),
          math.min(
            driverLocation!.coordinates.lat.toDouble(),
            target.coordinates.lat.toDouble(),
          ),
        ),
      );
      final northeast = Point(
        coordinates: Position(
          math.max(
            driverLocation!.coordinates.lng.toDouble(),
            target.coordinates.lng.toDouble(),
          ),
          math.max(
            driverLocation!.coordinates.lat.toDouble(),
            target.coordinates.lat.toDouble(),
          ),
        ),
      );

      final camera = await mapboxMap!.cameraForCoordinateBounds(
        CoordinateBounds(
          southwest: southwest,
          northeast: northeast,
          infiniteBounds: false,
        ),
        MbxEdgeInsets(top: 200, left: 60, bottom: 350, right: 60),
        null,
        null,
        null,
        null,
      );

      if (!isDisposed && mapReady) {
        await mapboxMap!.easeTo(
          camera,
          MapAnimationOptions(duration: 1200, startDelay: 0),
        );
      }
    } catch (e) {
      debugPrint('Error ajustando vista de ruta: $e');
    }
  }

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
      final coordinates = geometry.map((point) {
        return Position(point.longitude, point.latitude);
      }).toList();

      final style = mapboxMap!.style;

      await _safeRemoveLayer(style, routeLayerId);
      await _safeRemoveLayer(style, routeOutlineLayerId);
      await _safeRemoveSource(style, routeSourceId);

      await Future.delayed(const Duration(milliseconds: 100));
      if (isDisposed || !mapReady) return;

      final geoJsonData =
          '{"type":"Feature","properties":{},"geometry":{"type":"LineString","coordinates":${coordinates.map((c) => [c.lng.toDouble(), c.lat.toDouble()]).toList()}}}';

      await style.addSource(
        GeoJsonSource(id: routeSourceId, data: geoJsonData),
      );

      if (isDisposed) return;

      await style.addLayer(
        LineLayer(
          id: routeOutlineLayerId,
          sourceId: routeSourceId,
          lineColor: 0xFF1565C0,
          lineWidth: 8.0,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
        ),
      );

      if (isDisposed) return;

      await style.addLayer(
        LineLayer(
          id: routeLayerId,
          sourceId: routeSourceId,
          lineColor: 0xFF2196F3,
          lineWidth: 5.0,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
        ),
      );
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

  double calculateDistance(Point p1, Point p2) {
    const r = 6371000.0;
    final lat1 = p1.coordinates.lat.toDouble() * math.pi / 180;
    final lat2 = p2.coordinates.lat.toDouble() * math.pi / 180;
    final dLat =
        (p2.coordinates.lat.toDouble() - p1.coordinates.lat.toDouble()) *
        math.pi /
        180;
    final dLng =
        (p2.coordinates.lng.toDouble() - p1.coordinates.lng.toDouble()) *
        math.pi /
        180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Alterna entre modo 2D y 3D con protección
  Future<void> toggle3DMode() async {
    if (is3DMode) {
      // Desactivar 3D - vista general de ruta
      is3DMode = false;
      onStateChanged();

      if (mapboxMap != null && mapReady) {
        try {
          await fitRouteInView();
        } catch (e) {
          debugPrint('Error desactivando 3D: $e');
        }
      }
    } else {
      // Activar 3D con vista de navegación
      is3DMode = true;
      onStateChanged();

      await Future.delayed(const Duration(milliseconds: 200));

      if (mapboxMap != null && mapReady) {
        final centerPoint = driverLocation ?? pickup;
        try {
          await mapboxMap!.easeTo(
            CameraOptions(
              center: centerPoint,
              zoom: 17.5, // Zoom aumentado
              pitch: 55,
              bearing: currentBearing,
            ),
            MapAnimationOptions(duration: 1000, startDelay: 0),
          );
        } catch (e) {
          debugPrint('Error activando modo 3D: $e');
          is3DMode = false;
          onStateChanged();
        }
      }
    }
  }

  Future<void> centerOnDriver() async {
    if (driverLocation == null || mapboxMap == null || !mapReady) return;

    try {
      if (is3DMode) {
        // Modo navegación 3D - seguir al conductor
        await mapboxMap!.easeTo(
          CameraOptions(
            center: driverLocation,
            zoom: 17.5, // Zoom aumentado
            pitch: 55,
            bearing: currentBearing,
          ),
          MapAnimationOptions(duration: 800, startDelay: 0),
        );
      } else {
        // Modo 2D - centrar en conductor
        await mapboxMap!.easeTo(
          CameraOptions(
            center: driverLocation,
            zoom: 16.5, // Zoom aumentado
            pitch: 0,
            bearing: 0,
          ),
          MapAnimationOptions(duration: 800, startDelay: 0),
        );
      }
    } catch (e) {
      debugPrint('Error centrando cámara: $e');
    }
  }

  Future<void> onArrivedPickup() async {
    if (!toPickup || isDisposed) return;
    toPickup = false;
    onStateChanged();
    await loadRoute();
    await fitRouteInView();
  }
}
