/// Company Remote Data Source
/// Handles HTTP requests to company-related backend endpoints

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/core/error/exceptions.dart';

abstract class CompanyRemoteDataSource {
  Future<List<Map<String, dynamic>>> getDrivers(dynamic empresaId);
  Future<List<Map<String, dynamic>>> getPricing(dynamic empresaId);
  Future<bool> updatePricing(
    dynamic empresaId,
    List<Map<String, dynamic>> precios,
  );
  Future<Map<String, dynamic>> getCompanyDetails(dynamic empresaId);
  Future<Map<String, dynamic>> updateCompanyDetails(
    dynamic empresaId,
    Map<String, dynamic> data, {
    File? logoFile,
  });

  /// Obtener estadísticas del dashboard
  Future<Map<String, dynamic>> getDashboardStats({
    required dynamic empresaId,
    String periodo = 'hoy',
  });

  /// Obtener documentos de conductores de la empresa
  Future<Map<String, dynamic>> getConductoresDocumentos({
    required dynamic empresaId,
    dynamic userId,
    String? estadoVerificacion,
    String? searchQuery,
    int page = 1,
    int perPage = 20,
  });

  /// Procesar solicitud de conductor (aprobar/rechazar)
  Future<bool> procesarSolicitudConductor({
    required dynamic empresaId,
    required int conductorId,
    required String accion,
    required int procesadoPor,
    String? razon,
  });

  Future<Map<String, dynamic>> getReports({
    required dynamic empresaId,
    String periodo = '7d',
  });
  
  Future<Map<String, dynamic>> getCompanySettings(dynamic empresaId);
  Future<Map<String, dynamic>> updateCompanySettings(
    dynamic empresaId,
    Map<String, dynamic> settings,
  );
}

class CompanyRemoteDataSourceImpl implements CompanyRemoteDataSource {
  final http.Client client;

  CompanyRemoteDataSourceImpl({required this.client});

