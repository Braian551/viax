import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../models/confianza_model.dart';

/// Servicio para gestionar conductores de confianza
/// 
/// Maneja:
/// - Marcar/desmarcar conductores como favoritos
/// - Obtener lista de conductores favoritos
/// - Calcular score de confianza
class TrustedDriverService {
  static String get baseUrl => AppConfig.baseUrl;

  /// Marca o desmarca un conductor como favorito
  /// 
  /// Retorna `true` si el conductor quedó como favorito,
  /// `false` si fue removido de favoritos
  static Future<bool> toggleFavorite({
    required int usuarioId,
    required int conductorId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/toggle_favorite_driver.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario_id': usuarioId,
          'conductor_id': conductorId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('⭐ Favorito toggle: ${data['es_favorito']}');
          return data['es_favorito'] ?? false;
        } else {
          throw Exception(data['message'] ?? 'Error al actualizar favorito');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error en toggleFavorite: $e');
      rethrow;
    }
  }

  /// Obtiene la lista de conductores favoritos del usuario
  static Future<List<ConductorFavorito>> getFavoriteDrivers({
    required int usuarioId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/get_favorite_drivers.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario_id': usuarioId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final favoritos = (data['favoritos'] as List?)
              ?.map((f) => ConductorFavorito.fromJson(f))
              .toList() ?? [];
          debugPrint('⭐ Favoritos obtenidos: ${favoritos.length}');
          return favoritos;
        } else {
          throw Exception(data['message'] ?? 'Error al obtener favoritos');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error en getFavoriteDrivers: $e');
      return [];
    }
  }

  /// Calcula el score de confianza entre un usuario y un conductor
  static Future<ConfianzaInfo?> calculateTrustScore({
    required int usuarioId,
    required int conductorId,
    double? latitud,
    double? longitud,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'usuario_id': usuarioId,
        'conductor_id': conductorId,
      };
      
      if (latitud != null && longitud != null) {
        body['latitud'] = latitud;
        body['longitud'] = longitud;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/confianza/calculate_score.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return ConfianzaInfo(
            score: (data['score_confianza'] ?? 0).toDouble(),
            scoreTotal: (data['score_confianza'] ?? 0).toDouble() + 
                        (data['es_favorito'] == true ? 100 : 0),
            viajesPrevios: data['desglose']?['viajes_juntos'] ?? 0,
            esFavorito: data['es_favorito'] ?? false,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error en calculateTrustScore: $e');
      return null;
    }
  }

  /// Verifica si un conductor es favorito del usuario
  static Future<bool> isFavorite({
    required int usuarioId,
    required int conductorId,
  }) async {
    try {
      final score = await calculateTrustScore(
        usuarioId: usuarioId, 
        conductorId: conductorId,
      );
      return score?.esFavorito ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene información de confianza desde los datos de una solicitud
  /// (cuando ya viene incluida en la respuesta del backend)
  static ConfianzaInfo? parseConfianzaFromSolicitud(Map<String, dynamic> solicitud) {
    if (solicitud.containsKey('confianza')) {
      return ConfianzaInfo.fromJson(solicitud['confianza']);
    }
    return null;
  }
}
