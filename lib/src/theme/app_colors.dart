import 'package:flutter/material.dart';

/// Paleta de colores de la aplicación
/// Color principal: Azul (#2196F3)
class AppColors {
  AppColors._();

  // ========== COLORES PRINCIPALES ==========
  
  /// Color primario de la aplicación (Azul)
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryLight = Color(0xFF64B5F6);
  static const Color primaryDark = Color(0xFF1976D2);
  
  /// Variantes de azul para diferentes usos
  static const Color blue50 = Color(0xFFE3F2FD);
  static const Color blue100 = Color(0xFFBBDEFB);
  static const Color blue200 = Color(0xFF90CAF9);
  static const Color blue300 = Color(0xFF64B5F6);
  static const Color blue400 = Color(0xFF42A5F5);
  static const Color blue500 = Color(0xFF2196F3); // Primary
  static const Color blue600 = Color(0xFF1E88E5);
  static const Color blue700 = Color(0xFF1976D2);
  static const Color blue800 = Color(0xFF1565C0);
  static const Color blue900 = Color(0xFF0D47A1);

  // ========== COLORES DE ACENTO ==========
  
  /// Color de acento (Cyan/Azul claro para contraste)
  static const Color accent = Color(0xFF00BCD4);
  static const Color accentLight = Color(0xFF4DD0E1);
  static const Color accentDark = Color(0xFF0097A7);

  // ========== COLORES DE ESTADO ==========
  
  /// Colores para indicar estados
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // ========== COLORES DE FONDO (MODO CLARO) ==========
  
  /// Fondos para modo claro
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFE0E0E0);

  // ========== COLORES DE FONDO (MODO OSCURO) ==========
  
  /// Fondos para modo oscuro
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2C2C2C);
  static const Color darkDivider = Color(0xFF3C3C3C);

  // ========== COLORES DE TEXTO (MODO CLARO) ==========
  
  /// Textos para modo claro
  static const Color lightTextPrimary = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightTextDisabled = Color(0xFFBDBDBD);
  static const Color lightTextHint = Color(0xFF9E9E9E);

  // ========== COLORES DE TEXTO (MODO OSCURO) ==========
  
  /// Textos para modo oscuro
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextDisabled = Color(0xFF6C6C6C);
  static const Color darkTextHint = Color(0xFF808080);

  // ========== GRADIENTES ==========
  
  /// Gradiente principal (Azul)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  /// Gradiente de acento
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentDark],
  );

  /// Gradiente para fondo oscuro
  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBackground, darkSurface],
  );

  // ========== COLORES CON OPACIDAD ==========
  
  /// Overlays y capas
  static Color primaryWithOpacity(double opacity) => primary.withOpacity(opacity);
  static Color blackWithOpacity(double opacity) => Colors.black.withOpacity(opacity);
  static Color whiteWithOpacity(double opacity) => Colors.white.withOpacity(opacity);

  // ========== COLORES DE SOMBRAS ==========
  
  /// Sombras para modo claro
  static const Color lightShadow = Color(0x1F000000);
  
  /// Sombras para modo oscuro
  static const Color darkShadow = Color(0x3F000000);

  // ========== EFECTOS DE BRILLO ==========
  
  /// Para efectos de glow/brillo con el color primario
  static BoxShadow primaryGlow({double opacity = 0.25, double blur = 30, double spread = 8}) {
    return BoxShadow(
      color: primary.withOpacity(opacity),
      blurRadius: blur,
      spreadRadius: spread,
    );
  }

  /// Para efectos de glow/brillo con el color de acento
  static BoxShadow accentGlow({double opacity = 0.25, double blur = 30, double spread = 8}) {
    return BoxShadow(
      color: accent.withOpacity(opacity),
      blurRadius: blur,
      spreadRadius: spread,
    );
  }
}

// --------------------------------------------------
// Helper Color extensions (compatibility fixes)
// --------------------------------------------------
// We provide `withValues({alpha: double})` to match the
// usage across the codebase that expects this helper.
// This simply maps to `withOpacity` but clamps the alpha
// value to the valid 0.0 - 1.0 range.
extension AppColorExtensions on Color {
  Color withValues({required double alpha}) {
    double clamped = alpha;
    if (clamped < 0.0) clamped = 0.0;
    if (clamped > 1.0) clamped = 1.0;
    return withOpacity(clamped);
  }
}
