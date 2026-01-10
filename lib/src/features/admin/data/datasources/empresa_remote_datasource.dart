import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/core/error/exceptions.dart';
import '../models/empresa_transporte_model.dart';

/// Datasource remoto para operaciones de empresas de transporte
abstract class EmpresaRemoteDataSource {
  /// Obtiene lista de empresas con filtros opcionales
  Future<List<EmpresaTransporteModel>> getEmpresas({
    String? estado,
    String? municipio,
    String? search,
    int page = 1,
    int limit = 50,
  });

  /// Obtiene una empresa por su ID
  Future<EmpresaTransporteModel> getEmpresaById(int id);

  /// Crea una nueva empresa
  Future<int> createEmpresa(Map<String, dynamic> empresaData, int adminId);

  /// Actualiza una empresa existente
  Future<void> updateEmpresa(int id, Map<String, dynamic> empresaData, int adminId);

  /// Elimina una empresa (soft delete)
  Future<void> deleteEmpresa(int id, int adminId);

  /// Cambia el estado de una empresa
  Future<void> toggleEmpresaStatus(int id, String estado, int adminId);

  /// Aprueba una empresa pendiente
  Future<void> approveEmpresa(int id, int adminId);

  /// Rechaza una empresa pendiente
  Future<void> rejectEmpresa(int id, int adminId, String motivo);

  /// Obtiene estadísticas de empresas
  Future<EmpresaStatsModel> getEmpresaStats();
}

/// Implementación del datasource de empresas
class EmpresaRemoteDataSourceImpl implements EmpresaRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  EmpresaRemoteDataSourceImpl({
    required this.client,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? AppConfig.adminServiceUrl;

  @override
  Future<List<EmpresaTransporteModel>> getEmpresas({
    String? estado,
    String? municipio,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'action': 'list',
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (estado != null) queryParams['estado'] = estado;
      if (municipio != null) queryParams['municipio'] = municipio;
      if (search != null) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/empresas.php').replace(queryParameters: queryParams);
      
      final response = await client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final empresasList = data['empresas'] as List? ?? [];
          return empresasList
              .map((e) => EmpresaTransporteModel.fromJson(e as Map<String, dynamic>))
              .toList();
        } else {
          throw ServerException(data['message'] ?? 'Error al obtener empresas');
        }
      } else {
        throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexión: ${e.toString()}');
    }
  }

  @override
  Future<EmpresaTransporteModel> getEmpresaById(int id) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/empresas.php?action=get&id=$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['empresa'] != null) {
          return EmpresaTransporteModel.fromJson(data['empresa']);
        } else {
          throw ServerException(data['message'] ?? 'Empresa no encontrada');
        }
      } else if (response.statusCode == 404) {
        throw ServerException('Empresa no encontrada');
      } else {
        throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexión: ${e.toString()}');
    }
  }

  @override
  Future<int> createEmpresa(Map<String, dynamic> empresaData, int adminId) async {
    try {
      final logoFile = empresaData['logo_file'] as File?;
      if (empresaData.containsKey('logo_file')) {
        empresaData.remove('logo_file');
      }

      http.Response response;

      if (logoFile != null) {
        final uri = Uri.parse('$baseUrl/empresas.php');
        var request = http.MultipartRequest('POST', uri);
        
        request.fields['action'] = 'create';
        request.fields['admin_id'] = adminId.toString();
        
        empresaData.forEach((key, value) {
          if (value != null) {
            if (value is List) {
              request.fields[key] = json.encode(value);
            } else {
              request.fields[key] = value.toString();
            }
          }
        });

        request.files.add(await http.MultipartFile.fromPath('logo', logoFile.path));
        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        final body = {
          'action': 'create',
          'admin_id': adminId,
          ...empresaData,
        };

        response = await client.post(
          Uri.parse('$baseUrl/empresas.php'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        );
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['empresa_id'] as int;
        } else {
          throw ServerException(data['message'] ?? 'Error al crear empresa');
        }
      } else {
        String errorMessage = 'Error del servidor: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (_) {}
        throw ServerException(errorMessage);
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexión: ${e.toString()}');
    }
  }

  @override
  Future<void> updateEmpresa(int id, Map<String, dynamic> empresaData, int adminId) async {
    try {
      final logoFile = empresaData['logo_file'] as File?;
      if (empresaData.containsKey('logo_file')) {
        empresaData.remove('logo_file');
      }

      http.Response response;

      if (logoFile != null) {
        final uri = Uri.parse('$baseUrl/empresas.php');
        var request = http.MultipartRequest('POST', uri);
        
        request.fields['action'] = 'update';
        request.fields['id'] = id.toString();
        request.fields['admin_id'] = adminId.toString();
        
        empresaData.forEach((key, value) {
          if (value != null) {
            if (value is List) {
              request.fields[key] = json.encode(value);
            } else {
              request.fields[key] = value.toString();
            }
          }
        });

        request.files.add(await http.MultipartFile.fromPath('logo', logoFile.path));
        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        final body = {
          'action': 'update',
          'id': id,
          'admin_id': adminId,
          ...empresaData,
        };

        response = await client.post(
          Uri.parse('$baseUrl/empresas.php'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        );
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] != true) {
          throw ServerException(data['message'] ?? 'Error al actualizar empresa');
        }
      } else {
        throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexión: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteEmpresa(int id, int adminId) async {
    try {
      final body = {
        'action': 'delete',
        'id': id,
        'admin_id': adminId,
      };

      final response = await client.post(
        Uri.parse('$baseUrl/empresas.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] != true) {
          throw ServerException(data['message'] ?? 'Error al eliminar empresa');
        }
      } else {
        String errorMessage = 'Error del servidor: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (_) {}
        throw ServerException(errorMessage);
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexión: ${e.toString()}');
    }
  }

  @override
  Future<void> toggleEmpresaStatus(int id, String estado, int adminId) async {
    try {
      final body = {
        'action': 'toggle_status',
        'id': id,
        'estado': estado,
        'admin_id': adminId,
      };

      final response = await client.post(
        Uri.parse('$baseUrl/empresas.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] != true) {
          throw ServerException(data['message'] ?? 'Error al cambiar estado');
        }
      } else {
        throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexión: ${e.toString()}');
    }
  }

  @override
  Future<void> approveEmpresa(int id, int adminId) async {
    try {
      final body = {
        'action': 'approve',
        'id': id,
        'admin_id': adminId,
      };

      final response = await client.post(
        Uri.parse('$baseUrl/empresas.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] != true) {
          throw ServerException(data['message'] ?? 'Error al aprobar empresa');
        }
      } else {
        throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexión: ${e.toString()}');
    }
  }

  @override
  Future<void> rejectEmpresa(int id, int adminId, String motivo) async {
    try {
      final body = {
        'action': 'reject',
        'id': id,
        'admin_id': adminId,
        'motivo': motivo,
      };

      final response = await client.post(
        Uri.parse('$baseUrl/empresas.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] != true) {
          throw ServerException(data['message'] ?? 'Error al rechazar empresa');
        }
      } else {
        throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexión: ${e.toString()}');
    }
  }

  @override
  Future<EmpresaStatsModel> getEmpresaStats() async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/empresas.php?action=get_stats'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['stats'] != null) {
          return EmpresaStatsModel.fromJson(data['stats']);
        } else {
          throw ServerException(data['message'] ?? 'Error al obtener estadísticas');
        }
      } else {
        throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexión: ${e.toString()}');
    }
  }
}
