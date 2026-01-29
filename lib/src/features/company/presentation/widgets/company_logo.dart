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

  String _buildLogoUrl(String key) {
    // If it's a full URL that points to our r2_proxy, we should normalize it
    // to use the current AppConfig.baseUrl (fixing potential path/IP mismatches from backend)
    if (key.contains('r2_proxy.php') && key.contains('key=')) {
      try {
        final uri = Uri.parse(key);
        final extractedKey = uri.queryParameters['key'];
        if (extractedKey != null && extractedKey.isNotEmpty) {
           return '${AppConfig.baseUrl}/r2_proxy.php?key=${Uri.encodeComponent(extractedKey)}';
        }
      } catch (e) {
        debugPrint('Error parsing logo URL: $e');
      }
    }

    // If it's another full URL (e.g. external), return as is
    if (key.startsWith('http')) {
      return key;
    }
    
    // Normal case: it's just the key path
    return '${AppConfig.baseUrl}/r2_proxy.php?key=${Uri.encodeComponent(key)}';
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
