import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../models/simple_location.dart';
import 'auth/user_service.dart';
import 'google_places_service.dart';
import 'mapbox_service.dart';

/// Servicio potenciado para sugerencias de ubicación usando Google Places
/// Usa estrategia de búsqueda local-first con Google Places Autocomplete para mayor precisión
class LocationSuggestionService {
  static final Map<String, List<SimpleLocation>> _cache = {};
  static const int _cacheMaxSize = 50;
  static const int _maxRecentSuggestions = 8;
  static int? _cachedUserId;
  
  // UUID generator para session tokens de Google Places
  static final Uuid _uuid = Uuid();
  String? _currentSessionToken;
  
  LatLng? userLocation;
  String countryCode;
  String? userCity;
  LatLng? referencePoint;
  
  LocationSuggestionService({
    this.userLocation,
    this.countryCode = 'co',
    this.userCity,
    this.referencePoint,
  });
  
  /// Genera un nuevo session token para agrupar requests de autocomplete
  /// Esto optimiza los costos de Google Places API
  void _refreshSessionToken() {
    _currentSessionToken = _uuid.v4();
  }
  
  void setUserContext({
    LatLng? location,
    String? country,
    String? city,
    LatLng? reference,
  }) {
    userLocation = location ?? userLocation;
    countryCode = country ?? countryCode;
    userCity = city ?? userCity;
    referencePoint = reference ?? referencePoint;
  }
  
  void setReferencePoint(LatLng? point) {
    referencePoint = point;
  }
  
  /// Busca sugerencias usando Google Places Autocomplete para mayor precisión
  Future<List<SimpleLocation>> searchSuggestions({
    required String query,
    int limit = 8,
    bool localFirst = true,
  }) async {
    if (query.trim().length < 2) {
      return getRecentSuggestions(limit: limit);
    }
    
    final distanceRef = referencePoint ?? userLocation;
    final cacheKey = '${query.toLowerCase()}_${distanceRef?.latitude}_${distanceRef?.longitude}_${countryCode}_$limit';
    
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }
    
    // Generar session token si no existe
    _currentSessionToken ??= _uuid.v4();
    
