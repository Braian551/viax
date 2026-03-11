import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';

/// Modelo para un punto de tracking
class TrackingPoint {
  final double latitud;
  final double longitud;
  final double velocidad;
  final double bearing;
  final double distanciaAcumuladaKm;
  final int tiempoTranscurridoSeg;
  final double? precisionGps;
  final double? altitud;
  final String faseViaje;
  final String? evento;
  final DateTime timestamp;

  TrackingPoint({
    required this.latitud,
    required this.longitud,
    required this.velocidad,
    required this.bearing,
    required this.distanciaAcumuladaKm,
    required this.tiempoTranscurridoSeg,
    this.precisionGps,
    this.altitud,
    this.faseViaje = 'hacia_destino',
    this.evento,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'latitud': latitud,
    'longitud': longitud,
    'velocidad': velocidad,
    'bearing': bearing,
    'distancia_acumulada_km': distanciaAcumuladaKm,
    'tiempo_transcurrido_seg': tiempoTranscurridoSeg,
    'precision_gps': precisionGps,
    'altitud': altitud,
    'fase_viaje': faseViaje,
    'evento': evento,
  };
}

/// Datos de tracking actuales (para UI)
class TrackingData {
  final double distanciaKm;
  final int tiempoSegundos;
  final double precioActual;
  final double velocidadKmh;
  final bool sincronizado;

  TrackingData({
    required this.distanciaKm,
    required this.tiempoSegundos,
    required this.precioActual,
    required this.velocidadKmh,
    this.sincronizado = true,
  });

  int get tiempoMinutos => (tiempoSegundos / 60).ceil();

  String get tiempoFormateado {
    final mins = tiempoMinutos;
    if (mins < 60) return '$mins min';
    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    return '${hours}h ${remainingMins}m';
  }

  String get distanciaFormateada => '${distanciaKm.toStringAsFixed(1)} km';

  String get precioFormateado => '\$${precioActual.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]}.',
  )}';
}

/// Resultado de finalizar tracking
class TrackingFinalResult {
  final bool success;
  final double precioFinal;
  final double distanciaRealKm;
  final int tiempoRealMin;
  final int tiempoRealSeg; // Tiempo en segundos para mayor precisión
  final double diferenciaPrecio;
  final Map<String, dynamic>? desglose;
  final String? mensaje;

  TrackingFinalResult({
    required this.success,
    required this.precioFinal,
    required this.distanciaRealKm,
    required this.tiempoRealMin,
    this.tiempoRealSeg = 0,
    required this.diferenciaPrecio,
    this.desglose,
    this.mensaje,
  });

  factory TrackingFinalResult.fromJson(Map<String, dynamic> json) {
    final tiempoMin = json['tracking']?['tiempo_real_min'] ?? 0;
    final tiempoSeg = json['tracking']?['tiempo_real_seg'] ?? (tiempoMin * 60);
    
    return TrackingFinalResult(
      success: json['success'] ?? false,
      precioFinal: (json['precio_final'] ?? 0).toDouble(),
      distanciaRealKm: (json['tracking']?['distancia_real_km'] ?? 0).toDouble(),
      tiempoRealMin: tiempoMin,
      tiempoRealSeg: tiempoSeg,
      diferenciaPrecio: (json['comparacion_precio']?['diferencia'] ?? 0).toDouble(),
      desglose: json['desglose'],
      mensaje: json['message'],
    );
  }
}

/// Servicio de Tracking GPS en Tiempo Real para viajes
/// 
/// Similar a como funcionan Uber/Didi:
/// - Registra puntos GPS cada 5 segundos durante el viaje
/// - Calcula distancia real recorrida
/// - Sincroniza con el backend para cálculo de tarifa
/// - Mantiene los valores sincronizados entre conductor y cliente
class TripTrackingService {
  // Singleton
  static final TripTrackingService _instance = TripTrackingService._internal();
  factory TripTrackingService() => _instance;
  TripTrackingService._internal();

  // Configuración
  static const Duration _trackingInterval = Duration(seconds: 5);
  static const Duration _batchSyncInterval = Duration(seconds: 10);
  static const double _minDistanceToRegisterMeters = 15.0; // Filtro de jitter
  static const double _maxAcceptedAccuracyMeters = 80.0;
  static const double _maxPlausibleSpeedKmh = 140.0;
  static const double _maxJumpMetersWithoutDelta = 120.0;
  static const int _maxBatchSize = 20;

  // Estado del tracking
  bool _isTracking = false;
  int? _solicitudId;
  int? _conductorId;
  DateTime? _startTime;
  String _faseViaje = 'hacia_destino';
  
  // Acumuladores
  double _distanciaAcumuladaKm = 0.0;
  Position? _ultimaPosicion;
  double _precioActual = 0.0;

