import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Servicio de Certificate Pinning para proteger contra ataques MITM.
/// 
/// Verifica que el certificado SSL del servidor coincida
/// con el fingerprint SHA-256 conocido.
/// 
/// INSTRUCCIONES:
/// 1. Obtener el fingerprint del certificado del servidor:
///    echo | openssl s_client -connect tuservidor.com:443 2>/dev/null | openssl x509 -fingerprint -sha256 -noout
/// 2. Colocar el hash resultante en _pinnedCertificateHash
/// 3. Para HTTP plano (sin SSL), el pinning se desactiva automáticamente
class CertificatePinningService {
  // Hash SHA-256 del certificado del servidor de producción
  // NOTA: Actualizar cuando se renueve el certificado SSL
  // Formato: bytes en mayúsculas separados por dos puntos
  // Ejemplo: 'AA:BB:CC:DD:...'
  static const String _pinnedCertificateHash = '';

  /// Crea un HttpClient con certificate pinning activado.
  /// Usar con Dio: dio.httpClientAdapter = IOHttpClientAdapter(createHttpClient: createPinnedClient);
  static HttpClient createPinnedClient() {
    final client = HttpClient();
    
    // Si no hay hash configurado o estamos en desarrollo, no aplicar pinning
    if (_pinnedCertificateHash.isEmpty || kDebugMode) {
      debugPrint('[CertPinning] ⚠️ Pinning DESACTIVADO (desarrollo o hash vacío)');
      return client;
    }

    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      // Calcular el fingerprint SHA-256 del certificado recibido usando cert.der
      final hashBytes = sha256.convert(cert.der).bytes;
      final certHash = hashBytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
      
      final isValid = certHash == _pinnedCertificateHash;
      
      if (!isValid) {
        debugPrint('[CertPinning] 🚨 CERTIFICADO NO COINCIDE');
        debugPrint('[CertPinning] Esperado: ${_pinnedCertificateHash.substring(0, 20)}...');
        debugPrint('[CertPinning] Recibido: ${certHash.substring(0, 20)}...');
      }
      
      // false = rechazar conexión, true = aceptar
      return isValid;
    };

    debugPrint('[CertPinning] ✅ Certificate Pinning ACTIVADO');
    return client;
  }

  /// Verifica si el pinning está configurado
  static bool get isConfigured => _pinnedCertificateHash.isNotEmpty;
}
