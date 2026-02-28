import 'package:shared_preferences/shared_preferences.dart';

/// Gestiona preferencias y estado de sesión de segundo plano del conductor.
///
/// Permite:
/// - Guardar si el conductor habilitó trabajo en segundo plano.
/// - Recordar si hubo una sesión online sin cierre limpio.
/// - Forzar recuperación segura a offline en el próximo arranque.
class ConductorBackgroundSessionService {
  static const String _backgroundEnabledPrefix =
      'conductor_background_enabled_';
  static const String _backgroundPromptedPrefix =
      'conductor_background_prompted_';
  static const String _onlineSessionPrefix = 'conductor_online_session_';

  static String _key(String prefix, int conductorId) => '$prefix$conductorId';

  static Future<bool> isBackgroundModeEnabled(int conductorId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(_backgroundEnabledPrefix, conductorId)) ?? false;
  }

  static Future<void> setBackgroundModeEnabled(
    int conductorId,
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(_backgroundEnabledPrefix, conductorId), enabled);
  }

  static Future<bool> wasBackgroundPrompted(int conductorId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(_backgroundPromptedPrefix, conductorId)) ?? false;
  }

  static Future<void> markBackgroundPrompted(int conductorId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(_backgroundPromptedPrefix, conductorId), true);
  }

  /// Marca estado online de la sesión actual.
  ///
  /// Si la app se termina abruptamente estando `true`, en el siguiente arranque
  /// se debe forzar al backend a `offline`.
  static Future<void> setOnlineSession(int conductorId, bool isOnline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(_onlineSessionPrefix, conductorId), isOnline);
  }

  /// Consume el flag de sesión online no cerrada limpiamente.
  ///
  /// Retorna `true` cuando detecta una sesión anterior online que requiere
  /// forzar desconexión en backend.
  static Future<bool> consumeUnexpectedOnlineSession(int conductorId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(_onlineSessionPrefix, conductorId);
    final wasOnline = prefs.getBool(key) ?? false;
    if (wasOnline) {
      await prefs.setBool(key, false);
    }
    return wasOnline;
  }
}
