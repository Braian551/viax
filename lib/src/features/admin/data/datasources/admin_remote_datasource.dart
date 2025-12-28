import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/admin.dart';

abstract class AdminRemoteDataSource {
  // New User Management Methods
  Future<Map<String, dynamic>> getUsers({
    required int adminId,
    int page = 1,
    int perPage = 20,
    String? search,
    String? tipoUsuario,
    bool? esActivo,
  });

  Future<bool> updateUser({
    required int adminId,
    required int userId,
    String? nombre,
    String? apellido,
    String? telefono,
    String? tipoUsuario,
    bool? esActivo,
    bool? esVerificado,
    int? empresaId,
  });

  Future<bool> deleteUser({
    required int adminId,
    required int userId,
  });

  // Legacy Methods (Required by AdminRepositoryImpl)
  Future<SystemStats> getSystemStats();
  Future<List<Map<String, dynamic>>> getPendingDrivers();
  Future<void> approveDriver(int conductorId);
  Future<void> rejectDriver(int conductorId, String motivo);
  Future<List<Map<String, dynamic>>> getAllUsers(int? page, int? limit);
  Future<void> suspendUser(int userId, String motivo);
  Future<void> activateUser(int userId);
}

class AdminRemoteDataSourceImpl implements AdminRemoteDataSource {
  final http.Client client;

  AdminRemoteDataSourceImpl({required this.client});

  String get _baseUrl => AppConfig.adminServiceUrl;

  // --- New Methods ---

  @override
  Future<Map<String, dynamic>> getUsers({
    required int adminId,
    int page = 1,
    int perPage = 20,
    String? search,
    String? tipoUsuario,
    bool? esActivo,
  }) async {
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

    final response = await client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    print('AdminRemoteDataSource.getUsers URL: $uri');
    print('AdminRemoteDataSource.getUsers Status: ${response.statusCode}');
    print('AdminRemoteDataSource.getUsers Body: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw ServerException('Error al obtener usuarios: ${response.statusCode}');
    }
  }

  @override
  Future<bool> updateUser({
    required int adminId,
    required int userId,
    String? nombre,
    String? apellido,
    String? telefono,
    String? tipoUsuario,
    bool? esActivo,
    bool? esVerificado,
    int? empresaId,
  }) async {
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
    if (empresaId != null) {
      requestData['empresa_id'] = empresaId == -1 ? null : empresaId;
    }

    print('AdminRemoteDataSource.updateUser - Request: ${jsonEncode(requestData)}');

    try {
      final response = await client.put(
        Uri.parse('$_baseUrl/user_management.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      print('AdminRemoteDataSource.updateUser - Status: ${response.statusCode}');
      print('AdminRemoteDataSource.updateUser - Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        throw ServerException('Error al actualizar usuario: ${response.statusCode}');
      }
    } catch (e) {
      print('AdminRemoteDataSource.updateUser - Error: $e');
      rethrow;
    }
  }

  @override
  Future<bool> deleteUser({
    required int adminId,
    required int userId,
  }) async {
    final response = await client.delete(
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
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } else {
      throw ServerException('Error al eliminar usuario: ${response.statusCode}');
    }
  }

  // --- Legacy Methods Implementation ---

  @override
  Future<SystemStats> getSystemStats() async {
    // Implementación simulada o llamada real si existe endpoint
    final uri = Uri.parse('$_baseUrl/dashboard_stats.php').replace(
      queryParameters: {'admin_id': '1'}, // Assuming default admin for now
    );
    final response = await client.get(uri);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Map JSON to SystemStats object - Simplified for compilation
      return SystemStats(
        totalUsuarios: data['total_users'] ?? 0,
        totalConductores: data['active_drivers'] ?? 0,
        conductoresPendientes: data['pending_drivers'] ?? 0, // Assuming field
        viajesHoy: data['trips_today'] ?? 0, // Assuming field
        viajesTotal: data['completed_trips'] ?? 0,
        gananciaHoy: (data['revenue_today'] ?? 0).toDouble(), // Assuming field
        gananciaTotal: (data['total_revenue'] ?? 0).toDouble(),
      );
    } else {
      throw ServerException('Error getting stats');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingDrivers() async {
     // Endpoint hipotético basado en lógica anterior
     return []; 
  }

  @override
  Future<void> approveDriver(int conductorId) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/aprobar_conductor.php'),
      body: jsonEncode({'conductor_id': conductorId}),
    );
    if (response.statusCode != 200) throw ServerException('Error approving driver');
  }

  @override
  Future<void> rejectDriver(int conductorId, String motivo) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/rechazar_conductor.php'),
      body: jsonEncode({'conductor_id': conductorId, 'motivo': motivo}),
    );
    if (response.statusCode != 200) throw ServerException('Error rejecting driver');
  }

  @override
  Future<List<Map<String, dynamic>>> getAllUsers(int? page, int? limit) async {
    // Reusing get users logic but returning list
    final result = await getUsers(adminId: 1, page: page ?? 1, perPage: limit ?? 20);
    return List<Map<String, dynamic>>.from(result['usuarios'] ?? []);
  }

  @override
  Future<void> suspendUser(int userId, String motivo) async {
    await updateUser(adminId: 1, userId: userId, esActivo: false);
  }

  @override
  Future<void> activateUser(int userId) async {
    await updateUser(adminId: 1, userId: userId, esActivo: true);
  }
}
