import 'package:url_launcher/url_launcher.dart';

enum LegalRole { cliente, conductor, empresa, administrador, servidor }

class LegalLinksService {
  static const String _websiteBaseUrl = 'https://viaxcol.online';

  static LegalRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'conductor':
        return LegalRole.conductor;
      case 'empresa':
        return LegalRole.empresa;
      case 'administrador':
      case 'admin':
        return LegalRole.administrador;
      case 'soporte_tecnico':
      case 'soporte':
      case 'servidor':
        return LegalRole.servidor;
      case 'cliente':
      default:
        return LegalRole.cliente;
    }
  }

  static String _roleParam(LegalRole role) {
    switch (role) {
      case LegalRole.cliente:
        return 'cliente';
      case LegalRole.conductor:
        return 'conductor';
      case LegalRole.empresa:
        return 'empresa';
      case LegalRole.administrador:
        return 'administrador';
      case LegalRole.servidor:
        return 'servidor';
    }
  }

  static Uri _legalUri({
    required LegalRole role,
    required String doc,
  }) {
    return Uri.parse(_websiteBaseUrl).replace(
      path: '/legal',
      queryParameters: {
        'role': _roleParam(role),
        'doc': doc,
      },
    );
  }

  static Uri termsUri({required LegalRole role}) {
    return _legalUri(role: role, doc: 'terms');
  }

  static Uri privacyUri({required LegalRole role}) {
    return _legalUri(role: role, doc: 'privacy');
  }

  static Uri contentJsonUri() {
    return Uri.parse('$_websiteBaseUrl/legal_content.json');
  }

  static Future<bool> openTerms({required LegalRole role}) async {
    final uri = termsUri(role: role);
    try {
      // Intentar apertura directa; canLaunchUrl puede fallar en algunos dispositivos
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openPrivacy({required LegalRole role}) async {
    // Navega a la sección de privacidad del sitio web según el rol del usuario
    final uri = privacyUri(role: role);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
