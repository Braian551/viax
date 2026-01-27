// lib/src/global/services/email_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';

/// Servicio para envío de correos electrónicos
/// 
/// NOTA: email_service.php ahora está en el microservicio de auth
/// URL: AppConfig.authServiceUrl/email_service.php
class EmailService {
  /// URL del servicio de email
  /// Archivo movido a auth/ microservicio
  static String get _apiUrl {
    return '${AppConfig.authServiceUrl}/email_service.php';
  }

  /// Genera un código de verificación de 4 dígitos
  static String generateVerificationCode() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  /// Envía un código de verificación por correo usando el backend PHP
  static Future<bool> sendVerificationCode({
    required String email,
    required String code,
    required String userName,
  }) async {
    try {
      print('Enviando código de verificación a: $email');
      
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'code': code,
          'userName': userName,
        }),
      );

      print('Respuesta del servidor: ${response.statusCode}');
      print('Cuerpo de la respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] == true;
      } else {
        print('Error del servidor: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error enviando correo: $e');
      return false;
    }
  }

  /// Simula el envío de correo para desarrollo (sin API real)
  static Future<bool> sendVerificationCodeMock({
    required String email,
    required String code,
    required String userName,
  }) async {
    // Simular delay de red
    await Future.delayed(const Duration(seconds: 2));
    
    // Para desarrollo, siempre retorna true
    // En producción, reemplaza con tu servicio real de correo
    print('🔧 MODO DESARROLLO - Código de verificación para $email: $code');
    print('📧 En producción, este código se enviaría por email real');
    return true;
  }

  /// Método de conveniencia que usa el servicio real o mock según la configuración
  static Future<bool> sendVerificationCodeWithFallback({
    required String email,
    required String code,
    required String userName,
    bool? useMock, // Si es null, usa mock en desarrollo
  }) async {
    final shouldUseMock = useMock ?? (AppConfig.environment == Environment.development);
    
    if (shouldUseMock) {
      return await sendVerificationCodeMock(
        email: email,
        code: code,
        userName: userName,
      );
    } else {
      return await sendVerificationCode(
        email: email,
        code: code,
        userName: userName,
      );
    }
  }

  /// Envía un código de recuperación de contraseña por correo usando el backend PHP
  static Future<bool> sendPasswordRecoveryCode({
    required String email,
    required String code,
    required String userName,
  }) async {
    try {
      print('Enviando código de recuperación de contraseña a: $email');
      
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'code': code,
          'userName': userName,
          'type': 'password_recovery', // Tipo especial para recuperación
        }),
      );

      print('Respuesta del servidor: ${response.statusCode}');
      print('Cuerpo de la respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] == true;
      } else {
        print('Error del servidor: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error enviando correo de recuperación: $e');
      return false;
    }
  }

  /// Simula el envío de código de recuperación para desarrollo
  static Future<bool> sendPasswordRecoveryCodeMock({
    required String email,
    required String code,
    required String userName,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    print('🔧 MODO DESARROLLO - Código de recuperación para $email: $code');
    print('📧 En producción, este código se enviaría por email real');
    return true;
  }

  /// Método de conveniencia para enviar código de recuperación
  static Future<bool> sendPasswordRecoveryCodeWithFallback({
    required String email,
    required String code,
    required String userName,
    bool? useMock,
  }) async {
    final shouldUseMock = useMock ?? (AppConfig.environment == Environment.development);
    
    if (shouldUseMock) {
      return await sendPasswordRecoveryCodeMock(
        email: email,
        code: code,
        userName: userName,
      );
    } else {
      return await sendPasswordRecoveryCode(
        email: email,
        code: code,
        userName: userName,
      );
    }
  }
}
