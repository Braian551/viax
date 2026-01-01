import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Pantalla para visualizar documentos/imágenes en pantalla completa
/// Diseño moderno con soporte para zoom, descarga y tema de la app
class DocumentViewerScreen extends StatefulWidget {
  final String documentUrl;
  final String documentName;

  const DocumentViewerScreen({
    super.key,
    required this.documentUrl,
    required this.documentName,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, textColor, surfaceColor, isDark),
      body: _buildBody(context, textColor, secondaryText, isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Color textColor,
    Color surfaceColor,
    bool isDark,
  ) {
    return AppBar(
      backgroundColor: surfaceColor.withValues(alpha: 0.95),
      elevation: 0,
      centerTitle: true,
      leading: _buildBackButton(context, textColor),
      title: _buildTitle(textColor),
      actions: [
        _buildCopyUrlButton(context),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBackButton(BuildContext context, Color textColor) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20),
        onPressed: () => Navigator.pop(context),
        tooltip: 'Volver',
      ),
    );
  }

  Widget _buildTitle(Color textColor) {
    return Column(
      children: [
        Text(
          widget.documentName,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          'Desliza para hacer zoom',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildCopyUrlButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
        onPressed: () => _copyUrlToClipboard(context),
        tooltip: 'Copiar URL',
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Color textColor,
    Color secondaryText,
    bool isDark,
  ) {
    return SafeArea(
      child: Center(
        child: Hero(
          tag: 'document_${widget.documentUrl}',
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            child: _buildImage(textColor, secondaryText, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(Color textColor, Color secondaryText, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        widget.documentUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            // Image loaded successfully
            if (_isLoading) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  _animationController.forward();
                }
              });
            }
            return FadeTransition(
              opacity: _fadeAnimation,
              child: child,
            );
          }
          return _buildLoadingIndicator(loadingProgress);
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget(textColor, secondaryText, isDark);
        },
      ),
    );
  }

  Widget _buildLoadingIndicator(ImageChunkEvent loadingProgress) {
    final progress = loadingProgress.expectedTotalBytes != null
        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
        : null;

    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
              value: progress,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            progress != null ? '${(progress * 100).toInt()}%' : 'Cargando...',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(Color textColor, Color secondaryText, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.image_not_supported_rounded,
              color: AppColors.error,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Error al cargar la imagen',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No se pudo cargar el documento.\nVerifica tu conexión a internet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondaryText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => setState(() {}), // Retry
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyUrlToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.documentUrl));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            const Text(
              'URL copiada al portapapeles',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}