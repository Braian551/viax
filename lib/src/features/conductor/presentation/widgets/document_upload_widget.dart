import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:viax/src/theme/app_colors.dart';

enum DocumentType {
  image,
  pdf,
  any,
}

class DocumentUploadWidget extends StatelessWidget {
  final String label;
  final String? subtitle;
  final String? filePath;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final IconData icon;
  final DocumentType acceptedType;
  final bool isRequired;
  final bool allowGallery; // New parameter to restrict gallery

  const DocumentUploadWidget({
    super.key,
    required this.label,
    this.subtitle,
    required this.filePath,
    required this.onTap,
    this.onRemove,
    this.icon = Icons.upload_file_rounded,
    this.acceptedType = DocumentType.any,
    this.isRequired = false,
    this.allowGallery = true, // Default to true for backward compatibility
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = filePath != null && filePath!.isNotEmpty;
    final isPdf = hasFile && filePath!.toLowerCase().endsWith('.pdf');

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasFile
                    ? const Color(0xFFFFFF00).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // PrevisualizaciÃ³n o icono
                    _buildPreview(hasFile, isPdf),
                    const SizedBox(width: 16),
                    
                    // InformaciÃ³n del documento
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isRequired && !hasFile)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Requerido',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasFile
                                ? _getFileName()
                                : subtitle ?? _getAcceptedTypesText(),
                            style: TextStyle(
                              color: hasFile
                                  ? const Color(0xFFFFFF00)
                                  : Colors.white54,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    // Icono de acciÃ³n
                    if (hasFile && onRemove != null)
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.redAccent,
                          size: 24,
                        ),
                        onPressed: onRemove,
                        tooltip: 'Eliminar',
                      )
                    else
                      Icon(
                        hasFile
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        color: hasFile
                            ? const Color(0xFFFFFF00)
                            : Colors.white.withValues(alpha: 0.3),
                        size: 28,
                      ),
                  ],
                ),
                
                // BotÃ³n de vista previa ampliada (solo para imÃ¡genes)
                if (hasFile && !isPdf)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextButton.icon(
                      onPressed: () => _showFullPreview(context),
                      icon: const Icon(
                        Icons.visibility_rounded,
                        size: 18,
                        color: Color(0xFFFFFF00),
                      ),
                      label: const Text(
                        'Ver imagen completa',
                        style: TextStyle(
                          color: Color(0xFFFFFF00),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        backgroundColor: const Color(0xFFFFFF00).withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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

  Widget _buildPreview(bool hasFile, bool isPdf) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: hasFile
            ? const Color(0xFFFFFF00).withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFile
              ? const Color(0xFFFFFF00).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: hasFile
          ? isPdf
              ? _buildPdfPreview()
              : _buildImagePreview()
          : _buildEmptyPreview(),
    );
  }

  Widget _buildImagePreview() {
    final isRemoteUrl = filePath!.startsWith('http://') || filePath!.startsWith('https://');
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          isRemoteUrl
              ? Image.network(
                  filePath!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade800,
                      child: const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white54,
                        size: 32,
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey.shade800,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFFF00)),
                        ),
                      ),
                    );
                  },
                )
              : Image.file(
                  File(filePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade800,
                      child: const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white54,
                        size: 32,
                      ),
                    );
                  },
                ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfPreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.picture_as_pdf_rounded,
          color: Colors.red.shade400,
          size: 36,
        ),
        const SizedBox(height: 4),
        const Text(
          'PDF',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPreview() {
    return Icon(
      icon,
      color: Colors.white.withValues(alpha: 0.4),
      size: 36,
    );
  }

  String _getFileName() {
    if (filePath == null || filePath!.isEmpty) return '';
    final file = File(filePath!);
    final name = file.path.split('/').last;
    
    // Si el nombre es muy largo, mostrar solo el inicio y el final
    if (name.length > 30) {
      return '${name.substring(0, 15)}...${name.substring(name.length - 10)}';
    }
    return name;
  }

  String _getAcceptedTypesText() {
    switch (acceptedType) {
      case DocumentType.image:
        return allowGallery ? 'Toca para seleccionar imagen' : 'Toca para tomar foto';
      case DocumentType.pdf:
        return 'Toca para seleccionar PDF';
      case DocumentType.any:
        return 'Imagen o PDF';
    }
  }

  void _showFullPreview(BuildContext context) {
    if (filePath == null || filePath!.isEmpty) return;

    final isRemoteUrl = filePath!.startsWith('http://') || filePath!.startsWith('https://');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Imagen
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: isRemoteUrl
                          ? Image.network(
                              filePath!,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.broken_image_rounded,
                                        color: Colors.white54,
                                        size: 64,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No se pudo cargar la imagen',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.7),
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFFF00)),
                                  ),
                                );
                              },
                            )
                          : Image.file(
                              File(filePath!),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.broken_image_rounded,
                                        color: Colors.white54,
                                        size: 64,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No se pudo cargar la imagen',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.7),
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ),
              
              // BotÃ³n cerrar
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              
              // Indicador de nombre del archivo
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: Color(0xFFFFFF00),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getFileName(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper para mostrar bottom sheet de selección de documento
class DocumentPickerHelper {
  static Future<String?> showPickerOptions({
    required BuildContext context,
    required DocumentType documentType,
    bool allowGallery = true,
  }) async {
    // Si no se permite galería pero el tipo es 'any', mostrar opciones de cámara y PDF
    if (!allowGallery && documentType == DocumentType.any) {
      return await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _DocumentPickerBottomSheet(
          documentType: documentType,
          allowGallery: false, // No galería, pero sí cámara y PDF
        ),
      );
    }
    
    // Si no se permite galería y es solo tipo imagen, abrir cámara directamente con guías visuales
    if (!allowGallery && documentType == DocumentType.image) {
      // Mostrar guías visuales antes
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => const _DocumentGuidesDialog(guideType: DocumentGuideType.camera),
      );
      
      if (proceed == true) {
        return 'camera';
      }
      return null;
    }

    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _DocumentPickerBottomSheet(
        documentType: documentType,
        allowGallery: allowGallery,
      ),
    );

    return source;
  }

  static Future<String?> pickDocument({
    required BuildContext context,
    required DocumentType documentType,
    bool allowGallery = true,
  }) async {
    try {
      final action = await showPickerOptions(
        context: context,
        documentType: documentType,
        allowGallery: allowGallery,
      );

      if (action == null) {
        debugPrint('Usuario cancelÃ³ la selecciÃ³n de documento');
        return null;
      }

      debugPrint('AcciÃ³n seleccionada: $action');

      if (action == 'pdf') {
        // Seleccionar PDF
        debugPrint('Seleccionando PDF...');
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (result != null && result.files.single.path != null) {
          final path = result.files.single.path!;
          debugPrint('PDF seleccionado: $path');
          return path;
        } else {
          debugPrint('No se seleccionÃ³ ningÃºn PDF');
        }
      } else {
        // Seleccionar imagen
        
        // Si la accion es camara, mostrar guias (doble verificacion si se llama directo)
        if (action == 'camera') {
           // Las guias ya se mostraron en showPickerOptions si !allowGallery
           // Pero si llego aqui via bottom sheet (allowGallery=true), no se mostraron
           // Seria bueno mostrarlas siempre para la camara?
           // Por ahora asumimos que si !allowGallery, ya se mostraron.
        }

        debugPrint('Seleccionando imagen desde: $action');
        final ImageSource source = action == 'camera'
            ? ImageSource.camera
            : ImageSource.gallery;
        
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );

        if (image != null) {
          debugPrint('Imagen seleccionada: ${image.path}');
          debugPrint('TamaÃ±o original: ${await image.length()} bytes');

          // Verificar que el archivo existe
          final file = File(image.path);
          if (await file.exists()) {
            debugPrint('Archivo existe en el sistema de archivos');
            return image.path;
          } else {
            debugPrint('Archivo no existe despuÃ©s de ser seleccionado');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error: La imagen no se guardÃ³ correctamente'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return null;
          }
        } else {
          debugPrint('No se seleccionÃ³ ninguna imagen');
        }
      }
    } catch (e) {
      debugPrint('Error al seleccionar documento: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar documento: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    return null;
  }
}

