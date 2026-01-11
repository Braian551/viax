import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:viax/src/theme/app_colors.dart';


class MapLoadingShimmer extends StatelessWidget {
  const MapLoadingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Colores sutiles para fondo de mapa
    // Modo Claro: Un gris/beige muy suave
    // Modo Oscuro: Un gris oscuro similar al mapa nocturno
    final baseColor = isDark 
        ? const Color(0xFF242424) 
        : const Color(0xFFEEEEEE);
        
    final highlightColor = isDark 
        ? const Color(0xFF383838) 
        : const Color(0xFFFAEFE5); // Un tono calido muy sutil para light mode

    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: const Duration(milliseconds: 1500),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: baseColor,
        ),
      ),
    );
  }
}
