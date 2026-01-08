// lib/src/features/auth/presentation/screens/empresa_register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'package:viax/src/global/services/device_id_service.dart';
import 'package:viax/src/features/auth/data/services/empresa_register_service.dart';
import 'package:viax/src/features/auth/presentation/widgets/register_step_indicator.dart';
import 'package:viax/src/features/auth/data/services/colombia_location_service.dart';
import 'package:viax/src/features/auth/presentation/widgets/searchable_dropdown_sheet.dart';

/// Pantalla de registro de empresas de transporte
/// UI optimizada para coincidir con el registro de usuarios
class EmpresaRegisterScreen extends StatefulWidget {
  const EmpresaRegisterScreen({super.key});

  @override
  State<EmpresaRegisterScreen> createState() => _EmpresaRegisterScreenState();
}

class _EmpresaRegisterScreenState extends State<EmpresaRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  final int _totalSteps = 5;
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  File? _logoFile;
  
  // Location Service
  final _locationService = ColombiaLocationService();
  List<Department> _departments = [];
  List<City> _cities = [];
  Department? _selectedDepartment;
  City? _selectedCity;
  bool _isLoadingDepartments = false;
  bool _isLoadingCities = false;

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
  
  // Controladores - Representante
  final _representanteNombreController = TextEditingController();
  final _representanteTelefonoController = TextEditingController();
  final _representanteEmailController = TextEditingController();
  
  // Controladores - Seguridad
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Tipos de vehículos seleccionados
  final List<String> _tiposVehiculoSeleccionados = [];
  
  final List<String> _tiposVehiculoDisponibles = [
    'moto',
    'motocarro', 
    'taxi',
    'carro',
  ];

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    setState(() => _isLoadingDepartments = true);
    try {
      final deps = await _locationService.getDepartments();
      if (mounted) {
        setState(() {
          _departments = deps;
        });
      }
    } catch (e) {
      debugPrint('Error loading departments: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDepartments = false);
    }
  }

  Future<void> _loadCities(int departmentId) async {
    setState(() {
      _isLoadingCities = true;
      _cities = []; // Clear previous cities
      _selectedCity = null; // Reset selected city
    });
    try {
      final cities = await _locationService.getCitiesByDepartment(departmentId);
      if (mounted) {
        setState(() {
          _cities = cities;
        });
      }
    } catch (e) {
      debugPrint('Error loading cities: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCities = false);
    }
  }

  @override
  void dispose() {
    _nombreEmpresaController.dispose();
    _nitController.dispose();
    _razonSocialController.dispose();
    _descripcionController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _telefonoSecundarioController.dispose();
    _direccionController.dispose();
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

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      if (_validateCurrentStep()) {
        setState(() => _currentStep++);
      }
    } else {
      _submitForm();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Información empresa
        if (_nombreEmpresaController.text.trim().isEmpty) {
          _showError('El nombre de la empresa es requerido');
          return false;
        }
        return true;
      case 1: // Vehículos
        if (_tiposVehiculoSeleccionados.isEmpty) {
          _showError('Selecciona al menos un tipo de vehículo');
          return false;
        }
        return true;
      case 2: // Contacto & Ubicación
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
        if (_direccionController.text.trim().isEmpty) {
          _showError('La dirección es requerida');
         return false;
        }
        if (_selectedDepartment == null) {
          _showError('Selecciona un departamento');
          return false;
        }
        if (_selectedCity == null) {
          _showError('Selecciona un municipio');
          return false;
        }
        return true;
      case 3: // Representante
        if (_representanteNombreController.text.trim().isEmpty) {
          _showError('El nombre del representante es requerido');
          return false;
        }
        return true;
      case 4: // Seguridad
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
        municipio: _selectedCity?.name ?? '', // Use selected city name
        departamento: _selectedDepartment?.name ?? '', // Use selected department name
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
          _showRegistrationSuccessDialog();
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            onPressed: () {
               Navigator.of(context).pop(); // Close dialog
               Navigator.of(context).pop(); // Go back to login/welcome
            },
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
           // Background Blobs
          Positioned(
            top: -100,
            right: -50,
            child: _buildGradientBlob(size, AppColors.primary.withValues(alpha: 0.15)),
          ),
          Positioned(
            top: size.height * 0.4,
            left: -80,
            child: _buildGradientBlob(size, AppColors.accent.withValues(alpha: 0.1)),
          ),

          SafeArea(
            child: Column(
              children: [
                 // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                       GestureDetector(
                         onTap: _prevStep,
                         child: Container(
                           padding: const EdgeInsets.all(8),
                           decoration: BoxDecoration(
                             color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                             shape: BoxShape.circle,
                             border: Border.all(
                               color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                             ),
                           ),
                           child: Icon(
                             Icons.arrow_back_ios_new_rounded, 
                             size: 18,
                             color: textColor,
                           ),
                         ),
                       ),
                       Expanded(
                         child: RegisterStepIndicator(
                           currentStep: _currentStep, 
                           totalSteps: _totalSteps,
                           lineWidth: 25,
                         ),
                       ),
                       const SizedBox(width: 40), // Balance the back button space
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeInBack,
                        transitionBuilder: (child, animation) {
                           return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                 begin: const Offset(0.1, 0),
                                 end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _buildCurrentStepContent(isDark, textColor),
                      ),
                    ),
                  ),
                ),

                // Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 60,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentStep == _totalSteps - 1 ? 'Enviar Solicitud' : 'Continuar',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBlob(Size size, Color color) {
    return Container(
      width: size.width * 0.7,
      height: size.width * 0.7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildCurrentStepContent(bool isDark, Color textColor) {
    switch (_currentStep) {
      case 0:
        return _buildEmpresaInfoContent(isDark, textColor);
      case 1:
        return _buildVehiculosContent(isDark, textColor);
      case 2:
        return _buildContactoContent(isDark, textColor);
      case 3:
        return _buildRepresentanteContent(isDark, textColor);
      case 4:
        return _buildSeguridadContent(isDark, textColor);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHeaderTitle(String title, String subtitle, Color textColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: textColor,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildEmpresaInfoContent(bool isDark, Color textColor) {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderTitle(
          'Registrar Empresa', 
          'Ingresa los datos básicos para identificar tu empresa.', 
          textColor, 
          isDark
        ),
        
        // Logo Picker
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
                     // Add subtle shadow/border to match theme
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
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
                            Icon(Icons.add_a_photo_rounded, size: 28, color: Colors.grey[500]),
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
            'Logo de la empresa (Opcional)',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 24),

        AuthTextField(
          controller: _nombreEmpresaController,
          label: 'Nombre de la Empresa *',
          icon: Icons.business_rounded,
          textCapitalization: TextCapitalization.words,
          validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
             Expanded(
               child: AuthTextField(
                 controller: _nitController,
                 label: 'NIT *',
                 icon: Icons.badge_outlined,
                 keyboardType: TextInputType.number,
                 inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                 validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
               ),
             ),
             const SizedBox(width: 12),
             Expanded(
               child: AuthTextField(
                 controller: _razonSocialController,
                 label: 'Razón Social *',
                 icon: Icons.article_outlined,
                 textCapitalization: TextCapitalization.words,
                 validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
               ),
             ),
          ],
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: _descripcionController,
          label: 'Descripción (Opcional)',
          icon: Icons.description_outlined,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSearchableSelector<T>({
    required String label,
    required String hint,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T) onChanged,
    required bool isLoading,
    IconData icon = Icons.arrow_drop_down,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16), // Add bottom margin here instead of outside
      decoration: BoxDecoration(
        color: isDark 
            ? AppColors.darkSurface.withValues(alpha: 0.8) 
            : AppColors.lightSurface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.darkShadow : AppColors.lightShadow,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: isLoading || items.isEmpty ? null : () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => SearchableDropdownSheet<T>(
              title: 'Seleccionar $label',
              items: items,
              itemLabel: itemLabel,
              onSelected: onChanged,
              searchHint: 'Buscar $label...',
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
               // Prefix Icon Container (Matches AuthTextField)
               Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  label == 'Departamento' ? Icons.map_outlined : Icons.location_city_outlined, 
                  color: Colors.white, 
                  size: 20
                ),
              ),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Label (mimics labelText)
                    Text(
                      label,
                      style: TextStyle(
                         color: isDark ? Colors.white54 : Colors.black54,
                         fontSize: 13,
                         fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Value or Hint
                    Text(
                       value != null ? itemLabel(value) : hint,
                       style: TextStyle(
                         color: value != null ? textColor : Colors.grey,
                         fontSize: 16,
                         fontWeight: FontWeight.w500,
                       ),
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, color: Colors.grey),
              const SizedBox(width: 8), // Right padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactoContent(bool isDark, Color textColor) {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderTitle(
          'Contacto', 
          'Información para contactarnos con tu empresa.', 
          textColor, 
          isDark
        ),

        AuthTextField(
          controller: _emailController,
          label: 'Email Corporativo *',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Requerido';
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
              return 'Email inválido';
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
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Requerido';
            if (v.length < 7) return 'Min 7 dígitos';
            return null;
          },
        ),
        const SizedBox(height: 16),
         AuthTextField(
          controller: _telefonoSecundarioController,
          label: 'Teléfono Secundario',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 24),
         Text(
          'Ubicación',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        AuthTextField(
          controller: _direccionController,
          label: 'Dirección *',
          icon: Icons.location_on_outlined,
          textCapitalization: TextCapitalization.sentences,
          validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 16),
        
        // Departments Selector
        _buildSearchableSelector<Department>(
          label: 'Departamento',
          hint: 'Seleccionar departamento',
          value: _selectedDepartment,
          items: _departments,
          itemLabel: (dep) => dep.name,
          isLoading: _isLoadingDepartments,
          onChanged: (newValue) {
             setState(() {
               _selectedDepartment = newValue;
             });
             _loadCities(newValue.id);
          },
        ),
        
        const SizedBox(height: 16),

        // Cities Selector
        _buildSearchableSelector<City>(
          label: 'Municipio',
          hint: _selectedDepartment == null 
              ? 'Selecciona un departamento primero' 
              : 'Seleccionar municipio',
          value: _selectedCity,
          items: _cities,
          itemLabel: (city) => city.name,
          isLoading: _isLoadingCities,
          onChanged: (newValue) {
            setState(() {
              _selectedCity = newValue;
            });
          },
        ),

        const SizedBox(height: 20),
      ],
    );
  }



  Widget _buildRepresentanteContent(bool isDark, Color textColor) {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderTitle(
          'Representante', 
          'Persona encargada de administrar la cuenta.', 
          textColor, 
          isDark
        ),

        AuthTextField(
          controller: _representanteNombreController,
          label: 'Nombre Completo *',
          icon: Icons.person_outline,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
          ],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Requerido';
            if (v.trim().split(' ').length < 2) return 'Nombre y apellido';
            return null;
          },
        ),
        const SizedBox(height: 16),
         AuthTextField(
          controller: _representanteTelefonoController,
          label: 'Teléfono Directo',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: _representanteEmailController,
          label: 'Email Personal',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
             if (v != null && v.isNotEmpty && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
               return 'Email inválido';
             }
             return null;
          },
        ),
        
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'El email corporativo será tu usuario principal para iniciar sesión.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSeguridadContent(bool isDark, Color textColor) {
    return Column(
      key: const ValueKey(4),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderTitle(
          'Seguridad', 
          'Protege tu cuenta con una contraseña segura.', 
          textColor, 
          isDark
        ),

        AuthTextField(
          controller: _passwordController,
          label: 'Contraseña *',
          icon: Icons.lock_rounded,
          obscureText: _obscurePassword,
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: Colors.grey),
          ),
          validator: (v) => (v?.length ?? 0) < 6 ? 'Mínimo 6 caracteres' : null,
        ),
        const SizedBox(height: 16),
         AuthTextField(
          controller: _confirmPasswordController,
          label: 'Confirmar Contraseña *',
          icon: Icons.lock_rounded,
          obscureText: _obscureConfirmPassword,
          isLast: true,
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            child: Icon(_obscureConfirmPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: Colors.grey),
          ),
          validator: (v) => v != _passwordController.text ? 'No coinciden' : null,
        ),
        
        const SizedBox(height: 30),
        
        // Resumen simplificado
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Todo listo para enviar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Al hacer clic en "Enviar Solicitud", confirmas que los datos ingresados son verídicos y aceptas los términos y condiciones de Viax.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getVehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'moto':
        return Icons.two_wheeler_rounded;
      case 'motocarro':
        return Icons.delivery_dining_rounded;
      case 'taxi':
        return Icons.local_taxi_rounded;
      case 'carro':
        return Icons.directions_car_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  Widget _buildVehiculosContent(bool isDark, Color textColor) {
    return Column(
      key: const ValueKey(1), // Matches step index for switcher
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderTitle(
          '¿Qué transportas?', 
          'Selecciona los tipos de vehículos que opera tu empresa.', 
          textColor, 
          isDark
        ),
        
        _buildVehicleTypeSelector(isDark),
        
        const SizedBox(height: 30),
        
        // Info Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_rounded, color: AppColors.primary.withValues(alpha: 0.5), size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Puedes seleccionar uno o varios tipos según tu flota disponible.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildVehicleTypeSelector(bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: _tiposVehiculoDisponibles.length,
      itemBuilder: (context, index) {
        final tipo = _tiposVehiculoDisponibles[index];
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
            HapticFeedback.lightImpact();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppColors.primary 
                  : (isDark ? AppColors.darkSurface : Colors.white),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected 
                    ? AppColors.primaryLight 
                    : (isDark ? Colors.white10 : Colors.grey.shade200),
                width: 2,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.white.withValues(alpha: 0.2) 
                        : AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getVehicleIcon(tipo),
                    size: 32,
                    color: isSelected ? Colors.white : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tipo.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                    letterSpacing: 1.0,
                  ),
                ),
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

}
