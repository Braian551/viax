import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:viax/src/core/security/device_fingerprint_service.dart';
import 'package:viax/src/core/security/hmac_signing_service.dart';
import 'package:viax/src/core/security/app_integrity_service.dart';
import 'package:viax/src/core/security/session_key_service.dart';
import 'package:viax/src/global/services/active_trip_navigation_service.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/routes/route_names.dart';

/// Interceptor de seguridad completo para Dio.
/// Inyecta: fingerprint, firma HMAC con session_key dinámica, headers de integridad.
/// Detecta: bypass legal (403), session expirada (401), manipulación de requests.
class DioSecurityInterceptor extends Interceptor {
  
  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final path = options.path;

    // Excepción: No inyectar seguridad a auth o legal (ya que aún no tiene session_key)
    if (_isExemptPath(path)) {
      return super.onRequest(options, handler);
    }

    try {
      // 1. Inyectar Device Fingerprint
      final fingerprint = await DeviceFingerprintService.instance.getFingerprint();
      options.headers['X-Device-Fingerprint'] = fingerprint;

      // 2. Info del dispositivo
      final deviceInfo = await DeviceFingerprintService.instance.getDeviceInfo();
      options.headers['X-Device-Model'] = deviceInfo['model'] ?? 'unknown';
      options.headers['X-Device-Platform'] = deviceInfo['platform'] ?? 'unknown';

      // 3. Obtener session_key dinámica
      final session = await UserService.getSavedSession();
      String? sessionKey;
      int userId = 0;
      String deviceId = deviceInfo['device_id'] ?? 'unknown';

      if (session != null && session['id'] != null) {
        userId = int.tryParse(session['id'].toString()) ?? 0;
        
        if (userId > 0) {
          sessionKey = await SessionKeyService.instance.getSessionKey(
            userId: userId,
            deviceId: deviceId,
          );
          
          // Inyectar session_key como header
          if (sessionKey != null) {
            options.headers['X-Session-Key'] = sessionKey;
          }
        }
      }

      // 4. Firmar request con HMAC usando session_key
      final body = options.data != null ? jsonEncode(options.data) : '';
      final signatureHeaders = HmacSigningService.signRequest(
        body: body,
        path: path,
        userId: userId,
        deviceId: deviceId,
        sessionKey: sessionKey,
      );
      options.headers.addAll(signatureHeaders);
      options.headers['X-Device-Id'] = deviceId; // Siempre enviarlo para que el backend pueda usarlo

      // 5. Integridad del dispositivo
      final integrity = await AppIntegrityService.instance.checkIntegrity();
      options.headers['X-Integrity-Score'] = integrity.riskScore.toString();
      if (integrity.isHighRisk) {
        options.headers['X-Integrity-Warning'] = 'HIGH_RISK';
      }
    } catch (e) {
      debugPrint('[DioSecurity] Error inyectando seguridad: $e');
    }

    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    final data = err.response?.data;

    if (statusCode == 401 && data is Map) {
      // Session key expirada — renovar automáticamente
      debugPrint('[DioSecurity] 🔄 Session key expirada. Renovando...');
      SessionKeyService.instance.invalidate();
      // El próximo request intentará renovar automáticamente
    }

    if (statusCode == 403 && data is Map) {
      if (data['requiresUpdate'] == true || 
          data['error'] == 'LEGAL_BYPASS_DETECTED' ||
          data['error'] == 'SECURITY_VIOLATION') {
        debugPrint('[DioSecurity] 🚨 VIOLACIÓN DETECTADA. Redirigiendo.');
        _forceRedirectToLegal();
      }
    }

    super.onError(err, handler);
  }

  bool _isExemptPath(String path) {
    const exemptPaths = ['/auth/', '/legal/', 'current_version', 'health.php', 'session_key'];
    return exemptPaths.any((exempt) => path.contains(exempt));
  }

  void _forceRedirectToLegal() {
    if (ActiveTripNavigationService.navigatorKey.currentState != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final session = await UserService.getSavedSession();
        final role = (session?['tipo_usuario'] ?? 'cliente').toString().toLowerCase();
        final userId = int.tryParse((session?['id'] ?? 0).toString()) ?? 0;

        ActiveTripNavigationService.navigatorKey.currentState!.pushNamed(
          RouteNames.legalAcceptance,
          arguments: {
            'role': role,
            if (userId > 0) 'userId': userId,
            'returnResultOnAccept': true,
          },
        );
      });
    }
  }
}
