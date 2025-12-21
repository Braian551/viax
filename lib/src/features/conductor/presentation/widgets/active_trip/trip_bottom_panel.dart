import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/features/conductor/services/navigation_launcher_service.dart';
import '../common/pulsing_dot.dart';

/// Panel inferior deslizable para viaje activo.
///
/// Diseño estilo DiDi/Uber con información del pasajero,
/// estadísticas del viaje y acciones principales.
class TripBottomPanel extends StatefulWidget {
  final bool isDark;
  final bool toPickup;
  final bool arrivedAtPickup;  // NUEVO: esperando iniciar viaje
  final String passengerName;
  final String pickupAddress;
  final String destinationAddress;
  final int etaMinutes;
  final double distanceKm;
  final String arrivalTime;
  final bool isLoading;
  final VoidCallback onArrivedPickup;
  final VoidCallback onStartTrip;   // NUEVO: iniciar viaje
  final VoidCallback onFinishTrip;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  // Coordenadas para navegación externa
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final double? currentLat;
  final double? currentLng;

  const TripBottomPanel({
    super.key,
    required this.isDark,
    required this.toPickup,
    required this.arrivedAtPickup,
    required this.passengerName,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.etaMinutes,
    required this.distanceKm,
    required this.arrivalTime,
    required this.isLoading,
    required this.onArrivedPickup,
    required this.onStartTrip,
    required this.onFinishTrip,
    this.onCall,
    this.onMessage,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.currentLat,
    this.currentLng,
  });

  @override
  State<TripBottomPanel> createState() => _TripBottomPanelState();
}

class _TripBottomPanelState extends State<TripBottomPanel> {
  final DraggableScrollableController _dragController =
      DraggableScrollableController();

  static const double _minSize = 0.22;
  static const double _midSize = 0.38;
  static const double _maxSize = 0.55;

