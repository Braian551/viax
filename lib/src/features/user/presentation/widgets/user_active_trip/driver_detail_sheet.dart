import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';
import '../../../../conductor/services/document_upload_service.dart';

class DriverDetailSheet extends StatelessWidget {
  final Map<String, dynamic> conductor;
  final bool isDark;
  final ScrollController? scrollController;

  const DriverDetailSheet({
    super.key,
    required this.conductor,
    required this.isDark,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final conductorNombre = conductor['nombre'] as String? ?? 'Conductor';
    final conductorFoto = conductor['foto'];
    final calificacion = (conductor['calificacion_promedio'] as num?)?.toDouble() ?? 5.0;
    final vehiculo = conductor['vehiculo'] as Map<String, dynamic>?;
    final vehiculoInfo = vehiculo != null
        ? '${vehiculo['marca'] ?? ''} ${vehiculo['modelo'] ?? ''}'.trim()
        : 'Vehículo no especificado';
    final placa = vehiculo?['placa'] as String? ?? '';
    
    // Mock reviews for now as they are not yet in the backend response
    final reviews = [
      {
        'usuario': 'Ana María',
        'fecha': 'Hace 2 días',
        'texto': 'Excelente servicio, muy amable y condujo con precaución.',
        'calificacion': 5.0,
      },
      {
        'usuario': 'Carlos Ruiz',
        'fecha': 'Hace 1 semana',
        'texto': 'El carro estaba muy limpio y llegó rápido.',
        'calificacion': 5.0,
      },
      {
        'usuario': 'Laura T.',
        'fecha': 'Hace 2 semanas',
        'texto': 'Buen viaje, recomendadísimo.',
        'calificacion': 4.8,
      },
    ];

    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Flexible(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              shrinkWrap: true,
              children: [
                const SizedBox(height: 10),
                
                // Foto grande
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 3,
                      ),
                      image: DecorationImage(
                        image: conductorFoto != null
                            ? NetworkImage(DocumentUploadService.getDocumentUrl(conductorFoto))
                            : const AssetImage('assets/images/default_avatar.png') as ImageProvider, // Fallback safe
                        fit: BoxFit.cover,
                        onError: (_, __) {}, // Handle error silently
                      ),
                    ),
                    child: conductorFoto == null
                        ? const Icon(Icons.person, size: 50, color: Colors.grey)
                        : null,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Nombre
                Text(
                  conductorNombre,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Rating badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            calificacion.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Vehículo info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.directions_car_filled_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehiculoInfo,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (placa.isNotEmpty)
                            Text(
                              placa,
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.grey[600],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Reseñas header
                Text(
                  'Reseñas de usuarios',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Lista de reseñas
                ...reviews.map((review) => _buildReviewItem(review, isDark)),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review['usuario'] as String,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                review['fecha'] as String,
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < (review['calificacion'] as double) ? Icons.star_rounded : Icons.star_border_rounded,
                color: Colors.amber,
                size: 16,
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            review['texto'] as String,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey[700],
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
