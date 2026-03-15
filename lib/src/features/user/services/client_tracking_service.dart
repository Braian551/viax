import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/network_request_executor.dart';
import '../../../core/network/app_network_exception.dart';

/// Datos de tracking del viaje para el cliente
class ClientTrackingData {
  final double distanciaKm;
  final int tiempoSegundos;
  final double precioActual;
  final double velocidadConductor;
  final double headingConductor;
  final double? latitudConductor;
  final double? longitudConductor;
  final bool viajeEnCurso;
  final String? fase;
  final String? estadoViaje;
  final bool metricsLocked;
  final bool esTerminal;
  final DateTime? ultimaActualizacion;

  // Comparación con estimados
  final double? diferenciaDistancia;
  final int? diferenciaTiempo;
  final double? diferenciaPrecio;
  final String? mensajeComparacion;
  final int? backendElapsedSeconds;
  final double? backendPriceActual;

  ClientTrackingData({
    required this.distanciaKm,
    required this.tiempoSegundos,
    required this.precioActual,
    this.velocidadConductor = 0,
    this.headingConductor = 0,
    this.latitudConductor,
    this.longitudConductor,
    this.viajeEnCurso = true,
    this.fase,
    this.estadoViaje,
    this.metricsLocked = false,
    this.esTerminal = false,
    this.ultimaActualizacion,
    this.diferenciaDistancia,
    this.diferenciaTiempo,
    this.diferenciaPrecio,
    this.mensajeComparacion,
    this.backendElapsedSeconds,
    this.backendPriceActual,
  });

  ClientTrackingData copyWith({
    double? distanciaKm,
    int? tiempoSegundos,
    double? precioActual,
    double? velocidadConductor,
    double? headingConductor,
    double? latitudConductor,
    double? longitudConductor,
    bool? viajeEnCurso,
    String? fase,
    String? estadoViaje,
    bool? metricsLocked,
    bool? esTerminal,
    DateTime? ultimaActualizacion,
    double? diferenciaDistancia,
    int? diferenciaTiempo,
    double? diferenciaPrecio,
    String? mensajeComparacion,
    int? backendElapsedSeconds,
    double? backendPriceActual,
  }) {
    return ClientTrackingData(
      distanciaKm: distanciaKm ?? this.distanciaKm,
      tiempoSegundos: tiempoSegundos ?? this.tiempoSegundos,
      precioActual: precioActual ?? this.precioActual,
      velocidadConductor: velocidadConductor ?? this.velocidadConductor,
      headingConductor: headingConductor ?? this.headingConductor,
      latitudConductor: latitudConductor ?? this.latitudConductor,
      longitudConductor: longitudConductor ?? this.longitudConductor,
      viajeEnCurso: viajeEnCurso ?? this.viajeEnCurso,
      fase: fase ?? this.fase,
      estadoViaje: estadoViaje ?? this.estadoViaje,
      metricsLocked: metricsLocked ?? this.metricsLocked,
      esTerminal: esTerminal ?? this.esTerminal,
      ultimaActualizacion: ultimaActualizacion ?? this.ultimaActualizacion,
      diferenciaDistancia: diferenciaDistancia ?? this.diferenciaDistancia,
      diferenciaTiempo: diferenciaTiempo ?? this.diferenciaTiempo,
      diferenciaPrecio: diferenciaPrecio ?? this.diferenciaPrecio,
      mensajeComparacion: mensajeComparacion ?? this.mensajeComparacion,
      backendElapsedSeconds: backendElapsedSeconds ?? this.backendElapsedSeconds,
      backendPriceActual: backendPriceActual ?? this.backendPriceActual,
    );
  }

  int get tiempoMinutos => tiempoSegundos ~/ 60;

  String get tiempoFormateado {
    if (tiempoSegundos < 60) return '$tiempoSegundos seg';
    if (tiempoSegundos < 3600) {
      final mins = tiempoSegundos ~/ 60;
      final seg = tiempoSegundos % 60;
      return seg == 0 ? '$mins min' : '$mins:${seg.toString().padLeft(2, '0')}';
    }

    final hours = tiempoSegundos ~/ 3600;
    final remainingMins = (tiempoSegundos % 3600) ~/ 60;
    return '${hours}h ${remainingMins}m';
  }

  String get distanciaFormateada => '${distanciaKm.toStringAsFixed(1)} km';

