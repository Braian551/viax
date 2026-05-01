import 'package:shared_preferences/shared_preferences.dart';
import 'package:viax/src/global/announcements/announcement_models.dart';

class AppAnnouncementStorage {
  static const String _prefix = 'viax_app_announcement';

  Future<bool> shouldShow(AppAnnouncement announcement) async {
    if (announcement.presentation == AppAnnouncementPresentation.blockingSplash) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final storageKey = _buildStorageKey(announcement);
    final lastSeenMillis = prefs.getInt(storageKey);

    if (lastSeenMillis == null) {
      return true;
    }

    switch (announcement.displayRule.mode) {
      case AppAnnouncementRepeatMode.once:
      case AppAnnouncementRepeatMode.perVersion:
        return false;
      case AppAnnouncementRepeatMode.cooldown:
        final remindAfter = announcement.displayRule.remindAfter;
        if (remindAfter == null) {
          return false;
        }

        final lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenMillis);
        return DateTime.now().difference(lastSeen) >= remindAfter;
    }
  }

  Future<void> markSeen(AppAnnouncement announcement) async {
    if (announcement.presentation == AppAnnouncementPresentation.blockingSplash) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _buildStorageKey(announcement),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  String _buildStorageKey(AppAnnouncement announcement) {
    return '$_prefix.${announcement.id}.${announcement.displayRule.versionToken}';
  }
}