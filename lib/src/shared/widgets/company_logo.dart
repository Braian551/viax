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
    String finalKey = url;

    // Handle legacy r2_proxy.php URLs by extracting the R2 key
    if (url.contains('r2_proxy.php') && url.contains('key=')) {
      try {
        final uri = Uri.parse(url);
        final extractedKey = uri.queryParameters['key'];
        if (extractedKey != null && extractedKey.isNotEmpty) {
          finalKey = extractedKey;
        }
      } catch (_) {}
    }

    // If already a valid full URL (not legacy localhost), return it
    if (finalKey.startsWith('http') && !finalKey.contains('192.168.') && !finalKey.contains('localhost')) {
      return finalKey;
    }
    
    // If it's a legacy full URL, extract just the path
    if (finalKey.startsWith('http')) {
      final uri = Uri.tryParse(finalKey);
      if (uri != null && uri.path.isNotEmpty) {
        String path = uri.path;
        if (path.startsWith('/viax/backend/')) {
          path = path.substring('/viax/backend/'.length);
        } else if (path.startsWith('/')) {
          path = path.substring(1);
        }
        finalKey = path;
      }
    }
    
    // Remove leading slash if present
    final cleanKey = finalKey.startsWith('/') ? finalKey.substring(1) : finalKey;
    
    // Build URL through r2_proxy.php
    return '${AppConfig.baseUrl}/r2_proxy.php?key=${Uri.encodeComponent(cleanKey)}';
  }
}
