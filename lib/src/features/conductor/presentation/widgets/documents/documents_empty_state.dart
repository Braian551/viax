import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Estado vacío para documentos
class DocumentsEmptyState extends StatefulWidget {
  final String? errorMessage;
  final VoidCallback? onRetry;

  const DocumentsEmptyState({
    super.key,
    this.errorMessage,
    this.onRetry,
  });

  @override
  State<DocumentsEmptyState> createState() => _DocumentsEmptyStateState();
}

class _DocumentsEmptyStateState extends State<DocumentsEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isError = widget.errorMessage != null;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: (isError ? AppColors.error : AppColors.primary)
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isError
                            ? Icons.error_outline_rounded
                            : Icons.folder_open_rounded,
                        size: 60,
                        color: isError ? AppColors.error : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isError
                          ? 'Error al cargar documentos'
                          : 'Sin Documentos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isError
                          ? widget.errorMessage!
                          : 'No hay documentos para mostrar en este momento.',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? Colors.white70
                            : AppColors.lightTextSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (widget.onRetry != null)
                      OutlinedButton.icon(
                        onPressed: widget.onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
