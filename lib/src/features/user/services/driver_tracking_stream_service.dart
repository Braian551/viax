import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/config/app_config.dart';

class DriverTrackingEvent {
  DriverTrackingEvent({required this.event, required this.payload});

  final String event;
  final Map<String, dynamic> payload;
}

class DriverTrackingStreamService {
  HttpClient? _client;
  bool _closed = false;

  Future<void> connect({
    required int tripId,
    required void Function(DriverTrackingEvent event) onEvent,
    required void Function(Object error) onDisconnect,
  }) async {
    _closed = false;
    try {
      _client?.close(force: true);
      _client = HttpClient()..connectionTimeout = const Duration(seconds: 10);

      final uri = Uri.parse(
        '${AppConfig.baseUrl}/user/stream_trip_updates.php',
      ).replace(queryParameters: {'trip_id': '$tripId', 'wait_seconds': '35'});

      final request = await _client!.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('SSE status ${response.statusCode}', uri: uri);
      }

      String currentEvent = 'message';
      var dataBuffer = StringBuffer();

      await for (final line
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
        if (_closed) return;

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
            final decoded = jsonDecode(payloadRaw);
            if (decoded is Map<String, dynamic>) {
              onEvent(
                DriverTrackingEvent(event: currentEvent, payload: decoded),
              );
            }
          }
          currentEvent = 'message';
          dataBuffer = StringBuffer();
        }
      }

      throw const HttpException('SSE closed by server');
    } catch (e) {
      if (!_closed) {
        onDisconnect(e);
      }
    }
  }

  void close() {
    _closed = true;
    _client?.close(force: true);
  }
}
