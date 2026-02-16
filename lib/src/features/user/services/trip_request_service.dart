import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../core/network/network_request_executor.dart';
import '../../../core/network/app_network_exception.dart';
import '../../../global/models/simple_location.dart';

class TripRequestService {
  static String get baseUrl => AppConfig.baseUrl;
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();

  static String _friendlyMessage(NetworkRequestResult result, {String fallback = 'No pudimos completar la operación.'}) {
    return result.error?.userMessage ?? fallback;
  }

  static Map<String, dynamic> _errorResponse(NetworkRequestResult result, {String fallback = 'No pudimos completar la operación.'}) {
    return {
      'success': false,
      'message': _friendlyMessage(result, fallback: fallback),
      'error_type': result.error?.type.name,
    };
  }

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
      
      final result = await _network.postJson(
        url: Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        throw Exception(_friendlyMessage(result, fallback: 'No pudimos crear tu solicitud de viaje.'));
      }

      final data = result.json!;
      if (data['success'] == true) {
        print('✅ Solicitud creada exitosamente');
        return data;
      }

      final backendMessage = data['message']?.toString() ?? 'No pudimos crear tu solicitud de viaje.';
      throw Exception(backendMessage);
    } catch (e) {
      print('❌ Error en createTripRequest: $e');
      final networkError = AppNetworkException.fromError(e);
      throw Exception(networkError.userMessage);
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
      
      final result = await _network.postJson(
        url: Uri.parse('$baseUrl/user/find_nearby_drivers.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return [];
      }

      final data = result.json!;
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['conductores'] ?? []);
      }

      return [];
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
      final result = await _network.postJson(
        url: Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'solicitud_id': solicitudId,
        }),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        throw Exception(_friendlyMessage(result, fallback: 'No pudimos cancelar la solicitud.'));
      }

      final data = result.json!;
      if (data['success'] == true) {
        print('✅ Solicitud cancelada exitosamente');
        return true;
      }

      throw Exception(data['message']?.toString() ?? 'No pudimos cancelar la solicitud.');
    } catch (e) {
      print('❌ Error cancelando solicitud: $e');
      rethrow;
    }
  }

  /// Obtener estado de la solicitud
  static Future<Map<String, dynamic>?> getTripRequestStatus(int solicitudId) async {
    try {
      final result = await _network.getJson(
        url: Uri.parse('$baseUrl/user/get_trip_status.php?solicitud_id=$solicitudId'),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return null;
      }

      final data = result.json!;
      if (data['success'] == true) {
        return data['solicitud'];
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
      
      final result = await _network.getJson(
        url: Uri.parse(url),
        headers: {'Accept': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return _errorResponse(result, fallback: 'No pudimos consultar el estado del viaje.');
      }

      return result.json!;
    } catch (e) {
      print('❌ Error obteniendo estado: $e');
      final mapped = AppNetworkException.fromError(e);
      return {
        'success': false,
        'message': mapped.userMessage,
        'error_type': mapped.type.name,
      };
    }
  }

  /// Cancelar solicitud con parámetros completos
  /// Usa el mismo endpoint que el conductor para consistencia
  /// Cancelar solicitud con parámetros completos.
  /// Maneja tanto viajes activos (con conductor) como solicitudes en espera.
  static Future<Map<String, dynamic>> cancelTripRequestWithReason({
    required int solicitudId,
    int? clienteId,
    int? conductorId,
    String motivo = 'Cliente canceló',
    String canceladoPor = 'cliente',
  }) async {
    try {
      print('🚫 [TripRequestService] Cancelando solicitud ID: $solicitudId por: $canceladoPor');
      
      // Si tenemos conductorId, usamos el endpoint de actualización de estado (más robusto para viajes en curso)
      if (conductorId != null && conductorId > 0) {
        final body = {
          'solicitud_id': solicitudId,
          'conductor_id': conductorId,
          'nuevo_estado': 'cancelada',
          'motivo_cancelacion': motivo,
          'cancelado_por': canceladoPor,
        };
        
        print('📦 [TripRequestService] Usando endpoint conductor (update_trip_status). Body: $body');

        final result = await _network.postJson(
          url: Uri.parse('$baseUrl/conductor/update_trip_status.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
          timeout: AppConfig.connectionTimeout,
        );

        if (!result.success || result.json == null) {
          return _errorResponse(result, fallback: 'No pudimos cancelar el viaje en este momento.');
        }

        return result.json!;
      } 
      // Si no hay conductor (ej. aún buscando), usamos el endpoint de cancelación simple del cliente
      else {
        final body = {
          'solicitud_id': solicitudId,
          'cliente_id': clienteId,
          'motivo': motivo,
          'cancelado_por': canceladoPor,
        };
        
        print('📦 [TripRequestService] Usando endpoint cliente (cancel_trip_request). Body: $body');

        final result = await _network.postJson(
          url: Uri.parse('$baseUrl/user/cancel_trip_request.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
          timeout: AppConfig.connectionTimeout,
        );

        if (!result.success || result.json == null) {
          return _errorResponse(result, fallback: 'No pudimos cancelar la solicitud en este momento.');
        }

        return result.json!;
      }
    } catch (e) {
      print('❌ Error cancelando solicitud: $e');
      final mapped = AppNetworkException.fromError(e);
      return {
        'success': false,
        'message': mapped.userMessage,
        'error_type': mapped.type.name,
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
      
      final result = await _network.getJson(
        url: Uri.parse(url),
        headers: {'Accept': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return _errorResponse(result, fallback: 'No pudimos validar si tienes un viaje activo.');
      }

      return result.json!;
    } catch (e) {
      print('❌ Error check active trip: $e');
      final mapped = AppNetworkException.fromError(e);
      return {
        'success': false,
        'message': mapped.userMessage,
        'error_type': mapped.type.name,
      };
    }
  }
}