  String get precioFormateado {
    final precioInt = precioActual.toInt();
    return '\$${precioInt.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  bool get precioCambioSignificativo =>
      diferenciaPrecio != null && diferenciaPrecio!.abs() > 1000;

  factory ClientTrackingData.fromServerResponse(Map<String, dynamic> json) {
    final tracking = json['tracking_actual'];
    final comparacion = json['comparacion'];
    final viaje = json['viaje'] as Map<String, dynamic>?;
    double asDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int asInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    final fallbackPrice = asDouble(viaje?['precio_en_tracking']) > 0
        ? asDouble(viaje?['precio_en_tracking'])
        : asDouble(viaje?['precio_estimado']);
    final fallbackElapsed = asInt(viaje?['duracion_segundos']) > 0
        ? asInt(viaje?['duracion_segundos'])
        : asInt(viaje?['tiempo_transcurrido_seg']);

    final estado = (json['status'] ?? viaje?['estado'])
        ?.toString()
        .toLowerCase();
    final metricsLocked =
        json['metrics_locked'] == true ||
        json['meta']?['metrics_locked'] == true;
    final esTerminal =
        estado == 'completada' ||
        estado == 'completado' ||
        estado == 'entregado' ||
        estado == 'finalizado' ||
        estado == 'finalizada' ||
        estado == 'cancelada' ||
        estado == 'cancelado' ||
        estado == 'rechazado' ||
        estado == 'rechazada' ||
        estado == 'rejected';

    if (tracking == null) {
      // Sin tracking aún: usar tarifa base/estimada para no iniciar en 0.
      return ClientTrackingData(
        distanciaKm: 0.0,
        tiempoSegundos: fallbackElapsed,
        precioActual: fallbackPrice,
        viajeEnCurso: false,
        estadoViaje: estado,
        metricsLocked: metricsLocked,
        esTerminal: esTerminal,
        backendElapsedSeconds: fallbackElapsed,
        backendPriceActual: fallbackPrice,
      );
    }

    final trackingElapsed = asInt(tracking['tiempo_segundos']);
    final trackingPrice = asDouble(tracking['precio_actual']);
    final mergedElapsed = trackingElapsed > 0 ? trackingElapsed : fallbackElapsed;
    final mergedPrice = trackingPrice > 0 ? trackingPrice : fallbackPrice;

    return ClientTrackingData(
      distanciaKm: (tracking['distancia_km'] ?? 0).toDouble(),
      tiempoSegundos: mergedElapsed,
      precioActual: mergedPrice,
      velocidadConductor: (tracking['velocidad_kmh'] ?? 0).toDouble(),
      headingConductor: (tracking['heading_deg'] ?? 0).toDouble(),
      latitudConductor: tracking['ubicacion']?['latitud']?.toDouble(),
      longitudConductor: tracking['ubicacion']?['longitud']?.toDouble(),
      viajeEnCurso: !esTerminal,
      fase: tracking['fase'],
      estadoViaje: estado,
      metricsLocked: metricsLocked,
      esTerminal: esTerminal,
      ultimaActualizacion: tracking['ultima_actualizacion'] != null
          ? DateTime.tryParse(tracking['ultima_actualizacion'])
          : null,
      diferenciaDistancia: comparacion?['diferencia_distancia_km']?.toDouble(),
      diferenciaTiempo: comparacion?['diferencia_tiempo_min'],
      diferenciaPrecio: comparacion?['diferencia_precio']?.toDouble(),
      mensajeComparacion: comparacion?['mensaje'],
      backendElapsedSeconds: trackingElapsed,
      backendPriceActual: trackingPrice,
    );
  }

  factory ClientTrackingData.fromSsePayload(Map<String, dynamic> json) {
    final tracking = json['tracking_actual'] as Map<String, dynamic>?;
    if (tracking == null) {
      return ClientTrackingData(
        distanciaKm: 0.0,
        tiempoSegundos: 0,
        precioActual: 0.0,
        viajeEnCurso: true,
      );
    }

    return ClientTrackingData(
      distanciaKm: (tracking['distancia_km'] ?? 0).toDouble(),
      tiempoSegundos: tracking['tiempo_segundos'] is num
          ? (tracking['tiempo_segundos'] as num).toInt()
          : int.tryParse('${tracking['tiempo_segundos'] ?? 0}') ?? 0,
      precioActual: (tracking['precio_actual'] ?? 0).toDouble(),
      velocidadConductor: (tracking['velocidad_kmh'] ?? 0).toDouble(),
      headingConductor: (tracking['heading_deg'] ?? 0).toDouble(),
      latitudConductor: tracking['ubicacion']?['latitud']?.toDouble(),
      longitudConductor: tracking['ubicacion']?['longitud']?.toDouble(),
      viajeEnCurso: true,
      fase: tracking['fase']?.toString(),
      ultimaActualizacion: tracking['ultima_actualizacion'] != null
          ? DateTime.tryParse(tracking['ultima_actualizacion'].toString())
          : null,
      backendElapsedSeconds: tracking['tiempo_segundos'] is num
          ? (tracking['tiempo_segundos'] as num).toInt()
          : int.tryParse('${tracking['tiempo_segundos'] ?? 0}') ?? 0,
      backendPriceActual: (tracking['precio_actual'] ?? 0).toDouble(),
    );
  }
}

/// Servicio para que el cliente observe el tracking del viaje
///
/// El cliente NO genera tracking, solo lo consume para ver:
/// - Ubicación del conductor en tiempo real
/// - Distancia recorrida
/// - Tiempo transcurrido
/// - Precio actual (que coincide con el del conductor)
class ClientTripTrackingService {
  // Singleton
  static final ClientTripTrackingService _instance =
      ClientTripTrackingService._internal();
  factory ClientTripTrackingService() => _instance;
  ClientTripTrackingService._internal();

