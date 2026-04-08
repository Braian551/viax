// lib/src/global/services/mapbox_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:viax/src/core/network/network_request_executor.dart';
import 'app_secrets_service.dart';
import 'quota_monitor_service.dart';

/// Servicio para interactuar con la API de Mapbox
/// Maneja mapas, rutas, geocoding y optimizaciÃ³n de rutas
class MapboxService {
  static const String _baseUrl = 'https://api.mapbox.com';
  static const String _routeCacheVersion = 'v2_geojson_full';
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();
  static const Distance _distance = Distance();
  static const Duration _routeCacheTtl = Duration(minutes: 5);
  static const double _routeReuseThresholdMeters = 80.0;
  static const double _routeSimplifyToleranceMeters = 10.0;
  static final Map<String, _RouteCacheEntry> _routeCache = {};
  static String? _lastRouteCacheKey;
  static List<LatLng>? _lastRouteWaypoints;

  // ============================================
  // DIRECTIONS API (Rutas y NavegaciÃ³n)
  // ============================================

  /// Obtener ruta entre dos o mÃ¡s puntos usando Mapbox Directions API
  ///
  /// [waypoints] - Lista de coordenadas (mÃ­nimo 2)
  /// [profile] - Tipo de transporte: driving, walking, cycling
  /// [alternatives] - Si es true, devuelve rutas alternativas
  /// [steps] - Si es true, incluye instrucciones paso a paso
  ///
  /// Retorna [MapboxRoute] con la informaciÃ³n de la ruta
  static Future<MapboxRoute?> getRoute({
    required List<LatLng> waypoints,
    String profile = 'driving', // driving, walking, cycling, driving-traffic
    bool alternatives = false,
    bool steps = false,
    bool geometries = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      if (waypoints.length < 2) {
        throw Exception(
          'Se necesitan al menos 2 puntos para calcular una ruta',
        );
      }

      _pruneRouteCache();

      final cacheKey = _buildRouteCacheKey(
        waypoints,
        profile: profile,
        alternatives: alternatives,
        steps: steps,
      );

      final directHit = _routeCache[cacheKey];
      if (directHit != null && !directHit.isExpired) {
        debugPrint(
          '[RoutePreview] cache_hit=direct ms=${stopwatch.elapsedMilliseconds} points=${directHit.route.geometry.length}',
        );
        _rememberRouteContext(cacheKey, waypoints);
        return directHit.route;
      }

      if (_lastRouteCacheKey != null &&
          _lastRouteWaypoints != null &&
          _canReuseLastRoute(
            previous: _lastRouteWaypoints!,
            current: waypoints,
          )) {
        final nearbyEntry = _routeCache[_lastRouteCacheKey!];
        if (nearbyEntry != null && !nearbyEntry.isExpired) {
          debugPrint(
            '[RoutePreview] cache_hit=movement_threshold threshold_m=$_routeReuseThresholdMeters ms=${stopwatch.elapsedMilliseconds} points=${nearbyEntry.route.geometry.length}',
          );
          _rememberRouteContext(_lastRouteCacheKey!, waypoints);
          return nearbyEntry.route;
        }
      }

      // Construir string de coordenadas: "lng,lat;lng,lat;..."
      final coordinates = waypoints
          .map((point) => '${point.longitude},${point.latitude}')
          .join(';');

      // Construir URL
      final url = Uri.parse(
        '$_baseUrl/directions/v5/mapbox/$profile/$coordinates'
        '?alternatives=$alternatives'
        '&steps=$steps'
        '&geometries=geojson'
        '&overview=full'
        '&access_token=${AppSecretsService.instance.mapboxToken}',
      );

      final result = await _network.getJson(
        url: url,
        timeout: const Duration(seconds: 10),
      );

      if (result.success && result.json != null) {
        // Incrementar contador de uso
        await QuotaMonitorService.incrementMapboxRouting();

        final rawRoute = await compute(
          _parseDirectionsResponse,
          jsonEncode(result.json),
        );
        if (rawRoute == null) {
          debugPrint(
            '[RoutePreview] api_empty ms=${stopwatch.elapsedMilliseconds}',
          );
          return null;
        }

        _routeCache[cacheKey] = _RouteCacheEntry(
          route: rawRoute,
          expiresAt: DateTime.now().add(_routeCacheTtl),
        );
        _rememberRouteContext(cacheKey, waypoints);

        debugPrint(
          '[RoutePreview] cache_miss source=mapbox duration_ms=${stopwatch.elapsedMilliseconds} polyline_points=${rawRoute.geometry.length}',
        );

        return rawRoute;
      } else {
        debugPrint(
          '[RoutePreview] api_error ms=${stopwatch.elapsedMilliseconds} reason=${result.error?.userMessage}',
        );
        print('Error en Mapbox Directions: ${result.error?.userMessage}');
      }

      return null;
    } catch (e) {
      debugPrint(
        '[RoutePreview] exception ms=${stopwatch.elapsedMilliseconds} error=$e',
      );
      print('Error obteniendo ruta de Mapbox: $e');
      return null;
    } finally {
      stopwatch.stop();
    }
  }