/// Tipos de guía para documentos
enum DocumentGuideType { camera, pdf }

/// Diálogo de guías visuales reutilizable para cámara y PDF
class _DocumentGuidesDialog extends StatelessWidget {
  final DocumentGuideType guideType;
  
  const _DocumentGuidesDialog({required this.guideType});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCamera = guideType == DocumentGuideType.camera;
    
    // Configuración según el tipo
    final icon = isCamera ? Icons.camera_alt_rounded : Icons.picture_as_pdf_rounded;
    final color = isCamera ? AppColors.primary : Colors.red;
    final title = isCamera ? 'Instrucciones para la foto' : 'Instrucciones para PDF';
    final buttonText = isCamera ? 'Entendido, abrir cámara' : 'Entendido, seleccionar PDF';
    
    final guides = isCamera 
        ? [
            _GuideItem(Icons.crop_free_rounded, 'Documento completo', 'Asegúrate de que se vean las 4 esquinas'),
            _GuideItem(Icons.wb_sunny_rounded, 'Buena iluminación', 'Evita sombras sobre el texto'),
            _GuideItem(Icons.flash_off_rounded, 'Sin reflejos', 'Evita el uso del flash directo'),
          ]
        : [
            _GuideItem(Icons.description_rounded, 'Documento legible', 'Asegúrate que el PDF sea claro y legible'),
            _GuideItem(Icons.storage_rounded, 'Tamaño máximo', 'El archivo no debe superar 10MB'),
            _GuideItem(Icons.verified_rounded, 'Documento oficial', 'Usa el documento original, no escaneados de baja calidad'),
          ];
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark 
                  ? AppColors.darkSurface.withValues(alpha: 0.95) 
                  : AppColors.lightSurface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ícono principal
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 40),
                    ),
                    const SizedBox(height: 20),
                    
                    // Título
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // Guías
                    ...guides.map((guide) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildGuideRow(context, guide, isDark),
                    )),
                    
                    const SizedBox(height: 16),
                    
                    // Botón de acción
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          buttonText, 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideRow(BuildContext context, _GuideItem guide, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(guide.icon, color: isDark ? Colors.white70 : Colors.black54, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                guide.title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                guide.subtitle,
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 14,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideItem {
  final IconData icon;
  final String title;
  final String subtitle;
  
  const _GuideItem(this.icon, this.title, this.subtitle);
}

/// Bottom sheet para seleccionar tipo de documento (cámara, galería, PDF)
class _DocumentPickerBottomSheet extends StatelessWidget {
  final DocumentType documentType;
  final bool allowGallery;

  const _DocumentPickerBottomSheet({
    required this.documentType,
    required this.allowGallery,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark 
                ? AppColors.darkSurface.withValues(alpha: 0.95)
                : AppColors.lightSurface.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Título
                Text(
                  'Seleccionar documento',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Elige cómo quieres subir tu documento',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Opciones según el tipo de documento aceptado
                if (documentType == DocumentType.image || documentType == DocumentType.any)
                  _buildPickerOption(
                    context: context,
                    isDark: isDark,
                    icon: Icons.camera_alt_rounded,
                    title: 'Tomar foto',
                    subtitle: 'Usa la cámara del dispositivo',
                    color: AppColors.primary,
                    onTap: () => _handleCameraOption(context),
                  ),
                
                if (allowGallery && (documentType == DocumentType.image || documentType == DocumentType.any))
                  _buildPickerOption(
                    context: context,
                    isDark: isDark,
                    icon: Icons.photo_library_rounded,
                    title: 'Galería de fotos',
                    subtitle: 'Selecciona una imagen existente',
                    color: Colors.purple,
                    onTap: () => Navigator.pop(context, 'gallery'),
                  ),
                
                if (documentType == DocumentType.pdf || documentType == DocumentType.any)
                  _buildPickerOption(
                    context: context,
                    isDark: isDark,
                    icon: Icons.picture_as_pdf_rounded,
                    title: 'Archivo PDF',
                    subtitle: 'Selecciona un documento PDF',
                    color: Colors.red,
                    onTap: () => _handlePdfOption(context),
                  ),
                
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCameraOption(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => const _DocumentGuidesDialog(guideType: DocumentGuideType.camera),
    );
    if (context.mounted && proceed == true) {
      Navigator.pop(context, 'camera');
    }
  }

  Future<void> _handlePdfOption(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => const _DocumentGuidesDialog(guideType: DocumentGuideType.pdf),
    );
    if (context.mounted && proceed == true) {
      Navigator.pop(context, 'pdf');
    }
  }

  Widget _buildPickerOption({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.05) 
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.08) 
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
