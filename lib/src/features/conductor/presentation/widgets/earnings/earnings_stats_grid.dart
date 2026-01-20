import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';
import '../../../../user/presentation/widgets/trip_preview/trip_price_formatter.dart';

/// Card de estadística individual
/// Diseño compacto con animaciones de entrada
class EarningsStatCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final int index;

  const EarningsStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.index = 0,
  });

  @override
  State<EarningsStatCard> createState() => _EarningsStatCardState();
}

class _EarningsStatCardState extends State<EarningsStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 400 + (widget.index * 100)),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(Duration(milliseconds: widget.index * 100), () {
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.color.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.value,
                      key: ValueKey(widget.value),
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid de estadísticas (viajes y promedio)
class EarningsStatsGrid extends StatelessWidget {
  final int totalTrips;
  final double averagePerTrip;
  final double comisionPeriodo;

  const EarningsStatsGrid({
    super.key,
    required this.totalTrips,
    required this.averagePerTrip,
    this.comisionPeriodo = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: Row(
              children: [
                Expanded(
                  child: EarningsStatCard(
                    icon: Icons.route_rounded,
                    label: 'Viajes',
                    value: '$totalTrips',
                    color: AppColors.primary,
                    index: 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EarningsStatCard(
                    icon: Icons.trending_up_rounded,
                    label: 'Promedio',
                    value: formatCurrency(averagePerTrip),
                    color: AppColors.accent,
                    index: 1,
                  ),
                ),
              ],
            ),
          ),
          if (comisionPeriodo > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: EarningsStatCard(
                icon: Icons.receipt_long_rounded,
                label: 'Comisión período',
                value: formatCurrency(comisionPeriodo),
                color: Colors.orange,
                index: 2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
