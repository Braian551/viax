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
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(
                      alpha: isDark ? 0.26 : 0.72,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ThemePreviewOption(
                            label: 'Claro',
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ThemePreviewOption(
                            label: 'Oscuro',
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
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Usar ajustes del dispositivo',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Seguir el tema activo del sistema y dejarlo como predeterminado al instalar la app.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Switch.adaptive(
                          value: themeProvider.isSystemMode,
                          onChanged: (value) =>
                              _setSystemMode(context, themeProvider, value),
                        ),
                      ],
                    ),
                    if (themeProvider.isSystemMode) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Ahora mismo se está aplicando: ${themeProvider.isDarkMode ? 'Oscuro' : 'Claro'}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  const _ThemePreviewOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          child,
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
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
                    Icons.circle,
                    size: 12,
                    color: colorScheme.onPrimary,
                  )
                : null,
          ),
        ],
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
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkPreview ? const Color(0xFF0F1014) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isActive
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.7),
          width: isActive ? 2 : 1,
        ),
        boxShadow: isDarkPreview
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDarkPreview ? Colors.white10 : Colors.black12,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.music_note_rounded,
                color: isDarkPreview ? Colors.white70 : Colors.black87,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 8,
            width: 72,
            decoration: BoxDecoration(
              color: isDarkPreview ? Colors.white12 : Colors.black12,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            width: 48,
            decoration: BoxDecoration(
              color: isDarkPreview ? Colors.white10 : Colors.black12,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(child: _PreviewColorBlock(color: const Color(0xFF69D7A2))),
              const SizedBox(width: 4),
              Expanded(child: _PreviewColorBlock(color: const Color(0xFF8792E0))),
              const SizedBox(width: 4),
              Expanded(child: _PreviewColorBlock(color: const Color(0xFFF8DF7B))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _PreviewColorBlock(color: const Color(0xFFA7B0B9))),
              const SizedBox(width: 4),
              Expanded(child: _PreviewColorBlock(color: const Color(0xFFD0BC63))),
              const SizedBox(width: 4),
              Expanded(child: _PreviewColorBlock(color: const Color(0xFFD18A62))),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewColorBlock extends StatelessWidget {
  final Color color;

  const _PreviewColorBlock({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}