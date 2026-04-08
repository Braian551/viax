import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'trip_command_queue.dart';

class TripCommandExecutionResult {
  final bool success;
  final bool pending;
  final String message;
  final Map<String, dynamic>? responseData;

  const TripCommandExecutionResult({
    required this.success,
    required this.pending,
    required this.message,
    this.responseData,
  });
}

/// Ejecutor confiable de comandos de viaje con reintentos y flush por red.
class TripCommandExecutor {
  TripCommandExecutor._();

  static final TripCommandExecutor instance = TripCommandExecutor._();

  static const List<int> _backoffSeconds = <int>[5, 10, 20, 40, 80];
  static const int _maxRetries = 10;

  bool _flushInProgress = false;

  Future<TripCommandExecutionResult> enqueueAndTryNow({
    required int tripId,
    required TripCommandType type,
    required Map<String, dynamic> payload,
  }) async {
    final startedAt = DateTime.now();

    final command = await TripCommandQueue.instance.enqueue(
      tripId: tripId,
      type: type,
      payload: payload,
    );

    if (command == null || command.id == null) {
      return const TripCommandExecutionResult(
        success: false,
        pending: true,
        message: 'No se pudo encolar el comando.',
      );
    }

    final result = await _tryExecuteCommand(command);

    _log(
      tag: '[TripExecutor]',
      tripId: tripId,
      result: result.success
          ? 'executed_now_success'
          : (result.pending ? 'queued_pending' : 'executed_now_failed'),
      latencyMs: DateTime.now().difference(startedAt).inMilliseconds,
    );

    return result;
  }

  Future<void> flushQueue() async {
    if (_flushInProgress) {
      return;
    }

    _flushInProgress = true;
    final startedAt = DateTime.now();
    var processed = 0;

    try {
      final pending = await TripCommandQueue.instance.getPendingCommands();
      for (final command in pending) {
        if (command.id == null) {
          continue;
        }

        if (!_isDueForRetry(command)) {
          continue;
        }

        await _tryExecuteCommand(command);
        processed += 1;
      }

      _log(
        tag: '[TripExecutor]',
        tripId: 0,
        result: 'flush_done_processed_$processed',
        latencyMs: DateTime.now().difference(startedAt).inMilliseconds,
      );
    } finally {
      _flushInProgress = false;
    }
  }

  Future<TripCommandExecutionResult> _tryExecuteCommand(TripCommand command) async {
    final startedAt = DateTime.now();

    try {
      final response = await _sendToBackend(command);
      final parsed = _safeParseJson(response.body);

      final ok = await _isResponseSuccessful(
        tripId: command.tripId,
        commandType: command.commandType,
        statusCode: response.statusCode,
        payload: parsed,
      );

      if (ok) {
        await TripCommandQueue.instance.removeById(command.id!);

        _log(
          tag: '[TripExecutor]',
          tripId: command.tripId,
          result: 'success_${command.commandType}',
          latencyMs: DateTime.now().difference(startedAt).inMilliseconds,
        );

        return TripCommandExecutionResult(
          success: true,
          pending: false,
          message: 'Comando sincronizado correctamente.',
          responseData: parsed,
        );
      }

      final nextRetry = command.retryCount + 1;
      await _onAttemptFailed(command: command, nextRetry: nextRetry);

      final pending = nextRetry < _maxRetries;
      _log(
        tag: '[TripExecutor]',
        tripId: command.tripId,
        result: pending
            ? 'retry_scheduled_${command.commandType}'
            : 'failed_max_retries_${command.commandType}',
        latencyMs: DateTime.now().difference(startedAt).inMilliseconds,
      );

      return TripCommandExecutionResult(
        success: false,
        pending: pending,
        message: pending
            ? 'Comando en cola, se reintentará automáticamente.'
            : 'No fue posible sincronizar el comando después de varios intentos.',
        responseData: parsed,
      );
    } catch (e) {
      final nextRetry = command.retryCount + 1;
      await _onAttemptFailed(command: command, nextRetry: nextRetry);

      final pending = nextRetry < _maxRetries;

      _log(
        tag: '[TripExecutor]',
        tripId: command.tripId,
        result: pending
            ? 'network_retry_${command.commandType}'
            : 'network_failed_max_retries_${command.commandType}',
        latencyMs: DateTime.now().difference(startedAt).inMilliseconds,
      );

      return TripCommandExecutionResult(
        success: false,
        pending: pending,
        message: pending
            ? 'Sin conexión estable. El comando quedó en cola.'
            : 'Error de red persistente. Requiere intervención manual.',
      );
    }
  }

