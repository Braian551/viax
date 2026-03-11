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

  /// Duración en segundos (para formato flexible)
  final int duracionSegundos;

  /// Duración en minutos (legacy, se ignora si duracionSegundos > 0)
  final int duracionMinutos;
  final double precio;
  final String? metodoPago;
  final String? resumenCalculo;
  final Map<String, dynamic>? desglosePrecio;
  final bool mostrarPrecio;
  final bool isDark;

  const TripSummaryCard({
    super.key,
    required this.origen,
    required this.destino,
    required this.distanciaKm,
    this.duracionSegundos = 0,
    this.duracionMinutos = 0,
    required this.precio,
    this.metodoPago,
    this.resumenCalculo,
    this.desglosePrecio,
    this.mostrarPrecio = true,
    required this.isDark,
  });

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  /// Formatea la duración en formato legible (seg/min/horas)
  String get _duracionFormateada {
    // Usar segundos si está disponible, sino convertir minutos a segundos
    final totalSeg = duracionSegundos > 0
        ? duracionSegundos
        : (duracionMinutos * 60);

    if (totalSeg < 60) {
      return '$totalSeg seg';
    } else if (totalSeg < 3600) {
      final min = totalSeg ~/ 60;
      final seg = totalSeg % 60;
      if (seg == 0) return '$min min';
      return '$min min $seg seg';
    } else {
      final hours = totalSeg ~/ 3600;
      final mins = (totalSeg % 3600) ~/ 60;
      if (mins == 0) return '${hours}h';
      return '${hours}h ${mins}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey[200]!),
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
              Expanded(
                child: _buildStatItem(
                  Icons.route_rounded,
                  '${distanciaKm.toStringAsFixed(1)} km',
                  'Distancia',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.white12 : Colors.grey[300],
              ),
              Expanded(
                child: _buildStatItem(
                  Icons.schedule_rounded,
                  _duracionFormateada,
                  'Duración',
                ),
              ),
              if (mostrarPrecio) ...[
                Container(
                  width: 1,
                  height: 40,
                  color: isDark ? Colors.white12 : Colors.grey[300],
                ),
                Expanded(
                  child: _buildStatItem(
                    Icons.attach_money_rounded,
                    '\$${_formatCurrency(precio)}',
                    'Total',
                    highlight: true,
                  ),
                ),
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

          if (resumenCalculo != null && resumenCalculo!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? Colors.white12
                      : Colors.blue.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: isDark ? Colors.white70 : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      resumenCalculo!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark
                            ? Colors.white70
                            : Colors.blueGrey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (desglosePrecio != null && desglosePrecio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildBreakdownCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownCard() {
    final data = desglosePrecio!;
    final tarifaBase = _toDouble(data['tarifa_base']);
    final precioDistancia = _toDouble(data['precio_distancia']);
    final precioTiempo = _toDouble(data['precio_tiempo']);
    final recargoNocturno = _toDouble(data['recargo_nocturno']);
    final recargoHoraPico = _toDouble(data['recargo_hora_pico']);
    final recargoFestivo = _toDouble(data['recargo_festivo']);
    final recargoEspera = _toDouble(data['recargo_espera']);
    final subtotal = _toDouble(data['subtotal_sin_recargos']);
    final aplicoMinimo = data['aplico_tarifa_minima'] == true;

    final totalRecargos =
        recargoNocturno + recargoHoraPico + recargoFestivo + recargoEspera;
    final subtotalCalculado = subtotal > 0
        ? subtotal + totalRecargos
        : tarifaBase + precioDistancia + precioTiempo + totalRecargos;
    final ajusteMinimo = (precio - subtotalCalculado).clamp(0.0, double.infinity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Desglose del valor',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 10),
          _buildBreakdownRow('Tarifa base', tarifaBase),
          _buildBreakdownRow('Costo por distancia', precioDistancia),
          _buildBreakdownRow('Costo por tiempo', precioTiempo),
          if (recargoNocturno > 0)
            _buildBreakdownRow('Recargo nocturno', recargoNocturno),
          if (recargoHoraPico > 0)
            _buildBreakdownRow('Recargo hora pico', recargoHoraPico),
          if (recargoFestivo > 0)
            _buildBreakdownRow('Recargo festivo', recargoFestivo),
          if (recargoEspera > 0)
            _buildBreakdownRow('Recargo por espera', recargoEspera),
          _buildBreakdownRow('Subtotal', subtotalCalculado, isStrong: true),
          if (aplicoMinimo || ajusteMinimo > 0)
            _buildBreakdownRow('Ajuste por tarifa mínima', ajusteMinimo),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, double value, {bool isStrong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.grey[700],
              fontWeight: isStrong ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            '\$${_formatCurrency(value)}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white : Colors.grey[900],
              fontWeight: isStrong ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
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

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label, {
    bool highlight = false,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: highlight
              ? AppColors.success
              : (isDark ? Colors.white54 : Colors.grey[500]),
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

  /// Formatea la moneda con separadores de miles
  String _formatCurrency(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }
}
