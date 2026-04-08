import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Servicio de firma HMAC para proteger requests contra manipulación (MITM).
/// Ahora usa session_key dinámica del backend en lugar de secreto hardcodeado.
class HmacSigningService {
  /// Genera los headers de seguridad usando una clave dinámica (session_key).
  /// Si no hay session_key disponible, genera headers vacíos (el backend decidirá según modo de enforcement).
  static Map<String, String> signRequest({
    required String body,
    required String path,
    required int userId,
    required String deviceId,
    String? sessionKey,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = _generateNonce();

    // Si no hay session_key, enviar headers de timestamp/nonce sin firma
    // El backend en modo "monitor" los aceptará sin bloquear
    if (sessionKey == null || sessionKey.isEmpty) {
      return {
        'X-Timestamp': timestamp,
        'X-Nonce': nonce,
        'X-Signature': '', // Vacío — backend lo detectará según modo
        'X-Device-Id': deviceId,
      };
    }
    
    // Construir cadena a firmar: path + body + timestamp + nonce + userId + deviceId
    final dataToSign = '$path|$body|$timestamp|$nonce|$userId|$deviceId';
    
    // HMAC-SHA256 con session_key dinámica
    final key = utf8.encode(sessionKey);
    final data = utf8.encode(dataToSign);
    final hmac = Hmac(sha256, key);
    final signature = hmac.convert(data).toString();

    return {
      'X-Timestamp': timestamp,
      'X-Nonce': nonce,
      'X-Signature': signature,
    };
  }

  /// Genera un nonce único para evitar replay attacks
  static String _generateNonce() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = now.hashCode ^ DateTime.now().millisecondsSinceEpoch;
    final bytes = utf8.encode('$now|$random|${DateTime.now().toIso8601String()}');
    return sha256.convert(bytes).toString().substring(0, 16);
  }
}
