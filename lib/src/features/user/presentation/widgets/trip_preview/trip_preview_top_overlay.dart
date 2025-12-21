import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../../global/models/simple_location.dart';
import '../../../../../theme/app_colors.dart';
import '../../../domain/models/trip_models.dart';

class TripPreviewTopOverlay extends StatefulWidget {
  const TripPreviewTopOverlay({
    super.key,
    required this.slideAnimation,
    required this.fadeAnimation,
    required this.isDark,
    required this.quote,
    required this.origin,
    required this.destination,
    required this.stops,
    required this.onBack,
    required this.onLocationTap,
  });

  final Animation<Offset> slideAnimation;
  final Animation<double> fadeAnimation;
  final bool isDark;
  final TripQuote? quote;
  final SimpleLocation origin;
  final SimpleLocation destination;
  final List<SimpleLocation> stops;
  final VoidCallback onBack;
  final VoidCallback onLocationTap;

  @override
  State<TripPreviewTopOverlay> createState() => _TripPreviewTopOverlayState();
}

class _TripPreviewTopOverlayState extends State<TripPreviewTopOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _snapController;
  late final Animation<double> _snapCurve;
  double _animationStart = 1.0;
  double _animationEnd = 1.0;
  double _expansion = 1.0; // Siempre expandido por defecto

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _snapCurve =
        CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic)
          ..addListener(() {
            setState(() {
              _expansion = lerpDouble(
                _animationStart,
                _animationEnd,
                _snapCurve.value,
              )!;
            });
          });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  double get _locationHeightFactor {
    // Curva más suave para el clip
    final curve = Curves.easeOutQuart.transform(_expansion);
    return lerpDouble(0.0, 1.0, curve)!.clamp(0.0, 1.0);
  }

  double get _contentOpacity {
    // Fade out del contenido cuando está colapsando
    if (_expansion > 0.7) return 1.0;
    if (_expansion < 0.3) return 0.0;
    return ((_expansion - 0.3) / 0.4).clamp(0.0, 1.0);
  }

  bool get _isCollapsed => _expansion < 0.5;

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.delta.dy;
    setState(() {
      // Sensibilidad: cada 100px de drag = cambio completo
      _expansion = (_expansion + (delta / 100)).clamp(0.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    double target;

    // Sensibilidad mejorada de velocidad
    if (velocity.abs() > 300) {
      target = velocity > 0 ? 1.0 : 0.0;
    } else {
      // Snap point más inteligente
      target = _expansion >= 0.45 ? 1.0 : 0.0;
    }
    _animateTo(target);
  }

  void _toggleExpansion() {
    final target = _expansion >= 0.5 ? 0.0 : 1.0;
    _animateTo(target);
  }

  void _animateTo(double target) {
    if ((_expansion - target).abs() < 0.01) {
      setState(() => _expansion = target);
      return;
    }
    _animationStart = _expansion;
    _animationEnd = target;
    _snapController
      ..stop()
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: widget.slideAnimation,
          child: FadeTransition(
            opacity: widget.fadeAnimation,
            child: Container(
              margin: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                        color: widget.isDark
                          ? Colors.black.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: widget.isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.08),
                          blurRadius: 25,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header fijo con botón y badges
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: Row(
                            children: [
                              _GlassBackButton(onBack: widget.onBack),
                              const SizedBox(width: 12),
                              if (widget.quote != null)
                                Expanded(
                                  child: _InfoBadge(
                                    quote: widget.quote!,
                                    isDark: widget.isDark,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Divider
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                    widget.isDark
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.black.withValues(alpha: 0.1),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Contenido de ubicaciones colapsable
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Stack(
                            children: [
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                opacity: _contentOpacity,
                                child: ClipRect(
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    heightFactor: _locationHeightFactor,
                                    child: Column(
                                      children: [
                                        _LocationRow(
                                          icon: Icons.my_location,
                                          iconSize: 14,
                                          color: AppColors.primary,
                                          text: widget.origin.address,
                                          isOrigin: true,
                                          isDark: widget.isDark,
                                          onTap: widget.onLocationTap,
                                        ),
                                        for (final stop in widget.stops) ...[
                                          _ConnectorLine(isDark: widget.isDark),
                                          _LocationRow(
                                            icon: Icons.stop_circle_outlined,
                                            iconSize: 12,
                                            color: AppColors.accent,
                                            text: stop.address,
                                            isOrigin: false,
                                            isDark: widget.isDark,
                                            onTap: widget.onLocationTap,
                                          ),
                                        ],
                                        _DottedConnector(isDark: widget.isDark),
                                        _LocationRow(
                                          icon: Icons.location_on,
                                          iconSize: 16,
                                          color: AppColors.primaryDark,
                                          text: widget.destination.address,
                                          isOrigin: false,
                                          isDark: widget.isDark,
                                          onTap: widget.onLocationTap,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Gradiente de fade mejorado
                              if (_expansion < 0.95)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: IgnorePointer(
                                    child: AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      opacity: (1.0 - _expansion).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      child: Container(
                                        height: 40,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              widget.isDark
                                                  ? Colors.black.withValues(
                                                      alpha: 0.75,
                                                    )
                                                  : Colors.white.withValues(
                                                      alpha: 0.92,
                                                    ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Handle de drag en la parte inferior
                        GestureDetector(
                          onTap: _toggleExpansion,
                          onVerticalDragUpdate: _handleDragUpdate,
                          onVerticalDragEnd: _handleDragEnd,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            child: Column(
                              // Ensure the handle bar is horizontally centered
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Handle simple y discreto (centered)
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    width: 44,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                        color: widget.isDark
                                          ? Colors.white.withValues(alpha: 0.25)
                                          : Colors.black.withValues(alpha: 0.2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBackButton extends StatelessWidget {
  const _GlassBackButton({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onBack,
          child: const Icon(
            Icons.arrow_back_ios_new,
            size: 16,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.quote, required this.isDark});
  final TripQuote quote;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.12),
              AppColors.primaryDark.withValues(alpha: isDark ? 0.15 : 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoChip(
              icon: Icons.access_time_rounded,
              value: quote.formattedDuration,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            _InfoChip(icon: Icons.straighten, value: quote.formattedDistance),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.iconSize,
    required this.color,
    required this.text,
    required this.isOrigin,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final double iconSize;
  final Color color;
  final String text;
  final bool isOrigin;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
                ),
                child: Center(
                  child: Icon(icon, size: iconSize, color: color),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isOrigin ? FontWeight.w600 : FontWeight.w500,
                    color: isDark
                      ? Colors.white.withValues(alpha: 0.9)
                      : AppColors.lightTextPrimary,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.edit_outlined,
                size: 14,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectorLine extends StatelessWidget {
  const _ConnectorLine({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Container(
            width: 2,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedConnector extends StatelessWidget {
  const _DottedConnector({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 14),
          SizedBox(
            height: 22,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                4,
                (index) => Container(
                  width: 2,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.4 - (index * 0.05)),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
