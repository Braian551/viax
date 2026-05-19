enum LegalDocType { terms, privacy }

extension LegalDocTypeExtension on LegalDocType {
  String get key => this == LegalDocType.terms ? 'terms' : 'privacy';

  String get shortTitle =>
      this == LegalDocType.terms
          ? 'Términos y Condiciones'
          : 'Política de Privacidad';
}

class LegalDocumentSection {
  final String id;
  final String heading;
  final String summary;
  final List<String> bullets;

  const LegalDocumentSection({
    required this.id,
    required this.heading,
    required this.summary,
    required this.bullets,
  });

  bool get hasSummary => summary.trim().isNotEmpty;
}

class LegalDocumentData {
  static const Set<String> _defaultSummarySkipIds = {
    'company_identification',
    'legal_framework',
    'terms_modification',
    'terms_acceptance',
    'final_acceptance',
    'governing_law',
  };

  final String roleKey;
  final LegalDocType docType;
  final String title;
  final String intro;
  final String meta;
  final List<LegalDocumentSection> sections;

  const LegalDocumentData({
    required this.roleKey,
    required this.docType,
    required this.title,
    required this.intro,
    required this.meta,
    required this.sections,
  });

  String toPlainText() {
    final buffer = StringBuffer();

    if (title.trim().isNotEmpty) {
      buffer.writeln(title.trim());
      buffer.writeln();
    }

    if (intro.trim().isNotEmpty) {
      buffer.writeln(intro.trim());
      buffer.writeln();
    }

    if (meta.trim().isNotEmpty) {
      buffer.writeln(meta.trim());
      buffer.writeln();
    }

    for (var index = 0; index < sections.length; index++) {
      final section = sections[index];
      if (section.heading.trim().isNotEmpty) {
        buffer.writeln('${index + 1}. ${section.heading.trim()}');
      }
      if (section.summary.trim().isNotEmpty) {
        buffer.writeln(section.summary.trim());
      }
      for (final bullet in section.bullets) {
        if (bullet.trim().isEmpty) continue;
        buffer.writeln('* ${bullet.trim()}');
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  List<LegalDocumentSection> buildSummarySections({int maxItems = 3}) {
    final preferred = sections
        .where(
          (section) =>
              section.hasSummary &&
              !_defaultSummarySkipIds.contains(section.id.trim().toLowerCase()),
        )
        .take(maxItems)
        .toList();

    if (preferred.isNotEmpty) {
      return preferred;
    }

    return sections.where((section) => section.hasSummary).take(maxItems).toList();
  }
}