import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../../global/services/trip_status_navigation_service.dart';
import '../../../../../routes/route_names.dart';
import '../../../services/trip_request_service.dart';
import 'searching_driver_state.dart';

class SearchingDriverEvent {
  final String type;
  final TripNavigationDecision? navigationDecision;
  final String? message;

  const SearchingDriverEvent._({
    required this.type,
    this.navigationDecision,
    this.message,
  });

  factory SearchingDriverEvent.navigate(TripNavigationDecision decision) {
    return SearchingDriverEvent._(
      type: 'navigate',
      navigationDecision: decision,
    );
  }

  factory SearchingDriverEvent.cancelledBySystem() {
    return const SearchingDriverEvent._(type: 'cancelled_by_system');
  }

  factory SearchingDriverEvent.goHome() {
    return const SearchingDriverEvent._(type: 'go_home');
  }

  factory SearchingDriverEvent.error(String message) {
    return SearchingDriverEvent._(type: 'error', message: message);
  }

  factory SearchingDriverEvent.searchTimedOut([String? message]) {
    return SearchingDriverEvent._(
      type: 'search_timed_out',
      message: message ?? 'No encontramos conductor disponible',
    );
  }
}

class _RadiusStage {
  final int radiusKm;
  final int waitSeconds;
  final String label;

  const _RadiusStage({
    required this.radiusKm,
    required this.waitSeconds,
    required this.label,
  });
}

class SearchingDriverController extends ChangeNotifier {
  SearchingDriverController({
    required this.solicitudId,
    required this.clienteId,
    required this.tipoVehiculo,
    required this.companyCandidates,
    this.initialEmpresaId,
    this.initialCompanyName,
    this.initialCompanyLogoUrl,
    this.initialFlowState = SearchFlowState.searchingDriver,
  }) {
    _companyById = _buildCompanyLookup();
    final initialCompany = _resolveInitialCompany();
    _state = SearchingDriverState.initial(
      initialCompany: initialCompany,
      initialFlowState: initialFlowState,
    );

    final initialNearbyHint = _resolveInitialNearbyDriverHint(
      initialCompany?.id,
    );
    if (initialNearbyHint > 0) {
      _state = _state.copyWith(nearbyDriverCount: initialNearbyHint);
    }
  }

  final int solicitudId;
  final int clienteId;
  final String tipoVehiculo;
  final List<Map<String, dynamic>> companyCandidates;
  final int? initialEmpresaId;
  final String? initialCompanyName;
  final String? initialCompanyLogoUrl;
  final SearchFlowState initialFlowState;

  late final Map<int, CompanyPreview> _companyById;

  late SearchingDriverState _state;
  SearchingDriverState get state => _state;

  final StreamController<SearchingDriverEvent> _events =
      StreamController<SearchingDriverEvent>.broadcast();
  Stream<SearchingDriverEvent> get events => _events.stream;

  Timer? _stageTimer;
  Timer? _pollTimer;
  Timer? _dynamicMessageTimer;
  bool _statusRequestInFlight = false;
  bool _stageTickInFlight = false;
  bool _tripClosed = false;
  bool _disposed = false;

  /// Todos los conductores reales acumulados desde el backend durante la sesión.
  final List<DriverPreview> _allRealDrivers = [];

  /// Ultima firma entregada por backend (meta.signature).
  String _lastServerSignature = '';

  /// Huella local del payload para detectar cambios aunque la firma se estanque.
  String _lastPayloadFingerprint = '';

  static const List<_RadiusStage> _radiusStages = [
    _RadiusStage(radiusKm: 2, waitSeconds: 70, label: 'Buscando cerca de ti'),
    _RadiusStage(
      radiusKm: 4,
      waitSeconds: 60,
      label: 'Ampliando búsqueda a 4 km',
    ),
    _RadiusStage(
      radiusKm: 6,
      waitSeconds: 60,
      label: 'Ampliando búsqueda a 6 km',
    ),
    _RadiusStage(
      radiusKm: 9,
      waitSeconds: 90,
      label: 'Buscando en área extendida',
    ),
  ];

