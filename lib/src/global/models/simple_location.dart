import 'package:latlong2/latlong.dart';

/// Enhanced model to represent a location with rich display information.
/// Used for search suggestions, request screens, and map displays.
class SimpleLocation {
  final double latitude;
  final double longitude;
  final String address;
  
  /// Nombre corto del lugar (ej: "Colegio La Primavera")
  final String? placeName;
  
  /// Subtítulo con detalles (ej: "Calle 59c #68C37, Bello, Antioquia")
  final String? subtitle;
  
  /// Distancia en kilómetros desde el punto de referencia
  final double? distanceKm;
  
  /// Tipo de lugar: poi, address, place, neighborhood, etc.
  final String? placeType;
  
  /// ID del lugar de Google Places (para obtener detalles después)
  final String? placeId;

  /// Municipio al que pertenece (ej: "Medellín", "Bello")
  final String? municipality;

  const SimpleLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.placeName,
    this.subtitle,
    this.distanceKm,
    this.placeType,
    this.placeId,
    this.municipality,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);

  factory SimpleLocation.fromLatLng(LatLng pos, [String address = '']) {
    return SimpleLocation(
      latitude: pos.latitude, 
      longitude: pos.longitude, 
      address: address,
    );
  }
  
  /// Nombre para mostrar: placeName si existe, sino primera parte del address
  String get displayName {
    if (placeName != null && placeName!.isNotEmpty) {
      return placeName!;
    }
    // Extraer primera parte del address como nombre
    final parts = address.split(',');
    return parts.isNotEmpty ? parts[0].trim() : address;
  }
  
  /// Subtítulo para mostrar: subtitle si existe, sino resto del address
  String get displaySubtitle {
    if (subtitle != null && subtitle!.isNotEmpty) {
      return subtitle!;
    }
    // Extraer resto del address como subtítulo
    final parts = address.split(',');
    if (parts.length > 1) {
      return parts.sublist(1).take(2).map((e) => e.trim()).join(', ');
    }
    return '';
  }
  
  /// Distancia formateada para UI (ej: "4.2km" o "800m")
  String get formattedDistance {
    if (distanceKm == null) return '';
    if (distanceKm! < 1) {
      return '${(distanceKm! * 1000).toStringAsFixed(0)}m';
    }
    return '${distanceKm!.toStringAsFixed(1)}km';
  }
  
  /// Copia con nuevos valores
  SimpleLocation copyWith({
    double? latitude,
    double? longitude,
    String? address,
    String? placeName,
    String? subtitle,
    double? distanceKm,
    String? placeType,
    String? placeId,
    String? municipality,
  }) {
    return SimpleLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      placeName: placeName ?? this.placeName,
      subtitle: subtitle ?? this.subtitle,
      distanceKm: distanceKm ?? this.distanceKm,
      placeType: placeType ?? this.placeType,
      placeId: placeId ?? this.placeId,
      municipality: municipality ?? this.municipality,
    );
  }
  
  /// Verificar si el lugar tiene coordenadas válidas
  bool get hasValidCoordinates => latitude != 0 && longitude != 0;
  
  /// Verificar si necesita obtener detalles (tiene placeId pero no coordenadas)
  bool get needsDetails => placeId != null && placeId!.isNotEmpty && !hasValidCoordinates;
}

