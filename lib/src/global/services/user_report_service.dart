import 'dart:convert';

import '../../core/config/app_config.dart';
import '../../core/network/app_network_exception.dart';
import '../../core/network/network_request_executor.dart';

class UserReportService {
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();
  static String get _baseUrl => AppConfig.baseUrl;

  static String _friendlyError(NetworkRequestResult result, String fallback) {
    return result.error?.userMessage ?? fallback;
  }

  static Future<Map<String, dynamic>> reportUser({
    required int reporterUserId,
    required int reportedUserId,
    int? solicitudId,
    required String motivo,
    String? descripcion,
    String prioridad = 'media',
  }) async {
    final result = await _network.postJson(
      url: Uri.parse('$_baseUrl/user/report_user.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'reporter_user_id': reporterUserId,
        'reported_user_id': reportedUserId,
        if (solicitudId != null) 'solicitud_id': solicitudId,
        'motivo': motivo,
        if (descripcion != null && descripcion.trim().isNotEmpty)
          'descripcion': descripcion.trim(),
        'prioridad': prioridad,
      }),
      timeout: AppConfig.connectionTimeout,
    );

    if (!result.success || result.json == null) {
      throw Exception(
        _friendlyError(result, 'No pudimos enviar el reporte del usuario.'),
      );
    }

    final payload = result.json!;
    if (payload['success'] != true) {
      throw Exception(
        payload['message']?.toString() ??
            'No pudimos enviar el reporte del usuario.',
      );
    }

    return (payload['data'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
  }

  static String friendlyFromError(Object error) {
    return AppNetworkException.fromError(error).userMessage;
  }
}
