import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/trip_request_service.dart';
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/services/sound_service.dart';
import '../../../../theme/app_colors.dart';
import 'user_trip_accepted_screen.dart';

class SearchingDriverScreen extends StatefulWidget {
  final dynamic solicitudId;
  final int clienteId;
  final double latitudOrigen;
  final double longitudOrigen;
  final String direccionOrigen;
  final double latitudDestino;
  final double longitudDestino;
  final String direccionDestino;
  final String tipoVehiculo;

  const SearchingDriverScreen({
    super.key,
    required this.solicitudId,
    required this.clienteId,
    required this.latitudOrigen,
    required this.longitudOrigen,
    required this.direccionOrigen,
    required this.latitudDestino,
    required this.longitudDestino,
    required this.direccionDestino,
    required this.tipoVehiculo,
  });

  int get solicitudIdAsInt {
    if (solicitudId is int) return solicitudId;
    if (solicitudId is String) return int.tryParse(solicitudId) ?? 0;
    return 0;
  }

  @override
  State<SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends State<SearchingDriverScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  
  Timer? _searchTimer;
  Timer? _statusTimer; // Polling para detectar aceptación
  List<Map<String, dynamic>> _nearbyDrivers = [];
  bool _isCancelling = false;
  int _searchSeconds = 0;
  double _currentRadiusKm = 2.0;
  bool _tripAccepted = false; // Flag para evitar múltiples navegaciones
  
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startSearching();
    _startStatusPolling(); // Iniciar polling de estado
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  void _startSearching() {
    _searchDrivers();
    
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      setState(() {
        _searchSeconds++;
        _updateRadius();
      });
      
      if (_searchSeconds % 3 == 0) {
        _searchDrivers();
      }
    });
  }

  void _updateRadius() {
    double newRadius = 2.0;
    double newZoom = 15.0;
    
    if (_searchSeconds >= 120) {
      newRadius = 10.0;
      newZoom = 13.0;
    } else if (_searchSeconds >= 90) {
      newRadius = 7.0;
      newZoom = 13.5;
    } else if (_searchSeconds >= 60) {
      newRadius = 5.0;
      newZoom = 14.0;
    } else if (_searchSeconds >= 30) {
      newRadius = 3.0;
      newZoom = 14.5;
    }
    
    if (newRadius != _currentRadiusKm) {
      _currentRadiusKm = newRadius;
      _mapController.move(
        LatLng(widget.latitudOrigen, widget.longitudOrigen),
        newZoom,
      );
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _searchDrivers() async {
    if (!mounted) return;
    final drivers = await TripRequestService.findNearbyDrivers(
      latitude: widget.latitudOrigen,
      longitude: widget.longitudOrigen,
      vehicleType: widget.tipoVehiculo,
      radiusKm: _currentRadiusKm,
    );
    if (mounted) {
      setState(() => _nearbyDrivers = drivers);
    }
  }

  /// Inicia el polling para detectar cuando un conductor acepta la solicitud
  void _startStatusPolling() {
    print('🚀 [SearchingDriverScreen] INICIANDO POLLING para solicitud ${widget.solicitudIdAsInt}');
    // Consultar estado cada 3 segundos
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkTripStatus();
    });
    // También verificar inmediatamente
    _checkTripStatus();
  }

  /// Verifica el estado de la solicitud para detectar cuando es aceptada
  Future<void> _checkTripStatus() async {
    if (!mounted || _tripAccepted) return;
    
    print('🔍 [SearchingDriverScreen] Checking status for solicitud: ${widget.solicitudIdAsInt}');
    
    try {
      final result = await TripRequestService.getTripStatus(
        solicitudId: widget.solicitudIdAsInt,
      );
      
      print('📩 [SearchingDriverScreen] Response: ${result}');
      
      if (!mounted || _tripAccepted) return;
      
      if (result['success'] == true) {
        final trip = result['trip'];
        final estado = trip['estado'] as String?;
        
        print('📊 [SearchingDriverScreen] Estado actual: $estado');
        
        // Si el conductor aceptó la solicitud
        if (estado == 'aceptada' || estado == 'conductor_asignado') {
          print('✅ [SearchingDriverScreen] ¡CONDUCTOR ACEPTÓ! Navegando a UserTripAcceptedScreen...');
          _tripAccepted = true; // Evitar múltiples navegaciones
          _searchTimer?.cancel();
          _statusTimer?.cancel();
          
          // Reproducir sonido de notificación
          try {
            await SoundService.playRequestNotification();
          } catch (_) {}
          
          // Vibración de feedback
          HapticFeedback.heavyImpact();
          
          // Obtener info del conductor
          final conductor = trip['conductor'] as Map<String, dynamic>?;
          
          // Navegar a la pantalla de viaje aceptado
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => UserTripAcceptedScreen(
                  solicitudId: widget.solicitudIdAsInt,
                  clienteId: widget.clienteId,
                  latitudOrigen: widget.latitudOrigen,
                  longitudOrigen: widget.longitudOrigen,
                  direccionOrigen: widget.direccionOrigen,
                  latitudDestino: widget.latitudDestino,
                  longitudDestino: widget.longitudDestino,
                  direccionDestino: widget.direccionDestino,
                  conductorInfo: conductor,
                ),
              ),
            );
          }
        } else if (estado == 'cancelada') {
          // La solicitud fue cancelada
          _statusTimer?.cancel();
          _searchTimer?.cancel();
          // Sólo mostrar el diálogo si NO estamos cancelando nosotros
          if (mounted && !_isCancelling) {
            _showCancelledDialog();
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking trip status: $e');
    }
  }

  /// Muestra diálogo cuando la solicitud fue cancelada
  void _showCancelledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel, color: AppColors.error, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Solicitud cancelada')),
          ],
        ),
        content: const Text('No se encontraron conductores disponibles. Por favor intenta de nuevo.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelTrip() async {
    setState(() => _isCancelling = true);
    try {
      final success = await TripRequestService.cancelTripRequest(widget.solicitudIdAsInt);
      if (mounted && success) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _showCancelDialog() {
    if (_isCancelling) return;
    HapticFeedback.mediumImpact();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.cancel_rounded, color: AppColors.error),
            const SizedBox(width: 12),
            const Text('¿Cancelar viaje?'),
          ],
        ),
        content: const Text('Se cancelará tu solicitud. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Seguir buscando'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              _cancelTrip();
            },
            child: const Text('Sí, cancelar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String get _formattedTime {
    final m = _searchSeconds ~/ 60;
    final s = _searchSeconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _statusTimer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final origin = LatLng(widget.latitudOrigen, widget.longitudOrigen);
    final destination = LatLng(widget.latitudDestino, widget.longitudDestino);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // MAPA
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: origin,
              initialZoom: 15.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
                userAgentPackageName: 'com.viax.app',
              ),
              // Círculo del radio
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: origin,
                    radius: _currentRadiusKm * 1000,
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderColor: AppColors.primary.withValues(alpha: 0.3),
                    borderStrokeWidth: 2,
                    useRadiusInMeter: true,
                  ),
                ],
              ),
              // Marcadores
              MarkerLayer(
                markers: [
                  // Origen con animación
                  Marker(
                    point: origin,
                    width: 180,
                    height: 180,
                    child: _buildAnimatedOrigin(),
                  ),
                  // Destino
                  Marker(
                    point: destination,
                    width: 40,
                    height: 40,
                    child: _buildDestinationMarker(),
                  ),
                  // Conductores
                  ..._buildDriverMarkers(),
                ],
              ),
            ],
          ),
          
          // HEADER
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (isDark ? Colors.black : Colors.white),
                    (isDark ? Colors.black : Colors.white)
                        .withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Row(
                    children: [
                      // Botón cerrar
                      Material(
                        color: isDark ? Colors.white12 : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        elevation: isDark ? 0 : 2,
                        child: InkWell(
                          onTap: _showCancelDialog,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.close_rounded,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Tiempo
                      _buildInfoChip(
                        Icons.timer_outlined,
                        _formattedTime,
                        isDark,
                      ),
                      const SizedBox(width: 8),
                      // Radio
                      _buildInfoChip(
                        Icons.radar_rounded,
                        '${_currentRadiusKm.toStringAsFixed(0)} km',
                        isDark,
                        highlighted: _currentRadiusKm > 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // PANEL INFERIOR
          Positioned(
            bottom: bottomPadding + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Estado
                  Row(
                    children: [
                      _buildMiniRadar(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buscando conductor',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _nearbyDrivers.isEmpty
                                  ? 'Radio: ${_currentRadiusKm.toStringAsFixed(0)} km...'
                                  : '${_nearbyDrivers.length} conductor${_nearbyDrivers.length == 1 ? "" : "es"} cerca',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Barra de progreso
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Área de búsqueda',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          Text(
                            '${_currentRadiusKm.toStringAsFixed(0)} / 10 km',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _currentRadiusKm / 10.0,
                          minHeight: 6,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Info viaje
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 2,
                              height: 20,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                            const Icon(Icons.location_on, color: AppColors.error, size: 16),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.direccionOrigen,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.direccionDestino,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Botón cancelar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _isCancelling ? null : _showCancelDialog,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _isCancelling
                              ? Colors.grey.withValues(alpha: 0.3)
                              : AppColors.error.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isCancelling
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Cancelar búsqueda',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, bool isDark, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.primary.withValues(alpha: 0.15)
            : (isDark ? Colors.white12 : Colors.white),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? null : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: highlighted ? AppColors.primary : (isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: highlighted ? AppColors.primary : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedOrigin() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _waveController]),
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Ondas
            ...List.generate(3, (i) {
              final delay = i / 3;
              final progress = (_waveController.value + delay) % 1.0;
              final size = 40 + (100 * progress);
              final opacity = 0.5 * (1 - progress);
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: opacity),
                    width: 2.5 * (1 - progress),
                  ),
                ),
              );
            }),
            // Glow
            Container(
              width: 50 + (_pulseController.value * 15),
              height: 50 + (_pulseController.value * 15),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.25),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            // Centro
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 22),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDestinationMarker() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
    );
  }

  List<Marker> _buildDriverMarkers() {
    return _nearbyDrivers.map((d) {
      final lat = d['latitud'] as double?;
      final lng = d['longitud'] as double?;
      if (lat == null || lng == null) return null;
      return Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6),
            ],
          ),
          child: const Icon(Icons.local_taxi_rounded, color: AppColors.accent, size: 22),
        ),
      );
    }).whereType<Marker>().toList();
  }

  Widget _buildMiniRadar() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ...List.generate(2, (i) {
                final progress = (_waveController.value + (i * 0.5)) % 1.0;
                return Container(
                  width: 26 + (22 * progress),
                  height: 26 + (22 * progress),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4 * (1 - progress)),
                      width: 2,
                    ),
                  ),
                );
              }),
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_taxi, color: Colors.white, size: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