  // Configuración
  static const Duration _fallbackPollInterval = Duration(seconds: 5);
  static const Duration _sseReconnectDelay = Duration(seconds: 3);
  static const Duration _longPollWait = Duration(seconds: 4);
  static const Duration _interpolationTick = Duration(seconds: 1);
  static const int _maxElapsedDriftSec = 240;
  static const Duration _maxBackendSilence = Duration(seconds: 12);
  static const Duration _staleRefreshInterval = Duration(seconds: 4);
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();

  // Estado
  bool _isWatching = false;
  int? _solicitudId;
  HttpClient? _sseClient;
  bool _isFetching = false;
  String? _lastSinceTs;
  Timer? _interpolationTimer;
  Timer? _priceSmoothingTimer;
  int _lastBackendElapsedSeconds = 0;
  DateTime? _lastSyncTimestamp;
  double _backendPrice = 0.0;
  double _displayPrice = 0.0;
  int _sseBackoffSeconds = _sseReconnectDelay.inSeconds;
  DateTime? _lastSyncLogAt;
  DateTime? _lastForcedRefreshAt;

  // Último tracking conocido
  ClientTrackingData? _lastData;

  // Callbacks
  void Function(ClientTrackingData)? onTrackingUpdate;
  void Function(String)? onError;

  /// Getters
  bool get isWatching => _isWatching;
  ClientTrackingData? get lastData => _lastData;

  /// Inicia la observación del tracking de un viaje
  Future<bool> startWatching({required int solicitudId}) async {
    if (_isWatching) {
      debugPrint('⚠️ [ClientTracking] Ya hay observación activa');
      return false;
    }

    try {
      _solicitudId = solicitudId;
      _isWatching = true;

      debugPrint(
        '👀 [ClientTracking] Iniciando observación del viaje $solicitudId',
      );

      // Obtener datos iniciales por HTTP para pintar pantalla de inmediato.
      await _fetchTracking();
      _startInterpolationTimer();

      // Modo push preferido: SSE. Si falla, degradar a polling resiliente.
      unawaited(_runSsePreferredLoop());

      return true;
    } catch (e) {
      debugPrint('❌ [ClientTracking] Error iniciando: $e');
      onError?.call('Error al iniciar seguimiento: $e');
      return false;
    }
  }

  /// Detiene la observación
  void stopWatching() {
    if (!_isWatching) return;

    debugPrint('🛑 [ClientTracking] Deteniendo observación');

    _isWatching = false;
    _solicitudId = null;
    _lastData = null;
    _lastSinceTs = null;
    _isFetching = false;
    _interpolationTimer?.cancel();
    _interpolationTimer = null;
    _priceSmoothingTimer?.cancel();
    _priceSmoothingTimer = null;
    _lastBackendElapsedSeconds = 0;
    _lastSyncTimestamp = null;
    _backendPrice = 0.0;
    _displayPrice = 0.0;
    _sseBackoffSeconds = _sseReconnectDelay.inSeconds;
    _lastSyncLogAt = null;
    _lastForcedRefreshAt = null;
    try {
      _sseClient?.close(force: true);
    } catch (_) {}
    _sseClient = null;
  }

