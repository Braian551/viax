import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget de calificación con estrellas animadas.
/// 
/// Reutilizable tanto para conductor como para cliente.
/// Soporta diferentes tamaños y estilos.
class StarRatingWidget extends StatefulWidget {
  /// Calificación inicial (0-5).
  final int initialRating;
  
  /// Callback cuando cambia la calificación.
  final ValueChanged<int>? onRatingChanged;
  
  /// Tamaño de las estrellas.
  final double starSize;
  
  /// Espaciado entre estrellas.
  final double spacing;
  
  /// Si es de solo lectura.
  final bool readOnly;
  
  /// Color de estrella seleccionada.
  final Color? activeColor;
  
  /// Color de estrella no seleccionada.
  final Color? inactiveColor;
  
  /// Mostrar etiqueta debajo.
  final bool showLabel;

  const StarRatingWidget({
    super.key,
    this.initialRating = 0,
    this.onRatingChanged,
    this.starSize = 40,
    this.spacing = 4,
    this.readOnly = false,
    this.activeColor,
    this.inactiveColor,
    this.showLabel = true,
  });

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget>
    with SingleTickerProviderStateMixin {
  late int _currentRating;
  late AnimationController _controller;
  int? _animatingIndex;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setRating(int rating) {
    if (widget.readOnly) return;
    
    HapticFeedback.lightImpact();
    setState(() {
      _currentRating = rating;
      _animatingIndex = rating - 1;
    });
    
    _controller.forward(from: 0).then((_) {
      if (mounted) setState(() => _animatingIndex = null);
    });
    
    widget.onRatingChanged?.call(rating);
  }

  String get _ratingLabel {
    switch (_currentRating) {
      case 1:
        return 'Muy malo';
      case 2:
        return 'Malo';
      case 3:
        return 'Regular';
      case 4:
        return 'Bueno';
      case 5:
        return '¡Excelente!';
      default:
        return 'Toca para calificar';
    }
  }

  Color get _labelColor {
    if (_currentRating == 0) return Colors.grey;
    if (_currentRating <= 2) return Colors.red;
    if (_currentRating == 3) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = widget.activeColor ?? Colors.amber;
    final inactiveColor = widget.inactiveColor ?? 
        (isDark ? Colors.white24 : Colors.grey[300]);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starNumber = index + 1;
            final isSelected = starNumber <= _currentRating;
            final isAnimating = _animatingIndex == index;

            return GestureDetector(
              onTap: () => _setRating(starNumber),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.spacing),
                child: AnimatedScale(
                  scale: isAnimating ? 1.3 : (isSelected ? 1.1 : 1.0),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.elasticOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isSelected 
                          ? Icons.star_rounded 
                          : Icons.star_outline_rounded,
                      color: isSelected ? activeColor : inactiveColor,
                      size: widget.starSize,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (widget.showLabel) ...[
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _ratingLabel,
              key: ValueKey(_currentRating),
              style: TextStyle(
                color: _labelColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Widget compacto de calificación (solo lectura).
class StarRatingCompact extends StatelessWidget {
  final double rating;
  final double size;
  final Color? color;

  const StarRatingCompact({
    super.key,
    required this.rating,
    this.size = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? Colors.amber;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: starColor, size: size),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: starColor,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.9,
          ),
        ),
      ],
    );
  }
}
