import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/simple_location.dart';

/// Servicio reutilizable para sugerencias de ubicación
/// Prioriza resultados locales (ciudad/país del usuario)
class LocationSuggestionService {
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'ViaxApp/1.0';
  
  /// Cache simple para evitar llamadas repetidas
  static final Map<String, List<SimpleLocation>> _cache = {};
  static const int _cacheMaxSize = 50;
  
  /// Ubicación del usuario para priorizar resultados locales
  LatLng? userLocation;
  String? userCountryCode;
  String? userCity;
  
  LocationSuggestionService({
    this.userLocation,
    this.userCountryCode,
    this.userCity,
  });
  
  /// Configura la ubicación del usuario para priorizar resultados
  void setUserContext({
    LatLng? location,
    String? countryCode,
    String? city,
  }) {
    userLocation = location ?? userLocation;
    userCountryCode = countryCode ?? userCountryCode;
    userCity = city ?? userCity;
  }
  
  /// Busca sugerencias priorizando ubicaciones locales
  /// 
  /// [query] - Texto a buscar
  /// [limit] - Número máximo de resultados
  /// [localFirst] - Si es true, prioriza resultados cercanos
  Future<List<SimpleLocation>> searchSuggestions({
    required String query,
    int limit = 8,
    bool localFirst = true,
  }) async {
    if (query.trim().length < 2) {
      return [];
    }
    
    final cacheKey = '${query.toLowerCase()}_${userCountryCode ?? ''}_$limit';
    
    // Verificar cache
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }
    
    try {
      List<SimpleLocation> results = [];
      
      if (localFirst && (userLocation != null || userCountryCode != null)) {
        // Primero buscar localmente
        results = await _searchWithContext(query, limit);
        
        // Si hay pocos resultados locales, complementar con búsqueda global
        if (results.length < 3) {
          final globalResults = await _searchGlobal(query, limit - results.length);
          // Agregar solo los que no están duplicados
          for (var r in globalResults) {
            if (!results.any((e) => _isSimilarLocation(e, r))) {
              results.add(r);
            }
          }
        }
      } else {
        // Búsqueda global simple
        results = await _searchGlobal(query, limit);
      }
      
      // Ordenar: más cercanos primero si tenemos ubicación del usuario
      if (userLocation != null && results.isNotEmpty) {
        results = _sortByDistance(results);
      }
      
      // Guardar en cache
      _addToCache(cacheKey, results);
      
      return results;
    } catch (e) {
      debugPrint('LocationSuggestionService error: $e');
      return [];
    }
  }
  
  /// Búsqueda con contexto local (país/viewbox)
  Future<List<SimpleLocation>> _searchWithContext(String query, int limit) async {
    final params = <String, String>{
      'q': query,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '$limit',
    };
    
    // Agregar código de país si está disponible
    if (userCountryCode != null && userCountryCode!.isNotEmpty) {
      params['countrycodes'] = userCountryCode!;
    }
    
    // Agregar viewbox si tenemos ubicación (área de ±0.5 grados)
    if (userLocation != null) {
      final lat = userLocation!.latitude;
      final lng = userLocation!.longitude;
      params['viewbox'] = '${lng - 0.5},${lat + 0.5},${lng + 0.5},${lat - 0.5}';
      params['bounded'] = '0'; // No restringir estrictamente, solo priorizar
    }
    
    return _executeSearch(params);
  }
  
  /// Búsqueda global sin restricciones
  Future<List<SimpleLocation>> _searchGlobal(String query, int limit) async {
    final params = <String, String>{
      'q': query,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '$limit',
    };
    
    return _executeSearch(params);
  }
  
  /// Ejecuta la búsqueda HTTP
  Future<List<SimpleLocation>> _executeSearch(Map<String, String> params) async {
    final uri = Uri.parse('$_nominatimBaseUrl/search').replace(queryParameters: params);
    
    final response = await http.get(uri, headers: {
      'User-Agent': _userAgent,
    }).timeout(const Duration(seconds: 8));
    
    if (response.statusCode == 200) {
      return await compute(_parseSuggestionsResponse, response.body);
    }
    
    return [];
  }
  
  /// Ordena resultados por distancia al usuario
  List<SimpleLocation> _sortByDistance(List<SimpleLocation> locations) {
    if (userLocation == null) return locations;
    
    final Distance distance = const Distance();
    
    locations.sort((a, b) {
      final distA = distance.as(
        LengthUnit.Kilometer,
        userLocation!,
        LatLng(a.latitude, a.longitude),
      );
      final distB = distance.as(
        LengthUnit.Kilometer,
        userLocation!,
        LatLng(b.latitude, b.longitude),
      );
      return distA.compareTo(distB);
    });
    
    return locations;
  }
  
  /// Verifica si dos ubicaciones son similares (para evitar duplicados)
  bool _isSimilarLocation(SimpleLocation a, SimpleLocation b) {
    // Considerar similar si están a menos de 100m
    const threshold = 0.001; // ~100m en grados
    return (a.latitude - b.latitude).abs() < threshold &&
           (a.longitude - b.longitude).abs() < threshold;
  }
  
  /// Agrega al cache con límite de tamaño
  void _addToCache(String key, List<SimpleLocation> results) {
    if (_cache.length >= _cacheMaxSize) {
      // Eliminar la entrada más antigua
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = results;
  }
  
  /// Limpia el cache
  static void clearCache() {
    _cache.clear();
  }
  
  /// Geocodificación inversa para obtener dirección de coordenadas
  Future<String?> reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse('$_nominatimBaseUrl/reverse').replace(
        queryParameters: {
          'format': 'jsonv2',
          'lat': '$lat',
          'lon': '$lon',
        },
      );
      
      final response = await http.get(uri, headers: {
        'User-Agent': _userAgent,
      }).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = await compute(_parseReverseGeocodeResponse, response.body);
        
        // Extraer código de país para futuras búsquedas
        if (data['address'] != null) {
          userCountryCode = data['address']['country_code']?.toString().toUpperCase();
          userCity = data['address']['city'] ?? 
                     data['address']['town'] ?? 
                     data['address']['village'];
        }
        
        return data['display_name'] as String?;
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
    return null;
  }
  
  /// Extrae información legible de una dirección
  static LocationInfo parseAddress(String fullAddress) {
    final parts = fullAddress.split(',').map((e) => e.trim()).toList();
    
    return LocationInfo(
      name: parts.isNotEmpty ? parts[0] : fullAddress,
      subtitle: parts.length > 1 
          ? parts.sublist(1).take(2).join(', ')
          : '',
      fullAddress: fullAddress,
    );
  }
}

/// Información parseada de una ubicación
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

// Helper function for compute
List<SimpleLocation> _parseSuggestionsResponse(String responseBody) {
  final List data = json.decode(responseBody) as List;
  
  return data.map((item) {
    return SimpleLocation(
      latitude: double.tryParse(item['lat']?.toString() ?? '0') ?? 0,
      longitude: double.tryParse(item['lon']?.toString() ?? '0') ?? 0,
      address: item['display_name'] ?? '',
    );
  }).toList().cast<SimpleLocation>();
}

Map<String, dynamic> _parseReverseGeocodeResponse(String responseBody) {
  return json.decode(responseBody) as Map<String, dynamic>;
}


