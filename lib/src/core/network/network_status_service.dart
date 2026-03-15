import 'dart:async';

import 'package:flutter/foundation.dart';

import '../offline/trip_command_executor.dart';
import 'connectivity_service.dart';

/// Servicio para observar conectividad y disparar flush de cola al reconectar.
class NetworkStatusService {
  NetworkStatusService._();

  static final NetworkStatusService instance = NetworkStatusService._();

  bool _initialized = false;
  bool _lastKnownOnline = true;
  VoidCallback? _listener;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    final connectivity = ConnectivityService();
    _lastKnownOnline = connectivity.isOnline;

    _listener = () {
      final nowOnline = connectivity.isOnline;
      final wasOnline = _lastKnownOnline;
      _lastKnownOnline = nowOnline;

      final ts = DateTime.now().toIso8601String();
      debugPrint(
        '[NetworkStatus] ts=$ts tripId=0 latency_ms=0 result=state_${nowOnline ? 'online' : 'offline'}',
      );

      if (!wasOnline && nowOnline) {
        unawaited(_flushPendingCommands());
      }
    };

    connectivity.isOnlineListenable.addListener(_listener!);

    if (connectivity.isOnline) {
      await _flushPendingCommands();
    }
  }

  Future<void> _flushPendingCommands() async {
    final startedAt = DateTime.now();
    await TripCommandExecutor.instance.flushQueue();
    final latency = DateTime.now().difference(startedAt).inMilliseconds;

    final ts = DateTime.now().toIso8601String();
    debugPrint(
      '[NetworkStatus] ts=$ts tripId=0 latency_ms=$latency result=flush_triggered',
    );
  }

  Future<void> dispose() async {
    if (!_initialized) {
      return;
    }

    if (_listener != null) {
      ConnectivityService().isOnlineListenable.removeListener(_listener!);
      _listener = null;
    }

    _initialized = false;
  }
}