  Future<void> _onAttemptFailed({
    required TripCommand command,
    required int nextRetry,
  }) async {
    if (nextRetry >= _maxRetries) {
      await TripCommandQueue.instance.removeById(command.id!);
      return;
    }

    await TripCommandQueue.instance.markAttempt(
      commandId: command.id!,
      retryCount: nextRetry,
      lastAttemptAt: DateTime.now(),
    );
  }

  bool _isDueForRetry(TripCommand command) {
    if (command.retryCount <= 0 || command.lastAttemptAt == null) {
      return true;
    }

    final idx = command.retryCount - 1;
    final backoff = idx >= 0 && idx < _backoffSeconds.length
        ? _backoffSeconds[idx]
        : _backoffSeconds.last;

    final nextAllowed = command.lastAttemptAt!.add(Duration(seconds: backoff));
    return DateTime.now().isAfter(nextAllowed);
  }

  Future<http.Response> _sendToBackend(TripCommand command) async {
    final payload = command.payloadMap();
    final uri = _resolveEndpoint(command.commandType, payload);

    return http
        .post(
          uri,
          headers: const <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));
  }

  Uri _resolveEndpoint(String commandType, Map<String, dynamic> payload) {
    switch (commandType) {
      case 'finish_trip':
        // Compatibilidad: en producción el cierre actual del viaje entra por update_trip_status.
        return Uri.parse('${AppConfig.conductorServiceUrl}/update_trip_status.php');
      case 'start_trip':
      case 'driver_arrived':
      case 'cancel_trip':
        return Uri.parse('${AppConfig.conductorServiceUrl}/update_trip_status.php');
      default:
        throw ArgumentError('Tipo de comando no soportado: $commandType');
    }
  }

  Future<bool> _isResponseSuccessful({
    required int tripId,
    required String commandType,
    required int statusCode,
    required Map<String, dynamic>? payload,
  }) async {
    if (statusCode < 200 || statusCode >= 300 || payload == null) {
      return false;
    }

    final success = payload['success'] == true;
    if (!success) {
      return false;
    }

    if (commandType != 'finish_trip') {
      return true;
    }

    final stateRaw = (payload['trip_state'] ?? payload['estado'] ?? payload['status'])
        ?.toString()
        .toLowerCase();

    final responseSaysCompleted = stateRaw == 'completed' ||
        stateRaw == 'completada' ||
        stateRaw == 'completado' ||
        stateRaw == 'finalizada' ||
        stateRaw == 'finalizado';

    if (responseSaysCompleted) {
      return true;
    }

    // Autoridad del servidor: confirmar estado real del viaje antes de fallar.
    return _confirmCompletedStateFromServer(tripId);
  }

  Future<bool> _confirmCompletedStateFromServer(int tripId) async {
    // Poll corto para cubrir propagación eventual en backend.
    const checks = 3;
    for (var i = 0; i < checks; i++) {
      try {
        final uri = Uri.parse(
          '${AppConfig.baseUrl}/user/get_trip_status.php?solicitud_id=$tripId&wait_seconds=1',
        );

        final response = await http
            .get(
              uri,
              headers: const <String, String>{
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final payload = _safeParseJson(response.body);
          final estado = (payload?['trip']?['estado'] ??
                  payload?['estado'] ??
                  payload?['trip_state'])
              ?.toString()
              .toLowerCase();

          if (estado == 'completed' ||
              estado == 'completada' ||
              estado == 'completado' ||
              estado == 'finalizada' ||
              estado == 'finalizado') {
            return true;
          }
        }
      } catch (_) {
        // Ignorar y reintentar; la lógica de cola cubrirá fallas persistentes.
      }

      if (i < checks - 1) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    return false;
  }

  Map<String, dynamic>? _safeParseJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _log({
    required String tag,
    required int tripId,
    required String result,
    required int latencyMs,
  }) {
    final ts = DateTime.now().toIso8601String();
    debugPrint(
      '$tag ts=$ts tripId=$tripId latency_ms=$latencyMs result=$result',
    );
  }
}
