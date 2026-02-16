import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/network_request_executor.dart';
import '../models/notification_model.dart';

/// Servicio para gestionar las notificaciones del usuario
/// Maneja la comunicación con el backend de notificaciones
class NotificationService {
  static const String _basePath = '/notifications';
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();

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

      final result = await _network.getJson(
        url: uri,
        headers: {'Content-Type': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return {
          'success': false,
          'error': result.error?.userMessage ?? 'No pudimos obtener notificaciones.',
          'error_type': result.error?.type.name,
        };
      }

      final data = result.json!;

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

      final result = await _network.getJson(
        url: uri,
        headers: {'Content-Type': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return 0;
      }

      final data = result.json!;
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

      final result = await _network.postJson(
        url: Uri.parse('${AppConfig.baseUrl}$_basePath/mark_as_read.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return {
          'success': false,
          'error': result.error?.userMessage ?? 'No pudimos actualizar tus notificaciones.',
          'error_type': result.error?.type.name,
        };
      }

      final data = result.json!;

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

      final result = await _network.postJson(
        url: Uri.parse('${AppConfig.baseUrl}$_basePath/delete_notification.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return {
          'success': false,
          'error': result.error?.userMessage ?? 'No pudimos eliminar notificaciones.',
          'error_type': result.error?.type.name,
        };
      }

      final data = result.json!;

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

      final result = await _network.getJson(
        url: uri,
        headers: {'Content-Type': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return null;
      }

      final data = result.json!;

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

      final result = await _network.postJson(
        url: Uri.parse('${AppConfig.baseUrl}$_basePath/update_settings.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return {
          'success': false,
          'error': result.error?.userMessage ?? 'No pudimos actualizar la configuración.',
          'error_type': result.error?.type.name,
        };
      }

      final data = result.json!;

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

  /// Registra/actualiza el token push del dispositivo para el usuario.
  static Future<Map<String, dynamic>> registerPushToken({
    required int userId,
    required String token,
    String? plataforma,
    String? deviceId,
    String? deviceName,
  }) async {
    try {
      final body = {
        'usuario_id': userId,
        'token': token,
        if (plataforma != null) 'plataforma': plataforma,
        if (deviceId != null) 'device_id': deviceId,
        if (deviceName != null) 'device_name': deviceName,
      };

      final result = await _network.postJson(
        url: Uri.parse('${AppConfig.baseUrl}$_basePath/register_push_token.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return {
          'success': false,
          'error': result.error?.userMessage ?? 'No pudimos registrar el token push.',
          'error_type': result.error?.type.name,
        };
      }

      return Map<String, dynamic>.from(result.json!);
    } catch (e) {
      debugPrint('Error registerPushToken: $e');
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  /// Desactiva el token push del dispositivo para el usuario.
  static Future<Map<String, dynamic>> unregisterPushToken({
    required int userId,
    required String token,
  }) async {
    try {
      final body = {
        'usuario_id': userId,
        'token': token,
      };

      final result = await _network.postJson(
        url: Uri.parse('${AppConfig.baseUrl}$_basePath/unregister_push_token.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return {
          'success': false,
          'error': result.error?.userMessage ?? 'No pudimos desactivar el token push.',
          'error_type': result.error?.type.name,
        };
      }

      return Map<String, dynamic>.from(result.json!);
    } catch (e) {
      debugPrint('Error unregisterPushToken: $e');
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }
}
