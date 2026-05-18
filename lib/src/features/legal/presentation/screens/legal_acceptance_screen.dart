import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/legal/models/legal_document_model.dart';
import 'package:viax/src/features/legal/providers/legal_provider.dart';
import 'package:viax/src/features/legal/services/legal_content_service.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/global/services/device_id_service.dart';
import 'package:viax/src/global/services/legal/legal_links_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/shared/widgets/global_overlay_message.dart';
import 'package:viax/src/theme/app_colors.dart';

class LegalAcceptanceScreen extends StatefulWidget {
  final String role;
  final int? userId;
  final String version;
  final bool returnResultOnAccept;
  final bool isBlocking;

  const LegalAcceptanceScreen({
    super.key,
    required this.role, 
    required this.version,
    this.userId,
    this.returnResultOnAccept = false,
    this.isBlocking = true,
  });

  @override
  State<LegalAcceptanceScreen> createState() => _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends State<LegalAcceptanceScreen> {
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _isSubmitting = false;
  bool _isLoadingDocuments = true;

  String _resolvedVersion = '';
  bool _isUpdateFlow = false;
  LegalDocumentData? _termsDocument;
  LegalDocumentData? _privacyDocument;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _bootstrapLegalView();
  }

  Future<void> _bootstrapLegalView() async {
    setState(() {
      _isLoadingDocuments = true;
      _loadError = null;
    });

    try {
      final legalProvider = context.read<LegalProvider>();
      var resolvedVersion = widget.version.trim();
      var isUpdateFlow = false;

      if (widget.userId != null && widget.userId! > 0) {
        final status = await legalProvider.checkLegalStatus(
          role: widget.role,
          userId: widget.userId!,
        );

        if (!mounted) return;

        if (status == LegalStatus.accepted) {
          Navigator.of(context).pop(true);
          return;
        }

        resolvedVersion =
            legalProvider.currentRequiredVersion?.trim().isNotEmpty == true
                ? legalProvider.currentRequiredVersion!.trim()
                : resolvedVersion;
        isUpdateFlow = legalProvider.hasAcceptedAnyVersion;
      } else if (resolvedVersion.isEmpty || resolvedVersion == 'v1.0') {
        final fetchedVersion = await legalProvider.fetchCurrentVersion(
          role: widget.role,
        );
        resolvedVersion = fetchedVersion?.trim().isNotEmpty == true
            ? fetchedVersion!.trim()
            : resolvedVersion;
      }

      final role = LegalLinksService.fromString(widget.role);
      final docs = await Future.wait([
        LegalContentService.fetchDocumentData(
          role: role,
          docType: LegalDocType.terms,
        ),
        LegalContentService.fetchDocumentData(
          role: role,
          docType: LegalDocType.privacy,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _termsDocument = docs[0];
        _privacyDocument = docs[1];
        _resolvedVersion = resolvedVersion.isEmpty ? widget.version : resolvedVersion;
        _isUpdateFlow = isUpdateFlow;
        _isLoadingDocuments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError =
            'No se pudieron cargar los documentos legales. Revisa tu conexión e intenta de nuevo.';
        _isLoadingDocuments = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _roleLabel() {
    switch (widget.role.trim().toLowerCase()) {
      case 'conductor':
        return 'conductor';
      case 'empresa':
        return 'empresa';
      case 'administrador':
      case 'admin':
        return 'administrador';
      case 'soporte_tecnico':
        return 'soporte';
      default:
        return 'cliente';
    }
  }

  String _sheetTitle() {
    if (_isUpdateFlow) {
      return 'Actualizamos los términos de ${_roleLabel()}';
    }

    if (widget.userId == null || widget.userId == 0) {
      return 'Antes de crear tu cuenta';
    }

    return 'Confirma tus documentos legales';
  }

  String _sheetSubtitle() {
    if (_isUpdateFlow) {
      return 'Revisa el resumen vigente y acepta esta versión para seguir usando Viax en tu rol.';
    }

    if (widget.userId == null || widget.userId == 0) {
      return 'Necesitamos tu aceptación para terminar el alta y activar tu acceso sin volver a pedirlo en cada instalación.';
    }

    return 'Tu cuenta necesita esta aceptación para continuar con el flujo actual.';
  }

  Future<void> _navigateToRoleHome() async {
    final session = await UserService.getSavedSession();
    if (!mounted) return;

    final routeRole = widget.role.trim().toLowerCase();
    final sessionRole = (session?['tipo_usuario']?.toString().toLowerCase() ?? '').trim();

    // Si el rol de ruta viene por defecto como cliente, priorizar el rol real de sesión.
    String effectiveRole = routeRole;
    if (sessionRole.isNotEmpty && (effectiveRole.isEmpty || effectiveRole == 'cliente')) {
      effectiveRole = sessionRole;
    }

    switch (effectiveRole) {
      case 'conductor':
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.backgroundLocationDisclosure,
          (route) => false,
          arguments: {'role': effectiveRole},
        );
        break;
      case 'empresa':
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.companyHome,
          (route) => false,
          arguments: {'user': session ?? {}},
        );
        break;
      case 'administrador':
      case 'admin':
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.adminHome,
          (route) => false,
          arguments: {'admin_user': session ?? {}},
        );
        break;
      case 'soporte_tecnico':
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.supportHome,
          (route) => false,
          arguments: {'support_user': session ?? {}},
        );
        break;
      default:
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.home,
          (route) => false,
          arguments: {'email': session?['email'], 'user': session ?? {}},
        );
    }
  }

