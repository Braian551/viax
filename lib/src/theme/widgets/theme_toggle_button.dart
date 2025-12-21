import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/theme/theme_provider.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Widget de botón para cambiar el tema
/// Muestra el icono actual del tema y permite alternarlo
class ThemeToggleButton extends StatelessWidget {
  /// Tamaño del botón (por defecto: 48)
  final double size;
  
  /// Si se muestra el borde
  final bool showBorder;
  
  /// Color de fondo personalizado
  final Color? backgroundColor;

  const ThemeToggleButton({
    super.key,
    this.size = 48,
    this.showBorder = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? (isDark ? AppColors.darkSurface : AppColors.lightSurface),
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: isDark 
                    ? AppColors.darkDivider 
                    : AppColors.lightDivider,
                width: 1,
              )
            : null,
        boxShadow: showBorder
            ? [
                BoxShadow(
                  color: isDark 
                      ? AppColors.darkShadow 
                      : AppColors.lightShadow,
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => themeProvider.toggleTheme(),
          borderRadius: BorderRadius.circular(size / 2),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: Icon(
                themeProvider.themeModeIcon,
                key: ValueKey(themeProvider.themeModeIcon),
                color: isDark ? AppColors.primary : AppColors.primaryDark,
                size: size * 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget de selector de tema con opciones
/// Permite elegir entre modo claro, oscuro o sistema
class ThemeSelectorDialog extends StatelessWidget {
  const ThemeSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seleccionar tema',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            
            // Opción: Modo del Sistema
            _ThemeOption(
              icon: Icons.brightness_auto,
              title: 'Tema del Sistema',
              subtitle: 'Usar la configuración del dispositivo',
              isSelected: themeProvider.isSystemMode,
              onTap: () {
                themeProvider.setSystemMode();
                Navigator.of(context).pop();
              },
            ),
            
            const SizedBox(height: 12),
            
            // Opción: Modo Claro
            _ThemeOption(
              icon: Icons.light_mode,
              title: 'Modo Claro',
              subtitle: 'Colores brillantes y claros',
              isSelected: themeProvider.themeMode == ThemeMode.light,
              onTap: () {
                themeProvider.setLightMode();
                Navigator.of(context).pop();
              },
            ),
            
            const SizedBox(height: 12),
            
            // Opción: Modo Oscuro
            _ThemeOption(
              icon: Icons.dark_mode,
              title: 'Modo Oscuro',
              subtitle: 'Colores oscuros para la noche',
              isSelected: themeProvider.themeMode == ThemeMode.dark,
              onTap: () {
                themeProvider.setDarkMode();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Muestra el diálogo de selección de tema
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const ThemeSelectorDialog(),
    );
  }
}

/// Widget interno para cada opción de tema
class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkCard : AppColors.lightCard),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
