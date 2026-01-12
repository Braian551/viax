// lib/src/global/services/location_service.dart
// SERVICIO COMENTADO - YA NO SE USA GOOGLE MAPS
/*
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  /// Solicita permisos de ubicación y verifica el servicio
  static Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Permisos de ubicación denegados por el usuario');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Permisos de ubicación denegados permanentemente');
        return false;
      }

      return true;
    } catch (e) {
      print('Error solicitando permisos de ubicación: $e');
      return false;
    }
  }

  /// Obtiene la ubicación actual del usuario
  static Future<Position?> getCurrentPosition() async {
    bool hasPermission = await requestLocationPermission();
    if (!hasPermission) return null;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Intenta solicitar que se active el servicio
      bool requested = await Geolocator.openLocationSettings();
      if (!requested) {
        print('Servicio de ubicación deshabilitado');
        return null;
      }
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Permisos de ubicación denegados por el usuario');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Permisos de ubicación denegados permanentemente');
      return null;
    }

    // Configuración para mejor precisión
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings
      );
      return position;
    } catch (e) {
      print('Error obteniendo ubicación: $e');
      return null;
    }
  }

  /// Convierte coordenadas a dirección legible
  static Future<String?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Validar coordenadas
      if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
        print('Coordenadas invÃ¡lidas: lat=$latitude, lng=$longitude');
        return null;
      }

      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = '';
        
        if (place.street != null && place.street!.isNotEmpty) {
          address += place.street!;
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          address += address.isNotEmpty ? ', ${place.locality}' : place.locality!;
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          address += address.isNotEmpty ? ', ${place.administrativeArea}' : place.administrativeArea!;
        }
        
        return address.isNotEmpty ? address : 'DirecciÃ³n no disponible';
      }
      return null;
    } catch (e) {
      print('Error obteniendo direcciÃ³n: $e');
      return null;
    }
  }

  /// Convierte direcciÃ³n a coordenadas
  static Future<Position?> getCoordinatesFromAddress(String address) async {
    try {
      if (address.trim().isEmpty) {
        print('DirecciÃ³n vacÃ­a proporcionada');
        return null;
      }

      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        Location location = locations.first;
        return Position(
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
      print('No se encontraron coordenadas para la direcciÃ³n: $address');
      return null;
    } catch (e) {
      print('Error obteniendo coordenadas: $e');
      return null;
    }
  }
}
*/
