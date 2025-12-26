import 'dart:io';
import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

class ImageUploadCard extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;
  final bool isDark;

  const ImageUploadCard({
    super.key,
    required this.label,
    required this.file,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: file != null ? AppColors.success : (isDark ? Colors.white24 : Colors.grey.shade300),
                width: 1.5,
                style: file != null ? BorderStyle.solid : BorderStyle.none,
              ),
              image: file != null 
                  ? DecorationImage(
                      image: FileImage(file!),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken)
                    )
                  : null
            ),
             child: file != null 
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 24),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_rounded, size: 32, color: AppColors.primary.withOpacity(0.8)),
                    const SizedBox(height: 8),
                    Text(
                      'Toca para subir foto',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                        fontWeight: FontWeight.w500
                      ),
                    )
                  ],
                ),
          ),
        ),
      ],
    );
  }
}
