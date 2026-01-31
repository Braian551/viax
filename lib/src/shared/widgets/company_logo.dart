import 'package:flutter/material.dart';
import 'package:viax/src/core/config/app_config.dart';

class CompanyLogo extends StatelessWidget {
  const CompanyLogo({
    super.key,
    required this.logoUrl,
    this.size = 50.0,
    this.borderRadius = 12.0,
    this.backgroundColor,
    this.iconColor,
  });

  final String? logoUrl;
  final double size;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final validLogo = logoUrl != null && logoUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? (isDark ? const Color(0xFF2C2C2C) : Colors.white),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: validLogo
          ? ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.network(
                _getCorrectUrl(logoUrl!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildDefaultIcon(isDark),
              ),
            )
          : _buildDefaultIcon(isDark),
    );
  }

  Widget _buildDefaultIcon(bool isDark) {
    return Icon(
      Icons.business_rounded,
      color: iconColor ?? (isDark ? Colors.white24 : Colors.grey.shade300),
      size: size * 0.5,
    );
  }

  String _getCorrectUrl(String url) {
    if (url.startsWith('http')) {
      return url;
    }
    return '${AppConfig.baseUrl}/$url';
  }
}
