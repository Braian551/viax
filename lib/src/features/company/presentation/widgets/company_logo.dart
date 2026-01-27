import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/core/config/app_config.dart';

class CompanyLogo extends StatelessWidget {
  final String? logoKey;
  final String nombreEmpresa;
  final double size;
  final double fontSize;

  const CompanyLogo({
    super.key,
    this.logoKey,
    required this.nombreEmpresa,
    this.size = 48,
    this.fontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (logoKey != null && logoKey!.isNotEmpty) {
      final logoUrl = _buildLogoUrl(logoKey!);
      debugPrint('CompanyLogo: empresa=$nombreEmpresa, key=$logoKey, url=$logoUrl');
      return _buildImageWithFallback(logoUrl);
    }

    return _buildPlaceholder();
  }

  /// Construye la URL correcta para el logo
  /// - Si ya es una URL completa (http/https), la usa directamente
  /// - Si es una ruta de R2 (logos/, empresas/, profile/, imagenes/), usa r2_proxy.php
  /// - Si no, concatena con baseUrl
  String _buildLogoUrl(String key) {
    // Ya es URL completa
    if (key.startsWith('http')) {
      return key;
    }
    
    // Patrones que indican almacenamiento R2
    if (key.startsWith('logos/') || 
        key.startsWith('empresas/') ||
        key.startsWith('profile/') || 
        key.startsWith('imagenes/') ||
        key.startsWith('pdfs/')) {
      return '${AppConfig.baseUrl}/r2_proxy.php?key=$key';
    }
    
    // Para otros casos, intentar primero con r2_proxy
    // ya que la mayoría de assets están en R2
    return '${AppConfig.baseUrl}/r2_proxy.php?key=$key';
  }
  // Re-implementing with ClipOval for better error handling
  Widget _buildImageWithFallback(String url) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderContent();
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: _buildPlaceholderContent(),
    );
  }

  Widget _buildPlaceholderContent() {
    return Center(
      child: Text(
        nombreEmpresa.isNotEmpty ? nombreEmpresa[0].toUpperCase() : 'E',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
