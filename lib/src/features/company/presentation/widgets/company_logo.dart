import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/core/config/app_config.dart';

class CompanyLogo extends StatelessWidget {
  static final String _sessionCacheBuster = DateTime.now().millisecondsSinceEpoch.toString();

  final String? logoKey;
  final String nombreEmpresa;
  final double size;
  final double fontSize;
  final bool enableCacheBusting;

  const CompanyLogo({
    super.key,
    this.logoKey,
    required this.nombreEmpresa,
    this.size = 48,
    this.fontSize = 18,
    this.enableCacheBusting = true,
  });

  @override
  Widget build(BuildContext context) {
    if (logoKey != null && logoKey!.isNotEmpty) {
      final logoUrl = _buildLogoUrl(logoKey!);
      return _buildImageWithFallback(logoUrl);
    }

    return _buildPlaceholder();
  }

  String _buildLogoUrl(String key) {
    String finalKey = key;

    // Si viene con el formato antiguo de r2_proxy, extraemos la key real
    if (key.contains('r2_proxy.php') && key.contains('key=')) {
      try {
        final uri = Uri.parse(key);
        final extractedKey = uri.queryParameters['key'];
        if (extractedKey != null && extractedKey.isNotEmpty) {
           finalKey = extractedKey;
        }
      } catch (e) {
        debugPrint('Error parsing logo URL: $e');
      }
    }

    // Si ya es una URL válida y no es legacy (localhost/192.168), retornarla
    if (finalKey.startsWith('http') && 
        !finalKey.contains('192.168.') && 
        !finalKey.contains('localhost')) {
      return _appendCacheBuster(finalKey);
    }
    
    // Si es URL legacy, extraer solo el path
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
    
    // Remover slash inicial si existe
    final cleanKey = finalKey.startsWith('/') ? finalKey.substring(1) : finalKey;
    
    // Construir URL a través de r2_proxy.php
    final proxyUrl = '${AppConfig.baseUrl}/r2_proxy.php?key=${Uri.encodeComponent(cleanKey)}';
    return _appendCacheBuster(proxyUrl);
  }

  String _appendCacheBuster(String url) {
    if (!enableCacheBusting) {
      return url;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return url;
    }

    if (uri.queryParameters.containsKey('cb')) {
      return url;
    }

    final params = Map<String, String>.from(uri.queryParameters);
    params['cb'] = _sessionCacheBuster;
    return uri.replace(queryParameters: params).toString();
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
