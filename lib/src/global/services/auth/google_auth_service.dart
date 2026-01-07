import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/global/services/auth/user_service.dart';

/// Servicio para autenticación con Google OAuth
/// 
/// Implementa flujo de autenticación nativo con Google Sign-In SDK
/// compatible con Android, iOS y Web.
class GoogleAuthService {
  // Google OAuth Configuration - Web Client ID (para serverClientId en el SDK)
  // Este es el client ID del tipo "Web application" de Google Cloud Console
  // Se usa para obtener el id_token que el backend puede verificar
  static String? _cachedWebClientId;
  
  /// Obtiene el Web Client ID desde el backend o usa el fallback
  static Future<String> _getWebClientId() async {
    if (_cachedWebClientId != null) {
      return _cachedWebClientId!;
    }
    
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.authServiceUrl}/google/client_config.php'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['config'] != null) {
          _cachedWebClientId = data['config']['web_client_id'];
          debugPrint('Web Client ID cargado desde backend');
          return _cachedWebClientId!;
        }
      }
    } catch (e) {
      debugPrint('Error cargando config de Google: $e');
    }
    
    // Fallback hardcodeado (por si el backend no está disponible)
    // Web Client ID del proyecto viax-81a5e
    _cachedWebClientId = '879318355876-ii7g05sqsun2fijeqe9mik186a3fbisb.apps.googleusercontent.com';
    return _cachedWebClientId!;
  }
  
  /// Crea instancia de Google Sign-In con el client ID configurado
  static Future<GoogleSignIn> _getGoogleSignIn() async {
    final webClientId = await _getWebClientId();
    return GoogleSignIn(
      scopes: [
        'email',
        'profile',
        'openid',
      ],
      serverClientId: webClientId,
    );
  }
  
  /// Inicia sesión con Google usando el SDK nativo
  /// Retorna un Map con la información del usuario si es exitoso
  static Future<Map<String, dynamic>> signInWithGoogle({
    String? deviceUuid,
  }) async {
    try {
      // Obtener instancia de Google Sign-In
      final googleSignIn = await _getGoogleSignIn();
      
      // Cerrar sesión previa si existe (para permitir cambiar de cuenta)
      await googleSignIn.signOut();
      
      // Iniciar flujo de Google Sign-In
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // Usuario canceló el login
        return {
          'success': false,
          'message': 'Inicio de sesión cancelado',
          'cancelled': true,
        };
      }
      
      debugPrint('Google Sign-In exitoso: ${googleUser.email}');
      
      // Obtener tokens de autenticación
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;
      
      debugPrint('ID Token obtenido: ${idToken != null ? 'Sí' : 'No'}');
      debugPrint('Access Token obtenido: ${accessToken != null ? 'Sí' : 'No'}');
      
      if (idToken == null && accessToken == null) {
        return {
          'success': false,
          'message': 'No se pudo obtener el token de autenticación',
        };
      }
      
      // Enviar token al backend para verificación y registro/login
      final result = await _sendTokenToBackend(
        idToken: idToken,
        accessToken: accessToken,
        deviceUuid: deviceUuid,
      );
      
      return result;
      
    } catch (e) {
      debugPrint('Error en Google Sign-In: $e');
      return {
        'success': false,
        'message': 'Error al iniciar sesión con Google: $e',
      };
    }
  }
  
  /// Envía el token al backend para verificación
  static Future<Map<String, dynamic>> _sendTokenToBackend({
    String? idToken,
    String? accessToken,
    String? deviceUuid,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      
      if (idToken != null) {
        body['id_token'] = idToken;
      }
      if (accessToken != null) {
        body['access_token'] = accessToken;
      }
      if (deviceUuid != null) {
        body['device_uuid'] = deviceUuid;
      }
      
      final response = await http.post(
        Uri.parse('${AppConfig.authServiceUrl}/google/callback.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );
      
      debugPrint('Backend response: ${response.statusCode}');
      debugPrint('Backend body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final userData = data['data'];
          final user = userData['user'];
          
          // Guardar sesión del usuario
          if (user != null) {
            await UserService.saveSession(user);
          }
          
          return {
            'success': true,
            'message': data['message'] ?? 'Autenticación exitosa',
            'user': user,
            'is_new_user': userData['is_new_user'] ?? false,
            'requires_phone': userData['requires_phone'] ?? user?['requiere_telefono'] ?? false,
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Error en la autenticación',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error enviando token al backend: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }
  
  /// Cierra la sesión de Google
  static Future<void> signOut() async {
    try {
      final googleSignIn = await _getGoogleSignIn();
      await googleSignIn.signOut();
    } catch (e) {
      debugPrint('Error cerrando sesión de Google: $e');
    }
  }
  
  /// Verifica si hay una sesión de Google activa
  static Future<bool> isSignedIn() async {
    final googleSignIn = await _getGoogleSignIn();
    return await googleSignIn.isSignedIn();
  }
  
  /// Actualiza el número de teléfono del usuario
  /// Requerido después del registro con Google si no tiene teléfono
  static Future<Map<String, dynamic>> updatePhone({
    required int userId,
    required String phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.authServiceUrl}/update_phone.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'phone': phone,
        }),
      );
      
      debugPrint('Update phone response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final user = data['data']['user'];
          
          if (user != null) {
            await UserService.saveSession(user);
          }
          
          return {
            'success': true,
            'message': data['message'] ?? 'Teléfono actualizado',
            'user': user,
          };
        }
        
        return {
          'success': false,
          'message': data['message'] ?? 'Error al actualizar teléfono',
        };
      }
      
      return {
        'success': false,
        'message': 'Error del servidor: ${response.statusCode}',
      };
    } catch (e) {
      debugPrint('Error actualizando teléfono: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }
  
  /// Verifica si el usuario actual necesita ingresar su teléfono
  static Future<bool> checkRequiresPhone() async {
    try {
      final session = await UserService.getSavedSession();
      if (session == null) return false;
      
      // Si ya tiene teléfono en la sesión local, no requiere
      if (session['telefono'] != null && 
          session['telefono'].toString().isNotEmpty) {
        return false;
      }
      
      // Verificar en el servidor
      final profile = await UserService.getProfile(
        userId: session['id'] as int?,
        email: session['email'] as String?,
      );
      
      if (profile != null && profile['user'] != null) {
        final user = profile['user'];
        final telefono = user['telefono'];
        return telefono == null || telefono.toString().isEmpty;
      }
      
      return true;
    } catch (e) {
      debugPrint('Error verificando teléfono requerido: $e');
      return false;
    }
  }
}
