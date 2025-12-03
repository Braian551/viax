import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../../theme/app_colors.dart';
import 'active_trip_controller.dart';
import 'trip_bottom_sheet.dart';

/// Pantalla de viaje activo - Diseño DiDi/Uber moderno
/// Enfoque inmediato en conductor, UI limpia y animaciones fluidas
class ModernActiveTripScreen extends StatefulWidget {
  final int conductorId;
  final int? solicitudId;
  final int? viajeId;
  final double origenLat;
  final double origenLng;
  final double destinoLat;
  final double destinoLng;
  final String direccionOrigen;
  final String direccionDestino;
  final String? clienteNombre;

  const ModernActiveTripScreen({
    super.key,
    required this.conductorId,
    this.solicitudId,
    this.viajeId,
    required this.origenLat,
    required this.origenLng,
    required this.destinoLat,
    required this.destinoLng,
    required this.direccionOrigen,
    required this.direccionDestino,
    this.clienteNombre,
  });

  @override
  State<ModernActiveTripScreen> createState() =>
      _ModernActiveTripScreenState();
}

class _ModernActiveTripScreenState extends State<ModernActiveTripScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final ActiveTripController _controller;
  
  // Animaciones
  late AnimationController _uiEntryController;
  late AnimationController _navCardController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = ActiveTripController(
      origenLat: widget.origenLat,
      origenLng: widget.origenLng,
      destinoLat: widget.destinoLat,
      destinoLng: widget.destinoLng,
      onStateChanged: _onControllerStateChanged,
    );

    _setupAnimations();
  }

  void _setupAnimations() {
    // Animación de entrada UI
    _uiEntryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _uiEntryController, curve: Curves.easeOut),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _uiEntryController,
      curve: Curves.easeOutCubic,
    ));

    // Animación de la card de navegación
    _navCardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnim = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _navCardController, curve: Curves.elasticOut),
    );

    // Iniciar animaciones después de que el widget esté listo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _uiEntryController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _navCardController.forward();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiEntryController.dispose();
    _navCardController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.positionStream?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller.positionStream?.resume();
    }
  }

  void _onControllerStateChanged() {
    if (mounted && !_controller.isDisposed) {
      setState(() {});
    }
  }

  void _onActionPressed() async {
    if (_controller.toPickup) {
      await _controller.onArrivedPickup();
      if (!mounted || _controller.isDisposed) return;
      _showSnackbar('¡Pasajero recogido!', AppColors.success);
    } else {
      Navigator.pop(context, true);
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final screenHeight = MediaQuery.of(context).size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.grey[100],
        body: Stack(
          children: [
            // ===== MAPA =====
            Positioned.fill(child: _buildMap(isDark)),

            // ===== UI SUPERIOR =====
            Positioned(
              top: topPadding + 8,
              left: 12,
              right: 12,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: _buildTopBar(isDark),
                ),
              ),
            ),

            // ===== CARD DE NAVEGACIÓN =====
            Positioned(
              top: topPadding + 64,
              left: 16,
              right: 16,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _buildNavCard(isDark),
                ),
              ),
            ),

            // ===== CONTROLES DE MAPA =====
            Positioned(
              right: 16,
              bottom: screenHeight * 0.36,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildMapControls(isDark),
              ),
            ),

            // ===== VELOCÍMETRO =====
            Positioned(
              left: 16,
              bottom: screenHeight * 0.36,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildSpeedometer(isDark),
              ),
            ),

            // ===== PANEL INFERIOR =====
            _buildBottomSheet(isDark),

            // ===== LOADING =====
            if (_controller.loadingRoute) _buildLoading(isDark),

            // ===== ERROR =====
            if (_controller.error != null)
              Positioned(
                top: topPadding + 150,
                left: 16,
                right: 16,
                child: _buildError(),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MAPA
  // ===========================================================================

  Widget _buildMap(bool isDark) {
    if (_controller.mapError) {
      return _buildMapError(isDark);
    }

    return MapWidget(
      key: const ValueKey('tripMap'),
      cameraOptions: CameraOptions(
        center: _controller.driverLocation ?? _controller.pickup,
        zoom: 17,
        pitch: 60, // Vista navegación inmersiva
        bearing: _controller.currentBearing,
      ),
      styleUri: isDark
          ? 'mapbox://styles/mapbox/navigation-night-v1'
          : 'mapbox://styles/mapbox/navigation-day-v1',
      onMapCreated: _controller.onMapCreated,
      textureView: true,
      androidHostingMode: AndroidPlatformViewHostingMode.TLHC_HC,
      onStyleLoadedListener: (_) => _controller.onStyleLoaded(),
      onMapLoadErrorListener: _controller.onMapLoadError,
    );
  }

  Widget _buildMapError(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[900] : Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 56,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Mapa no disponible',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => setState(() => _controller.mapError = false),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // UI SUPERIOR
  // ===========================================================================

  Widget _buildTopBar(bool isDark) {
    return Row(
      children: [
        _CircleButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context, true),
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildStatusChip(isDark)),
        const SizedBox(width: 12),
        _CircleButton(
          icon: Icons.more_vert_rounded,
          onTap: () => _showOptions(isDark),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildStatusChip(bool isDark) {
    final isPickup = _controller.toPickup;
    final color = isPickup ? AppColors.warning : AppColors.success;
    final text = isPickup ? 'Ir a recoger' : 'En camino';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dot pulsante
          _PulsingDot(color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.grey[800],
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CARD DE NAVEGACIÓN
  // ===========================================================================

  Widget _buildNavCard(bool isDark) {
    final target =
        _controller.toPickup ? _controller.pickup : _controller.dropoff;
    final dist = _controller.driverLocation != null
        ? _controller.calculateDistance(_controller.driverLocation!, target)
        : 0.0;

    final distText =
        dist < 1000 ? '${dist.toInt()} m' : '${(dist / 1000).toStringAsFixed(1)} km';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.blue600],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icono de maniobra
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.straight_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // Distancia
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  distText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _controller.toPickup
                      ? 'hacia el punto de recogida'
                      : 'hacia el destino',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // ETA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_controller.etaMinutes} min',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CONTROLES DE MAPA
  // ===========================================================================

  Widget _buildMapControls(bool isDark) {
    return Column(
      children: [
        _CircleButton(
          icon: Icons.my_location_rounded,
          onTap: _controller.centerOnDriver,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _CircleButton(
          icon: _controller.is3DMode ? Icons.view_in_ar : Icons.map_outlined,
          onTap: _controller.toggle3DMode,
          isDark: isDark,
          isActive: _controller.is3DMode,
        ),
      ],
    );
  }

  // ===========================================================================
  // VELOCÍMETRO
  // ===========================================================================

  Widget _buildSpeedometer(bool isDark) {
    final speed = _controller.currentSpeed.toInt();
    final isMoving = speed > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.6)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$speed',
            style: TextStyle(
              color: isMoving
                  ? AppColors.primary
                  : (isDark ? Colors.white : Colors.grey[800]),
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'km/h',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey[500],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BOTTOM SHEET
  // ===========================================================================

  Widget _buildBottomSheet(bool isDark) {
    final fallbackDist = _controller.driverLocation != null
        ? _controller.calculateDistance(
                _controller.driverLocation!, _controller.pickup) /
            1000
        : 0.0;
    final dist =
        _controller.distanceKm > 0 ? _controller.distanceKm : fallbackDist;

    final arrivalTime = _controller.etaMinutes > 0
        ? DateTime.now().add(Duration(minutes: _controller.etaMinutes))
        : null;
    final arrivalStr = arrivalTime != null
        ? '${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return TripBottomSheet(
      isDark: isDark,
      toPickup: _controller.toPickup,
      passengerName: widget.clienteNombre ?? '',
      pickupAddress: widget.direccionOrigen,
      destinationAddress: widget.direccionDestino,
      etaMinutes: _controller.etaMinutes,
      distanceKm: dist,
      arrivalTime: arrivalStr,
      isLoading: _controller.loadingRoute,
      onAction: _onActionPressed,
      onCall: () {
        HapticFeedback.lightImpact();
        // TODO: Llamar
      },
      onMessage: () {
        HapticFeedback.lightImpact();
        // TODO: Mensaje
      },
    );
  }

  // ===========================================================================
  // LOADING & ERROR
  // ===========================================================================

  Widget _buildLoading(bool isDark) {
    return Container(
      color: Colors.black38,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Calculando ruta...',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _controller.error!,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _controller.error = null),
            child: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // OPCIONES
  // ===========================================================================

  void _showOptions(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _OptionTile(
              icon: Icons.cancel_outlined,
              label: 'Cancelar viaje',
              color: AppColors.error,
              isDark: isDark,
              onTap: () {
                Navigator.pop(ctx);
                _confirmCancel(isDark);
              },
            ),
            const SizedBox(height: 8),
            _OptionTile(
              icon: Icons.support_agent_rounded,
              label: 'Soporte',
              isDark: isDark,
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancel(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Cancelar viaje?',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.grey[900],
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Esto puede afectar tu calificación.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Volver',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, false);
            },
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGETS AUXILIARES
// =============================================================================

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final bool isActive;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? AppColors.primary.withValues(alpha: 0.15)
          : (isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: isActive
                ? Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4), width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: isActive
                ? AppColors.primary
                : (isDark ? Colors.white70 : Colors.grey[700]),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool isDark;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (isDark ? Colors.white : Colors.grey[800]);

    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: c, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: c,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white24 : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.5 * _ctrl.value),
                blurRadius: 6 * _ctrl.value,
                spreadRadius: 2 * _ctrl.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
