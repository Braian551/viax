import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/core/security/device_fingerprint_service.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Servicio de Session Keys dinámicas.
/// Obtiene una clave temporal (5 min) del backend para firmar requests con HMAC.
/// La clave NUNCA se persiste en disco — solo vive en memoria.
class SessionKeyService {
  static SessionKeyService? _instance;
  static SessionKeyService get instance => _instance ??= SessionKeyService._();
  SessionKeyService._();

  String? _sessionKey;
  int? _expiresAt; // Unix timestamp en segundos
  bool _isRefreshing = false;

  /// Retorna la session_key actual. Si expiró o no existe, la renueva automáticamente.
  Future<String?> getSessionKey({required int userId, required String deviceId}) async {
    // Si existe y no ha expirado, retornar
    if (_sessionKey != null && _expiresAt != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // Renovar 30 segundos antes de que expire para evitar errores de borde
      if (now < (_expiresAt! - 30)) {
        return _sessionKey;
      }
    }

    // Renovar
    return await refreshSessionKey(userId: userId, deviceId: deviceId);
  }

  /// Solicita una nueva session_key al backend.
  Future<String?> refreshSessionKey({required int userId, required String deviceId}) async {
    // Evitar múltiples renovaciones concurrentes
    if (_isRefreshing) {
      // Esperar a que termine la renovación actual
      await Future.delayed(const Duration(milliseconds: 500));
      return _sessionKey;
    }

    _isRefreshing = true;

    try {
      final fingerprint = await DeviceFingerprintService.instance.getFingerprint();

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/auth/session_key.php'),
        headers: {
          'Content-Type': 'application/json',
          'X-Device-Fingerprint': fingerprint,
        },
        body: jsonEncode({
          'user_id': userId,
          'device_id': deviceId,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _sessionKey = data['session_key'];
          _expiresAt = data['expires_at'];
          debugPrint('[SessionKey] ✅ Renovada. TTL: ${data['ttl_seconds']}s');
          return _sessionKey;
        }
      }

      debugPrint('[SessionKey] ❌ Error al renovar: ${response.statusCode}');
      return _sessionKey; // Retornar la última válida si falló
    } catch (e) {
      debugPrint('[SessionKey] ❌ Error de red: $e');
      return _sessionKey;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Invalida la session_key actual (ej: logout)
  void invalidate() {
    _sessionKey = null;
    _expiresAt = null;
    debugPrint('[SessionKey] Invalidada (logout)');
  }

  /// Indica si hay una session_key activa
  bool get hasValidKey {
    if (_sessionKey == null || _expiresAt == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now < (_expiresAt! - 30);
  }
}
