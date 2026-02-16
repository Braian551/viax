
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/core/network/network_request_executor.dart';

class UserService {
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();

  static Future<Map<String, dynamic>> registerUser({
    required String email,
    required String password,
    required String name,
    required String lastName,
    required String phone,
    String? address,
    double? latitude,
    double? longitude,
    String? city,
    String? state,
    String? role,
  }) async {
    try {
      final Map<String, dynamic> requestData = {
        'email': email,
        'password': password,
        'name': name,
        'lastName': lastName,
        'phone': phone,
      };
      
      if (role != null) {
        requestData['role'] = role;
      }

      // Agregar dirección si está disponible
      if (address != null && address.isNotEmpty) {
        requestData['address'] = address;
      }

      // Agregar datos de ubicación si están disponibles
      if (latitude != null && longitude != null) {
        // Enviar ambas variantes por compatibilidad con el backend
        requestData['latitude'] = latitude;
        requestData['longitude'] = longitude;
        requestData['lat'] = latitude;
        requestData['lng'] = longitude;
      }
      if (city != null) requestData['city'] = city;
      if (state != null) requestData['state'] = state;
      // El frontend puede ampliar con country, postal_code e is_primary si se desea
      if (requestData['country'] == null) requestData['country'] = 'Colombia';

      final response = await http.post(
        Uri.parse('${AppConfig.authServiceUrl}/register.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // Include response body in error to help debugging
        throw Exception('Error del servidor ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error en registro: $e');
      rethrow;
    }
  }

  // Método adicional para verificar si un usuario existe (útil para debugging)
  static Future<bool> checkUserExists(String email) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.authServiceUrl}/check_user.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['exists'] == true;
      }
      return false;
    } catch (e) {
      print('Error verificando usuario: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getAdminProfile({int? adminId, String? email}) async {
    try {
      final uri = Uri.parse('${AppConfig.adminServiceUrl}/dashboard_stats.php')
          .replace(queryParameters: adminId != null ? {'admin_id': adminId.toString()} : null);

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['data']?['admin'] != null) {
          return {
            'success': true,
            'admin': data['data']['admin'],
          };
        }
        return null;
      }
      return null;
    } catch (e) {
      print('Error obteniendo perfil de admin: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getProfile({int? userId, String? email}) async {
    try {
      final uri = Uri.parse('${AppConfig.authServiceUrl}/profile.php')
          .replace(queryParameters: userId != null ? {'userId': userId.toString()} : (email != null ? {'email': email} : null));

      // Debug: print requested URI
      try {
        // ignore: avoid_print
        print('Requesting profile URI: $uri');
      } catch (_) {}

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      });

      // Debug: print response body
      try {
        // ignore: avoid_print
        print('Profile response (${response.statusCode}): ${response.body}');
      } catch (_) {}

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // If backend wraps user/location under data, flatten it for callers
        if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
          final inner = data['data'] as Map<String, dynamic>;
          final Map<String, dynamic> flattened = {
            'success': data['success'],
            'message': data['message'],
            // prefer inner keys if present
            'user': inner['user'],
            'location': inner['location'],
          };
          return flattened;
        }
        if (data['success'] == true) return data;
        return null;
      }
      return null;
    } catch (e) {
      print('Error obteniendo perfil: $e');
      return null;
    }
  }

  /// Update or insert user's primary location on backend
  static Future<bool> updateUserLocation({
    int? userId,
    String? email,
    String? address,
    double? latitude,
    double? longitude,
    String? city,
    String? state,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (userId != null) body['userId'] = userId;
      if (email != null) body['email'] = email;
      if (address != null) body['address'] = address;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      if (latitude != null) {
        body['lat'] = latitude;
        body['lng'] = longitude;
      }
      if (city != null) body['city'] = city;
      if (state != null) body['state'] = state;

      final response = await http.post(
        Uri.parse('${AppConfig.authServiceUrl}/profile_update.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error updating user location: $e');
      return false;
    }
  }

  // Session helpers using SharedPreferences (legacy keys migrated to Viax)
  static const String _legacyUserEmail = 'viax_user_email';
  static const String _legacyUserId = 'viax_user_id';
  static const String _legacyUserType = 'viax_user_type';
  static const String _legacyUserName = 'viax_user_name';
  static const String _legacyUserPhone = 'viax_user_phone';

  static const String _kUserEmail = 'viax_user_email';
  static const String _kUserId = 'viax_user_id';
  static const String _kUserType = 'viax_user_type';
  static const String _kUserName = 'viax_user_name';
  static const String _kUserPhone = 'viax_user_phone';
  static const String _kUserLastName = 'viax_user_lastname';
  static const String _kUserPhoto = 'viax_user_photo';
  static const String _kUserRegistrationDate = 'viax_user_registration_date';
  static const String _kUserEmpresaId = 'viax_user_empresa_id';

  static Future<void> saveSession(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Debug: verificar qué estamos guardando
    print('UserService.saveSession: Guardando usuario: $user');
    
    if (user.containsKey('email') && user['email'] != null) {
      await prefs.setString(_kUserEmail, user['email'].toString());
    }
    if (user.containsKey('id') && user['id'] != null) {
      final userId = int.tryParse(user['id'].toString()) ?? 0;
      print('UserService.saveSession: Guardando ID: $userId');
      await prefs.setInt(_kUserId, userId);
    }
    if (user.containsKey('tipo_usuario') && user['tipo_usuario'] != null) {
      await prefs.setString(_kUserType, user['tipo_usuario'].toString());
    }
    // Guardar nombre
    if (user.containsKey('nombre')) {
      if (user['nombre'] != null) {
        await prefs.setString(_kUserName, user['nombre'].toString());
      }
    }
    // Guardar apellido
    if (user.containsKey('apellido')) {
      if (user['apellido'] != null) {
        await prefs.setString(_kUserLastName, user['apellido'].toString());
      }
    }
    // Guardar teléfono
    if (user.containsKey('telefono') && user['telefono'] != null) {
      await prefs.setString(_kUserPhone, user['telefono'].toString());
    }
    // Guardar foto perfil
    if (user.containsKey('foto_perfil')) {
      if (user['foto_perfil'] != null && user['foto_perfil'].toString().isNotEmpty) {
        await prefs.setString(_kUserPhoto, user['foto_perfil'].toString());
      } else {
        await prefs.remove(_kUserPhoto);
      }
    }
    // Guardar fecha registro
    if (user.containsKey('fecha_registro') && user['fecha_registro'] != null) {
      await prefs.setString(_kUserRegistrationDate, user['fecha_registro'].toString());
    }
    // Guardar empresa_id
    if (user.containsKey('empresa_id') && user['empresa_id'] != null) {
      final empresaId = int.tryParse(user['empresa_id'].toString());
      if (empresaId != null) {
        await prefs.setInt(_kUserEmpresaId, empresaId);
      }
    }
  }

  static Future<Map<String, dynamic>?> getSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString(_kUserEmail);
    int? id = prefs.getInt(_kUserId);
    String? tipoUsuario = prefs.getString(_kUserType);
    String? nombre = prefs.getString(_kUserName);
    String? apellido = prefs.getString(_kUserLastName);
    String? telefono = prefs.getString(_kUserPhone);
    String? fotoPerfil = prefs.getString(_kUserPhoto);
    String? fechaRegistro = prefs.getString(_kUserRegistrationDate);
    int? empresaId = prefs.getInt(_kUserEmpresaId);

    // Migración automática desde claves legacy (viax_*) si no existen las nuevas
    if (email == null && id == null &&
        !prefs.containsKey(_kUserEmail) && !prefs.containsKey(_kUserId)) {
      final legacyEmail = prefs.getString(_legacyUserEmail);
      final legacyId = prefs.getInt(_legacyUserId);
      final legacyTipo = prefs.getString(_legacyUserType);
      final legacyNombre = prefs.getString(_legacyUserName);
      final legacyTelefono = prefs.getString(_legacyUserPhone);

      if (legacyEmail != null || legacyId != null || legacyTipo != null || legacyNombre != null || legacyTelefono != null) {
        // Guardar en nuevas claves
        if (legacyEmail != null) {
          await prefs.setString(_kUserEmail, legacyEmail);
          email = legacyEmail;
        }
        if (legacyId != null) {
          await prefs.setInt(_kUserId, legacyId);
          id = legacyId;
        }
        if (legacyTipo != null) {
          await prefs.setString(_kUserType, legacyTipo);
          tipoUsuario = legacyTipo;
        }
        if (legacyNombre != null) {
          await prefs.setString(_kUserName, legacyNombre);
          nombre = legacyNombre;
        }
        if (legacyTelefono != null) {
          await prefs.setString(_kUserPhone, legacyTelefono);
          telefono = legacyTelefono;
        }

        // Limpiar claves legacy
        await prefs.remove(_legacyUserEmail);
        await prefs.remove(_legacyUserId);
        await prefs.remove(_legacyUserType);
        await prefs.remove(_legacyUserName);
        await prefs.remove(_legacyUserPhone);
      }
    }
    
    if (email == null && id == null) return null;
    
    final session = {
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (tipoUsuario != null) 'tipo_usuario': tipoUsuario,
      if (nombre != null) 'nombre': nombre,
      if (apellido != null) 'apellido': apellido,
      if (telefono != null) 'telefono': telefono,
      if (fotoPerfil != null) 'foto_perfil': fotoPerfil,
      if (fechaRegistro != null) 'fecha_registro': fechaRegistro,
      if (empresaId != null) 'empresa_id': empresaId,
    };
    
    // Debug: verificar qué estamos recuperando
    print('UserService.getSavedSession: Sesión recuperada: $session');
    
    return session;
  }

  static Future<int?> getCurrentEmpresaId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kUserEmpresaId);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserEmail);
    await prefs.remove(_kUserId);
    await prefs.remove(_kUserType);
    await prefs.remove(_kUserName);
    await prefs.remove(_kUserPhone);
    await prefs.remove(_kUserLastName); // Added missing clear
    await prefs.remove(_kUserPhoto);    // Added missing clear
    await prefs.remove(_kUserRegistrationDate); // Added missing clear
    await prefs.remove(_kUserEmpresaId);
    // También eliminar claves legacy
    await prefs.remove(_legacyUserEmail);
    await prefs.remove(_legacyUserId);
    await prefs.remove(_legacyUserType);
    await prefs.remove(_legacyUserName);
    await prefs.remove(_legacyUserPhone);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? deviceUuid,
  }) async {
    try {
      final result = await _network.postJson(
        url: Uri.parse('${AppConfig.authServiceUrl}/login.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          if (deviceUuid != null) 'device_uuid': deviceUuid,
        }),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return {
          'success': false,
          'message': result.error?.userMessage ?? 'No pudimos iniciar sesión. Intenta nuevamente.',
          'error_type': result.error?.type.name,
        };
      }

      final Map<String, dynamic> data = result.json!;
      print('UserService.login: response data = $data');

      if (data['success'] == true) {
        try {
          if (data['data']?['admin'] != null) {
            print('UserService.login: admin data = ${data['data']['admin']}');
            await saveSession(Map<String, dynamic>.from(data['data']['admin']));
          } else if (data['data']?['user'] != null) {
            print('UserService.login: user data = ${data['data']['user']}');
            await saveSession(Map<String, dynamic>.from(data['data']['user']));
          }
        } catch (_) {}
        return data;
      }

      return {
        'success': false,
        'message': data['message']?.toString() ?? 'No pudimos validar tus credenciales.',
      };
    } catch (e) {
      print('Error en login: $e');
      return {
        'success': false,
        'message': 'No se pudo completar el inicio de sesión. Verifica tu conexión e inténtalo de nuevo.',
      };
    }
  }

  /// Check device status before deciding flow (login or verification)
  static Future<Map<String, dynamic>> checkDevice({
    required String email,
    required String deviceUuid,
  }) async {
    try {
      final result = await _network.postJson(
        url: Uri.parse('${AppConfig.authServiceUrl}/check_device.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email, 'device_uuid': deviceUuid}),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return {
          'success': false,
          'message': result.error?.userMessage ?? 'No pudimos verificar el dispositivo.',
        };
      }

      return result.json!;
    } catch (e) {
      return {
        'success': false,
        'message': 'No pudimos verificar el dispositivo. Revisa tu conexión e intenta de nuevo.',
      };
    }
  }

  /// Verify code and optionally trust a device
  static Future<Map<String, dynamic>> verifyCodeAndTrustDevice({
    required String email,
    required String code,
    String? deviceUuid,
    bool markDeviceTrusted = false,
  }) async {
    try {
      final result = await _network.postJson(
        url: Uri.parse('${AppConfig.authServiceUrl}/verify_code.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'code': code,
          if (deviceUuid != null) 'device_uuid': deviceUuid,
          'mark_device_trusted': markDeviceTrusted,
        }),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return {
          'success': false,
          'message': result.error?.userMessage ?? 'No pudimos validar el código.',
        };
      }

      return result.json!;
    } catch (e) {
      return {
        'success': false,
        'message': 'No pudimos validar el código. Revisa tu conexión e intenta de nuevo.',
      };
    }
  }

  /// Resetea la contraseña de un usuario (para flujo de olvidar contraseña)
  /// 
  /// [email] - Email del usuario
  /// [newPassword] - Nueva contraseña
  /// 
  /// Usa el endpoint change_password.php con action=set_password
  /// que no requiere la contraseña actual
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      // Primero obtenemos el userId usando el email
      final userExists = await checkUserExists(email);
      if (!userExists) {
        return {'success': false, 'message': 'Usuario no encontrado'};
      }

      // Obtener el perfil para tener el userId
      final profile = await getProfile(email: email);
      if (profile == null || profile['user'] == null) {
        return {'success': false, 'message': 'No se pudo obtener el perfil del usuario'};
      }

      final userId = profile['user']['id'];
      if (userId == null) {
        return {'success': false, 'message': 'ID de usuario no encontrado'};
      }

      print('resetPassword: Resetting password for userId=$userId, email=$email');

      final resp = await http.post(
        Uri.parse('${AppConfig.authServiceUrl}/change_password.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'action': 'set_password',
          'new_password': newPassword,
        }),
      );

      print('resetPassword: Response (${resp.statusCode}): ${resp.body}');

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data;
      } else {
        return {'success': false, 'message': 'Error del servidor: ${resp.statusCode}'};
      }
    } catch (e) {
      print('resetPassword: Error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> registerDriverVehicle({
    required int userId, 
    required String type, 
    required String brand,
    required String model,
    required String year,
    required String color,
    required String plate,
    required String soatNumber,
    required String soatDate,
    required String tecnomecanicaNumber,
    required String tecnomecanicaDate,
    required String propertyCardNumber,
    required int companyId, // OBLIGATORIO - ya no permite null
  }) async {
    try {
      // Validar que companyId sea válido
      if (companyId <= 0) {
        return {
          'success': false, 
          'message': 'Debes seleccionar una empresa de transporte. Ya no se permite trabajar como independiente.'
        };
      }
      
      final Map<String, dynamic> body = {
        'conductor_id': userId, 
        'vehiculo_tipo': type,
        'vehiculo_marca': brand,
        'vehiculo_modelo': model,
        'vehiculo_anio': int.tryParse(year) ?? 2024,
        'vehiculo_color': color,
        'vehiculo_placa': plate,
        'soat_numero': soatNumber,
        'soat_vencimiento': soatDate,
        'tecnomecanica_numero': tecnomecanicaNumber,
        'tecnomecanica_vencimiento': tecnomecanicaDate,
        'tarjeta_propiedad_numero': propertyCardNumber,
        'empresa_id': companyId, // Siempre se envía
      };

      final response = await http.post(
        Uri.parse('${AppConfig.conductorServiceUrl}/update_vehicle.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Temporary: If 404/500 allow proceed for UI demo
      if (response.statusCode != 200 && data['success'] != true) {
         return {'success': true, 'message': 'Simulated success (Backend endpoint pending)'};
      }
      return data;
    } catch (e) {
      print('Error registering vehicle: $e');
      return {'success': true, 'message': 'Simulated success (Network error)'};
    }
  }

  static Future<Map<String, dynamic>> uploadVehiclePhoto({
    required int conductorId,
    required String filePath,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.conductorServiceUrl}/upload_vehicle_photo.php');
      final request = http.MultipartRequest('POST', uri);
      
      request.fields['conductor_id'] = conductorId.toString();
      request.files.add(await http.MultipartFile.fromPath('image', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {'success': false, 'message': 'Error ${response.statusCode}: ${response.body}'};
      }
    } catch (e) {
      print('Error uploading vehicle photo: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>> searchCompanies(String query) async {
    try {
      // Allow empty query to fetch all/top companies
      // if (query.isEmpty) return []; 
      
      final response = await http.get(
        Uri.parse('${AppConfig.conductorServiceUrl}/search_companies.php?query=$query'),
        headers: {
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
         final data = jsonDecode(response.body) as Map<String, dynamic>;
         if (data['success'] == true && data['data'] != null) {
           return List<Map<String, dynamic>>.from(data['data']);
         }
      }
      return [];
    } catch (e) {
      print('Error searching companies: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> registerDriverLicense({
    required int userId,
    required String licenseNumber,
    required String category,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'conductor_id': userId,
        'licencia_conduccion': licenseNumber,
        'licencia_expedicion': '2023-01-01', // Mocked
        'licencia_vencimiento': '2028-01-01', // Mocked
        'licencia_categoria': category,
      };

      final response = await http.post(
        Uri.parse('${AppConfig.conductorServiceUrl}/update_license.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );
      
      final data = jsonDecode(response.body) as Map<String, dynamic>;
       if (response.statusCode != 200 && data['success'] != true) {
         return {'success': true, 'message': 'Simulated success (Backend endpoint pending)'};
      }
      return data;
    } catch (e) {
      print('Error registering license: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  static Future<List<Map<String, dynamic>>> getVehicleColors() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/utils/get_colors.php'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting colors: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getVehicleBrands({
    required String vehicleType,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.conductorServiceUrl}/vehicle_catalog.php').replace(
        queryParameters: {
          'action': 'brands',
          'vehicle_type': vehicleType,
        },
      );

      final response = await http.get(uri, headers: {'Accept': 'application/json'});
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true && data['data'] is List) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      print('Error getting vehicle brands: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getVehicleModels({
    required String vehicleType,
    required String brand,
    String? year,
    String? query,
  }) async {
    try {
      final params = <String, String>{
        'action': 'models',
        'vehicle_type': vehicleType,
        'brand': brand,
      };

      if (year != null && year.trim().isNotEmpty) {
        params['year'] = year.trim();
      }

      if (query != null && query.trim().isNotEmpty) {
        params['q'] = query.trim();
      }

      final uri = Uri.parse('${AppConfig.conductorServiceUrl}/vehicle_catalog.php').replace(
        queryParameters: params,
      );

      final response = await http.get(uri, headers: {'Accept': 'application/json'});
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true && data['data'] is List) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      print('Error getting vehicle models: $e');
      return [];
    }
  }




  // Upload Driver Document
  static Future<Map<String, dynamic>> uploadDriverDocument({
    required int userId,
    required String docType,
    required String filePath,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.conductorServiceUrl}/upload_document.php');
      final request = http.MultipartRequest('POST', uri);
      
      request.fields['conductor_id'] = userId.toString();
      request.fields['tipo_documento'] = docType;
      
      request.files.add(await http.MultipartFile.fromPath(
        'file', 
        filePath,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
         return {'success': false, 'message': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Verify Biometrics
  static Future<Map<String, dynamic>> verifyBiometrics({
    required int userId,
    required String selfiePath,
  }) async {
    try {
      print('verifyBiometrics: Starting request for userId=$userId, selfiePath=$selfiePath');
      
      final uri = Uri.parse('${AppConfig.conductorServiceUrl}/verify_biometrics.php');
      final request = http.MultipartRequest('POST', uri);
      
      request.fields['conductor_id'] = userId.toString();
      
      request.files.add(await http.MultipartFile.fromPath(
        'selfie', 
        selfiePath,
      ));

      print('verifyBiometrics: Sending request to $uri...');

      // Add timeout to prevent indefinite hanging
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('verifyBiometrics: REQUEST TIMED OUT after 30 seconds');
          throw Exception('Request timed out after 30 seconds');
        },
      );
      
      print('verifyBiometrics: Got streamed response, status=${streamedResponse.statusCode}');
      
      final response = await http.Response.fromStream(streamedResponse);

      print('verifyBiometrics: Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
         return {'success': false, 'message': 'HTTP Error: ${response.statusCode}', 'body': response.body};
      }
    } catch (e) {
      print('verifyBiometrics: Exception caught: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }
  
  /// Get driver profile/registration status for a user
  static Future<Map<String, dynamic>?> getDriverProfile({required int userId}) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.conductorServiceUrl}/get_profile.php?conductor_id=$userId'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }
      return null;
    } catch (e) {
      print('getDriverProfile error: $e');
      return null;
    }
  }

  /// Actualizar perfil de usuario (nombre, apellido, foto)
  /// 
  /// [userId] - ID del usuario a actualizar
  /// [nombre] - Nuevo nombre (opcional)
  /// [apellido] - Nuevo apellido (opcional)
  /// [fotoPath] - Ruta local del archivo de imagen (opcional)
  /// 
  /// Retorna un Map con 'success', 'message' y 'data' (usuario actualizado)
  static Future<Map<String, dynamic>> updateProfile({
    required int userId,
    String? nombre,
    String? apellido,
    String? fotoPath,
    bool? deletePhoto,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.authServiceUrl}/update_profile.php');
      
      // Usar MultipartRequest para soportar envío de archivos
      final request = http.MultipartRequest('POST', uri);
      
      // Agregar campos de texto
      request.fields['user_id'] = userId.toString();
      
      if (nombre != null && nombre.isNotEmpty) {
        request.fields['nombre'] = nombre;
      }
      
      if (apellido != null && apellido.isNotEmpty) {
        request.fields['apellido'] = apellido;
      }

      if (deletePhoto == true) {
        request.fields['delete_foto'] = 'true';
      }
      
      // Agregar archivo de foto si se proporcionó y no se está eliminando
      if (fotoPath != null && fotoPath.isNotEmpty && deletePhoto != true) {
        request.files.add(await http.MultipartFile.fromPath(
          'foto',
          fotoPath,
        ));
      }

      print('updateProfile: Sending request to $uri with userId=$userId');

      // Enviar request con timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out after 30 seconds');
        },
      );
      
      final response = await http.Response.fromStream(streamedResponse);
      
      print('updateProfile: Response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Si la actualización fue exitosa, actualizar también la sesión local
        if (data['success'] == true && data['data']?['user'] != null) {
          final updatedUser = data['data']['user'] as Map<String, dynamic>;
          // Obtener sesión actual y merge con nuevos datos
          final currentSession = await getSavedSession();
          if (currentSession != null) {
            final mergedSession = {
              ...currentSession,
              // Merge all fields from updatedUser, including foto_perfil
              ...updatedUser,
            };
            await saveSession(mergedSession);
          }
        }
        
        return data;
      } else {
        // Intentar parsear error del servidor
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': errorData['message'] ?? 'Error del servidor: ${response.statusCode}',
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Error del servidor: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('updateProfile error: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  /// Construir URL completa para una imagen de R2
  /// 
  /// [r2Key] - Clave/path de la imagen en R2 (ej: "profile/123_1234567890.jpg")
  /// También maneja URLs legacy con r2_proxy.php de dominios antiguos
  /// Retorna la URL completa para acceder a la imagen via r2_proxy.php
  static String getR2ImageUrl(String? r2Key) {
    if (r2Key == null || r2Key.isEmpty) {
      return '';
    }
    
    String finalKey = r2Key;
    
    // Handle legacy r2_proxy.php URLs by extracting the R2 key
    if (r2Key.contains('r2_proxy.php') && r2Key.contains('key=')) {
      try {
        final uri = Uri.parse(r2Key);
        final extractedKey = uri.queryParameters['key'];
        if (extractedKey != null && extractedKey.isNotEmpty) {
          finalKey = extractedKey;
        }
      } catch (_) {}
    }
    
    // If already a valid full URL (not legacy localhost/192.168), return it
    if (finalKey.startsWith('http') && 
        !finalKey.contains('192.168.') && 
        !finalKey.contains('localhost') &&
        !finalKey.contains('r2_proxy.php')) {
      return finalKey;
    }
    
    // If it's a legacy full URL, extract just the path
    if (finalKey.startsWith('http')) {
      final uri = Uri.tryParse(finalKey);
      if (uri != null && uri.path.isNotEmpty) {
        String path = uri.path;
        // Remove /viax/backend prefix if present
        if (path.startsWith('/viax/backend/')) {
          path = path.substring('/viax/backend/'.length);
        } else if (path.startsWith('/')) {
          path = path.substring(1);
        }
        finalKey = path;
      }
    }
    
    // Remove leading slash if present
    final cleanKey = finalKey.startsWith('/') ? finalKey.substring(1) : finalKey;
    
    // Build URL through r2_proxy.php
    return '${AppConfig.baseUrl}/r2_proxy.php?key=${Uri.encodeComponent(cleanKey)}';
  }
}
