import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../../theme/app_colors.dart';
import 'active_trip_controller.dart';
import 'bottom_sheet_panel.dart';

/// Pantalla de viaje activo para el conductor - Estilo DiDi/Uber
/// UI limpia con enfoque en navegación y panel draggable
class ConductorActiveTripScreen extends StatefulWidget {
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

  const ConductorActiveTripScreen({
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
  State<ConductorActiveTripScreen> createState() =>
      _ConductorActiveTripScreenState();
}

class _ConductorActiveTripScreenState extends State<ConductorActiveTripScreen>
    with WidgetsBindingObserver {
  late final ActiveTripController _controller;

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  void _onArrivedPickup() async {
    await _controller.onArrivedPickup();
    if (!mounted || _controller.isDisposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('¡Cliente recogido! Navegando al destino'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.grey[100],
        body: Stack(
          children: [
            // Mapa a pantalla completa
            Positioned.fill(child: _buildMap(isDark)),

            // Controles superiores flotantes
            Positioned(
              top: statusBarHeight + 8,
              left: 12,
              right: 12,
              child: _buildTopControls(isDark),
            ),

            // Card de navegación compacta (distancia y tiempo)
            Positioned(
              top: statusBarHeight + 70,
              left: 16,
              right: 16,
              child: _buildNavigationCard(isDark),
            ),

            // Botones de mapa flotantes (derecha)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.42,
              right: 16,
              child: _buildMapControls(isDark),
            ),

            // Indicador de velocidad (izquierda)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.42,
              left: 16,
              child: _buildSpeedIndicator(isDark),
            ),

            // Panel inferior draggable
            _buildBottomPanel(isDark),

            // Loading overlay
            if (_controller.loadingRoute) _buildLoadingOverlay(isDark),

            // Error banner
            if (_controller.error != null)
              Positioned(
                top: statusBarHeight + 140,
                left: 16,
                right: 16,
                child: _buildErrorBanner(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    if (_controller.mapError) {
      return _buildMapFallback(isDark);
    }

    return MapWidget(
      key: const ValueKey('conductorTripMap'),
      cameraOptions: CameraOptions(
        center: _controller.driverLocation ?? _controller.pickup,
        zoom: 16,
        pitch: 45, // Vista 3D por defecto para navegación
        bearing: _controller.currentBearing,
      ),
      styleUri: isDark
          ? 'mapbox://styles/mapbox/navigation-night-v1'
          : 'mapbox://styles/mapbox/navigation-day-v1',
      onMapCreated: _controller.onMapCreated,
      textureView: true,
      androidHostingMode: AndroidPlatformViewHostingMode.TLHC_HC,
      onStyleLoadedListener: (eventData) => _controller.onStyleLoaded(),
      onMapLoadErrorListener: _controller.onMapLoadError,
    );
  }

  Widget _buildMapFallback(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [Colors.grey[900]!, Colors.black]
              : [Colors.grey[200]!, Colors.grey[100]!],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 64,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Mapa no disponible',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _controller.mapError = false);
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControls(bool isDark) {
    return Row(
      children: [
        // Botón atrás
        _FloatingButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context, true);
          },
          isDark: isDark,
          size: 44,
        ),
        const SizedBox(width: 12),

        // Estado del viaje
        Expanded(child: _buildStatusPill(isDark)),

        const SizedBox(width: 12),

        // Menú opciones
        _FloatingButton(
          icon: Icons.more_vert_rounded,
          onTap: () {
            HapticFeedback.lightImpact();
            _showOptionsMenu(context, isDark);
          },
          isDark: isDark,
          size: 44,
        ),
      ],
    );
  }

  Widget _buildStatusPill(bool isDark) {
    final color = _controller.toPickup ? AppColors.warning : AppColors.success;
    final text = _controller.toPickup ? 'Ir a recoger' : 'En camino';
    final icon = _controller.toPickup
        ? Icons.navigation_rounded
        : Icons.directions_car_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black54 : Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.5), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
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

  Widget _buildNavigationCard(bool isDark) {
    final target = _controller.toPickup
        ? _controller.pickup
        : _controller.dropoff;
    double dist = _controller.driverLocation != null
        ? _controller.calculateDistance(_controller.driverLocation!, target)
        : 0;
    String distText = dist < 1000
        ? '${dist.toInt()} m'
        : '${(dist / 1000).toStringAsFixed(1)} km';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.blue600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icono de dirección
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.straight_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Distancia
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  distText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  _controller.toPickup
                      ? 'hacia el punto de recogida'
                      : 'hacia el destino',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Tiempo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
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

  Widget _buildMapControls(bool isDark) {
    return Column(
      children: [
        // Centrar en conductor
        _FloatingButton(
          icon: Icons.my_location_rounded,
          onTap: () {
            HapticFeedback.lightImpact();
            _controller.centerOnDriver();
          },
          isDark: isDark,
        ),
        const SizedBox(height: 10),

        // Toggle 3D
        _FloatingButton(
          icon: _controller.is3DMode ? Icons.view_in_ar : Icons.map_outlined,
          onTap: () {
            HapticFeedback.lightImpact();
            _controller.toggle3DMode();
          },
          isDark: isDark,
          isActive: _controller.is3DMode,
        ),
      ],
    );
  }

  Widget _buildSpeedIndicator(bool isDark) {
    final speedInt = _controller.currentSpeed.toInt();
    final isMoving = speedInt > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black54 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$speedInt',
            style: TextStyle(
              color: isMoving
                  ? AppColors.primary
                  : (isDark ? Colors.white : Colors.grey[800]),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'km/h',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey[500],
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(bool isDark) {
    // Calcular datos para el panel
    final fallbackDistance = _controller.driverLocation != null
        ? _controller.calculateDistance(
                _controller.driverLocation!,
                _controller.pickup,
              ) /
              1000
        : 0.0;
    final displayDistance = _controller.distanceKm > 0
        ? _controller.distanceKm
        : fallbackDistance;
    final arrivalTime = _controller.etaMinutes > 0
        ? DateTime.now().add(Duration(minutes: _controller.etaMinutes))
        : null;
    final arrivalLabel = arrivalTime != null
        ? '${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return DraggableBottomPanel(
      isDark: isDark,
      toPickup: _controller.toPickup,
      passengerName: widget.clienteNombre ?? '',
      pickupAddress: widget.direccionOrigen,
      destinationAddress: widget.direccionDestino,
      etaMinutes: _controller.etaMinutes,
      distanceKm: displayDistance,
      arrivalTime: arrivalLabel,
      isLoading: _controller.loadingRoute,
      onArrivedPickup: _onArrivedPickup,
      onFinishTrip: () => Navigator.pop(context, true),
      onCall: () {
        // TODO: Implementar llamada
      },
      onMessage: () {
        // TODO: Implementar mensaje
      },
    );
  }

  Widget _buildLoadingOverlay(bool isDark) {
    return Positioned.fill(
      child: Container(
        color: Colors.black38,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Calculando ruta...',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.grey[800],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _controller.error!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _controller.error = null),
            child: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _OptionItem(
              icon: Icons.cancel_outlined,
              label: 'Cancelar viaje',
              color: AppColors.error,
              isDark: isDark,
              onTap: () {
                Navigator.pop(ctx);
                _showCancelDialog(context, isDark);
              },
            ),
            const SizedBox(height: 8),
            _OptionItem(
              icon: Icons.support_agent_rounded,
              label: 'Contactar soporte',
              isDark: isDark,
              onTap: () {
                Navigator.pop(ctx);
                // TODO: Contactar soporte
              },
            ),
            const SizedBox(height: 8),
            _OptionItem(
              icon: Icons.report_problem_outlined,
              label: 'Reportar problema',
              isDark: isDark,
              onTap: () {
                Navigator.pop(ctx);
                // TODO: Reportar problema
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Cancelar viaje?',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.grey[900],
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Esta acción no se puede deshacer y puede afectar tu calificación.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Volver',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, false);
            },
            child: Text(
              'Cancelar viaje',
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

class _FloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final double size;
  final bool isActive;

  const _FloatingButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
    this.size = 48,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withOpacity(0.15)
                : (isDark ? Colors.black54 : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: isActive
                ? Border.all(
                    color: AppColors.primary.withOpacity(0.5),
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
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

class _OptionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool isDark;
  final VoidCallback onTap;

  const _OptionItem({
    required this.icon,
    required this.label,
    this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? (isDark ? Colors.white : Colors.grey[800]);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: itemColor, size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: itemColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : Colors.grey[400],
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
