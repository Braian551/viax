import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Widget reutilizable para seleccionar/mostrar foto de perfil.
/// 
/// Muestra una imagen circular con overlay para cambiar la foto.
/// Soporta mostrar imagen desde URL (R2), archivo local, o placeholder.
/// 
/// Uso:
/// ```dart
/// ProfilePhotoPicker(
///   imageUrl: 'https://...',        // Imagen actual desde servidor
///   imageFile: _selectedFile,        // Archivo local seleccionado
///   onImageSelected: (file) => setState(() => _selectedFile = file),
///   size: 120,
/// )
/// ```
class ProfilePhotoPicker extends StatefulWidget {
  /// URL de la imagen actual (desde R2/servidor)
  final String? imageUrl;
  
  /// Archivo de imagen seleccionado localmente (tiene prioridad sobre imageUrl)
  final File? imageFile;
  
  /// Callback cuando se selecciona una nueva imagen
  final ValueChanged<File?> onImageSelected;
  
  /// Callback para eliminar la foto actual
  final VoidCallback? onPhotoRemoved;
  
  /// Tamaño del widget (ancho y alto)
  final double size;
  
  /// Si está habilitado para seleccionar imagen
  final bool enabled;
  
  /// Icono a mostrar cuando no hay imagen
  final IconData placeholderIcon;

  const ProfilePhotoPicker({
    super.key,
    this.imageUrl,
    this.imageFile,
    required this.onImageSelected,
    this.onPhotoRemoved,
    this.size = 120,
    this.enabled = true,
    this.placeholderIcon = Icons.person,
  });

  @override
  State<ProfilePhotoPicker> createState() => _ProfilePhotoPickerState();
}

class _ProfilePhotoPickerState extends State<ProfilePhotoPicker> {
  bool _isPickingImage = false;

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickingImage || !widget.enabled) return;
    
    setState(() => _isPickingImage = true);

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800, // Redimensionar para optimizar
        maxHeight: 800,
        imageQuality: 85, // Comprimir un poco
      );

      if (pickedFile != null) {
        widget.onImageSelected(File(pickedFile.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _showImageSourceDialog() {
    if (!widget.enabled) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ImageSourceBottomSheet(
        onCameraSelected: () {
          Navigator.pop(context);
          _pickImage(ImageSource.camera);
        },
        onGallerySelected: () {
          Navigator.pop(context);
          _pickImage(ImageSource.gallery);
        },
        onRemoveSelected: (widget.imageFile != null || (widget.imageUrl?.isNotEmpty ?? false)) && widget.onPhotoRemoved != null
            ? () {
                Navigator.pop(context);
                widget.onPhotoRemoved!();
              }
            : null,
      ),
    );
  }

  Widget _buildImage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Prioridad: archivo local > URL > placeholder
    if (widget.imageFile != null) {
      return ClipOval(
        child: Image.file(
          widget.imageFile!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
        ),
      );
    }

    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          widget.imageUrl!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
        ),
      );
    }

    return _buildPlaceholder(isDark);
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? AppColors.darkCard : AppColors.blue50,
            isDark ? AppColors.darkSurface : AppColors.blue100,
          ],
        ),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Icon(
        widget.placeholderIcon,
        size: widget.size * 0.4,
        color: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: widget.enabled ? _showImageSourceDialog : null,
      child: Stack(
        children: [
          // Imagen principal
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: _buildImage(),
          ),
          
          // Overlay de edición
          if (widget.enabled)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: widget.size * 0.32,
                height: widget.size * 0.32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  border: Border.all(
                    color: isDark ? AppColors.darkBackground : Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isPickingImage
                    ? const Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        Icons.camera_alt,
                        size: widget.size * 0.16,
                        color: Colors.white,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// BottomSheet para seleccionar fuente de imagen
class _ImageSourceBottomSheet extends StatelessWidget {
  final VoidCallback onCameraSelected;
  final VoidCallback onGallerySelected;
  final VoidCallback? onRemoveSelected;

  const _ImageSourceBottomSheet({
    required this.onCameraSelected,
    required this.onGallerySelected,
    this.onRemoveSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Título
            Text(
              'Seleccionar foto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Opciones
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOption(
                  context,
                  icon: Icons.camera_alt,
                  label: 'Cámara',
                  onTap: onCameraSelected,
                  isDark: isDark,
                ),
                _buildOption(
                  context,
                  icon: Icons.photo_library,
                  label: 'Galería',
                  onTap: onGallerySelected,
                  isDark: isDark,
                ),
                if (onRemoveSelected != null)
                  _buildOption(
                    context,
                    icon: Icons.delete_outline,
                    label: 'Eliminar',
                    onTap: onRemoveSelected!,
                    isDark: isDark,
                    isDestructive: true,
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Botón cancelar
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 16,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    bool isDestructive = false,
  }) {
    final color = isDestructive 
        ? AppColors.error 
        : AppColors.primary;
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              size: 28,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDestructive
                  ? AppColors.error
                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
