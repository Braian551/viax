import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Widget para mostrar estadísticas individuales (viajes, cancelados, etc)
class TripHistorySummaryCard extends StatefulWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final int index;

  const TripHistorySummaryCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.index = 0,
  });

  @override
  State<TripHistorySummaryCard> createState() => _TripHistorySummaryCardState();
}

class _TripHistorySummaryCardState extends State<TripHistorySummaryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 500 + (widget.index * 100)),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: widget.color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.lightTextPrimary.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid de tarjetas de resumen
class TripHistorySummaryGrid extends StatelessWidget {
  final int totalViajes;
  final int completados;
  final int cancelados;

  const TripHistorySummaryGrid({
    super.key,
    required this.totalViajes,
    required this.completados,
    required this.cancelados,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TripHistorySummaryCard(
              icon: Icons.directions_car_rounded,
              value: totalViajes.toString(),
              label: 'Total viajes',
              color: AppColors.primary,
              index: 0,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TripHistorySummaryCard(
              icon: Icons.check_circle_rounded,
              value: completados.toString(),
              label: 'Completados',
              color: AppColors.success,
              index: 1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TripHistorySummaryCard(
              icon: Icons.cancel_rounded,
              value: cancelados.toString(),
              label: 'Cancelados',
              color: AppColors.error,
              index: 2,
            ),
          ),
        ],
      ),
    );
  }
}
