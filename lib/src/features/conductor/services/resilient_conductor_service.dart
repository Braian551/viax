import 'package:flutter/foundation.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/network_resilience_service.dart';
import '../../../core/network/trip_sync_manager.dart';

/// Servicio de conductor con resiliencia de red
/// 
/// Proporciona:
/// - Reintentos automáticos con backoff exponencial
/// - Idempotencia para operaciones críticas
/// - Cola de operaciones para modo offline
/// - Optimistic updates
class ResilientConductorService {
  static final ResilientConductorService _instance = ResilientConductorService._internal();
  factory ResilientConductorService() => _instance;
  ResilientConductorService._internal();

  final _networkService = NetworkResilienceService();
  final _syncManager = TripSyncManager();

  /// URL base del microservicio de conductores
  static String get baseUrl => AppConfig.conductorServiceUrl;

  /// Genera una clave de idempotencia única
  static String generateIdempotencyKey(String operation, int solicitudId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 30000; // Única por 30 segundos
    return '${operation}_${solicitudId}_$timestamp';
  }

  /// Aceptar solicitud de viaje con reintentos y concurrencia segura
  Future<Map<String, dynamic>> aceptarSolicitudResilient({
    required int conductorId,
    required int solicitudId,
  }) async {
    final idempotencyKey = generateIdempotencyKey('accept', solicitudId);
    
    final result = await _networkService.postWithRetry(
      url: '$baseUrl/accept_trip_request.php',
      body: {
        'conductor_id': conductorId,
        'solicitud_id': solicitudId,
        'idempotency_key': idempotencyKey,
      },
      headers: {
        'X-Idempotency-Key': idempotencyKey,
      },
      maxRetries: 3,
      timeout: const Duration(seconds: 20),
      operationId: idempotencyKey,
    );

    if (result.isSuccess) {
      return result.data ?? {'success': false, 'message': 'Respuesta vacía'};
    } else {
      return {
        'success': false,
        'message': result.error ?? 'Error de conexión',
        'retry': true,
        'attempts': result.attempts,
      };
    }
  }

  /// Notificar llegada al punto de recogida con reintentos
  Future<bool> notificarLlegadaRecogidaResilient({
    required int conductorId,
    required int solicitudId,
  }) async {
    final idempotencyKey = generateIdempotencyKey('arrived', solicitudId);
    
    // Aplicar optimistically (asumir éxito)
    await _syncManager.applyOptimistic(
      type: TripOperationType.arrivedPickup,
      payload: {
        'conductor_id': conductorId,
        'solicitud_id': solicitudId,
        'nuevo_estado': 'conductor_llego',
      },
      syncFunction: () async {
        final result = await _actualizarEstadoViajeResilient(
          conductorId: conductorId,
          solicitudId: solicitudId,
          nuevoEstado: 'conductor_llego',
          idempotencyKey: idempotencyKey,
        );
        return SyncResult(
          success: result['success'] == true,
          error: result['message'],
          serverData: result,
        );
      },
    );

    // Retornar true inmediatamente (optimistic)
    return true;
  }

  /// Iniciar viaje con reintentos
  Future<bool> iniciarViajeResilient({
    required int conductorId,
    required int solicitudId,
  }) async {
    final idempotencyKey = generateIdempotencyKey('start', solicitudId);
    
    await _syncManager.applyOptimistic(
      type: TripOperationType.startTrip,
      payload: {
        'conductor_id': conductorId,
        'solicitud_id': solicitudId,
        'nuevo_estado': 'en_curso',
      },
      syncFunction: () async {
        final result = await _actualizarEstadoViajeResilient(
          conductorId: conductorId,
          solicitudId: solicitudId,
          nuevoEstado: 'en_curso',
          idempotencyKey: idempotencyKey,
        );
        return SyncResult(
          success: result['success'] == true,
          error: result['message'],
          serverData: result,
        );
      },
    );

    return true;
  }

