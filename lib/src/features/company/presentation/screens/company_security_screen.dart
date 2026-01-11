import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import '../providers/company_provider.dart';

class CompanySecurityScreen extends StatefulWidget {
  final dynamic userId;
  
  const CompanySecurityScreen({super.key, required this.userId});

  @override
  State<CompanySecurityScreen> createState() => _CompanySecurityScreenState();
}

class _CompanySecurityScreenState extends State<CompanySecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().checkPasswordStatus(widget.userId);
    });
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<CompanyProvider>();
    
    final success = await provider.changePassword(
      userId: widget.userId,
      currentPassword: provider.hasPassword ? _currentPasswordController.text : null,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.hasPassword 
              ? 'Contraseña actualizada exitosamente' 
              : 'Contraseña establecida exitosamente'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Error al cambiar la contraseña'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Seguridad',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<CompanyProvider>(
        builder: (context, provider, child) {
          if (provider.isCheckingPassword) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card for Google Users
                  if (provider.authProvider == 'google' && !provider.hasPassword)
                    _buildInfoCard(
                      'Iniciaste sesión con Google',
                      'Puedes establecer una contraseña para también poder iniciar sesión con tu email.',
                      Icons.info_outline,
                      isDark,
                    ),

                  if (provider.authProvider == 'google' && provider.hasPassword)
                    _buildInfoCard(
                      'Cuenta vinculada con Google',
                      'Puedes usar Google o tu contraseña para iniciar sesión.',
                      Icons.check_circle_outline,
                      isDark,
                      isSuccess: true,
                    ),

                  const SizedBox(height: 24),

                  _buildSectionHeader(
                    provider.hasPassword ? 'Cambiar Contraseña' : 'Establecer Contraseña',
                    isDark,
                  ),
                  const SizedBox(height: 16),

                  // Current Password (only if user has one)
                  if (provider.hasPassword)
                    AuthTextField(
                      controller: _currentPasswordController,
                      label: 'Contraseña Actual',
                      hintText: 'Ingresa tu contraseña actual',
                      icon: Icons.lock_outline,
                      obscureText: _obscureCurrent,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                          color: isDark ? Colors.white54 : Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                      validator: (value) {
                        if (provider.hasPassword && (value == null || value.isEmpty)) {
                          return 'Ingresa tu contraseña actual';
                        }
                        return null;
                      },
                    ),

                  if (provider.hasPassword) const SizedBox(height: 16),

                  // New Password
                  AuthTextField(
                    controller: _newPasswordController,
                    label: 'Nueva Contraseña',
                    hintText: 'Mínimo 8 caracteres',
                    icon: Icons.lock_outline,
                    obscureText: _obscureNew,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew ? Icons.visibility_off : Icons.visibility,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa una nueva contraseña';
                      }
                      if (value.length < 8) {
                        return 'La contraseña debe tener al menos 8 caracteres';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Confirm Password
                  AuthTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirmar Contraseña',
                    hintText: 'Repite la nueva contraseña',
                    icon: Icons.lock_outline,
                    obscureText: _obscureConfirm,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    validator: (value) {
                      if (value != _newPasswordController.text) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: provider.isSaving ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: provider.isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              provider.hasPassword ? 'Cambiar Contraseña' : 'Establecer Contraseña',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        color: isDark ? AppColors.primaryLight : AppColors.primary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInfoCard(String title, String message, IconData icon, bool isDark, {bool isSuccess = false}) {
    final color = isSuccess ? AppColors.success : AppColors.info;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
