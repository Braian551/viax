import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

class ConductorDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> conductor;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;
  final Function(int) onShowHistory;
  final Function(String?, String) onViewDocument;

  const ConductorDetailsSheet({
    super.key,
    required this.conductor,
    required this.onAprobar,
    required this.onRechazar,
    required this.onShowHistory,
    required this.onViewDocument,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
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
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailSection(context, 'Información Personal', [
                            _buildDetailRow(context, 'Nombre completo', conductor['nombre_completo']),
                            _buildDetailRow(context, 'Email', conductor['email']),
                            _buildDetailRow(context, 'Teléfono', conductor['telefono']),
                            _buildDetailRow(context, 'Usuario activo', conductor['es_activo'] == 1 ? 'Sí' : 'No'),
                            _buildDetailRow(context, 'Verificado', conductor['es_verificado'] == 1 ? 'Sí' : 'No'),
                          ]),
                          const SizedBox(height: 24),
                          _buildDetailSection(context, 'Licencia de Conducción', [
                            _buildDetailRow(context, 'Número', conductor['licencia_conduccion']),
                            _buildDetailRow(context, 'Categoría', conductor['licencia_categoria']),
                            _buildDetailRow(context, 'Expedición', _formatDate(conductor['licencia_expedicion'])),
                            _buildDetailRow(context, 'Vencimiento', _formatDate(conductor['licencia_vencimiento'])),
                          ]),
                          const SizedBox(height: 16),
                          if (conductor['licencia_foto_url'] != null)
                            _buildDocumentButton(context,
                              label: 'Ver Foto de Licencia',
                              documentUrl: conductor['licencia_foto_url'],
                              icon: Icons.photo_camera_rounded,
                            ),
                          const SizedBox(height: 24),
                          _buildDetailSection(context, 'Vehículo', [
                            _buildDetailRow(context, 'Tipo', conductor['vehiculo_tipo']),
                            _buildDetailRow(context, 'Placa', conductor['vehiculo_placa']),
                            _buildDetailRow(context, 'Marca', conductor['vehiculo_marca']),
                            _buildDetailRow(context, 'Modelo', conductor['vehiculo_modelo']),
                            _buildDetailRow(context, 'Año', conductor['vehiculo_anio']?.toString()),
                            _buildDetailRow(context, 'Color', conductor['vehiculo_color']),
                          ]),
                          const SizedBox(height: 24),
                          _buildDetailSection(context, 'SOAT', [
                            _buildDetailRow(context, 'Número', conductor['soat_numero']),
                            _buildDetailRow(context, 'Vencimiento', _formatDate(conductor['soat_vencimiento'])),
                          ]),
                          const SizedBox(height: 16),
                          if (conductor['soat_foto_url'] != null)
                            _buildDocumentButton(context,
                              label: 'Ver Foto de SOAT',
                              documentUrl: conductor['soat_foto_url'],
                              icon: Icons.photo_camera_rounded,
                            ),
                          const SizedBox(height: 24),
                          _buildDetailSection(context, 'Tecnomecánica', [
                            _buildDetailRow(context, 'Número', conductor['tecnomecanica_numero']),
                            _buildDetailRow(context, 'Vencimiento', _formatDate(conductor['tecnomecanica_vencimiento'])),
                          ]),
                          const SizedBox(height: 16),
                          if (conductor['tecnomecanica_foto_url'] != null)
                            _buildDocumentButton(context,
                              label: 'Ver Foto de Tecnomecánica',
                              documentUrl: conductor['tecnomecanica_foto_url'],
                              icon: Icons.photo_camera_rounded,
                            ),
                          const SizedBox(height: 24),
                          _buildDetailSection(context, 'Seguro', [
                            _buildDetailRow(context, 'Aseguradora', conductor['aseguradora']),
                            _buildDetailRow(context, 'Póliza', conductor['numero_poliza_seguro']),
                            _buildDetailRow(context, 'Vencimiento', _formatDate(conductor['vencimiento_seguro'])),
                          ]),
                          const SizedBox(height: 16),
                          if (conductor['seguro_foto_url'] != null)
                            _buildDocumentButton(context,
                              label: 'Ver Foto de Seguro',
                              documentUrl: conductor['seguro_foto_url'],
                              icon: Icons.photo_camera_rounded,
                            ),
                          const SizedBox(height: 24),
                          _buildDetailSection(context, 'Otros Documentos', [
                            _buildDetailRow(context, 'Tarjeta de propiedad', conductor['tarjeta_propiedad_numero']),
                          ]),
                          const SizedBox(height: 16),
                          if (conductor['tarjeta_propiedad_foto_url'] != null)
                            _buildDocumentButton(context,
                              label: 'Ver Tarjeta de Propiedad',
                              documentUrl: conductor['tarjeta_propiedad_foto_url'],
                              icon: Icons.photo_camera_rounded,
                            ),
                          const SizedBox(height: 24),
                          _buildDetailSection(context, 'Estado de Verificación', [
                            _buildDetailRow(context, 'Estado', conductor['estado_verificacion']),
                            _buildDetailRow(context, 'Aprobado', conductor['aprobado'] == 1 ? 'Sí' : 'No'),
                            _buildDetailRow(context, 'Última verificación', _formatDate(conductor['fecha_ultima_verificacion'])),
                          ]),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => onShowHistory(conductor['usuario_id']),
                            icon: const Icon(Icons.history_rounded),
                            label: const Text('Ver Historial de Documentos'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667eea),
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          if (conductor['documentos_vencidos'] != null && (conductor['documentos_vencidos'] as List).isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFf5576c).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFf5576c).withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.warning_rounded, color: Color(0xFFf5576c), size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Documentos Vencidos',
                                            style: TextStyle(
                                              color: Color(0xFFf5576c),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ...(conductor['documentos_vencidos'] as List).map((doc) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.circle, size: 6, color: Color(0xFFf5576c)),
                                            const SizedBox(width: 8),
                                            Text(
                                              doc.toString(),
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          if (conductor['estado_verificacion'] == 'pendiente' || conductor['estado_verificacion'] == 'en_revision')
                            Column(
                              children: [
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: onAprobar,
                                        icon: const Icon(Icons.check_circle_rounded),
                                        label: const Text('Aprobar'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF11998e),
                                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: onRechazar,
                                        icon: const Icon(Icons.cancel_rounded),
                                        label: const Text('Rechazar'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFf5576c),
                                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        ],
                      ),
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

  Widget _buildDetailSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, dynamic value) {
    final valueStr = value?.toString() ?? 'N/A';
    final isEmpty = value == null || valueStr == 'N/A' || valueStr.isEmpty;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              valueStr,
              style: TextStyle(
                color: isEmpty ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3) : Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildDocumentButton(BuildContext context, {
    required String label,
    required String? documentUrl,
    required IconData icon,
  }) {
    final bool hasDocument = documentUrl != null && documentUrl.isNotEmpty;
    
    return GestureDetector(
      onTap: hasDocument 
          ? () => _viewDocument(documentUrl, label)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasDocument 
              ? const Color(0xFF667eea).withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDocument 
                ? const Color(0xFF667eea).withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasDocument 
                    ? const Color(0xFF667eea).withValues(alpha: 0.2)
                    : Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: hasDocument ? const Color(0xFF667eea) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: hasDocument ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasDocument ? 'Toca para ver' : 'No disponible',
                    style: TextStyle(
                      color: hasDocument 
                          ? const Color(0xFF667eea) 
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (hasDocument)
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF667eea),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  void _viewDocument(String? documentUrl, String documentName) {
    onViewDocument(documentUrl, documentName);
  }
}