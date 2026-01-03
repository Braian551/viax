import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../models/notification_model.dart';

/// Servicio para gestionar las notificaciones del usuario
/// Maneja la comunicación con el backend de notificaciones
class NotificationService {
  static const String _basePath = '/notifications';

  /// Obtiene las notificaciones del usuario
  /// 
  /// [userId] ID del usuario
  /// [page] Número de página (default: 1)
  /// [limit] Cantidad por página (default: 20)
  /// [soloNoLeidas] Filtrar solo no leídas
  /// [tipo] Filtrar por tipo de notificación
  static Future<Map<String, dynamic>> getNotifications({
    required int userId,
    int page = 1,
    int limit = 20,
    bool soloNoLeidas = false,
    String? tipo,
  }) async {
    try {
      final queryParams = {
        'usuario_id': userId.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
        if (soloNoLeidas) 'solo_no_leidas': 'true',
        if (tipo != null) 'tipo': tipo,
      };

      final uri = Uri.parse('${AppConfig.baseUrl}$_basePath/get_notifications.php')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (data['success'] == true) {
        final notificaciones = (data['notificaciones'] as List)
            .map((n) => NotificationModel.fromJson(n))
            .toList();

        return {
          'success': true,
          'notificaciones': notificaciones,
          'no_leidas': data['no_leidas'] ?? 0,
          'pagination': data['pagination'],
        };
      }

      return {
        'success': false,
        'error': data['error'] ?? 'Error al obtener notificaciones',
      };
    } catch (e) {
      debugPrint('Error getNotifications: $e');
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  /// Obtiene solo el conteo de notificaciones no leídas
  /// Optimizado para llamadas frecuentes (badge)
  static Future<int> getUnreadCount({required int userId}) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}$_basePath/get_unread_count.php')
          .replace(queryParameters: {'usuario_id': userId.toString()});

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      return data['count'] ?? 0;
    } catch (e) {
      debugPrint('Error getUnreadCount: $e');
      return 0;
    }
  }

  /// Marca notificaciones como leídas
  /// 
  /// [userId] ID del usuario
  /// [notificationId] ID de una notificación específica (opcional)
  /// [notificationIds] Lista de IDs a marcar (opcional)
  /// [markAll] Marcar todas como leídas (opcional)
  static Future<Map<String, dynamic>> markAsRead({
    required int userId,
    int? notificationId,
    List<int>? notificationIds,
    bool markAll = false,
  }) async {
    try {
      final body = {
        'usuario_id': userId,
        if (notificationId != null) 'notification_id': notificationId,
        if (notificationIds != null) 'notification_ids': notificationIds,
        if (markAll) 'mark_all': true,
      };

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}$_basePath/mark_as_read.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'affected': data['affected'] ?? 0,
        'no_leidas': data['no_leidas'] ?? 0,
      };
    } catch (e) {
      debugPrint('Error markAsRead: $e');
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  /// Elimina notificaciones (soft delete)
  /// 
  /// [userId] ID del usuario
  /// [notificationId] ID de una notificación específica (opcional)
  /// [notificationIds] Lista de IDs a eliminar (opcional)
  /// [deleteAll] Eliminar todas (opcional)
  static Future<Map<String, dynamic>> deleteNotification({
    required int userId,
    int? notificationId,
    List<int>? notificationIds,
    bool deleteAll = false,
  }) async {
    try {
      final body = {
        'usuario_id': userId,
        if (notificationId != null) 'notification_id': notificationId,
        if (notificationIds != null) 'notification_ids': notificationIds,
        if (deleteAll) 'delete_all': true,
      };

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}$_basePath/delete_notification.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'affected': data['affected'] ?? 0,
        'no_leidas': data['no_leidas'] ?? 0,
      };
    } catch (e) {
      debugPrint('Error deleteNotification: $e');
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  /// Obtiene la configuración de notificaciones del usuario
  static Future<NotificationSettings?> getSettings({required int userId}) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}$_basePath/get_settings.php')
          .replace(queryParameters: {'usuario_id': userId.toString()});

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (data['success'] == true && data['settings'] != null) {
        return NotificationSettings.fromJson(data['settings']);
      }

      return null;
    } catch (e) {
      debugPrint('Error getSettings: $e');
      return null;
    }
  }

  /// Actualiza la configuración de notificaciones
  static Future<Map<String, dynamic>> updateSettings({
    required int userId,
    required Map<String, dynamic> settings,
  }) async {
    try {
      final body = {
        'usuario_id': userId,
        ...settings,
      };

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}$_basePath/update_settings.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (data['success'] == true && data['settings'] != null) {
        return {
          'success': true,
          'settings': NotificationSettings.fromJson(data['settings']),
        };
      }

      return {
        'success': false,
        'error': data['error'] ?? 'Error al actualizar configuración',
      };
    } catch (e) {
      debugPrint('Error updateSettings: $e');
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }
}
