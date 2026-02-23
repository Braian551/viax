import '../../routes/route_names.dart';

class TripNavigationDecision {
  final String routeName;
  final Map<String, dynamic> arguments;

  const TripNavigationDecision({
    required this.routeName,
    required this.arguments,
  });
}

class TripStatusNavigationService {
  static const Set<String> _meetingPointStates = {
    'aceptada',
    'conductor_asignado',
    'en_camino',
    'conductor_llego',
    'recogido',
  };

  static const Set<String> _inProgressStates = {
    'en_curso',
  };

  static const Set<String> _searchingStates = {
    'pendiente',
    'buscando',
    'buscando_conductor',
  };

  static const Set<String> _completedStates = {
    'completada',
    'completado',
    'finalizada',
    'finalizado',
    'entregado',
  };

  static const Set<String> _cancelledStates = {
    'cancelada',
    'cancelado',
    'cancelada_por_usuario',
  };

  static String normalizeStatus(dynamic rawStatus) {
    return (rawStatus?.toString() ?? '').trim().toLowerCase();
  }

  static bool isCompletedStatus(dynamic status) {
    return _completedStates.contains(normalizeStatus(status));
  }

  static bool isCancelledStatus(dynamic status) {
    return _cancelledStates.contains(normalizeStatus(status));
  }

  static bool shouldShowPendingSummary({
    required Map<String, dynamic> trip,
    required bool isConductor,
  }) {
    final status = normalizeStatus(trip['estado']);
    if (!isCompletedStatus(status)) return false;

    final flags = <dynamic>[
      trip['calificacion_dada'],
      trip['rating_dado'],
      trip['resumen_visto'],
      trip['summary_seen'],
      isConductor ? trip['calificacion_conductor'] : trip['calificacion_cliente'],
      isConductor ? trip['conductor_califico'] : trip['cliente_califico'],
    ];

    for (final value in flags) {
      if (value == null) continue;
      if (value == true || value == 1 || value == '1') return false;
      if (value is num && value > 0) return false;
      if (value is String && value.trim().isNotEmpty && value.trim() != '0') {
        return false;
      }
    }

    return true;
  }

  static TripNavigationDecision? resolveUserNavigation({
    required Map<String, dynamic> trip,
    required int fallbackClienteId,
  }) {
    final status = normalizeStatus(trip['estado']);
    if (status.isEmpty || isCancelledStatus(status)) return null;

    final solicitudId = _asInt(trip['id']);
    final clienteId = _asInt(trip['cliente_id']) == 0
        ? fallbackClienteId
        : _asInt(trip['cliente_id']);

    final origenLat = _asDouble(trip['origen']?['latitud'] ?? trip['latitud_recogida'] ?? trip['latitud_origen']);
    final origenLng = _asDouble(trip['origen']?['longitud'] ?? trip['longitud_recogida'] ?? trip['longitud_origen']);
    final destinoLat = _asDouble(trip['destino']?['latitud'] ?? trip['latitud_destino']);
    final destinoLng = _asDouble(trip['destino']?['longitud'] ?? trip['longitud_destino']);
    final direccionOrigen = (trip['origen']?['direccion'] ?? trip['direccion_recogida'] ?? trip['direccion_origen'] ?? '').toString();
    final direccionDestino = (trip['destino']?['direccion'] ?? trip['direccion_destino'] ?? '').toString();
    final conductor = trip['conductor'] is Map<String, dynamic>
        ? trip['conductor'] as Map<String, dynamic>
        : (trip['conductor'] is Map ? Map<String, dynamic>.from(trip['conductor'] as Map) : null);

    if (_searchingStates.contains(status)) {
      return TripNavigationDecision(
        routeName: RouteNames.userSearchingDriver,
        arguments: {
          'solicitudId': solicitudId,
          'clienteId': clienteId,
          'latitudOrigen': origenLat,
          'longitudOrigen': origenLng,
          'direccionOrigen': direccionOrigen,
          'latitudDestino': destinoLat,
          'longitudDestino': destinoLng,
          'direccionDestino': direccionDestino,
          'tipoVehiculo': (trip['tipo_vehiculo'] ?? 'mototaxi').toString(),
          'initialEmpresaId': _asNullableInt(trip['empresa_id']),
        },
      );
    }

    if (_meetingPointStates.contains(status)) {
      return TripNavigationDecision(
        routeName: RouteNames.userTripAccepted,
        arguments: {
          'solicitudId': solicitudId,
          'clienteId': clienteId,
          'latitudOrigen': origenLat,
          'longitudOrigen': origenLng,
          'direccionOrigen': direccionOrigen,
          'latitudDestino': destinoLat,
          'longitudDestino': destinoLng,
          'direccionDestino': direccionDestino,
          'conductorInfo': conductor,
        },
      );
    }

    if (_inProgressStates.contains(status)) {
      return TripNavigationDecision(
        routeName: RouteNames.userActiveTrip,
        arguments: {
          'solicitudId': solicitudId,
          'clienteId': clienteId,
          'origenLat': origenLat,
          'origenLng': origenLng,
          'direccionOrigen': direccionOrigen,
          'destinoLat': destinoLat,
          'destinoLng': destinoLng,
          'direccionDestino': direccionDestino,
          'conductorInfo': conductor,
        },
      );
    }

    return null;
  }

  static TripNavigationDecision? resolveConductorNavigation({
    required Map<String, dynamic> trip,
    required int fallbackConductorId,
  }) {
    final status = normalizeStatus(trip['estado']);
    if (status.isEmpty || isCancelledStatus(status) || isCompletedStatus(status)) {
      return null;
    }

    final solicitudId = _asInt(trip['id']);
    final conductorId = _asInt(trip['conductor_id']) == 0
        ? fallbackConductorId
        : _asInt(trip['conductor_id']);
    final clienteId = _asNullableInt(trip['cliente_id']);

    final origenLat = _asDouble(trip['origen']?['latitud'] ?? trip['latitud_recogida'] ?? trip['latitud_origen']);
    final origenLng = _asDouble(trip['origen']?['longitud'] ?? trip['longitud_recogida'] ?? trip['longitud_origen']);
    final destinoLat = _asDouble(trip['destino']?['latitud'] ?? trip['latitud_destino']);
    final destinoLng = _asDouble(trip['destino']?['longitud'] ?? trip['longitud_destino']);
    final direccionOrigen = (trip['origen']?['direccion'] ?? trip['direccion_recogida'] ?? trip['direccion_origen'] ?? '').toString();
    final direccionDestino = (trip['destino']?['direccion'] ?? trip['direccion_destino'] ?? '').toString();

    return TripNavigationDecision(
      routeName: RouteNames.conductorActiveTrip,
      arguments: {
        'conductorId': conductorId,
        'solicitudId': solicitudId,
        'clienteId': clienteId,
        'origenLat': origenLat,
        'origenLng': origenLng,
        'destinoLat': destinoLat,
        'destinoLng': destinoLng,
        'direccionOrigen': direccionOrigen,
        'direccionDestino': direccionDestino,
        'clienteNombre': trip['cliente_nombre'],
        'clienteFoto': trip['cliente_foto'],
        'clienteCalificacion': _asNullableDouble(
          trip['cliente_calificacion'] ??
              trip['calificacion_cliente'] ??
              trip['rating_cliente'] ??
              trip['cliente_rating'],
        ),
        'initialTripStatus': trip['estado'],
      },
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _asNullableInt(dynamic value) {
    final parsed = _asInt(value);
    return parsed == 0 ? null : parsed;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    final parsed = double.tryParse(value.toString());
    return parsed;
  }
}