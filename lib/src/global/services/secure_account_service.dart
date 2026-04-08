import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';

class SecureAccountService {
  static Future<Map<String, dynamic>> revealAccountNumber({
    required int actorUserId,
    required String resource,
    int? resourceId,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/secure/account_number.php').replace(
      queryParameters: {
        'actor_user_id': actorUserId.toString(),
        'resource': resource,
        if (resourceId != null) 'resource_id': resourceId.toString(),
      },
    );

    final response = await http.get(uri, headers: {'Accept': 'application/json'});
    if (response.body.isEmpty) {
      return {'success': false, 'message': 'Respuesta vacía del servidor'};
    }

    final jsonBody = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonBody;
    }

    return {
      'success': false,
      'message': jsonBody['message']?.toString() ?? 'No se pudo revelar la cuenta',
    };
  }

  static String maskAccount(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '******';
    final suffix = digits.length > 4 ? digits.substring(digits.length - 4) : digits;
    return '******$suffix';
  }
}
