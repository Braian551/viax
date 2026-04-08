import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';

enum LegalStatus { idle, checking, accepted, notAccepted, errorFallback }

class LegalProvider extends ChangeNotifier {
  static const String _cacheKeyPrefix = 'accepted_legal_version';
  
  LegalStatus _status = LegalStatus.idle;
  String? _currentRequiredVersion;
  String? _lastError;
  bool _initialized = false;

  LegalStatus get status => _status;
  String? get currentRequiredVersion => _currentRequiredVersion;
  String? get lastError => _lastError;
  bool get isAccepted => _status == LegalStatus.accepted;
  bool get isChecking => _status == LegalStatus.checking;
  bool get initialized => _initialized;

  String _cacheKeyFor({required String role, required int userId}) {
    return '$_cacheKeyPrefix-${role.toLowerCase()}-$userId';
  }

  /// Inicializa el estado desde cache local para evitar parpadeos (flickers)
  Future<void> init() async {
    if (_initialized) return;
    // La aceptación depende del usuario y rol, por lo que no se puede
    // inferir desde un cache global en init sin sesión activa.
    _initialized = true;
    notifyListeners();
  }

  /// Verifica la versión contra el backend
  Future<LegalStatus> checkLegalStatus({required String role, required int userId}) async {
    _status = LegalStatus.checking;
    _lastError = null;
    notifyListeners();

    try {
      final response = await http
          .get(Uri.parse('${AppConfig.baseUrl}/legal/current_version.php?role=$role'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _currentRequiredVersion = data['current_version'];
          
          final prefs = await SharedPreferences.getInstance();
          final localVersion = prefs.getString(_cacheKeyFor(role: role, userId: userId));

          if (localVersion == _currentRequiredVersion && localVersion != null) {
            _status = LegalStatus.accepted;
          } else {
            _status = LegalStatus.notAccepted;
          }
        } else {
          _status = LegalStatus.notAccepted;
          _lastError = data['message']?.toString();
        }
      } else {
        _status = LegalStatus.notAccepted;
        _lastError = 'No se pudo validar el estado legal (HTTP ${response.statusCode}).';
      }
    } catch (e) {
      debugPrint('[LegalProvider] Network Error: $e');
      _status = LegalStatus.notAccepted;
      _lastError = 'Error de red al validar estado legal.';
    }

    notifyListeners();
    return _status;
  }

  /// Obtiene la versión legal vigente por rol sin cambiar el estado del provider.
  Future<String?> fetchCurrentVersion({required String role}) async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.baseUrl}/legal/current_version.php?role=$role'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final version = data['current_version']?.toString();
        if (version != null && version.isNotEmpty) {
          _currentRequiredVersion = version;
          return version;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[LegalProvider] Version Error: $e');
      return null;
    }
  }

  /// Registra la aceptación en Backend y Local
  Future<bool> acceptTerms({
    required int userId,
    required String role,
    required String deviceId,
    required String version,
  }) async {
    _status = LegalStatus.checking;
    _lastError = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/legal/accept.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'role': role,
          'version': version,
          'device_id': deviceId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKeyFor(role: role, userId: userId), version);
          
          _status = LegalStatus.accepted;
          notifyListeners();
          return true;
        }
        _lastError = data['message']?.toString() ?? 'No se pudo registrar la aceptación.';
      } else {
        try {
          final data = jsonDecode(response.body);
          _lastError = data['message']?.toString();
        } catch (_) {
          _lastError = 'No se pudo registrar la aceptación (HTTP ${response.statusCode}).';
        }
      }
    } catch (e) {
      debugPrint('[LegalProvider] Accept Error: $e');
      _lastError = 'Error de red al registrar aceptación.';
    }

    _status = LegalStatus.notAccepted;
    notifyListeners();
    return false;
  }
  
  /// Permite resetear el estado (ej: logout)
  void reset() {
    _status = LegalStatus.idle;
    _lastError = null;
    _initialized = false;
    notifyListeners();
  }
}
