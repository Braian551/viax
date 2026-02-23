class AppUserSettings {
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool biometricEnabled;
  final String language;

  const AppUserSettings({
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.biometricEnabled = false,
    this.language = 'es',
  });

  AppUserSettings copyWith({
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? biometricEnabled,
    String? language,
  }) {
    return AppUserSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      language: language ?? this.language,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notifications_enabled': notificationsEnabled,
      'sound_enabled': soundEnabled,
      'vibration_enabled': vibrationEnabled,
      'biometric_enabled': biometricEnabled,
      'language': language,
    };
  }

  factory AppUserSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AppUserSettings();

    bool asBool(dynamic value, bool fallback) {
      if (value == null) return fallback;
      if (value is bool) return value;
      if (value is num) return value == 1;
      final stringValue = value.toString().trim().toLowerCase();
      if (stringValue == 'true' || stringValue == '1') return true;
      if (stringValue == 'false' || stringValue == '0') return false;
      return fallback;
    }

    return AppUserSettings(
      notificationsEnabled: asBool(map['notifications_enabled'], true),
      soundEnabled: asBool(map['sound_enabled'], true),
      vibrationEnabled: asBool(map['vibration_enabled'], true),
      biometricEnabled: asBool(map['biometric_enabled'], false),
      language: map['language']?.toString().trim().isNotEmpty == true
          ? map['language'].toString().trim()
          : 'es',
    );
  }
}