  static const int _totalMaxSeconds = 300;
  static const Duration _pollInterval = Duration(seconds: 3);
  static const Duration _dynamicMessageInterval = Duration(seconds: 4);
  static const int _statusWaitSeconds = 3;
  static const int _maxStoredDrivers = 8;
  static const int _searchingMessageCount = 2;

  void start() {
    _stopTimers();

    _stageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_tripClosed || _disposed) return;
      if (_state.flowState != SearchFlowState.searchingDriver) return;
      if (_state.noDriverTerminal) return;
      unawaited(_handleStageTick());
    });

    _startDynamicMessageTimer();

    if (solicitudId <= 0) {
      return;
    }

    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _pollTripStatus();
    });

    _pollTripStatus();
  }

  void setFlowState(SearchFlowState flowState) {
    if (_state.flowState == flowState) return;

    _setState(_state.copyWith(flowState: flowState, dynamicMessageIndex: 0));
  }

  void updateSheetSize(double nextSize) {
    final clampedSize = nextSize.clamp(0.12, 0.85);
    if ((_state.sheetSize - clampedSize).abs() < 0.01) {
      return;
    }

    _setState(_state.copyWith(sheetSize: clampedSize));
  }

  void _startDynamicMessageTimer() {
    _dynamicMessageTimer?.cancel();
    _dynamicMessageTimer = Timer.periodic(_dynamicMessageInterval, (_) {
      if (_disposed || _tripClosed) return;
      if (_state.flowState != SearchFlowState.searchingDriver) return;
      if (_state.noDriverTerminal) return;

      final nextIndex =
          (_state.dynamicMessageIndex + 1) % _searchingMessageCount;
      _setState(_state.copyWith(dynamicMessageIndex: nextIndex));
    });
  }

  Future<void> _handleStageTick() async {
    if (_stageTickInFlight || _disposed || _tripClosed) {
      return;
    }

    _stageTickInFlight = true;
    try {
      final nextTotalSeconds = _state.totalSecondsElapsed + 1;
      final nextSecondsInStage = _state.secondsInStage + 1;

      if (nextTotalSeconds >= _totalMaxSeconds) {
        _setState(
          _state.copyWith(
            elapsedSeconds: nextTotalSeconds,
            totalSecondsElapsed: nextTotalSeconds,
            secondsInStage: nextSecondsInStage,
          ),
        );
        await _handleSearchTimeout();
        return;
      }

      final currentStage = _radiusStages[_state.currentStageIndex];
      if (nextSecondsInStage >= currentStage.waitSeconds) {
        final nextStageIndex = _state.currentStageIndex + 1;
        if (nextStageIndex >= _radiusStages.length) {
          _setState(
            _state.copyWith(
              elapsedSeconds: nextTotalSeconds,
              totalSecondsElapsed: nextTotalSeconds,
              secondsInStage: nextSecondsInStage,
            ),
          );
          await _handleSearchTimeout();
          return;
        }

        final nextStage = _radiusStages[nextStageIndex];
        _setState(
          _state.copyWith(
            elapsedSeconds: nextTotalSeconds,
            totalSecondsElapsed: nextTotalSeconds,
            searchRadiusKm: nextStage.radiusKm.toDouble(),
            currentRadiusKm: nextStage.radiusKm,
            currentStageIndex: nextStageIndex,
            secondsInStage: 0,
            radiusLabel: nextStage.label,
            dynamicMessageIndex: 0,
          ),
        );
        await _syncRadiusWithBackend(nextStage.radiusKm);
        return;
      }

      _setState(
        _state.copyWith(
          elapsedSeconds: nextTotalSeconds,
          totalSecondsElapsed: nextTotalSeconds,
          secondsInStage: nextSecondsInStage,
        ),
      );
    } finally {
      _stageTickInFlight = false;
    }
  }

  Future<void> _syncRadiusWithBackend(int radiusKm) async {
    if (_disposed || _tripClosed || solicitudId <= 0) {
      return;
    }

    try {
      await TripRequestService.updateTripSearchRadius(
        solicitudId: solicitudId,
        radiusKm: radiusKm,
      );
    } catch (_) {
      // Ignorado: mantenemos la ampliación local aunque falle la sincronización.
    }
  }

  Future<void> _handleSearchTimeout() async {
    if (_disposed || _tripClosed) {
      return;
    }

    _tripClosed = true;
    _stopTimers();

    _setState(
      _state.copyWith(
        noDriverTerminal: true,
        dynamicMessageIndex: 0,
        isCancelling: false,
      ),
    );

    try {
      await TripRequestService.cancelTripRequest(solicitudId);
    } catch (_) {
      // Ignorado: la UI igual debe cerrar la búsqueda localmente.
    }

    _emit(
      SearchingDriverEvent.searchTimedOut(
        'No encontramos conductor disponible',
      ),
    );
  }

  /// Agrega un conductor real a la lista si no está duplicado.
  void _registerRealDriver(DriverPreview driver) {
    final yaExiste = _allRealDrivers.any((d) => d.name == driver.name);
    if (yaExiste) return;
    if (_allRealDrivers.length >= _maxStoredDrivers) return;
    _allRealDrivers.add(driver);
  }

  Future<void> cancelSearch() async {
    if (_disposed || _tripClosed || _state.isCancelling) return;

    if (_state.noDriverTerminal) {
      _tripClosed = true;
      _stopTimers();
      _emit(SearchingDriverEvent.goHome());
      return;
    }

    _setState(_state.copyWith(isCancelling: true));

    try {
      final success = await TripRequestService.cancelTripRequest(solicitudId);
      if (!success) {
        _setState(_state.copyWith(isCancelling: false));
        _emit(
          SearchingDriverEvent.error(
            'No pudimos cancelar la busqueda. Intentalo de nuevo.',
          ),
        );
        return;
      }

      _tripClosed = true;
      _stopTimers();
      _emit(SearchingDriverEvent.goHome());
    } catch (e) {
      _setState(_state.copyWith(isCancelling: false));
      _emit(
        SearchingDriverEvent.error(
          e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _pollTripStatus() async {
    if (_disposed || _tripClosed || _statusRequestInFlight) return;

    _statusRequestInFlight = true;
    try {
      final result = await TripRequestService.getTripStatus(
        solicitudId: solicitudId,
        waitSeconds: _statusWaitSeconds,
      );

      if (_disposed || _tripClosed) return;
      if (result['success'] != true || result['trip'] is! Map) return;

      final trip = Map<String, dynamic>.from(result['trip'] as Map);
      final serverSignature = (result['meta']?['signature'] ?? '').toString();
      final estado = TripStatusNavigationService.normalizeStatus(
        trip['estado'],
      );

      final rawMatchingStatus =
          (trip['matching_status'] ?? result['meta']?['matching_status'])
              ?.toString();
      final backendMatchingStatus = TripStatusNavigationService.normalizeStatus(
        rawMatchingStatus,
      );
      final matchingStatus = _normalizeMatchingStatus(
        rawMatchingStatus,
        normalizedEstado: estado,
      );

      final searchMode = _normalizeSearchMode(trip['search_mode']);
      final empresaId = _parseNullableInt(trip['empresa_id']);
      final rawUiMessage =
          (trip['ui_message'] ??
                  result['ui_message'] ??
                  result['meta']?['ui_message'])
              ?.toString();
      final uiMessage = rawUiMessage?.trim() ?? '';

      final driverCheckingRaw = trip['driver_checking'];
      final driverChecking = driverCheckingRaw is Map
          ? Map<String, dynamic>.from(driverCheckingRaw)
          : null;
      final assignedDriverRaw = trip['conductor'] ?? trip['driver'];
      final assignedDriver = assignedDriverRaw is Map
          ? DriverPreview.fromDriverChecking(
              Map<String, dynamic>.from(assignedDriverRaw),
            )
          : null;

      final backendNearbyCount =
          _parseNullableInt(
            trip['conductores_cerca'] ??
                trip['nearby_count'] ??
                result['conductores_cerca'],
          ) ??
          0;
      final hasRecoverableRealtimeActivity =
          driverChecking != null ||
          backendNearbyCount > 0 ||
          backendMatchingStatus == 'checking' ||
          backendMatchingStatus == 'driver_viewing' ||
          backendMatchingStatus == 'sending_request' ||
          backendMatchingStatus == 'contacting_drivers';
      final noDriverTerminal =
          !hasRecoverableRealtimeActivity &&
          (TripStatusNavigationService.isNoDriverTerminalStatus(estado) ||
              TripStatusNavigationService.isNoDriverTerminalStatus(
                matchingStatus,
              ));
      final activeCheckingDriver = !noDriverTerminal && driverChecking != null
          ? DriverPreview.fromDriverChecking(driverChecking)
          : null;
      final fallbackNearbyCount = _resolveFallbackNearbyDriverCount(
        empresaId: empresaId,
        searchMode: searchMode,
      );
      final hintedNearbyCount = backendNearbyCount > 0
          ? backendNearbyCount
          : (noDriverTerminal ? 0 : fallbackNearbyCount);
      final nearbyCount = (!noDriverTerminal && activeCheckingDriver != null)
          ? (hintedNearbyCount > 0 ? hintedNearbyCount : 1)
          : hintedNearbyCount;

      // Registrar conductor real en cada poll para no perder cambios de backend.
      final prevDriverCount = _allRealDrivers.length;
      if (activeCheckingDriver != null) {
        _registerRealDriver(activeCheckingDriver);
      }
      final driversChanged = _allRealDrivers.length != prevDriverCount;

      final decision = TripStatusNavigationService.resolveUserNavigation(
        trip: trip,
        fallbackClienteId: clienteId,
      );
      final shouldShowDriverFound =
          decision?.routeName == RouteNames.userTripAccepted;
      final nextFlowState = shouldShowDriverFound
          ? SearchFlowState.driverFound
          : SearchFlowState.searchingDriver;
      final effectiveVisibleDriver = shouldShowDriverFound
          ? (assignedDriver ?? activeCheckingDriver)
          : (noDriverTerminal ? null : activeCheckingDriver);

      final nextCompany = _resolveCurrentCompany(
        empresaId: empresaId,
        searchMode: searchMode,
        driverChecking: driverChecking,
      );

      final payloadFingerprint = [
        estado,
        matchingStatus,
        searchMode,
        (empresaId ?? 0).toString(),
        nearbyCount.toString(),
        noDriverTerminal ? '1' : '0',
        uiMessage,
        (nextCompany?.id ?? 0).toString(),
        nextCompany?.name ?? '',
        _driverCheckingFingerprint(driverChecking),
        _allRealDrivers.length.toString(),
        nextFlowState.name,
        effectiveVisibleDriver?.name ?? '',
      ].join('|');

      final serverSignatureChanged =
          serverSignature.isNotEmpty && serverSignature != _lastServerSignature;
      final payloadChanged = payloadFingerprint != _lastPayloadFingerprint;
      final shouldUpdateState =
          serverSignatureChanged ||
          payloadChanged ||
          driversChanged ||
          effectiveVisibleDriver != _state.visibleDriver ||
          nextFlowState != _state.flowState;

      if (shouldUpdateState) {
        _setState(
          _state.copyWith(
            flowState: nextFlowState,
            matchingStatus: matchingStatus,
            uiMessage: uiMessage,
            visibleDriver: noDriverTerminal ? null : effectiveVisibleDriver,
            hasRealDrivers:
                _allRealDrivers.isNotEmpty ||
                assignedDriver != null ||
                activeCheckingDriver != null,
            nearbyDriverCount: nearbyCount,
            currentCompany: nextCompany,
            searchMode: searchMode,
            noDriverTerminal: noDriverTerminal,
            dynamicMessageIndex:
                nextFlowState == SearchFlowState.searchingDriver
                ? _state.dynamicMessageIndex
                : 0,
          ),
        );
      }

      if (serverSignature.isNotEmpty) {
        _lastServerSignature = serverSignature;
      }
      _lastPayloadFingerprint = payloadFingerprint;

      if (TripStatusNavigationService.isCancelledStatus(estado)) {
        _tripClosed = true;
        _stopTimers();
        _emit(SearchingDriverEvent.cancelledBySystem());
        return;
      }

      if (noDriverTerminal) {
        _stopTimers();
        return;
      }

      if (decision != null &&
          decision.routeName != RouteNames.userSearchingDriver) {
        _tripClosed = true;
        _stopTimers();
        _emit(SearchingDriverEvent.navigate(decision));
        return;
      }
    } finally {
      _statusRequestInFlight = false;
    }
  }

  String _normalizeMatchingStatus(
    String? rawStatus, {
    required String normalizedEstado,
  }) {
    final status = TripStatusNavigationService.normalizeStatus(rawStatus);

    if (status == 'searching' ||
        status == 'expanding_search' ||
        status == 'contacting_drivers') {
      return status;
    }

    if (status == 'search_expanded') {
      return 'expanding_search';
    }

    if (status == 'checking' ||
        status == 'driver_viewing' ||
        status == 'sending_request') {
      return 'contacting_drivers';
    }

    if (normalizedEstado == 'expanding_search') {
      return 'expanding_search';
    }

    if (normalizedEstado == 'searching' ||
        normalizedEstado == 'pendiente' ||
        normalizedEstado == 'buscando' ||
        normalizedEstado == 'buscando_conductor') {
      return 'searching';
    }

    return 'searching';
  }

  String _normalizeSearchMode(dynamic rawMode) {
    final mode = (rawMode?.toString() ?? '').toLowerCase().trim();
    return mode == 'empresa' ? 'empresa' : 'azar';
  }

  String _driverCheckingFingerprint(Map<String, dynamic>? driverChecking) {
    if (driverChecking == null) return '';

    final id =
        _parseNullableInt(
          driverChecking['id'] ?? driverChecking['driver_id'],
        ) ??
        0;
    final nombre = (driverChecking['nombre'] ?? driverChecking['name'] ?? '')
        .toString()
        .trim();
    final status = (driverChecking['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final empresaId = _parseNullableInt(driverChecking['empresa_id']) ?? 0;
    final empresa =
        (driverChecking['empresa'] ?? driverChecking['company'] ?? '')
            .toString()
            .trim();
    final shownAt = (driverChecking['shown_at'] ?? '').toString().trim();

    return '$id|$nombre|$status|$empresaId|$empresa|$shownAt';
  }

  CompanyPreview? _resolveCurrentCompany({
    required int? empresaId,
    required String searchMode,
    required Map<String, dynamic>? driverChecking,
  }) {
    if (empresaId != null && empresaId > 0) {
      final knownCompany = _companyById[empresaId];
      if (knownCompany != null) {
        return knownCompany;
      }

      final companyName =
          (driverChecking?['empresa'] ?? driverChecking?['company'] ?? '')
              .toString()
              .trim();
      return CompanyPreview(
        id: empresaId,
        name: companyName.isEmpty ? 'Empresa #$empresaId' : companyName,
        logoUrl: '',
      );
    }

    final driverCompanyName =
        (driverChecking?['empresa'] ?? driverChecking?['company'] ?? '')
            .toString()
            .trim();
    if (driverCompanyName.isNotEmpty) {
      return CompanyPreview(id: 0, name: driverCompanyName, logoUrl: '');
    }

    if (searchMode == 'empresa' && initialEmpresaId != null) {
      return _companyById[initialEmpresaId!] ?? _resolveInitialCompany();
    }

    return null;
  }

  Map<int, CompanyPreview> _buildCompanyLookup() {
    final map = <int, CompanyPreview>{};
    for (final company in companyCandidates) {
      final id = _parseNullableInt(company['id']);
      if (id == null || id <= 0) continue;

      final name = (company['nombre'] ?? company['name'] ?? '')
          .toString()
          .trim();
      final logo = (company['logo_url'] ?? company['logo'] ?? '')
          .toString()
          .trim();
      map[id] = CompanyPreview(
        id: id,
        name: name.isEmpty ? 'Empresa' : name,
        logoUrl: logo,
      );
    }
    return map;
  }

  int _resolveInitialNearbyDriverHint(int? preferredCompanyId) {
    if (companyCandidates.isEmpty) {
      return 0;
    }

    if (preferredCompanyId != null && preferredCompanyId > 0) {
      for (final company in companyCandidates) {
        final companyId = _parseNullableInt(company['id']);
        if (companyId == preferredCompanyId) {
          return _extractCandidateNearbyCount(company);
        }
      }
    }

    var maxNearby = 0;
    for (final company in companyCandidates) {
      final count = _extractCandidateNearbyCount(company);
      if (count > maxNearby) {
        maxNearby = count;
      }
    }
    return maxNearby;
  }

  int _resolveFallbackNearbyDriverCount({
    required int? empresaId,
    required String searchMode,
  }) {
    if (companyCandidates.isEmpty) {
      return 0;
    }

    if (empresaId != null && empresaId > 0) {
      for (final company in companyCandidates) {
        final companyId = _parseNullableInt(company['id']);
        if (companyId == empresaId) {
          return _extractCandidateNearbyCount(company);
        }
      }
    }

    if (searchMode == 'empresa' && initialEmpresaId != null) {
      for (final company in companyCandidates) {
        final companyId = _parseNullableInt(company['id']);
        if (companyId == initialEmpresaId) {
          return _extractCandidateNearbyCount(company);
        }
      }
    }

    var maxNearby = 0;
    for (final company in companyCandidates) {
      final count = _extractCandidateNearbyCount(company);
      if (count > maxNearby) {
        maxNearby = count;
      }
    }
    return maxNearby;
  }

  int _extractCandidateNearbyCount(Map<String, dynamic> company) {
    final rawCount =
        company['conductores_cerca'] ??
        company['conductores'] ??
        company['conductores_cercanos'] ??
        company['total_conductores_cerca'] ??
        company['nearby_count'] ??
        company['drivers_nearby'];

    final parsed = _parseNullableInt(rawCount) ?? 0;
    return parsed < 0 ? 0 : parsed;
  }

  CompanyPreview? _resolveInitialCompany() {
    if (initialEmpresaId != null && initialEmpresaId! > 0) {
      final known = _companyById[initialEmpresaId!];
      if (known != null) {
        return known;
      }

      final name = (initialCompanyName ?? '').trim();
      return CompanyPreview(
        id: initialEmpresaId!,
        name: name.isEmpty ? 'Empresa' : name,
        logoUrl: (initialCompanyLogoUrl ?? '').trim(),
      );
    }

    return null;
  }

  int? _parseNullableInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value == null) {
      return null;
    }
    return int.tryParse(value.toString());
  }

  void _emit(SearchingDriverEvent event) {
    if (_disposed || _events.isClosed) return;
    _events.add(event);
  }

  void _setState(SearchingDriverState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  void _stopTimers() {
    _stageTimer?.cancel();
    _pollTimer?.cancel();
    _dynamicMessageTimer?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimers();
    _events.close();
    super.dispose();
  }
}
