import 'package:viax/src/core/config/app_config.dart';

/// Configuración de API
/// 
/// Usa AppConfig.baseUrl que se configura via variable de entorno:
/// flutter run --dart-define=API_BASE_URL=http://tu-servidor.com
class ApiConfig {
  // URL base - usa la configuración central
  static String get baseUrl => AppConfig.baseUrl;
  
  // Endpoints principales
  static String get authEndpoint => '$baseUrl/auth';
  static String get userEndpoint => '$baseUrl/user';
  static String get conductorEndpoint => '$baseUrl/conductor';
  static String get adminEndpoint => '$baseUrl/admin';

  // Configuración de timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
