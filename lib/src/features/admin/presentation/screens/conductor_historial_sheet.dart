import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

class ConductorHistorialSheet extends StatelessWidget {
  final List<Map<String, dynamic>> historial;
  final Function(String?, String, {String? tipoArchivo}) onViewDocument;

  const ConductorHistorialSheet({
    super.key,
    required this.historial,
    required this.onViewDocument,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: isDark 
                  ? AppColors.darkSurface.withValues(alpha: 0.98) 
                  : AppColors.lightSurface.withValues(alpha: 0.98),
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
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.history_edu_rounded, 
                            color: AppColors.primary, 
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Historial de Cambios',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${historial.length} ${historial.length == 1 ? 'registro' : 'registros'} de actividad',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface, size: 20),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      itemCount: historial.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final doc = historial[index];
                        return _buildHistorialItem(context, doc);
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
        color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHistorialItem(BuildContext context, Map<String, dynamic> doc) {
    final estado = doc['estado'] ?? 'pendiente';
    final Color estadoColor = _getEstadoColor(estado);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Map<String, String> tiposDocumento = {
      'licencia_conduccion': 'Licencia de Conducción',
      'licencia': 'Licencia de Conducción',
      'soat': 'SOAT',
      'tecnomecanica': 'Tecnomecánica',
      'tarjeta_propiedad': 'Tarjeta de Propiedad',
      'tecnomecanica': 'Tecnomecánica',
      'tarjeta_propiedad': 'Tarjeta de Propiedad',
      // 'seguro_contractual': 'Seguro Contractual',
      // 'seguro': 'Seguro Contractual',
    };

    final String nombreDoc = tiposDocumento[doc['tipo_documento']] ?? doc['tipo_documento'] ?? 'Documento';
    final bool hasMotivo = doc['motivo_rechazo'] != null && doc['motivo_rechazo'].toString().isNotEmpty;
    final bool hasArchivo = doc['ruta_archivo'] != null && doc['ruta_archivo'].toString().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header del item
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: estadoColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getDocumentIcon(doc['tipo_documento']),
                    color: estadoColor,
                    size: 20,
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
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(doc['fecha_subida']),
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(context, estado, estadoColor),
              ],
            ),
          ),
          
          // Cuerpo del item
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (doc['numero_documento'] != null)
                  _buildDataRow(context, Icons.tag, 'Número:', doc['numero_documento']),
                
                if (doc['fecha_vencimiento'] != null)
                  _buildDataRow(context, Icons.event_rounded, 'Vencimiento:', _formatDate(doc['fecha_vencimiento'])),

                if (doc['reemplazado_en'] != null)
                  _buildDataRow(
                    context, 
                    Icons.history_toggle_off_rounded, 
                    'Reemplazado el:', 
                    _formatDate(doc['reemplazado_en']),
                    isWarning: true
                  ),

                if (hasMotivo) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            doc['motivo_rechazo'],
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (hasArchivo) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => onViewDocument(doc['ruta_archivo'], nombreDoc, tipoArchivo: doc['tipo_archivo']?.toString()),
                      icon: Icon(
                        doc['tipo_archivo']?.toString().toLowerCase() == 'pdf' 
                            ? Icons.picture_as_pdf_rounded 
                            : Icons.visibility_rounded, 
                        size: 18,
                        color: doc['tipo_archivo']?.toString().toLowerCase() == 'pdf' 
                            ? Colors.red 
                            : AppColors.primary,
                      ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Ver Documento Original'),
                          if (doc['tipo_archivo']?.toString().toLowerCase() == 'pdf') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PDF',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ),
                          ],
                        ],
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: doc['tipo_archivo']?.toString().toLowerCase() == 'pdf' 
                            ? Colors.red 
                            : AppColors.primary,
                        side: BorderSide(color: (doc['tipo_archivo']?.toString().toLowerCase() == 'pdf' 
                            ? Colors.red 
                            : AppColors.primary).withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String estado, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _getEstadoLabel(estado),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, IconData icon, String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isWarning ? AppColors.warning : Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'aprobado': return AppColors.success;
      case 'rechazado': return AppColors.error;
      case 'en_revision': return AppColors.warning;
      case 'reemplazado': return Colors.grey;
      case 'pendiente': return AppColors.primary;
      default: return Colors.grey;
    }
  }

  String _getEstadoLabel(String estado) {
    switch (estado) {
      case 'aprobado': return 'Aprobado';
      case 'rechazado': return 'Rechazado';
      case 'en_revision': return 'En Revisión';
      case 'reemplazado': return 'Reemplazado';
      case 'pendiente': return 'Pendiente';
      default: return estado;
    }
  }

  IconData _getDocumentIcon(String? tipo) {
    switch (tipo) {
      case 'licencia':
      case 'licencia_conduccion': return Icons.badge_rounded;
      case 'soat': return Icons.health_and_safety_rounded;
      case 'tecnomecanica': return Icons.build_circle_rounded;
      case 'tarjeta_propiedad': return Icons.directions_car_rounded;
      case 'tarjeta_propiedad': return Icons.directions_car_rounded;
      // case 'seguro':
      // case 'seguro_contractual': return Icons.shield_rounded;
      default: return Icons.file_present_rounded;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return 'N/A';
    try {
      final DateTime dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date.toString();
    }
  }
}