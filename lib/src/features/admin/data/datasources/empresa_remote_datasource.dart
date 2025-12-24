import 'dart:convert';
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
      final body = {
        'action': 'create',
        'admin_id': adminId,
        ...empresaData,
      };

      final response = await client.post(
        Uri.parse('$baseUrl/empresas.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['empresa_id'] as int;
        } else {
          throw ServerException(data['message'] ?? 'Error al crear empresa');
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
  Future<void> updateEmpresa(int id, Map<String, dynamic> empresaData, int adminId) async {
    try {
      final body = {
        'action': 'update',
        'id': id,
        'admin_id': adminId,
        ...empresaData,
      };

      final response = await client.post(
        Uri.parse('$baseUrl/empresas.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

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
        throw ServerException('Error del servidor: ${response.statusCode}');
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
