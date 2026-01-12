import 'dart:io';
import 'package:flutter/material.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/widgets/profile_photo_picker.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

/// Pantalla para editar el perfil del cliente.
/// 
/// Permite al usuario editar:
/// - Nombre
/// - Apellido
/// - Foto de perfil (almacenada en Cloudflare R2)
/// 
/// Recibe como argumentos:
/// - userId: ID del usuario
/// - nombre: Nombre actual
/// - apellido: Apellido actual
/// - fotoUrl: URL de la foto actual (desde R2)
/// - email: Email del usuario (solo lectura)
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  
  int? _userId;
  String? _email;
  String? _phone;
  String? _currentFotoUrl;
  File? _selectedPhotoFile;
  bool _isLoading = false;
  bool _hasChanges = false;
  bool _deletePhoto = false;

  @override
  void initState() {
    super.initState();
    // Cargar datos iniciales después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      setState(() {
        _userId = args['userId'] as int?;
        _email = args['email'] as String?;
        _phone = args['telefono'] as String?;
        _nombreController.text = args['nombre'] as String? ?? '';
        _apellidoController.text = args['apellido'] as String? ?? '';
        
        // Construir URL de foto si viene el key de R2
        final fotoKey = args['foto_perfil'] as String?;
        if (fotoKey != null && fotoKey.isNotEmpty) {
          _currentFotoUrl = UserService.getR2ImageUrl(fotoKey);
        }
      });
    }
    
    // Listener para detectar cambios
    _nombreController.addListener(_onFieldChanged);
    _apellidoController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _nombreController.removeListener(_onFieldChanged);
    _apellidoController.removeListener(_onFieldChanged);
    _nombreController.dispose();
    _apellidoController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_userId == null) {
      CustomSnackbar.showError(context, message: 'Error: Usuario no identificado');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await UserService.updateProfile(
        userId: _userId!,
        nombre: _nombreController.text.trim(),
        apellido: _apellidoController.text.trim(),
        fotoPath: _selectedPhotoFile?.path,
        deletePhoto: _deletePhoto,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        CustomSnackbar.showSuccess(context, message: 'Perfil actualizado correctamente');
        
        // Retornar true para indicar que hubo cambios
        Navigator.pop(context, true);
      } else {
        CustomSnackbar.showError(
          context,
          message: result['message'] ?? 'Error al actualizar el perfil',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, message: 'Error de conexión: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onPhotoSelected(File? file) {
    setState(() {
      _selectedPhotoFile = file;
      _deletePhoto = false; // Reset delete flag if new photo selected
      _hasChanges = true;
    });
  }

  void _onPhotoRemoved() {
    setState(() {
      _selectedPhotoFile = null;
      _currentFotoUrl = null; // Hide current URL immediately
      _deletePhoto = true;    // Mark for deletion
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Editar Perfil',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: Text(
                'Guardar',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    
                    // Foto de perfil
                    ProfilePhotoPicker(
                      imageUrl: _currentFotoUrl,
                      imageFile: _selectedPhotoFile,
                      onImageSelected: _onPhotoSelected,
                      onPhotoRemoved: _onPhotoRemoved,
                      size: 140,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Texto indicativo
                    Text(
                      'Toca para cambiar la foto',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Campo Nombre
                    AuthTextField(
                      controller: _nombreController,
                      label: 'Nombre',
                      icon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El nombre es requerido';
                        }
                        if (value.trim().length < 2) {
                          return 'El nombre debe tener al menos 2 caracteres';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Campo Apellido
                    AuthTextField(
                      controller: _apellidoController,
                      label: 'Apellido',
                      icon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El apellido es requerido';
                        }
                        if (value.trim().length < 2) {
                          return 'El apellido debe tener al menos 2 caracteres';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),

                    // Teléfono (solo lectura)
                    if (_phone != null && _phone!.isNotEmpty) ...[
                      AuthTextField(
                        controller: TextEditingController(text: _phone),
                        label: 'Teléfono',
                        icon: Icons.phone_outlined,
                        enabled: true, // Enabled true for correct styling
                        readOnly: true,
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    // Email (solo lectura)
                    if (_email != null && _email!.isNotEmpty)
                      AuthTextField(
                        controller: TextEditingController(text: _email),
                        label: 'Correo electrónico',
                        icon: Icons.email_outlined,
                        enabled: true, // Enabled true for correct styling
                        readOnly: true,
                      ),
                    
                    const SizedBox(height: 40),
                    
                    // Botón guardar
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: (_hasChanges && !_isLoading) ? _saveProfile : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: isDark 
                              ? AppColors.darkDivider 
                              : AppColors.lightDivider,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: _hasChanges ? 4 : 0,
                          shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Guardar cambios',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Texto informativo
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.info,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tu foto de perfil se almacena de forma segura en la nube.',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
