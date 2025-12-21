// lib/src/widgets/quota_alert_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/map/providers/map_provider.dart';
import '../global/services/quota_monitor_service.dart';

/// Widget que muestra alertas sobre el uso de las cuotas de las APIs
/// Se actualiza automáticamente según el MapProvider
class QuotaAlertWidget extends StatelessWidget {
  final bool compact;
  
  const QuotaAlertWidget({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);
    final quotaStatus = mapProvider.quotaStatus;

    if (quotaStatus == null || !quotaStatus.hasAlert) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getBackgroundColor(quotaStatus.overallAlertLevel),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetailedQuotaDialog(context, quotaStatus),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: compact 
                ? _buildCompactAlert(quotaStatus)
                : _buildFullAlert(quotaStatus),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactAlert(QuotaStatus status) {
    return Row(
      children: [
        Icon(
          _getAlertIcon(status.overallAlertLevel),
          color: Colors.white,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            status.alertMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white70,
          size: 16,
        ),
      ],
    );
  }

  Widget _buildFullAlert(QuotaStatus status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getAlertIcon(status.overallAlertLevel),
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                status.alertMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Mapbox Tiles
        _buildQuotaBar(
          'Mapbox - Mapas',
          status.mapboxTilesUsed,
          status.mapboxTilesLimit,
          status.mapboxTilesPercentage,
        ),
        const SizedBox(height: 12),
        
        // Mapbox Routing
        _buildQuotaBar(
          'Mapbox - Rutas',
          status.mapboxRoutingUsed,
          status.mapboxRoutingLimit,
          status.mapboxRoutingPercentage,
        ),
        const SizedBox(height: 12),
        
        // TomTom Traffic
        _buildQuotaBar(
          'TomTom - Tráfico',
          status.tomtomTrafficUsed,
          status.tomtomTrafficLimit,
          status.tomtomTrafficPercentage,
        ),
        
        const SizedBox(height: 12),
        Text(
          'Toca para más detalles',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildQuotaBar(String label, int used, int limit, double percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${used.toStringAsFixed(0)} / ${limit.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage.clamp(0.0, 1.0),
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getProgressColor(percentage),
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(percentage * 100).toStringAsFixed(1)}% usado',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Color _getBackgroundColor(QuotaAlertLevel level) {
    switch (level) {
      case QuotaAlertLevel.critical:
        return Colors.red.shade800;
      case QuotaAlertLevel.danger:
        return Colors.orange.shade700;
      case QuotaAlertLevel.warning:
        return Colors.amber.shade700;
      default:
        return Colors.green.shade700;
    }
  }

  IconData _getAlertIcon(QuotaAlertLevel level) {
    switch (level) {
      case QuotaAlertLevel.critical:
        return Icons.error;
      case QuotaAlertLevel.danger:
        return Icons.warning;
      case QuotaAlertLevel.warning:
        return Icons.info;
      default:
        return Icons.check_circle;
    }
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 0.9) return Colors.red.shade300;
    if (percentage >= 0.75) return Colors.orange.shade300;
    if (percentage >= 0.5) return Colors.yellow.shade300;
    return Colors.green.shade300;
  }

  void _showDetailedQuotaDialog(BuildContext context, QuotaStatus status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getAlertIcon(status.overallAlertLevel),
              color: _getBackgroundColor(status.overallAlertLevel),
            ),
            const SizedBox(width: 12),
            const Text('Estado de Cuotas'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status.alertMessage,
                style: TextStyle(
                  color: _getBackgroundColor(status.overallAlertLevel),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              _buildDetailedQuotaSection(
                'Mapbox - Tiles de Mapas',
                'Solicitudes de tiles del mapa (mensual)',
                status.mapboxTilesUsed,
                status.mapboxTilesLimit,
                status.mapboxTilesPercentage,
                status.mapboxTilesAlertLevel,
              ),
              
              const Divider(height: 32),
              
              _buildDetailedQuotaSection(
                'Mapbox - Routing',
                'Cálculo de rutas y direcciones (mensual)',
                status.mapboxRoutingUsed,
                status.mapboxRoutingLimit,
                status.mapboxRoutingPercentage,
                status.mapboxRoutingAlertLevel,
              ),
              
              const Divider(height: 32),
              
              _buildDetailedQuotaSection(
                'TomTom - Traffic',
                'Información de tráfico en tiempo real (diario)',
                status.tomtomTrafficUsed,
                status.tomtomTrafficLimit,
                status.tomtomTrafficPercentage,
                status.tomtomTrafficAlertLevel,
              ),
              
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Información',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Los contadores se resetean automáticamente:\n'
                      'â€¢ Mapbox: Cada mes\n'
                      '• TomTom: Cada día\n\n'
                      'Todas estas APIs tienen planes gratuitos generosos.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedQuotaSection(
    String title,
    String subtitle,
    int used,
    int limit,
    double percentage,
    QuotaAlertLevel level,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getBackgroundColor(level),
            ),
            minHeight: 20,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(percentage * 100).toStringAsFixed(1)}% usado',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$used / $limit',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Widget compacto para la barra de estado
class QuotaStatusBadge extends StatelessWidget {
  const QuotaStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);
    final quotaStatus = mapProvider.quotaStatus;

    if (quotaStatus == null || !quotaStatus.hasAlert) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getBackgroundColor(quotaStatus.overallAlertLevel),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getAlertIcon(quotaStatus.overallAlertLevel),
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '${(quotaStatus.mapboxTilesPercentage * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor(QuotaAlertLevel level) {
    switch (level) {
      case QuotaAlertLevel.critical:
        return Colors.red.shade800;
      case QuotaAlertLevel.danger:
        return Colors.orange.shade700;
      case QuotaAlertLevel.warning:
        return Colors.amber.shade700;
      default:
        return Colors.green.shade700;
    }
  }

  IconData _getAlertIcon(QuotaAlertLevel level) {
    switch (level) {
      case QuotaAlertLevel.critical:
        return Icons.error;
      case QuotaAlertLevel.danger:
        return Icons.warning;
      case QuotaAlertLevel.warning:
        return Icons.info;
      default:
        return Icons.check_circle;
    }
  }
}
