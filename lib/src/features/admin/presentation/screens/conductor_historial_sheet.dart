import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

class ConductorHistorialSheet extends StatelessWidget {
  final List<Map<String, dynamic>> historial;

  const ConductorHistorialSheet({
    super.key,
    required this.historial,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
              child: Column(
                children: [
                  _buildSheetHandle(context),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.history_rounded, 
                            color: AppColors.primary, 
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Historial de Documentos',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${historial.length} ${historial.length == 1 ? 'registro' : 'registros'}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: historial.length,
                      itemBuilder: (context, index) {
                        final doc = historial[index];
                        return _buildHistorialItem(context, doc, index);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetHandle(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHistorialItem(BuildContext context, Map<String, dynamic> doc, int index) {
    final estado = doc['estado'] ?? 'pendiente';
    final Color estadoColor = estado == 'aprobado' 
        ? const Color(0xFF11998e) 
        : estado == 'rechazado'
            ? const Color(0xFFf5576c)
            : const Color(0xFFffa726);

    final Map<String, String> tiposDocumento = {
      'licencia': 'Licencia de Conducción',
      'soat': 'SOAT',
      'tecnomecanica': 'Tecnomecánica',
      'tarjeta_propiedad': 'Tarjeta de Propiedad',
      'seguro': 'Seguro',
    };

    final String nombreDoc = tiposDocumento[doc['tipo_documento']] ?? doc['tipo_documento'];
    final bool hasMotivo = doc['motivo_rechazo'] != null && doc['motivo_rechazo'].toString().isNotEmpty;
    final bool hasArchivo = doc['ruta_archivo'] != null && doc['ruta_archivo'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: estadoColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera
                Container(
                  padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: estadoColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: estadoColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getDocumentIcon(doc['tipo_documento']),
                          color: estadoColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombreDoc,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatDate(doc['fecha_subida']),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: estadoColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: estadoColor.withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getEstadoIcon(estado),
                              color: estadoColor,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getEstadoLabel(estado),
                              style: TextStyle(
                                color: estadoColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Contenido
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Información adicional del documento
                      if (doc['numero_documento'] != null && doc['numero_documento'].toString().isNotEmpty)
                        _buildHistorialInfoRow(
                          context,
                          Icons.numbers_rounded,
                          'Número',
                          doc['numero_documento'],
                        ),
                      
                      if (doc['fecha_vencimiento'] != null)
                        _buildHistorialInfoRow(
                          context,
                          Icons.event_rounded,
                          'Vencimiento',
                          _formatDate(doc['fecha_vencimiento']),
                        ),
                      
                      // Motivo de rechazo (si existe)
                      if (hasMotivo) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFf5576c).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFf5576c).withValues(alpha: 0.3),
                                width: 1,
                              ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFFf5576c),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Motivo de rechazo:',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      doc['motivo_rechazo'],
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.95),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Botón para ver documento
                      if (hasArchivo) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context); // Cerrar el historial
                              // onViewDocument(doc['ruta_archivo'], nombreDoc);
                            },
                            icon: const Icon(Icons.visibility_rounded, size: 20),
                            label: const Text('Ver Documento'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: estadoColor.withValues(alpha: 0.2),
                              foregroundColor: estadoColor,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: estadoColor.withValues(alpha: 0.5), width: 1.5),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      );
  }

  Widget _buildHistorialInfoRow(BuildContext context, IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDocumentIcon(String? tipo) {
    switch (tipo) {
      case 'licencia':
        return Icons.badge_rounded;
      case 'soat':
        return Icons.health_and_safety_rounded;
      case 'tecnomecanica':
        return Icons.build_rounded;
      case 'tarjeta_propiedad':
        return Icons.credit_card_rounded;
      case 'seguro':
        return Icons.shield_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  IconData _getEstadoIcon(String estado) {
    switch (estado) {
      case 'aprobado':
        return Icons.check_circle_rounded;
      case 'rechazado':
        return Icons.cancel_rounded;
      case 'en_revision':
        return Icons.pending_rounded;
      case 'pendiente':
      default:
        return Icons.schedule_rounded;
    }
  }

  String _getEstadoLabel(String estado) {
    switch (estado) {
      case 'aprobado':
        return 'Aprobado';
      case 'rechazado':
        return 'Rechazado';
      case 'en_revision':
        return 'En Revisión';
      case 'pendiente':
      default:
        return 'Pendiente';
    }
  }

  String _formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return 'N/A';
    try {
      final DateTime dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date.toString();
    }
  }
}