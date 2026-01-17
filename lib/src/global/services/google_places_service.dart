// lib/src/global/services/google_places_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'app_secrets_service.dart';

/// Servicio para interactuar con la API de Google Places (New)
/// Usa la nueva API v1 para autocompletado y detalles de lugares
class GooglePlacesService {
  static const String _baseUrl = 'https://places.googleapis.com/v1';
  
  // ============================================
  // AUTOCOMPLETE API (Nueva API v1)
  // ============================================
  
  /// Buscar sugerencias de lugares usando Google Places Autocomplete (New)
  /// 
  /// [query] - Texto de búsqueda
  /// [location] - Coordenadas para priorizar resultados cercanos
  /// [radius] - Radio en metros para la búsqueda (default 50km)
  /// [language] - Idioma de los resultados
  /// [country] - Código de país para restringir resultados (ej: 'co')
  static Future<List<GooglePlace>> searchPlaces({
    required String query,
    LatLng? location,
    int radius = 50000,
    String language = 'es',
    String? country,
    String? sessionToken,
  }) async {
    try {
      if (query.trim().isEmpty) return [];
      
      final apiKey = AppSecretsService.instance.googlePlacesApiKey;
      if (apiKey.isEmpty) {
        debugPrint('GooglePlacesService: API key not configured');
        return [];
      }
      
      // Construir el body de la request
      final Map<String, dynamic> requestBody = {
        'input': query,
        'languageCode': language,
      };
      
      // Agregar ubicación para resultados más relevantes
      if (location != null) {
        requestBody['locationBias'] = {
          'circle': {
            'center': {
              'latitude': location.latitude,
              'longitude': location.longitude,
            },
            'radius': radius.toDouble(),
          },
        };
      }
      
      // Restringir por país
      if (country != null && country.isNotEmpty) {
        requestBody['includedRegionCodes'] = [country.toUpperCase()];
      }
      
      // Session token para agrupar requests y optimizar costos
      if (sessionToken != null) {
        requestBody['sessionToken'] = sessionToken;
      }
      
      final url = Uri.parse('$_baseUrl/places:autocomplete');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat,suggestions.placePrediction.types,suggestions.placePrediction.distanceMeters',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final suggestions = data['suggestions'] as List<dynamic>? ?? [];
        
        return suggestions.map((suggestion) {
          final prediction = suggestion['placePrediction'] as Map<String, dynamic>? ?? {};
          return GooglePlace.fromNewApiPrediction(prediction);
        }).toList();
      } else {
        final errorData = json.decode(response.body);
        debugPrint('GooglePlaces API error: ${response.statusCode} - ${errorData['error']?['message'] ?? response.body}');
      }
      
      return [];
    } catch (e) {
      debugPrint('GooglePlacesService searchPlaces error: $e');
      return [];
    }
  }
  
  // ============================================
  // PLACE DETAILS API (Nueva API v1)
  // ============================================
  
  /// Obtener detalles completos de un lugar (incluyendo coordenadas)
  /// 
  /// [placeId] - ID del lugar obtenido del autocomplete
  /// [sessionToken] - Token de sesión para optimizar costos
  static Future<GooglePlaceDetails?> getPlaceDetails({
    required String placeId,
    String language = 'es',
    String? sessionToken,
  }) async {
    try {
      final apiKey = AppSecretsService.instance.googlePlacesApiKey;
      if (apiKey.isEmpty) {
        debugPrint('GooglePlacesService: API key not configured');
        return null;
      }
      
      final url = Uri.parse('$_baseUrl/places/$placeId');
      
      final headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'id,displayName,formattedAddress,location,types,addressComponents',
        'X-Goog-Language-Code': language,
      };
      
      if (sessionToken != null) {
        headers['X-Goog-Session-Token'] = sessionToken;
      }
      
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return GooglePlaceDetails.fromNewApiJson(data);
      } else {
        debugPrint('GooglePlaces Details error: ${response.statusCode} - ${response.body}');
      }
      
      return null;
    } catch (e) {
      debugPrint('GooglePlacesService getPlaceDetails error: $e');
      return null;
    }
  }
  
  // ============================================
  // REVERSE GEOCODING (Coordenadas a dirección)
  // ============================================
  
  /// Obtener dirección desde coordenadas usando Google Geocoding API
  static Future<GooglePlaceDetails?> reverseGeocode({
    required LatLng position,
    String language = 'es',
  }) async {
    try {
      final apiKey = AppSecretsService.instance.googlePlacesApiKey;
      if (apiKey.isEmpty) {
        debugPrint('GooglePlacesService: API key not configured');
        return null;
      }
      
      // Geocoding API sigue usando el formato legacy
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${position.latitude},${position.longitude}'
        '&key=$apiKey'
        '&language=$language'
      );
      
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'] != null && (data['results'] as List).isNotEmpty) {
          return GooglePlaceDetails.fromLegacyGeocodingJson(data['results'][0]);
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('GooglePlacesService reverseGeocode error: $e');
      return null;
    }
  }
}

/// Modelo para una sugerencia de lugar de Google Places Autocomplete
class GooglePlace {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final List<String> types;
  final int? distanceMeters;
  
  const GooglePlace({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    required this.types,
    this.distanceMeters,
  });
  
