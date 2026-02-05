import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';
import '../../../domain/models/company_vehicle_models.dart';
import '../../../../../global/services/auth/user_service.dart';

/// Widget para seleccionar empresa manualmente
/// Muestra chips con las empresas disponibles para el tipo de vehículo seleccionado
class CompanySelectorWidget extends StatelessWidget {
  final List<CompanyVehicleOption> empresas;
  final int? selectedEmpresaId;
  final ValueChanged<int> onEmpresaChanged;
  final bool isDark;
  final bool isCompact;

  const CompanySelectorWidget({
    super.key,
    required this.empresas,
    required this.selectedEmpresaId,
    required this.onEmpresaChanged,
    required this.isDark,
    this.isCompact = true,
  });

  @override
  Widget build(BuildContext context) {
    if (empresas.length <= 1) {
      // Solo hay una empresa, no mostrar selector
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.business_rounded,
                size: 16,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              const SizedBox(width: 6),
              Text(
                'Seleccionar empresa',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: isCompact ? 36 : 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: empresas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final empresa = empresas[index];
                final isSelected = empresa.id == selectedEmpresaId;
                
                return _CompanyChip(
                  empresa: empresa,
                  isSelected: isSelected,
                  isDark: isDark,
                  isCompact: isCompact,
                  onTap: () => onEmpresaChanged(empresa.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyChip extends StatelessWidget {
  final CompanyVehicleOption empresa;
  final bool isSelected;
  final bool isDark;
  final bool isCompact;
  final VoidCallback onTap;

  const _CompanyChip({
    required this.empresa,
    required this.isSelected,
    required this.isDark,
    required this.isCompact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 16,
          vertical: isCompact ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark ? Colors.white10 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(isCompact ? 18 : 24),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo o icono
            if (empresa.logoUrl != null && empresa.logoUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  UserService.getR2ImageUrl(empresa.logoUrl),
                  width: isCompact ? 18 : 24,
                  height: isCompact ? 18 : 24,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.business,
                    size: isCompact ? 16 : 20,
                    color: isSelected ? AppColors.primary : (isDark ? Colors.white60 : Colors.black45),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            // Nombre
            Text(
              empresa.nombre,
              style: TextStyle(
                fontSize: isCompact ? 12 : 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            // Indicador de conductores cercanos
            if (!isCompact) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, size: 12, color: Colors.green),
                    const SizedBox(width: 2),
                    Text(
                      '${empresa.conductores}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Check si está seleccionado
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.check_circle,
                size: isCompact ? 14 : 18,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget que muestra información de la empresa seleccionada
class SelectedCompanyBadge extends StatelessWidget {
  final CompanyVehicleOption? empresa;
  final bool isDark;
  final VoidCallback? onTap;

  const SelectedCompanyBadge({
    super.key,
    required this.empresa,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (empresa == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.business_rounded,
              size: 12,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              empresa!.nombre,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
