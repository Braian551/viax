import 'package:flutter/material.dart';
import 'package:viax/src/features/legal/models/legal_document_model.dart';
import 'package:viax/src/features/legal/services/legal_content_service.dart';
import 'package:viax/src/global/services/legal/legal_links_service.dart';
import 'package:viax/src/theme/app_colors.dart';

class LegalDocumentScreen extends StatefulWidget {
  final String role;
  final LegalDocType docType;

  const LegalDocumentScreen({
    super.key,
    required this.role,
    required this.docType,
  });

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  LegalDocumentData? _document;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final document = await LegalContentService.fetchDocumentData(
        role: LegalLinksService.fromString(widget.role),
        docType: widget.docType,
      );

      if (!mounted) return;
      setState(() {
        _document = document;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'No pudimos cargar este documento legal en este momento.';
        _isLoading = false;
      });
    }
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'conductor':
        return 'Conductor';
      case 'empresa':
        return 'Empresa';
      case 'administrador':
      case 'admin':
        return 'Administrador';
      case 'soporte_tecnico':
        return 'Soporte';
      default:
        return 'Cliente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(widget.docType.shortTitle),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadDocument,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : _document == null
            ? const SizedBox.shrink()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: _document!.sections.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // El encabezado resume la vigencia y el alcance del documento sin obligar al usuario a salir de la app.
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? colorScheme.outlineVariant.withValues(alpha: 0.7)
                              : AppColors.blue100.withValues(alpha: 0.95),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _document!.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _document!.intro,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _InfoChip(
                                label: _roleLabel(widget.role),
                                icon: Icons.badge_rounded,
                              ),
                              if (_document!.meta.trim().isNotEmpty)
                                _InfoChip(
                                  label: _document!.meta,
                                  icon: Icons.update_rounded,
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  final section = _document!.sections[index - 1];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark
                            ? colorScheme.outlineVariant.withValues(alpha: 0.6)
                            : AppColors.blue100.withValues(alpha: 0.9),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.heading,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (section.summary.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            section.summary,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                        if (section.bullets.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          ...section.bullets.map(
                            (bullet) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.only(top: 7),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      bullet,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurface,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}