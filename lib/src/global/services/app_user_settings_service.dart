import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user_settings.dart';
import 'auth/user_service.dart';

class AppUserSettingsService {
  static const String _settingsPrefix = 'viax_user_settings';

  static AppUserSettings _cachedSettings = const AppUserSettings();
  static String? _cachedKey;

  static String _keyFor({required int userId, required String role}) {
    return '$_settingsPrefix:$role:$userId';
  }

  static Future<AppUserSettings> loadForUser({
    required int userId,
    required String role,
  }) async {
    final key = _keyFor(userId: userId, role: role);
    if (_cachedKey == key) return _cachedSettings;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      _cachedKey = key;
      _cachedSettings = const AppUserSettings();
      return _cachedSettings;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _cachedKey = key;
      _cachedSettings = AppUserSettings.fromMap(decoded);
      return _cachedSettings;
    } catch (_) {
      _cachedKey = key;
      _cachedSettings = const AppUserSettings();
      return _cachedSettings;
    }
  }

  static Future<AppUserSettings> loadForCurrentUser() async {
    final session = await UserService.getSavedSession();
    final rawId = session?['id'];
    final userId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    final role = session?['tipo_usuario']?.toString() ?? 'cliente';

    if (userId == null || userId <= 0) {
      _cachedKey = null;
      _cachedSettings = const AppUserSettings();
      return _cachedSettings;
    }

    return loadForUser(userId: userId, role: role);
  }

  static Future<void> saveForUser({
    required int userId,
    required String role,
    required AppUserSettings settings,
  }) async {
    final key = _keyFor(userId: userId, role: role);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(settings.toMap()));
    _cachedKey = key;
    _cachedSettings = settings;
  }

  static Future<void> saveForCurrentUser(AppUserSettings settings) async {
    final session = await UserService.getSavedSession();
    final rawId = session?['id'];
    final userId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    final role = session?['tipo_usuario']?.toString() ?? 'cliente';

    if (userId == null || userId <= 0) return;

    await saveForUser(userId: userId, role: role, settings: settings);
  }

  static Future<bool> isNotificationsEnabled() async {
    final settings = await loadForCurrentUser();
    return settings.notificationsEnabled;
  }

  static Future<bool> isSoundEnabled() async {
    final settings = await loadForCurrentUser();
    return settings.soundEnabled;
  }

  static Future<bool> isVibrationEnabled() async {
    final settings = await loadForCurrentUser();
    return settings.vibrationEnabled;
  }
}