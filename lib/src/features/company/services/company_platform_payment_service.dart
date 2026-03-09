import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';

/// Servicio para gestionar pagos de empresa hacia la plataforma (admin).
/// Replica la lógica de DebtPaymentService pero para el flujo empresa→admin.
class CompanyPlatformPaymentService {
  /// Obtiene el contexto de deuda de la empresa con la plataforma.
  /// Incluye: deuda actual, cuenta bancaria del admin, último reporte.
  static Future<Map<String, dynamic>> getDebtContext({
    required int empresaId,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/company/platform_debt_context.php?empresa_id=$empresaId',
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

  /// Envía un comprobante de pago a la plataforma.
  /// Sube el archivo a R2 y crea un reporte pendiente de revisión.
  static Future<Map<String, dynamic>> submitPaymentProof({
    required int empresaId,
    required int userId,
    required double monto,
    required File comprobante,
    String? observaciones,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/company/report_platform_payment.php',
      );

      final request = http.MultipartRequest('POST', uri);
      request.fields['empresa_id'] = empresaId.toString();
      request.fields['user_id'] = userId.toString();
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

  /// Obtiene las facturas de la empresa.
  static Future<Map<String, dynamic>> getFacturas({
    required int empresaId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.adminServiceUrl}/facturas.php?empresa_id=$empresaId&page=$page&limit=$limit',
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
}
