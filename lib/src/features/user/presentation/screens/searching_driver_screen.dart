import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/trip_request_service.dart';
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/services/sound_service.dart';
import '../../../../global/widgets/map_retry_wrapper.dart';
import '../../../../theme/app_colors.dart';
import 'package:viax/src/features/company/presentation/widgets/company_logo.dart';
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
  final int? initialEmpresaId;
  final String? initialCompanyName;
  final String? initialCompanyLogoUrl;
  final List<Map<String, dynamic>> companyCandidates;

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
    this.initialEmpresaId,
    this.initialCompanyName,
    this.initialCompanyLogoUrl,
    this.companyCandidates = const [],
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
  int? _currentEmpresaId;
  String? _currentEmpresaNombre;
  String? _currentEmpresaLogo;
  bool _syncingCompany = false;
  final List<_SearchCompanyCandidate> _companyRotationQueue = [];
  int _currentCompanyIndex = -1;
  int _lastCompanySwitchSecond = 0;

  static const int _companySwitchIntervalNoDriversSec = 8;
  static const int _companySwitchIntervalWithDriversSec = 18;
  
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _initializeCompanyRotation();
    _initAnimations();
    _startSearching();
    _startStatusPolling(); // Iniciar polling de estado
  }

  void _initializeCompanyRotation() {
    final parsed = widget.companyCandidates
        .map(_SearchCompanyCandidate.fromMap)
        .where((company) => company.id > 0)
        .toList();

    parsed.sort((a, b) {
      final aHasActive = a.conductores > 0;
      final bHasActive = b.conductores > 0;
      if (aHasActive != bHasActive) {
        return bHasActive ? 1 : -1;
      }

      final ad = a.distanciaConductorKm ?? 999999;
      final bd = b.distanciaConductorKm ?? 999999;
      final distanceCompare = ad.compareTo(bd);
      if (distanceCompare != 0) return distanceCompare;

      final driversCompare = b.conductores.compareTo(a.conductores);
      if (driversCompare != 0) return driversCompare;

      return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    });

    if (widget.initialEmpresaId != null) {
      final preferredIdx = parsed.indexWhere((c) => c.id == widget.initialEmpresaId);
      if (preferredIdx > 0) {
        final preferred = parsed.removeAt(preferredIdx);
        parsed.insert(0, preferred);
      }
    }

    _companyRotationQueue
      ..clear()
      ..addAll(parsed);

    if (widget.initialEmpresaId != null) {
      _currentEmpresaId = widget.initialEmpresaId;
      _currentEmpresaNombre = widget.initialCompanyName;
      _currentEmpresaLogo = widget.initialCompanyLogoUrl;
      final idx = _companyRotationQueue.indexWhere((c) => c.id == widget.initialEmpresaId);
      _currentCompanyIndex = idx >= 0 ? idx : (_companyRotationQueue.isNotEmpty ? 0 : -1);
    } else if (_companyRotationQueue.isNotEmpty) {
      _currentCompanyIndex = 0;
      final first = _companyRotationQueue.first;
      _currentEmpresaId = first.id;
      _currentEmpresaNombre = first.nombre;
      _currentEmpresaLogo = first.logoUrl;
    }

    debugPrint(
      '🔁 [SearchingDriverScreen] Rotación init: cola=${_companyRotationQueue.length}, '
      'empresaInicial=$_currentEmpresaId, index=$_currentCompanyIndex',
    );
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
    _bootstrapDynamicCompanySearch();
    
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      setState(() {
        _searchSeconds++;
        _updateRadius();
      });

      _maybeRotateCompany();
      
      if (_searchSeconds % 3 == 0) {
        _searchDrivers();
      }
    });
  }

  Future<void> _bootstrapDynamicCompanySearch() async {
    if (_currentEmpresaId != null) {
      await _syncSearchCompany(_currentEmpresaId);
    }
    await _searchDrivers();
    await _maybeRotateCompany(forceImmediate: true);
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
      empresaId: _currentEmpresaId,
      radiusKm: _currentRadiusKm,
    );
    if (mounted) {
      debugPrint(
        '🚕 [SearchingDriverScreen] Conductores cerca=${drivers.length}, '
        'empresa=${_currentEmpresaId ?? 'libre'}',
      );
      setState(() => _nearbyDrivers = drivers);
    }
  }

  Future<void> _maybeRotateCompany({bool forceImmediate = false}) async {
    if (!mounted || _tripAccepted || _syncingCompany) return;
    if (_companyRotationQueue.length < 2) return;

    final noDriversNearby = _nearbyDrivers.isEmpty;
    final switchInterval = noDriversNearby
        ? _companySwitchIntervalNoDriversSec
        : _companySwitchIntervalWithDriversSec;

    if (!forceImmediate) {
      if (_searchSeconds < 4) return;
      if ((_searchSeconds - _lastCompanySwitchSecond) < switchInterval) return;
    }

    final shouldRotate = noDriversNearby || _searchSeconds >= 60 || forceImmediate;
    if (!shouldRotate) return;

    final startIndex = _currentCompanyIndex < 0 ? 0 : _currentCompanyIndex;
    final queueLen = _companyRotationQueue.length;

    debugPrint(
      '🔁 [SearchingDriverScreen] Intentando rotación: sec=$_searchSeconds, '
      'sinConductores=$noDriversNearby, actual=$_currentEmpresaId, index=$startIndex',
    );

    for (int step = 1; step <= queueLen; step++) {
      final nextIndex = (startIndex + step) % queueLen;
      final nextCompany = _companyRotationQueue[nextIndex];

      if (nextCompany.id == _currentEmpresaId) {
        continue;
      }

      final changed = await _syncSearchCompany(
        nextCompany.id,
        forcedName: nextCompany.nombre,
        forcedLogo: nextCompany.logoUrl,
        forcedIndex: nextIndex,
      );

      if (changed) {
        debugPrint(
          '✅ [SearchingDriverScreen] Rotó empresa a ${nextCompany.nombre} (${nextCompany.id})',
        );
        _lastCompanySwitchSecond = _searchSeconds;
        await _searchDrivers();
        if (mounted) {
          HapticFeedback.lightImpact();
        }
        return;
      }

      debugPrint(
        '⚠️ [SearchingDriverScreen] Falló cambio a ${nextCompany.nombre} (${nextCompany.id}), probando siguiente',
      );
    }

    debugPrint('⚠️ [SearchingDriverScreen] No se pudo rotar a ninguna empresa candidata');

    if (noDriversNearby && _currentEmpresaId != null) {
      final fallbackToFreeMode = await _syncSearchCompany(
        null,
        forcedName: 'Al azar',
        forcedLogo: null,
        forcedIndex: -1,
      );
      if (fallbackToFreeMode) {
        debugPrint('✅ [SearchingDriverScreen] Fallback a libre competencia aplicado');
        _lastCompanySwitchSecond = _searchSeconds;
        await _searchDrivers();
      } else {
        debugPrint('⚠️ [SearchingDriverScreen] También falló fallback a libre competencia');
      }
    }
  }

  Future<bool> _syncSearchCompany(
    int? empresaId, {
    String? forcedName,
    String? forcedLogo,
    int? forcedIndex,
  }) async {
    if (_syncingCompany || _tripAccepted) return false;
    if (_currentEmpresaId == empresaId && forcedName == null && forcedLogo == null) {
      return false;
    }

    _syncingCompany = true;
    try {
      final result = await TripRequestService.updateTripSearchCompany(
        solicitudId: widget.solicitudIdAsInt,
        clienteId: widget.clienteId,
        empresaId: empresaId,
      );

      if (result['success'] != true) {
        debugPrint(
          '⚠️ [SearchingDriverScreen] updateTripSearchCompany falló: '
          '${result['message'] ?? 'sin mensaje'} (empresa=$empresaId)',
        );
      }

      if (result['success'] == true && mounted) {
        final backendCompany = result['empresa'] as Map<String, dynamic>?;

        setState(() {
          _currentEmpresaId = empresaId;
          _currentEmpresaNombre =
              forcedName ?? backendCompany?['nombre']?.toString() ?? _currentEmpresaNombre;
          _currentEmpresaLogo =
              forcedLogo ?? backendCompany?['logo_url']?.toString() ?? _currentEmpresaLogo;
          if (forcedIndex != null) {
            _currentCompanyIndex = forcedIndex;
          } else {
            _currentCompanyIndex = _companyRotationQueue.indexWhere((c) => c.id == empresaId);
          }
        });

        return true;
      }
    } catch (_) {
      // Fallback silencioso
    } finally {
      _syncingCompany = false;
    }

    return false;
  }

  String _vehicleImagePath() {
    switch (widget.tipoVehiculo) {
      case 'moto':
        return 'assets/images/vehicles/moto3d.png';
      case 'motocarro':
        return 'assets/images/vehicles/motocarro3d.png';
      case 'taxi':
        return 'assets/images/vehicles/taxi3d.png';
      case 'auto':
      case 'carro':
      default:
        return 'assets/images/vehicles/auto3d.png';
    }
  }

  String _vehicleLabel() {
    switch (widget.tipoVehiculo) {
      case 'moto':
        return 'Moto';
      case 'motocarro':
        return 'Motocarro';
      case 'taxi':
        return 'Taxi';
      case 'auto':
      case 'carro':
        return 'Carro';
      default:
        return widget.tipoVehiculo;
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
      
      print('📩 [SearchingDriverScreen] Response: $result');
      
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
          MapRetryWrapper(
            isDark: isDark,
            builder: ({required mapKey, required onMapReady, required onTileError}) => FlutterMap(
              key: mapKey,
              mapController: _mapController,
              options: MapOptions(
                initialCenter: origin,
                initialZoom: 15.0,
                onMapReady: onMapReady,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
                  userAgentPackageName: 'com.viax.app',
                  errorTileCallback: (tile, error, stackTrace) => onTileError(error, stackTrace),
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
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Image.asset(
                                    _vehicleImagePath(),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.directions_car,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${_vehicleLabel()} · ${_currentEmpresaNombre ?? 'Al azar'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ),
                                if (_currentEmpresaLogo != null && _currentEmpresaLogo!.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CompanyLogo(
                                      logoKey: _currentEmpresaLogo,
                                      nombreEmpresa: _currentEmpresaNombre ?? 'Empresa',
                                      size: 20,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
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

class _SearchCompanyCandidate {
  _SearchCompanyCandidate({
    required this.id,
    required this.nombre,
    required this.conductores,
    this.logoUrl,
    this.distanciaConductorKm,
  });

  final int id;
  final String nombre;
  final int conductores;
  final String? logoUrl;
  final double? distanciaConductorKm;

  factory _SearchCompanyCandidate.fromMap(Map<String, dynamic> json) {
    final rawConductores = json['conductores'];
    int conductores = 0;
    if (rawConductores is int) {
      conductores = rawConductores;
    } else if (rawConductores != null) {
      conductores = int.tryParse('$rawConductores') ?? 0;
    }

    return _SearchCompanyCandidate(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      nombre: (json['nombre'] ?? '').toString(),
      conductores: conductores,
      logoUrl: json['logo_url']?.toString(),
      distanciaConductorKm: json['distancia_conductor_km'] == null
          ? null
          : double.tryParse('${json['distancia_conductor_km']}'),
    );
  }
}
