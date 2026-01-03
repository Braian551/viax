// lib/src/core/constants/app_constants.dart
import 'package:viax/src/core/config/app_config.dart';

class AppConstants {
  // ============================================
  // CONFIGURACIÃ“N DE MAPAS (MAPBOX)
  // ============================================
  // La configuraciÃ³n de Mapbox ahora estÃ¡ en EnvConfig
  // Ver: lib/src/core/config/env_config.dart
  
  // UbicaciÃ³n por defecto (BogotÃ¡, Colombia)
  static const double defaultLatitude = 4.6097;
  static const double defaultLongitude = -74.0817;
  static const double defaultZoom = 15.0;
  
  // Estilos de mapa disponibles
  static const String mapStyleStreets = 'streets-v12';
  static const String mapStyleDark = 'dark-v11';
  static const String mapStyleLight = 'light-v11';
  static const String mapStyleOutdoors = 'outdoors-v12';
  static const String mapStyleSatellite = 'satellite-streets-v12';
  
  // ============================================
  // CONFIGURACIÃ“N DE EMAIL
  // ============================================
  // NOTA: email_service.php YA FUE MOVIDO a auth/ microservicio
  // Usar: AppConfig.authServiceUrl + '/email_service.php'
  @Deprecated('Usar AppConfig.authServiceUrl + \'/email_service.php\' en su lugar')
  static String get emailApiUrl => '${AppConfig.authServiceUrl}/email_service.php';
  static const bool useEmailMock = false;
  
  // ============================================
  // CONFIGURACIÓN DE BASE DE DATOS
  // ============================================
  // SECURITY: Direct database connection was REMOVED.
  // All database access MUST go through the backend API.
  // See: lib/src/global/config/api_config.dart for API URLs
  
  // ============================================
  // CONFIGURACIÃ“N DE LA APLICACIÃ“N
  // ============================================
  static const String appName = 'Viax';
  static const String appVersion = '1.0.0';
  static const String baseApiUrl = 'https://api.viax.com'; // TODO: actualizar cuando exista dominio real
  
  // ============================================
  // CONFIGURACIÃ“N DE VALIDACIÃ“N
  // ============================================
  static const int minPasswordLength = 6;
  static const int minPhoneLength = 10;
  static const int verificationCodeLength = 6;
  static const int resendCodeDelaySeconds = 60;
  
  // ============================================
  // CONFIGURACIÃ“N DE RUTAS Y NAVEGACIÃ“N
  // ============================================
  static const String defaultRoutingProfile = 'driving'; // driving, walking, cycling
  static const bool enableTrafficInfo = true;
  static const bool enableRouteOptimization = true;
  static const double trafficCheckRadiusKm = 5.0;
  
  // ============================================
  // CONFIGURACIÃ“N DE NOTIFICACIONES
  // ============================================
  static const bool enableQuotaNotifications = true;
  static const bool showQuotaInUI = true;
}
