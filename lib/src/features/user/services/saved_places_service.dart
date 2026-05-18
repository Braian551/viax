import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/features/user/data/models/saved_user_place.dart';
import 'package:viax/src/global/models/simple_location.dart';
import 'package:viax/src/global/services/auth/user_service.dart';

class _SavedPlacesSession {
  final int userId;
  final String email;

  const _SavedPlacesSession({required this.userId, required this.email});
}

class SavedPlacesService {
  static SavedPlacesCollection _cachedPlaces = const SavedPlacesCollection.empty();
  static int? _cachedUserId;

  static Future<_SavedPlacesSession?> _getCurrentSession() async {
    final session = await UserService.getSavedSession();
    final rawId = session?['id'];
    final userId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (userId == null || userId <= 0) {
      _invalidateCache();
      return null;
    }

    return _SavedPlacesSession(
      userId: userId,
      email: session?['email']?.toString() ?? '',
    );
  }

  static void _invalidateCache() {
    _cachedPlaces = const SavedPlacesCollection.empty();
    _cachedUserId = null;
  }

  static Future<Map<String, dynamic>> _decodeJsonResponse(
    http.Response response,
  ) async {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw Exception('Respuesta inesperada del servidor');
  }

  static Future<SavedPlacesCollection> loadForCurrentUser({
    bool forceRefresh = false,
  }) async {
    final session = await _getCurrentSession();
    if (session == null) {
      return const SavedPlacesCollection.empty();
    }

    if (!forceRefresh && _cachedUserId == session.userId) {
      return _cachedPlaces;
    }

    final uri = Uri.parse('${AppConfig.authServiceUrl}/get_saved_places.php').replace(
      queryParameters: {
        'userId': session.userId.toString(),
        if (session.email.isNotEmpty) 'email': session.email,
      },
    );

    final response = await http.get(uri, headers: const {'Accept': 'application/json'});
    final data = await _decodeJsonResponse(response);

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'No se pudieron cargar las direcciones guardadas');
    }

    _cachedPlaces = SavedPlacesCollection.fromResponse(data);
    _cachedUserId = session.userId;

    return _cachedPlaces;
  }

  static Future<SavedUserPlace> savePlace({
    required SavedPlaceType type,
    required SimpleLocation location,
    String? savedName,
    int? placeId,
  }) async {
    final session = await _getCurrentSession();
    if (session == null) {
      throw Exception('No hay una sesion activa para guardar direcciones');
    }

    final response = await http.post(
      Uri.parse('${AppConfig.authServiceUrl}/save_saved_place.php'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'userId': session.userId,
        if (session.email.isNotEmpty) 'email': session.email,
        'place_type': type.apiValue,
        if (placeId != null && placeId > 0) 'place_id': placeId,
        if (savedName != null && savedName.trim().isNotEmpty)
          'saved_name': savedName.trim(),
        'address': location.address,
        'latitude': location.latitude,
        'longitude': location.longitude,
        if (location.municipality?.isNotEmpty == true)
          'city': location.municipality,
        if (location.department?.isNotEmpty == true)
          'state': location.department,
        if (location.country?.isNotEmpty == true) 'country': location.country,
      }),
    );

    final data = await _decodeJsonResponse(response);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'No se pudo guardar la direccion');
    }

    final payload = data['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(data['data'] as Map<String, dynamic>)
        : data;

    final placeData = payload['place'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(payload['place'] as Map<String, dynamic>)
        : null;

    if (placeData == null) {
      throw Exception('El servidor no devolvio la direccion guardada');
    }

    _invalidateCache();
    return SavedUserPlace.fromMap(placeData);
  }

  static Future<void> deletePlace({
    required SavedPlaceType type,
    int? placeId,
  }) async {
    final session = await _getCurrentSession();
    if (session == null) {
      throw Exception('No hay una sesion activa para eliminar direcciones');
    }

    if (type == SavedPlaceType.favorite && (placeId == null || placeId <= 0)) {
      throw Exception('Se requiere el identificador del favorito a eliminar');
    }

    final response = await http.post(
      Uri.parse('${AppConfig.authServiceUrl}/delete_saved_place.php'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'userId': session.userId,
        if (session.email.isNotEmpty) 'email': session.email,
        'place_type': type.apiValue,
        if (placeId != null && placeId > 0) 'place_id': placeId,
      }),
    );

    final data = await _decodeJsonResponse(response);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'No se pudo eliminar la direccion');
    }

    _invalidateCache();
  }
}