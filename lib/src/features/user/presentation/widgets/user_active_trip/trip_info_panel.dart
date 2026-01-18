import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

import 'package:viax/src/features/conductor/services/document_upload_service.dart';

/// Panel con información del viaje y conductor.
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
  });
  
  /// Formatea segundos en formato legible (seg/min/horas)
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
    final calificacion = (conductor?['calificacion_promedio'] as num?)?.toDouble();

    final conductorFoto = conductor?['foto'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Destino
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  direccionDestino,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.grey[900],
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(
            color: isDark ? Colors.white12 : Colors.grey[200],
            height: 1,
          ),
          const SizedBox(height: 16),

          // Info del conductor
          Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: conductorFoto != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          DocumentUploadService.getDocumentUrl(conductorFoto),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 14),

              // Nombre y vehículo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            conductorNombre,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.grey[900],
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (calificacion != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 14,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  calificacion.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (vehiculoInfo != null && vehiculoInfo.isNotEmpty)
                      Text(
                        vehiculoInfo,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),

              // Placa
              if (placa != null && placa.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    placa,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.grey[800],
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
          
          // Tracking en tiempo real
          if (precioActual != null && precioActual! > 0) ...[
            const SizedBox(height: 16),
            Divider(
              color: isDark ? Colors.white12 : Colors.grey[200],
              height: 1,
            ),
            const SizedBox(height: 16),
            _buildTrackingInfo(isDark),
          ],
        ],
      ),
    );
  }
  
  /// Construye la información de tracking en tiempo real
  Widget _buildTrackingInfo(bool isDark) {
    final distancia = distanciaRecorrida ?? 0.0;
    final tiempo = tiempoTranscurrido ?? 0;
    final precio = precioActual ?? 0.0;
    
    // Formatear tiempo de manera flexible
    final tiempoFormateado = _formatearTiempo(tiempo);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Distancia recorrida
          _buildTrackingStat(
            icon: Icons.route_rounded,
            label: 'Recorrido',
            value: '${distancia.toStringAsFixed(2)} km',
            isDark: isDark,
          ),
          
          // Separador
          Container(
            width: 1,
            height: 40,
            color: isDark ? Colors.white12 : Colors.grey[300],
          ),
          
          // Tiempo transcurrido
          _buildTrackingStat(
            icon: Icons.timer_rounded,
            label: 'Tiempo',
            value: tiempoFormateado,
            isDark: isDark,
          ),
          
          // Separador
          Container(
            width: 1,
            height: 40,
            color: isDark ? Colors.white12 : Colors.grey[300],
          ),
          
          // Precio actual
          _buildTrackingStat(
            icon: Icons.attach_money_rounded,
            label: 'Precio',
            value: '\$${precio.toStringAsFixed(0)}',
            isDark: isDark,
            isHighlighted: true,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrackingStat({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    bool isHighlighted = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color: isHighlighted 
              ? AppColors.primary 
              : (isDark ? Colors.white60 : Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isHighlighted 
                ? AppColors.primary 
                : (isDark ? Colors.white : Colors.grey[900]),
            fontSize: 15,
            fontWeight: FontWeight.w700,
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
}
