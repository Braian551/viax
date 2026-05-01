import 'package:flutter/material.dart';
import 'package:viax/src/global/announcements/announcement_models.dart';

class AnnouncementTemplates {
  const AnnouncementTemplates._();

  static AppAnnouncement update({
    required String id,
    required bool enabled,
    required String versionToken,
    required String title,
    required String summary,
    List<String> highlights = const [],
    AppAnnouncementAudience audience = const AppAnnouncementAudience(),
    int priority = 80,
  }) {
    final filteredHighlights =
        highlights.where((item) => item.trim().isNotEmpty).toList(growable: false);

    return AppAnnouncement(
      id: id,
      enabled: enabled,
      priority: priority,
      type: AppAnnouncementType.update,
      presentation: AppAnnouncementPresentation.onboarding,
      dismissible: true,
      badge: 'Actualización',
      primaryButtonLabel: 'Entendido',
      secondaryButtonLabel: 'Cerrar',
      audience: audience,
      displayRule: AppAnnouncementDisplayRule.perVersion(
        versionToken: versionToken,
      ),
      pages: [
        AppAnnouncementPage(
          title: title,
          message: summary,
          icon: Icons.system_update_alt_rounded,
          bulletPoints: filteredHighlights.take(3).toList(growable: false),
          footnote:
              'Mantén este resumen corto y cambia el versionToken cuando quieras volver a mostrarlo.',
        ),
        if (filteredHighlights.length > 3)
          AppAnnouncementPage(
            title: 'Cambios principales',
            message: 'Resumen corto de lo más importante de esta versión.',
            icon: Icons.checklist_rounded,
            bulletPoints: filteredHighlights.skip(3).toList(growable: false),
          ),
      ],
    );
  }

  static AppAnnouncement maintenance({
    required String id,
    required bool enabled,
    required String versionToken,
    required String title,
    required String summary,
    List<String> bulletPoints = const [],
    AppAnnouncementAudience audience = const AppAnnouncementAudience(),
    int priority = 120,
  }) {
    return AppAnnouncement(
      id: id,
      enabled: enabled,
      priority: priority,
      type: AppAnnouncementType.maintenance,
      presentation: AppAnnouncementPresentation.blockingSplash,
      dismissible: false,
      badge: 'Mantenimiento',
      audience: audience,
      displayRule: AppAnnouncementDisplayRule.once(versionToken: versionToken),
      pages: [
        AppAnnouncementPage(
          title: title,
          message: summary,
          icon: Icons.construction_rounded,
          bulletPoints: bulletPoints,
          footnote: 'Esta pantalla es obligatoria mientras el aviso esté activo.',
        ),
      ],
    );
  }

  static AppAnnouncement notice({
    required String id,
    required bool enabled,
    required String versionToken,
    required String title,
    required String summary,
    List<String> bulletPoints = const [],
    AppAnnouncementAudience audience = const AppAnnouncementAudience(),
    AppAnnouncementDisplayRule? displayRule,
    int priority = 70,
  }) {
    return AppAnnouncement(
      id: id,
      enabled: enabled,
      priority: priority,
      type: AppAnnouncementType.notice,
      presentation: AppAnnouncementPresentation.modal,
      dismissible: true,
      badge: 'Aviso',
      primaryButtonLabel: 'Entendido',
      secondaryButtonLabel: 'Cerrar',
      audience: audience,
      displayRule:
          displayRule ??
          AppAnnouncementDisplayRule.cooldown(
            versionToken: versionToken,
            remindAfter: const Duration(hours: 24),
          ),
      pages: [
        AppAnnouncementPage(
          title: title,
          message: summary,
          icon: Icons.campaign_rounded,
          bulletPoints: bulletPoints,
        ),
      ],
    );
  }

  static AppAnnouncement promotion({
    required String id,
    required bool enabled,
    required String versionToken,
    required String title,
    required String summary,
    List<String> bulletPoints = const [],
    AppAnnouncementAudience audience = const AppAnnouncementAudience(),
    AppAnnouncementDisplayRule? displayRule,
    int priority = 60,
  }) {
    return AppAnnouncement(
      id: id,
      enabled: enabled,
      priority: priority,
      type: AppAnnouncementType.promotion,
      presentation: AppAnnouncementPresentation.onboarding,
      dismissible: true,
      badge: 'Promoción',
      primaryButtonLabel: 'Continuar',
      secondaryButtonLabel: 'Cerrar',
      audience: audience,
      displayRule:
          displayRule ??
          AppAnnouncementDisplayRule.cooldown(
            versionToken: versionToken,
            remindAfter: const Duration(days: 3),
          ),
      pages: [
        AppAnnouncementPage(
          title: title,
          message: summary,
          icon: Icons.local_offer_rounded,
          bulletPoints: bulletPoints.take(3).toList(growable: false),
        ),
        if (bulletPoints.length > 3)
          AppAnnouncementPage(
            title: 'Detalles de la promoción',
            message: 'Información complementaria para el usuario.',
            icon: Icons.card_giftcard_rounded,
            bulletPoints: bulletPoints.skip(3).toList(growable: false),
          ),
      ],
    );
  }
}