  /// Obtiene los datos de tracking una vez (sin polling)
  Future<ClientTrackingData?> getTrackingOnce(int solicitudId) async {
    return _requestTracking(solicitudId, withLongPoll: false);
  }

  Future<ClientTrackingData?> _requestTracking(
    int solicitudId, {
    required bool withLongPoll,
  }) async {
    try {
      final query = <String, String>{
        'solicitud_id': '$solicitudId',
      };
      if (withLongPoll) {
        query['wait_seconds'] = '${_longPollWait.inSeconds}';
        if (_lastSinceTs != null && _lastSinceTs!.isNotEmpty) {
          query['since_ts'] = _lastSinceTs!;
        }
      }

      final url = Uri.parse(
        '${AppConfig.baseUrl}/conductor/tracking/get_tracking.php',
      ).replace(queryParameters: query);

      final result = await _network.getJson(
        url: url,
        headers: {'Content-Type': 'application/json'},
        timeout: withLongPoll
            ? const Duration(seconds: 25)
            : AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        if (result.error != null) {
          onError?.call(result.error!.userMessage);
        }
        return null;
      }

      final data = result.json!;
      if (data['success'] == true) {
        final latestTs = data['meta']?['latest_tracking_ts']?.toString();
        if (latestTs != null && latestTs.isNotEmpty) {
          _lastSinceTs = latestTs;
        }
        return ClientTrackingData.fromServerResponse(data);
      }

      return null;
    } catch (e) {
      debugPrint('❌ [ClientTracking] Error obteniendo tracking: $e');
      final mapped = AppNetworkException.fromError(e);
      onError?.call(mapped.userMessage);
      return null;
    }
  }

  Future<void> _runSsePreferredLoop() async {
    var sseHealthy = false;

    while (_isWatching && _solicitudId != null) {
      try {
        await _connectSseAndConsume(_solicitudId!);
        sseHealthy = true;
        _sseBackoffSeconds = _sseReconnectDelay.inSeconds;
      } catch (e) {
        debugPrint(
          '[SSE_DISCONNECTED] ts=${DateTime.now().toIso8601String()} tripId=$_solicitudId latency_ms=0 result=$e',
        );
        debugPrint('⚠️ [ClientTracking] SSE no disponible, fallback polling: $e');
        if (!sseHealthy) {
          onError?.call('Conexión en vivo inestable. Activando modo respaldo.');
        }

        // Fallback resiliente a polling con menor frecuencia para bajar carga.
        await _runFallbackPollingWindow();
      }

      if (!_isWatching) break;
      final wait = Duration(seconds: _sseBackoffSeconds);
      await Future.delayed(wait);
      _sseBackoffSeconds = _sseReconnectDelay.inSeconds;
      debugPrint(
        '[SSE_RECONNECTED] ts=${DateTime.now().toIso8601String()} tripId=$_solicitudId latency_ms=${wait.inMilliseconds} result=retry',
      );
    }
  }

  Future<void> _runFallbackPollingWindow() async {
    final until = DateTime.now().add(const Duration(seconds: 30));
    while (_isWatching && _solicitudId != null && DateTime.now().isBefore(until)) {
      final before = _lastData;
      await _fetchTracking(withLongPoll: true);
      final noFreshData = identical(before, _lastData);
      if (noFreshData) {
        _emitCachedFallback();
      }
      if (!_isWatching) return;
      await Future.delayed(_fallbackPollInterval);
    }
  }

  void _emitCachedFallback() {
    final cached = _lastData;
    if (cached == null) return;

    onTrackingUpdate?.call(cached);
  }

