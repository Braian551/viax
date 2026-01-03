class ApiConfig {
  // URL base del servidor - Laragon local
  // Para desarrollo local con Laragon
  // Para dispositivo físico: usar IP de tu PC en la red local
  // Para emulador Android: usar 10.0.2.2
  // Para navegador: usar localhost
  // static const String baseUrl = 'http://192.168.18.68/viax/backend';

  // Para emulador Android, cambiar a:
  static const String baseUrl = 'http://10.0.2.2/viax/backend';
  
  // Para producciÃ³n Railway, cambiar a:
  // static const String baseUrl = 'https://viax-backend-production.up.railway.app';

  // Endpoints principales
  static const String authEndpoint = '$baseUrl/auth';
  static const String userEndpoint = '$baseUrl/user';
  static const String conductorEndpoint = '$baseUrl/conductor';
  static const String adminEndpoint = '$baseUrl/admin';

  // ConfiguraciÃ³n de timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
