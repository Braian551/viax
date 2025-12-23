import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';
import '../../../services/conductor_earnings_service.dart';
import '../../../../user/presentation/widgets/trip_preview/trip_price_formatter.dart';

/// Item individual del desglose de ganancias
class EarningsBreakdownItem extends StatefulWidget {
  final String label;
  final double amount;
  final double percentage;
  final int index;

  const EarningsBreakdownItem({
    super.key,
    required this.label,
    required this.amount,
    required this.percentage,
    this.index = 0,
  });

  @override
  State<EarningsBreakdownItem> createState() => _EarningsBreakdownItemState();
}

class _EarningsBreakdownItemState extends State<EarningsBreakdownItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: widget.percentage / 100).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    Future.delayed(Duration(milliseconds: 100 + (widget.index * 80)), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkCard.withValues(alpha: 0.6)
                    : Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        formatCurrency(widget.amount),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return LinearProgressIndicator(
                          value: _progressAnimation.value,
                          minHeight: 6,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        );
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
}

/// Sección completa de desglose de ganancias
class EarningsBreakdownSection extends StatelessWidget {
  final double total;
  final List<EarningsDayModel>? dailyBreakdown;

  const EarningsBreakdownSection({
    super.key,
    required this.total,
    this.dailyBreakdown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;

    // Calcular porcentajes del total (solo viajes completados en efectivo)
    final viajesAmount = total;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de Ingresos',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          EarningsBreakdownItem(
            label: 'Viajes completados',
            amount: viajesAmount,
            percentage: 100,
            index: 0,
          ),
          // Si hay desglose diario, mostrarlo
          if (dailyBreakdown != null && dailyBreakdown!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDailyBreakdown(isDark, textColor),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyBreakdown(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Últimos días',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...dailyBreakdown!.take(5).toList().asMap().entries.map((entry) {
          final index = entry.key;
          final day = entry.value;
          return _DailyEarningsItem(
            date: day.fecha,
            amount: day.ganancias,
            trips: day.viajes,
            index: index,
            isDark: isDark,
          );
        }),
      ],
    );
  }
}

class _DailyEarningsItem extends StatelessWidget {
  final String date;
  final double amount;
  final int trips;
  final int index;
  final bool isDark;

  const _DailyEarningsItem({
    required this.date,
    required this.amount,
    required this.trips,
    required this.index,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final subtitleColor = isDark ? Colors.white60 : AppColors.lightTextSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$trips viajes',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatCurrency(amount),
            style: TextStyle(
              color: AppColors.success,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
