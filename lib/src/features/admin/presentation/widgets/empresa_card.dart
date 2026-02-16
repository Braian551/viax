import 'package:flutter/material.dart';
import 'package:viax/src/features/admin/domain/entities/empresa_transporte.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/features/company/presentation/widgets/company_logo.dart';
import 'package:shimmer/shimmer.dart';

/// Card que muestra información resumida de una empresa
class EmpresaCard extends StatelessWidget {
  final EmpresaTransporte empresa;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onSetCommission;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const EmpresaCard({
    super.key,
    required this.empresa,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onToggleStatus,
    this.onSetCommission,
    this.onApprove,
    this.onReject,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
            color: _getStatusColor(empresa.estado).withValues(alpha: 0.3),
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
                  _buildHeader(context),
                  const SizedBox(height: 12),
                  _buildInfo(context),
                  if (empresa.tiposVehiculo.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildVehicleTypes(context),
                  ],
                  const SizedBox(height: 12),
                  _buildStats(context),
                  const SizedBox(height: 12),
                  _buildActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // Logo o icono
        CompanyLogo(
          logoKey: empresa.logoUrl,
          nombreEmpresa: empresa.nombre,
          size: 50,
          fontSize: 20,
        ),
        const SizedBox(width: 12),
        // Nombre y estado
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                empresa.nombre,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (empresa.nit != null && empresa.nit!.isNotEmpty)
                Text(
                  'NIT: ${empresa.nit}',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        // Badge de estado
        _buildStatusBadge(context),
      ],
    );
  }



  Widget _buildStatusBadge(BuildContext context) {
    final color = _getStatusColor(empresa.estado);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            empresa.estado.displayName,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (empresa.municipio != null || empresa.departamento != null)
          _buildInfoRow(
            context,
            Icons.location_on_outlined,
            [empresa.municipio, empresa.departamento]
                .where((e) => e != null && e.isNotEmpty)
                .join(', '),
          ),
        if (empresa.telefono != null && empresa.telefono!.isNotEmpty)
          _buildInfoRow(context, Icons.phone_outlined, empresa.telefono!),
        if (empresa.email != null && empresa.email!.isNotEmpty)
          _buildInfoRow(context, Icons.email_outlined, empresa.email!),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTypes(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: empresa.tiposVehiculo.map((tipo) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getVehicleIcon(tipo),
                size: 12,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                _formatVehicleType(tipo),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStats(BuildContext context) {
    return Row(
      children: [
        _buildStatItem(
          context,
          Icons.people_outline,
          '${empresa.totalConductores}',
          'Conductores',
        ),
        const SizedBox(width: 16),
        _buildStatItem(
          context,
          Icons.directions_car_outlined,
          '${empresa.totalViajesCompletados}',
          'Viajes',
        ),
        const SizedBox(width: 16),
        _buildStatItem(
          context,
          Icons.star_outline,
          empresa.calificacionPromedio.toStringAsFixed(1),
          'Rating',
        ),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
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
             Row(
               children: [
                 Expanded(child: _buildShimmerButton()),
                 const SizedBox(width: 8),
                 Container(
                   width: 40,
                   height: 40,
                   decoration: BoxDecoration(
                     color: Colors.white,
                     borderRadius: BorderRadius.circular(12),
                   ),
                 ),
               ],
             ),
          ],
        ),
      );
    }

    // Si la empresa está pendiente, mostrar botones de aprobar/rechazar
    if (empresa.estado == EmpresaEstado.pendiente && (onApprove != null || onReject != null)) {
      return Row(
        children: [
          if (onReject != null)
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.close_rounded,
                label: 'Rechazar',
                color: AppColors.error,
                onTap: onReject!,
                isOutlined: true,
              ),
            ),
          if (onReject != null && onApprove != null)
            const SizedBox(width: 8),
          if (onApprove != null)
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.check_rounded,
                label: 'Aprobar',
                color: AppColors.success,
                onTap: onApprove!,
                isFilled: true,
              ),
            ),
        ],
      );
    }
    
    // Acciones normales para empresas no pendientes
    return Column(
      children: [
        Row(
          children: [
            if (onSetCommission != null)
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.percent_rounded,
                  label: 'Comisión',
                  color: AppColors.primary,
                  onTap: onSetCommission!,
                ),
              ),
            if (onSetCommission != null && onEdit != null)
              const SizedBox(width: 8),
            if (onEdit != null)
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.edit_rounded,
                  label: 'Editar',
                  color: AppColors.blue600,
                  onTap: onEdit!,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (onToggleStatus != null)
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: empresa.estado == EmpresaEstado.activo 
                      ? Icons.pause_rounded 
                      : Icons.play_arrow_rounded,
                  label: empresa.estado == EmpresaEstado.activo ? 'Desactivar' : 'Activar',
                  color: empresa.estado == EmpresaEstado.activo 
                      ? AppColors.warning 
                      : AppColors.success,
                  onTap: onToggleStatus!,
                ),
              ),
             if (onDelete != null) ...[
               const SizedBox(width: 8),
               _buildDeleteButton(),
             ],
          ],
        ),
      ],
    );
  }

  Widget _buildDeleteButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDelete,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.error,
            size: 20,
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

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isFilled = false,
    bool isOutlined = false,
  }) {
    // Tonal style by default: color with low alpha, no border
    final backgroundColor = isFilled 
        ? color 
        : (isOutlined ? Colors.transparent : color.withValues(alpha: 0.1));
        
    final textColor = isFilled ? Colors.white : color;
    final borderColor = isOutlined ? color.withValues(alpha: 0.5) : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30), // Fully rounded
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(30),
            border: isOutlined ? Border.all(color: borderColor) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(EmpresaEstado estado) {
    switch (estado) {
      case EmpresaEstado.activo:
        return AppColors.success;
      case EmpresaEstado.inactivo:
        return Colors.grey;
      case EmpresaEstado.suspendido:
        return AppColors.error;
      case EmpresaEstado.pendiente:
        return AppColors.warning;
      case EmpresaEstado.eliminado:
        return AppColors.error;
    }
  }

  IconData _getVehicleIcon(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'moto':
        return Icons.two_wheeler;
      case 'motocarro':
        return Icons.electric_rickshaw;
      case 'taxi':
        return Icons.local_taxi;
      case 'carro':
        return Icons.directions_car;
      default:
        return Icons.directions_car;
    }
  }

  String _formatVehicleType(String tipo) {
    return tipo[0].toUpperCase() + tipo.substring(1).toLowerCase();
  }
}
