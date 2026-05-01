import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../global/services/mapbox_service.dart';
import '../../../../global/services/route_preview_cache.dart';
import '../../../../global/widgets/map_retry_wrapper.dart';
import '../../../../routes/route_names.dart';
import '../../../../theme/app_colors.dart';
import 'searching_driver/searching_driver_controller.dart';
import 'searching_driver/searching_driver_state.dart';
import 'searching_driver/widgets/dynamic_status_header.dart';
import 'searching_driver/widgets/search_flow_sheet.dart';

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
  final SearchFlowState initialFlowState;
  final String? estimatedPriceLabel;
  final String paymentLabel;
  final List<String> serviceFeatures;

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
    this.initialFlowState = SearchFlowState.searchingDriver,
    this.estimatedPriceLabel,
    this.paymentLabel = 'Efectivo o tarjeta',
    this.serviceFeatures = const [
      'Seguimiento en tiempo real',
      'Asignacion continua',
      'Cobertura ampliada',
    ],
  });

  int get solicitudIdAsInt {
    if (solicitudId is int) return solicitudId;
    if (solicitudId is String) return int.tryParse(solicitudId) ?? 0;
    return 0;
  }

  @override
  State<SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends State<SearchingDriverScreen> {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  late final SearchingDriverController _controller;
  StreamSubscription<SearchingDriverEvent>? _eventSubscription;
  MapboxRoute? _plannedRoute;
  String _lastRouteGeometrySignature = '';
  String _lastViewportRouteSignature = '';
  bool _isLoadingPlannedRoute = false;

  bool _didSyncInitialViewport = false;
  SearchFlowState? _lastFlowState;
  String _lastFocusedDriverName = '';

  LatLng get _origin => LatLng(widget.latitudOrigen, widget.longitudOrigen);
  LatLng get _destination =>
      LatLng(widget.latitudDestino, widget.longitudDestino);
  List<LatLng> get _routeWaypoints => <LatLng>[_origin, _destination];

  @override
  void initState() {
    super.initState();

    final cachedRoute = RoutePreviewCache.instance.getCachedRoute(
      waypoints: _routeWaypoints,
    );
    if (cachedRoute != null) {
      _plannedRoute = cachedRoute.route;
      _lastRouteGeometrySignature = _hashRouteGeometry(
        cachedRoute.route.geometry,
      );
    }

    _controller = SearchingDriverController(
      solicitudId: widget.solicitudIdAsInt,
      clienteId: widget.clienteId,
      tipoVehiculo: widget.tipoVehiculo,
      companyCandidates: widget.companyCandidates,
      initialEmpresaId: widget.initialEmpresaId,
      initialCompanyName: widget.initialCompanyName,
      initialCompanyLogoUrl: widget.initialCompanyLogoUrl,
      initialFlowState: widget.initialFlowState,
    );

    _eventSubscription = _controller.events.listen(_handleControllerEvent);
    _controller.start();

    if (_plannedRoute == null || _plannedRoute!.geometry.length < 2) {
      unawaited(_ensurePlannedRouteLoaded());
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerEvent(SearchingDriverEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case 'navigate':
        final decision = event.navigationDecision;
        if (decision == null) return;

        final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
        if (!isCurrentRoute) return;

        Navigator.pushReplacementNamed(
          context,
          decision.routeName,
          arguments: decision.arguments,
        );
        break;

      case 'cancelled_by_system':
        _showCancelledDialog();
        break;

      case 'search_timed_out':
        _showSearchTimedOutDialog(
          (event.message ?? 'No encontramos conductor disponible').trim(),
        );
        break;

      case 'go_home':
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(RouteNames.home, (route) => false);
        break;

      case 'error':
        final message = (event.message ?? '').trim();
        if (message.isEmpty) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        break;
    }
  }

  void _showCancelledDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_rounded, color: AppColors.warning),
              SizedBox(width: 10),
              Expanded(child: Text('Busqueda finalizada')),
            ],
          ),
          content: const Text(
            'Tu solicitud ya no esta activa. Puedes volver al inicio e intentarlo de nuevo.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(RouteNames.home, (route) => false);
              },
              child: const Text('Volver al inicio'),
            ),
          ],
        );
      },
    );
  }

  void _showSearchTimedOutDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.search_off_rounded, color: AppColors.warning),
              SizedBox(width: 10),
              Expanded(child: Text('No encontramos conductor disponible')),
            ],
          ),
          content: Text(
            '$message. Cancelamos la busqueda automaticamente para que puedas intentarlo de nuevo.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(RouteNames.home, (route) => false);
              },
              child: const Text('Volver al inicio'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCancelDialog() async {
    final state = _controller.state;
    final closeOnly = state.noDriverTerminal;

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Icon(
                closeOnly ? Icons.home_rounded : Icons.close_rounded,
                color: AppColors.error,
              ),
              const SizedBox(width: 10),
              Text(closeOnly ? 'Cerrar busqueda' : 'Cancelar busqueda'),
            ],
          ),
          content: Text(
            closeOnly
                ? 'No hay conductores disponibles en este momento. Puedes volver al inicio.'
                : 'Esta accion cancelara la solicitud actual. ¿Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Seguir en el mapa'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                closeOnly ? 'Volver al inicio' : 'Cancelar solicitud',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (shouldCancel == true) {
      HapticFeedback.mediumImpact();
      await _controller.cancelSearch();
    }
  }

  void _handleFareSelected() {
    HapticFeedback.selectionClick();
    _controller.setFlowState(SearchFlowState.searchingDriver);
  }

  Future<void> _ensurePlannedRouteLoaded() async {
    if (_isLoadingPlannedRoute) {
      return;
    }

    _isLoadingPlannedRoute = true;
    try {
      final route = await RoutePreviewCache.instance
          .getOrFetchRoute(waypoints: _routeWaypoints)
          .timeout(const Duration(seconds: 12), onTimeout: () => null);

      if (!mounted || route == null || route.geometry.length < 2) {
        return;
      }

      final nextSignature = _hashRouteGeometry(route.geometry);
      if (nextSignature == _lastRouteGeometrySignature) {
        return;
      }

      setState(() {
        _plannedRoute = route;
        _lastRouteGeometrySignature = nextSignature;
      });
    } catch (_) {
      // Ignorado: si la ruta no carga, evitamos la linea recta para no degradar la UI.
    } finally {
      _isLoadingPlannedRoute = false;
    }
  }

  String _vehicleLabel() {
    switch (widget.tipoVehiculo.toLowerCase().trim()) {
      case 'moto':
        return 'Moto';
      case 'mototaxi':
        return 'Mototaxi';
      case 'taxi':
        return 'Taxi';
      case 'carro':
      case 'auto':
        return 'Carro';
      default:
        return widget.tipoVehiculo;
    }
  }

  String _formatTimer(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final restSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$restSeconds';
  }

  String _hashRouteGeometry(List<LatLng> points) {
    if (points.isEmpty) return 'empty';
    final first = points.first;
    final last = points.last;
    return '${points.length}|${first.latitude.toStringAsFixed(5)},${first.longitude.toStringAsFixed(5)}|${last.latitude.toStringAsFixed(5)},${last.longitude.toStringAsFixed(5)}';
  }

  String _estimatedAssignmentTime(SearchingDriverState state) {
    final now = DateTime.now();
    final estimatedMinutes = math.max(
      2,
      state.visibleDriver?.etaMinutes ?? (state.currentRadiusKm + 1),
    );
    final eta = now.add(Duration(minutes: estimatedMinutes));
    final hour = eta.hour.toString().padLeft(2, '0');
    final minute = eta.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int _effectiveNearbyDriverCount(SearchingDriverState state) {
    return math.max(
      state.nearbyDriverCount,
      state.visibleDriver != null ? 1 : 0,
    );
  }

  String _driverCountLabel(int count) {
    return count == 1
        ? '1 conductor cerca de ti'
        : '$count conductores cerca de ti';
  }

  String _watchingDriversSubtitle(SearchingDriverState state) {
    final watchingCount = _effectiveNearbyDriverCount(state);
    final companyName = state.currentCompany?.name.trim() ?? '';
    final companySuffix = companyName.isEmpty ? '' : ' · $companyName';
    final backendUiMessage = state.uiMessage.trim();

    if (backendUiMessage.isNotEmpty && state.visibleDriver == null) {
      return backendUiMessage;
    }

    if (state.visibleDriver != null) {
      if (watchingCount > 1) {
        return '${_driverCountLabel(watchingCount)}$companySuffix';
      }
      final etaMinutes = math.max(1, state.visibleDriver!.etaMinutes);
      return 'Tiempo estimado de respuesta: $etaMinutes min$companySuffix';
    }

    if (watchingCount > 0) {
      return '${_driverCountLabel(watchingCount)}$companySuffix';
    }

    if (state.matchingStatus == 'contacting_drivers') {
      return 'Estamos esperando la primera respuesta disponible$companySuffix';
    }

    return 'Seguimos revisando disponibilidad en tu zona$companySuffix';
  }

  List<FlowHeaderMessage> _buildHeaderMessages(SearchingDriverState state) {
    switch (state.flowState) {
      case SearchFlowState.confirmingDestination:
        return const [
          FlowHeaderMessage(
            title: 'Confirma tu destino',
            subtitle: 'Revisa la ruta antes de solicitar conductor',
          ),
        ];
      case SearchFlowState.selectingFare:
        return const [
          FlowHeaderMessage(
            title: 'Elige tu tarifa',
            subtitle: 'Compara servicio, pago y tiempo estimado',
          ),
        ];
      case SearchFlowState.driverFound:
        return [
          FlowHeaderMessage(
            title: 'Conductor asignado',
            subtitle: state.visibleDriver != null
                ? '${state.visibleDriver!.name} ya va hacia ti'
                : 'Tu conductor ya respondio a la solicitud',
          ),
        ];
      case SearchFlowState.searchingDriver:
        if (state.noDriverTerminal) {
          return const [
            FlowHeaderMessage(
              title: 'Sin conductores disponibles',
              subtitle: 'Puedes cerrar la busqueda o intentarlo nuevamente',
            ),
          ];
        }

        final backendUiMessage = state.uiMessage.trim();
        if (backendUiMessage.isNotEmpty && state.visibleDriver == null) {
          final nearbyDrivers = _effectiveNearbyDriverCount(state);
          return [
            FlowHeaderMessage(
              title: backendUiMessage,
              subtitle: nearbyDrivers > 0
                  ? _driverCountLabel(nearbyDrivers)
                  : _watchingDriversSubtitle(state),
            ),
            FlowHeaderMessage(
              title: state.radiusLabel,
              subtitle: 'Radio actual: ${state.currentRadiusKm} km',
            ),
          ];
        }

        if (state.visibleDriver != null) {
          return [
            FlowHeaderMessage(
              title: '${state.visibleDriver!.name} esta revisando tu solicitud',
              subtitle: _watchingDriversSubtitle(state),
            ),
            FlowHeaderMessage(
              title: state.radiusLabel,
              subtitle: 'Radio actual: ${state.currentRadiusKm} km',
            ),
          ];
        }

        final nearbyDrivers = _effectiveNearbyDriverCount(state);
        if (nearbyDrivers > 0) {
          return [
            FlowHeaderMessage(
              title: _driverCountLabel(nearbyDrivers),
              subtitle: _watchingDriversSubtitle(state),
            ),
            FlowHeaderMessage(
              title: state.radiusLabel,
              subtitle: 'Radio actual: ${state.currentRadiusKm} km',
            ),
          ];
        }

        if (state.matchingStatus == 'contacting_drivers') {
          return [
            FlowHeaderMessage(
              title: 'Enviando tu solicitud a conductores',
              subtitle: _watchingDriversSubtitle(state),
            ),
            FlowHeaderMessage(
              title: state.radiusLabel,
              subtitle: 'Radio actual: ${state.currentRadiusKm} km',
            ),
          ];
        }

        switch (state.currentStageIndex) {
          case 0:
            return [
              FlowHeaderMessage(
                title: 'Revisando conductores cerca...',
                subtitle: _watchingDriversSubtitle(state),
              ),
              FlowHeaderMessage(
                title: state.radiusLabel,
                subtitle: 'Radio actual: ${state.currentRadiusKm} km',
              ),
            ];
          case 1:
            return [
              const FlowHeaderMessage(
                title: 'Ampliando búsqueda a 4 km',
                subtitle: 'Buscando más conductores',
              ),
              FlowHeaderMessage(
                title: state.radiusLabel,
                subtitle: 'Radio actual: ${state.currentRadiusKm} km',
              ),
            ];
          case 2:
            return [
              const FlowHeaderMessage(
                title: 'Búsqueda en radio extendido',
                subtitle: 'Casi encontramos tu conductor',
              ),
              FlowHeaderMessage(
                title: state.radiusLabel,
                subtitle: 'Radio actual: ${state.currentRadiusKm} km',
              ),
            ];
          default:
            return [
              FlowHeaderMessage(
                title: 'Área de búsqueda máxima',
                subtitle:
                    'Asignación estimada: ${_estimatedAssignmentTime(state)}',
              ),
              FlowHeaderMessage(
                title: state.radiusLabel,
                subtitle: 'Radio actual: ${state.currentRadiusKm} km',
              ),
            ];
        }
    }
  }

  void _syncMapViewport(SearchingDriverState state) {
    final flowChanged = _lastFlowState != state.flowState;
    final driverFocusChanged =
        state.flowState == SearchFlowState.driverFound &&
        (state.visibleDriver?.name ?? '') != _lastFocusedDriverName;
    final routeGeometryChanged =
        _lastViewportRouteSignature != _lastRouteGeometrySignature;

    if (_didSyncInitialViewport &&
        !flowChanged &&
        !driverFocusChanged &&
        !routeGeometryChanged) {
      return;
    }

    _didSyncInitialViewport = true;
    _lastFlowState = state.flowState;
    _lastFocusedDriverName = state.visibleDriver?.name ?? '';
    _lastViewportRouteSignature = _lastRouteGeometrySignature;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: _boundsForState(state),
            padding: _cameraPaddingForState(state),
          ),
        );
      } catch (_) {
        // Ignorado: puede ocurrir antes de que el mapa termine de montar.
      }

      if (flowChanged) {
        await _snapSheetToCompact();
      }
    });
  }

  Future<void> _snapSheetToCompact() async {
    try {
      if (!_sheetController.isAttached) return;
      await _sheetController.animateTo(
        0.28,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      // Ignorado: el sheet puede no estar listo aún.
    }
  }

  EdgeInsets _cameraPaddingForState(SearchingDriverState state) {
    final normalizedSheet = ((state.sheetSize - 0.12) / (0.85 - 0.12)).clamp(
      0.0,
      1.0,
    );
    final bottom = lerpDouble(165, 430, normalizedSheet)!;
    final top = state.flowState == SearchFlowState.driverFound ? 128.0 : 144.0;
    return EdgeInsets.fromLTRB(56, top, 56, bottom);
  }

  LatLngBounds _boundsForState(SearchingDriverState state) {
    final routePoints = _plannedRoute?.geometry ?? const <LatLng>[];
    final points = routePoints.length > 1
        ? List<LatLng>.from(routePoints)
        : <LatLng>[_origin, _destination];
    final driverPoint = _driverPoint(state);
    if (driverPoint != null) {
      points.add(driverPoint);
    }
    return LatLngBounds.fromPoints(points);
  }

  LatLng _initialCenter() {
    return LatLng(
      (_origin.latitude + _destination.latitude) / 2,
      (_origin.longitude + _destination.longitude) / 2,
    );
  }

  LatLng? _driverPoint(SearchingDriverState state) {
    if (state.visibleDriver == null) return null;

    final distanceMeters = state.flowState == SearchFlowState.driverFound
        ? math.max(420.0, (state.visibleDriver!.etaMinutes * 180).toDouble())
        : state.currentRadiusKm * 1000 * 0.36;
    final angle = state.flowState == SearchFlowState.driverFound
        ? math.pi * 0.78
        : (state.totalSecondsElapsed * 0.22) + (math.pi / 6);

    final latOffset = (distanceMeters / 111000) * math.cos(angle);
    final lngOffset =
        (distanceMeters /
            (111000 * math.cos(_origin.latitude * math.pi / 180))) *
        math.sin(angle);

    return LatLng(_origin.latitude + latOffset, _origin.longitude + lngOffset);
  }

  List<Polyline> _buildPolylines(SearchingDriverState state) {
    final polylines = <Polyline>[];
    final routePoints = _plannedRoute?.geometry ?? const <LatLng>[];

    if (routePoints.length > 1) {
      polylines.add(
        Polyline(
          points: routePoints,
          strokeWidth: 12,
          color: Colors.black.withValues(alpha: 0.20),
          borderStrokeWidth: 0,
        ),
      );
      polylines.add(
        Polyline(
          points: routePoints,
          strokeWidth: 7,
          color: AppColors.primary,
          borderStrokeWidth: 0,
          gradientColors: const [
            AppColors.primaryLight,
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
      );
    }

    final driverPoint = _driverPoint(state);
    if (state.flowState == SearchFlowState.driverFound && driverPoint != null) {
      polylines.add(
        Polyline(
          points: [driverPoint, _origin],
          strokeWidth: 10,
          color: Colors.black.withValues(alpha: 0.16),
          borderStrokeWidth: 0,
        ),
      );
      polylines.add(
        Polyline(
          points: [driverPoint, _origin],
          strokeWidth: 5,
          color: const Color(0xFF1FAA6D),
        ),
      );
    }

    return polylines;
  }

  Color _searchCircleFillColor(SearchingDriverState state) {
    switch (state.currentRadiusKm) {
      case 2:
        return const Color(0xFF2B7FFF).withValues(alpha: 0.08);
      case 4:
        return const Color(0xFF2B7FFF).withValues(alpha: 0.06);
      case 6:
        return const Color(0xFFFF9B3D).withValues(alpha: 0.05);
      default:
        return const Color(0xFFFF8C2C).withValues(alpha: 0.07);
    }
  }

  Color _searchCircleBorderColor(SearchingDriverState state) {
    switch (state.currentRadiusKm) {
      case 2:
        return const Color(0xFF2B7FFF).withValues(alpha: 0.24);
      case 4:
        return const Color(0xFF2B7FFF).withValues(alpha: 0.18);
      case 6:
        return const Color(0xFFFF9B3D).withValues(alpha: 0.22);
      default:
        return const Color(0xFFFF8C2C).withValues(alpha: 0.28);
    }
  }

  List<CircleMarker> _buildCircles(
    SearchingDriverState state,
    double animatedRadiusKm,
  ) {
    final circles = <CircleMarker>[];

    if (state.flowState == SearchFlowState.searchingDriver) {
      final pulseFactor =
          0.88 + (0.12 * ((math.sin(state.totalSecondsElapsed * 0.9) + 1) / 2));
      circles.add(
        CircleMarker(
          point: _origin,
          radius: animatedRadiusKm * 1000 * pulseFactor,
          useRadiusInMeter: true,
          color: _searchCircleFillColor(state),
          borderColor: _searchCircleBorderColor(state),
          borderStrokeWidth: 2,
        ),
      );
    }

    if (state.flowState == SearchFlowState.selectingFare) {
      circles.add(
        CircleMarker(
          point: _origin,
          radius: 18,
          color: const Color(0xFFFF9B3D).withValues(alpha: 0.18),
          borderColor: const Color(0xFFFF9B3D).withValues(alpha: 0.40),
          borderStrokeWidth: 2,
        ),
      );
    }

    return circles;
  }

  Widget _buildCircleLayer(SearchingDriverState state) {
    if (state.flowState != SearchFlowState.searchingDriver) {
      return CircleLayer(
        circles: _buildCircles(state, state.currentRadiusKm.toDouble()),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: state.currentRadiusKm.toDouble()),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, animatedRadiusKm, _) {
        return CircleLayer(circles: _buildCircles(state, animatedRadiusKm));
      },
    );
  }

  List<Marker> _buildMarkers(SearchingDriverState state) {
    final markers = <Marker>[
      Marker(
        point: _origin,
        width: 80,
        height: 80,
        child: const _OriginMapMarker(),
      ),
      Marker(
        point: _destination,
        width: 50,
        height: 70,
        alignment: Alignment.topCenter,
        child: const _DestinationMapMarker(),
      ),
    ];

    if (state.flowState == SearchFlowState.searchingDriver) {
      markers.addAll(_buildNearbyDriverDots(state));
    }

    final driverPoint = _driverPoint(state);
    if (state.flowState == SearchFlowState.driverFound && driverPoint != null) {
      markers.add(
        Marker(
          point: driverPoint,
          width: 62,
          height: 62,
          child: _DriverMapMarker(driver: state.visibleDriver),
        ),
      );
    }

    return markers;
  }

  List<Marker> _buildNearbyDriverDots(SearchingDriverState state) {
    final markers = <Marker>[];
    final count = math.min(
      math.max(state.nearbyDriverCount, state.visibleDriver != null ? 1 : 0),
      4,
    );

    if (count == 0) {
      return markers;
    }

    for (var index = 0; index < count; index++) {
      final distanceMeters =
          state.currentRadiusKm * 1000 * (0.20 + (index * 0.06));
      final angle =
          (state.totalSecondsElapsed * 0.28) + ((2 * math.pi * index) / count);
      final latOffset = (distanceMeters / 111000) * math.cos(angle);
      final lngOffset =
          (distanceMeters /
              (111000 * math.cos(_origin.latitude * math.pi / 180))) *
          math.sin(angle);

      markers.add(
        Marker(
          point: LatLng(
            _origin.latitude + latOffset,
            _origin.longitude + lngOffset,
          ),
          width: 18,
          height: 18,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.95),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildFlowLeadingIcon(SearchFlowState flowState) {
    switch (flowState) {
      case SearchFlowState.confirmingDestination:
        return const _FlowLeadingIcon(
          icon: Icons.place_rounded,
          color: Color(0xFFFF9B3D),
          backgroundColor: Color(0xFFFFF2E4),
        );
      case SearchFlowState.selectingFare:
        return const _FlowLeadingIcon(
          icon: Icons.sell_rounded,
          color: AppColors.primary,
          backgroundColor: Color(0xFFEAF2FF),
        );
      case SearchFlowState.driverFound:
        return const _FlowLeadingIcon(
          icon: Icons.verified_rounded,
          color: Color(0xFF1FAA6D),
          backgroundColor: Color(0xFFEAF9F1),
        );
      case SearchFlowState.searchingDriver:
        return const _FlowLeadingIcon(
          icon: Icons.route_rounded,
          color: AppColors.primary,
          backgroundColor: Color(0xFFEAF2FF),
        );
    }
  }

  Widget _buildTrailingStatus(SearchingDriverState state) {
    switch (state.flowState) {
      case SearchFlowState.confirmingDestination:
        return const _PulsingPinIcon();
      case SearchFlowState.selectingFare:
        return const _StaticStatusIcon(
          icon: Icons.local_offer_rounded,
          color: AppColors.primary,
        );
      case SearchFlowState.driverFound:
        return _DriverAssignedStatusAvatar(driver: state.visibleDriver);
      case SearchFlowState.searchingDriver:
        return const _PulsingBroadcastIcon();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final horizontalPadding = MediaQuery.sizeOf(context).width < 360
            ? 12.0
            : 16.0;
        final state = _controller.state;
        _syncMapViewport(state);

        final overlayStyle = isDark
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
                systemNavigationBarColor: AppColors.darkBackground,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
                systemNavigationBarColor: AppColors.lightBackground,
                systemNavigationBarIconBrightness: Brightness.dark,
              );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Stack(
              fit: StackFit.expand,
              children: [
                MapRetryWrapper(
                  isDark: isDark,
                  builder:
                      ({
                        required mapKey,
                        required onMapReady,
                        required onTileError,
                      }) {
                        return FlutterMap(
                          key: mapKey,
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _initialCenter(),
                            initialZoom: 13.2,
                            onMapReady: onMapReady,
                            interactionOptions: const InteractionOptions(
                              flags:
                                  InteractiveFlag.drag |
                                  InteractiveFlag.pinchZoom,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: MapboxService.getTileUrl(
                                isDarkMode: isDark,
                              ),
                              userAgentPackageName: 'com.viax.app',
                              errorTileCallback: (tile, error, stackTrace) {
                                onTileError(error, stackTrace);
                              },
                            ),
                            PolylineLayer(polylines: _buildPolylines(state)),
                            _buildCircleLayer(state),
                            MarkerLayer(markers: _buildMarkers(state)),
                          ],
                        );
                      },
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        12,
                        horizontalPadding,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _RouteOverviewPill(
                            route: _plannedRoute,
                            isLoading: _isLoadingPlannedRoute,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.end,
                              children: [
                                _HeaderChip(
                                  icon: Icons.schedule_rounded,
                                  label: _formatTimer(
                                    state.totalSecondsElapsed,
                                  ),
                                ),
                                _HeaderChip(
                                  icon: Icons.two_wheeler_rounded,
                                  label:
                                      '${_vehicleLabel()} · ${state.searchMode == 'azar' ? 'Al azar' : 'Empresa'}',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SearchFlowSheet(
                  state: state,
                  sheetController: _sheetController,
                  headerMessages: _buildHeaderMessages(state),
                  leading: _buildFlowLeadingIcon(state.flowState),
                  trailing: _buildTrailingStatus(state),
                  originLabel: widget.direccionOrigen,
                  destinationLabel: widget.direccionDestino,
                  vehicleLabel: _vehicleLabel(),
                  priceLabel: widget.estimatedPriceLabel,
                  paymentLabel: widget.paymentLabel,
                  serviceFeatures: widget.serviceFeatures,
                  onCancel: _showCancelDialog,
                  onFareSelected: _handleFareSelected,
                  onSheetSizeChanged: _controller.updateSheetSize,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RouteOverviewPill extends StatelessWidget {
  final MapboxRoute? route;
  final bool isLoading;

  const _RouteOverviewPill({required this.route, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (route == null && !isLoading) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final child = route == null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Conectando ruta...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time_filled_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                route!.formattedDuration,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Icon(
                Icons.directions_car_filled_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                route!.formattedDistance,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints: BoxConstraints(
            minHeight: 44,
            maxWidth: MediaQuery.sizeOf(context).width - 40,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: isDark ? 0.90 : 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: isDark ? 0.90 : 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: isDark ? 0.18 : 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.09),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: colorScheme.onSurface.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowLeadingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _FlowLeadingIcon({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _StaticStatusIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _StaticStatusIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _PulsingBroadcastIcon extends StatefulWidget {
  const _PulsingBroadcastIcon();

  @override
  State<_PulsingBroadcastIcon> createState() => _PulsingBroadcastIconState();
}

class _PulsingBroadcastIconState extends State<_PulsingBroadcastIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.92,
      end: 1.14,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.wifi_tethering_rounded,
          color: AppColors.primary,
          size: 25,
        ),
      ),
    );
  }
}

class _PulsingPinIcon extends StatefulWidget {
  const _PulsingPinIcon();

  @override
  State<_PulsingPinIcon> createState() => _PulsingPinIconState();
}

class _PulsingPinIconState extends State<_PulsingPinIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.94,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF2E4),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.place_rounded,
          color: Color(0xFFFF9B3D),
          size: 25,
        ),
      ),
    );
  }
}

class _DriverAssignedStatusAvatar extends StatefulWidget {
  final DriverPreview? driver;

  const _DriverAssignedStatusAvatar({required this.driver});

  @override
  State<_DriverAssignedStatusAvatar> createState() =>
      _DriverAssignedStatusAvatarState();
}

class _DriverAssignedStatusAvatarState
    extends State<_DriverAssignedStatusAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.96,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: const Color(0xFF1FAA6D).withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: CircleAvatar(
          backgroundColor: colorScheme.surface,
          backgroundImage: widget.driver?.photoUrl != null
              ? NetworkImage(widget.driver!.photoUrl!)
              : null,
          child: widget.driver?.photoUrl == null
              ? const Icon(Icons.person_rounded, color: Color(0xFF1FAA6D))
              : null,
        ),
      ),
    );
  }
}

class _OriginMapMarker extends StatefulWidget {
  const _OriginMapMarker();

  @override
  State<_OriginMapMarker> createState() => _OriginMapMarkerState();
}

class _OriginMapMarkerState extends State<_OriginMapMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 1.0,
      end: 1.18,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _scale = Tween<double>(
      begin: 0.98,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pulseValue = _pulse.value;
        return Transform.scale(
          scale: _scale.value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 60 * pulseValue,
                height: 60 * pulseValue,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight.withValues(
                    alpha: 0.30 / pulseValue,
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.38),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DestinationMapMarker extends StatelessWidget {
  const _DestinationMapMarker();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 3,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
            ),
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: AppColors.primaryDark,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryDark, width: 3),
              ),
              child: const Icon(
                Icons.location_on,
                color: AppColors.primaryDark,
                size: 24,
              ),
            ),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 30,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ],
    );
  }
}

class _DriverMapMarker extends StatelessWidget {
  final DriverPreview? driver;

  const _DriverMapMarker({required this.driver});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF1FAA6D).withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        backgroundColor: colorScheme.surface,
        backgroundImage: driver?.photoUrl != null
            ? NetworkImage(driver!.photoUrl!)
            : null,
        child: driver?.photoUrl == null
            ? const Icon(
                Icons.directions_car_filled_rounded,
                color: Color(0xFF1FAA6D),
              )
            : null,
      ),
    );
  }
}