  /// Factory para la API legacy (no usada actualmente)
  factory GooglePlace.fromPrediction(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'] as Map<String, dynamic>? ?? {};
    
    return GooglePlace(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: structuredFormatting['main_text'] ?? json['description'] ?? '',
      secondaryText: structuredFormatting['secondary_text'] ?? '',
      types: (json['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      distanceMeters: json['distance_meters'] as int?,
    );
  }
  
  /// Factory para la nueva API v1 de Google Places
  factory GooglePlace.fromNewApiPrediction(Map<String, dynamic> json) {
    final structuredFormat = json['structuredFormat'] as Map<String, dynamic>? ?? {};
    final mainTextObj = structuredFormat['mainText'] as Map<String, dynamic>? ?? {};
    final secondaryTextObj = structuredFormat['secondaryText'] as Map<String, dynamic>? ?? {};
    final textObj = json['text'] as Map<String, dynamic>? ?? {};
    
    return GooglePlace(
      placeId: json['placeId'] ?? '',
      description: textObj['text'] ?? '',
      mainText: mainTextObj['text'] ?? textObj['text'] ?? '',
      secondaryText: secondaryTextObj['text'] ?? '',
      types: (json['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      distanceMeters: json['distanceMeters'] as int?,
    );
  }
  
  /// Obtener distancia en kilómetros
  double? get distanceKm => distanceMeters != null ? distanceMeters! / 1000.0 : null;
  
  /// Verificar si es un POI (punto de interés)
  bool get isPoi => types.any((t) => 
    t.contains('establishment') || 
    t.contains('point_of_interest') ||
    t.contains('store') ||
    t.contains('restaurant') ||
    t.contains('school') ||
    t.contains('hospital')
  );
  
  @override
  String toString() => 'GooglePlace($mainText - $secondaryText)';
}

/// Modelo para detalles completos de un lugar
class GooglePlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final LatLng coordinates;
  final List<String> types;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  
  const GooglePlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.coordinates,
    required this.types,
    this.city,
    this.state,
    this.country,
    this.postalCode,
  });
  
  /// Factory para la nueva API v1 de Google Places
  factory GooglePlaceDetails.fromNewApiJson(Map<String, dynamic> json) {
    // Extraer coordenadas de la nueva estructura
    final location = json['location'] as Map<String, dynamic>? ?? {};
    final lat = (location['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (location['longitude'] as num?)?.toDouble() ?? 0.0;
    
    // Extraer nombre
    final displayName = json['displayName'] as Map<String, dynamic>? ?? {};
    final name = displayName['text'] ?? json['formattedAddress'] ?? '';
    
    // Extraer componentes de la dirección
    String? city;
    String? state;
    String? country;
    String? postalCode;
    
    final addressComponents = json['addressComponents'] as List<dynamic>? ?? [];
    for (var component in addressComponents) {
      final types = (component['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final longName = component['longText'] as String?;
      
      if (types.contains('locality')) {
        city = longName;
      } else if (types.contains('administrative_area_level_1')) {
        state = longName;
      } else if (types.contains('country')) {
        country = longName;
      } else if (types.contains('postal_code')) {
        postalCode = longName;
      }
    }
    
    return GooglePlaceDetails(
      placeId: json['id'] ?? '',
      name: name,
      formattedAddress: json['formattedAddress'] ?? '',
      coordinates: LatLng(lat, lng),
      types: (json['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      city: city,
      state: state,
      country: country,
      postalCode: postalCode,
    );
  }
  
  /// Factory para la API legacy de Geocoding
  factory GooglePlaceDetails.fromLegacyGeocodingJson(Map<String, dynamic> json) {
    // Extraer coordenadas
    final geometry = json['geometry'] as Map<String, dynamic>? ?? {};
    final location = geometry['location'] as Map<String, dynamic>? ?? {};
    final lat = (location['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (location['lng'] as num?)?.toDouble() ?? 0.0;
    
    // Extraer componentes de la dirección
    String? city;
    String? state;
    String? country;
    String? postalCode;
    
    final addressComponents = json['address_components'] as List<dynamic>? ?? [];
    for (var component in addressComponents) {
      final types = (component['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final longName = component['long_name'] as String?;
      
      if (types.contains('locality')) {
        city = longName;
      } else if (types.contains('administrative_area_level_1')) {
        state = longName;
      } else if (types.contains('country')) {
        country = longName;
      } else if (types.contains('postal_code')) {
        postalCode = longName;
      }
    }
    
    return GooglePlaceDetails(
      placeId: json['place_id'] ?? '',
      name: json['formatted_address'] ?? '',
      formattedAddress: json['formatted_address'] ?? '',
      coordinates: LatLng(lat, lng),
      types: (json['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      city: city,
      state: state,
      country: country,
      postalCode: postalCode,
    );
  }
  
  /// Factory para la API legacy de Places (por compatibilidad)
  factory GooglePlaceDetails.fromJson(Map<String, dynamic> json) {
    // Extraer coordenadas
    final geometry = json['geometry'] as Map<String, dynamic>? ?? {};
    final location = geometry['location'] as Map<String, dynamic>? ?? {};
    final lat = (location['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (location['lng'] as num?)?.toDouble() ?? 0.0;
    
    // Extraer componentes de la dirección
    String? city;
    String? state;
    String? country;
    String? postalCode;
    
    final addressComponents = json['address_components'] as List<dynamic>? ?? [];
    for (var component in addressComponents) {
      final types = (component['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final longName = component['long_name'] as String?;
      
      if (types.contains('locality')) {
        city = longName;
      } else if (types.contains('administrative_area_level_1')) {
        state = longName;
      } else if (types.contains('country')) {
        country = longName;
      } else if (types.contains('postal_code')) {
        postalCode = longName;
      }
    }
    
    return GooglePlaceDetails(
      placeId: json['place_id'] ?? '',
      name: json['name'] ?? json['formatted_address'] ?? '',
      formattedAddress: json['formatted_address'] ?? '',
      coordinates: LatLng(lat, lng),
      types: (json['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      city: city,
      state: state,
      country: country,
      postalCode: postalCode,
    );
  }
  
  @override
  String toString() => 'GooglePlaceDetails($name @ $coordinates)';
}
