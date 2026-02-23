import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';

class CompanyDebtPaymentService {
  static Future<Map<String, dynamic>> getReports({
    required int empresaId,
    required int conductorId,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/company/debt_payment_reports.php?empresa_id=$empresaId&conductor_id=$conductorId&limit=20',
      );

      final response = await http.get(uri, headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      return {
        'success': false,
        'message': 'Error del servidor: ${response.statusCode}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> performAction({
    required int empresaId,
    required int reporteId,
    required String action,
    required int actorUserId,
    String? motivo,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/company/debt_payment_reports.php');
      final payload = {
        'empresa_id': empresaId,
        'reporte_id': reporteId,
        'action': action,
        'actor_user_id': actorUserId,
        if ((motivo ?? '').trim().isNotEmpty) 'motivo': motivo,
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.body.isNotEmpty) {
        final jsonBody = json.decode(response.body) as Map<String, dynamic>;
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return jsonBody;
        }
        return {
          'success': false,
          'message': jsonBody['message'] ?? 'No se pudo ejecutar la acción',
        };
      }

      return {
        'success': false,
        'message': 'Respuesta vacía del servidor',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }
}
