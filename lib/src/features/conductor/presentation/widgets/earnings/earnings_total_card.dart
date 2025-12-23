import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';
import '../../../../user/presentation/widgets/trip_preview/trip_price_formatter.dart';

/// Card principal de ganancias totales
/// Diseño glassmorphism con animaciones suaves
class EarningsTotalCard extends StatefulWidget {
  final double total;
  final String periodLabel;
  final int totalTrips;
  final bool isLoading;

  const EarningsTotalCard({
    super.key,
    required this.total,
    required this.periodLabel,
    this.totalTrips = 0,
    this.isLoading = false,
  });

  @override
  State<EarningsTotalCard> createState() => _EarningsTotalCardState();
}

class _EarningsTotalCardState extends State<EarningsTotalCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.success.withValues(alpha: 0.25),
                    AppColors.success.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.15),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 24),
                  _buildAmount(isDark),
                  const SizedBox(height: 8),
                  _buildPeriodLabel(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Icono de efectivo
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.payments_rounded,
            color: AppColors.success,
            size: 28,
          ),
        ),
        // Badge de efectivo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.monetization_on_rounded,
                color: AppColors.success,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Efectivo',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmount(bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ganancias en Efectivo',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.7),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 56),
            child: FittedBox(
              key: ValueKey<double>(widget.total),
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatCurrency(widget.total),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  height: 0.92,
                  letterSpacing: -2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodLabel(bool isDark) {
    final subtitleColor = isDark ? Colors.white60 : AppColors.lightTextSecondary;

    return Row(
      children: [
        Icon(
          Icons.calendar_today_rounded,
          color: subtitleColor,
          size: 14,
        ),
        const SizedBox(width: 6),
        Text(
          widget.periodLabel,
          style: TextStyle(
            color: subtitleColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        if (widget.totalTrips > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${widget.totalTrips} viajes',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