  /// Completar viaje con reintentos y garantía de entrega
  /// 
  /// Esta operación es crítica y debe completarse eventualmente
  Future<Map<String, dynamic>> completarViajeResilient({
    required int conductorId,
    required int solicitudId,
    double? distanceKm,
    int? elapsedMinutes,
  }) async {
    final idempotencyKey = generateIdempotencyKey('complete', solicitudId);
    
    final operationId = await _syncManager.applyOptimistic(
      type: TripOperationType.finishTrip,
      payload: {
        'conductor_id': conductorId,
        'solicitud_id': solicitudId,
        'nuevo_estado': 'completada',
        'distancia_recorrida': distanceKm,
        'tiempo_transcurrido': elapsedMinutes,
      },
      syncFunction: () async {
        final result = await _actualizarEstadoViajeResilient(
          conductorId: conductorId,
          solicitudId: solicitudId,
          nuevoEstado: 'completada',
          distanceKm: distanceKm,
          elapsedMinutes: elapsedMinutes,
          idempotencyKey: idempotencyKey,
        );
        return SyncResult(
          success: result['success'] == true,
          error: result['message'],
          serverData: result,
        );
      },
    );

    debugPrint('📤 Operación de completar viaje encolada: $operationId');
    
    // Esperar un poco y verificar el estado
    await Future.delayed(const Duration(milliseconds: 500));
    
    final operation = _syncManager.getOperation(operationId);
    if (operation != null && operation.status == SyncStatus.synced) {
      return {'success': true, 'message': 'Viaje completado'};
    } else if (operation != null && operation.status == SyncStatus.error) {
      return {
        'success': false, 
        'message': operation.lastError ?? 'Error desconocido',
        'retry': true,
      };
    }
    
    // Retornar éxito optimista
    return {'success': true, 'message': 'Viaje completándose...', 'pending': true};
  }

  /// Método interno para actualizar estado con resiliencia
  Future<Map<String, dynamic>> _actualizarEstadoViajeResilient({
    required int conductorId,
    required int solicitudId,
    required String nuevoEstado,
    String? motivoCancelacion,
    double? distanceKm,
    int? elapsedMinutes,
    required String idempotencyKey,
  }) async {
    final body = {
      'conductor_id': conductorId,
      'solicitud_id': solicitudId,
      'nuevo_estado': nuevoEstado,
      'idempotency_key': idempotencyKey,
      if (motivoCancelacion != null) 'motivo_cancelacion': motivoCancelacion,
      if (distanceKm != null) 'distancia_recorrida': distanceKm,
      if (elapsedMinutes != null) 'tiempo_transcurrido': elapsedMinutes,
    };

    final result = await _networkService.postWithRetry(
      url: '$baseUrl/update_trip_status.php',
      body: body,
      headers: {
        'X-Idempotency-Key': idempotencyKey,
      },
      maxRetries: 5, // Más reintentos para operaciones críticas
      timeout: const Duration(seconds: 25),
      operationId: idempotencyKey,
    );

    if (result.isSuccess) {
      debugPrint('✅ Estado actualizado a $nuevoEstado (${result.attempts} intentos, ${result.totalDuration.inMilliseconds}ms)');
      return result.data ?? {'success': false, 'message': 'Respuesta vacía'};
    } else {
      debugPrint('❌ Error actualizando estado: ${result.error}');
      return {
        'success': false,
        'message': result.error ?? 'Error de conexión',
        'attempts': result.attempts,
      };
    }
  }

  /// Verificar si hay operaciones pendientes de sincronizar
  bool get hasPendingOperations => _syncManager.pendingOperations.isNotEmpty;

  /// Obtener número de operaciones pendientes
  int get pendingOperationsCount => _syncManager.pendingOperations.length;

  /// Stream de estado de sincronización
  Stream<SyncStatus> get syncStatusStream => _syncManager.syncStatusStream;

  /// Reintentar operaciones pendientes
  Future<void> retryPendingOperations() async {
    await _syncManager.retryPending(
      syncFunctionFactory: (operation) async {
        final payload = operation.payload;
        final result = await _actualizarEstadoViajeResilient(
          conductorId: payload['conductor_id'],
          solicitudId: payload['solicitud_id'],
          nuevoEstado: payload['nuevo_estado'],
          distanceKm: payload['distancia_recorrida'],
          elapsedMinutes: payload['tiempo_transcurrido'],
          idempotencyKey: operation.id,
        );
        return SyncResult(
          success: result['success'] == true,
          error: result['message'],
          serverData: result,
        );
      },
    );
  }

  /// Inicializar el servicio
  Future<void> initialize() async {
    await _syncManager.initialize();
  }
}

/// Extension para simplificar uso con ConductorService existente
extension ConductorServiceResilient on Type {
  static ResilientConductorService get resilient => ResilientConductorService();
}
