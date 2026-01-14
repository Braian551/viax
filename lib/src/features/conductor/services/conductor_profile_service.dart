import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/conductor_profile_model.dart';
import '../models/driver_license_model.dart';
import '../models/vehicle_model.dart';
import '../../../core/config/app_config.dart';
import '../../../global/services/auth/user_service.dart';

/// Servicio para gestiÃ³n de perfil de conductor
/// 
/// NOTA: Este servicio es redundante con ConductorRemoteDataSource.
/// Se mantiene por compatibilidad con cÃ³digo legacy.
class ConductorProfileService {
  /// URL base del microservicio de conductores
  static String get baseUrl => AppConfig.conductorServiceUrl;

  /// Obtener perfil completo del conductor
  static Future<ConductorProfileModel?> getProfile(int conductorId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_profile.php?conductor_id=$conductorId'),
        headers: {'Accept': 'application/json'},
      );

      print('Profile response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['profile'] != null) {
          return ConductorProfileModel.fromJson(data['profile']);
        }
      }
      return null;
    } catch (e) {
      print('Error obteniendo perfil del conductor: $e');
      return null;
    }
  }

  /// Actualizar perfil completo
  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_profile.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      print('Update profile response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      print('Error actualizando perfil: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Registrar o actualizar licencia de conducciÃ³n
  static Future<Map<String, dynamic>> updateLicense({
    required int conductorId,
    required DriverLicenseModel license,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_license.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'conductor_id': conductorId,
          ...license.toJson(),
        }),
      );

      print('Update license response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      print('Error actualizando licencia: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Registrar o actualizar vehÃ­culo
  static Future<Map<String, dynamic>> updateVehicle({
    required int conductorId,
    required VehicleModel vehicle,
  }) async {
    try {
      final rawEmpresaId = vehicle.empresaId ?? await UserService.getCurrentEmpresaId();
      final empresaId = rawEmpresaId is int
          ? rawEmpresaId
          : int.tryParse(rawEmpresaId?.toString() ?? '');

      if (empresaId == null || empresaId <= 0) {
        return {
          'success': false,
          'message': 'Debes seleccionar una empresa de transporte'
        };
      }

      final payload = {
        'conductor_id': conductorId,
        ...vehicle.toJson(),
        'empresa_id': empresaId,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/update_vehicle.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      print('Update vehicle response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      print('Error actualizando vehÃ­culo: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Subir foto de documento
  static Future<Map<String, dynamic>> uploadDocument({
    required int conductorId,
    required String documentType,
    required File imageFile,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload_document.php'),
      );

      request.fields['conductor_id'] = conductorId.toString();
      request.fields['document_type'] = documentType;

      request.files.add(
        await http.MultipartFile.fromPath(
          'document',
          imageFile.path,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Upload document response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      print('Error subiendo documento: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Enviar perfil para verificaciÃ³n
  static Future<Map<String, dynamic>> submitForVerification(int conductorId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/submit_verification.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'conductor_id': conductorId,
        }),
      );

      print('Submit verification response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      print('Error enviando para verificaciÃ³n: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Obtener estado de verificaciÃ³n
  static Future<Map<String, dynamic>> getVerificationStatus(int conductorId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_verification_status.php?conductor_id=$conductorId'),
        headers: {'Accept': 'application/json'},
      );

      print('Verification status response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        }
      }
      return {'success': false};
    } catch (e) {
      print('Error obteniendo estado de verificaciÃ³n: $e');
      return {'success': false};
    }
  }

  /// Verificar si el conductor tiene perfil completo
  static Future<bool> hasCompleteProfile(int conductorId) async {
    try {
      final profile = await getProfile(conductorId);
      return profile?.isProfileComplete ?? false;
    } catch (e) {
      print('Error verificando perfil completo: $e');
      return false;
    }
  }

  /// Obtener documentos pendientes
  static Future<List<String>> getPendingDocuments(int conductorId) async {
    try {
      final profile = await getProfile(conductorId);
      return profile?.documentosPendientes ?? [];
    } catch (e) {
      print('Error obteniendo documentos pendientes: $e');
      return [];
    }
  }

  /// Obtener detalles de la empresa vinculada
  static Future<Map<String, dynamic>?> getCompanyDetails(int empresaId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/empresa/profile.php?id=$empresaId'),
        headers: {'Accept': 'application/json'},
      );

      print('Company details response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return Map<String, dynamic>.from(data['data'] ?? data['empresa']);
        }
      }
      return null;
    } catch (e) {
      print('Error obteniendo detalles de empresa: $e');
      return null;
    }
  }
}
