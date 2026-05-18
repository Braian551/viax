import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'flutter_map_tile_provider_service.dart';

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

    // Adelantar la inicialización del renderer y del proveedor compartido de
    // tiles reduce el costo de la primera apertura del mapa y del preview.
    await Future.delayed(const Duration(milliseconds: 100));
    FlutterMapTileProviderService.warmUp();
    _isReady = true;
  }
}
