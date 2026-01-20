import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../global/models/simple_location.dart';

class TripRequestService {
  static String get baseUrl => AppConfig.baseUrl;

  /// Crear una nueva solicitud de viaje
  static Future<Map<String, dynamic>> createTripRequest({
    required int userId,
    required double latitudOrigen,
    required double longitudOrigen,
    required String direccionOrigen,
    required double latitudDestino,
    required double longitudDestino,
    required String direccionDestino,
    required String tipoServicio, // 'viaje' o 'paquete'
    required String tipoVehiculo, // 'moto', 'auto', 'motocarro'
    required double distanciaKm,
    required int duracionMinutos,
    required double precioEstimado,
    int? empresaId, // ID de la empresa seleccionada para las tarifas
    List<SimpleLocation>? stops, // Paradas intermedias
  }) async {
    try {
      final url = '$baseUrl/user/create_trip_request.php';
      print('📍 Enviando solicitud a: $url');
      
      final requestBody = {
        'usuario_id': userId,
        'latitud_origen': latitudOrigen,
        'longitud_origen': longitudOrigen,
        'direccion_origen': direccionOrigen,
        'latitud_destino': latitudDestino,
        'longitud_destino': longitudDestino,
        'direccion_destino': direccionDestino,
        'tipo_servicio': tipoServicio,
        'tipo_vehiculo': tipoVehiculo,
        'distancia_km': distanciaKm,
        'duracion_minutos': duracionMinutos,
        'precio_estimado': precioEstimado,
        if (empresaId != null) 'empresa_id': empresaId,
      };

      // Agregar paradas si existen
      if (stops != null && stops.isNotEmpty) {
        requestBody['paradas'] = stops.map((stop) => {
          'latitud': stop.latitude,
          'longitud': stop.longitude,
          'direccion': stop.address,
        }).toList();
      }
      
      print('📦 Datos enviados: $requestBody');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Tiempo de espera agotado. Verifica tu conexión.');
        },
      );

      print('📥 Respuesta recibida - Status: ${response.statusCode}');
      print('📄 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ Solicitud creada exitosamente');
          return data;
        } else {
          final errorMsg = data['message'] ?? 'Error al crear solicitud';
          print('❌ Error del servidor: $errorMsg');
          throw Exception(errorMsg);
        }
      } else {
        final errorMsg = 'Error del servidor: ${response.statusCode} - ${response.body}';
        print('❌ $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('❌ Error en createTripRequest: $e');
      if (e.toString().contains('SocketException') || e.toString().contains('Connection')) {
        throw Exception('No se pudo conectar al servidor. Verifica tu conexión.');
      }
      throw Exception('Error al crear solicitud de viaje: $e');
    }
  }

  /// Buscar conductores cercanos disponibles
  /// Filtra por tipo de vehículo y opcionalmente por empresa
  static Future<List<Map<String, dynamic>>> findNearbyDrivers({
    required double latitude,
    required double longitude,
    required String vehicleType,
    int? empresaId,
    double radiusKm = 5.0,
  }) async {
    try {
      final requestBody = {
        'latitud': latitude,
        'longitud': longitude,
        'tipo_vehiculo': vehicleType,
        'radio_km': radiusKm,
        if (empresaId != null) 'empresa_id': empresaId,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/user/find_nearby_drivers.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['conductores'] ?? []);
        } else {
          return [];
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('Error buscando conductores cercanos: $e');
      return [];
    }
  }

  /// Cancelar solicitud de viaje
  static Future<bool> cancelTripRequest(int solicitudId) async {
    try {
      print('🚫 Cancelando solicitud ID: $solicitudId');
      
      final url = '$baseUrl/user/cancel_trip_request.php';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'solicitud_id': solicitudId,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Tiempo de espera agotado al cancelar');
        },
      );

      print('📥 Respuesta de cancelación - Status: ${response.statusCode}');
      print('📄 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ Solicitud cancelada exitosamente');
          return true;
        } else {
          print('❌ Error al cancelar: ${data['message']}');
          throw Exception(data['message'] ?? 'Error al cancelar la solicitud');
        }
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error cancelando solicitud: $e');
      rethrow;
    }
  }

  /// Obtener estado de la solicitud
  static Future<Map<String, dynamic>?> getTripRequestStatus(int solicitudId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/get_trip_status.php?solicitud_id=$solicitudId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['solicitud'];
        }
      }
      return null;
    } catch (e) {
      print('Error obteniendo estado de solicitud: $e');
      return null;
    }
  }

  /// Obtener estado completo del viaje con info del conductor
  static Future<Map<String, dynamic>> getTripStatus({
    required int solicitudId,
  }) async {
    try {
      final url = '$baseUrl/user/get_trip_status.php?solicitud_id=$solicitudId';
      print('🌐 [TripRequestService] GET: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );
      
      print('📡 [TripRequestService] Status: ${response.statusCode}');
      print('📄 [TripRequestService] Body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Error al obtener estado: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error obteniendo estado: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  /// Cancelar solicitud con parámetros completos
  static Future<Map<String, dynamic>> cancelTripRequestWithReason({
    required int solicitudId,
    required int clienteId,
    String motivo = 'Cliente canceló',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/cancel_trip_request.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'solicitud_id': solicitudId,
          'cliente_id': clienteId,
          'motivo': motivo,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error cancelando solicitud: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }
  /// Verificar si el usuario tiene un viaje activo
  static Future<Map<String, dynamic>> checkActiveTrip({
    required int userId,
    required String role,
  }) async {
    try {
      final url = '$baseUrl/user/check_active_trip.php?user_id=$userId&role=$role';
      print('查询 [TripRequestService] check active: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error check active trip: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }
}