  static void _rememberRouteContext(String key, List<LatLng> waypoints) {
    _lastRouteCacheKey = key;
    _lastRouteWaypoints = List<LatLng>.from(waypoints);
  }

  static void _pruneRouteCache() {
    if (_routeCache.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final expiredKeys = _routeCache.entries
        .where((entry) => entry.value.expiresAt.isBefore(now))
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _routeCache.remove(key);
    }
  }

  static String _buildRouteCacheKey(
    List<LatLng> waypoints, {
    required String profile,
    required bool alternatives,
    required bool steps,
  }) {
    final pointsKey = waypoints
        .map(
          (point) =>
              '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}',
        )
        .join('|');
    return '$_routeCacheVersion|$profile|alt=$alternatives|steps=$steps|$pointsKey';
  }

  static bool _canReuseLastRoute({
    required List<LatLng> previous,
    required List<LatLng> current,
  }) {
    if (previous.length != current.length || previous.length < 2) {
      return false;
    }

    final originMovement = _distance.as(
      LengthUnit.Meter,
      previous.first,
      current.first,
    );
    final destinationMovement = _distance.as(
      LengthUnit.Meter,
      previous.last,
      current.last,
    );

    return originMovement <= _routeReuseThresholdMeters &&
        destinationMovement <= _routeReuseThresholdMeters;
  }

  static MapboxRoute _simplifyRoute(
    MapboxRoute route, {
    required double toleranceMeters,
  }) {
    final geometry = route.geometry;
    if (geometry.length < 3) {
      return route;
    }

    final simplified = _douglasPeucker(geometry, toleranceMeters);
    if (simplified.length < 2 || simplified.length >= geometry.length) {
      return route;
    }

    return route.copyWith(geometry: simplified);
  }

  static List<LatLng> _douglasPeucker(
    List<LatLng> points,
    double toleranceMeters,
  ) {
    if (points.length <= 2) {
      return List<LatLng>.from(points);
    }

    final keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;
    _simplifySegment(points, 0, points.length - 1, toleranceMeters, keep);

    final result = <LatLng>[];
    for (var i = 0; i < points.length; i++) {
      if (keep[i]) {
        result.add(points[i]);
      }
    }

    return result.length >= 2 ? result : List<LatLng>.from(points);
  }

