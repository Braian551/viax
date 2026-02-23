import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';

class TripRequestSearchService {
  static Timer? _searchTimer;
  static bool _isSearching = false;
  static int? _conductorId;
  static double? _currentLat;
  static double? _currentLng;
  static Function(List<Map<String, dynamic>>)? _onRequestsFound;
  static Function(String)? _onError;
  static final Set<int> _processedRequestIds = {};
  static const double searchRadiusKm = 5.0;
  static const int searchIntervalSeconds = 5;

  static void startSearching({
    required int conductorId,
    required double currentLat,
    required double currentLng,
    required Function(List<Map<String, dynamic>>) onRequestsFound,
    required Function(String) onError,
  }) {
    _conductorId = conductorId;
    _currentLat = currentLat;
    _currentLng = currentLng;
    _onRequestsFound = onRequestsFound;
    _onError = onError;

    if (_isSearching) {
      print('Ya hay una busqueda activa, actualizando contexto de búsqueda');
      return;
    }

    print('Iniciando busqueda de solicitudes...');
    _isSearching = true;

    _runSearchCycle();

    _searchTimer = Timer.periodic(
      const Duration(seconds: searchIntervalSeconds),
      (timer) {
        _runSearchCycle();
      },
    );
  }

  static void updateSearchLocation({
    required double latitude,
    required double longitude,
  }) {
    _currentLat = latitude;
    _currentLng = longitude;
  }

  static void stopSearching() {
    print('Deteniendo busqueda de solicitudes');
    _searchTimer?.cancel();
    _searchTimer = null;
    _isSearching = false;
    _conductorId = null;
    _currentLat = null;
    _currentLng = null;
    _onRequestsFound = null;
    _onError = null;
  }
  
  static void markRequestAsProcessed(int requestId) {
    _processedRequestIds.add(requestId);
    print('Solicitud  marcada como procesada');
  }
  
  static void clearProcessedRequests() {
    _processedRequestIds.clear();
    print('Cache de solicitudes procesadas limpiado');
  }

  static Future<void> _searchRequests({
    required int conductorId,
    required double currentLat,
    required double currentLng,
    required Function(List<Map<String, dynamic>>) onRequestsFound,
    required Function(String) onError,
  }) async {
    try {
      final response = await _postWithFallback(
        path: '/conductor/get_solicitudes_pendientes.php',
        body: {
          'conductor_id': conductorId,
          'latitud_actual': currentLat,
          'longitud_actual': currentLng,
          'radio_km': searchRadiusKm,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          final solicitudes = List<Map<String, dynamic>>.from(
            data['solicitudes'] ?? [],
          );
          
          final filteredSolicitudes = solicitudes.where((solicitud) {
            final id = solicitud['id'] as int?;
            return id != null && !_processedRequestIds.contains(id);
          }).toList();
          
          print('Encontradas ${solicitudes.length} solicitudes totales, ${filteredSolicitudes.length} nuevas');
          onRequestsFound(filteredSolicitudes);
        } else {
          print('Sin solicitudes: ${data['message']}');
          onRequestsFound([]);
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('Error buscando solicitudes: $e');
      onError(e.toString());
    }
  }

  static Future<void> _runSearchCycle() async {
    final conductorId = _conductorId;
    final currentLat = _currentLat;
    final currentLng = _currentLng;
    final onRequestsFound = _onRequestsFound;
    final onError = _onError;

    if (!_isSearching ||
        conductorId == null ||
        currentLat == null ||
        currentLng == null ||
        onRequestsFound == null ||
        onError == null) {
      return;
    }

    await _searchRequests(
      conductorId: conductorId,
      currentLat: currentLat,
      currentLng: currentLng,
      onRequestsFound: onRequestsFound,
      onError: onError,
    );
  }

  static Future<void> updateLocation({
    required int conductorId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _postWithFallback(
        path: '/conductor/update_location.php',
        body: {
          'conductor_id': conductorId,
          'latitud': latitude,
          'longitud': longitude,
        },
        timeout: const Duration(seconds: 5),
      );
    } catch (e) {
      print('Error actualizando ubicacion: ');
    }
  }

  static Future<Map<String, dynamic>> acceptRequest({
    required int solicitudId,
    required int conductorId,
  }) async {
    try {
      final response = await _postWithFallback(
        path: '/conductor/accept_trip_request.php',
        body: {
          'solicitud_id': solicitudId,
          'conductor_id': conductorId,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al aceptar solicitud: ',
      };
    }
  }

  static Future<Map<String, dynamic>> rejectRequest({
    required int solicitudId,
    required int conductorId,
    String? motivo,
  }) async {
    try {
      final response = await _postWithFallback(
        path: '/conductor/reject_trip_request.php',
        body: {
          'solicitud_id': solicitudId,
          'conductor_id': conductorId,
          'motivo': motivo ?? 'No disponible',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al rechazar solicitud: ',
      };
    }
  }

  static bool get isSearching => _isSearching;

  /// Hace POST probando múltiples hosts locales (IP LAN, 10.0.2.2, localhost)
  /// para evitar timeouts cuando se cambia entre emulador y dispositivo físico.
  static Future<http.Response> _postWithFallback({
    required String path,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    Exception? lastError;

    for (final base in AppConfig.baseUrlCandidates) {
      final url = Uri.parse('$base$path');
      try {
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(timeout);

        AppConfig.rememberWorkingBaseUrl(base);
        return response;
      } on TimeoutException catch (e) {
        lastError = e;
        print('⏳ Timeout en $path usando $base, probando siguiente host...');
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print('🌐 Error en $path usando $base: $e');
      }
    }

    throw lastError ?? Exception('No hay hosts disponibles para $path');
  }
}

