import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:viax/src/routes/route_names.dart';
import 'system_overlay_service.dart';

/// Datos del viaje activo necesarios para navegar de vuelta
class ActiveTripData {
  final int solicitudId;
  final int userId;
  final String userRole; // 'cliente' o 'conductor'
  final double origenLat;
  final double origenLng;
  final String direccionOrigen;
  final double destinoLat;
  final double destinoLng;
  final String direccionDestino;
  final Map<String, dynamic>? conductorInfo;
  final Map<String, dynamic>? clienteInfo;
  final String? clienteNombre;
  final String? clienteFoto;
  final String? initialTripStatus;

  const ActiveTripData({
    required this.solicitudId,
    required this.userId,
    required this.userRole,
    required this.origenLat,
    required this.origenLng,
    required this.direccionOrigen,
    required this.destinoLat,
    required this.destinoLng,
    required this.direccionDestino,
    this.conductorInfo,
    this.clienteInfo,
    this.clienteNombre,
    this.clienteFoto,
    this.initialTripStatus,
  });

  bool get isClient => userRole == 'cliente';
  bool get isDriver => userRole == 'conductor';

  ActiveTripData copyWith({
    int? solicitudId,
    int? userId,
    String? userRole,
    double? origenLat,
    double? origenLng,
    String? direccionOrigen,
    double? destinoLat,
    double? destinoLng,
    String? direccionDestino,
    Map<String, dynamic>? conductorInfo,
    Map<String, dynamic>? clienteInfo,
    String? clienteNombre,
    String? clienteFoto,
    String? initialTripStatus,
  }) {
    return ActiveTripData(
      solicitudId: solicitudId ?? this.solicitudId,
      userId: userId ?? this.userId,
      userRole: userRole ?? this.userRole,
      origenLat: origenLat ?? this.origenLat,
      origenLng: origenLng ?? this.origenLng,
      direccionOrigen: direccionOrigen ?? this.direccionOrigen,
      destinoLat: destinoLat ?? this.destinoLat,
      destinoLng: destinoLng ?? this.destinoLng,
      direccionDestino: direccionDestino ?? this.direccionDestino,
      conductorInfo: conductorInfo ?? this.conductorInfo,
      clienteInfo: clienteInfo ?? this.clienteInfo,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteFoto: clienteFoto ?? this.clienteFoto,
      initialTripStatus: initialTripStatus ?? this.initialTripStatus,
    );
  }
}

/// Servicio singleton que gestiona la navegación cuando hay un viaje activo.
/// 
/// Permite que el usuario navegue libremente por la app mientras hay un viaje
/// en curso, mostrando un FAB flotante para regresar a la pantalla del viaje.
/// También maneja el overlay del sistema cuando el usuario sale de la app.
class ActiveTripNavigationService extends ChangeNotifier {
  static const Set<String> _clientMeetingPointStates = {
    'aceptada',
    'conductor_asignado',
    'en_camino',
    'conductor_llego',
  };

  // Singleton
  static final ActiveTripNavigationService _instance = ActiveTripNavigationService._internal();
  factory ActiveTripNavigationService() => _instance;
  ActiveTripNavigationService._internal() {
    _initSystemOverlay();
  }

  /// Navigator key global para navegación desde cualquier parte
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Servicio de overlay del sistema
  final SystemOverlayService _systemOverlay = SystemOverlayService();

  /// Indica si el overlay del sistema está habilitado
  bool _systemOverlayEnabled = true;
  bool get systemOverlayEnabled => _systemOverlayEnabled;

  /// Datos del viaje activo actual
  ActiveTripData? _activeTripData;
  ActiveTripData? get activeTripData => _activeTripData;

  /// Indica si el usuario está actualmente en la pantalla del viaje
  bool _isOnTripScreen = false;
  bool get isOnTripScreen => _isOnTripScreen;

  /// Indica si hay un viaje activo
  bool get hasActiveTrip => _activeTripData != null;

  /// Indica si debe mostrarse el FAB flotante
  /// (hay viaje activo Y el usuario NO está en la pantalla del viaje)
  bool get shouldShowFloatingFab => hasActiveTrip && !_isOnTripScreen;

  /// Stream controller para notificar cambios
  final _stateController = StreamController<bool>.broadcast();
  Stream<bool> get stateStream => _stateController.stream;

  /// Inicializa el overlay del sistema
  void _initSystemOverlay() {
    // Configurar callback para navegación desde el overlay del sistema
    _systemOverlay.setNavigationCallback((userRole, solicitudId) {
      debugPrint('🔵 [ActiveTripNav] Navegando desde overlay del sistema');
      _navigateFromSystemOverlay();
    });

    // Callback cuando el usuario elimina el overlay
    _systemOverlay.setOverlayRemovedCallback(() {
      _systemOverlayEnabled = false;
      notifyListeners();
    });
  }

  /// Navega al viaje activo desde el overlay del sistema
  void _navigateFromSystemOverlay() {
    if (_activeTripData == null) return;
    
    final data = _activeTripData!;
    if (data.isClient) {
      _navigateToClientTrip(data);
    } else {
      _navigateToDriverTrip(data);
    }
  }

  /// Registra un viaje activo
  void registerActiveTrip(ActiveTripData tripData) {
    _activeTripData = tripData;
    _isOnTripScreen = true;
    _notifyChange();
    debugPrint('🚗 [ActiveTripNav] Viaje registrado: ${tripData.solicitudId}');
  }

