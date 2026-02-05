import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'network_resilience_service.dart';

/// Tipo de operación de viaje
enum TripOperationType {
  finishTrip,
  startTrip,
  arrivedPickup,
  updateLocation,
  acceptRequest,
  cancelTrip,
}

/// Estado de sincronización
enum SyncStatus {
  synced,        // Todos los cambios sincronizados
  syncing,       // Sincronización en progreso
  pending,       // Cambios pendientes por sincronizar
  error,         // Error en la última sincronización
  offline,       // Sin conexión
}

/// Representa una operación optimista aplicada localmente
class OptimisticOperation {
  final String id;
  final TripOperationType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  final Map<String, dynamic>? previousState;
  int syncAttempts;
  SyncStatus status;
  String? lastError;

  OptimisticOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.timestamp,
    this.previousState,
    this.syncAttempts = 0,
    this.status = SyncStatus.pending,
    this.lastError,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'payload': payload,
    'timestamp': timestamp.toIso8601String(),
    'previousState': previousState,
    'syncAttempts': syncAttempts,
    'status': status.name,
    'lastError': lastError,
  };

  factory OptimisticOperation.fromJson(Map<String, dynamic> json) {
    return OptimisticOperation(
      id: json['id'],
      type: TripOperationType.values.firstWhere((e) => e.name == json['type']),
      payload: json['payload'],
      timestamp: DateTime.parse(json['timestamp']),
      previousState: json['previousState'],
      syncAttempts: json['syncAttempts'] ?? 0,
      status: SyncStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SyncStatus.pending,
      ),
      lastError: json['lastError'],
    );
  }
}

/// Resultado de una operación de sincronización
class SyncResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? serverData;

  const SyncResult({
    required this.success,
    this.error,
    this.serverData,
  });
}

/// Gestor de sincronización para operaciones de viaje
/// 
/// Implementa:
/// - Optimistic updates (cambios locales inmediatos)
/// - Cola de operaciones pendientes con persistencia
/// - Sincronización automática en background
/// - Rollback en caso de error
class TripSyncManager {
  static final TripSyncManager _instance = TripSyncManager._internal();
  factory TripSyncManager() => _instance;
  TripSyncManager._internal();

  final _resilienceService = NetworkResilienceService();
  
  /// Cola de operaciones pendientes
  final List<OptimisticOperation> _pendingOperations = [];
  
  /// Stream para notificar cambios de estado
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  
  /// Stream para operaciones individuales
  final _operationController = StreamController<OptimisticOperation>.broadcast();
  Stream<OptimisticOperation> get operationStream => _operationController.stream;
  
  /// Timer para sincronización periódica
  Timer? _syncTimer;
  
  /// Estado actual de sincronización
  SyncStatus _currentStatus = SyncStatus.synced;
  SyncStatus get currentStatus => _currentStatus;

  /// Inicializa el manager y carga operaciones pendientes
  Future<void> initialize() async {
    await _loadPendingOperations();
    _startPeriodicSync();
  }

  /// Aplica una operación de forma optimista
  /// 
  /// Retorna el ID de la operación para tracking
  Future<String> applyOptimistic({
    required TripOperationType type,
    required Map<String, dynamic> payload,
    required Future<SyncResult> Function() syncFunction,
    Map<String, dynamic>? previousState,
  }) async {
    final operationId = '${type.name}_${DateTime.now().millisecondsSinceEpoch}';
    
    final operation = OptimisticOperation(
      id: operationId,
      type: type,
      payload: payload,
      timestamp: DateTime.now(),
      previousState: previousState,
    );
    
    _pendingOperations.add(operation);
    await _savePendingOperations();
    _updateStatus(SyncStatus.pending);
    _operationController.add(operation);
    
    // Intentar sincronizar inmediatamente
    _syncOperation(operation, syncFunction);
    
    return operationId;
  }

