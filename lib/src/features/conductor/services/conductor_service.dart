import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/config/app_config.dart';

/// Servicio para operaciones de conductor
/// 
/// NOTA: Este servicio es redundante con ConductorRemoteDataSource.
/// Se mantiene por compatibilidad, pero deberÃ­a migrarse a usar
/// el patrÃ³n de Clean Architecture (Repository -> DataSource)
class ConductorService {
  /// URL base del microservicio de conductores
  static String get baseUrl => AppConfig.conductorServiceUrl;

  /// Obtener informaciÃ³n completa del conductor
  static Future<Map<String, dynamic>?> getConductorInfo(int conductorId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_info.php?conductor_id=$conductorId'),
        headers: {'Accept': 'application/json'},
      );

      print('Conductor info response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        }
      }
      return null;
    } catch (e) {
      print('Error obteniendo informaciÃ³n del conductor: $e');
      return null;
    }
  }

  /// Obtener viajes activos del conductor
  static Future<List<Map<String, dynamic>>> getViajesActivos(int conductorId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_viajes_activos.php?conductor_id=$conductorId'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['viajes'] != null) {
          return List<Map<String, dynamic>>.from(data['viajes']);
        }
      }
      return [];
    } catch (e) {
      print('Error obteniendo viajes activos: $e');
      return [];
    }
  }

  /// Obtener historial de viajes del conductor
  static Future<Map<String, dynamic>> getHistorialViajes({
    required int conductorId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_historial.php?conductor_id=$conductorId&page=$page&limit=$limit'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        }
      }
      return {'success': false, 'viajes': [], 'total': 0};
    } catch (e) {
      print('Error obteniendo historial de viajes: $e');
      return {'success': false, 'viajes': [], 'total': 0};
    }
  }

  /// Obtener estadÃ­sticas del conductor
  static Future<Map<String, dynamic>> getEstadisticas(int conductorId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_estadisticas.php?conductor_id=$conductorId'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['estadisticas'] ?? {};
        }
      }
      return {};
    } catch (e) {
      print('Error obteniendo estadÃ­sticas: $e');
      return {};
    }
  }

  /// Actualizar estado de disponibilidad del conductor
  static Future<bool> actualizarDisponibilidad({
    required int conductorId,
    required bool disponible,
    double? latitud,
    double? longitud,
  }) async {
    try {
      final body = {
        'conductor_id': conductorId,
        'disponible': disponible ? 1 : 0,
        if (latitud != null) 'latitud': latitud,
        if (longitud != null) 'longitud': longitud,
      };

      print('📡 Actualizando disponibilidad: conductorId=$conductorId, disponible=$disponible');
      
      final response = await http.post(
        Uri.parse('$baseUrl/actualizar_disponibilidad.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      print('📥 Respuesta disponibilidad: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return true;
        } else {
          // Lanzar excepción con el mensaje del servidor
          throw Exception(data['message'] ?? 'Error desconocido del servidor');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error actualizando disponibilidad: $e');
      rethrow; // Re-lanzar la excepción para que el provider la maneje
    }
  }

  /// Aceptar una solicitud de viaje
  static Future<Map<String, dynamic>> aceptarSolicitud({
    required int conductorId,
    required int solicitudId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/aceptar_solicitud.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'conductor_id': conductorId,
          'solicitud_id': solicitudId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      print('Error aceptando solicitud: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Actualizar ubicaciÃ³n del conductor
  /// Actualizar ubicaciÃ³n del conductor y datos del viaje en curso
  static Future<bool> actualizarUbicacion({
    required int conductorId,
    required double latitud,
    required double longitud,
    double? distanceKm,
    int? elapsedMinutes,
    int? solicitudId,
  }) async {
    try {
      final body = {
        'conductor_id': conductorId,
        'latitud': latitud,
        'longitud': longitud,
        if (distanceKm != null) 'distancia_recorrida': distanceKm,
        if (elapsedMinutes != null) 'tiempo_transcurrido': elapsedMinutes,
        if (solicitudId != null) 'solicitud_id': solicitudId,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/actualizar_ubicacion.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error actualizando ubicaciÃ³n: $e');
      return false;
    }
  }

  /// Obtener ganancias del conductor
  static Future<Map<String, dynamic>> getGanancias({
    required int conductorId,
    String? fechaInicio,
    String? fechaFin,
  }) async {
    try {
      var uri = '$baseUrl/get_ganancias.php?conductor_id=$conductorId';
      if (fechaInicio != null) uri += '&fecha_inicio=$fechaInicio';
      if (fechaFin != null) uri += '&fecha_fin=$fechaFin';

      final response = await http.get(
        Uri.parse(uri),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        }
      }
      return {'success': false, 'ganancias': {}};
    } catch (e) {
      print('Error obteniendo ganancias: $e');
      return {'success': false, 'ganancias': {}};
    }
  }

  /// Actualizar el estado de un viaje/solicitud
  /// Estados válidos: 'conductor_llego', 'recogido', 'en_curso', 'completada', 'cancelada'
  static Future<Map<String, dynamic>> actualizarEstadoViaje({
    required int conductorId,
    required int solicitudId,
    required String nuevoEstado,
    String? motivoCancelacion,
    double? distanceKm,
    int? elapsedMinutes,
  }) async {
    try {
      final body = {
        'conductor_id': conductorId,
        'solicitud_id': solicitudId,
        'nuevo_estado': nuevoEstado,
        if (motivoCancelacion != null) 'motivo_cancelacion': motivoCancelacion,
        if (distanceKm != null) 'distancia_recorrida': distanceKm,
        if (elapsedMinutes != null) 'tiempo_transcurrido': elapsedMinutes,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/update_trip_status.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      print('Update trip status response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'Error del servidor: ${response.statusCode}'};
    } catch (e) {
      print('Error actualizando estado del viaje: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Notificar que el conductor llegó al punto de recogida
  static Future<bool> notificarLlegadaRecogida({
    required int conductorId,
    required int solicitudId,
  }) async {
    final result = await actualizarEstadoViaje(
      conductorId: conductorId,
      solicitudId: solicitudId,
      nuevoEstado: 'conductor_llego',
    );
    return result['success'] == true;
  }

  /// Notificar que el cliente fue recogido e inicia el viaje
  static Future<bool> iniciarViaje({
    required int conductorId,
    required int solicitudId,
  }) async {
    final result = await actualizarEstadoViaje(
      conductorId: conductorId,
      solicitudId: solicitudId,
      nuevoEstado: 'en_curso',
    );
    return result['success'] == true;
  }

  /// Notificar que el viaje fue completado
  static Future<bool> completarViaje({
    required int conductorId,
    required int solicitudId,
    double? distanceKm,
    int? elapsedMinutes,
  }) async {
    final result = await actualizarEstadoViaje(
      conductorId: conductorId,
      solicitudId: solicitudId,
      nuevoEstado: 'completada',
      distanceKm: distanceKm,
      elapsedMinutes: elapsedMinutes,
    );
    return result['success'] == true;
  }

  /// Consultar el estado actual de un viaje (Polling)
  static Future<Map<String, dynamic>?> checkTripStatus(int solicitudId) async {
    try {
      // Usamos el endpoint de user/get_trip_status.php ya que es la fuente de verdad
      // y parece ser público/accesible
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/user/get_trip_status.php?solicitud_id=$solicitudId'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['trip'] != null) {
          return data['trip'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('Error checking trip status: $e');
      return null;
    }
  }
}
