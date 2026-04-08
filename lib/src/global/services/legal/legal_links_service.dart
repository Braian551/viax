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

  static Uri termsUri({required LegalRole role}) {
    final roleParam = _roleParam(role);
    return Uri.parse('$_websiteBaseUrl/legal/?doc=terms&role=$roleParam');
  }

  static Uri privacyUri({required LegalRole role}) {
    final roleParam = _roleParam(role);
    return Uri.parse('$_websiteBaseUrl/legal/?doc=privacy&role=$roleParam');
  }

  static Uri contentJsonUri() {
    return Uri.parse('$_websiteBaseUrl/legal_content.json');
  }

  static Future<bool> openTerms({required LegalRole role}) async {
    final uri = termsUri(role: role);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openPrivacy({required LegalRole role}) async {
    final uri = privacyUri(role: role);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