  Future<void> _connectSseAndConsume(int solicitudId) async {
    final since = _lastData?.ultimaActualizacion?.toIso8601String() ?? '';
    final primaryUri = Uri.parse('${AppConfig.baseUrl}/sse/trip_updates.php').replace(
      queryParameters: {
        'trip_id': '$solicitudId',
        'wait_seconds': '35',
        if (since.isNotEmpty) 'since_signature': sha1Lite(since),
      },
    );

    final legacyUri = Uri.parse('${AppConfig.baseUrl}/user/stream_trip_updates.php').replace(
      queryParameters: {
        'trip_id': '$solicitudId',
        'wait_seconds': '35',
        if (since.isNotEmpty) 'since_signature': sha1Lite(since),
      },
    );

    _sseClient?.close(force: true);
    _sseClient = HttpClient()..connectionTimeout = const Duration(seconds: 12);

    var activeUri = primaryUri;
    var request = await _sseClient!.getUrl(activeUri);
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    var response = await request.close();

    // Compatibilidad: si el endpoint nuevo no existe, usar el endpoint legacy.
    if (response.statusCode == 404) {
      activeUri = legacyUri;
      request = await _sseClient!.getUrl(activeUri);
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      response = await request.close();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('SSE status ${response.statusCode}');
    }

    debugPrint(
      '[SSE_CONNECTED] ts=${DateTime.now().toIso8601String()} tripId=$solicitudId latency_ms=0 result=connected uri=$activeUri',
    );

    String? currentEvent;
    StringBuffer dataBuffer = StringBuffer();

    await for (final line in response
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (!_isWatching) return;

      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
        continue;
      }

      if (line.startsWith('data:')) {
        dataBuffer.writeln(line.substring(5).trim());
        continue;
      }

      if (line.trim().isEmpty) {
        final payloadRaw = dataBuffer.toString().trim();
        if (payloadRaw.isNotEmpty) {
          _handleSseEvent(currentEvent, payloadRaw);
        }
        currentEvent = null;
        dataBuffer = StringBuffer();
      }
    }
  }

  void _handleSseEvent(String? event, String payloadRaw) {
    try {
      final parsed = jsonDecode(payloadRaw);
      if (parsed is! Map<String, dynamic>) return;

      if (event == 'trip_update') {
        final data = ClientTrackingData.fromSsePayload(parsed);
        _ingestBackendData(data);
      }
    } catch (e) {
      debugPrint('⚠️ [ClientTracking] SSE payload inválido: $e');
    }
  }

  // Hash liviano para mantener compatibilidad con since_signature.
  String sha1Lite(String input) {
    var hash = 0;
    for (final code in input.codeUnits) {
      hash = ((hash << 5) - hash) + code;
      hash &= 0x7fffffff;
    }
    return hash.toRadixString(16);
  }

  // =========================================================================
  // MÉTODOS PRIVADOS
  // =========================================================================

  Future<void> _fetchTracking({bool withLongPoll = false}) async {
    if (_solicitudId == null) return;
    if (_isFetching) return;

    _isFetching = true;

    try {
      final data = await _requestTracking(
        _solicitudId!,
        withLongPoll: withLongPoll,
      );

      if (data != null) {
        _ingestBackendData(data);

        if (data.esTerminal) {
          debugPrint(
            '🛑 [TrackingStopped] Trip terminal detectado, solicitud=$_solicitudId',
          );
          stopWatching();
        }

      } else {
        debugPrint('⚠️ [ClientTracking] No hay datos de tracking disponibles');
      }
    } catch (e) {
      debugPrint('⚠️ [ClientTracking] Error en fetch: $e');
    } finally {
      _isFetching = false;
    }
  }

  void _startInterpolationTimer() {
    _interpolationTimer?.cancel();
    _interpolationTimer = Timer.periodic(_interpolationTick, (_) {
      if (!_isWatching || _lastData == null) return;
      _emitInterpolatedSnapshot();
    });
  }

  void _ingestBackendData(ClientTrackingData incoming) {
    final now = DateTime.now();

    if (incoming.tiempoSegundos > 0) {
      _lastBackendElapsedSeconds = incoming.tiempoSegundos;
      _lastSyncTimestamp = now;
    }

    if (incoming.precioActual > 0) {
      _backendPrice = incoming.precioActual;
      _syncDisplayPriceWithBackend(_backendPrice);
    }

    final localElapsed = _computeLocalElapsed(now);
    final emitted = incoming.copyWith(
      tiempoSegundos: localElapsed > incoming.tiempoSegundos
          ? localElapsed
          : incoming.tiempoSegundos,
      precioActual: _displayPrice > 0 ? _displayPrice : incoming.precioActual,
      backendElapsedSeconds: incoming.tiempoSegundos,
      backendPriceActual: incoming.precioActual,
    );

    _lastData = emitted;
    onTrackingUpdate?.call(emitted);
    _logTrackingSync(emitted);
  }

