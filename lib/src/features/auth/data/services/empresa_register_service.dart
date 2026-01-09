import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';

/// Servicio para el registro de empresas de transporte
class EmpresaRegisterService {
  /// Registra una nueva empresa de transporte
  static Future<Map<String, dynamic>> registerEmpresa({
    required String nombreEmpresa,
    String? nit,
    String? razonSocial,
    required String email,
    required String telefono,
    String? telefonoSecundario,
    String? direccion,
    String? municipio,
    String? departamento,
    required String representanteNombre,
    required String representanteApellido, // New required parameter
    String? representanteTelefono,
    String? representanteEmail,
    String? descripcion,
    List<String>? tiposVehiculo,
    required String password,
    required String deviceUuid,
    File? logoFile,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/empresa/register.php');
      
      // Si hay logo, usar multipart
      if (logoFile != null) {
        var request = http.MultipartRequest('POST', uri);
        
        request.fields['action'] = 'register';
        request.fields['nombre_empresa'] = nombreEmpresa;
        request.fields['email'] = email;
        request.fields['telefono'] = telefono;
        request.fields['representante_nombre'] = representanteNombre;
        request.fields['representante_apellido'] = representanteApellido; // Add to fields
        request.fields['password'] = password;
        request.fields['device_uuid'] = deviceUuid;
        
        if (nit != null && nit.isNotEmpty) request.fields['nit'] = nit;
        if (razonSocial != null && razonSocial.isNotEmpty) request.fields['razon_social'] = razonSocial;
        if (telefonoSecundario != null && telefonoSecundario.isNotEmpty) {
          request.fields['telefono_secundario'] = telefonoSecundario;
        }
        if (direccion != null && direccion.isNotEmpty) request.fields['direccion'] = direccion;
        if (municipio != null && municipio.isNotEmpty) request.fields['municipio'] = municipio;
        if (departamento != null && departamento.isNotEmpty) request.fields['departamento'] = departamento;
        if (representanteTelefono != null && representanteTelefono.isNotEmpty) {
          request.fields['representante_telefono'] = representanteTelefono;
        }
        if (representanteEmail != null && representanteEmail.isNotEmpty) {
          request.fields['representante_email'] = representanteEmail;
        }
        if (descripcion != null && descripcion.isNotEmpty) request.fields['descripcion'] = descripcion;
        if (tiposVehiculo != null && tiposVehiculo.isNotEmpty) {
          request.fields['tipos_vehiculo'] = json.encode(tiposVehiculo);
        }
        
        request.files.add(await http.MultipartFile.fromPath('logo', logoFile.path));
        
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        
        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorBody = json.decode(response.body);
          return {
            'success': false,
            'message': errorBody['message'] ?? 'Error del servidor: ${response.statusCode}',
            ...errorBody, // Pass through all other fields like debug_error
          };
        }
      } else {
        // Sin logo, usar JSON
        final Map<String, dynamic> body = {
          'action': 'register',
          'nombre_empresa': nombreEmpresa,
          'email': email,
          'telefono': telefono,
          'representante_nombre': representanteNombre,
          'representante_apellido': representanteApellido,
          'password': password,
          'device_uuid': deviceUuid,
        };
        
        if (nit != null && nit.isNotEmpty) body['nit'] = nit;
        if (razonSocial != null && razonSocial.isNotEmpty) body['razon_social'] = razonSocial;
        if (telefonoSecundario != null && telefonoSecundario.isNotEmpty) {
          body['telefono_secundario'] = telefonoSecundario;
        }
        if (direccion != null && direccion.isNotEmpty) body['direccion'] = direccion;
        if (municipio != null && municipio.isNotEmpty) body['municipio'] = municipio;
        if (departamento != null && departamento.isNotEmpty) body['departamento'] = departamento;
        if (representanteTelefono != null && representanteTelefono.isNotEmpty) {
          body['representante_telefono'] = representanteTelefono;
        }
        if (representanteEmail != null && representanteEmail.isNotEmpty) {
          body['representante_email'] = representanteEmail;
        }
        if (descripcion != null && descripcion.isNotEmpty) body['descripcion'] = descripcion;
        if (tiposVehiculo != null && tiposVehiculo.isNotEmpty) {
          body['tipos_vehiculo'] = tiposVehiculo;
        }
        
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        );
        
        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          try {
            final errorBody = json.decode(response.body);
            return {
              'success': false,
              'message': errorBody['message'] ?? 'Error del servidor: ${response.statusCode}',
              ...errorBody, // Pass through all other fields like debug_error
            };
          } catch (_) {
            return {
              'success': false,
              'message': 'Error del servidor: ${response.statusCode}'
            };
          }
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}'
      };
    }
  }
}
