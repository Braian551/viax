import 'dart:async';
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
    this.ultimaActualizacion,
    this.diferenciaDistancia,
    this.diferenciaTiempo,
    this.diferenciaPrecio,
    this.mensajeComparacion,
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

  String get precioFormateado {
    final precioInt = precioActual.toInt();
    return '\$${precioInt.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  bool get precioCambioSignificativo => 
      diferenciaPrecio != null && diferenciaPrecio!.abs() > 1000;

  factory ClientTrackingData.fromServerResponse(Map<String, dynamic> json) {
    final tracking = json['tracking_actual'];
    final comparacion = json['comparacion'];
    final estimados = json['estimados'];

    if (tracking == null) {
      // Sin tracking aún - retornar 0, NO usar estimados
      // El tracking real comenzará cuando el conductor inicie el viaje
      return ClientTrackingData(
        distanciaKm: 0.0,
        tiempoSegundos: 0,
        precioActual: 0.0,
        viajeEnCurso: false,
      );
    }

    return ClientTrackingData(
      distanciaKm: (tracking['distancia_km'] ?? 0).toDouble(),
      tiempoSegundos: tracking['tiempo_segundos'] ?? 0,
      precioActual: (tracking['precio_actual'] ?? 0).toDouble(),
      velocidadConductor: (tracking['velocidad_kmh'] ?? 0).toDouble(),
      latitudConductor: tracking['ubicacion']?['latitud']?.toDouble(),
      longitudConductor: tracking['ubicacion']?['longitud']?.toDouble(),
      viajeEnCurso: true,
      fase: tracking['fase'],
      ultimaActualizacion: tracking['ultima_actualizacion'] != null
          ? DateTime.tryParse(tracking['ultima_actualizacion'])
          : null,
      diferenciaDistancia: comparacion?['diferencia_distancia_km']?.toDouble(),
      diferenciaTiempo: comparacion?['diferencia_tiempo_min'],
      diferenciaPrecio: comparacion?['diferencia_precio']?.toDouble(),
      mensajeComparacion: comparacion?['mensaje'],
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
  static final ClientTripTrackingService _instance = ClientTripTrackingService._internal();
  factory ClientTripTrackingService() => _instance;
  ClientTripTrackingService._internal();

  // Configuración
  static const Duration _pollInterval = Duration(seconds: 5);
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();

  // Estado
  bool _isWatching = false;
  int? _solicitudId;
  Timer? _pollTimer;

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

      debugPrint('👀 [ClientTracking] Iniciando observación del viaje $solicitudId');

      // Obtener datos iniciales
      await _fetchTracking();

      // Iniciar polling
      _pollTimer = Timer.periodic(_pollInterval, (_) => _fetchTracking());

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

    _pollTimer?.cancel();
    _pollTimer = null;
    _isWatching = false;
    _solicitudId = null;
    _lastData = null;
  }

  /// Obtiene los datos de tracking una vez (sin polling)
  Future<ClientTrackingData?> getTrackingOnce(int solicitudId) async {
    try {
      final url = Uri.parse(
        '${AppConfig.baseUrl}/conductor/tracking/get_tracking.php?solicitud_id=$solicitudId'
      );

      final result = await _network.getJson(
        url: url,
        headers: {'Content-Type': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        if (result.error != null) {
          onError?.call(result.error!.userMessage);
        }
        return null;
      }

      final data = result.json!;
      if (data['success'] == true) {
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

  // =========================================================================
  // MÉTODOS PRIVADOS
  // =========================================================================

  Future<void> _fetchTracking() async {
    if (_solicitudId == null) return;

    try {
      final data = await getTrackingOnce(_solicitudId!);
      
      if (data != null) {
        _lastData = data;
        onTrackingUpdate?.call(data);
        
        // Log periódico para debug
        debugPrint('📍 [ClientTracking] Actualización: ${data.distanciaFormateada}, ${data.tiempoFormateado}, ${data.precioFormateado}');
      } else {
        debugPrint('⚠️ [ClientTracking] No hay datos de tracking disponibles');
      }
    } catch (e) {
      debugPrint('⚠️ [ClientTracking] Error en fetch: $e');
    }
  }
}