  bool _isExpanded = false;

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  String get _displayName => widget.passengerName.trim().isNotEmpty
      ? widget.passengerName.trim()
      : 'Pasajero';

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
        return Container(
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
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
                _buildDragHandle(),
                _buildPassengerInfo(),
                // Botones de navegación siempre visibles
                _buildNavigationSection(),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: _buildExpandedContent(),
                  crossFadeState: _isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
                _buildActionButton(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      onTap: _handleTap,
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

  void _handleTap() {
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
  }

  Widget _buildPassengerInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 12),
          Expanded(child: _buildNameAndStatus()),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.person_rounded, color: AppColors.primary, size: 26),
    );
  }

  Widget _buildNameAndStatus() {
    final statusColor = widget.toPickup ? AppColors.warning : AppColors.success;
    final statusText = widget.toPickup ? 'Esperando' : 'En viaje';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                _displayName,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.grey[900],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _StatusBadge(
              text: statusText,
              color: statusColor,
              isDark: widget.isDark,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.location_on_rounded, color: AppColors.primary, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.toPickup
                    ? widget.pickupAddress
                    : widget.destinationAddress,
                style: TextStyle(
                  color: widget.isDark ? Colors.white60 : Colors.grey[600],
                  fontSize: 12,
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
      children: [
        _QuickActionButton(
          icon: Icons.phone_rounded,
          color: AppColors.success,
          isDark: widget.isDark,
          onTap: widget.onCall ?? () {},
        ),
        const SizedBox(width: 8),
        _QuickActionButton(
          icon: Icons.message_rounded,
          color: AppColors.primary,
          isDark: widget.isDark,
          onTap: widget.onMessage ?? () {},
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    // Determinar destino según fase del viaje
    final targetLat = widget.toPickup
        ? widget.pickupLat
        : widget.destinationLat;
    final targetLng = widget.toPickup
        ? widget.pickupLng
        : widget.destinationLng;

    if (targetLat == null || targetLng == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _NavigationButton(
              label: 'Google Maps',
              icon: Icons.map_rounded,
              color: const Color(0xFF4285F4),
              isDark: widget.isDark,
              onTap: () => _openGoogleMaps(targetLat, targetLng),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _NavigationButton(
              label: 'Waze',
              icon: Icons.navigation_rounded,
              color: const Color(0xFF33CCFF),
              isDark: widget.isDark,
              onTap: () => _openWaze(targetLat, targetLng),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    HapticFeedback.lightImpact();
    final success = await NavigationLauncherService.openGoogleMaps(
      destinationLat: lat,
      destinationLng: lng,
      originLat: widget.currentLat,
      originLng: widget.currentLng,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo abrir Google Maps'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _openWaze(double lat, double lng) async {
    HapticFeedback.lightImpact();
    final success = await NavigationLauncherService.openWaze(
      destinationLat: lat,
      destinationLng: lng,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo abrir Waze'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Widget _buildExpandedContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          _buildStatsRow(),
          const SizedBox(height: 12),
          _buildArrivalInfo(),
        ],
      ),
    );
  }

  /// Construye la sección de botones de navegación externa.
  /// Se muestra siempre visible para fácil acceso.
  Widget _buildNavigationSection() {
    final targetLat = widget.toPickup
        ? widget.pickupLat
        : widget.destinationLat;
    final targetLng = widget.toPickup
        ? widget.pickupLng
        : widget.destinationLng;

    if (targetLat == null || targetLng == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Navegar con',
              style: TextStyle(
                color: widget.isDark ? Colors.white60 : Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _NavigationButton(
                  label: 'Google Maps',
                  icon: Icons.map_rounded,
                  color: const Color(0xFF4285F4),
                  isDark: widget.isDark,
                  onTap: () => _openGoogleMaps(targetLat, targetLng),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NavigationButton(
                  label: 'Waze',
                  icon: Icons.navigation_rounded,
                  color: const Color(0xFF33CCFF),
                  isDark: widget.isDark,
                  onTap: () => _openWaze(targetLat, targetLng),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.schedule_rounded,
            value: '${widget.etaMinutes}',
            unit: 'min',
            label: 'Tiempo',
            isDark: widget.isDark,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.route_rounded,
            value: widget.distanceKm < 1
                ? '${(widget.distanceKm * 1000).toInt()}'
                : widget.distanceKm.toStringAsFixed(1),
            unit: widget.distanceKm < 1 ? 'm' : 'km',
            label: 'Distancia',
            isDark: widget.isDark,
            color: AppColors.blue600,
          ),
        ),
      ],
    );
  }

  Widget _buildArrivalInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (widget.isDark ? Colors.white : Colors.grey).withValues(
          alpha: 0.05,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (widget.isDark ? Colors.white : Colors.grey).withValues(
            alpha: 0.1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.access_time_filled_rounded,
              color: AppColors.success,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hora estimada de llegada',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white54 : Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                Text(
                  widget.arrivalTime,
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.grey[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    // Determinar texto, acción y estilo según el estado actual
    String buttonText;
    VoidCallback buttonAction;
    Color buttonColor;
    IconData buttonIcon;

    if (widget.toPickup) {
      // Estado 1: En camino al punto de recogida
      buttonText = 'Llegué al punto';
      buttonAction = widget.onArrivedPickup;
      buttonColor = AppColors.primary;
      buttonIcon = Icons.check_circle_rounded;
    } else if (widget.arrivedAtPickup) {
      // Estado 2: Llegó al punto, esperando al cliente
      buttonText = 'Comenzar viaje';
      buttonAction = widget.onStartTrip;
      buttonColor = AppColors.accent;
      buttonIcon = Icons.play_arrow_rounded;
    } else {
      // Estado 3: Viaje en curso, hacia el destino
      buttonText = 'Finalizar viaje';
      buttonAction = widget.onFinishTrip;
      buttonColor = AppColors.success;
      buttonIcon = Icons.flag_rounded;
    }

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
                  buttonAction();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: buttonColor.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 4,
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
                    Icon(buttonIcon, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ===========================================================================
// WIDGETS AUXILIARES PRIVADOS
// ===========================================================================

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final bool isDark;

  const _StatusBadge({
    required this.text,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsingDot(color: color, size: 6),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionButton({
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
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final bool isDark;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.grey[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      unit,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey[500],
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Botón para abrir aplicación de navegación externa.
class _NavigationButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _NavigationButton({
    required this.label,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey[800],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
