import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Modelo para un documento
class DocumentItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final DocumentStatus status;
  final String? expirationDate;
  final String? imageUrl;

  DocumentItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
    this.expirationDate,
    this.imageUrl,
  });
}

enum DocumentStatus {
  pending,
  approved,
  rejected,
  expired,
  missing,
}

/// Tarjeta de documento individual
class DocumentCard extends StatefulWidget {
  final DocumentItem document;
  final VoidCallback? onTap;
  final VoidCallback? onUpload;
  final int animationIndex;

  const DocumentCard({
    super.key,
    required this.document,
    this.onTap,
    this.onUpload,
    this.animationIndex = 0,
  });

  @override
  State<DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<DocumentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 400 + (widget.animationIndex * 100)),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOut),
      ),
    );

    Future.delayed(Duration(milliseconds: widget.animationIndex * 80), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (widget.document.status) {
      case DocumentStatus.approved:
        return AppColors.success;
      case DocumentStatus.pending:
        return AppColors.warning;
      case DocumentStatus.rejected:
        return AppColors.error;
      case DocumentStatus.expired:
        return Colors.orange;
      case DocumentStatus.missing:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (widget.document.status) {
      case DocumentStatus.approved:
        return 'Aprobado';
      case DocumentStatus.pending:
        return 'Pendiente';
      case DocumentStatus.rejected:
        return 'Rechazado';
      case DocumentStatus.expired:
        return 'Vencido';
      case DocumentStatus.missing:
        return 'Sin cargar';
    }
  }

  IconData _getStatusIcon() {
    switch (widget.document.status) {
      case DocumentStatus.approved:
        return Icons.check_circle_rounded;
      case DocumentStatus.pending:
        return Icons.pending_rounded;
      case DocumentStatus.rejected:
        return Icons.cancel_rounded;
      case DocumentStatus.expired:
        return Icons.schedule_rounded;
      case DocumentStatus.missing:
        return Icons.upload_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _getStatusColor();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: GestureDetector(
                onTap: widget.onTap,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCard.withValues(alpha: 0.6)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Icono del documento
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          widget.document.icon,
                          size: 28,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Info del documento
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.document.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.document.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white60
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            if (widget.document.expirationDate != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Vence: ${widget.document.expirationDate}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.document.status ==
                                          DocumentStatus.expired
                                      ? AppColors.error
                                      : (isDark
                                          ? Colors.white54
                                          : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Status y acción
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(),
                                  size: 14,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getStatusText(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.document.status == DocumentStatus.missing ||
                              widget.document.status == DocumentStatus.rejected ||
                              widget.document.status == DocumentStatus.expired)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: GestureDetector(
                                onTap: widget.onUpload,
                                child: Text(
                                  'Subir',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