  // Stream de posición
  StreamSubscription<Position>? _positionSubscription;
  Timer? _syncTimer;
  DateTime _lastBatchSync = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isSyncingBatch = false;
  bool _syncBlockedByPricingConfig = false;

  // Cola de puntos pendientes (para modo offline)
  final List<TrackingPoint> _pendingPoints = [];

  // Callbacks
  void Function(TrackingData)? onTrackingUpdate;
  void Function(String)? onError;

  /// Getters
  bool get isTracking => _isTracking;
  double get distanciaKm => _distanciaAcumuladaKm;
  int get tiempoSegundos => _startTime != null 
      ? DateTime.now().difference(_startTime!).inSeconds 
      : 0;
  double get precioActual => _precioActual;

  /// Inicia el tracking de un viaje
  /// [startTime] - Tiempo de inicio del viaje (para sincronizar con cronómetro del conductor)
  Future<bool> startTracking({
    required int solicitudId,
    required int conductorId,
    String faseViaje = 'hacia_destino',
    double distanciaInicial = 0.0,
    DateTime? startTime,
  }) async {
    if (_isTracking) {
      debugPrint('⚠️ [Tracking] Ya hay un tracking activo');
      return false;
    }

    try {
      _solicitudId = solicitudId;
      _conductorId = conductorId;
      _faseViaje = faseViaje;
      _distanciaAcumuladaKm = distanciaInicial; // Siempre comienza en 0
      _precioActual = 0.0; // Reset precio
      // Usar tiempo proporcionado o crear uno nuevo
      _startTime = startTime ?? DateTime.now();
      _ultimaPosicion = null;
      _pendingPoints.clear(); // Limpiar cola
      _lastBatchSync = DateTime.now();
      _isSyncingBatch = false;
      _syncBlockedByPricingConfig = false;
      _isTracking = true;

      debugPrint('🚀 [Tracking] Iniciando tracking para viaje $solicitudId');
      debugPrint('   - Distancia inicial: $_distanciaAcumuladaKm km');
      debugPrint('   - Hora inicio: $_startTime');

      // Obtener posición inicial
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _ultimaPosicion = position;
      
      debugPrint('📍 [Tracking] Posición inicial: ${position.latitude}, ${position.longitude}');

      // Registrar punto de inicio
      await _registrarPunto(position, evento: 'inicio', forceSync: true);

      // Iniciar stream de posición
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
        ),
      ).listen(_onPositionUpdate, onError: _onPositionError);

      // Timer de sincronización periódica - envía punto actual cada 5 segundos
      // Esto asegura que el tiempo se actualice aunque el conductor esté estático
      _syncTimer = Timer.periodic(_trackingInterval, (_) => _periodicSync());

