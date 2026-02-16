import 'dart:convert';

import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/core/network/network_request_executor.dart';

class AdminService {
  static String get _baseUrl => AppConfig.adminServiceUrl;
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();

  static Map<String, dynamic> _errorResult(
    NetworkRequestResult result, {
    String fallback = 'No se pudo completar la solicitud.',
  }) {
    return {
      'success': false,
      'message': result.error?.userMessage ?? fallback,
      'error_type': result.error?.type.name,
    };
  }

  static Future<Map<String, dynamic>> getDashboardStats({
    required int adminId,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/dashboard_stats.php').replace(
        queryParameters: {'admin_id': adminId.toString()},
      );

      final result = await _network.getJson(
        url: uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        if (result.statusCode == 403) {
          return {
            'success': false,
            'message': 'Acceso denegado. Solo administradores pueden acceder.'
          };
        }
        if (result.statusCode == 400) {
          return {'success': false, 'message': 'Solicitud inválida'};
        }
        return _errorResult(result, fallback: 'Error al obtener estadísticas.');
      }

      return result.json!;
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> getUsers({
    required int adminId,
    int page = 1,
    int perPage = 20,
    String? search,
    String? tipoUsuario,
    bool? esActivo,
  }) async {
    try {
      final queryParams = {
        'admin_id': adminId.toString(),
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (tipoUsuario != null) queryParams['tipo_usuario'] = tipoUsuario;
      if (esActivo != null) queryParams['es_activo'] = esActivo ? '1' : '0';

      final uri = Uri.parse('$_baseUrl/user_management.php').replace(queryParameters: queryParams);

      final result = await _network.getJson(
        url: uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        if (result.statusCode == 403) {
          return {
            'success': false,
            'message': 'Acceso denegado. Solo administradores pueden ver usuarios.'
          };
        }
        if (result.statusCode == 400) {
          return {'success': false, 'message': 'Solicitud inválida'};
        }
        return _errorResult(result, fallback: 'Error al obtener usuarios.');
      }

      return result.json!;
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> updateUser({
    required int adminId,
    required int userId,
    String? nombre,
    String? apellido,
    String? telefono,
    String? tipoUsuario,
    bool? esActivo,
    bool? esVerificado,
  }) async {
    try {
      final requestData = {
        'admin_id': adminId,
        'user_id': userId,
        if (nombre != null) 'nombre': nombre,
        if (apellido != null) 'apellido': apellido,
        if (telefono != null) 'telefono': telefono,
        if (tipoUsuario != null) 'tipo_usuario': tipoUsuario,
        if (esActivo != null) 'es_activo': esActivo ? 1 : 0,
        if (esVerificado != null) 'es_verificado': esVerificado ? 1 : 0,
      };

      final result = await _network.putJson(
        url: Uri.parse('$_baseUrl/user_management.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestData),
        timeout: AppConfig.connectionTimeout,
      );

      if (result.success && result.json != null) return result.json!;
      return _errorResult(result, fallback: 'Error al actualizar usuario');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteUser({
    required int adminId,
    required int userId,
  }) async {
    try {
      final result = await _network.deleteJson(
        url: Uri.parse('$_baseUrl/user_management.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'admin_id': adminId, 'user_id': userId}),
        timeout: AppConfig.connectionTimeout,
      );

      if (result.success && result.json != null) return result.json!;
      return _errorResult(result, fallback: 'Error al eliminar usuario');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getAuditLogs({
    required int adminId,
    int page = 1,
    int perPage = 50,
    String? accion,
    int? usuarioId,
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    try {
      final queryParams = {
        'admin_id': adminId.toString(),
        'page': page.toString(),
        'per_page': perPage.toString(),
        if (accion != null) 'accion': accion,
        if (usuarioId != null) 'usuario_id': usuarioId.toString(),
        if (fechaDesde != null) 'fecha_desde': fechaDesde,
        if (fechaHasta != null) 'fecha_hasta': fechaHasta,
      };

      final uri = Uri.parse('$_baseUrl/audit_logs.php').replace(queryParameters: queryParams);

      final result = await _network.getJson(
        url: uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (result.success && result.json != null) return result.json!;
      return _errorResult(result, fallback: 'Error al obtener logs');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getAppConfig({
    int? adminId,
    bool publicOnly = false,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (publicOnly) {
        queryParams['public'] = '1';
      } else if (adminId != null) {
        queryParams['admin_id'] = adminId.toString();
      }

      final uri = Uri.parse('$_baseUrl/app_config.php').replace(queryParameters: queryParams);

      final result = await _network.getJson(
        url: uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (result.success && result.json != null) return result.json!;
      return _errorResult(result, fallback: 'Error al obtener configuración');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateAppConfig({
    required int adminId,
    required String clave,
    required String valor,
    String? tipo,
    String? categoria,
    String? descripcion,
    bool? esPublica,
  }) async {
    try {
      final requestData = {
        'admin_id': adminId,
        'clave': clave,
        'valor': valor,
        if (tipo != null) 'tipo': tipo,
        if (categoria != null) 'categoria': categoria,
        if (descripcion != null) 'descripcion': descripcion,
        if (esPublica != null) 'es_publica': esPublica ? '1' : '0',
      };

      final result = await _network.putJson(
        url: Uri.parse('$_baseUrl/app_config.php'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(requestData),
        timeout: AppConfig.connectionTimeout,
      );

      if (result.success && result.json != null) return result.json!;
      return _errorResult(result, fallback: 'Error al actualizar configuración');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getConductoresDocumentos({
    required int adminId,
    int? conductorId,
    String? estadoVerificacion,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = {
        'admin_id': adminId.toString(),
        'page': page.toString(),
        'per_page': perPage.toString(),
        if (conductorId != null) 'conductor_id': conductorId.toString(),
        if (estadoVerificacion != null) 'estado_verificacion': estadoVerificacion,
      };

      final uri = Uri.parse('$_baseUrl/get_conductores_documentos.php').replace(queryParameters: queryParams);

      final result = await _network.getJson(
        url: uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        if (result.statusCode == 403) {
          return {
            'success': false,
            'message': 'Acceso denegado. Solo administradores pueden ver documentos.'
          };
        }
        return _errorResult(result, fallback: 'Error al obtener documentos');
      }

      return result.json!;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> aprobarConductor({
    required int adminId,
    required int conductorId,
    String? notas,
  }) async {
    try {
      final result = await _network.postJson(
        url: Uri.parse('$_baseUrl/aprobar_conductor.php'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'admin_id': adminId,
          'conductor_id': conductorId,
          'notas': notas,
        }),
        timeout: AppConfig.connectionTimeout,
      );

      if (result.success && result.json != null) return result.json!;
      return _errorResult(result, fallback: 'Error al aprobar conductor');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> rechazarConductor({
    required int adminId,
    required int conductorId,
    required String motivo,
  }) async {
    try {
      final result = await _network.postJson(
        url: Uri.parse('$_baseUrl/rechazar_conductor.php'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'admin_id': adminId,
          'conductor_id': conductorId,
          'motivo': motivo,
        }),
        timeout: AppConfig.connectionTimeout,
      );

      if (result.success && result.json != null) return result.json!;
      return _errorResult(result, fallback: 'Error al rechazar conductor');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getDocumentosHistorial({
    required int adminId,
    required int conductorId,
  }) async {
    try {
      final queryParams = {
        'admin_id': adminId.toString(),
        'conductor_id': conductorId.toString(),
      };

      final uri = Uri.parse('$_baseUrl/get_documentos_historial.php').replace(queryParameters: queryParams);

      final result = await _network.getJson(
        url: uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        if (result.statusCode == 403) {
          return {
            'success': false,
            'message': 'Acceso denegado. Solo administradores pueden ver historial.'
          };
        }
        return _errorResult(result, fallback: 'Error al obtener historial de documentos');
      }

      return result.json!;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> registrarPagoComision({
    required int adminId,
    required int conductorId,
    required double monto,
    String? notas,
    String metodoPago = 'efectivo',
  }) async {
    try {
      final result = await _network.postJson(
        url: Uri.parse('$_baseUrl/registrar_pago_comision.php'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'admin_id': adminId,
          'conductor_id': conductorId,
          'monto': monto,
          'notas': notas,
          'metodo_pago': metodoPago,
        }),
        timeout: AppConfig.connectionTimeout,
      );

      if (result.success && result.json != null) return result.json!;
      return _errorResult(result, fallback: 'Error al registrar pago');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getConductorEarnings({
    required int conductorId,
  }) async {
    try {
      final base = _baseUrl.replaceAll('/admin', '/conductor');
      final uri = Uri.parse('$base/get_ganancias.php').replace(queryParameters: {
        'conductor_id': conductorId.toString(),
      });

      final result = await _network.getJson(
        url: uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (result.success && result.json != null) return result.json!;
      return _errorResult(result, fallback: 'Error al obtener ganancias');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getPlatformEarnings({
    String periodo = 'mes',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/platform_earnings.php').replace(
        queryParameters: {'periodo': periodo},
      );

      final result = await _network.getJson(
        url: uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (result.success && result.json != null) return result.json!;
      return _errorResult(result, fallback: 'Error al obtener ganancias de plataforma');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> registrarPagoEmpresa({
    required int empresaId,
    required double monto,
    int? adminId,
    String? notas,
    String metodoPago = 'transferencia',
  }) async {
    try {
      final result = await _network.postJson(
        url: Uri.parse('$_baseUrl/registrar_pago_empresa.php'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'empresa_id': empresaId,
          'monto': monto,
          'admin_id': adminId,
          'notas': notas,
          'metodo_pago': metodoPago,
        }),
        timeout: AppConfig.connectionTimeout,
      );

      if (result.success && result.json != null) return result.json!;
      return _errorResult(result, fallback: 'Error al registrar pago de empresa');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
