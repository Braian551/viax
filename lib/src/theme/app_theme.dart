import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// Configuración de temas de la aplicación
class AppTheme {
  AppTheme._();

  // ========== TEMA CLARO ==========
  
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    
    // Colores principales
    primaryColor: AppColors.primary,
    primaryColorLight: AppColors.primaryLight,
    primaryColorDark: AppColors.primaryDark,
    
    scaffoldBackgroundColor: AppColors.lightBackground,
    
    // Esquema de colores
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      primaryContainer: AppColors.primaryLight,
      secondary: AppColors.accent,
      secondaryContainer: AppColors.accentLight,
      surface: AppColors.lightSurface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.lightTextPrimary,
      onError: Colors.white,
      brightness: Brightness.light,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(
        color: AppColors.lightTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
    ),

    // Cards
    cardTheme: const CardThemeData(
      color: AppColors.lightCard,
      elevation: 2,
      shadowColor: AppColors.lightShadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),

    // Botones elevados
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: AppColors.primary.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Botones de texto
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Botones outlined
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Input decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.lightTextSecondary),
      hintStyle: const TextStyle(color: AppColors.lightTextHint),
      prefixIconColor: AppColors.lightTextSecondary,
      suffixIconColor: AppColors.lightTextSecondary,
    ),

    // Iconos
    iconTheme: const IconThemeData(
      color: AppColors.lightTextSecondary,
      size: 24,
    ),

    // Dividers
    dividerTheme: const DividerThemeData(
      color: AppColors.lightDivider,
      thickness: 1,
      space: 1,
    ),

    // Bottom navigation bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.lightTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // Text theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.lightTextPrimary),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.lightTextPrimary),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
      titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.lightTextPrimary),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.lightTextPrimary),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.lightTextSecondary),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.lightTextSecondary),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.lightTextSecondary),
    ),
  );

  // ========== TEMA OSCURO ==========
  
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    
    // Colores principales
    primaryColor: AppColors.primary,
    primaryColorLight: AppColors.primaryLight,
    primaryColorDark: AppColors.primaryDark,
    
    scaffoldBackgroundColor: AppColors.darkBackground,
    
    // Esquema de colores
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      primaryContainer: AppColors.primaryDark,
      secondary: AppColors.accent,
      secondaryContainer: AppColors.accentDark,
      surface: AppColors.darkSurface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.darkTextPrimary,
      onError: Colors.white,
      brightness: Brightness.dark,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      titleTextStyle: TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
    ),

    // Cards
    cardTheme: const CardThemeData(
      color: AppColors.darkCard,
      elevation: 4,
      shadowColor: AppColors.darkShadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),

    // Botones elevados
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: AppColors.primary.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Botones de texto
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Botones outlined
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Input decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
      hintStyle: const TextStyle(color: AppColors.darkTextHint),
      prefixIconColor: AppColors.darkTextSecondary,
      suffixIconColor: AppColors.darkTextSecondary,
    ),

    // Iconos
    iconTheme: const IconThemeData(
      color: AppColors.darkTextSecondary,
      size: 24,
    ),

    // Dividers
    dividerTheme: const DividerThemeData(
      color: AppColors.darkDivider,
      thickness: 1,
      space: 1,
    ),

    // Bottom navigation bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.darkTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // Text theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary),
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary),
      titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.darkTextPrimary),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.darkTextPrimary),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.darkTextSecondary),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.darkTextSecondary),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.darkTextSecondary),
    ),
  );
}