  @override
  Future<Map<String, dynamic>> getCompanyDetails(dynamic empresaId) async {
    try {
      final url = Uri.parse(
        '${AppConfig.baseUrl}/empresa/profile.php?id=$empresaId',
      );
      print('DEBUG: Fetching company profile from $url');
      final response = await client.get(
        url,
        headers: {'Accept': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Si devuelve 'data', úsalo, si no, busca 'empresa' por compatibilidad
          return Map<String, dynamic>.from(data['data'] ?? data['empresa']);
        }
        throw ServerException(
          data['message'] ?? 'Error al obtener detalles de la empresa',
        );
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Error de conexión: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> updateCompanyDetails(
    dynamic empresaId,
    Map<String, dynamic> data, {
    File? logoFile,
  }) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/empresa/profile.php');

      if (logoFile != null) {
        // Use MultipartRequest
        final request = http.MultipartRequest('POST', url);
        
        // Add fields
        data.forEach((key, value) {
          request.fields[key] = value.toString();
        });
        request.fields['empresa_id'] = empresaId.toString();

        // Add file
        final stream = http.ByteStream(logoFile.openRead());
        final length = await logoFile.length();
        final multipartFile = http.MultipartFile(
          'logo',
          stream,
          length,
          filename: logoFile.path.split('/').last,
        );
        request.files.add(multipartFile);

        final streamedResponse = await client.send(request);
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            return Map<String, dynamic>.from(responseData['data']);
          }
          throw ServerException(responseData['message'] ?? 'Error al actualizar perfil');
        }
        throw ServerException('Error del servidor: ${response.statusCode}');

      } else {
        // Use existing JSON Post logic
        final bodyData = Map<String, dynamic>.from(data);
        bodyData['empresa_id'] = empresaId;
        
        final response = await client.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(bodyData),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return Map<String, dynamic>.from(data['data']);
          }
          throw ServerException(data['message'] ?? 'Error al actualizar perfil');
        }
        throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Error de conexión: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getDashboardStats({
    required dynamic empresaId,
    String periodo = 'hoy',
  }) async {
    try {
      final url = Uri.parse(
        '${AppConfig.baseUrl}/company/dashboard_stats.php?empresa_id=$empresaId&periodo=$periodo',
      );
      final response = await client.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Map<String, dynamic>.from(data['data']);
        }
        throw ServerException(
          data['message'] ?? 'Error al obtener estadísticas',
        );
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Error de conexión: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getDrivers(dynamic empresaId) async {
    try {
      final url = Uri.parse(
        '${AppConfig.baseUrl}/company/drivers.php?empresa_id=$empresaId',
      );
      final response = await client.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(
            data['data']['conductores'] ?? [],
          );
        }
        throw ServerException(
          data['message'] ?? 'Error al obtener conductores',
        );
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Error de conexión: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPricing(dynamic empresaId) async {
    try {
      final url = Uri.parse(
        '${AppConfig.baseUrl}/company/pricing.php?empresa_id=$empresaId',
      );
      final response = await client.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        }
        throw ServerException(data['message'] ?? 'Error al obtener tarifas');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Error de conexión: $e');
    }
  }

  @override
  Future<bool> updatePricing(
    dynamic empresaId,
    List<Map<String, dynamic>> precios,
  ) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/company/pricing.php');
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'empresa_id': empresaId, 'precios': precios}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Error de conexión: $e');
    }
  }

  /// Obtener documentos de conductores que aplicaron a la empresa
  @override
  Future<Map<String, dynamic>> getConductoresDocumentos({
    required dynamic empresaId,
    dynamic userId,
    String? estadoVerificacion,
    String? searchQuery,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      var url =
          '${AppConfig.baseUrl}/company/conductores_documentos.php?empresa_id=$empresaId';
      if (userId != null) url += '&user_id=$userId';
      if (estadoVerificacion != null)
        url += '&estado_verificacion=$estadoVerificacion';
      if (searchQuery != null && searchQuery.isNotEmpty)
        url += '&search=${Uri.encodeComponent(searchQuery)}';
      url += '&page=$page&per_page=$perPage';

      final response = await client.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Map<String, dynamic>.from(data['data']);
        }
        throw ServerException(data['message'] ?? 'Error al obtener documentos');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Error de conexión: $e');
    }
  }

  /// Aprobar o rechazar solicitud/documentos de conductor
  @override
  Future<bool> procesarSolicitudConductor({
    required dynamic empresaId,
    required int conductorId,
    required String accion,
    required int procesadoPor,
    String? razon,
  }) async {
    try {
      final url = Uri.parse(
        '${AppConfig.baseUrl}/company/conductores_documentos.php',
      );
      final requestBody = {
        'empresa_id': empresaId,
        'conductor_id': conductorId,
        'accion': accion,
        'procesado_por': procesadoPor,
        if (razon != null) 'razon': razon,
      };
      print('DEBUG: procesarSolicitudConductor sending: $requestBody');

      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Error de conexión: $e');
    }
  }

  /// Obtener reportes avanzados de la empresa
  @override
  Future<Map<String, dynamic>> getReports({
    required dynamic empresaId,
    String periodo = '7d',
  }) async {
    try {
      final url = Uri.parse(
        '${AppConfig.baseUrl}/company/reports.php?action=overview&empresa_id=$empresaId&periodo=$periodo',
      );
      final response = await client.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Map<String, dynamic>.from(data['data']);
        }
        throw ServerException(data['message'] ?? 'Error al obtener reportes');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Error de conexión: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getCompanySettings(dynamic empresaId) async {
    try {
      final url = Uri.parse(
        '${AppConfig.baseUrl}/empresa/settings.php?action=get_settings&empresa_id=$empresaId',
      );
      final response = await client.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Map<String, dynamic>.from(data['data']);
        }
        throw ServerException(data['message'] ?? 'Error al obtener configuración');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Error de conexión: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> updateCompanySettings(
    dynamic empresaId,
    Map<String, dynamic> settings,
  ) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/empresa/settings.php');
      final bodyData = Map<String, dynamic>.from(settings);
      bodyData['empresa_id'] = empresaId;
      bodyData['action'] = 'update_settings';

      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(bodyData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Map<String, dynamic>.from(data['data']);
        }
        throw ServerException(data['message'] ?? 'Error al actualizar configuración');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Error de conexión: $e');
    }
  }
}
