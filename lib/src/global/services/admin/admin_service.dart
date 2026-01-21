import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:viax/src/core/config/app_config.dart';

class AdminService {
  static String get _baseUrl => AppConfig.adminServiceUrl;

  /// Obtiene estadÃ­sticas del dashboard
  static Future<Map<String, dynamic>> getDashboardStats({
    required int adminId,
  }) async {
    try {
      print('AdminService: Obteniendo estadÃ­sticas para admin_id: $adminId');
      
      final uri = Uri.parse('$_baseUrl/dashboard_stats.php').replace(
        queryParameters: {'admin_id': adminId.toString()},
      );
      
      print('AdminService: URL completa: $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Tiempo de espera agotado');
        },
      );

      print('AdminService: Status Code: ${response.statusCode}');
      print('AdminService: Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'message': 'Acceso denegado. Solo administradores pueden acceder.'
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'message': 'Solicitud invÃ¡lida'
        };
      }

      return {
        'success': false,
        'message': 'Error del servidor: ${response.statusCode}'
      };
    } catch (e) {
      print('AdminService Error en getDashboardStats: $e');
      return {
        'success': false,
        'message': 'Error de conexiÃ³n: ${e.toString()}'
      };
    }
  }

  /// Obtiene lista de usuarios con filtros y paginaciÃ³n
  static Future<Map<String, dynamic>> getUsers({
    required int adminId,
    int page = 1,
    int perPage = 20,
    String? search,
    String? tipoUsuario,
    bool? esActivo,
  }) async {
    try {
      // Construir query parameters
      final queryParams = {
        'admin_id': adminId.toString(),
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (tipoUsuario != null) {
        queryParams['tipo_usuario'] = tipoUsuario;
      }

      if (esActivo != null) {
        queryParams['es_activo'] = esActivo ? '1' : '0';
      }

      final uri = Uri.parse('$_baseUrl/user_management.php')
          .replace(queryParameters: queryParams);

      print('AdminService.getUsers - URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout: No se pudo conectar con el servidor');
        },
      );

      print('AdminService.getUsers - Status: ${response.statusCode}');
      print('AdminService.getUsers - Body preview: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'message': 'Acceso denegado. Solo administradores pueden ver usuarios.'
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'message': 'Solicitud invÃ¡lida'
        };
      }

      return {
        'success': false,
        'message': 'Error del servidor: ${response.statusCode}'
      };
    } catch (e, stackTrace) {
      print('AdminService.getUsers - Exception: $e');
      print('AdminService.getUsers - StackTrace: $stackTrace');
      return {
        'success': false,
        'message': 'Error de conexiÃ³n: ${e.toString()}'
      };
    }
  }

  /// Actualiza un usuario
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
      final Map<String, dynamic> requestData = {
        'admin_id': adminId,
        'user_id': userId,
      };

      if (nombre != null) requestData['nombre'] = nombre;
      if (apellido != null) requestData['apellido'] = apellido;
      if (telefono != null) requestData['telefono'] = telefono;
      if (tipoUsuario != null) requestData['tipo_usuario'] = tipoUsuario;
      if (esActivo != null) requestData['es_activo'] = esActivo ? 1 : 0;
      if (esVerificado != null) requestData['es_verificado'] = esVerificado ? 1 : 0;

      final response = await http.put(
        Uri.parse('$_baseUrl/user_management.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }

      return {'success': false, 'message': 'Error al actualizar usuario'};
    } catch (e) {
      print('Error en updateUser: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Desactiva un usuario
  static Future<Map<String, dynamic>> deleteUser({
    required int adminId,
    required int userId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/user_management.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'admin_id': adminId,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }

      return {'success': false, 'message': 'Error al eliminar usuario'};
    } catch (e) {
      print('Error en deleteUser: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Obtiene logs de auditorÃ­a
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
      };

      if (accion != null) queryParams['accion'] = accion;
      if (usuarioId != null) queryParams['usuario_id'] = usuarioId.toString();
      if (fechaDesde != null) queryParams['fecha_desde'] = fechaDesde;
      if (fechaHasta != null) queryParams['fecha_hasta'] = fechaHasta;

      final uri = Uri.parse('$_baseUrl/audit_logs.php')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }

      return {'success': false, 'message': 'Error al obtener logs'};
    } catch (e) {
      print('Error en getAuditLogs: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Obtiene configuraciones de la app
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

      final uri = Uri.parse('$_baseUrl/app_config.php')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }

      return {'success': false, 'message': 'Error al obtener configuraciÃ³n'};
    } catch (e) {
      print('Error en getAppConfig: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Actualiza una configuraciÃ³n de la app
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
      final Map<String, dynamic> requestData = {
        'admin_id': adminId,
        'clave': clave,
        'valor': valor,
      };

      if (tipo != null) requestData['tipo'] = tipo;
      if (categoria != null) requestData['categoria'] = categoria;
      if (descripcion != null) requestData['descripcion'] = descripcion;
      if (esPublica != null) requestData['es_publica'] = esPublica ? '1' : '0';

      final response = await http.put(
        Uri.parse('$_baseUrl/app_config.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }

      return {'success': false, 'message': 'Error al actualizar configuraciÃ³n'};
    } catch (e) {
      print('Error en updateAppConfig: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Obtiene documentos de conductores con todos los campos
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
      };

      if (conductorId != null) queryParams['conductor_id'] = conductorId.toString();
      if (estadoVerificacion != null) queryParams['estado_verificacion'] = estadoVerificacion;

      final uri = Uri.parse('$_baseUrl/get_conductores_documentos.php')
          .replace(queryParameters: queryParams);

      print('AdminService.getConductoresDocumentos - URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout: No se pudo conectar con el servidor');
        },
      );

      print('AdminService.getConductoresDocumentos - Status: ${response.statusCode}');
      print('AdminService.getConductoresDocumentos - Body preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return data;
        } catch (e) {
          print('AdminService.getConductoresDocumentos - JSON Parse Error: $e');
          print('AdminService.getConductoresDocumentos - Full Response Body: ${response.body}');
          return {
            'success': false,
            'message': 'Error al procesar la respuesta del servidor'
          };
        }
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'message': 'Acceso denegado. Solo administradores pueden ver documentos.'
        };
      }

      return {'success': false, 'message': 'Error al obtener documentos'};
    } catch (e) {
      print('Error en getConductoresDocumentos: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Aprobar documentos de conductor
  static Future<Map<String, dynamic>> aprobarConductor({
    required int adminId,
    required int conductorId,
    String? notas,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/aprobar_conductor.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'admin_id': adminId,
          'conductor_id': conductorId,
          'notas': notas,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }

      return {'success': false, 'message': 'Error al aprobar conductor'};
    } catch (e) {
      print('Error en aprobarConductor: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Rechazar documentos de conductor
  static Future<Map<String, dynamic>> rechazarConductor({
    required int adminId,
    required int conductorId,
    required String motivo,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/rechazar_conductor.php');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'admin_id': adminId,
          'conductor_id': conductorId,
          'motivo': motivo,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }

      return {'success': false, 'message': 'Error al rechazar conductor'};
    } catch (e) {
      print('Error en rechazarConductor: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Obtiene el historial de documentos de un conductor
  static Future<Map<String, dynamic>> getDocumentosHistorial({
    required int adminId,
    required int conductorId,
  }) async {
    try {
      final queryParams = {
        'admin_id': adminId.toString(),
        'conductor_id': conductorId.toString(),
      };

      final uri = Uri.parse('$_baseUrl/get_documentos_historial.php')
          .replace(queryParameters: queryParams);

      print('AdminService.getDocumentosHistorial - URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout: No se pudo conectar con el servidor');
        },
      );

      print('AdminService.getDocumentosHistorial - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'message': 'Acceso denegado. Solo administradores pueden ver historial.'
        };
      }

      return {'success': false, 'message': 'Error al obtener historial de documentos'};
    } catch (e) {
      print('Error en getDocumentosHistorial: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
  /// Registrar pago de comisión
  static Future<Map<String, dynamic>> registrarPagoComision({
    required int adminId,
    required int conductorId,
    required double monto,
    String? notas,
    String metodoPago = 'efectivo',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/registrar_pago_comision.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'admin_id': adminId,
          'conductor_id': conductorId,
          'monto': monto,
          'notas': notas,
          'metodo_pago': metodoPago,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }

      return {'success': false, 'message': 'Error al registrar pago'};
    } catch (e) {
      print('Error en registrarPagoComision: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Obtener ganancias de un conductor (reutiliza endpoint de conductor)
  static Future<Map<String, dynamic>> getConductorEarnings({
    required int conductorId,
  }) async {
    try {
      // Reutilizamos el endpoint existente del conductor
      // Nota: asume que la URL base es la misma para conductor y admin, 
      // o que _baseUrl apunta a /backend/admin y necesitamos salir a /backend/conductor
      // Ajustaremos la URL asumiendo que _baseUrl es .../backend/admin
      
      final base = _baseUrl.replaceAll('/admin', '/conductor');
      final uri = Uri.parse('$base/get_ganancias.php').replace(queryParameters: {
        'conductor_id': conductorId.toString(),
      });

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }

      return {'success': false, 'message': 'Error al obtener ganancias'};
    } catch (e) {
      print('Error en getConductorEarnings: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Obtener ganancias de la plataforma (cuánto deben las empresas)
  static Future<Map<String, dynamic>> getPlatformEarnings({
    String periodo = 'mes',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/platform_earnings.php').replace(
        queryParameters: {'periodo': periodo},
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }

      return {'success': false, 'message': 'Error al obtener ganancias de plataforma'};
    } catch (e) {
      print('Error en getPlatformEarnings: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Registrar pago de una empresa a la plataforma
  static Future<Map<String, dynamic>> registrarPagoEmpresa({
    required int empresaId,
    required double monto,
    int? adminId,
    String? notas,
    String metodoPago = 'transferencia',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/registrar_pago_empresa.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'empresa_id': empresaId,
          'monto': monto,
          'admin_id': adminId,
          'notas': notas,
          'metodo_pago': metodoPago,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }

      return {'success': false, 'message': 'Error al registrar pago de empresa'};
    } catch (e) {
      print('Error en registrarPagoEmpresa: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
