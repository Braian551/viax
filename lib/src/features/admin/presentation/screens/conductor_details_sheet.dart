import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

class ConductorDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> conductor;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;
  final Function(int) onShowHistory;
  /// Callback para ver documento: (url, nombre, tipoArchivo)
  final Function(String?, String, {String? tipoArchivo}) onViewDocument;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Usamos Container en lugar de DraggableScrollableSheet para un modal fijo más limpio
    // o DraggableScrollableSheet sin el handle visual si se prefiere funcionalidad
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark 
                    ? AppColors.darkSurface.withValues(alpha: 0.98) 
                    : AppColors.lightSurface.withValues(alpha: 0.98),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                   // Espaciado superior limpio sin handle
                  const SizedBox(height: 20),
                  
                  // Título centralizado
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_pin_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                conductor['nombre_completo'] ?? 'Conductor',
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Detalles de registro',
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(context, 'Información Personal'),
                          _buildInfoCard(context, [
                            _buildInfoRow(context, 'Email', conductor['email'], Icons.email_outlined),
                            _buildInfoRow(context, 'Teléfono', conductor['telefono'], Icons.phone_outlined),
                            _buildInfoRow(context, 'Estado', conductor['es_activo'] == 1 ? 'Activo' : 'Inactivo', 
                              conductor['es_activo'] == 1 ? Icons.check_circle_outline : Icons.cancel_outlined),
                          ]),

                          const SizedBox(height: 24),
                          _buildSectionTitle(context, 'Licencia de Conducción'),
                          _buildInfoCard(context, [
                            _buildInfoRow(context, 'Número', conductor['licencia_conduccion'], Icons.badge_outlined),
                            _buildInfoRow(context, 'Categoría', conductor['licencia_categoria'], Icons.category_outlined),
                            _buildInfoRow(context, 'Vencimiento', _formatDate(conductor['licencia_vencimiento']), Icons.event_outlined),
                          ]),
                          if (conductor['licencia_foto_url'] != null)
                             _buildDocButton(context, 'Ver Licencia', conductor['licencia_foto_url'], Icons.drive_eta_rounded, conductor['licencia_tipo_archivo']),

                          const SizedBox(height: 24),
                          _buildSectionTitle(context, 'Vehículo'),
                          _buildInfoCard(context, [
                            _buildInfoRow(context, 'Placa', conductor['vehiculo_placa'], Icons.directions_car_outlined, isBold: true),
                            _buildInfoRow(context, 'Modelo', '${conductor['vehiculo_marca']} ${conductor['vehiculo_modelo']} ${conductor['vehiculo_anio'] ?? ''}', Icons.info_outline),
                            _buildInfoRow(context, 'Color', conductor['vehiculo_color'], Icons.color_lens_outlined),
                            _buildInfoRow(context, 'Tipo', conductor['vehiculo_tipo'], Icons.local_taxi_outlined),
                          ]),
                          if (conductor['vehiculo_foto_url'] != null)
                             _buildDocButton(context, 'Ver Foto Vehículo', conductor['vehiculo_foto_url'], Icons.directions_car_rounded, conductor['vehiculo_tipo_archivo'])
                          else
                             _buildDocButton(context, 'Sin Foto Vehículo', null, Icons.directions_car_rounded, null),
                          
                          const SizedBox(height: 24),
                          _buildSectionTitle(context, 'Documentación Legal'),
                          _buildInfoCard(context, [
                            _buildInfoRow(context, 'SOAT', _formatDate(conductor['soat_vencimiento']), Icons.security_outlined),
                            _buildInfoRow(context, 'Número SOAT', conductor['soat_numero'], Icons.tag),
                            _buildInfoRow(context, 'Tecnomecánica', _formatDate(conductor['tecnomecanica_vencimiento']), Icons.build_outlined),
                            _buildInfoRow(context, 'Número Tecno', conductor['tecnomecanica_numero'], Icons.tag),
                            // _buildInfoRow(context, 'Seguro', _formatDate(conductor['vencimiento_seguro']), Icons.shield_outlined), // REMOVED
                            _buildInfoRow(context, 'Tarjeta Propiedad', conductor['tarjeta_propiedad_numero'], Icons.credit_card_outlined),
                          ]),
                          
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              if (conductor['soat_foto_url'] != null)
                                _buildMiniDocButton(context, 'SOAT', conductor['soat_foto_url'], conductor['soat_tipo_archivo']),
                              if (conductor['tecnomecanica_foto_url'] != null)
                                _buildMiniDocButton(context, 'Tecno', conductor['tecnomecanica_foto_url'], conductor['tecnomecanica_tipo_archivo']),
                              // if (conductor['seguro_foto_url'] != null)
                              //   _buildMiniDocButton(context, 'Seguro', conductor['seguro_foto_url'], conductor['seguro_tipo_archivo']), // REMOVED
                              if (conductor['tarjeta_propiedad_foto_url'] != null)
                                _buildMiniDocButton(context, 'Tarjeta', conductor['tarjeta_propiedad_foto_url'], conductor['tarjeta_propiedad_tipo_archivo']),
                            ],
                          ),

                          const SizedBox(height: 24),
                          _buildHistoryButton(context),

                          if (conductor['documentos_vencidos'] != null && (conductor['documentos_vencidos'] as List).isNotEmpty)
                            _buildExpiredWarning(context, conductor['documentos_vencidos'] as List),

                          const SizedBox(height: 100), // Espacio para botones flotantes
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, dynamic value, IconData icon, {bool isBold = false}) {
    final valueStr = value?.toString() ?? 'N/A';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Expanded(
            flex: 2,
            child: Text(
              valueStr,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocButton(BuildContext context, String label, String? url, IconData icon, String? tipoArchivo) {
    final isPdf = tipoArchivo?.toLowerCase() == 'pdf';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: url != null ? () => onViewDocument(url, label, tipoArchivo: tipoArchivo) : null,
        icon: Icon(isPdf ? Icons.picture_as_pdf_rounded : icon, size: 18, color: url != null ? (isPdf ? Colors.red : AppColors.primary) : Colors.grey),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (isPdf) ...[
              const SizedBox(width: 6),
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
          foregroundColor: isPdf ? Colors.red : AppColors.primary,
          side: BorderSide(color: (isPdf ? Colors.red : AppColors.primary).withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildMiniDocButton(BuildContext context, String label, String? url, String? tipoArchivo) {
    final isPdf = tipoArchivo?.toLowerCase() == 'pdf';
    return ActionChip(
      avatar: Icon(
        isPdf ? Icons.picture_as_pdf_rounded : Icons.description_outlined, 
        size: 16, 
        color: isPdf ? Colors.red : AppColors.primary,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isPdf) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'PDF',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
          ],
        ],
      ),
      onPressed: () => onViewDocument(url, 'Documento $label', tipoArchivo: tipoArchivo),
      backgroundColor: (isPdf ? Colors.red : AppColors.primary).withValues(alpha: 0.1),
      side: BorderSide.none,
      labelStyle: TextStyle(
        color: isPdf ? Colors.red : AppColors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildHistoryButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () => onShowHistory(conductor['usuario_id']),
        icon: const Icon(Icons.history, size: 20),
        label: const Text('Ver Historial de Cambios'),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).textTheme.bodyMedium?.color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildExpiredWarning(BuildContext context, List docs) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'Documentos Vencidos',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...docs.map((d) => Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 4),
            child: Text(
              '• $d',
              style: TextStyle(
                color: AppColors.error.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          )),
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
}