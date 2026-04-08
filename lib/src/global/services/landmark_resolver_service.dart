import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:viax/src/core/network/network_request_executor.dart';

import 'app_secrets_service.dart';
import 'location_cache_service.dart';

class LandmarkResolverResult {
  final String name;
  final String? placeId;
  final double distanceMeters;

  const LandmarkResolverResult({
    required this.name,
    required this.distanceMeters,
    this.placeId,
  });
}

class LandmarkResolverService {
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();

  static const Set<String> _allowedTypes = {
    'transit_station',
    'bus_station',
    'airport',
    'shopping_mall',
    'hospital',
    'university',
    'stadium',
    'tourist_attraction',
  };

  static const double _maxDistanceMeters = 80.0;

  static Future<LandmarkResolverResult?> resolveNearestLandmark({
    required LatLng position,
    String language = 'es',
  }) async {
    final stopwatch = Stopwatch()..start();
    final cacheKey = LocationCacheService.buildKey(position);

    try {
      if (LocationCacheService.hasLandmarkEntry(position)) {
        final cached = LocationCacheService.getLandmark<LandmarkResolverResult?>(position);
        debugPrint(
          '[LandmarkResolver] cache_hit key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds} has_landmark=${cached != null}',
        );
        return cached;
      }

      final apiKey = AppSecretsService.instance.googlePlacesApiKey;
      if (apiKey.isEmpty) {
        LocationCacheService.setLandmark<LandmarkResolverResult?>(position, null);
        debugPrint(
          '[LandmarkResolver] missing_api_key key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds}',
        );
        return null;
      }

      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/findplacefromtext/json',
        {
          'input': '${position.latitude},${position.longitude}',
          'inputtype': 'textquery',
          'fields': 'name,geometry,types,place_id',
          'language': language,
          'key': apiKey,
        },
      );

      final response = await _network.getJson(
        url: uri,
        timeout: const Duration(seconds: 8),
      );

      if (!response.success || response.json == null) {
        LocationCacheService.setLandmark<LandmarkResolverResult?>(position, null);
        debugPrint(
          '[LandmarkResolver] api_error key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds} reason=${response.error?.userMessage}',
        );
        return null;
      }

      final resultMap = await compute(
        _parseLandmarkCandidate,
        jsonEncode({
          'lat': position.latitude,
          'lng': position.longitude,
          'response': response.json,
          'allowedTypes': _allowedTypes.toList(),
          'maxDistanceMeters': _maxDistanceMeters,
        }),
      );

      if (resultMap == null) {
        LocationCacheService.setLandmark<LandmarkResolverResult?>(position, null);
        debugPrint(
          '[LandmarkResolver] no_match key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds}',
        );
        return null;
      }

      final landmark = LandmarkResolverResult(
        name: resultMap['name']?.toString() ?? '',
        placeId: resultMap['placeId']?.toString(),
        distanceMeters: (resultMap['distanceMeters'] as num?)?.toDouble() ?? 9999,
      );

      LocationCacheService.setLandmark<LandmarkResolverResult?>(position, landmark);
      debugPrint(
        '[LandmarkResolver] match key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds} landmark=${landmark.name} dist_m=${landmark.distanceMeters.toStringAsFixed(1)}',
      );

      return landmark;
    } catch (e) {
      debugPrint(
        '[LandmarkResolver] exception key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds} error=$e',
      );
      return null;
    } finally {
      stopwatch.stop();
    }
  }
}

Map<String, dynamic>? _parseLandmarkCandidate(String payload) {
  final decoded = jsonDecode(payload) as Map<String, dynamic>;
  final response = decoded['response'] as Map<String, dynamic>?;
  final candidates = response?['candidates'] as List<dynamic>? ?? const [];

  if ((response?['status']?.toString() ?? '') != 'OK' || candidates.isEmpty) {
    return null;
  }

  final lat = (decoded['lat'] as num?)?.toDouble();
  final lng = (decoded['lng'] as num?)?.toDouble();
  final maxDistanceMeters =
      (decoded['maxDistanceMeters'] as num?)?.toDouble() ?? 80.0;

  if (lat == null || lng == null) {
    return null;
  }

  final allowedTypes = (decoded['allowedTypes'] as List<dynamic>? ?? const [])
      .map((e) => e.toString())
      .toSet();

  final normalizedCandidates = <Map<String, dynamic>>[];

  for (final raw in candidates) {
    final item = raw as Map<String, dynamic>;
    final name = item['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      continue;
    }

    final types = (item['types'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();

    final hasAllowedType = types.any(allowedTypes.contains);
    if (!hasAllowedType) {
      continue;
    }

    final geometry = item['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    final itemLat = (location?['lat'] as num?)?.toDouble();
    final itemLng = (location?['lng'] as num?)?.toDouble();

    if (itemLat == null || itemLng == null) {
      continue;
    }

    final distanceMeters = _haversineDistanceMeters(
      lat1: lat,
      lng1: lng,
      lat2: itemLat,
      lng2: itemLng,
    );

    if (distanceMeters > maxDistanceMeters) {
      continue;
    }

    normalizedCandidates.add({
      'name': name,
      'placeId': item['place_id']?.toString(),
      'distanceMeters': distanceMeters,
    });
  }

  if (normalizedCandidates.isEmpty) {
    return null;
  }

  normalizedCandidates.sort((a, b) {
    final da = (a['distanceMeters'] as num).toDouble();
    final db = (b['distanceMeters'] as num).toDouble();
    return da.compareTo(db);
  });

  return normalizedCandidates.first;
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
