import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';

class DebtPaymentService {
  static Future<Map<String, dynamic>> getContext({
    required int conductorId,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.conductorServiceUrl}/debt_payment_context.php?conductor_id=$conductorId',
      );

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      });

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

  static Future<Map<String, dynamic>> submitPaymentProof({
    required int conductorId,
    required double monto,
    required File comprobante,
    String? observaciones,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.conductorServiceUrl}/report_debt_payment.php');

      final request = http.MultipartRequest('POST', uri);
      request.fields['conductor_id'] = conductorId.toString();
      request.fields['monto'] = monto.toStringAsFixed(2);
      if ((observaciones ?? '').trim().isNotEmpty) {
        request.fields['observaciones'] = observaciones!.trim();
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'comprobante',
          comprobante.path,
          filename: comprobante.path.split(Platform.pathSeparator).last,
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.body.isNotEmpty) {
        final jsonBody = json.decode(response.body) as Map<String, dynamic>;
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return jsonBody;
        }
        return {
          'success': false,
          'message': jsonBody['message'] ?? 'No se pudo enviar el comprobante',
        };
      }

      return {
        'success': false,
        'message': 'Respuesta vacía del servidor',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error subiendo comprobante: $e',
      };
    }
  }
}