  static void _simplifySegment(
    List<LatLng> points,
    int start,
    int end,
    double toleranceMeters,
    List<bool> keep,
  ) {
    if (end <= start + 1) {
      return;
    }

    final startPoint = points[start];
    final endPoint = points[end];
    double maxDistance = -1.0;
    int maxIndex = -1;

    for (var i = start + 1; i < end; i++) {
      final distance = _distanceToSegmentMeters(
        points[i],
        startPoint,
        endPoint,
      );
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    if (maxDistance > toleranceMeters && maxIndex > start && maxIndex < end) {
      keep[maxIndex] = true;
      _simplifySegment(points, start, maxIndex, toleranceMeters, keep);
      _simplifySegment(points, maxIndex, end, toleranceMeters, keep);
    }
  }

  static double _distanceToSegmentMeters(
    LatLng point,
    LatLng segmentStart,
    LatLng segmentEnd,
  ) {
    final projectedStart = _projectToMeters(segmentStart);
    final projectedEnd = _projectToMeters(segmentEnd);
    final projectedPoint = _projectToMeters(point);

    final dx = projectedEnd.x - projectedStart.x;
    final dy = projectedEnd.y - projectedStart.y;

    if (dx == 0 && dy == 0) {
      final distX = projectedPoint.x - projectedStart.x;
      final distY = projectedPoint.y - projectedStart.y;
      return math.sqrt((distX * distX) + (distY * distY));
    }

    final t = (((projectedPoint.x - projectedStart.x) * dx) +
            ((projectedPoint.y - projectedStart.y) * dy)) /
        ((dx * dx) + (dy * dy));
    final clampedT = t.clamp(0.0, 1.0);

    final closestX = projectedStart.x + (dx * clampedT);
    final closestY = projectedStart.y + (dy * clampedT);
    final distX = projectedPoint.x - closestX;
    final distY = projectedPoint.y - closestY;

    return math.sqrt((distX * distX) + (distY * distY));
  }

  static math.Point<double> _projectToMeters(LatLng point) {
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLng =
        metersPerDegreeLat * math.cos(point.latitude * math.pi / 180.0);

    return math.Point<double>(
      point.longitude * metersPerDegreeLng,
      point.latitude * metersPerDegreeLat,
    );
  }

  /// Optimizar orden de mÃºltiples waypoints para la ruta mÃ¡s eficiente
  /// Ãštil para delivery o mÃºltiples paradas
  static Future<MapboxRoute?> getOptimizedRoute({
    required LatLng origin,
    required LatLng destination,
    required List<LatLng> waypoints,
    String profile = 'driving',
  }) async {
    try {
      // Construir lista completa: origin, waypoints, destination
      final allPoints = [origin, ...waypoints, destination];

      // Construir string de coordenadas
      final coordinates = allPoints
          .map((point) => '${point.longitude},${point.latitude}')
          .join(';');

      // El endpoint de optimizaciÃ³n requiere indicar quÃ© puntos son fijos
      final url = Uri.parse(
        '$_baseUrl/optimized-trips/v1/mapbox/$profile/$coordinates'
        '?source=first' // Origen es el primer punto
        '&destination=last' // Destino es el Ãºltimo punto
        '&roundtrip=false' // No es un viaje circular
        '&steps=true'
        '&geometries=geojson'
        '&overview=full'
        '&access_token=${AppSecretsService.instance.mapboxToken}',
      );

      final result = await _network.getJson(
        url: url,
        timeout: const Duration(seconds: 10),
      );

      if (result.success && result.json != null) {
        await QuotaMonitorService.incrementMapboxRouting();

        return await compute(_parseOptimizationResponse, jsonEncode(result.json));
      }

      return null;
    } catch (e) {
      print('Error en ruta optimizada: $e');
      return null;
    }
  }

  // ============================================
  // STATIC IMAGES API
  // ============================================

  /// Obtener URL de imagen estÃ¡tica del mapa
  /// Ãštil para previsualizaciones o miniaturas
  static String getStaticMapUrl({
    required LatLng center,
    double zoom = 14,
    int width = 600,
    int height = 400,
    String style = 'streets-v12',
    List<MapMarker>? markers,
  }) {
    final lng = center.longitude;
    final lat = center.latitude;

    String overlays = '';

    // AÃ±adir marcadores si existen
    if (markers != null && markers.isNotEmpty) {
      for (var marker in markers) {
        overlays +=
            'pin-s-${marker.label}+${marker.color}(${marker.position.longitude},${marker.position.latitude}),';
      }
      // Remover Ãºltima coma
      if (overlays.isNotEmpty) {
        overlays = overlays.substring(0, overlays.length - 1);
      }
    }

    return '$_baseUrl/styles/v1/mapbox/$style/static/$overlays/$lng,$lat,$zoom,0/${width}x$height@2x?access_token=${AppSecretsService.instance.mapboxToken}';
  }

  // ============================================
  // GEOCODING API (BÃºsqueda de lugares)
  // ============================================

  /// Buscar lugares por texto
  /// [query] - Texto de bÃºsqueda (direcciÃ³n, nombre de lugar, etc.)
  /// [proximity] - Coordenadas para priorizar resultados cercanos
  /// [limit] - NÃºmero mÃ¡ximo de resultados (1-10)
  /// [types] - Tipos de resultados: address, poi, place, etc.
  static Future<List<MapboxPlace>> searchPlaces({
    required String query,
    LatLng? proximity,
    int limit = 5,
    List<String>? types,
    String? country,
    List<double>? bbox,
    bool fuzzyMatch = true,
  }) async {
    try {
      if (query.trim().isEmpty) return [];

      final queryParams = <String, String>{
        'access_token': AppSecretsService.instance.mapboxToken,
        'limit': limit.toString(),
        'language': 'es',
        'fuzzyMatch': fuzzyMatch.toString(),
      };

      if (proximity != null) {
        queryParams['proximity'] =
            '${proximity.longitude},${proximity.latitude}';
      }

      if (types != null && types.isNotEmpty) {
        queryParams['types'] = types.join(',');
      }
      
      // Restringir por país (muy importante para resultados locales)
      if (country != null && country.isNotEmpty) {
        queryParams['country'] = country;
      }
      
      // Restringir por bounding box (área geográfica específica)
      if (bbox != null && bbox.length == 4) {
        queryParams['bbox'] = bbox.join(',');
      }

      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        '$_baseUrl/geocoding/v5/mapbox.places/$encodedQuery.json',
      ).replace(queryParameters: queryParams);

      final result = await _network.getJson(
        url: url,
        timeout: const Duration(seconds: 10),
      );

      if (result.success && result.json != null) {
        return await compute(_parsePlacesResponse, jsonEncode(result.json));
      } else {
        print('Error en Mapbox Geocoding: ${result.error?.userMessage}');
      }

      return [];
    } catch (e) {
      print('Error buscando lugares: $e');
      return [];
    }
  }

