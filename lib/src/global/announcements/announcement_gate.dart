import 'package:flutter/material.dart';
import 'package:viax/src/global/announcements/announcement_models.dart';
import 'package:viax/src/global/announcements/announcement_registry.dart';
import 'package:viax/src/global/announcements/announcement_storage.dart';

class AppAnnouncementGate extends StatefulWidget {
  final Widget child;
  final AppAnnouncementViewer viewer;

  const AppAnnouncementGate({
    super.key,
    required this.child,
    required this.viewer,
  });

  @override
  State<AppAnnouncementGate> createState() => _AppAnnouncementGateState();
}

class _AppAnnouncementGateState extends State<AppAnnouncementGate> {
  final AppAnnouncementStorage _storage = AppAnnouncementStorage();

  bool _evaluationStarted = false;
  AppAnnouncement? _blockingAnnouncement;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _evaluateAnnouncements();
    });
  }

  Future<void> _evaluateAnnouncements() async {
    if (!mounted || _evaluationStarted) {
      return;
    }

    _evaluationStarted = true;
    final candidates = AppAnnouncementRegistry.enabledFor(widget.viewer);

    for (final announcement in candidates) {
      final shouldShow = await _storage.shouldShow(announcement);
      if (!mounted || !shouldShow) {
        continue;
      }

      if (announcement.presentation == AppAnnouncementPresentation.blockingSplash) {
        setState(() {
          _blockingAnnouncement = announcement;
        });
        return;
      }

      final handled = await _presentAnnouncement(announcement);
      if (!mounted) {
        return;
      }

      if (handled) {
        await _storage.markSeen(announcement);
      }
    }
  }

  Future<bool> _presentAnnouncement(AppAnnouncement announcement) async {
    switch (announcement.presentation) {
      case AppAnnouncementPresentation.modal:
        final modalResult = await showDialog<bool>(
          context: context,
          barrierDismissible: announcement.dismissible,
          builder: (context) => _AnnouncementModalDialog(
            announcement: announcement,
          ),
        );
        return modalResult ?? true;
      case AppAnnouncementPresentation.onboarding:
        final onboardingResult = await showDialog<bool>(
          context: context,
          barrierDismissible: announcement.dismissible,
          builder: (context) => _AnnouncementOnboardingDialog(
            announcement: announcement,
          ),
        );
        return onboardingResult ?? true;
      case AppAnnouncementPresentation.blockingSplash:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_blockingAnnouncement != null)
          Positioned.fill(
            child: _AnnouncementBlockingSplash(
              announcement: _blockingAnnouncement!,
            ),
          ),
      ],
    );
  }
}

class _AnnouncementModalDialog extends StatelessWidget {
  final AppAnnouncement announcement;

  const _AnnouncementModalDialog({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final page = announcement.firstPage;

    return Dialog(
      backgroundColor: colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _AnnouncementBadge(
                    label: announcement.badge,
                    icon: page.icon,
                  ),
                  const Spacer(),
                  if (announcement.dismissible)
                    IconButton(
                      tooltip: 'Cerrar aviso',
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                page.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                page.message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              if (page.bulletPoints.isNotEmpty) ...[
                const SizedBox(height: 18),
                ...page.bulletPoints.map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Icon(
                            Icons.circle,
                            size: 8,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            point,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(announcement.primaryButtonLabel ?? 'Entendido'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementOnboardingDialog extends StatefulWidget {
  final AppAnnouncement announcement;

  const _AnnouncementOnboardingDialog({required this.announcement});

  @override
  State<_AnnouncementOnboardingDialog> createState() =>
      _AnnouncementOnboardingDialogState();
}

class _AnnouncementOnboardingDialogState
    extends State<_AnnouncementOnboardingDialog> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _currentPage == widget.announcement.pages.length - 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog.fullscreen(
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth > 720 ? 40.0 : 20.0;
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    8,
                  ),
                  child: Row(
                    children: [
                      _AnnouncementBadge(
                        label: widget.announcement.badge,
                        icon: widget.announcement.firstPage.icon,
                      ),
                      const Spacer(),
                      if (widget.announcement.dismissible)
                        IconButton(
                          tooltip: 'Cerrar aviso',
                          onPressed: () => Navigator.of(context).pop(true),
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.announcement.pages.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final page = widget.announcement.pages[index];
                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          12,
                          horizontalPadding,
                          24,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 580),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: Icon(
                                    page.icon,
                                    size: 42,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  page.title,
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  page.message,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                                ),
                                if (page.bulletPoints.isNotEmpty) ...[
                                  const SizedBox(height: 22),
                                  ...page.bulletPoints.map(
                                    (point) => Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              point,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                color: colorScheme.onSurface,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                if (page.footnote != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    page.footnote!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    8,
                    horizontalPadding,
                    20,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          children: List.generate(
                            widget.announcement.pages.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: index == _currentPage ? 28 : 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: index == _currentPage
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          if (_isLastPage) {
                            Navigator.of(context).pop(true);
                            return;
                          }

                          await _pageController.nextPage(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          );
                        },
                        child: Text(
                          _isLastPage
                              ? (widget.announcement.primaryButtonLabel ??
                                    'Entendido')
                              : 'Siguiente',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AnnouncementBlockingSplash extends StatelessWidget {
  final AppAnnouncement announcement;

  const _AnnouncementBlockingSplash({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final page = announcement.firstPage;

    return Material(
      color: colorScheme.surface,
      child: PopScope(
        canPop: false,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AnnouncementBadge(
                      label: announcement.badge,
                      icon: page.icon,
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Icon(
                        page.icon,
                        size: 48,
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      page.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      page.message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    if (page.bulletPoints.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      ...page.bulletPoints.map(
                        (point) => Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colorScheme.outlineVariant),
                          ),
                          child: Text(
                            point,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: colorScheme.primary,
                      ),
                    ),
                    if (page.footnote != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        page.footnote!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementBadge extends StatelessWidget {
  final String? label;
  final IconData icon;

  const _AnnouncementBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.onSecondaryContainer),
          if (label != null && label!.trim().isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              label!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}