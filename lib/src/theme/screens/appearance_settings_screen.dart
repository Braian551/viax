import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/theme/theme_provider.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  Future<void> _setSystemMode(
    BuildContext context,
    ThemeProvider themeProvider,
    bool enabled,
  ) async {
    if (enabled) {
      await themeProvider.setSystemMode();
      return;
    }

    await themeProvider.setThemeMode(
      themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        elevation: 0,
        centerTitle: true,
        title: const Text('Apariencia'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aspecto',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? colorScheme.outlineVariant.withValues(alpha: 0.28)
                        : AppColors.blue100.withValues(alpha: 0.95),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Elige el look de Viax',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'La vista previa usa el mismo lenguaje visual de la app: header flotante, tarjetas y navegación inferior.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isStacked = constraints.maxWidth < 340;
                        final optionWidth = isStacked
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 16) / 2;

                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: optionWidth,
                              child: _ThemePreviewOption(
                                label: 'Claro',
                                subtitle: 'Más luz y contraste suave para el día.',
                                isSelected:
                                    themeProvider.themeMode == ThemeMode.light,
                                onTap: () => themeProvider.setLightMode(),
                                child: _ThemePreviewCard(
                                  isDarkPreview: false,
                                  isActive:
                                      themeProvider.themeMode == ThemeMode.light,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: optionWidth,
                              child: _ThemePreviewOption(
                                label: 'Oscuro',
                                subtitle: 'Reduce brillo y mantiene el estilo nocturno de Viax.',
                                isSelected:
                                    themeProvider.themeMode == ThemeMode.dark,
                                onTap: () => themeProvider.setDarkMode(),
                                child: _ThemePreviewCard(
                                  isDarkPreview: true,
                                  isActive:
                                      themeProvider.themeMode == ThemeMode.dark,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _SystemModeCard(
                      isDark: isDark,
                      isEnabled: themeProvider.isSystemMode,
                      resolvedLabel:
                          themeProvider.isDarkMode ? 'Oscuro' : 'Claro',
                      onChanged: (value) =>
                          _setSystemMode(context, themeProvider, value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreviewOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  const _ThemePreviewOption({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.08)
                : colorScheme.surface.withValues(alpha: isDark ? 0.78 : 0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : (isDark
                        ? colorScheme.outlineVariant.withValues(alpha: 0.7)
                        : AppColors.blue100.withValues(alpha: 0.95)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              child,
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outline,
                        width: 2,
                      ),
                      color: isSelected
                          ? colorScheme.primary
                          : Colors.transparent,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: colorScheme.onPrimary,
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  final bool isDarkPreview;
  final bool isActive;

  const _ThemePreviewCard({
    required this.isDarkPreview,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive
        ? AppColors.primary.withValues(alpha: isDarkPreview ? 0.75 : 0.45)
        : (isDarkPreview
              ? Colors.white.withValues(alpha: 0.08)
          : AppColors.blue100.withValues(alpha: 0.95));
    final previewBackground = isDarkPreview
        ? const Color(0xFF15181E)
        : const Color(0xFFF3F5F8);
    final previewAccent = isDarkPreview
        ? AppColors.primary.withValues(alpha: 0.22)
        : AppColors.primary.withValues(alpha: 0.12);
    final surfaceColor = isDarkPreview
        ? AppColors.darkCard.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.94);
    final surfaceBorder = isDarkPreview
        ? Colors.white.withValues(alpha: 0.10)
      : AppColors.blue100.withValues(alpha: 0.88);
    final primaryText = isDarkPreview ? Colors.white : AppColors.lightTextPrimary;
    final secondaryText = isDarkPreview
        ? Colors.white.withValues(alpha: 0.65)
        : AppColors.lightTextSecondary;

    return AspectRatio(
      aspectRatio: 0.78,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              previewBackground,
              Color.lerp(previewBackground, previewAccent, 0.35)!,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: borderColor,
            width: isActive ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkPreview ? 0.22 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.7),
                radius: 1.1,
                colors: [
                  previewAccent,
                  Colors.transparent,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: surfaceBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: isDarkPreview ? 0.22 : 0.12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.navigation_rounded,
                                    color: AppColors.primary,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        height: 4,
                                        width: 34,
                                        decoration: BoxDecoration(
                                          color: secondaryText,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        height: 6,
                                        width: 62,
                                        decoration: BoxDecoration(
                                          color: primaryText,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.notifications_none_rounded,
                                  size: 16,
                                  color: primaryText,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: surfaceBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 6,
                                width: 84,
                                decoration: BoxDecoration(
                                  color: primaryText,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 4,
                                width: 112,
                                decoration: BoxDecoration(
                                  color: secondaryText,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: isDarkPreview
                                          ? [
                                              AppColors.primary.withValues(
                                                alpha: 0.56,
                                              ),
                                              AppColors.primaryDark.withValues(
                                                alpha: 0.46,
                                              ),
                                            ]
                                          : [
                                              AppColors.primary.withValues(
                                                alpha: 0.24,
                                              ),
                                              Colors.white,
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _PreviewStatBlock(
                                          icon: Icons.location_on_rounded,
                                          color: isDarkPreview
                                              ? Colors.white
                                              : AppColors.primary,
                                        ),
                                      ),
                                      Expanded(
                                        child: _PreviewStatBlock(
                                          icon: Icons.route_rounded,
                                          color: isDarkPreview
                                              ? Colors.white70
                                              : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: isDarkPreview ? 0.32 : 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.home_rounded,
                                        size: 18,
                                        color: isDarkPreview
                                            ? Colors.white
                                            : AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 16,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: isDarkPreview
                                              ? Colors.white.withValues(alpha: 0.85)
                                              : AppColors.primary.withValues(alpha: 0.55),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Icon(
                                  Icons.history_rounded,
                                  size: 18,
                                  color: secondaryText,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 18,
                                  color: secondaryText,
                                ),
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
        ),
      ),
    );
  }
}

class _PreviewStatBlock extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _PreviewStatBlock({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _SystemModeCard extends StatelessWidget {
  final bool isDark;
  final bool isEnabled;
  final String resolvedLabel;
  final ValueChanged<bool> onChanged;

  const _SystemModeCard({
    required this.isDark,
    required this.isEnabled,
    required this.resolvedLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEnabled
            ? colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.08)
            : colorScheme.surface.withValues(alpha: isDark ? 0.82 : 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isEnabled
              ? colorScheme.primary.withValues(alpha: isDark ? 0.55 : 0.38)
              : (isDark
                    ? colorScheme.outlineVariant.withValues(alpha: 0.7)
                    : AppColors.blue100.withValues(alpha: 0.95)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.devices_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usar ajustes del dispositivo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sigue el tema activo del sistema y déjalo como valor predeterminado al instalar la app.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                if (isEnabled) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Ahora mismo se está aplicando: $resolvedLabel',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: isEnabled,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}