import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

class FlutterMapTileProviderService {
  FlutterMapTileProviderService._();

  static const String userAgentPackageName = 'com.viax.app';
  static const Duration _tileFreshAge = Duration(days: 14);
  static const int _maxCacheSizeBytes = 300 * 1024 * 1024;

  static final http.Client _httpClient = http.Client();

  // Mantener un único proveedor reduce reconexiones HTTP y permite reutilizar
  // el caché integrado de flutter_map entre el mapa inicial y los previews.
  static final BuiltInMapCachingProvider _cachingProvider =
      BuiltInMapCachingProvider.getOrCreateInstance(
        maxCacheSize: _maxCacheSizeBytes,
        overrideFreshAge: _tileFreshAge,
        tileKeyGenerator: _buildStableTileKey,
      );

  static final TileProvider _sharedProvider = NetworkTileProvider(
    httpClient: _httpClient,
    cachingProvider: _cachingProvider,
    abortObsoleteRequests: true,
  );

  static TileProvider get provider => _sharedProvider;

  static void warmUp() {
    // Forzar la creación temprana del proveedor compartido evita trabajo extra
    // en la primera pantalla que necesite tiles.
    provider;
  }

  static String _buildStableTileKey(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      final normalizedParams = Map<String, String>.from(uri.queryParameters)
        ..remove('access_token');

      final normalizedUrl = uri.replace(
        queryParameters: normalizedParams.isEmpty ? null : normalizedParams,
      );

      return BuiltInMapCachingProvider.uuidTileKeyGenerator(
        normalizedUrl.toString(),
      );
    } catch (_) {
      return BuiltInMapCachingProvider.uuidTileKeyGenerator(rawUrl);
    }
  }
}