  Future<void> _handleAcceptance() async {
    setState(() => _isSubmitting = true);

    final userId = widget.userId ?? 0;
    bool success = true;

    if (userId > 0) {
      final legalProv = context.read<LegalProvider>();
      final deviceId = await DeviceIdService.getOrCreateDeviceUuid();

      success = await legalProv.acceptTerms(
        userId: userId,
        role: widget.role,
        deviceId: deviceId,
        version: _resolvedVersion.isEmpty ? widget.version : _resolvedVersion,
      );
    }

    if (success && mounted) {
      if (widget.returnResultOnAccept || Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
        return;
      }

      await _navigateToRoleHome();
    } else {
      if (mounted) {
        final legalProv = context.read<LegalProvider>();
        final backendMessage = legalProv.lastError?.trim();
        setState(() => _isSubmitting = false);
        GlobalOverlayMessage.showError(
          context,
          (backendMessage != null && backendMessage.isNotEmpty)
            ? backendMessage
            : 'Error al procesar la aceptación. Intenta de nuevo.',
        );
      }
    }
  }

  void _openDocument(LegalDocType docType) {
    Navigator.of(context).pushNamed(
      docType == LegalDocType.terms ? RouteNames.terms : RouteNames.privacy,
      arguments: {'role': widget.role},
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required LegalDocumentData document,
    required IconData icon,
    required VoidCallback onOpen,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final summarySections = document.buildSummarySections(maxItems: 2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? colorScheme.outlineVariant.withValues(alpha: 0.7)
              : AppColors.blue100.withValues(alpha: 0.95),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  document.docType.shortTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...summarySections.map(
            (section) => Padding(
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
                      section.summary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: onOpen,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text('Ver documento completo'),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptanceRow({
    required BuildContext context,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String prefix,
    required String linkText,
    required VoidCallback onOpen,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: (checked) => onChanged(checked ?? false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(text: prefix),
                      TextSpan(
                        text: linkText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = onOpen,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !widget.isBlocking,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: isDark ? 0.72 : 0.50),
                      Colors.black.withValues(alpha: isDark ? 0.58 : 0.38),
                    ],
                  ),
                ),
              ),
            ),
            if (!widget.isBlocking)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(false),
                  child: const SizedBox.expand(),
                ),
              ),
            SafeArea(
              child: Stack(
                children: [
                  if (!widget.isBlocking)
                    Positioned(
                      top: 12,
                      right: 16,
                      child: IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  // Anclar el sheet al fondo evita que desaparezca cuando la ruta se monta como overlay.
                  Positioned.fill(
                    child: DraggableScrollableSheet(
                      expand: false,
                      initialChildSize: 0.82,
                      minChildSize: 0.74,
                      maxChildSize: 0.95,
                      builder: (context, scrollController) {
                        // El sheet resume la aceptación y deja el documento completo en una vista aparte para no saturar el primer contacto.
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(34),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.24),
                                blurRadius: 24,
                                offset: const Offset(0, -6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              Container(
                                width: 52,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: colorScheme.outlineVariant,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Expanded(
                                child: CustomScrollView(
                                  controller: scrollController,
                                  slivers: [
                                    SliverPadding(
                                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                      sliver: SliverToBoxAdapter(
                                        child: _isLoadingDocuments
                                            ? const Padding(
                                                padding: EdgeInsets.symmetric(vertical: 80),
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              )
                                            : _loadError != null
                                            ? Padding(
                                                padding: const EdgeInsets.symmetric(
                                                  vertical: 36,
                                                ),
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
                                                      onPressed: _bootstrapLegalView,
                                                      child: const Text('Reintentar'),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _sheetTitle(),
                                                    style: theme.textTheme.headlineSmall?.copyWith(
                                                      fontWeight: FontWeight.w900,
                                                      color: colorScheme.onSurface,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    _sheetSubtitle(),
                                                    style: theme.textTheme.bodyMedium?.copyWith(
                                                      color: colorScheme.onSurfaceVariant,
                                                      height: 1.45,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 18),
                                                  Wrap(
                                                    spacing: 10,
                                                    runSpacing: 10,
                                                    children: [
                                                      _LegalMetaChip(
                                                        label: 'Rol ${_roleLabel()}',
                                                        icon: Icons.shield_rounded,
                                                      ),
                                                      if (_resolvedVersion.trim().isNotEmpty)
                                                        _LegalMetaChip(
                                                          label: 'Versión $_resolvedVersion',
                                                          icon: Icons.verified_rounded,
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 22),
                                                  if (_termsDocument != null)
                                                    _buildSummaryCard(
                                                      context: context,
                                                      document: _termsDocument!,
                                                      icon: Icons.gavel_rounded,
                                                      onOpen: () => _openDocument(
                                                        LegalDocType.terms,
                                                      ),
                                                    ),
                                                  if (_termsDocument != null)
                                                    const SizedBox(height: 14),
                                                  if (_privacyDocument != null)
                                                    _buildSummaryCard(
                                                      context: context,
                                                      document: _privacyDocument!,
                                                      icon: Icons.privacy_tip_rounded,
                                                      onOpen: () => _openDocument(
                                                        LegalDocType.privacy,
                                                      ),
                                                    ),
                                                  const SizedBox(height: 18),
                                                  Container(
                                                    padding: const EdgeInsets.all(16),
                                                    decoration: BoxDecoration(
                                                      color: colorScheme.surface,
                                                      borderRadius: BorderRadius.circular(22),
                                                      border: Border.all(
                                                        color: isDark
                                                            ? colorScheme.outlineVariant.withValues(alpha: 0.7)
                                                            : AppColors.blue100.withValues(alpha: 0.95),
                                                      ),
                                                    ),
                                                    child: Column(
                                                      children: [
                                                        _buildAcceptanceRow(
                                                          context: context,
                                                          value: _acceptedTerms,
                                                          onChanged: (value) => setState(
                                                            () => _acceptedTerms = value,
                                                          ),
                                                          prefix: 'Acepto los ',
                                                          linkText:
                                                              'Términos y Condiciones',
                                                          onOpen: () => _openDocument(
                                                            LegalDocType.terms,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        _buildAcceptanceRow(
                                                          context: context,
                                                          value: _acceptedPrivacy,
                                                          onChanged: (value) => setState(
                                                            () => _acceptedPrivacy = value,
                                                          ),
                                                          prefix:
                                                              'Acepto la ',
                                                          linkText:
                                                              'Política de Privacidad y tratamiento de datos',
                                                          onOpen: () => _openDocument(
                                                            LegalDocType.privacy,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                                decoration: BoxDecoration(
                                  color: theme.scaffoldBackgroundColor,
                                  border: Border(
                                    top: BorderSide(
                                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                      child: FilledButton(
                                        onPressed: (_isLoadingDocuments ||
                                                _loadError != null ||
                                                !_acceptedTerms ||
                                                !_acceptedPrivacy ||
                                                _isSubmitting)
                                            ? null
                                            : _handleAcceptance,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                        ),
                                        child: _isSubmitting
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.4,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Text(
                                                _isUpdateFlow
                                                    ? 'Aceptar actualización'
                                                    : 'Aceptar y continuar',
                                              ),
                                      ),
                                    ),
                                    if (!widget.isBlocking) ...[
                                      const SizedBox(height: 10),
                                      TextButton(
                                        onPressed: _isSubmitting
                                            ? null
                                            : () => Navigator.of(context).pop(false),
                                        child: const Text('Ahora no'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalMetaChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _LegalMetaChip({required this.label, required this.icon});

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
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
