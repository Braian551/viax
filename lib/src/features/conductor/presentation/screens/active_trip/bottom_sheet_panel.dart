import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../theme/app_colors.dart';

/// Panel inferior deslizable estilo DiDi/Uber
/// Más limpio, funcional y con drag gesture
class DraggableBottomPanel extends StatefulWidget {
  final bool isDark;
  final bool toPickup;
  final String passengerName;
  final String pickupAddress;
  final String destinationAddress;
  final int etaMinutes;
  final double distanceKm;
  final String arrivalTime;
  final bool isLoading;
  final VoidCallback onArrivedPickup;
  final VoidCallback onFinishTrip;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final VoidCallback? onCancel;

  const DraggableBottomPanel({
    super.key,
    required this.isDark,
    required this.toPickup,
    required this.passengerName,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.etaMinutes,
    required this.distanceKm,
    required this.arrivalTime,
    required this.isLoading,
    required this.onArrivedPickup,
    required this.onFinishTrip,
    this.onCall,
    this.onMessage,
    this.onCancel,
  });

  @override
  State<DraggableBottomPanel> createState() => _DraggableBottomPanelState();
}

class _DraggableBottomPanelState extends State<DraggableBottomPanel>
    with SingleTickerProviderStateMixin {
  // Controlador para el DraggableScrollableSheet
  final DraggableScrollableController _dragController =
      DraggableScrollableController();

  // Tamaños del panel
  static const double _minSize = 0.22; // Mínimo colapsado
  static const double _midSize = 0.38; // Tamaño medio (default)
  static const double _maxSize = 0.55; // Máximo expandido

  bool _isExpanded = false;

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _dragController,
      initialChildSize: _midSize,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      snap: true,
      snapSizes: const [_minSize, _midSize, _maxSize],
      builder: (context, scrollController) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            // Auto-snap cuando se suelta
            return false;
          },
          child: Container(
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle de arrastre
                  _buildDragHandle(),

                  // Contenido compacto principal (siempre visible)
                  _buildCompactContent(),

                  // Contenido expandido (info adicional)
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: _buildExpandedContent(),
                    crossFadeState: _isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),

                  // Botón de acción principal
                  _buildActionButton(),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final current = _dragController.size;
        if (current < _midSize) {
          _dragController.animateTo(
            _midSize,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        } else if (current < _maxSize - 0.05) {
          _dragController.animateTo(
            _maxSize,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
          setState(() => _isExpanded = true);
        } else {
          _dragController.animateTo(
            _midSize,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
          setState(() => _isExpanded = false);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white24 : Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Fila de info principal: Pasajero + Acciones
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),

              // Nombre y estado
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.passengerName.isNotEmpty
                                ? widget.passengerName
                                : 'Pasajero',
                            style: TextStyle(
                              color: widget.isDark
                                  ? Colors.white
                                  : Colors.grey[900],
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.toPickup) ...[
                          const SizedBox(width: 8),
                          _buildStatusBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: widget.toPickup
                              ? AppColors.primary
                              : AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.toPickup
                                ? widget.pickupAddress
                                : widget.destinationAddress,
                            style: TextStyle(
                              color: widget.isDark
                                  ? Colors.white60
                                  : Colors.grey[600],
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Botones de acción rápida
              _buildQuickActions(),
            ],
          ),

          const SizedBox(height: 16),

          // Stats compactos
          _buildCompactStats(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Esperando',
            style: TextStyle(
              color: AppColors.warning,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuickActionBtn(
          icon: Icons.phone_rounded,
          color: AppColors.success,
          isDark: widget.isDark,
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onCall?.call();
          },
        ),
        const SizedBox(width: 8),
        _QuickActionBtn(
          icon: Icons.chat_bubble_rounded,
          color: AppColors.primary,
          isDark: widget.isDark,
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onMessage?.call();
          },
        ),
      ],
    );
  }

  Widget _buildCompactStats() {
    final distStr = widget.distanceKm < 1
        ? '${(widget.distanceKm * 1000).toInt()} m'
        : '${widget.distanceKm.toStringAsFixed(1)} km';

    return Row(
      children: [
        // Tiempo
        Expanded(
          child: _CompactStatItem(
            icon: Icons.schedule_rounded,
            value: '${widget.etaMinutes}',
            unit: 'min',
            label: 'Tiempo',
            isDark: widget.isDark,
          ),
        ),
        Container(
          width: 1,
          height: 40,
          color: widget.isDark ? Colors.white12 : Colors.grey[200],
        ),
        // Distancia
        Expanded(
          child: _CompactStatItem(
            icon: Icons.straighten_rounded,
            value: distStr.replaceAll(' km', '').replaceAll(' m', ''),
            unit: widget.distanceKm < 1 ? 'm' : 'km',
            label: 'Distancia',
            isDark: widget.isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider
          Divider(
            color: widget.isDark ? Colors.white12 : Colors.grey[200],
            height: 1,
          ),
          const SizedBox(height: 16),

          // Hora de llegada
          _buildArrivalTimeCard(),

          const SizedBox(height: 12),

          // Direcciones completas
          _buildAddressesCard(),
        ],
      ),
    );
  }

  Widget _buildArrivalTimeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.access_time_filled_rounded,
              color: AppColors.success,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Llega antes de',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white54 : Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.arrivalTime,
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.grey[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          // Circular progress indicator
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: 0.7,
              strokeWidth: 3,
              backgroundColor: widget.isDark
                  ? Colors.white12
                  : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressesCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Origen
          _AddressRow(
            icon: Icons.radio_button_checked,
            iconColor: AppColors.primary,
            label: 'Recoger en',
            address: widget.pickupAddress,
            isDark: widget.isDark,
            isActive: widget.toPickup,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(
              width: 2,
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primary, AppColors.error],
                ),
              ),
            ),
          ),
          // Destino
          _AddressRow(
            icon: Icons.location_on,
            iconColor: AppColors.error,
            label: 'Destino',
            address: widget.destinationAddress,
            isDark: widget.isDark,
            isActive: !widget.toPickup,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final isToPickup = widget.toPickup;
    final buttonColor = isToPickup ? AppColors.primary : AppColors.success;
    final buttonText = isToPickup
        ? 'Llegué por el pasajero'
        : 'Finalizar viaje';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: widget.isLoading
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  if (isToPickup) {
                    widget.onArrivedPickup();
                  } else {
                    widget.onFinishTrip();
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: buttonColor.withOpacity(0.5),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Chevron animado estilo DiDi
                    _AnimatedChevrons(color: Colors.white.withOpacity(0.7)),
                    const SizedBox(width: 8),
                    Text(
                      buttonText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// =============================================================================
// WIDGETS AUXILIARES
// =============================================================================

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _CompactStatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final bool isDark;

  const _CompactStatItem({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white54 : Colors.grey[500],
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.grey[900],
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    unit,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey[400],
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;
  final bool isDark;
  final bool isActive;

  const _AddressRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
    required this.isDark,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey[400],
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: TextStyle(
                  color: isActive
                      ? (isDark ? Colors.white : Colors.grey[900])
                      : (isDark ? Colors.white54 : Colors.grey[600]),
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
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
}

/// Chevrons animados estilo DiDi
class _AnimatedChevrons extends StatefulWidget {
  final Color color;

  const _AnimatedChevrons({required this.color});

  @override
  State<_AnimatedChevrons> createState() => _AnimatedChevronsState();
}

class _AnimatedChevronsState extends State<_AnimatedChevrons>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(2, (index) {
              final delay = index * 0.3;
              final animValue = ((_controller.value + delay) % 1.0).clamp(
                0.0,
                1.0,
              );
              final opacity = animValue < 0.5
                  ? (animValue * 2)
                  : (1.0 - (animValue - 0.5) * 2);
              return Opacity(
                opacity: opacity.clamp(0.3, 1.0),
                child: Icon(Icons.chevron_right, color: widget.color, size: 16),
              );
            }),
          );
        },
      ),
    );
  }
}
