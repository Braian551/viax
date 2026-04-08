import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:viax/src/core/network/network_request_executor.dart';

import 'app_secrets_service.dart';
import 'location_cache_service.dart';

class PoiResolverResult {
  final String name;
  final String? placeId;
  final double distanceMeters;

  const PoiResolverResult({
    required this.name,
    required this.distanceMeters,
    this.placeId,
  });
}

class PoiResolverService {
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();

  static const List<String> _allowedTypes = [
    'transit_station',
    'bus_station',
    'airport',
    'shopping_mall',
    'hospital',
    'university',
    'school',
    'stadium',
    'tourist_attraction',
    'restaurant',
    'store',
    'establishment',
  ];

  static const List<double> _searchRadiiMeters = [30, 50, 80, 120];

  static Future<PoiResolverResult?> resolveNearestPoi({
    required LatLng position,
    String language = 'es',
  }) async {
    final stopwatch = Stopwatch()..start();
    final cacheKey = LocationCacheService.buildKey(position);

    try {
      if (LocationCacheService.hasPoiEntry(position)) {
        final cached = LocationCacheService.getPoi<PoiResolverResult?>(position);
        debugPrint(
          '[POIResolver] cache_hit key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds} has_poi=${cached != null}',
        );
        return cached;
      }

      final apiKey = AppSecretsService.instance.googlePlacesApiKey;
      if (apiKey.isEmpty) {
        LocationCacheService.setPoi<PoiResolverResult?>(position, null);
        debugPrint(
          '[POIResolver] missing_api_key key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds}',
        );
        return null;
      }

      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/nearbysearch/json',
        {
          'location': '${position.latitude},${position.longitude}',
          'radius': '120',
          'language': language,
          'key': apiKey,
        },
      );

      final response = await _network.getJson(
        url: uri,
        timeout: const Duration(seconds: 8),
      );

      if (!response.success || response.json == null) {
        LocationCacheService.setPoi<PoiResolverResult?>(position, null);
        debugPrint(
          '[POIResolver] api_error key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds} reason=${response.error?.userMessage}',
        );
        return null;
      }

      final resultMap = await compute(
        _parseAndRankPoiInIsolate,
        jsonEncode({
          'lat': position.latitude,
          'lng': position.longitude,
          'response': response.json,
          'allowedTypes': _allowedTypes,
          'radii': _searchRadiiMeters,
        }),
      );

      if (resultMap == null) {
        LocationCacheService.setPoi<PoiResolverResult?>(position, null);
        debugPrint(
          '[POIResolver] no_match key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds}',
        );
        return null;
      }

      final poi = PoiResolverResult(
        name: resultMap['name']?.toString() ?? '',
        placeId: resultMap['placeId']?.toString(),
        distanceMeters: (resultMap['distanceMeters'] as num?)?.toDouble() ?? 9999,
      );

      LocationCacheService.setPoi<PoiResolverResult?>(position, poi);
      debugPrint(
        '[POIResolver] match key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds} poi=${poi.name} dist_m=${poi.distanceMeters.toStringAsFixed(1)}',
      );
      return poi;
    } catch (e) {
      debugPrint(
        '[POIResolver] exception key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds} error=$e',
      );
      return null;
    } finally {
      stopwatch.stop();
    }
  }
}

Map<String, dynamic>? _parseAndRankPoiInIsolate(String payload) {
  final decoded = jsonDecode(payload) as Map<String, dynamic>;
  final response = decoded['response'] as Map<String, dynamic>?;
  final results = response?['results'] as List<dynamic>? ?? const [];

  if ((response?['status']?.toString() ?? '') != 'OK' || results.isEmpty) {
    return null;
  }

  final lat = (decoded['lat'] as num?)?.toDouble();
  final lng = (decoded['lng'] as num?)?.toDouble();
  if (lat == null || lng == null) return null;

  final allowedTypes = (decoded['allowedTypes'] as List<dynamic>? ?? const [])
      .map((e) => e.toString())
      .toSet();
  final radii = (decoded['radii'] as List<dynamic>? ?? const [])
      .map((e) => (e as num).toDouble())
      .toList()
    ..sort();

  final candidates = <Map<String, dynamic>>[];

  for (final raw in results) {
    final item = raw as Map<String, dynamic>;
    final name = item['name']?.toString();
    if (name == null || name.trim().isEmpty) continue;

    final types = (item['types'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();

    final hasAllowedType = types.any(allowedTypes.contains);
    if (!hasAllowedType) continue;

    final geometry = item['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    final itemLat = (location?['lat'] as num?)?.toDouble();
    final itemLng = (location?['lng'] as num?)?.toDouble();
    if (itemLat == null || itemLng == null) continue;

    final distanceMeters = _haversineDistanceMeters(
      lat1: lat,
      lng1: lng,
      lat2: itemLat,
      lng2: itemLng,
    );

    candidates.add({
      'name': name.trim(),
      'placeId': item['place_id']?.toString(),
      'distanceMeters': distanceMeters,
    });
  }

  if (candidates.isEmpty) {
    return null;
  }

  candidates.sort((a, b) {
    final da = (a['distanceMeters'] as num).toDouble();
    final db = (b['distanceMeters'] as num).toDouble();
    return da.compareTo(db);
  });

  for (final radius in radii) {
    for (final candidate in candidates) {
      final distance = (candidate['distanceMeters'] as num).toDouble();
      if (distance <= radius) {
        return candidate;
      }
    }
  }

  return null;
}

double _haversineDistanceMeters({
  required double lat1,
  required double lng1,
  required double lat2,
  required double lng2,
}) {
  const earthRadius = 6371000.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final sinDLat = math.sin(dLat / 2);
  final sinDLng = math.sin(dLng / 2);

  final a = (sinDLat * sinDLat) +
      (sinDLng * sinDLng *
          math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)));

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double _toRadians(double degrees) => degrees * 0.017453292519943295;
