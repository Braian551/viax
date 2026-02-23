import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';
import 'package:viax/src/features/company/presentation/widgets/company_logo.dart';

/// Header de la búsqueda: controles rápidos + tag de empresa/vehículo.
class SearchingDriverHeader extends StatelessWidget {
  const SearchingDriverHeader({
    super.key,
    required this.isDark,
    required this.formattedTime,
    required this.currentRadiusKm,
    required this.vehicleLabel,
    required this.vehicleImagePath,
    required this.companyName,
    required this.companyLogoKey,
    required this.onClose,
    required this.onCompanyTap,
  });

  final bool isDark;
  final String formattedTime;
  final double currentRadiusKm;
  final String vehicleLabel;
  final String vehicleImagePath;
  final String companyName;
  final String? companyLogoKey;
  final VoidCallback onClose;
  final VoidCallback onCompanyTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (isDark ? Colors.black : Colors.white),
            (isDark ? Colors.black : Colors.white).withValues(alpha: 0.0),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: isDark ? Colors.white12 : Colors.white,
                borderRadius: BorderRadius.circular(14),
                elevation: isDark ? 0 : 2,
                child: InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip(
                          Icons.timer_outlined,
                          formattedTime,
                          isDark,
                        ),
                        _buildInfoChip(
                          Icons.radar_rounded,
                          '${currentRadiusKm.toStringAsFixed(0)} km',
                          isDark,
                          highlighted: currentRadiusKm > 2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildVehicleCompanyChip(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, bool dark, {bool highlighted = false}) {
    // Chip reutilizable para tiempo/radio.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.primary.withValues(alpha: 0.15)
            : (dark ? Colors.white12 : Colors.white),
        borderRadius: BorderRadius.circular(20),
        boxShadow: dark
            ? null
            : [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: highlighted ? AppColors.primary : (dark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: highlighted ? AppColors.primary : (dark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCompanyChip() {
    // Tag glass interactivo que abre detalle de empresa.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onCompanyTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.75),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: Image.asset(
                      vehicleImagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.directions_car,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '$vehicleLabel · $companyName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  if (companyLogoKey != null && companyLogoKey!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CompanyLogo(
                        logoKey: companyLogoKey,
                        nombreEmpresa: companyName,
                        size: 18,
                        fontSize: 9,
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
