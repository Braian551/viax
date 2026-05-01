import 'package:viax/src/global/announcements/announcement_models.dart';
import 'package:viax/src/global/announcements/announcement_templates.dart';

class AppAnnouncementRegistry {
  const AppAnnouncementRegistry._();

  static final List<AppAnnouncement> all = [
    AnnouncementTemplates.notice(
      id: 'aviso-mayo-servidores-2026',
      enabled: true,
      priority: 100,
      versionToken: '2026-05-servidores',
      title: 'Aviso importante de mayo',
      summary:
          'Durante el mes de mayo la app puede presentar errores intermitentes mientras actualizamos tecnologías en los servidores.',
      bulletPoints: const [
        'Podrías notar lentitud, cierres inesperados o validaciones tardías en algunos momentos.',
        'El equipo irá corrigiendo incidencias de forma progresiva durante la migración.',
        'Si algo falla, cierra y abre la app nuevamente antes de volver a intentarlo.',
      ],
      audience: const AppAnnouncementAudience(
        roles: {AppAnnouncementRole.all},
      ),
      displayRule: const AppAnnouncementDisplayRule.cooldown(
        versionToken: '2026-05-servidores',
        remindAfter: Duration(hours: 24),
      ),
    ),
    AnnouncementTemplates.update(
      id: 'actualizacion-base-app',
      enabled: false,
      priority: 90,
      versionToken: '0.1.0+12',
      title: 'Novedades de la app',
      summary:
          'La app ahora puede mostrar anuncios internos al entrar al home según el rol del usuario.',
      highlights: const [
        'Ahora puedes activar avisos, promociones y novedades directamente por código.',
        'Los anuncios recuerdan si ya fueron vistos para no repetirse de forma molesta.',
        'También se admite mantenimiento obligatorio con splash bloqueante por rol o empresa.',
      ],
      audience: const AppAnnouncementAudience(
        roles: {AppAnnouncementRole.all},
      ),
    ),
    AnnouncementTemplates.maintenance(
      id: 'mantenimiento-obligatorio-demo',
      enabled: false,
      priority: 120,
      versionToken: 'mantenimiento-demo-v1',
      title: 'Mantenimiento en curso',
      summary:
          'Activa este splash solo cuando la app deba quedar bloqueada temporalmente.',
      bulletPoints: const [
        'Mientras esté activo no permitirá cerrar el aviso.',
        'Úsalo para cortes reales o mantenimientos obligatorios.',
      ],
      audience: const AppAnnouncementAudience(
        roles: {AppAnnouncementRole.all},
      ),
    ),
    AnnouncementTemplates.promotion(
      id: 'promocion-demo-empresa-especifica',
      enabled: false,
      priority: 55,
      versionToken: 'promo-empresa-demo-v1',
      title: 'Promoción para empresa específica',
      summary:
          'Plantilla de ejemplo para mostrar promociones solo a empresas definidas por código.',
      bulletPoints: const [
        'Cambia el companyIds para apuntar a una empresa real.',
        'Puedes combinarlo con roles y frecuencia controlada.',
      ],
      audience: const AppAnnouncementAudience(
        roles: {AppAnnouncementRole.company},
        companyIds: {999999},
      ),
    ),
  ];

  static List<AppAnnouncement> enabledFor(AppAnnouncementViewer viewer) {
    final items = all
        .where((announcement) =>
            announcement.enabled && announcement.audience.matches(viewer))
        .toList(growable: false);

    items.sort((left, right) => right.priority.compareTo(left.priority));
    return items;
  }
}