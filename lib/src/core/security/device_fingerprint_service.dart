import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de huella digital del dispositivo.
/// Genera un hash único combinando propiedades de hardware y software
/// para detectar granjas de dispositivos y cuentas múltiples.
class DeviceFingerprintService {
  static DeviceFingerprintService? _instance;
  static DeviceFingerprintService get instance => _instance ??= DeviceFingerprintService._();
  DeviceFingerprintService._();

  static const String _cacheKey = 'device_fingerprint_v1';
  // El salt real está en el backend (.env FINGERPRINT_SALT).
  // En el cliente usamos un valor no-secreto; la seguridad real
  // descansa en la session_key dinámica y el HMAC verificado servidor-lado.
  static const String _clientSalt = 'viax_client_fp_v1';

  String? _cachedFingerprint;
  Map<String, String>? _rawDeviceInfo;

  /// Obtiene el fingerprint cacheado o lo genera
  Future<String> getFingerprint() async {
    if (_cachedFingerprint != null) return _cachedFingerprint!;

    // Intentar leer desde SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_cacheKey);
    if (stored != null) {
      _cachedFingerprint = stored;
      return stored;
    }

    // Generar nuevo fingerprint
    final fingerprint = await _generateFingerprint();
    _cachedFingerprint = fingerprint;
    await prefs.setString(_cacheKey, fingerprint);
    return fingerprint;
  }

  /// Retorna información cruda del dispositivo para incluir en headers
  Future<Map<String, String>> getDeviceInfo() async {
    if (_rawDeviceInfo != null) return _rawDeviceInfo!;
    _rawDeviceInfo = await _collectDeviceInfo();
    return _rawDeviceInfo!;
  }

  /// Genera el fingerprint combinando múltiples señales del dispositivo
  Future<String> _generateFingerprint() async {
    final info = await _collectDeviceInfo();
    
    // Construir cadena base para el hash
    final base = [
      info['device_id'] ?? '',
      info['model'] ?? '',
      info['manufacturer'] ?? '',
      info['os_version'] ?? '',
      info['sdk_version'] ?? '',
      info['screen_density'] ?? '',
      info['timezone'] ?? '',
      _clientSalt,
    ].join('|');

    final bytes = utf8.encode(base);
    final hash = sha256.convert(bytes);
    
    debugPrint('[DeviceFingerprint] Fingerprint generado: ${hash.toString().substring(0, 12)}...');
    return hash.toString();
  }

  /// Recolecta información del dispositivo de forma segura
  Future<Map<String, String>> _collectDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final result = <String, String>{};

    try {
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        result['device_id'] = android.id;
        result['model'] = android.model;
        result['manufacturer'] = android.manufacturer;
        result['os_version'] = android.version.release;
        result['sdk_version'] = android.version.sdkInt.toString();
        result['screen_density'] = 'android_default';
        result['is_physical'] = android.isPhysicalDevice.toString();
        result['hardware'] = android.hardware;
        result['fingerprint_android'] = android.fingerprint;
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        result['device_id'] = ios.identifierForVendor ?? 'ios_unknown';
        result['model'] = ios.utsname.machine;
        result['manufacturer'] = 'Apple';
        result['os_version'] = ios.systemVersion;
        result['sdk_version'] = ios.systemVersion;
        result['screen_density'] = 'ios_default';
        result['is_physical'] = ios.isPhysicalDevice.toString();
        result['hardware'] = ios.utsname.machine;
        result['fingerprint_android'] = '';
      }
    } catch (e) {
      debugPrint('[DeviceFingerprint] Error recolectando info: $e');
    }

    // Señales adicionales
    result['timezone'] = DateTime.now().timeZoneName;
    result['platform'] = Platform.operatingSystem;

    return result;
  }
}
