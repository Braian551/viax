import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Resumen del estado de documentos
class DocumentsSummaryCard extends StatefulWidget {
  final int totalDocuments;
  final int approvedDocuments;
  final int pendingDocuments;
  final int rejectedDocuments;

  const DocumentsSummaryCard({
    super.key,
    required this.totalDocuments,
    required this.approvedDocuments,
    required this.pendingDocuments,
    required this.rejectedDocuments,
  });

  @override
  State<DocumentsSummaryCard> createState() => _DocumentsSummaryCardState();
}

class _DocumentsSummaryCardState extends State<DocumentsSummaryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
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

    final progress = widget.totalDocuments > 0
        ? widget.approvedDocuments / widget.totalDocuments
        : 0.0;

    final isComplete = widget.approvedDocuments == widget.totalDocuments &&
        widget.totalDocuments > 0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isComplete
                    ? [
                        AppColors.success.withValues(alpha: 0.15),
                        AppColors.success.withValues(alpha: 0.05),
                      ]
                    : [
                        AppColors.primary.withValues(alpha: 0.15),
                        isDark
                            ? AppColors.darkCard.withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.9),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isComplete ? AppColors.success : AppColors.primary)
                    .withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isComplete ? AppColors.success : AppColors.primary)
                      .withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Indicador circular
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: Stack(
                        children: [
                          SizedBox(
                            width: 70,
                            height: 70,
                            child: CircularProgressIndicator(
                              value: _progressAnimation.value * progress,
                              strokeWidth: 6,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation(
                                isComplete ? AppColors.success : AppColors.primary,
                              ),
                            ),
                          ),
                          Center(
                            child: isComplete
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 32,
                                    color: AppColors.success,
                                  )
                                : Text(
                                    '${(progress * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isComplete
                                ? '¡Documentos Completos!'
                                : 'Documentación',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isComplete
                                ? 'Todos tus documentos están al día'
                                : '${widget.approvedDocuments} de ${widget.totalDocuments} documentos aprobados',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Estadísticas
                Row(
                  children: [
                    _buildStatItem(
                      icon: Icons.check_circle_rounded,
                      value: widget.approvedDocuments.toString(),
                      label: 'Aprobados',
                      color: AppColors.success,
                      isDark: isDark,
                    ),
                    _buildStatItem(
                      icon: Icons.pending_rounded,
                      value: widget.pendingDocuments.toString(),
                      label: 'Pendientes',
                      color: AppColors.warning,
                      isDark: isDark,
                    ),
                    _buildStatItem(
                      icon: Icons.cancel_rounded,
                      value: widget.rejectedDocuments.toString(),
                      label: 'Rechazados',
                      color: AppColors.error,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
