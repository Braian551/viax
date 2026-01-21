import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';

/// Resultado de enviar una calificación.
class RatingResult {
  final bool success;
  final String message;
  final bool wasUpdated;
  final int? previousRating;
  final int? currentRating;
  final double? nuevoPromedio;

  const RatingResult({
    required this.success,
    required this.message,
    this.wasUpdated = false,
    this.previousRating,
    this.currentRating,
    this.nuevoPromedio,
  });

  factory RatingResult.fromJson(Map<String, dynamic> json) {
    return RatingResult(
      success: json['success'] == true,
      message: json['message'] ?? '',
      wasUpdated: json['updated'] == true,
      previousRating: json['previous_rating'] as int?,
      currentRating: json['current_rating'] as int?,
      nuevoPromedio: (json['nuevo_promedio'] as num?)?.toDouble(),
    );
  }

  factory RatingResult.error(String message) {
    return RatingResult(success: false, message: message);
  }
}

/// Servicio para gestionar calificaciones de viajes.
/// 
/// Maneja calificaciones de cliente a conductor y viceversa.
/// 
/// **Lógica de reemplazo**: Si un usuario intenta calificar el mismo
/// viaje más de una vez, la calificación anterior será reemplazada
/// por la nueva, evitando duplicados en la base de datos.
class RatingService {
  static String get _baseUrl => AppConfig.baseUrl;

  /// Enviar calificación de un viaje.
  /// 
  /// [solicitudId] ID de la solicitud/viaje.
  /// [calificadorId] ID del usuario que califica.
  /// [calificadoId] ID del usuario calificado.
  /// [calificacion] Valor de 1 a 5 estrellas.
  /// [tipoCalificador] 'cliente' o 'conductor'.
  /// [comentario] Comentario opcional.
  /// 
  /// **Nota**: Si el usuario ya había calificado este viaje,
  /// la calificación anterior será reemplazada automáticamente.
  static Future<Map<String, dynamic>> enviarCalificacion({
    required int solicitudId,
    required int calificadorId,
    required int calificadoId,
    required int calificacion,
    required String tipoCalificador,
    String? comentario,
  }) async {
    try {
      debugPrint('📝 [RatingService] Enviando calificación:');
      debugPrint('   - solicitud_id: $solicitudId');
      debugPrint('   - calificador_id: $calificadorId');
      debugPrint('   - calificado_id: $calificadoId');
      debugPrint('   - calificacion: $calificacion');
      debugPrint('   - tipo_calificador: $tipoCalificador');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/rating/submit_rating.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'solicitud_id': solicitudId,
          'calificador_id': calificadorId,
          'calificado_id': calificadoId,
          'calificacion': calificacion,
          'tipo_calificador': tipoCalificador,
          'comentario': comentario,
        }),
      );

      debugPrint('📥 [RatingService] Response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Log si fue una actualización
        if (data['updated'] == true) {
          debugPrint('♻️ [RatingService] Calificación actualizada (anterior: ${data['previous_rating']})');
        } else {
          debugPrint('✅ [RatingService] Nueva calificación creada');
        }
        
        return data;
      }
      
      return {
        'success': false,
        'message': 'Error al enviar calificación: ${response.statusCode}',
      };
    } catch (e) {
      debugPrint('❌ [RatingService] Error enviando calificación: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  /// Enviar calificación con resultado tipado.
  /// 
  /// Versión alternativa que retorna un [RatingResult] en lugar de Map.
  static Future<RatingResult> enviarCalificacionTyped({
    required int solicitudId,
    required int calificadorId,
    required int calificadoId,
    required int calificacion,
    required String tipoCalificador,
    String? comentario,
  }) async {
    final result = await enviarCalificacion(
      solicitudId: solicitudId,
      calificadorId: calificadorId,
      calificadoId: calificadoId,
      calificacion: calificacion,
      tipoCalificador: tipoCalificador,
      comentario: comentario,
    );
    
    return RatingResult.fromJson(result);
  }

  /// Obtener calificaciones de un usuario.
  static Future<Map<String, dynamic>> obtenerCalificaciones({
    required int usuarioId,
    required String tipoUsuario, // 'cliente' o 'conductor'
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final url = '$_baseUrl/rating/get_ratings.php'
          '?usuario_id=$usuarioId'
          '&tipo_usuario=$tipoUsuario'
          '&page=$page'
          '&limit=$limit';
      
      debugPrint('📥 [RatingService] Fetching ratings from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );

      debugPrint('📥 [RatingService] Response status: ${response.statusCode}');
      debugPrint('📥 [RatingService] Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('📥 [RatingService] Parsed ${(data['calificaciones'] as List?)?.length ?? 0} calificaciones');
        return data;
      }
      
      debugPrint('📥 [RatingService] Error: status ${response.statusCode}');
      return {'success': false, 'calificaciones': []};
    } catch (e) {
      debugPrint('📥 [RatingService] Exception: $e');
      return {'success': false, 'calificaciones': []};
    }
  }

  /// Confirmar recepción de pago en efectivo.
  static Future<Map<String, dynamic>> confirmarPagoEfectivo({
    required int solicitudId,
    required int conductorId,
    required double monto,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/rating/confirm_cash_payment.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'solicitud_id': solicitudId,
          'conductor_id': conductorId,
          'monto': monto,
        }),
      );

      debugPrint('Payment confirmation (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      
      return {
        'success': false,
        'message': 'Error al confirmar pago',
      };
    } catch (e) {
      debugPrint('Error confirmando pago: $e');
      return {
        'success': false,
        'message': 'Error de conexión',
      };
    }
  }

  /// Obtener resumen de viaje completado.
  static Future<Map<String, dynamic>> obtenerResumenViaje({
    required int solicitudId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/rating/get_trip_summary.php?solicitud_id=$solicitudId'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      
      return {'success': false};
    } catch (e) {
      debugPrint('Error obteniendo resumen: $e');
      return {'success': false};
    }
  }
}