  /// GeocodificaciÃ³n inversa: obtener direcciÃ³n desde coordenadas
  static Future<MapboxPlace?> reverseGeocode({required LatLng position}) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/geocoding/v5/mapbox.places/${position.longitude},${position.latitude}.json'
        '?access_token=${AppSecretsService.instance.mapboxToken}'
        '&language=es'
        '&types=address,poi,place',
      );

      final result = await _network.getJson(
        url: url,
        timeout: const Duration(seconds: 10),
      );

      if (result.success && result.json != null) {
        final data = result.json!;

        if (data['features'] != null && (data['features'] as List).isNotEmpty) {
          return MapboxPlace.fromJson(data['features'][0]);
        }
      }

      return null;
    } catch (e) {
      print('Error en geocodificaciÃ³n inversa: $e');
      return null;
    }
  }

  /// GeocodificaciÃ³n inversa solo para calles/direcciones
  /// Útil para snap-to-road que solo quiere calles, no casas
  static Future<MapboxPlace?> reverseGeocodeStreetOnly({
    required LatLng position,
  }) async {
    try {
      // Primero intentar solo con 'address' que es direcciÃ³n de calle
      final url = Uri.parse(
        '$_baseUrl/geocoding/v5/mapbox.places/${position.longitude},${position.latitude}.json'
        '?access_token=${AppSecretsService.instance.mapboxToken}'
        '&language=es'
        '&types=address',
      );

      final result = await _network.getJson(
        url: url,
        timeout: const Duration(seconds: 10),
      );

      if (result.success && result.json != null) {
        final data = result.json!;

        if (data['features'] != null && (data['features'] as List).isNotEmpty) {
          final features = data['features'] as List;

          // Filtrar solo resultados que sean de tipo "address"
          for (var feature in features) {
            final place = MapboxPlace.fromJson(feature);
            // address type son direcciones en calles/avenidas
            if (place.placeType == 'address') {
              return place;
            }
          }

          // Si no hay address, devolver el primero
          return MapboxPlace.fromJson(features[0]);
        }
      }

      return null;
    } catch (e) {
      print('Error en geocodificaciÃ³n inversa (calle): $e');
      return null;
    }
  }

  // ============================================
  // TILES API
  // ============================================

  /// Obtener URL para tiles de Mapbox (para flutter_map)
  /// [isDarkMode] - Si es true, usa estilo oscuro, si es false usa estilo claro
  static String getTileUrl({bool isDarkMode = false}) {
    final style = isDarkMode ? 'dark-v11' : 'streets-v12';
    return 'https://api.mapbox.com/styles/v1/mapbox/$style/tiles/{z}/{x}/{y}@2x?access_token=${AppSecretsService.instance.mapboxToken}';
  }

  /// Obtener estilo de mapa según el tema
  static String getMapStyle({bool isDarkMode = false}) {
    return isDarkMode ? 'dark-v11' : 'streets-v12';
  }

  // ============================================
  // MATRIX API (Distances y Tiempos)
  // ============================================

  /// Calcular matriz de distancias y tiempos entre mÃºltiples puntos
  /// Ãštil para encontrar el punto mÃ¡s cercano o comparar mÃºltiples destinos
  static Future<MapboxMatrix?> getMatrix({
    required List<LatLng> origins,
    required List<LatLng> destinations,
    String profile = 'driving',
  }) async {
    try {
      // Combinar todos los puntos
      final allPoints = [...origins, ...destinations];

      final coordinates = allPoints
          .map((point) => '${point.longitude},${point.latitude}')
          .join(';');

      // Indicar cuÃ¡les son orÃ­genes y cuÃ¡les destinos
      final sources = List.generate(origins.length, (i) => i).join(';');
      final destinationsIdx = List.generate(
        destinations.length,
        (i) => i + origins.length,
      ).join(';');

      final url = Uri.parse(
        '$_baseUrl/directions-matrix/v1/mapbox/$profile/$coordinates'
        '?sources=$sources'
        '&destinations=$destinationsIdx'
        '&access_token=${AppSecretsService.instance.mapboxToken}',
      );

      final result = await _network.getJson(
        url: url,
        timeout: const Duration(seconds: 10),
      );

      if (result.success && result.json != null) {
        await QuotaMonitorService.incrementMapboxRouting();

        final data = result.json!;
        return MapboxMatrix.fromJson(data);
      }

      return null;
    } catch (e) {
      print('Error en Mapbox Matrix: $e');
      return null;
    }
  }

  // ============================================
  // MAP MATCHING API (Snap to Road)
  // ============================================

  /// Proyectar un punto a la carretera/calle más cercana usando Map Matching API
  /// Esta API es específica para ajustar puntos GPS a carreteras reales
  /// [point] - Coordenadas a proyectar
  /// [radius] - Radio de búsqueda en metros (máximo 50)
  /// Retorna las coordenadas del punto en la carretera más cercana
  static Future<LatLng?> snapToRoad({
    required LatLng point,
    int radius = 25,
    String profile = 'driving',
  }) async {
    try {
      // Map Matching requiere al menos 2 puntos, usamos el mismo punto duplicado
      // con un pequeño offset para simular una "trayectoria" de un punto
      final offsetLat = 0.00005; // ~5 metros
      final point2 = LatLng(point.latitude + offsetLat, point.longitude);

      final coordinates =
          '${point.longitude},${point.latitude};${point2.longitude},${point2.latitude}';

      final url = Uri.parse(
        '$_baseUrl/matching/v5/mapbox/$profile/$coordinates'
        '?access_token=${AppSecretsService.instance.mapboxToken}'
        '&geometries=geojson'
        '&radiuses=$radius;$radius'
        '&steps=false'
        '&overview=full',
      );

      final result = await _network.getJson(
        url: url,
        timeout: const Duration(seconds: 10),
      );

      if (result.success && result.json != null) {
        final data = result.json!;

        if (data['matchings'] != null &&
            (data['matchings'] as List).isNotEmpty) {
          final matching = data['matchings'][0];

          // Obtener el primer punto de la geometría que es el más cercano al input
          if (matching['geometry'] != null &&
              matching['geometry']['coordinates'] != null) {
            final coords = matching['geometry']['coordinates'] as List;
            if (coords.isNotEmpty) {
              // El primer punto de la geometría es el snap del primer punto input
              final firstCoord = coords[0];
              return LatLng(firstCoord[1] as double, firstCoord[0] as double);
            }
          }

          // Alternativa: usar tracepoints para obtener la posición exacta
          if (data['tracepoints'] != null) {
            final tracepoints = data['tracepoints'] as List;
            if (tracepoints.isNotEmpty && tracepoints[0] != null) {
              final tracepoint = tracepoints[0];
              if (tracepoint['location'] != null) {
                final loc = tracepoint['location'] as List;
                return LatLng(loc[1] as double, loc[0] as double);
              }
            }
          }
        }

        // Si no hay matchings, puede que el punto esté muy lejos de cualquier carretera
        // Intentar con un radio mayor
        if (radius < 50) {
          return await snapToRoad(point: point, radius: 50, profile: profile);
        }
      }

      print('No se pudo hacer snap to road: ${result.statusCode}');
      return null;
    } catch (e) {
      print('Error en Map Matching: $e');
      return null;
    }
  }

  /// Proyectar un punto a la calle más cercana (solo para calles accesibles en carro)
  /// Esta es la función principal para snap-to-road en UI de selección de pickup
  static Future<LatLng?> snapToStreet({required LatLng point}) async {
    // Primero intentar Map Matching que es más preciso
    final snapped = await snapToRoad(point: point, radius: 30);

    if (snapped != null) {
      return snapped;
    }

    // Si falla, usar geocodificación inversa como fallback
    final place = await reverseGeocodeStreetOnly(position: point);
    if (place != null) {
      return place.coordinates;
    }

    // Si todo falla, devolver null
    return null;
  }
}

