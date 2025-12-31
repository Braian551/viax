import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/simple_location.dart';
import 'mapbox_service.dart';

/// Servicio potenciado para sugerencias de ubicación usando Mapbox
/// Usa estrategia de búsqueda local-first con bounding box + POI priority (estilo DiDi)
class LocationSuggestionService {
  static final Map<String, List<SimpleLocation>> _cache = {};
  static const int _cacheMaxSize = 50;
  
  /// Tipos de lugares a buscar: POIs primero (escuelas, negocios), luego direcciones
  static const List<String> poiTypes = ['poi', 'poi.landmark', 'address', 'place', 'neighborhood'];
  
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
  
  /// Busca sugerencias con estrategia LOCAL-FIRST + POI PRIORITY (como DiDi)
  Future<List<SimpleLocation>> searchSuggestions({
    required String query,
    int limit = 8,
    bool localFirst = true,
  }) async {
    if (query.trim().length < 2) {
      return [];
    }
    
    final distanceRef = referencePoint ?? userLocation;
    final cacheKey = '${query.toLowerCase()}_${distanceRef?.latitude}_${distanceRef?.longitude}_${countryCode}_$limit';
    
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }
    
    try {
      List<MapboxPlace> places = [];
      
      // ESTRATEGIA LOCAL-FIRST + POI PRIORITY (como DiDi)
      if (localFirst && distanceRef != null) {
        // Paso 1: Buscar POIs en ~50km
        final bbox50km = _createBoundingBox(distanceRef, 0.45);
        
        places = await MapboxService.searchPlaces(
          query: query,
          limit: 10,
          proximity: distanceRef,
          country: countryCode,
          bbox: bbox50km,
          types: poiTypes, // ¡CLAVE: Incluir POIs!
          fuzzyMatch: true,
        );
        
        // Paso 2: Si < 3 resultados, expandir a ~100km
        if (places.length < 3) {
          final bbox100km = _createBoundingBox(distanceRef, 0.9);
          
          final morePlaces = await MapboxService.searchPlaces(
            query: query,
            limit: 10,
            proximity: distanceRef,
            country: countryCode,
            bbox: bbox100km,
            types: poiTypes,
            fuzzyMatch: true,
          );
          
          final existingIds = places.map((p) => p.id).toSet();
          for (var p in morePlaces) {
            if (!existingIds.contains(p.id)) {
              places.add(p);
            }
          }
        }
      }
      
      // Paso 3: Fallback nacional con POIs
      if (places.isEmpty) {
        places = await MapboxService.searchPlaces(
          query: query,
          limit: limit,
          proximity: distanceRef,
          country: countryCode,
          types: poiTypes,
          fuzzyMatch: true,
        );
      }
      
      final results = _convertPlacesToLocations(places, distanceRef);
      
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
  
  List<double> _createBoundingBox(LatLng center, double radiusDegrees) {
    return [
      center.longitude - radiusDegrees,
      center.latitude - radiusDegrees,
      center.longitude + radiusDegrees,
      center.latitude + radiusDegrees,
    ];
  }
  
  List<SimpleLocation> _convertPlacesToLocations(
    List<MapboxPlace> places, 
    LatLng? referencePoint,
  ) {
    final Distance distanceCalculator = const Distance();
    
    return places.map((place) {
      double? distanceKm;
      if (referencePoint != null) {
        distanceKm = distanceCalculator.as(
          LengthUnit.Kilometer,
          referencePoint,
          place.coordinates,
        );
      }
      
      final placeInfo = _extractPlaceInfo(place);
      
      return SimpleLocation(
        latitude: place.coordinates.latitude,
        longitude: place.coordinates.longitude,
        address: place.placeName,
        placeName: placeInfo.name,
        subtitle: placeInfo.subtitle,
        distanceKm: distanceKm,
        placeType: place.placeType,
      );
    }).toList();
  }
  
  _PlaceInfo _extractPlaceInfo(MapboxPlace place) {
    String name = place.text;
    String subtitle = '';
    
    final fullName = place.placeName;
    if (fullName.contains(',')) {
      final parts = fullName.split(',').map((e) => e.trim()).toList();
      if (parts.length > 1) {
        final startIndex = parts[0] == name ? 1 : 0;
        subtitle = parts.sublist(startIndex).take(3).join(', ');
      }
    }
    
    if (subtitle.isEmpty && place.address != null) {
      subtitle = place.address!;
    }
    
    return _PlaceInfo(name: name, subtitle: subtitle);
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
  
  Future<String?> reverseGeocode(double lat, double lon) async {
    try {
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

class _PlaceInfo {
  final String name;
  final String subtitle;
  const _PlaceInfo({required this.name, required this.subtitle});
}
