import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Resultado de la verificación de integridad del dispositivo
class IntegrityCheckResult {
  final bool isRooted;
  final bool isEmulator;
  final bool isDebugMode;
  final int riskScore; // 0-100: 0=seguro, 100=altísimo riesgo

  const IntegrityCheckResult({
    required this.isRooted,
    required this.isEmulator,
    required this.isDebugMode,
    required this.riskScore,
  });

  bool get isSafe => riskScore < 30;
  bool get isHighRisk => riskScore >= 60;
}

/// Servicio de detección de root, emulador y depuración.
/// Detecta dispositivos comprometidos o entornos de prueba usados para bypass.
class AppIntegrityService {
  static AppIntegrityService? _instance;
  static AppIntegrityService get instance => _instance ??= AppIntegrityService._();
  AppIntegrityService._();

  IntegrityCheckResult? _cachedResult;

  /// Ejecuta todas las verificaciones de integridad
  Future<IntegrityCheckResult> checkIntegrity() async {
    if (_cachedResult != null) return _cachedResult!;

    int riskScore = 0;
    bool isRooted = false;
    bool isEmulator = false;
    final bool isDebug = kDebugMode;

    if (isDebug) riskScore += 10;

    try {
      if (Platform.isAndroid) {
        final result = await _checkAndroid();
        isRooted = result['rooted'] ?? false;
        isEmulator = result['emulator'] ?? false;

        if (isRooted) riskScore += 40;
        if (isEmulator) riskScore += 30;
      } else if (Platform.isIOS) {
        final result = await _checkIOS();
        isRooted = result['jailbroken'] ?? false;
        isEmulator = result['simulator'] ?? false;

        if (isRooted) riskScore += 50;
        if (isEmulator) riskScore += 20;
      }
    } catch (e) {
      debugPrint('[AppIntegrity] Error durante verificación: $e');
      riskScore += 15; // Sospechoso si falla la verificación
    }

    _cachedResult = IntegrityCheckResult(
      isRooted: isRooted,
      isEmulator: isEmulator,
      isDebugMode: isDebug,
      riskScore: riskScore.clamp(0, 100),
    );

    debugPrint('[AppIntegrity] Resultado: risk=$riskScore, root=$isRooted, emulator=$isEmulator, debug=$isDebug');
    return _cachedResult!;
  }

  /// Verificaciones específicas de Android
  Future<Map<String, bool>> _checkAndroid() async {
    final result = <String, bool>{};
    final deviceInfo = DeviceInfoPlugin();
    final android = await deviceInfo.androidInfo;

    // Detección de emulador: señales comunes
    result['emulator'] = !android.isPhysicalDevice ||
        android.model.toLowerCase().contains('sdk') ||
        android.model.toLowerCase().contains('emulator') ||
        android.hardware.toLowerCase().contains('goldfish') ||
        android.hardware.toLowerCase().contains('ranchu') ||
        android.fingerprint.contains('generic') ||
        android.manufacturer.toLowerCase().contains('genymotion');

    // Detección de root: verificar binarios comunes
    result['rooted'] = await _checkRootFiles();

    return result;
  }

  /// Verificaciones específicas de iOS
  Future<Map<String, bool>> _checkIOS() async {
    final result = <String, bool>{};
    final deviceInfo = DeviceInfoPlugin();
    final ios = await deviceInfo.iosInfo;

    result['simulator'] = !ios.isPhysicalDevice;

    // Detección de jailbreak: verificar archivos comunes
    result['jailbroken'] = await _checkJailbreakFiles();

    return result;
  }

  /// Verifica la existencia de binarios típicos de root en Android
  Future<bool> _checkRootFiles() async {
    // Rutas comunes donde se encuentran binarios de superusuario
    const rootPaths = [
      '/system/app/Superuser.apk',
      '/sbin/su',
      '/system/bin/su',
      '/system/xbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/data/local/su',
      '/su/bin/su',
      '/data/adb/magisk',
    ];

    for (final path in rootPaths) {
      try {
        if (await File(path).exists()) {
          debugPrint('[AppIntegrity] ROOT DETECTADO: $path');
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Verifica archivos comunes de jailbreak en iOS
  Future<bool> _checkJailbreakFiles() async {
    const jailbreakPaths = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt/',
      '/usr/bin/ssh',
      '/private/var/stash',
    ];

    for (final path in jailbreakPaths) {
      try {
        if (await File(path).exists()) {
          debugPrint('[AppIntegrity] JAILBREAK DETECTADO: $path');
          return true;
        }
      } catch (_) {}
    }
    return false;
  }
}
