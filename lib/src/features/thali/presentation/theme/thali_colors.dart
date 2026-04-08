import 'package:flutter/material.dart';

/// Kuromi-inspired color palette for Thali's love module
class ThaliColors {
  ThaliColors._();

  // Primary purples (Kuromi style)
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleDark = Color(0xFF6D28D9);
  static const Color purpleDeep = Color(0xFF4C1D95);
  static const Color purpleLight = Color(0xFFC4B5FD);
  static const Color purpleSoft = Color(0xFFEDE9FE);

  // Kuromi pinks
  static const Color pink = Color(0xFFF9A8D4);
  static const Color pinkSoft = Color(0xFFFCE7F3);
  static const Color pinkAccent = Color(0xFFEC4899);

  // Background
  static const Color bgDark = Color(0xFF1A1025);
  static const Color bgCard = Color(0xFF2D1B4E);
  static const Color bgCardLight = Color(0xFF3D2B5E);

  // Text
  static const Color textPrimary = Color(0xFFF5F3FF);
  static const Color textSecondary = Color(0xFFC4B5FD);
  static const Color textMuted = Color(0xFF9B8EC4);

  // Accents
  static const Color starGold = Color(0xFFFBBF24);
  static const Color heartRed = Color(0xFFEF4444);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1A1025),
      Color(0xFF2D1B4E),
      Color(0xFF1A1025),
    ],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF3D2B5E),
      Color(0xFF2D1B4E),
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
    ],
  );
}
