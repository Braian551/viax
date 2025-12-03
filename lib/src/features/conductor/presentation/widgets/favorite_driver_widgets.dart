import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_colors.dart';
import '../../models/confianza_model.dart';
import '../../services/trusted_driver_service.dart';

/// Widget para marcar/desmarcar un conductor como favorito
/// 
/// Muestra un icono de estrella que cambia según el estado
/// y permite alternar el estado con un tap
class FavoriteDriverButton extends StatefulWidget {
  final int usuarioId;
  final int conductorId;
  final bool initialValue;
  final double size;
  final VoidCallback? onChanged;

  const FavoriteDriverButton({
    super.key,
    required this.usuarioId,
    required this.conductorId,
    this.initialValue = false,
    this.size = 24,
    this.onChanged,
  });

  @override
  State<FavoriteDriverButton> createState() => _FavoriteDriverButtonState();
}

class _FavoriteDriverButtonState extends State<FavoriteDriverButton>
    with SingleTickerProviderStateMixin {
  late bool _isFavorite;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.initialValue;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await TrustedDriverService.toggleFavorite(
        usuarioId: widget.usuarioId,
        conductorId: widget.conductorId,
      );

      if (mounted) {
        setState(() {
          _isFavorite = result;
          _isLoading = false;
        });

        // Animación de escala
        _animationController.forward().then((_) {
          _animationController.reverse();
        });

        widget.onChanged?.call();
        
        // Mostrar feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isFavorite
                      ? 'Conductor agregado a favoritos'
                      : 'Conductor removido de favoritos',
                ),
              ],
            ),
            backgroundColor: _isFavorite ? AppColors.accent : Colors.grey,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleFavorite,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isFavorite
                ? AppColors.accent.withOpacity(0.15)
                : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: _isLoading
              ? SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              : Icon(
                  _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: _isFavorite ? AppColors.accent : Colors.grey,
                  size: widget.size,
                ),
        ),
      ),
    );
  }
}

/// Widget que muestra el indicador de nivel de confianza
class TrustLevelIndicator extends StatelessWidget {
  final ConfianzaInfo confianza;
  final bool showLabel;
  final double size;

  const TrustLevelIndicator({
    super.key,
    required this.confianza,
    this.showLabel = true,
    this.size = 16,
  });

  Color get _color {
    switch (confianza.nivel) {
      case NivelConfianza.muyAlto:
        return Colors.green.shade700;
      case NivelConfianza.alto:
        return AppColors.accent;
      case NivelConfianza.medio:
        return Colors.blue;
      case NivelConfianza.bajo:
        return Colors.orange;
      case NivelConfianza.nuevo:
        return Colors.grey;
    }
  }

  IconData get _icon {
    switch (confianza.nivel) {
      case NivelConfianza.muyAlto:
        return Icons.verified_rounded;
      case NivelConfianza.alto:
        return Icons.workspace_premium_rounded;
      case NivelConfianza.medio:
        return Icons.thumb_up_rounded;
      case NivelConfianza.bajo:
        return Icons.history_rounded;
      case NivelConfianza.nuevo:
        return Icons.person_outline_rounded;
    }
  }

  String get _label {
    switch (confianza.nivel) {
      case NivelConfianza.muyAlto:
        return 'Muy confiable';
      case NivelConfianza.alto:
        return 'Favorito';
      case NivelConfianza.medio:
        return 'Conocido';
      case NivelConfianza.bajo:
        return 'Previo';
      case NivelConfianza.nuevo:
        return 'Nuevo';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 8 : 4,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color, size: size),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              _label,
              style: TextStyle(
                color: _color,
                fontSize: size * 0.75,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (confianza.viajesPrevios > 0 && showLabel) ...[
            const SizedBox(width: 4),
            Text(
              '(${confianza.viajesPrevios})',
              style: TextStyle(
                color: _color.withOpacity(0.7),
                fontSize: size * 0.65,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Badge pequeño para mostrar cuando un conductor es favorito
class FavoriteBadge extends StatelessWidget {
  final bool isFavorite;
  final double size;

  const FavoriteBadge({
    super.key,
    required this.isFavorite,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (!isFavorite) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.star_rounded,
        color: Colors.white,
        size: size,
      ),
    );
  }
}
