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
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF1E1E1E).withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Row: Back Button + Floating Stats Pill
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              _GlassBackButton(onBack: widget.onBack),
                              const SizedBox(width: 12),
                              if (widget.quote != null)
                                Expanded(
                                  child: _StatsPill(
                                    quote: widget.quote!,
                                    isDark: widget.isDark,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Collapsible Content (Locations)
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          child: SizedBox(
                            width: double.infinity,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _contentOpacity,
                              child: _isCollapsed
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                      child: Column(
                                        children: [
                                          _LocationRow(
                                            icon: Icons.my_location,
                                            iconColor: Colors.blueAccent,
                                            text: widget.origin.address,
                                            isOrigin: true,
                                            isDark: widget.isDark,
                                          ),
                                          _DashedLine(isDark: widget.isDark),
                                          for (final stop in widget.stops) ...[
                                            _LocationRow(
                                              icon: Icons.stop_circle_outlined,
                                              iconColor: Colors.orangeAccent,
                                              text: stop.address,
                                              isOrigin: false,
                                              isDark: widget.isDark,
                                            ),
                                            _DashedLine(isDark: widget.isDark),
                                          ],
                                          _LocationRow(
                                            icon: Icons.location_on,
                                            iconColor: AppColors.primary,
                                            text: widget.destination.address,
                                            isOrigin: false,
                                            isDark: widget.isDark,
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        // Drag Handle Area
                        GestureDetector(
                          onTap: _toggleExpansion,
                          onVerticalDragUpdate: _handleDragUpdate,
                          onVerticalDragEnd: _handleDragEnd,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: widget.isDark
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : Colors.black.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(2),
                              ),
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
    // Determine if dark mode is active from context since we don't pass isDark here directly, 
    // but better to just use standard logic or pass it. 
    // Assuming context theme or consistent style. 
    // Using a light blue tint often looks good in both.
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onBack,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.1) 
              : AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark 
                ? Colors.white.withValues(alpha: 0.1) 
                : AppColors.primary.withValues(alpha: 0.2), 
            width: 1,
          ),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: isDark ? Colors.white : AppColors.primary,
        ),
      ),
    );
  }
}

class _StatsPill extends StatelessWidget {
  const _StatsPill({required this.quote, required this.isDark});
  final TripQuote quote;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // Center the content
        children: [
          Icon(Icons.access_time_filled_rounded, 
               size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            quote.formattedDuration,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.directions_car_filled_rounded, 
               size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            quote.formattedDistance,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.isOrigin,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final bool isOrigin;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (isOrigin) // Subtext only for origin to balance visual
                  Text(
                    'Punto de partida',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
              ],
            ),
          ),
          // Edit icon
          Icon(
            Icons.edit_rounded,
            size: 16,
            color: isDark ? Colors.white30 : Colors.black26,
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 15, top: 0, bottom: 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          height: 16,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              3,
              (index) => Container(
                width: 2,
                height: 3,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
