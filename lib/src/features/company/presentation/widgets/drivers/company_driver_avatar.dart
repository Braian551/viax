import 'package:flutter/material.dart';
import 'package:viax/src/global/services/auth/user_service.dart';

class CompanyDriverAvatar extends StatelessWidget {
  final String name;
  final String? photoKey;
  final double size;
  final Color color;
  final Color? borderColor;
  final double borderWidth;

  const CompanyDriverAvatar({
    super.key,
    required this.name,
    this.photoKey,
    this.size = 48,
    required this.color,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImageUrl(photoKey);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: borderColor != null && borderWidth > 0
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      child: ClipOval(
        child: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';

    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String? _resolveImageUrl(String? key) {
    if (key == null || key.trim().isEmpty) return null;
    final resolved = UserService.getR2ImageUrl(key.trim());
    if (resolved.trim().isEmpty) return null;
    return resolved;
  }
}
