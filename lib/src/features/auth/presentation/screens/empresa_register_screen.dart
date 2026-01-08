// lib/src/features/auth/presentation/screens/empresa_register_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/widgets/entrance_fader.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'package:viax/src/global/services/device_id_service.dart';
import 'package:viax/src/features/auth/data/services/empresa_register_service.dart';

/// Pantalla de registro de empresas de transporte
/// Sigue el mismo formato del formulario de admin pero adaptado para registro público
class EmpresaRegisterScreen extends StatefulWidget {
  const EmpresaRegisterScreen({super.key});

  @override
  State<EmpresaRegisterScreen> createState() => _EmpresaRegisterScreenState();
}

class _EmpresaRegisterScreenState extends State<EmpresaRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  File? _logoFile;
  
  // Controladores - Información de la empresa
  final _nombreEmpresaController = TextEditingController();
  final _nitController = TextEditingController();
  final _razonSocialController = TextEditingController();
  final _descripcionController = TextEditingController();
  
  // Controladores - Contacto
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _telefonoSecundarioController = TextEditingController();
  
  // Controladores - Ubicación
  final _direccionController = TextEditingController();
  final _municipioController = TextEditingController();
  final _departamentoController = TextEditingController();
  
  // Controladores - Representante
  final _representanteNombreController = TextEditingController();
  final _representanteTelefonoController = TextEditingController();
  final _representanteEmailController = TextEditingController();
  
  // Controladores - Seguridad
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Tipos de vehículos seleccionados
  List<String> _tiposVehiculoSeleccionados = [];
  
  final List<String> _tiposVehiculoDisponibles = [
    'moto',
    'motocarro', 
    'taxi',
    'carro',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nombreEmpresaController.dispose();
    _nitController.dispose();
    _razonSocialController.dispose();
    _descripcionController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _telefonoSecundarioController.dispose();
    _direccionController.dispose();
    _municipioController.dispose();
    _departamentoController.dispose();
    _representanteNombreController.dispose();
    _representanteTelefonoController.dispose();
    _representanteEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _logoFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _nextPage() {
    if (_currentPage < 3) {
      // Validar página actual antes de avanzar
      if (_validateCurrentPage()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0: // Información empresa
        if (_nombreEmpresaController.text.trim().isEmpty) {
          _showError('El nombre de la empresa es requerido');
          return false;
        }
        return true;
      case 1: // Contacto
        if (_emailController.text.trim().isEmpty) {
          _showError('El email es requerido');
          return false;
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text)) {
          _showError('Ingresa un email válido');
          return false;
        }
        if (_telefonoController.text.trim().isEmpty) {
          _showError('El teléfono es requerido');
          return false;
        }
        return true;
      case 2: // Representante
        if (_representanteNombreController.text.trim().isEmpty) {
          _showError('El nombre del representante es requerido');
          return false;
        }
        return true;
      case 3: // Seguridad
        return true;
      default:
        return true;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      _showError('Por favor completa todos los campos requeridos');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Las contraseñas no coinciden');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showError('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final deviceUuid = await DeviceIdService.getOrCreateDeviceUuid();
      
      final result = await EmpresaRegisterService.registerEmpresa(
        nombreEmpresa: _nombreEmpresaController.text.trim(),
        nit: _nitController.text.trim(),
        razonSocial: _razonSocialController.text.trim(),
        email: _emailController.text.trim(),
        telefono: _telefonoController.text.trim(),
        telefonoSecundario: _telefonoSecundarioController.text.trim(),
        direccion: _direccionController.text.trim(),
        municipio: _municipioController.text.trim(),
        departamento: _departamentoController.text.trim(),
        representanteNombre: _representanteNombreController.text.trim(),
        representanteTelefono: _representanteTelefonoController.text.trim(),
        representanteEmail: _representanteEmailController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        tiposVehiculo: _tiposVehiculoSeleccionados,
        password: _passwordController.text,
        deviceUuid: deviceUuid,
        logoFile: _logoFile,
      );

      if (result['success'] == true) {
        if (mounted) {
          _showSuccess('¡Registro exitoso! Tu solicitud está pendiente de aprobación.');
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context).pop();
            // Mostrar diálogo de confirmación
            _showRegistrationSuccessDialog();
          }
        }
      } else {
        _showError(result['message'] ?? 'Error al registrar la empresa');
      }
    } catch (e) {
      _showError('Error de conexión. Verifica tu internet e intenta nuevamente.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRegistrationSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppColors.success),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '¡Solicitud Enviada!',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu solicitud de registro ha sido recibida correctamente.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Nuestro equipo revisará tu información y te notificaremos por email cuando tu cuenta esté activa.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Entendido', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    CustomSnackbar.showError(context, message: message);
  }

  void _showSuccess(String message) {
    CustomSnackbar.showSuccess(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: Theme.of(context).textTheme.bodyLarge?.color,
              size: 20,
            ),
            onPressed: () {
              if (_currentPage > 0) {
                _previousPage();
              } else {
                Navigator.pop(context);
              }
            },
            padding: EdgeInsets.zero,
          ),
        ),
        title: Text(
          'Registrar Empresa',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Indicador de progreso
          _buildProgressIndicator(isDark),
          
          // Contenido del formulario
          Expanded(
            child: Form(
              key: _formKey,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildEmpresaInfoPage(isDark),
                  _buildContactoPage(isDark),
                  _buildRepresentantePage(isDark),
                  _buildSeguridadPage(isDark),
                ],
              ),
            ),
          ),
          
          // Botones de navegación
          _buildNavigationButtons(isDark),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    final steps = ['Empresa', 'Contacto', 'Representante', 'Seguridad'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: List.generate(4, (index) {
              final isCompleted = index < _currentPage;
              final isCurrent = index == _currentPage;
              
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isCompleted || isCurrent
                              ? AppColors.primary
                              : (isDark ? Colors.white12 : Colors.black12),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (index < 3) const SizedBox(width: 4),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: steps.asMap().entries.map((entry) {
              final isCurrent = entry.key == _currentPage;
              return Text(
                entry.value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  color: isCurrent
                      ? AppColors.primary
                      : Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpresaInfoPage(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: EntranceFader(
        delay: const Duration(milliseconds: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, 'Información de la Empresa', Icons.business),
            const SizedBox(height: 20),
            
            // Logo picker
            Center(
              child: GestureDetector(
                onTap: _pickLogo,
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.grey[200],
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                        image: _logoFile != null
                            ? DecorationImage(
                                image: FileImage(_logoFile!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _logoFile == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 28, color: Colors.grey[500]),
                                const SizedBox(height: 4),
                                Text(
                                  'Logo',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                              ],
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Opcional',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            AuthTextField(
              controller: _nombreEmpresaController,
              label: 'Nombre de la Empresa *',
              icon: Icons.business_rounded,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es requerido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: AuthTextField(
                    controller: _nitController,
                    label: 'NIT',
                    icon: Icons.badge_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AuthTextField(
                    controller: _razonSocialController,
                    label: 'Razón Social',
                    icon: Icons.article_outlined,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            AuthTextField(
              controller: _descripcionController,
              label: 'Descripción (opcional)',
              icon: Icons.description_outlined,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            
            _buildSectionTitle(context, 'Tipos de Vehículos', Icons.directions_car),
            const SizedBox(height: 12),
            _buildVehicleTypeSelector(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildContactoPage(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: EntranceFader(
        delay: const Duration(milliseconds: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, 'Información de Contacto', Icons.contact_phone),
            const SizedBox(height: 20),
            
            AuthTextField(
              controller: _emailController,
              label: 'Email de la Empresa *',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El email es requerido';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Ingresa un email válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            AuthTextField(
              controller: _telefonoController,
              label: 'Teléfono Principal *',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El teléfono es requerido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            AuthTextField(
              controller: _telefonoSecundarioController,
              label: 'Teléfono Secundario (opcional)',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            
            _buildSectionTitle(context, 'Ubicación', Icons.location_on),
            const SizedBox(height: 16),
            
            AuthTextField(
              controller: _direccionController,
              label: 'Dirección',
              icon: Icons.location_on_outlined,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: AuthTextField(
                    controller: _municipioController,
                    label: 'Municipio',
                    icon: Icons.location_city_outlined,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AuthTextField(
                    controller: _departamentoController,
                    label: 'Departamento',
                    icon: Icons.map_outlined,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepresentantePage(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: EntranceFader(
        delay: const Duration(milliseconds: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, 'Representante Legal', Icons.person),
            const SizedBox(height: 8),
            Text(
              'Esta persona será el administrador de la cuenta de la empresa',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            
            AuthTextField(
              controller: _representanteNombreController,
              label: 'Nombre Completo *',
              icon: Icons.person_outline,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es requerido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            AuthTextField(
              controller: _representanteTelefonoController,
              label: 'Teléfono del Representante',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            
            AuthTextField(
              controller: _representanteEmailController,
              label: 'Email del Representante',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 30),
            
            // Información adicional
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'El email de la empresa será tu usuario para iniciar sesión',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeguridadPage(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: EntranceFader(
        delay: const Duration(milliseconds: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, 'Seguridad de la Cuenta', Icons.lock_outline),
            const SizedBox(height: 8),
            Text(
              'Crea una contraseña segura para tu cuenta',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            
            AuthTextField(
              controller: _passwordController,
              label: 'Contraseña *',
              icon: Icons.lock_rounded,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  size: 22,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'La contraseña es requerida';
                }
                if (value.length < 6) {
                  return 'Mínimo 6 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            AuthTextField(
              controller: _confirmPasswordController,
              label: 'Confirmar Contraseña *',
              icon: Icons.lock_rounded,
              obscureText: _obscureConfirmPassword,
              isLast: true,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  size: 22,
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirma tu contraseña';
                }
                if (value != _passwordController.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // Resumen
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.summarize_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Resumen del Registro',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Empresa', _nombreEmpresaController.text),
                  _buildSummaryRow('Email', _emailController.text),
                  _buildSummaryRow('Teléfono', _telefonoController.text),
                  _buildSummaryRow('Representante', _representanteNombreController.text),
                  if (_tiposVehiculoSeleccionados.isNotEmpty)
                    _buildSummaryRow('Vehículos', _tiposVehiculoSeleccionados.join(', ')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Términos y condiciones
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Al registrarte, aceptas los Términos de Servicio y la Política de Privacidad de Viax.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleTypeSelector(bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _tiposVehiculoDisponibles.map((tipo) {
        final isSelected = _tiposVehiculoSeleccionados.contains(tipo);
        
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _tiposVehiculoSeleccionados.remove(tipo);
              } else {
                _tiposVehiculoSeleccionados.add(tipo);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white12 : Colors.black12),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getVehicleIcon(tipo),
                  size: 20,
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatVehicleType(tipo),
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getVehicleIcon(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'moto':
        return Icons.two_wheeler;
      case 'motocarro':
        return Icons.electric_rickshaw;
      case 'taxi':
        return Icons.local_taxi;
      case 'carro':
        return Icons.directions_car;
      default:
        return Icons.directions_car;
    }
  }

  String _formatVehicleType(String tipo) {
    return tipo[0].toUpperCase() + tipo.substring(1).toLowerCase();
  }

  Widget _buildNavigationButtons(bool isDark) {
    final isLastPage = _currentPage == 3;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentPage > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousPage,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.3) ?? Colors.grey,
                    ),
                  ),
                  child: Text(
                    'Anterior',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (_currentPage > 0) const SizedBox(width: 16),
            Expanded(
              flex: _currentPage > 0 ? 1 : 2,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (isLastPage ? _submitForm : _nextPage),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        isLastPage ? 'Registrar Empresa' : 'Siguiente',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
