import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// Card con resumen del viaje completado.
/// 
/// Muestra origen, destino, distancia, duración y precio.
/// Reutilizable para conductor y cliente.
class TripSummaryCard extends StatelessWidget {
  final String origen;
  final String destino;
  final double distanciaKm;
  final int duracionMinutos;
  final double precio;
  final String? metodoPago;
  final bool mostrarPrecio;
  final bool isDark;

  const TripSummaryCard({
    super.key,
    required this.origen,
    required this.destino,
    required this.distanciaKm,
    required this.duracionMinutos,
    required this.precio,
    this.metodoPago,
    this.mostrarPrecio = true,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Resumen del viaje',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Ruta (origen -> destino)
          _buildRouteSection(),
          
          const SizedBox(height: 16),
          
          // Stats row
          Row(
            children: [
              Expanded(child: _buildStatItem(
                Icons.route_rounded,
                '${distanciaKm.toStringAsFixed(1)} km',
                'Distancia',
              )),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.white12 : Colors.grey[300],
              ),
              Expanded(child: _buildStatItem(
                Icons.schedule_rounded,
                '$duracionMinutos min',
                'Duración',
              )),
              if (mostrarPrecio) ...[
                Container(
                  width: 1,
                  height: 40,
                  color: isDark ? Colors.white12 : Colors.grey[300],
                ),
                Expanded(child: _buildStatItem(
                  Icons.attach_money_rounded,
                  '\$${precio.toStringAsFixed(0)}',
                  'Total',
                  highlight: true,
                )),
              ],
            ],
          ),
          
          // Método de pago
          if (metodoPago != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getPaymentIcon(metodoPago!),
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    metodoPago!,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Línea de ruta
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 30,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        // Direcciones
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                origen,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey[800],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              Text(
                destino,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey[800],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, {bool highlight = false}) {
    return Column(
      children: [
        Icon(
          icon,
          color: highlight ? AppColors.success : (isDark ? Colors.white54 : Colors.grey[500]),
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: highlight 
                ? AppColors.success 
                : (isDark ? Colors.white : Colors.grey[800]),
            fontWeight: FontWeight.bold,
            fontSize: highlight ? 16 : 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.grey[500],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  IconData _getPaymentIcon(String metodo) {
    // Solo efectivo soportado
    return Icons.money_rounded;
  }
}
