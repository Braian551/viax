/// ConfiguraciÃ³n centralizada de la aplicaciÃ³n
/// 
/// Contiene constantes y configuraciones que pueden variar
/// segÃºn el entorno (dev, staging, production).
/// 
/// MIGRACIÃ“N A MICROSERVICIOS:
/// - Estas URLs cambiarÃ­an a endpoints de diferentes servicios
/// - Usa variables de entorno para diferentes ambientes
/// - Considera usar un API Gateway que enrute a los servicios
/// 
/// EJEMPLO CONFIGURACIÃ“N MICROSERVICIOS:
/// ```dart
/// // Desarrollo local
/// static const apiGateway = 'http://localhost:8080';
/// static const conductorServiceUrl = '$apiGateway/conductor-service/v1';
/// static const authServiceUrl = '$apiGateway/auth-service/v1';
/// static const paymentServiceUrl = '$apiGateway/payment-service/v1';
/// 
/// // ProducciÃ³n
/// static const apiGateway = 'https://api.pingo.com';
/// static const conductorServiceUrl = '$apiGateway/conductor/v1';
/// ```
class AppConfig {
  // Ambiente actual - CAMBIAR AQUÃ PARA ALTERNAR ENTRE LOCAL Y PRODUCCIÃ“N
  static const Environment environment = Environment.development;

  // URLs base segÃºn ambiente
  static String get baseUrl {
    switch (environment) {
  case Environment.development:
        // DESARROLLO LOCAL CON LARAGON
        // Para navegador web o depuraciÃ³n desde VS Code: localhost
        // Para emulador Android: 10.0.2.2 (IMPORTANTE: usar esta para emulador)
        // Para dispositivo fÃ­sico: usar IP de tu mÃ¡quina (ej: 192.168.1.X)
        
        // DISPOSITIVO FÍSICO - usa tu IP local:
        return 'http://192.168.18.68/viax/backend';
        
        // EMULADOR ANDROID - descomentar esta línea:
        // return 'http://10.0.2.2/viax/backend';
        
      case Environment.staging:
        return 'https://staging-api.pingo.com';
      case Environment.production:
        // Railway backend URL - PRODUCCIÃ“N
        return 'https://pinggo-backend-production.up.railway.app';
    }
  }

  // ============================================
  // MICROSERVICIOS
  // ============================================
  // Cada servicio tiene su propia URL modular
  // En producciÃ³n con servidores separados, cambiar a:
  //   - authServiceUrl: 'https://auth.pingo.com/v1'
  //   - conductorServiceUrl: 'https://conductors.pingo.com/v1'
  //   - adminServiceUrl: 'https://admin.pingo.com/v1'
  
  /// Microservicio de AutenticaciÃ³n y Usuarios
  /// Endpoints: login, register, profile, email_service, etc.
  static String get authServiceUrl => '$baseUrl/auth';
  
  /// Microservicio de Conductores
  /// Endpoints: profile, license, vehicle, trips, earnings, etc.
  static String get conductorServiceUrl => '$baseUrl/conductor';
  
  /// Microservicio de AdministraciÃ³n
  /// Endpoints: dashboard, user_management, audit_logs, etc.
  static String get adminServiceUrl => '$baseUrl/admin';
  
  /// Microservicio de Viajes (futuro)
  static String get tripServiceUrl => '$baseUrl/viajes';
  
  /// Microservicio de Mapas (futuro)
  static String get mapServiceUrl => '$baseUrl/map';
  
  // Alias para compatibilidad con cÃ³digo legacy
  @Deprecated('Usar authServiceUrl en su lugar')
  static String get userServiceUrl => authServiceUrl;

  // ConfiguraciÃ³n de red
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ConfiguraciÃ³n de cachÃ©
  static const Duration cacheExpiration = Duration(hours: 1);
  static const int maxCacheSize = 50 * 1024 * 1024; // 50MB

  // Feature flags (para habilitar/deshabilitar features)
  static const bool enableOfflineMode = false;
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;

  // ConfiguraciÃ³n de mapas
  static const String mapboxAccessToken = 'YOUR_MAPBOX_TOKEN'; // Desde env
  static const double defaultLatitude = -34.603722;
  static const double defaultLongitude = -58.381592;

  // VersiÃ³n de la app
  static const String appVersion = '1.0.0';
  static const String apiVersion = 'v1';
}

/// EnumeraciÃ³n de ambientes
enum Environment {
  development,
  staging,
  production,
}

/// ConfiguraciÃ³n por feature (para microservicios)
/// 
/// Permite configurar cada mÃ³dulo/servicio independientemente.
/// Preparado para migraciÃ³n a arquitectura de microservicios.
class FeatureConfig {
  // ConfiguraciÃ³n del Microservicio de Usuarios
  static const userServiceConfig = {
    'endpoint': '/auth',
    'version': 'v1',
    'timeout': Duration(seconds: 15),
    'retryAttempts': 3,
    'enableCache': false,
  };

  // ConfiguraciÃ³n del mÃ³dulo Conductor
  static const conductorConfig = {
    'endpoint': '/conductor',
    'version': 'v1',
    'timeout': Duration(seconds: 15),
    'retryAttempts': 3,
  };

  // ConfiguraciÃ³n del mÃ³dulo Auth (alias de userService para retrocompatibilidad)
  static const authConfig = {
    'endpoint': '/auth',
    'version': 'v1',
    'timeout': Duration(seconds: 10),
    'tokenExpiration': Duration(hours: 24),
  };

  // ConfiguraciÃ³n del mÃ³dulo Map
  static const mapConfig = {
    'endpoint': '/map',
    'version': 'v1',
    'timeout': Duration(seconds: 20),
    'cacheEnabled': true,
  };
}