  int _computeLocalElapsed(DateTime now) {
    if (_lastBackendElapsedSeconds <= 0 || _lastSyncTimestamp == null) {
      return _lastData?.tiempoSegundos ?? 0;
    }

    final drift = now.difference(_lastSyncTimestamp!).inSeconds;
    final safeDrift = drift < 0 ? 0 : drift;
    final projected = _lastBackendElapsedSeconds + safeDrift;
    final maxAllowed = _lastBackendElapsedSeconds + _maxElapsedDriftSec;
    return projected > maxAllowed ? maxAllowed : projected;
  }

  void _syncDisplayPriceWithBackend(double newBackendPrice) {
    if (_displayPrice <= 0) {
      _displayPrice = newBackendPrice;
      return;
    }

    final base = _displayPrice.abs() < 1 ? 1.0 : _displayPrice.abs();
    final diffRatio = ((newBackendPrice - _displayPrice).abs()) / base;

    if (diffRatio > 0.20) {
      _priceSmoothingTimer?.cancel();
      _displayPrice = newBackendPrice;
      return;
    }

    _priceSmoothingTimer?.cancel();
    const totalSteps = 5;
    final start = _displayPrice;
    final delta = (newBackendPrice - start) / totalSteps;
    var step = 0;

    _priceSmoothingTimer = Timer.periodic(const Duration(milliseconds: 200), (
      timer,
    ) {
      step += 1;
      if (step >= totalSteps) {
        _displayPrice = newBackendPrice;
        timer.cancel();
        return;
      }
      _displayPrice = start + (delta * step);
      _emitInterpolatedSnapshot();
    });
  }

  void _emitInterpolatedSnapshot() {
    final base = _lastData;
    if (base == null) return;

    final now = DateTime.now();
    final localElapsed = _computeLocalElapsed(now);

    final emitted = base.copyWith(
      tiempoSegundos: localElapsed > base.tiempoSegundos
          ? localElapsed
          : base.tiempoSegundos,
      precioActual: _displayPrice > 0 ? _displayPrice : base.precioActual,
      backendElapsedSeconds: _lastBackendElapsedSeconds,
      backendPriceActual: _backendPrice,
    );

    final unchangedElapsed = emitted.tiempoSegundos == base.tiempoSegundos;
    final unchangedPrice =
        (emitted.precioActual - base.precioActual).abs() < 0.01;
    if (unchangedElapsed && unchangedPrice) {
      return;
    }

    _lastData = emitted;
    onTrackingUpdate?.call(emitted);
    _logTrackingSync(emitted);
    _maybeForceRefreshOnStale(now);
  }

  void _maybeForceRefreshOnStale(DateTime now) {
    if (!_isWatching || _solicitudId == null || _isFetching) {
      return;
    }
    if (_lastSyncTimestamp == null) {
      return;
    }

    final silence = now.difference(_lastSyncTimestamp!);
    if (silence < _maxBackendSilence) {
      return;
    }

    if (_lastForcedRefreshAt != null &&
        now.difference(_lastForcedRefreshAt!) < _staleRefreshInterval) {
      return;
    }

    _lastForcedRefreshAt = now;
    debugPrint(
      '[ClientTracking] stale_detected tripId=${_solicitudId ?? 0} '
      'silence_s=${silence.inSeconds} forcing_refresh=true',
    );
    unawaited(_fetchTracking(withLongPoll: false));
  }

  void _logTrackingSync(ClientTrackingData data) {
    if (!kDebugMode) return;
    final now = DateTime.now();
    if (_lastSyncLogAt != null &&
        now.difference(_lastSyncLogAt!).inMilliseconds < 900) {
      return;
    }
    _lastSyncLogAt = now;

    debugPrint(
      '[TripSync] ts=${now.toIso8601String()} tripId=${_solicitudId ?? 0} latency_ms=0 '
      'result=tracking_update backendElapsed=${data.backendElapsedSeconds ?? _lastBackendElapsedSeconds} '
      'localElapsed=${data.tiempoSegundos}',
    );
    debugPrint(
      '[PriceSync] ts=${now.toIso8601String()} tripId=${_solicitudId ?? 0} latency_ms=0 '
      'result=price_update backendPrice=${(data.backendPriceActual ?? _backendPrice).toStringAsFixed(2)} '
      'localElapsed=${data.tiempoSegundos} '
      'displayPrice=${data.precioActual.toStringAsFixed(2)}',
    );
  }
}
