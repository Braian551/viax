import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';

/// Servicio SSE con reconexión automática infinita para eventos de viaje.
class TripSseService {
  HttpClient? _client;
  bool _running = false;

  Future<void> start({
    required int tripId,
    required void Function(Map<String, dynamic> event) onTripUpdate,
    void Function(String error)? onError,
    String? sinceSignature,
  }) async {
    _running = true;

    while (_running) {
      final startedAt = DateTime.now();
      try {
        await _connectAndConsume(
          tripId: tripId,
          onTripUpdate: onTripUpdate,
          sinceSignature: sinceSignature,
        );

        if (!_running) break;

        _log(
          tag: '[SSE_DISCONNECTED]',
          tripId: tripId,
          result: 'closed_by_server',
          latencyMs: DateTime.now().difference(startedAt).inMilliseconds,
        );
      } catch (e) {
        if (!_running) break;

        onError?.call(e.toString());
        _log(
          tag: '[SSE_DISCONNECTED]',
          tripId: tripId,
          result: 'error_$e',
          latencyMs: DateTime.now().difference(startedAt).inMilliseconds,
        );
      }

      if (!_running) break;

      await Future.delayed(const Duration(seconds: 3));
      if (!_running) break;

      _log(
        tag: '[SSE_RECONNECTED]',
        tripId: tripId,
        result: 'retry_after_3s',
        latencyMs: 3000,
      );
    }
  }

  Future<void> stop() async {
    _running = false;
    try {
      _client?.close(force: true);
    } catch (_) {}
    _client = null;
  }

  Future<void> _connectAndConsume({
    required int tripId,
    required void Function(Map<String, dynamic> event) onTripUpdate,
    String? sinceSignature,
  }) async {
    final query = <String, String>{'trip_id': '$tripId'};
    if (sinceSignature != null && sinceSignature.isNotEmpty) {
      query['since_signature'] = sinceSignature;
    }

    final uri = Uri.parse('${AppConfig.baseUrl}/sse/trip_updates.php').replace(
      queryParameters: query,
    );

    _client?.close(force: true);
    _client = HttpClient()..connectionTimeout = const Duration(seconds: 12);

    final request = await _client!.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');

    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('SSE status ${response.statusCode}', uri: uri);
    }

    _log(
      tag: '[SSE_CONNECTED]',
      tripId: tripId,
      result: 'ok',
      latencyMs: 0,
    );

    String? currentEvent;
    var buffer = StringBuffer();

    await for (final line in response
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (!_running) {
        return;
      }

      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
        continue;
      }

      if (line.startsWith('data:')) {
        buffer.writeln(line.substring(5).trim());
        continue;
      }

      if (line.trim().isEmpty) {
        final payloadRaw = buffer.toString().trim();
        if (payloadRaw.isNotEmpty) {
          _dispatchEvent(currentEvent, payloadRaw, onTripUpdate);
        }
        currentEvent = null;
        buffer = StringBuffer();
      }
    }

    throw const HttpException('SSE closed by server');
  }

  void _dispatchEvent(
    String? currentEvent,
    String payloadRaw,
    void Function(Map<String, dynamic> event) onTripUpdate,
  ) {
    try {
      final decoded = jsonDecode(payloadRaw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      if (currentEvent == null ||
          currentEvent == 'trip_update' ||
          currentEvent == 'message') {
        onTripUpdate(decoded);
      }
    } catch (e) {
      debugPrint('[SSE_DISCONNECTED] ts=${DateTime.now().toIso8601String()} tripId=0 latency_ms=0 result=payload_error_$e');
    }
  }

  void _log({
    required String tag,
    required int tripId,
    required String result,
    required int latencyMs,
  }) {
    final ts = DateTime.now().toIso8601String();
    debugPrint('$tag ts=$ts tripId=$tripId latency_ms=$latencyMs result=$result');
  }
}
