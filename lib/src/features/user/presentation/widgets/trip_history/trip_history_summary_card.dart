import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Widget para mostrar estadísticas individuales con diseño moderno
class TripHistorySummaryCard extends StatefulWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final int index;
  final bool isDark;

  const TripHistorySummaryCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.index = 0,
    this.isDark = false,
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

  List<Color> _getGradientColors() {
    // Generar gradientes basados en el color base
    if (widget.color == AppColors.primary) { // Blue
      return [
        const Color(0xFF2196F3).withValues(alpha: 0.2), 
        const Color(0xFF1976D2).withValues(alpha: 0.05)
      ];
    } else if (widget.color == AppColors.success) { // Green
      return [
        const Color(0xFF4CAF50).withValues(alpha: 0.2), 
        const Color(0xFF388E3C).withValues(alpha: 0.05)
      ];
    } else if (widget.color == AppColors.error) { // Red
      return [
        const Color(0xFFF44336).withValues(alpha: 0.2), 
        const Color(0xFFD32F2F).withValues(alpha: 0.05)
      ];
    }
    return [
      widget.color.withValues(alpha: 0.2),
      widget.color.withValues(alpha: 0.05),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = _getGradientColors();
    final textColor = widget.isDark 
        ? Colors.white 
        : Colors.black87;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isDark 
                  ? [
                      const Color(0xFF2C2C2C),
                      const Color(0xFF1E1E1E),
                    ]
                  : [
                      Colors.white,
                      const Color(0xFFF5F5F5),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: widget.isDark ? 0.15 : 0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              ),
            ],
            border: Border.all(
              color: widget.isDark 
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 12),
              
              // Value
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.value,
                  style: TextStyle(
                    fontSize: 24, // Larger font
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              
              // Label
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
  final bool isDark;

  const TripHistorySummaryGrid({
    super.key,
    required this.totalViajes,
    required this.completados,
    required this.cancelados,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20), // More padding
      child: Row(
        children: [
          Expanded(
            child: TripHistorySummaryCard(
              icon: Icons.directions_car_filled_rounded,
              value: totalViajes.toString(),
              label: 'Total',
              color: const Color(0xFF2196F3), // Bright Blue
              index: 0,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TripHistorySummaryCard(
              icon: Icons.check_circle_rounded,
              value: completados.toString(),
              label: 'Completados',
              color: const Color(0xFF4CAF50), // Bright Green
              index: 1,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TripHistorySummaryCard(
              icon: Icons.cancel_rounded,
              value: cancelados.toString(),
              label: 'Cancelados',
              color: const Color(0xFFF44336), // Bright Red
              index: 2,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}
