import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Pantalla para visualizar documentos en pantalla completa
class DocumentViewerScreen extends StatelessWidget {
  final String documentUrl;
  final String documentName;

  const DocumentViewerScreen({
    required this.documentUrl,
    required this.documentName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
      appBar: AppBar(
        backgroundColor: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          documentName,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.download_rounded, color: AppColors.primary),
            onPressed: () => _showDownloadInfo(context),
            tooltip: 'Información de descarga',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            documentUrl,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar el documento',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    documentUrl,
                    style: TextStyle(
                      color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDownloadInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Text('URL del Documento', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Para descargar el documento, copia esta URL:',
              style: TextStyle(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                documentUrl,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white70)),
          ),
        ],
      ),
    );
  }
}