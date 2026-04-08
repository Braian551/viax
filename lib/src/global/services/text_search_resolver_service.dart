import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:viax/src/core/network/network_request_executor.dart';

import 'app_secrets_service.dart';
import 'location_cache_service.dart';

class TextSearchResolverResult {
  final String name;
  final String? placeId;
  final double distanceMeters;

  const TextSearchResolverResult({
    required this.name,
    required this.distanceMeters,
    this.placeId,
  });
}

class TextSearchResolverService {
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();

  static const Set<String> _allowedTypes = {
    'bus_station',
    'transit_station',
    'shopping_mall',
    'airport',
    'hospital',
    'university',
  };

  static const double _radiusMeters = 150.0;
  static const List<String> _queryTemplates = [
    'bus station near',
    'terminal near',
    'station near',
    'mall near',
  ];

  static Future<TextSearchResolverResult?> resolveNearestTextSearchPoi({
    required LatLng position,
    String language = 'es',
  }) async {
    final stopwatch = Stopwatch()..start();
    final cacheKey = LocationCacheService.buildKey(position);

    try {
      if (LocationCacheService.hasTextSearchPoiEntry(position)) {
        final cached =
            LocationCacheService.getTextSearchPoi<TextSearchResolverResult?>(
          position,
        );
        debugPrint(
          '[TextSearchResolver] cache_hit key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds} result_count=0 chosen_place=${cached?.name ?? 'none'}',
        );
        return cached;
      }

      final apiKey = AppSecretsService.instance.googlePlacesApiKey;
      if (apiKey.isEmpty) {
        LocationCacheService.setTextSearchPoi<TextSearchResolverResult?>(
          position,
          null,
        );
        debugPrint(
          '[TextSearchResolver] missing_api_key key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds} result_count=0 chosen_place=none',
        );
        return null;
      }

      final allCandidates = <Map<String, dynamic>>[];

      for (final template in _queryTemplates) {
        final query =
            '$template ${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';
        final uri = Uri.https(
          'maps.googleapis.com',
          '/maps/api/place/textsearch/json',
          {
            'query': query,
            'location': '${position.latitude},${position.longitude}',
            'radius': _radiusMeters.toInt().toString(),
            'language': language,
            'key': apiKey,
          },
        );

        final response = await _network.getJson(
          url: uri,
          timeout: const Duration(seconds: 8),
        );

        if (!response.success || response.json == null) {
          continue;
        }

        final parsedCandidates = await compute(
          _parseTextSearchCandidates,
          jsonEncode({
            'lat': position.latitude,
            'lng': position.longitude,
            'response': response.json,
            'allowedTypes': _allowedTypes.toList(),
            'maxDistanceMeters': _radiusMeters,
          }),
        );

        if (parsedCandidates != null && parsedCandidates.isNotEmpty) {
          allCandidates.addAll(parsedCandidates);
        }
      }

      if (allCandidates.isEmpty) {
        LocationCacheService.setTextSearchPoi<TextSearchResolverResult?>(
          position,
          null,
        );
        debugPrint(
          '[TextSearchResolver] no_match key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds} result_count=0 chosen_place=none',
        );
        return null;
      }

      allCandidates.sort((a, b) {
        final da = (a['distanceMeters'] as num).toDouble();
        final db = (b['distanceMeters'] as num).toDouble();
        return da.compareTo(db);
      });

      final chosen = allCandidates.first;
      final resolved = TextSearchResolverResult(
        name: chosen['name']?.toString() ?? '',
        placeId: chosen['placeId']?.toString(),
        distanceMeters: (chosen['distanceMeters'] as num?)?.toDouble() ?? 9999,
      );

      LocationCacheService.setTextSearchPoi<TextSearchResolverResult?>(
        position,
        resolved,
      );

      debugPrint(
        '[TextSearchResolver] resolved key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds} result_count=${allCandidates.length} chosen_place=${resolved.name}',
      );

      return resolved;
    } catch (e) {
      debugPrint(
        '[TextSearchResolver] exception key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds} result_count=0 chosen_place=none error=$e',
      );
      return null;
    } finally {
      stopwatch.stop();
    }
  }
}

List<Map<String, dynamic>>? _parseTextSearchCandidates(String payload) {
  final decoded = jsonDecode(payload) as Map<String, dynamic>;
  final response = decoded['response'] as Map<String, dynamic>?;
  final results = response?['results'] as List<dynamic>? ?? const [];

  if ((response?['status']?.toString() ?? '') != 'OK' || results.isEmpty) {
    return null;
  }

  final lat = (decoded['lat'] as num?)?.toDouble();
  final lng = (decoded['lng'] as num?)?.toDouble();
  final maxDistanceMeters =
      (decoded['maxDistanceMeters'] as num?)?.toDouble() ?? 150.0;
  if (lat == null || lng == null) {
    return null;
  }

  final allowedTypes = (decoded['allowedTypes'] as List<dynamic>? ?? const [])
      .map((e) => e.toString())
      .toSet();

  final candidates = <Map<String, dynamic>>[];

  for (final raw in results) {
    final item = raw as Map<String, dynamic>;
    final name = item['name']?.toString().trim() ?? '';
    if (name.isEmpty) continue;

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
    if (distanceMeters > maxDistanceMeters) {
      continue;
    }

    candidates.add({
      'name': name,
      'placeId': item['place_id']?.toString(),
      'distanceMeters': distanceMeters,
    });
  }

  return candidates;
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