    try {
      // Usar Google Places Autocomplete
      final places = await GooglePlacesService.searchPlaces(
        query: query,
        location: distanceRef,
        radius: localFirst ? 50000 : 100000, // 50km local, 100km expandido
        language: 'es',
        country: countryCode,
        sessionToken: _currentSessionToken,
      );
      
      debugPrint('GooglePlaces returned ${places.length} results for "$query"');
      
      if (places.isEmpty) {
        return [];
      }
      
      // Convertir GooglePlace a SimpleLocation SIN obtener detalles (más rápido)
      // Los detalles se obtienen cuando el usuario selecciona
      final results = _convertGooglePlacesToLocationsQuick(places, distanceRef);
      
      // Ordenar por distancia si hay punto de referencia
      if (distanceRef != null && results.isNotEmpty) {
        results.sort((a, b) {
          final distA = a.distanceKm ?? double.infinity;
          final distB = b.distanceKm ?? double.infinity;
          return distA.compareTo(distB);
        });
      }
      
      final limitedResults = results.take(limit).toList();
      _addToCache(cacheKey, limitedResults);
      
      return limitedResults;
    } catch (e) {
      debugPrint('LocationSuggestionService error: $e');
      return [];
    }
  }
  
  /// Convierte los resultados de Google Places a SimpleLocation rápidamente
  /// Sin hacer llamadas adicionales a la API (los detalles se obtienen al seleccionar)
  List<SimpleLocation> _convertGooglePlacesToLocationsQuick(
    List<GooglePlace> places, 
    LatLng? referencePoint,
  ) {
    return places.map((place) {
      return SimpleLocation(
        latitude: 0, // Se llenará cuando el usuario seleccione
        longitude: 0, // Se llenará cuando el usuario seleccione
        address: place.description,
        placeName: place.mainText,
        subtitle: place.secondaryText,
        distanceKm: place.distanceKm,
        placeType: place.isPoi ? 'poi' : 'address',
        placeId: place.placeId, // Guardar el placeId para obtener detalles después
      );
    }).toList();
  }
  
  /// Obtener los detalles completos (coordenadas) de un lugar seleccionado
  Future<SimpleLocation?> getPlaceDetails(SimpleLocation place) async {
    if (place.placeId == null || place.placeId!.isEmpty) {
      saveRecentSelection(place);
      return place; // Ya tiene coordenadas
    }
    
    try {
      final details = await GooglePlacesService.getPlaceDetails(
        placeId: place.placeId!,
        language: 'es',
        sessionToken: _currentSessionToken,
      );
      
      // Refrescar session token después de obtener detalles
      _refreshSessionToken();
      
      if (details != null) {
        final resolved = SimpleLocation(
          latitude: details.coordinates.latitude,
          longitude: details.coordinates.longitude,
          address: details.formattedAddress,
          placeName: place.placeName,
          subtitle: place.subtitle,
          distanceKm: place.distanceKm,
          placeType: place.placeType,
        );
        return resolved;
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
    }
    
    return null;
  }
  
  void _addToCache(String key, List<SimpleLocation> results) {
    if (_cache.length >= _cacheMaxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = results;
  }
  
  static void clearCache() {
    _cache.clear();
  }
  
  /// Notificar que el usuario seleccionó un lugar
  /// Esto refresca el session token para la próxima búsqueda
  void onPlaceSelected() {
    _refreshSessionToken();
  }

  void saveRecentSelection(SimpleLocation location) {
    unawaited(_saveRecentToBackend(location));
  }

  Future<List<SimpleLocation>> getRecentSuggestions({int limit = 8}) async {
    final userId = await _resolveUserId();
    if (userId == null || userId <= 0) return [];

    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/user/get_recent_searches.php')
          .replace(queryParameters: {
            'user_id': '$userId',
            '_ts': DateTime.now().millisecondsSinceEpoch.toString(),
          });
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['success'] != true) return [];

      final rows = (data['recent_searches'] as List<dynamic>?) ??
          (data['places'] as List<dynamic>?) ??
          <dynamic>[];

        final parsed = rows
          .map((row) {
            if (row is! Map) return null;
            final map = Map<String, dynamic>.from(row);
            final lat = _toDouble(map['lat'] ?? map['latitud']);
            final lng = _toDouble(map['lng'] ?? map['longitud']);
            final address = (map['address'] ?? map['direccion'] ?? map['name'] ?? '')
                .toString()
                .trim();
            if (lat == null || lng == null || address.isEmpty) return null;

            final parts = address.split(',').map((e) => e.trim()).toList();
            return SimpleLocation(
              latitude: lat,
              longitude: lng,
              address: address,
              placeName: parts.isNotEmpty ? parts.first : address,
              subtitle: parts.length > 1 ? parts.sublist(1).join(', ') : '',
              placeType: 'recent',
            );
          })
          .whereType<SimpleLocation>()
          .toList();

      return _dedupeAndLimitRecents(parsed, limit: limit);
    } catch (_) {
      return [];
    }
  }

  List<SimpleLocation> _dedupeAndLimitRecents(
    List<SimpleLocation> recents, {
    required int limit,
  }) {
    final normalizedLimit = limit.clamp(1, _maxRecentSuggestions);
    final unique = <String, SimpleLocation>{};

    for (final item in recents) {
      final key = _recentKey(item);
      unique.putIfAbsent(key, () => item);
      if (unique.length >= normalizedLimit) {
        break;
      }
    }

    return unique.values.toList();
  }

  String _recentKey(SimpleLocation location) {
    final normalizedAddress = location.address.trim().toLowerCase();
    if (normalizedAddress.isNotEmpty) {
      return normalizedAddress;
    }
    final lat = location.latitude.toStringAsFixed(5);
    final lng = location.longitude.toStringAsFixed(5);
    return '$lat|$lng';
  }

  static Future<int?> _resolveUserId() async {
    try {
      final session = await UserService.getSavedSession();
      if (session == null) {
        _cachedUserId = null;
        return null;
      }

      final rawId = session['id'];
      if (rawId is int && rawId > 0) {
        if (_cachedUserId != rawId) {
          _cachedUserId = rawId;
        }
        return _cachedUserId;
      }

      final parsed = int.tryParse(rawId?.toString() ?? '');
      if (parsed != null && parsed > 0) {
        if (_cachedUserId != parsed) {
          _cachedUserId = parsed;
        }
        return _cachedUserId;
      }
    } catch (_) {}

    _cachedUserId = null;
    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Future<void> _saveRecentToBackend(SimpleLocation location) async {
    if (!location.hasValidCoordinates || location.address.trim().isEmpty) {
      return;
    }

    final userId = await _resolveUserId();
    if (userId == null || userId <= 0) return;

    try {
      final payload = {
        'user_id': userId,
        'place_name': location.displayName,
        'place_address': location.address,
        'place_lat': location.latitude,
        'place_lng': location.longitude,
      };

      await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/user/save_recent_search.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // No bloquear UX por fallas de red en sincronización de recientes.
    }
  }
  
  /// Geocodificación inversa usando Google Places
  Future<String?> reverseGeocode(double lat, double lon) async {
    try {
      // Primero intentar con Google Places
      final details = await GooglePlacesService.reverseGeocode(
        position: LatLng(lat, lon),
        language: 'es',
      );
      
      if (details != null) {
        return details.formattedAddress;
      }
      
      // Fallback a Mapbox si Google falla
      final place = await MapboxService.reverseGeocode(position: LatLng(lat, lon));
      return place?.placeName;
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
    return null;
  }
  
  static LocationInfo parseAddress(String fullAddress) {
    final parts = fullAddress.split(',').map((e) => e.trim()).toList();
    return LocationInfo(
      name: parts.isNotEmpty ? parts[0] : fullAddress,
      subtitle: parts.length > 1 ? parts.sublist(1).take(2).join(', ') : '',
      fullAddress: fullAddress,
    );
  }
}

class LocationInfo {
  final String name;
  final String subtitle;
  final String fullAddress;
  
  const LocationInfo({
    required this.name,
    required this.subtitle,
    required this.fullAddress,
  });
}
