import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapPreloadService {
  MapPreloadService._();

  static MapboxMap? mapInstance;
  static bool _isReady = false;
  static Future<void>? _warmupTask;

  static bool get isReady => _isReady;

  static Future<void> preload() {
    if (_isReady) {
      return Future<void>.value();
    }

    _warmupTask ??= _runWarmup();
    return _warmupTask!;
  }

  static Future<void> _runWarmup() async {
    if (_isReady) return;

    // Pequeña ventana para adelantar inicialización interna del renderer.
    await Future.delayed(const Duration(milliseconds: 100));
    _isReady = true;
  }
}
