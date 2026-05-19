import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:viax/src/features/legal/models/legal_document_model.dart';
import 'package:viax/src/global/services/legal/legal_links_service.dart';

class LegalContentService {
  static const String _localAssetPath = 'assets/legal/legal_content.json';

  static Future<LegalDocumentData> fetchDocumentData({
    required LegalRole role,
    required LegalDocType docType,
  }) async {
    try {
      return _loadStructuredDocumentFromRemoteJson(role: role, docType: docType);
    } catch (_) {
      return _loadStructuredDocumentFromLocalAsset(role: role, docType: docType);
    }
  }

  static Future<String> fetchTerms({required LegalRole role}) async {
    try {
      final remoteJsonText = await _loadFromRemoteJson(role: role, docType: 'terms');
      if (_isSubstantive(remoteJsonText)) return remoteJsonText;
    } catch (_) {}

    try {
      final text = await _fetchAndNormalize(
        LegalLinksService.termsUri(role: role),
        mainTitle: 'Terminos y Condiciones',
      );
      if (_isSubstantive(text)) return text;
    } catch (_) {}

    return _loadFromLocalAsset(role: role, docType: 'terms');
  }

  static Future<String> fetchPrivacy({required LegalRole role}) async {
    try {
      final remoteJsonText = await _loadFromRemoteJson(role: role, docType: 'privacy');
      if (_isSubstantive(remoteJsonText)) return remoteJsonText;
    } catch (_) {}

    try {
      final text = await _fetchAndNormalize(
        LegalLinksService.privacyUri(role: role),
        mainTitle: 'Politica de Privacidad',
      );
      if (_isSubstantive(text)) return text;
    } catch (_) {}

    return _loadFromLocalAsset(role: role, docType: 'privacy');
  }

