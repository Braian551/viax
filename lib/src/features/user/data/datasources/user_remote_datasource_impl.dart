import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/error/exceptions.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'user_remote_datasource.dart';

/// ImplementaciÃ³n del Datasource Remoto usando HTTP
/// 
/// RESPONSABILIDADES:
/// - Hacer peticiones HTTP al backend
/// - Parsear respuestas JSON
/// - Convertir errores HTTP en Exceptions del dominio
/// - Manejar timeouts y errores de red
class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final http.Client client;

  UserRemoteDataSourceImpl({http.Client? client})
      : client = client ?? http.Client();

  /// URL base del microservicio de usuarios
  /// 
  /// NOTA: En producciÃ³n con microservicios reales, esto serÃ­a:
  /// - Desarrollo: http://localhost:8001/v1
  /// - Staging: https://staging-api.viax.com/user-service/v1
  /// - ProducciÃ³n: https://api.viax.com/user-service/v1
  /// 
  /// Por ahora apunta al monolito pero la estructura ya estÃ¡ preparada
  String get _baseUrl => '${AppConfig.authServiceUrl}';

  @override
  Future<Map<String, dynamic>> register({
    required String nombre,
    required String apellido,
    required String email,
    required String telefono,
    required String password,
    String? direccion,
    double? latitud,
    double? longitud,
    String? ciudad,
    String? departamento,
    String? pais,
  }) async {
    try {
      final requestData = {
        'name': nombre,
        'lastName': apellido,
        'email': email,
        'phone': telefono,
        'password': password,
        if (direccion != null) 'address': direccion,
        if (latitud != null) 'latitude': latitud,
        if (longitud != null) 'longitude': longitud,
        if (latitud != null) 'lat': latitud, // Backend acepta ambas variantes
        if (longitud != null) 'lng': longitud,
        if (ciudad != null) 'city': ciudad,
        if (departamento != null) 'state': departamento,
        'country': pais ?? 'Colombia',
      };

      final response = await client
          .post(
            Uri.parse('$_baseUrl/register.php'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestData),
          )
          .timeout(AppConfig.connectionTimeout);

      return _processResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client
          .post(
            Uri.parse('$_baseUrl/login.php'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(AppConfig.connectionTimeout);

      return _processResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getProfile({int? userId, String? email}) async {
    try {
      final queryParams = <String, String>{};
      if (userId != null) queryParams['userId'] = userId.toString();
      if (email != null) queryParams['email'] = email;

      final uri = Uri.parse('$_baseUrl/profile.php')
          .replace(queryParameters: queryParams);

      final response = await client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(AppConfig.connectionTimeout);

      return _processResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> updateProfile({
    required int userId,
    String? nombre,
    String? apellido,
    String? telefono,
  }) async {
    try {
      final requestData = {
        'userId': userId,
        if (nombre != null) 'name': nombre,
        if (apellido != null) 'lastName': apellido,
        if (telefono != null) 'phone': telefono,
      };

      final response = await client
          .post(
            Uri.parse('$_baseUrl/profile_update.php'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestData),
          )
          .timeout(AppConfig.connectionTimeout);

      return _processResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> updateLocation({
    required int userId,
    String? direccion,
    double? latitud,
    double? longitud,
    String? ciudad,
    String? departamento,
    String? pais,
  }) async {
    try {
      final requestData = {
        'userId': userId,
        if (direccion != null) 'address': direccion,
        if (latitud != null) 'latitude': latitud,
        if (longitud != null) 'longitude': longitud,
        if (latitud != null) 'lat': latitud,
        if (longitud != null) 'lng': longitud,
        if (ciudad != null) 'city': ciudad,
        if (departamento != null) 'state': departamento,
        if (pais != null) 'country': pais,
      };

      final response = await client
          .post(
            Uri.parse('$_baseUrl/profile_update.php'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestData),
          )
          .timeout(AppConfig.connectionTimeout);

      return _processResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> checkUserExists(String email) async {
    try {
      final response = await client
          .post(
            Uri.parse('$_baseUrl/check_user.php'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(AppConfig.connectionTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return {'exists': false};
    } catch (e) {
      return {'exists': false};
    }
  }

  /// Procesar respuesta HTTP y extraer JSON
  Map<String, dynamic> _processResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Si el backend responde con success: false, lanzar excepciÃ³n
      if (data['success'] == false) {
        throw ServerException(
          data['message'] as String? ?? 'Error del servidor',
        );
      }

      return data;
    } else if (response.statusCode == 404) {
      throw NotFoundException('Recurso no encontrado');
    } else if (response.statusCode == 401) {
      throw AuthException('No autorizado');
    } else if (response.statusCode == 403) {
      throw UnauthorizedException('Acceso denegado');
    } else {
      throw ServerException(
        'Error del servidor: ${response.statusCode}',
      );
    }
  }

  /// Manejar errores y convertirlos en excepciones del dominio
  Never _handleError(dynamic error) {
    if (error is AppException) {
      throw error;
    } else if (error is http.ClientException) {
      throw NetworkException('Error de red: ${error.message}');
    } else if (error.toString().contains('TimeoutException')) {
      throw NetworkException('Tiempo de espera agotado');
    } else {
      throw ServerException('Error inesperado: ${error.toString()}');
    }
  }
}
