import 'package:latlong2/latlong.dart';

/// Cache compartido para geocoding y POI con clave por coordenada redondeada.
class LocationCacheService {
  static const Duration _ttl = Duration(minutes: 15);
  static final Map<String, _CacheEntry<dynamic>> _reverseGeocodeCache = {};
  static final Map<String, _CacheEntry<dynamic>> _poiCache = {};
  static final Map<String, _CacheEntry<dynamic>> _landmarkCache = {};
  static final Map<String, _CacheEntry<dynamic>> _textSearchPoiCache = {};

  static String buildKey(LatLng position, {int precision = 4}) {
    return '${position.latitude.toStringAsFixed(precision)},${position.longitude.toStringAsFixed(precision)}';
  }

  static T? getReverse<T>(LatLng position) {
    _prune(_reverseGeocodeCache);
    final key = buildKey(position);
    final entry = _reverseGeocodeCache[key];
    if (entry == null || entry.isExpired) {
      return null;
    }
    return entry.value as T?;
  }

  static void setReverse<T>(LatLng position, T value) {
    _prune(_reverseGeocodeCache);
    final key = buildKey(position);
    _reverseGeocodeCache[key] = _CacheEntry<dynamic>(
      value: value,
      expiresAt: DateTime.now().add(_ttl),
    );
  }

  static bool hasPoiEntry(LatLng position) {
    _prune(_poiCache);
    final key = buildKey(position);
    final entry = _poiCache[key];
    return entry != null && !entry.isExpired;
  }

  static T? getPoi<T>(LatLng position) {
    _prune(_poiCache);
    final key = buildKey(position);
    final entry = _poiCache[key];
    if (entry == null || entry.isExpired) {
      return null;
    }
    return entry.value as T?;
  }

  static void setPoi<T>(LatLng position, T value) {
    _prune(_poiCache);
    final key = buildKey(position);
    _poiCache[key] = _CacheEntry<dynamic>(
      value: value,
      expiresAt: DateTime.now().add(_ttl),
    );
  }

  static bool hasLandmarkEntry(LatLng position) {
    _prune(_landmarkCache);
    final key = buildKey(position);
    final entry = _landmarkCache[key];
    return entry != null && !entry.isExpired;
  }

  static T? getLandmark<T>(LatLng position) {
    _prune(_landmarkCache);
    final key = buildKey(position);
    final entry = _landmarkCache[key];
    if (entry == null || entry.isExpired) {
      return null;
    }
    return entry.value as T?;
  }

  static void setLandmark<T>(LatLng position, T value) {
    _prune(_landmarkCache);
    final key = buildKey(position);
    _landmarkCache[key] = _CacheEntry<dynamic>(
      value: value,
      expiresAt: DateTime.now().add(_ttl),
    );
  }

  static bool hasTextSearchPoiEntry(LatLng position) {
    _prune(_textSearchPoiCache);
    final key = buildKey(position);
    final entry = _textSearchPoiCache[key];
    return entry != null && !entry.isExpired;
  }

  static T? getTextSearchPoi<T>(LatLng position) {
    _prune(_textSearchPoiCache);
    final key = buildKey(position);
    final entry = _textSearchPoiCache[key];
    if (entry == null || entry.isExpired) {
      return null;
    }
    return entry.value as T?;
  }

  static void setTextSearchPoi<T>(LatLng position, T value) {
    _prune(_textSearchPoiCache);
    final key = buildKey(position);
    _textSearchPoiCache[key] = _CacheEntry<dynamic>(
      value: value,
      expiresAt: DateTime.now().add(_ttl),
    );
  }

  static void _prune(Map<String, _CacheEntry<dynamic>> cache) {
    if (cache.isEmpty) return;
    final now = DateTime.now();
    final expired = cache.entries
        .where((entry) => entry.value.expiresAt.isBefore(now))
        .map((entry) => entry.key)
        .toList();

    for (final key in expired) {
      cache.remove(key);
    }
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  _CacheEntry({
    required this.value,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
