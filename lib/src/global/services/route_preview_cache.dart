import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:viax/src/core/config/app_config.dart';

import 'app_secrets_service.dart';
import 'mapbox_service.dart';

class RoutePreviewCacheEntry {
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final List<LatLng> polyline;
  final double distance;
  final double duration;
  final DateTime timestamp;
  final MapboxRoute route;

  RoutePreviewCacheEntry({
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    required this.polyline,
    required this.distance,
    required this.duration,
    required this.timestamp,
    required this.route,
  });

  bool isFresh(Duration ttl) => DateTime.now().difference(timestamp) <= ttl;
}

class RoutePreviewCache {
  RoutePreviewCache._();

  static final RoutePreviewCache instance = RoutePreviewCache._();
  static const Duration _ttl = Duration(minutes: 5);

  final Map<String, RoutePreviewCacheEntry> _cache = {};
  final http.Client _httpClient = http.Client();

  RoutePreviewCacheEntry? getCachedRoute({
    required List<LatLng> waypoints,
  }) {
    _pruneExpired();
    final key = _keyForWaypoints(waypoints);
    final entry = _cache[key];

    if (entry != null && entry.isFresh(_ttl)) {
      debugPrint('[RoutePreview] cache_hit key=$key');
      return entry;
    }

    debugPrint('[RoutePreview] cache_miss key=$key');
    return null;
  }

  Future<MapboxRoute?> prefetchRoute({
    required List<LatLng> waypoints,
  }) async {
    if (waypoints.length < 2) return null;

    final cached = getCachedRoute(waypoints: waypoints);
    if (cached != null) {
      return cached.route;
    }

    final key = _keyForWaypoints(waypoints);
    final watch = Stopwatch()..start();
    debugPrint('[RoutePreview] prefetch_start key=$key');

    final backendRoute = await _fetchRouteFromBackend(waypoints: waypoints);
    final route = backendRoute ?? await MapboxService.getRoute(waypoints: waypoints);
    if (route == null) {
      debugPrint('[RoutePreview] prefetch_complete key=$key ok=false duration_ms=${watch.elapsedMilliseconds}');
      return null;
    }

    _cache[key] = RoutePreviewCacheEntry(
      originLat: waypoints.first.latitude,
      originLng: waypoints.first.longitude,
      destLat: waypoints.last.latitude,
      destLng: waypoints.last.longitude,
      polyline: List<LatLng>.from(route.geometry),
      distance: route.distance,
      duration: route.duration,
      timestamp: DateTime.now(),
      route: route,
    );

    debugPrint(
      '[RoutePreview] prefetch_complete key=$key ok=true duration_ms=${watch.elapsedMilliseconds} polyline_points=${route.geometry.length}',
    );
    return route;
  }

  Future<MapboxRoute?> _fetchRouteFromBackend({
    required List<LatLng> waypoints,
  }) async {
    if (waypoints.length < 2) {
      return null;
    }

    final origin = waypoints.first;
    final destination = waypoints.last;

    try {
      final response = await _httpClient
          .post(
            Uri.parse('${AppConfig.baseUrl}/user/prefetch_route.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'origin': {'lat': origin.latitude, 'lng': origin.longitude},
              'destination': {
                'lat': destination.latitude,
                'lng': destination.longitude,
              },
              'mapbox_token': AppSecretsService.instance.mapboxToken,
            }),
          )
          .timeout(const Duration(seconds: 2));

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true || data['route'] is! Map<String, dynamic>) {
        return null;
      }

      final routeData = data['route'] as Map<String, dynamic>;
      final polyline = routeData['polyline']?.toString() ?? '';
      if (polyline.isEmpty) {
        return null;
      }

      final geometry = _decodePolyline(polyline);
      if (geometry.isEmpty) {
        return null;
      }

      return MapboxRoute(
        distance: (routeData['distance_meters'] as num?)?.toDouble() ?? 0,
        duration: (routeData['duration_seconds'] as num?)?.toDouble() ?? 0,
        geometry: geometry,
      );
    } catch (_) {
      return null;
    }
  }

  Future<MapboxRoute?> getOrFetchRoute({
    required List<LatLng> waypoints,
  }) async {
    final cached = getCachedRoute(waypoints: waypoints);
    if (cached != null) {
      return cached.route;
    }

    return prefetchRoute(waypoints: waypoints);
  }

  void _pruneExpired() {
    if (_cache.isEmpty) return;

    final staleKeys = _cache.entries
        .where((entry) => !entry.value.isFresh(_ttl))
        .map((entry) => entry.key)
        .toList();

    for (final key in staleKeys) {
      _cache.remove(key);
    }
  }

  String _keyForWaypoints(List<LatLng> waypoints) {
    return waypoints
        .map(
          (point) =>
              '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}',
        )
        .join('|');
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int byte;

      do {
        if (index >= encoded.length) {
          return points;
        }
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      final dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      result = 0;
      shift = 0;

      do {
        if (index >= encoded.length) {
          return points;
        }
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      final dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}
