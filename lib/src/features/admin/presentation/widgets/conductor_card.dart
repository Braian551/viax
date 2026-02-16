import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:shimmer/shimmer.dart';
import 'package:viax/src/core/utils/colombian_plate_utils.dart';

/// Card que muestra información resumida de un conductor pendiente de verificación
class ConductorCard extends StatelessWidget {
  final Map<String, dynamic> conductor;
  final VoidCallback? onTap;
  final VoidCallback? onAprobar;
  final VoidCallback? onRechazar;
  final VoidCallback? onDesactivar;
  final VoidCallback? onDesvincular;
  final bool isLoading;

  const ConductorCard({
    super.key,
    required this.conductor,
    this.onTap,
    this.onAprobar,
    this.onRechazar,
    this.onDesactivar,
    this.onDesvincular,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // We removed the global early return to allow granular shimmer like in EmpresaCard

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final estadoVerificacion = conductor['estado_verificacion'] ?? 'pendiente';
    final estadoSolicitud = conductor['estado_solicitud'];
    
    Color statusColor = _getStatusColor(estadoVerificacion);
    if (estadoSolicitud == 'rechazada') {
      statusColor = AppColors.error;
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark 
              ? AppColors.darkSurface.withValues(alpha: 0.8)
              : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, statusColor),
                  const SizedBox(height: 12),
                  _buildInfo(context),
                  const SizedBox(height: 12),
                  _buildDocumentProgress(context, statusColor),
                  if (_hasExpiredDocuments()) ...[
                    const SizedBox(height: 8),
                    _buildExpiredWarning(context),
                  ],
                  const SizedBox(height: 16),
                  _buildActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color statusColor) {
    String? fotoUrl = conductor['foto_perfil'];
    // Handle Cloudflare/R2 URL display if needed
    if (fotoUrl != null && !fotoUrl.startsWith('http')) {
        fotoUrl = '${AppConfig.baseUrl}/r2_proxy.php?key=$fotoUrl';
    }

    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: fotoUrl != null && fotoUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    fotoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.person_outline_rounded,
                      color: statusColor,
                      size: 28,
                    ),
                  ),
                )
              : Icon(
                  Icons.person_outline_rounded,
                  color: statusColor,
                  size: 28,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conductor['nombre_completo'] ?? 'Sin nombre',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                conductor['email'] ?? 'Sin email',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _buildStatusBadge(context, statusColor),
      ],
    );
  }

  Widget _buildShimmerContainer({required double width, required double height, double borderRadius = 8}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, Color color) {
    final estado = conductor['estado_verificacion'] ?? 'pendiente';
    final esSolicitud = conductor['es_solicitud_pendiente'] == true;
    final estadoSolicitud = conductor['estado_solicitud'];
    
    String label = _getStatusLabel(estado);
    Color badgeColor = color;

    if (esSolicitud) {
      if (estadoSolicitud == 'rechazada') {
        label = 'Rechazado';
        badgeColor = AppColors.error;
      } else {
        label = 'Solicitud';
        badgeColor = AppColors.warning;
      }
    } else if (estado == 'pendiente' || estado == null) {
      label = 'Docs Pendientes';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoItem(
            context,
            Icons.badge_outlined,
            'Licencia',
            conductor['licencia_conduccion'] ?? 'N/A',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoItem(
            context,
            Icons.directions_car_outlined,
            'Placa',
            ColombianPlateUtils.formatForDisplay(
              conductor['vehiculo_placa']?.toString(),
              fallback: 'N/A',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(BuildContext context, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentProgress(BuildContext context, Color statusColor) {
    final completed = int.tryParse(conductor['documentos_completos']?.toString() ?? '0') ?? 0;
    final total = int.tryParse(conductor['total_documentos_requeridos']?.toString() ?? '7') ?? 7;
    final percentage = total > 0 ? completed / total : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Documentos: $completed/$total',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            Text(
              '${(percentage * 100).toInt()}%',
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation(statusColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildExpiredWarning(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 14),
          const SizedBox(width: 6),
          Text(
            'Documentos vencidos',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (isLoading) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Row(
          children: [
            Expanded(child: _buildShimmerButton()),
            const SizedBox(width: 8),
            Expanded(child: _buildShimmerButton()),
          ],
        ),
      );
    }

    final estado = conductor['estado_verificacion'] ?? 'pendiente';
    
    if (estado == 'aprobado') {
      return _buildApprovedActions(context);
    }

    final estadoSolicitud = conductor['estado_solicitud'];

    if (estado == 'rechazado' || estadoSolicitud == 'rechazada') {
      return _buildRejectedStatus(context);
    }
    
    return _buildPendingActions(context);
  }

  Widget _buildPendingActions(BuildContext context) {
    return Row(
      children: [
        if (onRechazar != null)
          Expanded(
            child: _buildActionButton(
              context,
              icon: Icons.close_rounded,
              label: 'Rechazar',
              color: AppColors.error,
              onTap: onRechazar!,
              isOutlined: true,
            ),
          ),
        if (onRechazar != null && onAprobar != null)
          const SizedBox(width: 8),
        if (onAprobar != null)
          Expanded(
            child: _buildActionButton(
              context,
              icon: Icons.check_circle_outline,
              label: 'Aprobar',
              color: AppColors.success,
              onTap: onAprobar!,
              isFilled: true,
            ),
          ),
      ],
    );
  }

  Widget _buildApprovedActions(BuildContext context) {
    if (isLoading) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildShimmerButton()),
                const SizedBox(width: 8),
                Expanded(child: _buildShimmerButton()),
              ],
            ),
            const SizedBox(height: 8),
            _buildShimmerButton(),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Botón de estado principal (Desactivar/Activar)
        Row(
          children: [
            if (onDesactivar != null)
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.block_rounded,
                  label: 'Desactivar',
                  color: AppColors.warning,
                  onTap: onDesactivar!,
                  isFilled: false,
                ),
              ),
            if (onDesvincular != null) ...[
              const SizedBox(width: 8),
              _buildIconActionButton(
                context,
                icon: Icons.link_off_rounded,
                color: AppColors.error,
                onTap: onDesvincular!,
                tooltip: 'Desvincular',
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildIconActionButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip ?? '',
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerButton() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
    );
  }

  Widget _buildRejectedStatus(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cancel_rounded, color: AppColors.error, size: 16),
          const SizedBox(width: 6),
          Text(
            'Conductor rechazado',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isFilled = false,
    bool isOutlined = false,
  }) {
    final backgroundColor = isFilled 
        ? color 
        : (isOutlined ? Colors.transparent : color.withValues(alpha: 0.1));
        
    final textColor = isFilled ? Colors.white : color;
    final borderColor = isOutlined ? color.withValues(alpha: 0.5) : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(30), // Pill shape
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(30),
            border: isOutlined ? Border.all(color: borderColor) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              else ...[
                Icon(icon, size: 16, color: textColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _hasExpiredDocuments() {
    return conductor['tiene_documentos_vencidos'] == true;
  }

  Color _getStatusColor(String estado) {
    switch (estado) {
      case 'aprobado':
        return AppColors.success;
      case 'rechazado':
        return AppColors.error;
      case 'en_revision':
        return AppColors.primary;
      case 'pendiente':
      default:
        return AppColors.warning;
    }
  }

  String _getStatusLabel(String estado) {
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
}