// ============================================
// MODELOS DE DATOS
// ============================================

/// Modelo de ruta de Mapbox
class MapboxRoute {
  final double distance; // en metros
  final double duration; // en segundos
  final List<LatLng> geometry; // Puntos de la ruta
  final List<MapboxStep>? steps; // Instrucciones paso a paso
  final String? routeSummary;

  MapboxRoute({
    required this.distance,
    required this.duration,
    required this.geometry,
    this.steps,
    this.routeSummary,
  });

  factory MapboxRoute.fromJson(Map<String, dynamic> json) {
    List<LatLng> geometry = [];

    // Parsear geometría GeoJSON o polyline codificada.
    if (json['geometry'] is Map<String, dynamic> &&
        json['geometry']['coordinates'] != null) {
      final coords = json['geometry']['coordinates'] as List;
      geometry = coords.map((coord) {
        return LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
      }).toList();
    } else if (json['geometry'] is String) {
      geometry = _decodePolyline(json['geometry'] as String);
    }

    // Parsear steps
    List<MapboxStep>? steps;
    if (json['legs'] != null) {
      final legs = json['legs'] as List;
      if (legs.isNotEmpty && legs[0]['steps'] != null) {
        final stepsData = legs[0]['steps'] as List;
        steps = stepsData.map((step) => MapboxStep.fromJson(step)).toList();
      }
    }

    return MapboxRoute(
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      geometry: geometry,
      steps: steps,
      routeSummary: json['summary'],
    );
  }

