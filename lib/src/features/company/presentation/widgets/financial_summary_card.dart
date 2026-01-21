import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Widget de tarjeta para mostrar información financiera resumida.
/// Reutilizable en pantallas de pricing, dashboard, y reportes.
class FinancialSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool showWarning;

  const FinancialSummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    this.showWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: showWarning 
                ? AppColors.warning.withValues(alpha: 0.5)
                : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
            width: showWarning ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (onTap != null) ...[
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark 
                        ? AppColors.darkTextSecondary 
                        : AppColors.lightTextSecondary,
                    size: 20,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (subtitle != null) ...[
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (title.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget para mostrar la fila de resumen de plataforma y cuenta
/// Específico para la pantalla de pricing de empresa
class PlatformBalanceSummary extends StatelessWidget {
  final double comisionPorcentaje;
  final double saldoPendiente;
  final VoidCallback? onCuentaTap;

  const PlatformBalanceSummary({
    super.key,
    required this.comisionPorcentaje,
    required this.saldoPendiente,
    this.onCuentaTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDebt = saldoPendiente > 0;

    return Row(
      children: [
        // Commission Card (Plataforma)
        Expanded(
          child: FinancialSummaryCard(
            title: 'Plataforma',
            value: '${comisionPorcentaje.toStringAsFixed(1)}%',
            subtitle: 'Comisión',
            icon: Icons.percent_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        // Balance Card (Cuenta)
        Expanded(
          child: FinancialSummaryCard(
            title: hasDebt ? 'Por pagar' : 'Al día',
            value: '\$${_formatNumber(saldoPendiente)}',
            subtitle: 'Cuenta',
            icon: hasDebt
                ? Icons.account_balance_wallet_rounded
                : Icons.check_circle_outline_rounded,
            color: hasDebt ? AppColors.warning : AppColors.success,
            showWarning: hasDebt,
            onTap: onCuentaTap,
          ),
        ),
      ],
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }
}
