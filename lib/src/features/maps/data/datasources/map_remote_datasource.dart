import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/core/error/exceptions.dart';
import '../models/location_model.dart';

Map<String, double> parseRideSignals(Map<String, dynamic> json) {
  double toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  return {
    'pickupEtaMinutes':
        toDouble(json['pickupEtaMinutes'] ?? json['pickup_eta_minutes']),
    'surgeMultiplier':
        toDouble(json['surgeMultiplier'] ?? json['surge_multiplier'], fallback: 1.0),
    'driverDistance':
        toDouble(json['driverDistance'] ?? json['driver_distance']),
  };
}

/// Interfaz abstracta para el datasource de mapas
abstract class MapRemoteDataSource {
  Future<LocationModel> geocodeAddress(String address);
  Future<LocationModel> reverseGeocode(double lat, double lng);
  Future<RouteModel> calculateRoute(Map<String, dynamic> origin, Map<String, dynamic> destination);
  Future<double> calculateDistance(Map<String, dynamic> origin, Map<String, dynamic> destination);
  Future<List<LocationModel>> searchNearbyPlaces(double lat, double lng, String query, double radius, {int? userId});
  Future<List<LocationModel>> getRecentSearches({required int userId});
  Future<void> saveRecentSearch({
    required int userId,
    required LocationModel location,
  });
}

/// ImplementaciÃ³n del datasource de mapas
class MapRemoteDataSourceImpl implements MapRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  MapRemoteDataSourceImpl({
    required this.client,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? AppConfig.mapServiceUrl;

  String get _apiBaseUrl => AppConfig.baseUrl;

  @override
  Future<LocationModel> geocodeAddress(String address) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/geocode.php?address=${Uri.encodeComponent(address)}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return LocationModel.fromJson(data['location']);
        } else {
          throw ServerException(data['message'] ?? 'Error al geocodificar');
        }
      } else {
        throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexiÃ³n: ${e.toString()}');
    }
  }

  @override
  Future<LocationModel> reverseGeocode(double lat, double lng) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/reverse_geocode.php?lat=$lat&lng=$lng'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return LocationModel.fromJson(data['location']);
        } else {
          throw ServerException(data['message'] ?? 'Error al obtener direcciÃ³n');
        }
      } else {
        throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexiÃ³n: ${e.toString()}');
    }
  }

  @override
  Future<RouteModel> calculateRoute(
    Map<String, dynamic> origin,
    Map<String, dynamic> destination,
  ) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/calculate_route.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'origin': origin,
          'destination': destination,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return RouteModel.fromJson(data['route']);
        } else {
          throw ServerException(data['message'] ?? 'Error al calcular ruta');
        }
      } else {
        throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexiÃ³n: ${e.toString()}');
    }
  }

  @override
  Future<double> calculateDistance(
    Map<String, dynamic> origin,
    Map<String, dynamic> destination,
  ) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/calculate_distance.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'origin': origin,
          'destination': destination,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['distance'] as num).toDouble();
        } else {
          throw ServerException(data['message'] ?? 'Error al calcular distancia');
        }
      } else {
        throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexiÃ³n: ${e.toString()}');
    }
  }

  @override
  Future<List<LocationModel>> searchNearbyPlaces(
    double lat,
    double lng,
    String query,
    double radius,
    {int? userId}
  ) async {
    try {
      final qp = <String, String>{
        'lat': '$lat',
        'lng': '$lng',
        'query': query,
        'radius': '$radius',
      };
      if (userId != null && userId > 0) {
        qp['user_id'] = '$userId';
      }

      final response = await client.get(
        Uri.parse('$_apiBaseUrl/user/search_places.php').replace(queryParameters: qp),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> places = data['places'] ?? [];
          return places.map((p) => LocationModel.fromJson(p)).toList();
        } else {
          throw ServerException(data['message'] ?? 'Error al buscar lugares');
        }
      } else {
        throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexiÃ³n: ${e.toString()}');
    }
  }

  @override
  Future<List<LocationModel>> getRecentSearches({required int userId}) async {
    try {
      Future<List<LocationModel>> parseRecentResponse(http.Response response) async {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            final List<dynamic> items =
                (data['recent_searches'] as List<dynamic>?) ??
                (data['places'] as List<dynamic>?) ??
                <dynamic>[];

            return items
                .map(
                  (p) => LocationModel.fromJson(<String, dynamic>{
                    'lat': p['lat'] ?? p['latitud'],
                    'lng': p['lng'] ?? p['longitud'],
                    'address': p['address'] ?? p['direccion'] ?? p['name'],
                  }),
                )
                .where((loc) => loc.latitud != 0 && loc.longitud != 0)
                .toList();
          }
          throw ServerException(data['message'] ?? 'Error al cargar búsquedas recientes');
        }
        throw ServerException('Error del servidor: ${response.statusCode}');
      }

      // Endpoint dedicado.
      final primary = await client.get(
        Uri.parse('$_apiBaseUrl/user/get_recent_searches.php').replace(
          queryParameters: {
            'user_id': '$userId',
            '_ts': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        ),
        headers: {'Content-Type': 'application/json'},
      );

      return parseRecentResponse(primary);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexión: ${e.toString()}');
    }
  }

  @override
  Future<void> saveRecentSearch({
    required int userId,
    required LocationModel location,
  }) async {
    try {
      final response = await client.post(
        Uri.parse('$_apiBaseUrl/user/save_recent_search.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'place_name': location.direccion ?? 'Ubicación',
          'place_address': location.direccion ?? 'Ubicación',
          'place_lat': location.latitud,
          'place_lng': location.longitud,
        }),
      );

      if (response.statusCode != 200) {
        throw ServerException('Error del servidor: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw ServerException(data['message'] ?? 'No se pudo guardar búsqueda reciente');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexión: ${e.toString()}');
    }
  }
}
