import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para manejar notificaciones de aprobaciÃ³n del conductor
class ApprovalNotificationService {
  static const String _keyPrefix = 'conductor_approval_shown_';
  static const String _lastStatusKey = 'conductor_last_status_';
  static const String _lastCheckKey = 'conductor_last_check_';

  /// Verifica si debe mostrar la alerta de aprobaciÃ³n
  /// Retorna true solo cuando el conductor acaba de ser aprobado (cambio de estado)
  static Future<bool> shouldShowApprovalAlert(
    int conductorId,
    String currentStatus,
    bool isApproved,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Claves Ãºnicas por conductor
      final shownKey = '$_keyPrefix$conductorId';
      final statusKey = '$_lastStatusKey$conductorId';
      final checkKey = '$_lastCheckKey$conductorId';

      // Verificar si ya se mostrÃ³ la alerta de aprobaciÃ³n
      final hasShownAlert = prefs.getBool(shownKey) ?? false;

      // Obtener el Ãºltimo estado guardado
      final lastStatus = prefs.getString(statusKey);
      
      // Obtener Ãºltima vez que se verificÃ³
      final lastCheck = prefs.getInt(checkKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      print('ðŸ”” Verificando alerta de aprobaciÃ³n:');
      print('   - Conductor ID: $conductorId');
      print('   - Estado actual: $currentStatus');
      print('   - Aprobado: $isApproved');
      print('   - Ãšltimo estado guardado: ${lastStatus ?? "ninguno"}');
      print('   - Ya se mostrÃ³ alerta: $hasShownAlert');
      print('   - Ãšltima verificaciÃ³n: ${DateTime.fromMillisecondsSinceEpoch(lastCheck)}');

      // Actualizar Ãºltima verificaciÃ³n
      await prefs.setInt(checkKey, now);

      // Si ya se mostrÃ³ la alerta, nunca volver a mostrarla
      if (hasShownAlert) {
        print('   âŒ Alerta ya fue mostrada anteriormente - NO MOSTRAR');
        // Actualizar el estado para la prÃ³xima verificaciÃ³n
        await prefs.setString(statusKey, currentStatus);
        return false;
      }

      // Caso 1: Primera vez detectando estado aprobado
      if (lastStatus == null && (currentStatus == 'aprobado' || isApproved)) {
        print('   âœ… Primera detecciÃ³n - conductor aprobado - MOSTRAR ALERTA');
        await prefs.setString(statusKey, currentStatus);
        return true;
      }

      // Caso 2: Cambio de estado a aprobado
      if (lastStatus != null && 
          lastStatus != 'aprobado' && 
          (currentStatus == 'aprobado' || isApproved)) {
        print('   ✅ Cambio de estado detectado ($lastStatus → $currentStatus) - MOSTRAR ALERTA');
        await prefs.setString(statusKey, currentStatus);
        return true;
      }

      // En cualquier otro caso, no mostrar
      print('   ❌ No se cumple condición para mostrar alerta');
      await prefs.setString(statusKey, currentStatus);
      return false;
      
    } catch (e) {
      print('Error en shouldShowApprovalAlert: $e');
      return false;
    }
  }

  /// Marca que se mostró la alerta de aprobación
  /// Una vez marcada, la alerta nunca se volverá a mostrar para este conductor
  static Future<void> markApprovalAlertAsShown(int conductorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shownKey = '$_keyPrefix$conductorId';
      await prefs.setBool(shownKey, true);
      print('✅ Alerta de aprobación marcada como mostrada para conductor $conductorId');
    } catch (e) {
      print('Error en markApprovalAlertAsShown: $e');
    }
  }

  /// Resetea el estado (útil para testing o casos especiales)
  static Future<void> resetApprovalStatus(int conductorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shownKey = '$_keyPrefix$conductorId';
      final statusKey = '$_lastStatusKey$conductorId';
      final checkKey = '$_lastCheckKey$conductorId';
      
      await prefs.remove(shownKey);
      await prefs.remove(statusKey);
      await prefs.remove(checkKey);
      
      print('ðŸ”„ Estado de aprobaciÃ³n reseteado para conductor $conductorId');
    } catch (e) {
      print('Error en resetApprovalStatus: $e');
    }
  }
}
