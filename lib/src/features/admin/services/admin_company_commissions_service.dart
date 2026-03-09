import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';

/// Servicio para gestionar comisiones de empresas desde el panel admin.
/// Maneja: comprobantes de empresa, facturas, configuración bancaria, empresas deudoras.
class AdminCompanyCommissionsService {
  /// Obtiene la lista de empresas deudoras con sus saldos.
  static Future<Map<String, dynamic>> getEmpresasDeudoras() async {
    try {
      final uri = Uri.parse(
        '${AppConfig.adminServiceUrl}/empresas_deudoras.php',
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

  /// Obtiene los reportes de pago de empresas.
  /// Filtros opcionales: empresa_id, estado.
  static Future<Map<String, dynamic>> getPaymentReports({
    int? empresaId,
    String? estado,
    int limit = 25,
  }) async {
    try {
      final params = <String, String>{
        'limit': limit.toString(),
      };
      if (empresaId != null && empresaId > 0) {
        params['empresa_id'] = empresaId.toString();
      }
      if (estado != null && estado.isNotEmpty) {
        params['estado'] = estado;
      }

      final uri = Uri.parse(
        '${AppConfig.adminServiceUrl}/empresa_payment_reports.php',
      ).replace(queryParameters: params);

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

  /// Ejecuta una acción sobre un reporte: approve, reject, confirm_payment.
  static Future<Map<String, dynamic>> performAction({
    required int reporteId,
    required String action,
    required int actorUserId,
    String? motivo,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.adminServiceUrl}/empresa_payment_reports.php',
      );

      final payload = {
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

  /// Obtiene las facturas (con filtros opcionales).
  static Future<Map<String, dynamic>> getFacturas({
    int? empresaId,
    String? tipo,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (empresaId != null && empresaId > 0) {
        params['empresa_id'] = empresaId.toString();
      }
      if (tipo != null && tipo.isNotEmpty) {
        params['tipo'] = tipo;
      }

      final uri = Uri.parse(
        '${AppConfig.adminServiceUrl}/facturas.php',
      ).replace(queryParameters: params);

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

  /// Obtiene la configuración bancaria del administrador.
  static Future<Map<String, dynamic>> getBankConfig({
    required int adminId,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.adminServiceUrl}/bank_config.php?admin_id=$adminId',
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

  /// Actualiza la configuración bancaria del administrador.
  static Future<Map<String, dynamic>> updateBankConfig({
    required int adminId,
    required String bancoNombre,
    required String tipoCuenta,
    required String numeroCuenta,
    required String titularCuenta,
    String? bancoCodigo,
    String? documentoTitular,
    String? referencia,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.adminServiceUrl}/bank_config.php',
      );

      final payload = {
        'admin_id': adminId,
        'banco_nombre': bancoNombre,
        'tipo_cuenta': tipoCuenta,
        'numero_cuenta': numeroCuenta,
        'titular_cuenta': titularCuenta,
        if (bancoCodigo != null) 'banco_codigo': bancoCodigo,
        if (documentoTitular != null) 'documento_titular': documentoTitular,
        if (referencia != null) 'referencia_transferencia': referencia,
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
          'message': jsonBody['message'] ?? 'Error al guardar configuración',
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

  /// Registra pago manual de empresa (admin registra directamente).
  static Future<Map<String, dynamic>> registrarPagoEmpresa({
    required int empresaId,
    required double monto,
    required int adminId,
    String? notas,
    String metodoPago = 'transferencia',
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.adminServiceUrl}/registrar_pago_empresa.php',
      );

      final payload = {
        'empresa_id': empresaId,
        'monto': monto,
        'admin_id': adminId,
        'metodo_pago': metodoPago,
        if (notas != null) 'notas': notas,
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
        return json.decode(response.body) as Map<String, dynamic>;
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
