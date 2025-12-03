import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../theme/app_colors.dart';

/// Panel inferior moderno estilo DiDi Conductor
/// Con animaciones fluidas, diseño limpio y drag funcional
class TripBottomSheet extends StatefulWidget {
  final bool isDark;
  final bool toPickup;
  final String passengerName;
  final String passengerRating;
  final int passengerTrips;
  final String pickupAddress;
  final String destinationAddress;
  final int etaMinutes;
  final double distanceKm;
  final String arrivalTime;
  final bool isLoading;
  final VoidCallback onAction;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final VoidCallback? onNavigate;

  const TripBottomSheet({
    super.key,
    required this.isDark,
    required this.toPickup,
    required this.passengerName,
    this.passengerRating = '4.75',
    this.passengerTrips = 12,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.etaMinutes,
    required this.distanceKm,
    required this.arrivalTime,
    required this.isLoading,
    required this.onAction,
    this.onCall,
    this.onMessage,
    this.onNavigate,
  });

  @override
  State<TripBottomSheet> createState() => _TripBottomSheetState();
}

class _TripBottomSheetState extends State<TripBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late AnimationController _chevronController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  double _currentExtent = 0.32;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    // Animación de entrada
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );

    // Pulso para estado "esperando"
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Chevron animado
    _chevronController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    _chevronController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.32,
          minChildSize: 0.18,
          maxChildSize: 0.52,
          snap: true,
          snapSizes: const [0.18, 0.32, 0.52],
          builder: (context, scrollController) {
            return NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                setState(() => _currentExtent = notification.extent);
                return true;
              },
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Handle
                    _buildHandle(),

                    // Contenido principal
                    _buildMainContent(),

                    // Contenido expandido
                    if (_currentExtent > 0.25) _buildExpandedContent(),

                    // Botón de acción
                    _buildActionButton(),

                    SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white24 : Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          // Avatar del pasajero con indicador
          _buildPassengerAvatar(),
          const SizedBox(width: 14),

          // Info del pasajero
          Expanded(child: _buildPassengerInfo()),

          // Acciones rápidas
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildPassengerAvatar() {
    return Stack(
      children: [
        // Avatar principal
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),

        // Indicador de estado
        if (widget.toPickup)
          Positioned(
            right: -2,
            top: -2,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isDark
                          ? const Color(0xFF1A1A1A)
                          : Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warning
                            .withValues(alpha: 0.5 * _pulseController.value),
                        blurRadius: 8 * _pulseController.value,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPassengerInfo() {
    final displayName = widget.passengerName.isNotEmpty
        ? widget.passengerName
        : 'Usuario';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nombre y badge
        Row(
          children: [
            Flexible(
              child: Text(
                displayName,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.grey[900],
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            // Rating y viajes
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: Colors.amber[600],
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${widget.passengerRating}★',
                    style: TextStyle(
                      color: widget.isDark ? Colors.white70 : Colors.grey[700],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    ' · ${widget.passengerTrips} viajes',
                    style: TextStyle(
                      color: widget.isDark ? Colors.white54 : Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Dirección actual
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.toPickup ? AppColors.primary : AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.toPickup
                    ? widget.pickupAddress
                    : widget.destinationAddress,
                style: TextStyle(
                  color: widget.isDark ? Colors.white60 : Colors.grey[600],
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: Icons.phone_rounded,
          color: AppColors.success,
          isDark: widget.isDark,
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onCall?.call();
          },
        ),
        const SizedBox(width: 10),
        _ActionButton(
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

  Widget _buildExpandedContent() {
    return AnimatedOpacity(
      opacity: _currentExtent > 0.28 ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          children: [
            // Separador
            Divider(
              color: widget.isDark ? Colors.white12 : Colors.grey[200],
              height: 1,
            ),
            const SizedBox(height: 16),

            // Stats row
            _buildStatsRow(),

            const SizedBox(height: 16),

            // Hora de llegada
            _buildArrivalInfo(),

            const SizedBox(height: 16),

            // Direcciones completas
            _buildAddressesPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final distStr = widget.distanceKm < 1
        ? '${(widget.distanceKm * 1000).toInt()}'
        : widget.distanceKm.toStringAsFixed(1);
    final distUnit = widget.distanceKm < 1 ? 'm' : 'km';

    return Row(
      children: [
        Expanded(
          child: _StatItem(
            icon: Icons.schedule_rounded,
            value: '${widget.etaMinutes}',
            unit: 'min',
            label: 'Tiempo',
            color: AppColors.primary,
            isDark: widget.isDark,
          ),
        ),
        Container(
          width: 1,
          height: 50,
          color: widget.isDark ? Colors.white12 : Colors.grey[200],
        ),
        Expanded(
          child: _StatItem(
            icon: Icons.straighten_rounded,
            value: distStr,
            unit: distUnit,
            label: 'Distancia',
            color: AppColors.blue600,
            isDark: widget.isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildArrivalInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.access_time_filled_rounded,
              color: AppColors.success,
              size: 20,
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
                Text(
                  widget.arrivalTime,
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.grey[900],
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Progress circular
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              value: 0.7,
              strokeWidth: 3,
              backgroundColor:
                  widget.isDark ? Colors.white12 : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressesPreview() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Origen
          _AddressItem(
            icon: Icons.radio_button_checked_rounded,
            iconColor: AppColors.primary,
            label: 'Recoger',
            address: widget.pickupAddress,
            isDark: widget.isDark,
            isActive: widget.toPickup,
          ),
          // Línea conectora
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.primary, AppColors.error],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Destino
          _AddressItem(
            icon: Icons.location_on_rounded,
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
    final isPickup = widget.toPickup;
    final color = isPickup ? AppColors.primary : AppColors.success;
    final text = isPickup ? 'Llegué por el pasajero' : 'Finalizar viaje';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.isLoading
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  widget.onAction();
                },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: widget.isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Chevrons animados
                      _AnimatedChevrons(controller: _chevronController),
                      const SizedBox(width: 10),
                      Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
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

// =============================================================================
// WIDGETS AUXILIARES
// =============================================================================

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final Color color;
  final bool isDark;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey[400],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddressItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;
  final bool isDark;
  final bool isActive;

  const _AddressItem({
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
        Icon(icon, color: iconColor, size: 20),
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
              Text(
                address,
                style: TextStyle(
                  color: isActive
                      ? (isDark ? Colors.white : Colors.grey[900])
                      : (isDark ? Colors.white54 : Colors.grey[600]),
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnimatedChevrons extends StatelessWidget {
  final AnimationController controller;

  const _AnimatedChevrons({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(2, (index) {
            final delay = index * 0.4;
            final value = ((controller.value + delay) % 1.0);
            final opacity = value < 0.5 ? value * 2 : 2 - value * 2;
            return Opacity(
              opacity: opacity.clamp(0.3, 1.0),
              child: Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 18,
              ),
            );
          }),
        );
      },
    );
  }
}
