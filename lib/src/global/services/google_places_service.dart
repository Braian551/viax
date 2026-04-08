// lib/src/global/services/google_places_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:viax/src/core/network/network_request_executor.dart';
import 'package:viax/src/global/models/location_data.dart';
import 'app_secrets_service.dart';
import 'location_cache_service.dart';

/// Servicio para interactuar con la API de Google Places (New)
/// Usa la nueva API v1 para autocompletado y detalles de lugares
class GooglePlacesService {
  static const String _baseUrl = 'https://places.googleapis.com/v1';
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();
  
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
      
      final result = await _network.postJson(
        url: url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat,suggestions.placePrediction.types,suggestions.placePrediction.distanceMeters',
        },
        body: json.encode(requestBody),
        timeout: const Duration(seconds: 10),
      );

      if (!result.success || result.json == null) {
        debugPrint('GooglePlaces API error: ${result.error?.userMessage}');
        return [];
      }

      final data = result.json!;
        final suggestions = data['suggestions'] as List<dynamic>? ?? [];
        
        return suggestions.map((suggestion) {
          final prediction = suggestion['placePrediction'] as Map<String, dynamic>? ?? {};
          return GooglePlace.fromNewApiPrediction(prediction);
        }).toList();
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
      
      final result = await _network.getJson(
        url: url,
        headers: headers,
        timeout: const Duration(seconds: 10),
      );

      if (!result.success || result.json == null) {
        debugPrint('GooglePlaces Details error: ${result.error?.userMessage}');
        return null;
      }

      return GooglePlaceDetails.fromNewApiJson(result.json!);
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
        '&result_type=locality|administrative_area_level_2'
        '&key=$apiKey'
        '&language=$language'
      );
      
      final result = await _network.getJson(
        url: url,
        timeout: const Duration(seconds: 10),
      );

      if (!result.success || result.json == null) {
        return null;
      }

      final data = result.json!;
      if (data['status'] == 'OK' && data['results'] != null && (data['results'] as List).isNotEmpty) {
        return GooglePlaceDetails.fromLegacyGeocodingJson(data['results'][0]);
      }

      return null;
    } catch (e) {
      debugPrint('GooglePlacesService reverseGeocode error: $e');
      return null;
    }
  }

  /// Normaliza componentes administrativos para municipio/departamento/país.
  /// Nunca usa formatted_address para extraer municipio.
  static Future<LocationData?> reverseGeocodeLocationData({
    required LatLng position,
    required String sourceType,
    String language = 'es',
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final cacheKey = LocationCacheService.buildKey(position);
      final cached = LocationCacheService.getReverse<LocationData>(position);
      if (cached != null) {
        debugPrint(
          '[GeoResolver] cache_hit key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds}',
        );
        return cached;
      }

      debugPrint('[GeoResolver] cache_miss key=$cacheKey');

      final apiKey = AppSecretsService.instance.googlePlacesApiKey;
      if (apiKey.isEmpty) {
        return null;
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${position.latitude},${position.longitude}'
        '&key=$apiKey'
        '&language=$language',
      );

      final result = await _network.getJson(
        url: url,
        timeout: const Duration(seconds: 10),
      );

      if (!result.success || result.json == null) {
        return null;
      }

      final data = result.json!;
      final resolved = await compute(
        _resolveLocationDataFromPayload,
        jsonEncode({
          'lat': position.latitude,
          'lng': position.longitude,
          'sourceType': sourceType,
          'response': data,
        }),
      );

      if (resolved == null) {
        return null;
      }

      final locationData = LocationData(
        lat: position.latitude,
        lng: position.longitude,
        municipality: resolved['municipality']?.toString() ?? '',
        department: resolved['department']?.toString(),
        country: resolved['country']?.toString(),
        placeId: resolved['placeId']?.toString(),
        sourceType: sourceType,
        address: resolved['displayAddress']?.toString(),
        contextType: resolved['contextType']?.toString() ?? 'rural',
        isUrban: resolved['isUrban'] == true,
      );

      LocationCacheService.setReverse<LocationData>(position, locationData);

      debugPrint(
        '[GeoResolver] resolved key=$cacheKey latency_ms=${stopwatch.elapsedMilliseconds} context=${locationData.contextType} municipality=${locationData.municipality} display=${locationData.address}',
      );

      return locationData;
    } catch (e) {
      debugPrint('GooglePlacesService reverseGeocodeLocationData error: $e');
      return null;
    } finally {
      stopwatch.stop();
    }
  }
}

