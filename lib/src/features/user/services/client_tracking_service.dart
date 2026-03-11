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

  ClientTrackingData({
    required this.distanciaKm,
    required this.tiempoSegundos,
    required this.precioActual,
    this.velocidadConductor = 0,
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
  });

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
      // Sin tracking aún - retornar 0, NO usar estimados
      // El tracking real comenzará cuando el conductor inicie el viaje
      return ClientTrackingData(
        distanciaKm: 0.0,
        tiempoSegundos: 0,
        precioActual: 0.0,
        viajeEnCurso: false,
        estadoViaje: estado,
        metricsLocked: metricsLocked,
        esTerminal: esTerminal,
      );
    }

    return ClientTrackingData(
      distanciaKm: (tracking['distancia_km'] ?? 0).toDouble(),
      tiempoSegundos: tracking['tiempo_segundos'] ?? 0,
      precioActual: (tracking['precio_actual'] ?? 0).toDouble(),
      velocidadConductor: (tracking['velocidad_kmh'] ?? 0).toDouble(),
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
      latitudConductor: tracking['ubicacion']?['latitud']?.toDouble(),
      longitudConductor: tracking['ubicacion']?['longitud']?.toDouble(),
      viajeEnCurso: true,
      fase: tracking['fase']?.toString(),
      ultimaActualizacion: tracking['ultima_actualizacion'] != null
          ? DateTime.tryParse(tracking['ultima_actualizacion'].toString())
          : null,
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
  static const Duration _pollInterval = Duration(seconds: 5);
  static const Duration _fallbackPollInterval = Duration(seconds: 12);
  static const Duration _sseReconnectDelay = Duration(seconds: 2);
  static const Duration _longPollWait = Duration(seconds: 20);
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();

  // Estado
  bool _isWatching = false;
  int? _solicitudId;
  Future<void>? _watchLoop;
  HttpClient? _sseClient;
  bool _isFetching = false;
  String? _lastSinceTs;

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

      // Modo push preferido: SSE. Si falla, degradar a polling resiliente.
      _watchLoop = _runSsePreferredLoop();

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

  Future<void> _runWatchLoop() async {
    while (_isWatching && _solicitudId != null) {
      await _fetchTracking(withLongPoll: true);
      if (!_isWatching) break;
      await Future.delayed(_pollInterval);
    }
  }

  Future<void> _runSsePreferredLoop() async {
    var sseHealthy = false;

    while (_isWatching && _solicitudId != null) {
      try {
        await _connectSseAndConsume(_solicitudId!);
        sseHealthy = true;
      } catch (e) {
        debugPrint('⚠️ [ClientTracking] SSE no disponible, fallback polling: $e');
        if (!sseHealthy) {
          onError?.call('Conexión en vivo inestable. Activando modo respaldo.');
        }

        // Fallback resiliente a polling con menor frecuencia para bajar carga.
        await _runFallbackPollingWindow();
      }

      if (!_isWatching) break;
      await Future.delayed(_sseReconnectDelay);
    }
  }

  Future<void> _runFallbackPollingWindow() async {
    final until = DateTime.now().add(const Duration(seconds: 30));
    while (_isWatching && _solicitudId != null && DateTime.now().isBefore(until)) {
      await _fetchTracking(withLongPoll: true);
      if (!_isWatching) return;
      await Future.delayed(_fallbackPollInterval);
    }
  }

  Future<void> _connectSseAndConsume(int solicitudId) async {
    final since = _lastData?.ultimaActualizacion?.toIso8601String() ?? '';
    final uri = Uri.parse('${AppConfig.baseUrl}/user/stream_trip_updates.php').replace(
      queryParameters: {
        'trip_id': '$solicitudId',
        'wait_seconds': '35',
        if (since.isNotEmpty) 'since_signature': sha1Lite(since),
      },
    );

    _sseClient?.close(force: true);
    _sseClient = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    final request = await _sseClient!.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    final response = await request.close();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('SSE status ${response.statusCode}');
    }

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
        _lastData = data;
        onTrackingUpdate?.call(data);

        debugPrint(
          '📡 [ClientTracking][SSE] ${data.distanciaFormateada}, ${data.tiempoFormateado}, ${data.precioFormateado}',
        );
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
        _lastData = data;

        if (data.esTerminal) {
          debugPrint(
            '🛑 [TrackingStopped] Trip terminal detectado, solicitud=$_solicitudId',
          );
          stopWatching();
        }

        onTrackingUpdate?.call(data);

        // Log periódico para debug
        debugPrint(
          '📍 [ClientTracking] Actualización: ${data.distanciaFormateada}, ${data.tiempoFormateado}, ${data.precioFormateado}',
        );
      } else {
        debugPrint('⚠️ [ClientTracking] No hay datos de tracking disponibles');
      }
    } catch (e) {
      debugPrint('⚠️ [ClientTracking] Error en fetch: $e');
    } finally {
      _isFetching = false;
    }
  }
}
