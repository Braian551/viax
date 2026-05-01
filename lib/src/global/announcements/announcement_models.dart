import 'package:flutter/material.dart';

enum AppAnnouncementType { update, maintenance, notice, promotion }

enum AppAnnouncementPresentation { onboarding, modal, blockingSplash }

enum AppAnnouncementRole { all, client, conductor, admin, company, support }

enum AppAnnouncementRepeatMode { once, perVersion, cooldown }

class AppAnnouncementViewer {
  final AppAnnouncementRole role;
  final int? companyId;

  const AppAnnouncementViewer({required this.role, this.companyId});

  factory AppAnnouncementViewer.fromUserType(
    String userType, {
    int? companyId,
  }) {
    return AppAnnouncementViewer(
      role: normalizeRole(userType),
      companyId: companyId,
    );
  }

  static AppAnnouncementRole normalizeRole(String userType) {
    switch (userType.trim().toLowerCase()) {
      case 'cliente':
      case 'user':
      case 'usuario':
        return AppAnnouncementRole.client;
      case 'conductor':
        return AppAnnouncementRole.conductor;
      case 'admin':
      case 'administrador':
        return AppAnnouncementRole.admin;
      case 'empresa':
        return AppAnnouncementRole.company;
      case 'soporte_tecnico':
      case 'support':
        return AppAnnouncementRole.support;
      default:
        return AppAnnouncementRole.client;
    }
  }
}

class AppAnnouncementAudience {
  final Set<AppAnnouncementRole> roles;
  final Set<int> companyIds;

  const AppAnnouncementAudience({
    this.roles = const {AppAnnouncementRole.all},
    this.companyIds = const {},
  });

  bool matches(AppAnnouncementViewer viewer) {
    final roleMatches =
        roles.contains(AppAnnouncementRole.all) || roles.contains(viewer.role);

    if (!roleMatches) {
      return false;
    }

    if (companyIds.isEmpty) {
      return true;
    }

    return viewer.role == AppAnnouncementRole.company &&
        viewer.companyId != null &&
        companyIds.contains(viewer.companyId);
  }
}

class AppAnnouncementDisplayRule {
  final AppAnnouncementRepeatMode mode;
  final String versionToken;
  final Duration? remindAfter;

  const AppAnnouncementDisplayRule._({
    required this.mode,
    required this.versionToken,
    this.remindAfter,
  });

  const AppAnnouncementDisplayRule.once({required String versionToken})
    : this._(
        mode: AppAnnouncementRepeatMode.once,
        versionToken: versionToken,
      );

  const AppAnnouncementDisplayRule.perVersion({required String versionToken})
    : this._(
        mode: AppAnnouncementRepeatMode.perVersion,
        versionToken: versionToken,
      );

  const AppAnnouncementDisplayRule.cooldown({
    required String versionToken,
    required Duration remindAfter,
  }) : this._(
         mode: AppAnnouncementRepeatMode.cooldown,
         versionToken: versionToken,
         remindAfter: remindAfter,
       );
}

class AppAnnouncementPage {
  final String title;
  final String message;
  final IconData icon;
  final List<String> bulletPoints;
  final String? footnote;

  const AppAnnouncementPage({
    required this.title,
    required this.message,
    required this.icon,
    this.bulletPoints = const [],
    this.footnote,
  });
}

class AppAnnouncement {
  final String id;
  final bool enabled;
  final int priority;
  final AppAnnouncementType type;
  final AppAnnouncementPresentation presentation;
  final bool dismissible;
  final String? badge;
  final String? primaryButtonLabel;
  final String? secondaryButtonLabel;
  final AppAnnouncementAudience audience;
  final AppAnnouncementDisplayRule displayRule;
  final List<AppAnnouncementPage> pages;

  const AppAnnouncement({
    required this.id,
    required this.enabled,
    required this.priority,
    required this.type,
    required this.presentation,
    required this.dismissible,
    required this.audience,
    required this.displayRule,
    required this.pages,
    this.badge,
    this.primaryButtonLabel,
    this.secondaryButtonLabel,
  });

  AppAnnouncementPage get firstPage => pages.first;
}