Map<String, dynamic>? _resolveLocationDataFromPayload(String payload) {
  final decoded = jsonDecode(payload) as Map<String, dynamic>;
  final response = decoded['response'] as Map<String, dynamic>?;
  final results = response?['results'] as List<dynamic>? ?? const [];
  if ((response?['status']?.toString() ?? '') != 'OK' || results.isEmpty) {
    return null;
  }

  String? route;
  String? streetNumber;
  String? neighborhood;
  String? sublocality;
  String? locality;
  String? adminLevel2;
  String? adminLevel1;
  String? country;
  String? placeId;

  for (final rawResult in results) {
    final resultItem = rawResult as Map<String, dynamic>;
    placeId ??= resultItem['place_id']?.toString();

    final components = resultItem['address_components'] as List<dynamic>? ?? const [];
    for (final rawComponent in components) {
      final component = rawComponent as Map<String, dynamic>;
      final types = (component['types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final longName = component['long_name']?.toString();
      if (longName == null || longName.isEmpty) continue;

      if (types.contains('route')) route ??= longName;
      if (types.contains('street_number')) streetNumber ??= longName;
      if (types.contains('neighborhood')) neighborhood ??= longName;
      if (types.contains('sublocality') || types.contains('sublocality_level_1')) {
        sublocality ??= longName;
      }
      if (types.contains('locality')) locality ??= longName;
      if (types.contains('administrative_area_level_2')) adminLevel2 ??= longName;
      if (types.contains('administrative_area_level_1')) adminLevel1 ??= longName;
      if (types.contains('country')) country ??= longName;
    }
  }

  final isUrban = (route != null && route!.isNotEmpty) ||
      (streetNumber != null && streetNumber!.isNotEmpty);
  final contextType = isUrban ? 'urban' : 'rural';

  final municipality = locality ?? adminLevel2 ?? adminLevel1 ?? '';
  if (municipality.isEmpty) {
    return null;
  }

  final displayAddress = resolveDisplayAddress(
    route: route,
    streetNumber: streetNumber,
    neighborhood: neighborhood,
    sublocality: sublocality,
    locality: locality,
    administrativeAreaLevel2: adminLevel2,
    administrativeAreaLevel1: adminLevel1,
    isUrban: isUrban,
  );

  return {
    'municipality': municipality,
    'department': adminLevel1,
    'country': country,
    'placeId': placeId,
    'displayAddress': displayAddress,
    'contextType': contextType,
    'isUrban': isUrban,
  };
}

String resolveDisplayAddress({
  String? route,
  String? streetNumber,
  String? neighborhood,
  String? sublocality,
  String? locality,
  String? administrativeAreaLevel2,
  String? administrativeAreaLevel1,
  required bool isUrban,
}) {
  final display = resolveDisplayLabel(
    poiName: null,
    textSearchPoiName: null,
    route: route,
    streetNumber: streetNumber,
    neighborhood: neighborhood,
    sublocality: sublocality,
    locality: locality,
    administrativeAreaLevel2: administrativeAreaLevel2,
    administrativeAreaLevel1: administrativeAreaLevel1,
    isUrban: isUrban,
  );
  return display.fullText;
}

ResolvedDisplayLabel resolveDisplayLabel({
  String? landmarkName,
  String? poiName,
  String? textSearchPoiName,
  String? route,
  String? streetNumber,
  String? neighborhood,
  String? sublocality,
  String? locality,
  String? administrativeAreaLevel2,
  String? administrativeAreaLevel1,
  required bool isUrban,
}) {
  final cleanLandmark = (landmarkName ?? '').trim();
  final cleanPoi = (poiName ?? '').trim();
  final cleanTextSearchPoi = (textSearchPoiName ?? '').trim();
  final municipality =
      (locality ?? administrativeAreaLevel2 ?? administrativeAreaLevel1 ?? '')
          .trim();
  final department = (administrativeAreaLevel1 ?? '').trim();
  final subtitle = _composeSubtitle(municipality, department);

  if (cleanLandmark.isNotEmpty) {
    return ResolvedDisplayLabel(
      label: cleanLandmark,
      subtitle: subtitle,
    );
  }

  if (cleanPoi.isNotEmpty) {
    return ResolvedDisplayLabel(
      label: cleanPoi,
      subtitle: subtitle,
    );
  }

  if (cleanTextSearchPoi.isNotEmpty) {
    return ResolvedDisplayLabel(
      label: cleanTextSearchPoi,
      subtitle: subtitle,
    );
  }

  final cleanRoute = (route ?? '').trim();
  final cleanStreetNumber = (streetNumber ?? '').trim();
  if (isUrban && cleanRoute.isNotEmpty) {
    final streetLabel = cleanStreetNumber.isNotEmpty
        ? '$cleanRoute #$cleanStreetNumber'
        : cleanRoute;
    return ResolvedDisplayLabel(
      label: streetLabel,
      subtitle: subtitle,
    );
  }

  final cleanNeighborhood = (neighborhood ?? '').trim();
  if (cleanNeighborhood.isNotEmpty) {
    return ResolvedDisplayLabel(
      label: cleanNeighborhood,
      subtitle: subtitle,
    );
  }

  final cleanSublocality = (sublocality ?? '').trim();
  if (cleanSublocality.isNotEmpty) {
    return ResolvedDisplayLabel(
      label: cleanSublocality,
      subtitle: subtitle,
    );
  }

  final fallback = subtitle.isNotEmpty ? subtitle : 'Punto en la vía';
  return ResolvedDisplayLabel(label: fallback, subtitle: '');
}

String _composeSubtitle(String municipality, String department) {
  if (municipality.isNotEmpty &&
      department.isNotEmpty &&
      municipality != department) {
    return '$municipality, $department';
  }
  return municipality.isNotEmpty ? municipality : department;
}

class ResolvedDisplayLabel {
  final String label;
  final String subtitle;

  const ResolvedDisplayLabel({
    required this.label,
    required this.subtitle,
  });

  String get fullText {
    if (subtitle.trim().isEmpty) {
      return label.trim().isEmpty ? 'Punto en la vía' : label.trim();
    }
    return '${label.trim()}, ${subtitle.trim()}';
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
