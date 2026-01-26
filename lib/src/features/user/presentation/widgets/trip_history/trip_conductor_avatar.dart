import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';
import '../../../../conductor/services/document_upload_service.dart';

/// Widget reutilizable para mostrar el avatar del conductor
/// Maneja automáticamente la lógica de URLs de R2 y Google
class TripConductorAvatar extends StatelessWidget {
  final String? photoUrl;
  final String conductorName;
  final double radius;
  final double? size;

  const TripConductorAvatar({
    super.key,
    required this.photoUrl,
    required this.conductorName,
    this.radius = 20,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final actualSize = size ?? radius * 2;
    
    // Si no hay foto, mostrar icono por defecto
    if (photoUrl == null || photoUrl!.isEmpty) {
      return _buildPlaceholder(actualSize);
    }

    return Container(
      width: actualSize,
      height: actualSize,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        image: DecorationImage(
          image: NetworkImage(
            DocumentUploadService.getDocumentUrl(photoUrl!),
          ),
          fit: BoxFit.cover,
          onError: (_, __) {
            // Error silencioso, se mostrará el placeholder por el color de fondo
            // o podemos renderizar un hijo si falla.
            // DecorationImage no tiene un builder para error, así que usamos un hijo.
          },
        ),
      ),
      // Child para manejar error de carga visualmente si es necesario, 
      // aunque con DecorationImage y color de fondo suele ser suficiente.
      // Sin embargo, para ser más robustos usamos ClipOval + Image.network
      child: ClipOval(
        child: Image.network(
          DocumentUploadService.getDocumentUrl(photoUrl!),
          fit: BoxFit.cover,
          width: actualSize,
          height: actualSize,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder(actualSize);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: AppColors.primary.withValues(alpha: 0.1),
              width: actualSize,
              height: actualSize,
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_rounded,
        color: AppColors.primary,
        size: size * 0.6, // Escalar icono relativo al tamaño
      ),
    );
  }
}