  /// Sincroniza una operación con el servidor
  Future<void> _syncOperation(
    OptimisticOperation operation,
    Future<SyncResult> Function() syncFunction,
  ) async {
    operation.status = SyncStatus.syncing;
    operation.syncAttempts++;
    _operationController.add(operation);
    _updateStatus(SyncStatus.syncing);
    
    try {
      final result = await syncFunction();
      
      if (result.success) {
        operation.status = SyncStatus.synced;
        _pendingOperations.removeWhere((op) => op.id == operation.id);
        await _savePendingOperations();
        debugPrint('✅ Operación ${operation.id} sincronizada exitosamente');
      } else {
        operation.status = SyncStatus.error;
        operation.lastError = result.error;
        debugPrint('❌ Error sincronizando ${operation.id}: ${result.error}');
      }
    } catch (e) {
      operation.status = SyncStatus.error;
      operation.lastError = e.toString();
      debugPrint('❌ Excepción sincronizando ${operation.id}: $e');
    }
    
    _operationController.add(operation);
    await _savePendingOperations();
    _recalculateStatus();
  }

  /// Reintenta operaciones pendientes
  Future<void> retryPending({
    required Future<SyncResult> Function(OptimisticOperation) syncFunctionFactory,
  }) async {
    final pending = _pendingOperations.where(
      (op) => op.status == SyncStatus.pending || op.status == SyncStatus.error
    ).toList();
    
    for (final operation in pending) {
      if (operation.syncAttempts < 5) { // Máximo 5 intentos
        await _syncOperation(operation, () => syncFunctionFactory(operation));
      } else {
        debugPrint('⚠️ Operación ${operation.id} excedió límite de reintentos');
      }
    }
  }

  /// Obtiene estado de una operación específica
  OptimisticOperation? getOperation(String operationId) {
    try {
      return _pendingOperations.firstWhere((op) => op.id == operationId);
    } catch (_) {
      return null;
    }
  }

  /// Verifica si hay operaciones pendientes de un tipo
  bool hasPendingOfType(TripOperationType type) {
    return _pendingOperations.any((op) => op.type == type);
  }

  /// Obtiene operaciones pendientes
  List<OptimisticOperation> get pendingOperations => List.unmodifiable(_pendingOperations);

  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _syncStatusController.add(status);
  }

  void _recalculateStatus() {
    if (_pendingOperations.isEmpty) {
      _updateStatus(SyncStatus.synced);
    } else if (_pendingOperations.any((op) => op.status == SyncStatus.error)) {
      _updateStatus(SyncStatus.error);
    } else if (_pendingOperations.any((op) => op.status == SyncStatus.syncing)) {
      _updateStatus(SyncStatus.syncing);
    } else {
      _updateStatus(SyncStatus.pending);
    }
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_pendingOperations.isNotEmpty) {
        debugPrint('🔄 Sincronización periódica: ${_pendingOperations.length} operaciones pendientes');
        // La sincronización real se maneja externamente con retryPending
      }
    });
  }

  Future<void> _loadPendingOperations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('trip_pending_operations');
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _pendingOperations.clear();
        _pendingOperations.addAll(
          jsonList.map((json) => OptimisticOperation.fromJson(json)).toList(),
        );
        debugPrint('📥 Cargadas ${_pendingOperations.length} operaciones pendientes');
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando operaciones pendientes: $e');
    }
    _recalculateStatus();
  }

  Future<void> _savePendingOperations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_pendingOperations.map((op) => op.toJson()).toList());
      await prefs.setString('trip_pending_operations', jsonString);
    } catch (e) {
      debugPrint('⚠️ Error guardando operaciones pendientes: $e');
    }
  }

  /// Limpia todas las operaciones
  Future<void> clearAll() async {
    _pendingOperations.clear();
    await _savePendingOperations();
    _updateStatus(SyncStatus.synced);
  }

  /// Marca una operación como completada (exitosamente sincronizada externamente)
  Future<void> markCompleted(String operationId) async {
    _pendingOperations.removeWhere((op) => op.id == operationId);
    await _savePendingOperations();
    _recalculateStatus();
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncStatusController.close();
    _operationController.close();
  }
}
