import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../theme/app_colors.dart';

import 'package:viax/src/features/conductor/services/document_upload_service.dart';

/// Panel con información del viaje y conductor.
/// Diseño moderno consistente con el estilo de la app.
class TripInfoPanel extends StatelessWidget {
  final String direccionDestino;
  final Map<String, dynamic>? conductor;
  final double distanceKm;
  final int etaMinutes;
  final bool isDark;
  
  /// Precio en tiempo real del tracking (opcional)
  final double? precioActual;
  
  /// Distancia recorrida real del tracking (opcional)
  final double? distanciaRecorrida;
  
  /// Tiempo transcurrido real en segundos del tracking (opcional)
  final int? tiempoTranscurrido;
  
  /// Callback al tocar la info del conductor
  final VoidCallback? onDriverTap;

  const TripInfoPanel({
    super.key,
    required this.direccionDestino,
    this.conductor,
    required this.distanceKm,
    required this.etaMinutes,
    required this.isDark,
    this.precioActual,
    this.distanciaRecorrida,
    this.tiempoTranscurrido,
    this.onDriverTap,
  });
  
  /// Formatea segundos en formato legible
  String _formatearTiempo(int totalSeg) {
    if (totalSeg < 60) {
      return '$totalSeg seg';
    } else if (totalSeg < 3600) {
      final min = totalSeg ~/ 60;
      final seg = totalSeg % 60;
      if (seg == 0) return '$min min';
      return '$min:${seg.toString().padLeft(2, '0')}';
    } else {
      final hours = totalSeg ~/ 3600;
      final mins = (totalSeg % 3600) ~/ 60;
      if (mins == 0) return '${hours}h';
      return '${hours}h ${mins}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final conductorNombre = conductor?['nombre'] as String? ?? 'Tu conductor';
    final vehiculo = conductor?['vehiculo'] as Map<String, dynamic>?;
    final vehiculoInfo = vehiculo != null
        ? '${vehiculo['marca'] ?? ''} ${vehiculo['modelo'] ?? ''}'.trim()
        : null;
    final placa = vehiculo?['placa'] as String?;
    final conductorFoto = conductor?['foto'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Destino ──
          _buildDestination(),

          const SizedBox(height: 16),
          _buildGradientDivider(),
          const SizedBox(height: 16),

          // ── Conductor ──
          _buildDriverRow(
            conductorNombre,
            conductorFoto,
            vehiculoInfo,
            placa,
          ),
          
          // ── Tracking stats ──
          if (precioActual != null && precioActual! > 0) ...[
            const SizedBox(height: 16),
            _buildGradientDivider(),
            const SizedBox(height: 16),
            _buildTrackingStats(),
          ],
        ],
      ),
    );
  }

  // ── Destination Row ─────────────────────────────────────────────────

  Widget _buildDestination() {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withValues(alpha: 0.3),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            direccionDestino,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.grey[900],
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Gradient Divider ────────────────────────────────────────────────

  Widget _buildGradientDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            isDark ? Colors.white24 : Colors.grey[300]!,
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  // ── Driver Row ──────────────────────────────────────────────────────

  Widget _buildDriverRow(
      String nombre, String? foto, String? vehiculoInfo, String? placa) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onDriverTap?.call();
      },
      child: Row(
        children: [
          // Avatar con borde gradiente (estilo consistente)
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.7),
                  AppColors.primaryDark,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(2.5),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              ),
              child: ClipOval(
                child: foto != null
                    ? Image.network(
                        DocumentUploadService.getDocumentUrl(foto),
                        fit: BoxFit.cover,
                        errorBuilder: (context, err, stack) => Icon(
                          Icons.person_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      )
                    : Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Nombre y vehículo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.grey[900],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (vehiculoInfo != null && vehiculoInfo.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    vehiculoInfo,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey[500],
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Placa badge
          if (placa != null && placa.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.grey[300]!,
                  width: 1.5,
                ),
              ),
              child: Text(
                placa,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey[800],
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],

          const SizedBox(width: 4),

          // Chevron
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? Colors.white24 : Colors.grey[300],
            size: 22,
          ),
        ],
      ),
    );
  }

  // ── Tracking Stats ──────────────────────────────────────────────────

  Widget _buildTrackingStats() {
    final distancia = distanciaRecorrida ?? 0.0;
    final tiempo = tiempoTranscurrido ?? 0;
    final precio = precioActual ?? 0.0;
    final tiempoFormateado = _formatearTiempo(tiempo);

    return Row(
      children: [
        // Distancia recorrida
        Expanded(
          child: _buildStatCard(
            icon: Icons.route_rounded,
            value: '${distancia.toStringAsFixed(2)} km',
            label: 'Recorrido',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),

        // Tiempo
        Expanded(
          child: _buildStatCard(
            icon: Icons.timer_rounded,
            value: tiempoFormateado,
            label: 'Tiempo',
            color: AppColors.blue600,
          ),
        ),
        const SizedBox(width: 10),

        // Precio
        Expanded(
          child: _buildStatCard(
            icon: Icons.attach_money_rounded,
            value: '\$${precio.toStringAsFixed(0)}',
            label: 'Precio',
            color: AppColors.success,
            isHighlighted: true,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: isHighlighted
                  ? color
                  : (isDark ? Colors.white : Colors.grey[800]),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.grey[400],
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
