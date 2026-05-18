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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final shellPadding = screenWidth < 360 ? 16.0 : 20.0;
    final panelPadding = screenWidth < 360 ? 16.0 : 20.0;

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
          // Reducir el margen lateral en móviles deja más ancho útil para decidir entre fila o columna sin apretar las previews.
          padding: EdgeInsets.fromLTRB(shellPadding, 16, shellPadding, 32),
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
                padding: EdgeInsets.all(panelPadding),
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
                        final optionSpacing =
                            constraints.maxWidth < 300 ? 8.0 : 10.0;
                        final shouldStackOptions = constraints.maxWidth < 340;

                        final lightOption = _ThemePreviewOption(
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
                        );
                        final darkOption = _ThemePreviewOption(
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
                        );

                        // En anchos compactos conviene apilar las tarjetas para evitar el overflow del mock interno.
                        if (shouldStackOptions) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              lightOption,
                              SizedBox(height: optionSpacing),
                              darkOption,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: lightOption),
                            SizedBox(width: optionSpacing),
                            Expanded(child: darkOption),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 150;
        final isDense = constraints.maxWidth < 132;
        final optionPadding = isDense ? 9.0 : (isCompact ? 10.0 : 12.0);
        final optionRadius = isDense ? 18.0 : 22.0;
        final childSpacing = isDense ? 8.0 : 10.0;
        final labelSpacing = isDense ? 4.0 : 6.0;
        final selectorSize = isDense ? 20.0 : (isCompact ? 22.0 : 24.0);
        final selectorIconSize = isDense ? 11.0 : 13.0;
        final subtitleHeight = isDense ? 60.0 : 52.0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(optionRadius),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.all(optionPadding),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.08)
                    : colorScheme.surface.withValues(alpha: isDark ? 0.78 : 0.96),
                borderRadius: BorderRadius.circular(optionRadius),
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
                mainAxisSize: MainAxisSize.max,
                children: [
                  child,
                  SizedBox(height: childSpacing),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: (isCompact
                                  ? theme.textTheme.titleSmall
                                  : theme.textTheme.titleMedium)
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: selectorSize,
                        height: selectorSize,
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
                                size: selectorIconSize,
                                color: colorScheme.onPrimary,
                              )
                            : null,
                      ),
                    ],
                  ),
                  SizedBox(height: labelSpacing),
                  // Reservar el mismo bloque de texto mantiene alineadas ambas tarjetas aunque cambie el copy.
                  SizedBox(
                    height: subtitleHeight,
                    child: Text(
                      subtitle,
                      maxLines: isDense ? 4 : 3,
                      overflow: TextOverflow.fade,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: isDense ? 1.2 : 1.3,
                        fontSize: isDense ? 11.2 : 11.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewWidth = constraints.maxWidth;
        final isCompact = previewWidth < 150;
        final isDense = previewWidth < 132;
        final outerRadius = isDense ? 16.0 : (isCompact ? 18.0 : 20.0);
        final innerRadius = isDense ? 12.0 : (isCompact ? 14.0 : 16.0);
        final framePadding = isDense ? 7.0 : (isCompact ? 8.0 : 10.0);
        final surfacePadding = isDense ? 7.0 : (isCompact ? 8.0 : 10.0);
        final navSpacing = isDense ? 6.0 : 8.0;
        final smallGap = isDense ? 2.0 : 3.0;
        final mediumGap = isDense ? 6.0 : 8.0;
        final largeGap = isDense ? 7.0 : 9.0;
        final topBarHorizontal = isDense ? 7.0 : 8.0;
        final topBarVertical = isDense ? 5.0 : 6.0;
        final navBubbleSize = isDense ? 18.0 : (isCompact ? 20.0 : 22.0);
        final topIconSize = isDense ? 11.0 : 12.0;
        final navIconSize = isDense ? 13.0 : 15.0;
        final statMargin = isDense ? 4.0 : 5.0;
        final statRadius = isDense ? 10.0 : 12.0;
        final statIconSize = isDense ? 13.0 : 14.0;
        final bottomPadding = isDense ? 5.0 : 6.0;
        final bottomHorizontal = isDense ? 6.0 : 8.0;
        final bottomVertical = isDense ? 4.0 : 5.0;
        final activeIndicatorSize = isDense ? 5.0 : 6.0;
        final selectedNavGap = isDense ? 3.0 : 4.0;
        final trailingNavBox = isDense ? 22.0 : 24.0;
        final aspectRatio = isDense ? 0.72 : (isCompact ? 0.7 : 0.68);

        // Mantener una proporción más vertical hace que la preview respire mejor sin romper la fila.
        return AspectRatio(
          aspectRatio: aspectRatio,
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
              borderRadius: BorderRadius.circular(outerRadius),
              border: Border.all(
                color: borderColor,
                width: isActive ? 1.6 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDarkPreview ? 0.22 : 0.08,
                  ),
                  blurRadius: isDense ? 14 : 20,
                  offset: Offset(0, isDense ? 8 : 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(outerRadius),
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
                        padding: EdgeInsets.all(framePadding),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: topBarHorizontal,
                                    vertical: topBarVertical,
                                  ),
                                  decoration: BoxDecoration(
                                    color: surfaceColor,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: surfaceBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: navBubbleSize,
                                        height: navBubbleSize,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: isDarkPreview ? 0.22 : 0.12,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.navigation_rounded,
                                          color: AppColors.primary,
                                          size: topIconSize,
                                        ),
                                      ),
                                      SizedBox(width: isDense ? 6 : 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _PreviewLine(
                                              widthFactor: isDense ? 0.38 : 0.34,
                                              height: isDense ? 3.5 : 4,
                                              color: secondaryText,
                                            ),
                                            SizedBox(height: smallGap),
                                            _PreviewLine(
                                              widthFactor: isDense ? 0.72 : 0.68,
                                              height: isDense ? 5 : 6,
                                              color: primaryText,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.notifications_none_rounded,
                                        size: topIconSize,
                                        color: primaryText,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: largeGap),
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(surfacePadding),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(innerRadius),
                                  border: Border.all(color: surfaceBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _PreviewLine(
                                      widthFactor: isDense ? 0.48 : 0.44,
                                      height: isDense ? 5 : 6,
                                      color: primaryText,
                                    ),
                                    SizedBox(height: isDense ? 5 : 6),
                                    _PreviewLine(
                                      widthFactor: isDense ? 0.72 : 0.66,
                                      height: isDense ? 3.5 : 4,
                                      color: secondaryText,
                                    ),
                                    SizedBox(height: mediumGap),
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
                                          borderRadius: BorderRadius.circular(
                                            isDense ? 14 : 18,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _PreviewStatBlock(
                                                icon: Icons.location_on_rounded,
                                                color: isDarkPreview
                                                    ? Colors.white
                                                    : AppColors.primary,
                                                margin: statMargin,
                                                borderRadius: statRadius,
                                                iconSize: statIconSize,
                                              ),
                                            ),
                                            Expanded(
                                              child: _PreviewStatBlock(
                                                icon: Icons.route_rounded,
                                                color: isDarkPreview
                                                    ? Colors.white70
                                                    : AppColors.lightTextSecondary,
                                                margin: statMargin,
                                                borderRadius: statRadius,
                                                iconSize: statIconSize,
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
                            SizedBox(height: largeGap),
                            Container(
                              padding: EdgeInsets.all(bottomPadding),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: surfaceBorder),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // El item activo usa un pill compacto para que el icono de inicio nunca se quede sin ancho.
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: bottomHorizontal,
                                      vertical: bottomVertical,
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
                                          size: navIconSize,
                                          color: isDarkPreview
                                              ? Colors.white
                                              : AppColors.primary,
                                        ),
                                        SizedBox(width: selectedNavGap),
                                        Container(
                                          width: activeIndicatorSize,
                                          height: activeIndicatorSize,
                                          decoration: BoxDecoration(
                                            color: isDarkPreview
                                                ? Colors.white.withValues(
                                                    alpha: 0.88,
                                                  )
                                                : AppColors.primary.withValues(
                                                    alpha: 0.62,
                                                  ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: navSpacing),
                                  SizedBox(
                                    width: trailingNavBox,
                                    child: Center(
                                      child: Icon(
                                        Icons.history_rounded,
                                        size: navIconSize,
                                        color: secondaryText,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: navSpacing),
                                  SizedBox(
                                    width: trailingNavBox,
                                    child: Center(
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: navIconSize,
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
      },
    );
  }
}

class _PreviewStatBlock extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double margin;
  final double borderRadius;
  final double iconSize;

  const _PreviewStatBlock({
    required this.icon,
    required this.color,
    required this.margin,
    required this.borderRadius,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(margin),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(icon, size: iconSize, color: color),
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  final double widthFactor;
  final double height;
  final Color color;

  const _PreviewLine({
    required this.widthFactor,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
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