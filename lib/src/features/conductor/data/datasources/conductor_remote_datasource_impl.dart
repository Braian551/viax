import 'dart:convert';
import 'package:http/http.dart' as http;
import 'conductor_remote_datasource.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/config/app_config.dart';
import '../../../../global/services/auth/user_service.dart';

/// ImplementaciÃ³n concreta del data source remoto
/// 
/// Se comunica con el backend via HTTP/REST.
/// Lanza excepciones que serÃ¡n capturadas por el repositorio.
/// 
/// CONFIGURACIÃ“N PARA MICROSERVICIOS:
/// - Las URLs se gestionan centralizadamente en AppConfig
/// - FÃ¡cil migraciÃ³n a microservicios cambiando solo AppConfig
class ConductorRemoteDataSourceImpl implements ConductorRemoteDataSource {
  final http.Client client;
  
  /// URL base del microservicio de conductores
  /// Centralizada en AppConfig para fÃ¡cil migraciÃ³n
  String get baseUrl => AppConfig.conductorServiceUrl;

  ConductorRemoteDataSourceImpl({http.Client? client})
      : client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>> getProfile(int conductorId) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/get_profile.php?conductor_id=$conductorId'),
        headers: {'Accept': 'application/json'},
      );

      print('[HTTP] GET profile (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['profile'] != null) {
          return data['profile'] as Map<String, dynamic>;
        }
        throw ServerException(data['message'] ?? 'Error desconocido');
      } else if (response.statusCode == 404) {
        throw NotFoundException('Perfil no encontrado');
      } else {
        throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException || e is NotFoundException) rethrow;
      throw NetworkException('Error de conexiÃ³n: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> updateProfile(
    int conductorId,
    Map<String, dynamic> profileData,
  ) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/update_profile.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'conductor_id': conductorId,
          ...profileData,
        }),
      );

      print('[HTTP] POST update_profile (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        }
        throw ServerException(data['message'] ?? 'Error al actualizar');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexiÃ³n: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> updateLicense(
    int conductorId,
    Map<String, dynamic> licenseData,
  ) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/update_license.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'conductor_id': conductorId,
          ...licenseData,
        }),
      );

      print('[HTTP] POST update_license (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        }
        throw ServerException(data['message'] ?? 'Error al actualizar licencia');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexiÃ³n: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> updateVehicle(
    int conductorId,
    Map<String, dynamic> vehicleData,
  ) async {
    try {
      final rawEmpresaId = vehicleData['empresa_id'] ?? await UserService.getCurrentEmpresaId();
      final empresaId = rawEmpresaId is int
          ? rawEmpresaId
          : int.tryParse(rawEmpresaId?.toString() ?? '');

      if (empresaId == null || empresaId <= 0) {
        throw ServerException('Debes seleccionar una empresa de transporte');
      }

      final payload = {
        'conductor_id': conductorId,
        ...vehicleData,
        'empresa_id': empresaId,
      };

      final response = await client.post(
        Uri.parse('$baseUrl/update_vehicle.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      print('[HTTP] POST update_vehicle (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        }
        throw ServerException(data['message'] ?? 'Error al actualizar vehÃ­culo');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexiÃ³n: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> submitForApproval(int conductorId) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/submit_for_approval.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'conductor_id': conductorId}),
      );

      print('[HTTP] POST submit_for_approval (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        }
        throw ServerException(data['message'] ?? 'Error al enviar para aprobaciÃ³n');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexiÃ³n: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getVerificationStatus(int conductorId) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/get_verification_status.php?conductor_id=$conductorId'),
        headers: {'Accept': 'application/json'},
      );

      print('[HTTP] GET verification_status (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        }
        throw ServerException(data['message'] ?? 'Error al obtener estado');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexiÃ³n: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getStatistics(int conductorId) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/get_estadisticas.php?conductor_id=$conductorId'),
        headers: {'Accept': 'application/json'},
      );

      print('[HTTP] GET estadisticas (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['statistics'] as Map<String, dynamic>;
        }
        throw ServerException(data['message'] ?? 'Error al obtener estadÃ­sticas');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexiÃ³n: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getEarnings(int conductorId, String periodo) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/get_ganancias.php?conductor_id=$conductorId&periodo=$periodo'),
        headers: {'Accept': 'application/json'},
      );

      print('[HTTP] GET ganancias (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['earnings'] as Map<String, dynamic>;
        }
        throw ServerException(data['message'] ?? 'Error al obtener ganancias');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexiÃ³n: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getTripHistory(int conductorId) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/get_historial.php?conductor_id=$conductorId'),
        headers: {'Accept': 'application/json'},
      );

      print('[HTTP] GET historial (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['trips'] != null) {
          return List<Map<String, dynamic>>.from(data['trips']);
        }
        throw ServerException(data['message'] ?? 'Error al obtener historial');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexiÃ³n: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveTrips(int conductorId) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/get_viajes_activos.php?conductor_id=$conductorId'),
        headers: {'Accept': 'application/json'},
      );

      print('[HTTP] GET viajes_activos (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['trips'] != null) {
          return List<Map<String, dynamic>>.from(data['trips']);
        }
        throw ServerException(data['message'] ?? 'Error al obtener viajes activos');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexiÃ³n: $e');
    }
  }

  @override
  Future<void> updateAvailability(int conductorId, bool disponible) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/update_availability.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'conductor_id': conductorId,
          'disponible': disponible ? 1 : 0,
        }),
      );

      print('[HTTP] POST update_availability (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return;
        }
        throw ServerException(data['message'] ?? 'Error al actualizar disponibilidad');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexiÃ³n: $e');
    }
  }

  @override
  Future<void> updateLocation(int conductorId, double latitud, double longitud) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/update_location.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'conductor_id': conductorId,
          'latitud': latitud,
          'longitud': longitud,
        }),
      );

      print('[HTTP] POST update_location (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return;
        }
        throw ServerException(data['message'] ?? 'Error al actualizar ubicaciÃ³n');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException('Error de conexiÃ³n: $e');
    }
  }
}

