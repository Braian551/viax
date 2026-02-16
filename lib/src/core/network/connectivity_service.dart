import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitorea conectividad de red y acceso real a internet.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> _isOnlineNotifier = ValueNotifier<bool>(true);

  StreamSubscription<dynamic>? _subscription;
  bool _initialized = false;

  ValueListenable<bool> get isOnlineListenable => _isOnlineNotifier;
  bool get isOnline => _isOnlineNotifier.value;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await refreshConnectionStatus();

    _subscription = _connectivity.onConnectivityChanged.listen(
      (dynamic result) async {
        final hasNetworkInterface = _hasAnyNetwork(result);
        if (!hasNetworkInterface) {
          _setOnline(false);
          return;
        }

        await refreshConnectionStatus();
      },
      onError: (_) {
        _setOnline(false);
      },
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }

  Future<bool> refreshConnectionStatus() async {
    try {
      final dynamic connectivityResult = await _connectivity.checkConnectivity();
      if (!_hasAnyNetwork(connectivityResult)) {
        _setOnline(false);
        return false;
      }

      final bool hasInternet = await _hasInternetAccess();
      _setOnline(hasInternet);
      return hasInternet;
    } catch (_) {
      _setOnline(false);
      return false;
    }
  }

  Future<bool> hasInternetConnection() async {
    return refreshConnectionStatus();
  }

  bool _hasAnyNetwork(dynamic connectivityResult) {
    if (connectivityResult is List<ConnectivityResult>) {
      return connectivityResult.any((result) => result != ConnectivityResult.none);
    }

    if (connectivityResult is ConnectivityResult) {
      return connectivityResult != ConnectivityResult.none;
    }

    return false;
  }

  Future<bool> _hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _setOnline(bool value) {
    if (_isOnlineNotifier.value == value) return;
    _isOnlineNotifier.value = value;
  }
}
