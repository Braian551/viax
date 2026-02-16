/// Módulo de tema de la aplicación
/// 
/// Este módulo proporciona:
/// - Definición de colores (app_colors.dart)
/// - Configuración de temas claro y oscuro (app_theme.dart)
/// - Provider para gestión de tema (theme_provider.dart)
/// 
/// Uso:
/// ```dart
/// import 'package:viax/src/theme/theme.dart';
/// 
/// // Acceder a colores
/// AppColors.primary
/// 
/// // Usar el provider
/// final themeProvider = Provider.of<ThemeProvider>(context);
/// themeProvider.toggleTheme();
/// ```

library;

export 'app_colors.dart';
export 'app_theme.dart';
export 'theme_provider.dart';