  MapboxRoute copyWith({
    double? distance,
    double? duration,
    List<LatLng>? geometry,
    List<MapboxStep>? steps,
    String? routeSummary,
  }) {
    return MapboxRoute(
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      geometry: geometry ?? this.geometry,
      steps: steps ?? this.steps,
      routeSummary: routeSummary ?? this.routeSummary,
    );
  }

  /// Distancia en kilómetros (safe getter that handles non-finite values)
  double get distanceKm {
    final km = distance / 1000;
    // Safety check: if result is not finite, return 0
    if (!km.isFinite) return 0.0;
    return km;
  }

  /// Duración en minutos (safe getter that handles non-finite values)
  double get durationMinutes {
    final mins = duration / 60;
    // Safety check: if result is not finite, return 0
    if (!mins.isFinite) return 0.0;
    return mins;
  }

  /// Formato legible de distancia
  String get formattedDistance {
    if (distanceKm < 1) {
      return '${distance.toStringAsFixed(0)} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Formato legible de duraciÃ³n
  String get formattedDuration {
    if (durationMinutes < 60) {
      return '${durationMinutes.toStringAsFixed(0)} min';
    }
    final hours = (durationMinutes / 60).floor();
    final mins = (durationMinutes % 60).toStringAsFixed(0);
    return '${hours}h ${mins}min';
  }
}

List<LatLng> _decodePolyline(String encoded) {
  final points = <LatLng>[];
  int index = 0;
  int lat = 0;
  int lng = 0;

  while (index < encoded.length) {
    int result = 0;
    int shift = 0;
    int b;
    do {
      if (index >= encoded.length) {
        return points;
      }
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dLat;

    result = 0;
    shift = 0;
    do {
      if (index >= encoded.length) {
        return points;
      }
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dLng;

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }

  return points;
}

/// Paso de instrucciÃ³n de ruta
class MapboxStep {
  final double distance;
  final double duration;
  final String instruction;
  final String? name;
  final String? maneuver;

  MapboxStep({
    required this.distance,
    required this.duration,
    required this.instruction,
    this.name,
    this.maneuver,
  });

  factory MapboxStep.fromJson(Map<String, dynamic> json) {
    return MapboxStep(
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      instruction: json['maneuver']?['instruction'] ?? '',
      name: json['name'],
      maneuver: json['maneuver']?['type'],
    );
  }
}

/// Matriz de distancias y tiempos
class MapboxMatrix {
  final List<List<double?>> durations; // en segundos
  final List<List<double?>> distances; // en metros

  MapboxMatrix({required this.durations, required this.distances});

  factory MapboxMatrix.fromJson(Map<String, dynamic> json) {
    return MapboxMatrix(
      durations:
          (json['durations'] as List?)
              ?.map((row) => (row as List).map((d) => d as double?).toList())
              .toList() ??
          [],
      distances:
          (json['distances'] as List?)
              ?.map((row) => (row as List).map((d) => d as double?).toList())
              .toList() ??
          [],
    );
  }
}

/// Marcador para mapas estÃ¡ticos
class MapMarker {
  final LatLng position;
  final String label; // 'a', 'b', 'c', etc. o 'star', 'circle'
  final String color; // hexadecimal sin #, ej: 'ff0000'

  MapMarker({required this.position, this.label = 'a', this.color = 'ff0000'});
}

class _RouteCacheEntry {
  final MapboxRoute route;
  final DateTime expiresAt;

  _RouteCacheEntry({
    required this.route,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Lugar encontrado por Geocoding API
class MapboxPlace {
  final String id;
  final String placeName; // Nombre completo del lugar
  final String text; // Nombre corto
  final LatLng coordinates;
  final String? address;
  final String? placeType; // poi, address, place, etc.
  final Map<String, dynamic>?
  context; // InformaciÃ³n de contexto (ciudad, paÃ­s, etc.)

  MapboxPlace({
    required this.id,
    required this.placeName,
    required this.text,
    required this.coordinates,
    this.address,
    this.placeType,
    this.context,
  });

  factory MapboxPlace.fromJson(Map<String, dynamic> json) {
    final coords = json['geometry']['coordinates'] as List;

    return MapboxPlace(
      id: json['id'] ?? '',
      placeName: json['place_name'] ?? '',
      text: json['text'] ?? '',
      coordinates: LatLng(coords[1] as double, coords[0] as double),
      address: json['properties']?['address'],
      placeType: (json['place_type'] as List?)?.first,
      context: json['context'] != null ? Map<String, dynamic>.from(json) : null,
    );
  }

  /// Obtener informaciÃ³n del contexto (ciudad, regiÃ³n, paÃ­s)
  String get contextInfo {
    if (context == null) return '';

    final parts = <String>[];
    final contextList = context!['context'] as List?;

    if (contextList != null) {
      for (var item in contextList) {
        if (item['id'].toString().startsWith('place.') ||
            item['id'].toString().startsWith('region.')) {
          parts.add(item['text']);
        }
      }
    }

    return parts.join(', ');
  }
}

// Helper functions for compute
MapboxRoute? _parseDirectionsResponse(String responseBody) {
  final data = json.decode(responseBody);
  if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
    return MapboxRoute.fromJson(data['routes'][0]);
  }
  return null;
}

MapboxRoute? _parseOptimizationResponse(String responseBody) {
  final data = json.decode(responseBody);
  if (data['trips'] != null && (data['trips'] as List).isNotEmpty) {
    return MapboxRoute.fromJson(data['trips'][0]);
  }
  return null;
}

List<MapboxPlace> _parsePlacesResponse(String responseBody) {
  final data = json.decode(responseBody);
  if (data['features'] != null) {
    final features = data['features'] as List;
    return features.map((f) => MapboxPlace.fromJson(f)).toList();
  }
  return [];
}

List<List<double>>? _simplifyRouteGeometryInIsolate(String payload) {
  final decoded = jsonDecode(payload) as Map<String, dynamic>;
  final tolerance = (decoded['toleranceMeters'] as num?)?.toDouble() ?? 10.0;
  final geometryRaw = decoded['geometry'] as List<dynamic>? ?? const [];
  if (geometryRaw.length < 3) {
    return geometryRaw
        .map((p) => [
              ((p as List)[0] as num).toDouble(),
              (p[1] as num).toDouble(),
            ])
        .toList();
  }

  final points = geometryRaw
      .map((p) => [
            ((p as List)[0] as num).toDouble(),
            (p[1] as num).toDouble(),
          ])
      .toList();

  final keep = List<bool>.filled(points.length, false);
  keep[0] = true;
  keep[points.length - 1] = true;

  void simplifySegment(int start, int end) {
    if (end <= start + 1) return;

    final startPoint = points[start];
    final endPoint = points[end];
    double maxDistance = -1;
    int maxIndex = -1;

    for (var i = start + 1; i < end; i++) {
      final point = points[i];
      final distance = _distanceToSegmentMetersInIsolate(
        point,
        startPoint,
        endPoint,
      );
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    if (maxDistance > tolerance && maxIndex > start && maxIndex < end) {
      keep[maxIndex] = true;
      simplifySegment(start, maxIndex);
      simplifySegment(maxIndex, end);
    }
  }

  simplifySegment(0, points.length - 1);

  final simplified = <List<double>>[];
  for (var i = 0; i < points.length; i++) {
    if (keep[i]) {
      simplified.add(points[i]);
    }
  }

  if (simplified.length < 2 || simplified.length >= points.length) {
    return points;
  }

  return simplified;
}

double _distanceToSegmentMetersInIsolate(
  List<double> point,
  List<double> start,
  List<double> end,
) {
  final projectedStart = _projectToMetersInIsolate(start[0], start[1]);
  final projectedEnd = _projectToMetersInIsolate(end[0], end[1]);
  final projectedPoint = _projectToMetersInIsolate(point[0], point[1]);

  final dx = projectedEnd.x - projectedStart.x;
  final dy = projectedEnd.y - projectedStart.y;

  if (dx == 0 && dy == 0) {
    final distX = projectedPoint.x - projectedStart.x;
    final distY = projectedPoint.y - projectedStart.y;
    return math.sqrt((distX * distX) + (distY * distY));
  }

  final t = (((projectedPoint.x - projectedStart.x) * dx) +
          ((projectedPoint.y - projectedStart.y) * dy)) /
      ((dx * dx) + (dy * dy));
  final clampedT = t.clamp(0.0, 1.0);

  final closestX = projectedStart.x + (dx * clampedT);
  final closestY = projectedStart.y + (dy * clampedT);
  final distX = projectedPoint.x - closestX;
  final distY = projectedPoint.y - closestY;

  return math.sqrt((distX * distX) + (distY * distY));
}

math.Point<double> _projectToMetersInIsolate(double lat, double lng) {
  const metersPerDegreeLat = 111320.0;
  final metersPerDegreeLng =
      metersPerDegreeLat * math.cos(lat * math.pi / 180.0);

  return math.Point<double>(
    lng * metersPerDegreeLng,
    lat * metersPerDegreeLat,
  );
}


