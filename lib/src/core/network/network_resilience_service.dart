import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Resultado de una operación con reintentos
class NetworkResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;
  final int attempts;
  final Duration totalDuration;

  const NetworkResult._({
    this.data,
    this.error,
    required this.isSuccess,
    required this.attempts,
    required this.totalDuration,
  });

  factory NetworkResult.success(T data, int attempts, Duration duration) {
    return NetworkResult._(
      data: data,
      isSuccess: true,
      attempts: attempts,
      totalDuration: duration,
    );
  }

  factory NetworkResult.failure(String error, int attempts, Duration duration) {
    return NetworkResult._(
      error: error,
      isSuccess: false,
      attempts: attempts,
      totalDuration: duration,
    );
  }
}

/// Estado de una operación en curso para optimistic updates
enum OperationStatus {
  pending,
  inProgress,
  success,
  failed,
  retrying,
}

/// Información de operación pendiente para cola de sincronización
class PendingOperation {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int attempts;
  OperationStatus status;

  PendingOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.attempts = 0,
    this.status = OperationStatus.pending,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'attempts': attempts,
    'status': status.name,
  };

  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      id: json['id'],
      type: json['type'],
      data: json['data'],
      createdAt: DateTime.parse(json['createdAt']),
      attempts: json['attempts'] ?? 0,
      status: OperationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => OperationStatus.pending,
      ),
    );
  }
}

/// Servicio para manejo de resiliencia de red
/// 
/// Proporciona:
/// - Reintentos automáticos con backoff exponencial
/// - Timeout configurable
/// - Cola de operaciones pendientes
/// - Detección de conectividad
class NetworkResilienceService {
  static final NetworkResilienceService _instance = NetworkResilienceService._internal();
  factory NetworkResilienceService() => _instance;
  NetworkResilienceService._internal();

  /// Cola de operaciones pendientes para sincronización
  final List<PendingOperation> _pendingQueue = [];
  
  /// Stream controller para notificar cambios en el estado de operaciones
  final _operationStatusController = StreamController<PendingOperation>.broadcast();
  Stream<PendingOperation> get operationStatusStream => _operationStatusController.stream;

  /// Configuración por defecto
  static const int defaultMaxRetries = 3;
  static const Duration defaultTimeout = Duration(seconds: 15);
  static const Duration defaultRetryDelay = Duration(seconds: 2);

  /// Ejecuta una solicitud HTTP con reintentos automáticos
  Future<NetworkResult<Map<String, dynamic>>> executeWithRetry({
    required Future<http.Response> Function() request,
    int maxRetries = defaultMaxRetries,
    Duration timeout = defaultTimeout,
    Duration retryDelay = defaultRetryDelay,
    bool useExponentialBackoff = true,
    String? operationId,
  }) async {
    final stopwatch = Stopwatch()..start();
    int attempts = 0;
    String? lastError;

    while (attempts < maxRetries) {
      attempts++;
      
      try {
        final response = await request().timeout(timeout);
        stopwatch.stop();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          
          if (operationId != null) {
            _removeFromQueue(operationId);
          }
          
          return NetworkResult.success(data, attempts, stopwatch.elapsed);
        } else {
          lastError = 'HTTP ${response.statusCode}: ${response.body}';
          debugPrint('⚠️ [Retry $attempts/$maxRetries] $lastError');
        }
      } on TimeoutException {
        lastError = 'Tiempo de espera agotado';
        debugPrint('⏱️ [Retry $attempts/$maxRetries] Timeout');
      } on SocketException catch (e) {
        lastError = 'Error de conexión: ${e.message}';
        debugPrint('🔌 [Retry $attempts/$maxRetries] Socket error: $e');
      } catch (e) {
        lastError = e.toString();
        debugPrint('❌ [Retry $attempts/$maxRetries] Error: $e');
      }

      // Si no es el último intento, esperar antes de reintentar
      if (attempts < maxRetries) {
        final delay = useExponentialBackoff 
          ? retryDelay * (1 << (attempts - 1)) // 2s, 4s, 8s...
          : retryDelay;
        
        debugPrint('⏳ Reintentando en ${delay.inSeconds}s...');
        await Future.delayed(delay);
      }
    }

    stopwatch.stop();
    return NetworkResult.failure(
      lastError ?? 'Error desconocido',
      attempts,
      stopwatch.elapsed,
    );
  }

  /// Ejecuta una operación POST con reintentos
  Future<NetworkResult<Map<String, dynamic>>> postWithRetry({
    required String url,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
    int maxRetries = defaultMaxRetries,
    Duration timeout = defaultTimeout,
    String? operationId,
  }) async {
    return executeWithRetry(
      operationId: operationId,
      maxRetries: maxRetries,
      timeout: timeout,
      request: () => http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...?headers,
        },
        body: jsonEncode(body),
      ),
    );
  }

  /// Agrega una operación a la cola de pendientes
  String addToQueue({
    required String type,
    required Map<String, dynamic> data,
  }) {
    final id = '${type}_${DateTime.now().millisecondsSinceEpoch}';
    final operation = PendingOperation(
      id: id,
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );
    _pendingQueue.add(operation);
    _operationStatusController.add(operation);
    return id;
  }

  /// Remueve una operación de la cola
  void _removeFromQueue(String operationId) {
    _pendingQueue.removeWhere((op) => op.id == operationId);
  }

  /// Obtiene operaciones pendientes por tipo
  List<PendingOperation> getPendingByType(String type) {
    return _pendingQueue.where((op) => op.type == type).toList();
  }

  /// Número de operaciones pendientes
  int get pendingCount => _pendingQueue.length;

  /// Limpia todas las operaciones pendientes
  void clearQueue() {
    _pendingQueue.clear();
  }

  /// Libera recursos
  void dispose() {
    _operationStatusController.close();
  }
}

/// Extension para facilitar el uso con callbacks de UI
extension NetworkResultExtension<T> on NetworkResult<T> {
  /// Ejecuta callbacks según el resultado
  void when({
    required void Function(T data) onSuccess,
    required void Function(String error) onError,
  }) {
    if (isSuccess && data != null) {
      onSuccess(data as T);
    } else {
      onError(error ?? 'Error desconocido');
    }
  }
}