  /// Actualiza el estado del viaje activo sin perder contexto de navegación
  void updateActiveTripStatus(String? status) {
    if (_activeTripData == null || status == null || status.isEmpty) return;

    final currentStatus = _activeTripData!.initialTripStatus;
    if (currentStatus == status) return;

    _activeTripData = _activeTripData!.copyWith(initialTripStatus: status);
    _notifyChange();
    debugPrint('🔄 [ActiveTripNav] Estado actualizado: $status');
  }

  /// Actualiza el estado cuando el usuario entra/sale de la pantalla de viaje
  void setOnTripScreen(bool isOnScreen) {
    if (_isOnTripScreen != isOnScreen) {
      _isOnTripScreen = isOnScreen;
      _notifyChange();
      debugPrint('📍 [ActiveTripNav] En pantalla de viaje: $isOnScreen');
    }
  }

  /// Limpia el viaje activo (al finalizar o cancelar)
  void clearActiveTrip() {
    _activeTripData = null;
    _isOnTripScreen = false;
    // Ocultar overlay del sistema
    hideSystemOverlay();
    _notifyChange();
    debugPrint('🗑️ [ActiveTripNav] Viaje activo eliminado');
  }

  /// Muestra el overlay del sistema (cuando el usuario minimiza la app)
  Future<void> showSystemOverlay() async {
    if (!Platform.isAndroid) return;
    if (_activeTripData == null) return;
    if (!_systemOverlayEnabled) return;

    final data = _activeTripData!;
    await _systemOverlay.showOverlay(
      userRole: data.userRole,
      solicitudId: data.solicitudId,
    );
  }

  /// Oculta el overlay del sistema (cuando la app vuelve a primer plano)
  Future<void> hideSystemOverlay() async {
    if (!Platform.isAndroid) return;
    await _systemOverlay.hideOverlay();
  }

  /// Solicita permiso para el overlay del sistema
  Future<bool> requestSystemOverlayPermission(BuildContext context) async {
    if (!Platform.isAndroid) return false;
    return await _systemOverlay.showPermissionDialog(context);
  }

  /// Verifica si tiene permiso para overlay del sistema
  Future<bool> hasSystemOverlayPermission() async {
    if (!Platform.isAndroid) return false;
    return await _systemOverlay.hasOverlayPermission();
  }

  /// Habilita/deshabilita el overlay del sistema
  void setSystemOverlayEnabled(bool enabled) {
    _systemOverlayEnabled = enabled;
    if (!enabled) {
      hideSystemOverlay();
    }
    notifyListeners();
  }

  /// Navega de vuelta a la pantalla del viaje activo
  void navigateToActiveTrip(BuildContext context) {
    if (_activeTripData == null) return;

    final data = _activeTripData!;
    
    if (data.isClient) {
      _navigateToClientTrip(data);
    } else {
      _navigateToDriverTrip(data);
    }
  }

  void _navigateToClientTrip(ActiveTripData data) {
    final shouldOpenMeetingPoint = _clientMeetingPointStates.contains(data.initialTripStatus);

    if (shouldOpenMeetingPoint) {
      navigatorKey.currentState?.pushNamed(
        RouteNames.userTripAccepted,
        arguments: {
          'solicitudId': data.solicitudId,
          'clienteId': data.userId,
          'latitudOrigen': data.origenLat,
          'longitudOrigen': data.origenLng,
          'direccionOrigen': data.direccionOrigen,
          'latitudDestino': data.destinoLat,
          'longitudDestino': data.destinoLng,
          'direccionDestino': data.direccionDestino,
          'conductorInfo': data.conductorInfo,
        },
      );
      return;
    }

    // Usar key global para asegurar que navegamos en el navigator principal
    navigatorKey.currentState?.pushNamed(
      RouteNames.userActiveTrip,
      arguments: {
        'solicitudId': data.solicitudId,
        'clienteId': data.userId,
        'origenLat': data.origenLat,
        'origenLng': data.origenLng,
        'direccionOrigen': data.direccionOrigen,
        'destinoLat': data.destinoLat,
        'destinoLng': data.destinoLng,
        'direccionDestino': data.direccionDestino,
        'conductorInfo': data.conductorInfo,
      },
    );
  }

  void _navigateToDriverTrip(ActiveTripData data) {
    // Usar key global para asegurar que navegamos en el navigator principal
    navigatorKey.currentState?.pushNamed(
      RouteNames.conductorActiveTrip,
      arguments: {
        'conductorId': data.userId,
        'solicitudId': data.solicitudId,
        'origenLat': data.origenLat,
        'origenLng': data.origenLng,
        'destinoLat': data.destinoLat,
        'destinoLng': data.destinoLng,
        'direccionOrigen': data.direccionOrigen,
        'direccionDestino': data.direccionDestino,
        'clienteNombre': data.clienteNombre,
        'clienteFoto': data.clienteFoto,
        'clienteId': data.clienteInfo?['id'],
        'initialTripStatus': data.initialTripStatus,
      },
    );
  }

  void _notifyChange() {
    _stateController.add(shouldShowFloatingFab);
    notifyListeners();
  }

  @override
  void dispose() {
    _stateController.close();
    super.dispose();
  }
}
