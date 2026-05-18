import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/legal/providers/legal_provider.dart';
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
  static const double _blockingInitialSheetSize = 0.54;
  static const double _blockingMinSheetSize = 0.42;
  static const double _blockingMaxSheetSize = 0.74;
  static const double _compactInitialSheetSize = 0.46;
  static const double _compactMinSheetSize = 0.36;
  static const double _compactMaxSheetSize = 0.62;

  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _isSubmitting = false;
  bool _isLoadingState = true;

  String _resolvedVersion = '';
  bool _isUpdateFlow = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // Esperar el primer frame evita notificar al provider mientras Flutter monta la ruta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _bootstrapLegalView();
      }
    });
  }

  Future<void> _bootstrapLegalView() async {
    setState(() {
      _isLoadingState = true;
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

      if (!mounted) return;
      setState(() {
        _resolvedVersion = resolvedVersion.isEmpty
            ? widget.version
            : resolvedVersion;
        _isUpdateFlow = isUpdateFlow;
        _isLoadingState = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError =
            'No se pudo validar la información legal. Intenta nuevamente.';
        _isLoadingState = false;
      });
    }
  }

  String _sheetTitle() => 'Términos y condiciones';

  String? _sheetSubtitle() {
    return null;
  }

  bool get _usesCompactSheet => !widget.isBlocking && !_isUpdateFlow;

  double get _initialSheetSize =>
      _usesCompactSheet ? _compactInitialSheetSize : _blockingInitialSheetSize;

  double get _minSheetSize =>
      _usesCompactSheet ? _compactMinSheetSize : _blockingMinSheetSize;

  double get _maxSheetSize =>
      _usesCompactSheet ? _compactMaxSheetSize : _blockingMaxSheetSize;

  Future<void> _navigateToRoleHome() async {
    final session = await UserService.getSavedSession();
    if (!mounted) return;

    final routeRole = widget.role.trim().toLowerCase();
    final sessionRole =
        (session?['tipo_usuario']?.toString().toLowerCase() ?? '').trim();

    String effectiveRole = routeRole;
    if (sessionRole.isNotEmpty &&
        (effectiveRole.isEmpty || effectiveRole == 'cliente')) {
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
    var success = true;

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
      return;
    }

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

  Future<void> _openTermsLink() async {
    final opened = await LegalLinksService.openTerms(
      role: LegalLinksService.fromString(widget.role),
    );

    if (!opened && mounted) {
      GlobalOverlayMessage.showError(
        context,
        'No se pudo abrir Términos y Condiciones.',
      );
    }
  }

  Future<void> _openPrivacyLink() async {
    final opened = await LegalLinksService.openPrivacy(
      role: LegalLinksService.fromString(widget.role),
    );

    if (!opened && mounted) {
      GlobalOverlayMessage.showError(
        context,
        'No se pudo abrir Política de Privacidad.',
      );
    }
  }

  void _dismissSheet() {
    if (widget.isBlocking || _isSubmitting || !Navigator.of(context).canPop()) {
      return;
    }

    Navigator.of(context).pop(false);
  }

  bool _handleSheetNotification(DraggableScrollableNotification notification) {
    // Cuando el usuario baja el sheet hasta el mínimo, cerramos el flujo opcional sin registrar nada.
    if (widget.isBlocking || _isSubmitting) {
      return false;
    }

    if (notification.extent <= notification.minExtent + 0.01) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _dismissSheet();
        }
      });
    }

    return false;
  }

  Widget _buildAcceptanceRow({
    required BuildContext context,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String prefix,
    required String linkText,
    required String suffix,
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
          // Centrar verticalmente el checkbox respecto al texto
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Transform.scale(
              scale: 1.18,
              alignment: Alignment.center,
              child: Checkbox(
                value: value,
                onChanged: (checked) => onChanged(checked ?? false),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
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
                    TextSpan(text: suffix),
                  ],
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
                      Colors.black.withValues(alpha: isDark ? 0.70 : 0.46),
                      Colors.black.withValues(alpha: isDark ? 0.56 : 0.32),
                    ],
                  ),
                ),
              ),
            ),
            if (!widget.isBlocking)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _dismissSheet,
                  child: const SizedBox.expand(),
                ),
              ),
            SafeArea(
              top: true,
              child: NotificationListener<DraggableScrollableNotification>(
                onNotification: _handleSheetNotification,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: _initialSheetSize,
                    minChildSize: _minSheetSize,
                    maxChildSize: _maxSheetSize,
                    builder: (context, scrollController) {
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
                            Expanded(
                              child: ListView(
                                controller: scrollController,
                                padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
                                children: [
                                  // El titulo principal conserva contraste usando el color del tema activo.
                                  ...[
                                    Text(
                                      _sheetTitle(),
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: colorScheme.onSurface,
                                          ),
                                    ),
                                    if (_sheetSubtitle() != null) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        _sheetSubtitle()!,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              height: 1.4,
                                            ),
                                      ),
                                    ],
                                    if (_resolvedVersion.trim().isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        'Versión $_resolvedVersion',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colorScheme.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                    const SizedBox(height: 20),
                                    Divider(
                                      height: 1,
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                  if (_isLoadingState)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 48,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  else if (_loadError != null)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _loadError!,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                                height: 1.4,
                                              ),
                                        ),
                                        const SizedBox(height: 16),
                                        FilledButton(
                                          onPressed: _bootstrapLegalView,
                                          child: const Text('Reintentar'),
                                        ),
                                      ],
                                    )
                                  else
                                    Container(
                                      padding: EdgeInsets.fromLTRB(
                                        18,
                                        20,
                                        18,
                                        18,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surface,
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: isDark
                                              ? colorScheme.outlineVariant
                                                    .withValues(alpha: 0.7)
                                              : AppColors.blue100.withValues(
                                                  alpha: 0.95,
                                                ),
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
                                            linkText: 'Términos y condiciones',
                                            suffix: '.',
                                            onOpen: _openTermsLink,
                                          ),
                                          const SizedBox(height: 12),
                                          _buildAcceptanceRow(
                                            context: context,
                                            value: _acceptedPrivacy,
                                            onChanged: (value) => setState(
                                              () => _acceptedPrivacy = value,
                                            ),
                                            prefix: 'Acepto la ',
                                            linkText: 'Política de privacidad',
                                            suffix:
                                                ' y el tratamiento de datos personales.',
                                            onOpen: _openPrivacyLink,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                16,
                                24,
                                24,
                              ),
                              decoration: BoxDecoration(
                                // Sin borde superior para un look más limpio
                                color: theme.scaffoldBackgroundColor,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: FilledButton(
                                  onPressed:
                                      (_isLoadingState ||
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
                                      : const Text('Aceptar'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
