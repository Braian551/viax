import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../global/services/mapbox_service.dart';
import '../../../../theme/app_colors.dart';
import '../models/trip_request_view.dart';

class RequestActionPanel extends StatefulWidget {
  const RequestActionPanel({
    super.key,
    required this.request,
    required this.routeToClient,
    required this.currentLocation,
    required this.onAccept,
    required this.onReject,
    required this.onTimeout,
    required this.isDark,
  });

  final TripRequestView request;
  final MapboxRoute? routeToClient;
  final LatLng? currentLocation;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onTimeout;
  final bool isDark;

  @override
  State<RequestActionPanel> createState() => _RequestActionPanelState();
}

class _RequestActionPanelState extends State<RequestActionPanel>
    with TickerProviderStateMixin {
  late AnimationController _panelController;
  late Animation<Offset> _panelSlideAnimation;
  late Animation<double> _panelFadeAnimation;
  late AnimationController _acceptButtonController;
  late Animation<double> _acceptButtonScale;
  late AnimationController _timerController;
  late Animation<double> _timerAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _panelExpanded = false;
  bool _panelCollapsed = false;
  double _dragStartPosition = 0;
  double _currentDragOffset = 0;
  static const double _maxDragOffset = 100;
  static const double _collapsedOffset = 350; // Oculta la mayor parte del panel
  static const double _minOpacity = 0.85;
  // Para el indicador de drag
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _panelController.forward();
      _timerController.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _panelController.dispose();
    _acceptButtonController.dispose();
    _timerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _panelController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _panelSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(parent: _panelController, curve: Curves.easeOutCubic),
        );
    _panelFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _panelController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _acceptButtonController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _acceptButtonScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _acceptButtonController, curve: Curves.easeInOut),
    );

    _timerController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );
    _timerAnimation =
        Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(parent: _timerController, curve: Curves.linear),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            widget.onTimeout();
          }
        });

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Color _timerColor(int seconds) {
    if (seconds <= 5) return const Color(0xFFF44336);
    if (seconds <= 10) return const Color(0xFFFF9800);
    if (seconds <= 20) return AppColors.primary;
    return const Color(0xFF4CAF50);
  }

  String _formatPrice(double price) {
    final formatter = NumberFormat('#,###', 'es_CO');
    return formatter.format(price.round());
  }

  double _driverToClientKm() {
    if (widget.currentLocation == null) return 0;
    const distance = Distance();
    return distance.as(
      LengthUnit.Kilometer,
      widget.currentLocation!,
      widget.request.origen,
    );
  }

  int _etaMinutes(double distanciaConductorCliente) {
    if (widget.routeToClient != null) {
      return widget.routeToClient!.durationMinutes.ceil();
    }
    return (distanciaConductorCliente * 2).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final distanciaConductorCliente = _driverToClientKm();
    final etaMinutos = _etaMinutes(distanciaConductorCliente);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _panelSlideAnimation,
        child: FadeTransition(
          opacity: _panelFadeAnimation,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: _panelCollapsed
                  ? 0
                  : _currentDragOffset.clamp(-_maxDragOffset, _collapsedOffset),
            ),
            duration: _isDragging
                ? Duration.zero
                : const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            builder: (context, animatedOffset, child) {
              // Calcular opacidad basada en qué tan colapsado está
              final collapseProgress = animatedOffset / _collapsedOffset;
              final contentOpacity = (1 - collapseProgress * 0.3).clamp(
                _minOpacity,
                1.0,
              );
              return Transform.translate(
                offset: Offset(0, animatedOffset),
                child: Opacity(opacity: contentOpacity, child: child),
              );
            },
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(36),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: GestureDetector(
                  onVerticalDragStart: (details) {
                    setState(() {
                      _dragStartPosition = details.localPosition.dy;
                      _isDragging = true;
                    });
                  },
                  onVerticalDragUpdate: (details) {
                    setState(() {
                      // Permitir drag más amplio
                      _currentDragOffset =
                          (details.localPosition.dy - _dragStartPosition).clamp(
                            -_maxDragOffset,
                            _collapsedOffset,
                          );
                    });
                  },
                  onVerticalDragEnd: (details) {
                    final v = details.primaryVelocity;
                    setState(() => _isDragging = false);
                    if (v != null) {
                      if (v < -400 || _currentDragOffset < -60) {
                        // Deslizar hacia arriba - expandir
                        setState(() {
                          _panelExpanded = true;
                          _panelCollapsed = false;
                          _currentDragOffset = 0;
                        });
                      } else if (v > 400 || _currentDragOffset > 100) {
                        // Deslizar hacia abajo - colapsar
                        setState(() {
                          _panelExpanded = false;
                          _panelCollapsed = true;
                          _currentDragOffset = 0; // Fix: Offset 0 para mostrar la info compacta
                        });
                      } else {
                        // Regresar a estado normal
                        setState(() {
                          _currentDragOffset = _panelCollapsed ? 0 : 0;
                        });
                      }
                    } else {
                      setState(
                        () => _currentDragOffset = _panelCollapsed ? 0 : 0,
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                AppColors.darkCard.withValues(alpha: 0.85),
                                AppColors.darkCard.withValues(alpha: 0.98),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.85),
                                Colors.white.withValues(alpha: 0.98),
                              ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(36),
                      ),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 40,
                          offset: const Offset(0, -15),
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.5 : 0.2,
                          ),
                          blurRadius: 30,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(isDark),
                            const SizedBox(height: 18),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: 1,
                              child: Column(
                                children: [
                                  // Mostrar precio solo si está expandido o parcialmente visible
                                  if (!_panelCollapsed)
                                    _buildPriceCard(
                                      isDark,
                                      distanciaConductorCliente,
                                      etaMinutos,
                                    )
                                  else
                                    // Versión compacta para cuando está colapsado
                                    _buildCompactInfo(
                                      isDark,
                                      distanciaConductorCliente,
                                      etaMinutos,
                                    ),

                                  const SizedBox(height: 18),
                                  if (!_panelCollapsed) ...[
                                    _buildRouteSummary(isDark),
                                    const SizedBox(height: 18),
                                    _buildActions(isDark),
                                  ],
                                ],
                              ),
                            ),
                            AnimatedCrossFade(
                              duration: const Duration(milliseconds: 300),
                              crossFadeState: _panelExpanded
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              firstChild: const SizedBox.shrink(),
                              secondChild: Column(
                                children: const [SizedBox(height: 32)],
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
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AnimatedBuilder(
          animation: _timerAnimation,
          builder: (context, child) {
            final seconds = (_timerAnimation.value * 30).ceil();
            final timerColor = _timerColor(seconds);
            return Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    timerColor.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: timerColor.withValues(alpha: 0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: timerColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: CircularProgressIndicator(
                      value: _timerAnimation.value,
                      strokeWidth: 3.5,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.0, end: seconds <= 5 ? 1.15 : 1.0),
                    duration: const Duration(milliseconds: 200),
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Text(
                          '$seconds',
                          style: TextStyle(
                            color: timerColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
        Column(
          children: [
            Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          Colors.white.withValues(alpha: 0.2),
                          Colors.white.withValues(alpha: 0.4),
                          Colors.white.withValues(alpha: 0.2),
                        ]
                      : [
                          Colors.grey.withValues(alpha: 0.3),
                          Colors.grey.withValues(alpha: 0.5),
                          Colors.grey.withValues(alpha: 0.3),
                        ],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.25),
                AppColors.primary.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(
                            alpha: 0.6 * (2 - _pulseAnimation.value),
                          ),
                          blurRadius: 6 * _pulseAnimation.value,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              const Text(
                '¡Nuevo viaje!',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard(
    bool isDark,
    double distanciaConductorCliente,
    int etaMinutos,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.blue700.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.08),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$',
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.85),
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 2),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: widget.request.precioEstimado),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Text(
                    _formatPrice(value),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                      height: 1,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'COP',
                  style: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.65),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.primary.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _infoChip(
                icon: Icons.route_rounded,
                value: '${widget.request.distanciaKm.toStringAsFixed(1)} km',
                color: AppColors.primary,
                isDark: isDark,
              ),
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.3),
              ),
              _infoChip(
                icon: Icons.schedule_rounded,
                value: '${widget.request.duracionMinutos} min',
                color: AppColors.primary,
                isDark: isDark,
              ),
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.3),
              ),
              _infoChip(
                icon: Icons.navigation_rounded,
                value: etaMinutos > 0
                    ? '$etaMinutos min'
                    : '${distanciaConductorCliente.toStringAsFixed(1)} km',
                color: const Color(0xFF4CAF50),
                label: etaMinutos > 0 ? 'hasta cliente' : 'distancia',
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSummary(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A2A2A).withValues(alpha: 0.65)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ruta rápida',
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.grey[800],
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _locationInfo(
            icon: Icons.my_location,
            iconColor: const Color(0xFF4CAF50),
            label: 'Recoger en',
            value: widget.request.direccionOrigen,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _locationInfo(
            icon: Icons.location_on,
            iconColor: AppColors.primary,
            label: 'Destino',
            value: widget.request.direccionDestino,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool isDark) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF3A3A3A), const Color(0xFF2A2A2A)]
                  : [Colors.grey[200]!, Colors.grey[300]!],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onReject();
              },
              child: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white : Colors.grey[700],
                size: 30,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: AnimatedBuilder(
            animation: _acceptButtonScale,
            builder: (context, child) {
              return Transform.scale(
                scale: _acceptButtonScale.value,
                child: child,
              );
            },
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.blue700],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 50,
                    spreadRadius: 5,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    widget.onAccept();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Aceptar viaje',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String value,
    required Color color,
    String? label,
    bool isDark = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.95)
                    : Colors.grey[800],
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (label != null) ...[
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _locationInfo({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool isDark = true,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey[800],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Método para expandir el panel cuando está colapsado
  void _expandPanel() {
    setState(() {
      _panelExpanded = false;
      _panelCollapsed = false;
      _currentDragOffset = 0;
    });
  }

  Widget _buildCompactInfo(bool isDark, double distancia, int eta) {
    return Column(
      children: [
        // Info compacta con precio y tiempo - TOCABLE para expandir
        GestureDetector(
          onTap: _expandPanel,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoChip(
                  icon: Icons.attach_money,
                  value: _formatPrice(widget.request.precioEstimado),
                  color: AppColors.primary,
                  isDark: isDark,
                ),
                Container(
                  height: 20,
                  width: 1,
                  color: Colors.grey.withOpacity(0.3),
                ),
                _infoChip(
                  icon: Icons.navigation_rounded,
                  value: '$eta min',
                  color: Colors.green,
                  isDark: isDark,
                ),
                // Flecha indicando que puede expandir
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Botones de acción siempre visibles
        _buildActions(isDark),
      ],
    );
  }
}