  static Future<String> _loadFromRemoteJson({
    required LegalRole role,
    required String docType,
  }) async {
    final response = await http.get(
      LegalLinksService.contentJsonUri(),
      headers: const {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw Exception('No se pudo cargar JSON legal remoto.');
    }

    final raw = utf8.decode(response.bodyBytes);
    return _parseDocumentFromJson(raw, role: role, docType: docType).toPlainText();
  }

  static Future<String> _fetchAndNormalize(
    Uri uri, {
    required String mainTitle,
  }) async {
    final response = await http.get(
      uri,
      headers: const {'Accept': 'text/html,application/xhtml+xml'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw Exception('No se pudo cargar el documento legal.');
    }

    String html;
    try {
      html = utf8.decode(response.bodyBytes);
    } catch (_) {
      html = latin1.decode(response.bodyBytes);
    }

    html = html.replaceAll(
      RegExp(r'<script[^>]*>[\\s\\S]*?</script>', caseSensitive: false),
      '',
    );
    html = html.replaceAll(
      RegExp(r'<style[^>]*>[\\s\\S]*?</style>', caseSensitive: false),
      '',
    );
    html = html.replaceAll(RegExp(r'<br\\s*/?>', caseSensitive: false), '\n');
    html = html.replaceAll(
      RegExp(r'</(p|div|h1|h2|h3|h4|h5|section|article|li|tr)>', caseSensitive: false),
      '\n',
    );
    html = html.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '* ');
    html = html.replaceAll(RegExp(r'<[^>]+>'), '');

    var text = _decodeHtmlEntities(html);
    text = _extractMainLegalText(text, mainTitle: mainTitle);
    text = text.replaceAll('\r', '');
    text = text.replaceAll(RegExp(r'\t+'), ' ');
    text = text.replaceAll(RegExp(r' {2,}'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }

  static bool _isSubstantive(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length < 1200) return false;
    if (!compact.toLowerCase().contains('viax')) return false;
    return RegExp(r'\b1\.|\b2\.|\b3\.|\b4\.|\b5\.', caseSensitive: false)
        .hasMatch(compact);
  }

  static Future<String> _loadFromLocalAsset({
    required LegalRole role,
    required String docType,
  }) async {
    final raw = await rootBundle.loadString(_localAssetPath);
    return _parseDocumentFromJson(raw, role: role, docType: docType).toPlainText();
  }

  static Future<LegalDocumentData> _loadStructuredDocumentFromRemoteJson({
    required LegalRole role,
    required LegalDocType docType,
  }) async {
    final response = await http.get(
      LegalLinksService.contentJsonUri(),
      headers: const {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw Exception('No se pudo cargar JSON legal remoto.');
    }

    final raw = utf8.decode(response.bodyBytes);
    return _parseDocumentFromJson(raw, role: role, docType: docType.key);
  }

  static Future<LegalDocumentData> _loadStructuredDocumentFromLocalAsset({
    required LegalRole role,
    required LegalDocType docType,
  }) async {
    final raw = await rootBundle.loadString(_localAssetPath);
    return _parseDocumentFromJson(raw, role: role, docType: docType.key);
  }

  static LegalDocumentData _parseDocumentFromJson(
    String raw, {
    required LegalRole role,
    required String docType,
  }) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Contenido legal local invalido.');
    }

    String roleKey;
    switch (role) {
      case LegalRole.conductor:
        roleKey = 'conductor';
        break;
      case LegalRole.empresa:
        roleKey = 'empresa';
        break;
      case LegalRole.administrador:
        roleKey = 'administrador';
        break;
      case LegalRole.servidor:
        roleKey = 'servidor';
        break;
      case LegalRole.cliente:
        roleKey = 'cliente';
        break;
    }

    final roleDoc = decoded[roleKey];
    if (roleDoc is! Map<String, dynamic>) {
      throw Exception('No hay contenido legal para el rol: $roleKey');
    }

    final doc = roleDoc[docType];
    if (doc is! Map<String, dynamic>) {
      throw Exception('No hay documento legal local: $docType para rol $roleKey');
    }

    final title = doc['title']?.toString().trim() ?? '';
    final intro = doc['intro']?.toString().trim() ?? '';
    final meta = doc['meta']?.toString().trim() ?? '';
    final sections = doc['sections'];
    final parsedSections = <LegalDocumentSection>[];

    if (sections is List) {
      for (final section in sections) {
        if (section is! Map<String, dynamic>) continue;

        final bullets = <String>[];
        final rawBullets = section['bullets'];
        if (rawBullets is List) {
          for (final bullet in rawBullets) {
            final text = bullet?.toString().trim();
            if (text != null && text.isNotEmpty) {
              bullets.add(text);
            }
          }
        }

        parsedSections.add(
          LegalDocumentSection(
            id: section['id']?.toString().trim() ?? '',
            heading: section['heading']?.toString().trim() ?? '',
            summary: section['summary']?.toString().trim() ?? '',
            bullets: bullets,
          ),
        );
      }
    }

    final documentData = LegalDocumentData(
      roleKey: roleKey,
      docType: docType == LegalDocType.privacy.key
          ? LegalDocType.privacy
          : LegalDocType.terms,
      title: title,
      intro: intro,
      meta: meta,
      sections: parsedSections,
    );

    final result = documentData.toPlainText();
    if (result.isEmpty) {
      throw Exception('El contenido legal local esta vacio.');
    }

    return documentData;
  }

  static String _extractMainLegalText(String text, {required String mainTitle}) {
    final normalized = _normalizeForSearch(text);
    final normalizedTitle = _normalizeForSearch(mainTitle);

    var start = normalized.indexOf(normalizedTitle);
    if (start < 0) {
      start = normalized.indexOf(_normalizeForSearch('Documentos legales'));
    }

    if (start > 0 && start < text.length) {
      text = text.substring(start);
    }

    final footerCandidates = [
      'VIAX TECHNOLOGY S.A.S',
      'Transparencia total',
      'PLATAFORMA',
      'Privacidad y Cookies',
      'Todos los derechos reservados',
    ];

    var end = -1;
    for (final candidate in footerCandidates) {
      final idx = text.indexOf(candidate);
      if (idx > 0 && (end == -1 || idx < end)) {
        end = idx;
      }
    }

    if (end > 0) {
      text = text.substring(0, end);
    }

    return text;
  }

  static String _normalizeForSearch(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
  }

  static String _decodeHtmlEntities(String input) {
    return input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&aacute;', 'á')
        .replaceAll('&eacute;', 'é')
        .replaceAll('&iacute;', 'í')
        .replaceAll('&oacute;', 'ó')
        .replaceAll('&uacute;', 'ú')
        .replaceAll('&Aacute;', 'Á')
        .replaceAll('&Eacute;', 'É')
        .replaceAll('&Iacute;', 'Í')
        .replaceAll('&Oacute;', 'Ó')
        .replaceAll('&Uacute;', 'Ú')
        .replaceAll('&ntilde;', 'ñ')
        .replaceAll('&Ntilde;', 'Ñ');
  }
}
