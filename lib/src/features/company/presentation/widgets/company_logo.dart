import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/global/services/auth/user_service.dart';

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
    final logoUrl = logoKey != null && logoKey!.isNotEmpty
        ? UserService.getR2ImageUrl(logoKey)
        : null;

    if (logoUrl != null) {
      return _buildImageWithFallback(logoUrl);
    }

    return _buildPlaceholder();
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