      return true;
    } catch (e) {
      debugPrint('❌ [Tracking] Error iniciando: $e');
      onError?.call('Error al iniciar tracking: $e');
      return false;
    }
  }

  /// Sincronización periódica - envía posición actual aunque no haya movimiento
  Future<void> _periodicSync() async {
    if (!_isTracking || _solicitudId == null) return;
    
    // Registrar punto actual para mantener tiempo actualizado
    if (_ultimaPosicion != null) {
      await _registrarPunto(_ultimaPosicion!);
      _notifyUpdate(_ultimaPosicion!);
    }

    if (_syncBlockedByPricingConfig) {
      // Seguimos emitiendo estado local para UI, pero sin insistir en backend.
      return;
    }

    final shouldFlush = _pendingPoints.length >= _maxBatchSize ||
        DateTime.now().difference(_lastBatchSync) >= _batchSyncInterval;

    if (shouldFlush) {
      await _syncPendingPoints();
    }
  }

  /// Detiene el tracking
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    debugPrint('🛑 [Tracking] Deteniendo tracking');

    _isTracking = false;

    _positionSubscription?.cancel();
    _positionSubscription = null;
    _syncTimer?.cancel();
    _syncTimer = null;

    // Sincronizar puntos pendientes
    await _syncPendingPoints();

    _solicitudId = null;
    _conductorId = null;
  }

  /// Finaliza el tracking y calcula el precio final
  /// [tiempoRealSegundos] - Tiempo real medido por el conductor (desde inicio hasta fin)
  Future<TrackingFinalResult?> finalizeTracking({int? tiempoRealSegundos}) async {
    if (_solicitudId == null || _conductorId == null) {
      debugPrint('⚠️ [Tracking] No hay viaje activo para finalizar');
      return null;
    }

    try {
      debugPrint('📊 [Tracking] Finalizando tracking y calculando precio');

      // Registrar último punto
      if (_ultimaPosicion != null) {
        await _registrarPunto(_ultimaPosicion!, evento: 'fin', forceSync: true);
      }

      // Asegurar flush final antes del cálculo de tarifa
      await _syncPendingPoints();

      // Usar tiempo real del conductor si se proporciona, sino el del tracking
      final tiempoFinalSeg = tiempoRealSegundos ?? tiempoSegundos;
      
      debugPrint('📊 [Tracking] Tiempo final: ${tiempoFinalSeg}s (${(tiempoFinalSeg/60).toStringAsFixed(1)} min)');
      debugPrint('📊 [Tracking] Distancia final: ${_distanciaAcumuladaKm.toStringAsFixed(2)} km');

      // Llamar al endpoint de finalización
      final url = Uri.parse('${AppConfig.baseUrl}/conductor/tracking/finalize.php');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'solicitud_id': _solicitudId,
          'conductor_id': _conductorId,
          'distancia_final_km': _distanciaAcumuladaKm,
          'tiempo_final_seg': tiempoFinalSeg,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          debugPrint('✅ [Tracking] Precio final calculado: ${data['precio_final']}');
          return TrackingFinalResult.fromJson(data);
        }
      }

      debugPrint('⚠️ [Tracking] Error en finalización: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('❌ [Tracking] Error finalizando: $e');
      return null;
    } finally {
      await stopTracking();
    }
  }

  /// Cambia la fase del viaje (de recogida a destino)
  void setFase(String fase) {
    _faseViaje = fase;
    debugPrint('📍 [Tracking] Fase cambiada a: $fase');
  }

  /// Obtener datos de tracking del servidor
  Future<Map<String, dynamic>?> getTrackingFromServer(int solicitudId) async {
    try {
      final url = Uri.parse(
        '${AppConfig.baseUrl}/conductor/tracking/get_tracking.php?solicitud_id=$solicitudId'
      );

      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ [Tracking] Error obteniendo tracking: $e');
      return null;
    }
  }

  // =========================================================================
  // MÉTODOS PRIVADOS
  // =========================================================================

  void _onPositionUpdate(Position position) async {
    if (!_isTracking) return;

    // IMPORTANTE:
    // Si la precisión es mala, no acumulamos distancia para evitar saltos GPS.
    if (position.accuracy > _maxAcceptedAccuracyMeters) {
      debugPrint(
        '⚠️ [Tracking] Punto descartado por baja precisión: ${position.accuracy.toStringAsFixed(1)}m',
      );
      return;
    }

    // Filtrar jitter: solo procesar si se movió suficiente
    if (_ultimaPosicion != null) {
      final distancia = Geolocator.distanceBetween(
        _ultimaPosicion!.latitude,
        _ultimaPosicion!.longitude,
        position.latitude,
        position.longitude,
      );

      final deltaSegundos = position.timestamp
          .difference(_ultimaPosicion!.timestamp)
          .inSeconds;
      final velocidadCalculadaKmh = deltaSegundos > 0
          ? (distancia / deltaSegundos) * 3.6
          : 0.0;
      final velocidadReportadaKmh =
          (position.speed.isFinite && position.speed > 0)
          ? position.speed * 3.6
          : 0.0;
      final velocidadReferencia =
          velocidadCalculadaKmh > velocidadReportadaKmh
          ? velocidadCalculadaKmh
          : velocidadReportadaKmh;

      final saltoSinTiempoValido =
          deltaSegundos <= 0 && distancia > _maxJumpMetersWithoutDelta;
      final velocidadImprobable = velocidadReferencia > _maxPlausibleSpeedKmh;

      if (saltoSinTiempoValido || velocidadImprobable) {
        debugPrint(
          '⚠️ [Tracking] Salto GPS descartado: dist=${distancia.toStringAsFixed(1)}m, dt=${deltaSegundos}s, v=${velocidadReferencia.toStringAsFixed(1)}km/h',
        );
        return;
      }

      if (distancia < _minDistanceToRegisterMeters) {
        return; // Muy cerca del último punto, ignorar
      }

      // Acumular distancia
      _distanciaAcumuladaKm += (distancia / 1000.0);
    }

    _ultimaPosicion = position;

    // Registrar punto
    await _registrarPunto(position);

    // Notificar actualización
    _notifyUpdate(position);
  }

  void _onPositionError(dynamic error) {
    debugPrint('⚠️ [Tracking] Error de GPS: $error');
    onError?.call('Error de GPS: $error');
  }

  Future<void> _registrarPunto(Position position, {String? evento, bool forceSync = false}) async {
    if (_solicitudId == null || _conductorId == null) return;
    if (_syncBlockedByPricingConfig) return;

    final punto = TrackingPoint(
      latitud: position.latitude,
      longitud: position.longitude,
      velocidad: position.speed * 3.6, // m/s a km/h
      bearing: position.heading,
      distanciaAcumuladaKm: _distanciaAcumuladaKm,
      tiempoTranscurridoSeg: tiempoSegundos,
      precisionGps: position.accuracy,
      altitud: position.altitude,
      faseViaje: _faseViaje,
      evento: evento,
    );

    _pendingPoints.add(punto);

    if (forceSync || _pendingPoints.length >= _maxBatchSize) {
      await _syncPendingPoints();
    }
  }

  Future<bool> _enviarPunto(TrackingPoint punto) async {
    if (_solicitudId == null || _conductorId == null) return false;

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/conductor/tracking/register_point.php');
      
      final body = {
        'solicitud_id': _solicitudId,
        'conductor_id': _conductorId,
        ...punto.toJson(),
      };

      debugPrint('📤 [Tracking] Enviando punto: dist=${punto.distanciaAcumuladaKm.toStringAsFixed(2)}km, tiempo=${punto.tiempoTranscurridoSeg}s');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          // Actualizar precio desde servidor
          final nuevoPrecio = (data['data']?['precio_parcial'] ?? _precioActual).toDouble();
          _precioActual = nuevoPrecio;
          debugPrint('✅ [Tracking] Punto registrado. Precio actual: \$$nuevoPrecio');
          return true;
        } else {
          debugPrint('⚠️ [Tracking] Respuesta sin éxito: ${data['message']}');
        }
      } else {
        debugPrint('❌ [Tracking] HTTP ${response.statusCode}: ${response.body}');
      }

      return false;
    } catch (e) {
      debugPrint('⚠️ [Tracking] Error enviando punto: $e');
      return false;
    }
  }

  Future<void> _syncPendingPoints() async {
    if (_pendingPoints.isEmpty || _isSyncingBatch) return;
    if (_solicitudId == null || _conductorId == null) return;

    _isSyncingBatch = true;
    try {
      while (_pendingPoints.isNotEmpty) {
        final currentBatch = _pendingPoints
            .take(_maxBatchSize)
            .map((point) => point.toJson())
            .toList();

        debugPrint('🔄 [Tracking] Sincronizando lote de ${currentBatch.length} puntos (${_pendingPoints.length} pendientes)');

        final enviado = await _enviarLote(currentBatch);
        if (!enviado) {
          break;
        }

        _pendingPoints.removeRange(0, currentBatch.length);
        _lastBatchSync = DateTime.now();
      }
    } finally {
      _isSyncingBatch = false;
    }
  }

  Future<bool> _enviarLote(List<Map<String, dynamic>> puntos) async {
    if (_solicitudId == null || _conductorId == null || puntos.isEmpty) return false;

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/conductor/tracking/register_points_batch.php');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'solicitud_id': _solicitudId,
          'conductor_id': _conductorId,
          'puntos': puntos,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final nuevoPrecio = (data['data']?['precio_parcial'] ?? _precioActual).toDouble();
          _precioActual = nuevoPrecio;
          return true;
        }
      }

      final backendMessage = _extractBackendMessage(response.body);
      if (_isMissingPricingConfigError(response.statusCode, backendMessage)) {
        _handleMissingPricingConfig(backendMessage);
        return true;
      }

      debugPrint('⚠️ [Tracking] Error enviando lote: HTTP ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      debugPrint('⚠️ [Tracking] Error enviando lote: $e');
      return false;
    }
  }

  String? _extractBackendMessage(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {
      // body no JSON, se ignora
    }
    return null;
  }

  bool _isMissingPricingConfigError(int statusCode, String? message) {
    if (statusCode != 400 || message == null) return false;
    final normalized = message.toLowerCase();
    return normalized.contains('configuraci') &&
        normalized.contains('precio') &&
        normalized.contains('veh');
  }

  void _handleMissingPricingConfig(String? backendMessage) {
    if (_syncBlockedByPricingConfig) return;

    _syncBlockedByPricingConfig = true;
    _pendingPoints.clear();

    final message = backendMessage ??
        'No hay configuración de precios para este tipo de vehículo';

    debugPrint('⛔ [Tracking] Sincronización pausada por error no recuperable: $message');
    onError?.call(
      'No se pudo sincronizar el tracking: $message. '
      'El viaje sigue activo, pero debes configurar tarifas para este vehículo.',
    );
  }

  void _notifyUpdate(Position position) {
    final data = TrackingData(
      distanciaKm: _distanciaAcumuladaKm,
      tiempoSegundos: tiempoSegundos,
      precioActual: _precioActual,
      velocidadKmh: position.speed * 3.6,
      sincronizado: _pendingPoints.isEmpty,
    );

    onTrackingUpdate?.call(data);
  }
}
