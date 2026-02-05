import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../core/network/network_resilience_service.dart';
import '../../../global/models/simple_location.dart';

/// Servicio de solicitudes de viaje con resiliencia de red
/// 
/// Proporciona:
/// - Reintentos automáticos con backoff exponencial
/// - Idempotencia para evitar solicitudes duplicadas
/// - Manejo robusto de errores de conexión
class ResilientTripRequestService {
  static final ResilientTripRequestService _instance = ResilientTripRequestService._internal();
  factory ResilientTripRequestService() => _instance;
  ResilientTripRequestService._internal();

  final _networkService = NetworkResilienceService();
  static String get baseUrl => AppConfig.baseUrl;

  /// Genera una clave de idempotencia única para una solicitud de viaje
  static String generateRequestIdempotencyKey({
    required int userId,
    required double latOrigen,
    required double lngOrigen,
    required double latDestino,
    required double lngDestino,
  }) {
    // Usar coordenadas truncadas para evitar duplicados por variación de GPS
    final coordKey = '${latOrigen.toStringAsFixed(4)}_${lngOrigen.toStringAsFixed(4)}_'
        '${latDestino.toStringAsFixed(4)}_${lngDestino.toStringAsFixed(4)}';
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 60000; // Única por minuto
    return 'trip_${userId}_${coordKey}_$timestamp';
  }

  /// Crear una nueva solicitud de viaje con reintentos automáticos
  Future<Map<String, dynamic>> createTripRequestResilient({
    required int userId,
    required double latitudOrigen,
    required double longitudOrigen,
    required String direccionOrigen,
    required double latitudDestino,
    required double longitudDestino,
    required String direccionDestino,
    required String tipoServicio,
    required String tipoVehiculo,
    required double distanciaKm,
    required int duracionMinutos,
    required double precioEstimado,
    int? empresaId,
    List<SimpleLocation>? stops,
  }) async {
    final idempotencyKey = generateRequestIdempotencyKey(
      userId: userId,
      latOrigen: latitudOrigen,
      lngOrigen: longitudOrigen,
      latDestino: latitudDestino,
      lngDestino: longitudDestino,
    );

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
      'idempotency_key': idempotencyKey,
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

    debugPrint('📍 Enviando solicitud con idempotency: $idempotencyKey');

    final result = await _networkService.postWithRetry(
      url: '$baseUrl/user/create_trip_request.php',
      body: requestBody,
      headers: {
        'X-Idempotency-Key': idempotencyKey,
      },
      maxRetries: 3,
      timeout: const Duration(seconds: 15),
      operationId: idempotencyKey,
    );

    if (result.isSuccess && result.data != null) {
      final data = result.data!;
      if (data['success'] == true) {
        debugPrint('✅ Solicitud creada exitosamente (${result.attempts} intentos)');
        return data;
      } else {
        // La solicitud llegó pero el servidor rechazó
        throw Exception(data['message'] ?? 'Error al crear solicitud');
      }
    } else {
      debugPrint('❌ Falló después de ${result.attempts} intentos: ${result.error}');
      throw Exception(result.error ?? 'Error de conexión al crear solicitud');
    }
  }

  /// Verificar estado de una solicitud
  Future<Map<String, dynamic>?> getTripStatus(int solicitudId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/get_trip_status.php?solicitud_id=$solicitudId'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['trip'] != null) {
          return data['trip'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error verificando estado: $e');
      return null;
    }
  }

  /// Cancelar solicitud con reintentos
  Future<bool> cancelTripRequestResilient(int solicitudId, {int? userId}) async {
    final idempotencyKey = 'cancel_${solicitudId}_${DateTime.now().millisecondsSinceEpoch ~/ 30000}';
    
    final result = await _networkService.postWithRetry(
      url: '$baseUrl/user/cancel_trip_request.php',
      body: {
        'solicitud_id': solicitudId,
        if (userId != null) 'usuario_id': userId,
        'idempotency_key': idempotencyKey,
      },
      headers: {
        'X-Idempotency-Key': idempotencyKey,
      },
      maxRetries: 3,
      timeout: const Duration(seconds: 10),
    );

    if (result.isSuccess && result.data != null) {
      return result.data!['success'] == true;
    }
    
    return false;
  }

  /// Polling resiliente del estado de la solicitud
  Stream<Map<String, dynamic>?> pollTripStatus({
    required int solicitudId,
    Duration interval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 10),
  }) async* {
    final stopwatch = Stopwatch()..start();
    int consecutiveErrors = 0;
    
    while (stopwatch.elapsed < timeout) {
      try {
        final status = await getTripStatus(solicitudId);
        consecutiveErrors = 0;
        yield status;
        
        // Si el viaje terminó, parar el polling
        if (status != null) {
          final estado = status['estado'] as String?;
          if (estado == 'completada' || 
              estado == 'cancelada' || 
              estado == 'cancelada_por_usuario' ||
              estado == 'cancelada_por_conductor') {
            break;
          }
        }
      } catch (e) {
        consecutiveErrors++;
        debugPrint('⚠️ Error en polling ($consecutiveErrors): $e');
        
        // Si hay muchos errores consecutivos, aumentar el intervalo
        if (consecutiveErrors > 3) {
          await Future.delayed(interval * 2);
        }
        
        yield null;
      }
      
      await Future.delayed(interval);
    }
    
    stopwatch.stop();
  }
}
