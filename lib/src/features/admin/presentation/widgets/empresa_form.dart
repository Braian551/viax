import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/features/admin/data/models/empresa_transporte_model.dart';
import 'package:viax/src/features/admin/domain/entities/empresa_transporte.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/widgets/auth_text_area.dart';
import 'package:viax/src/features/auth/presentation/widgets/searchable_dropdown_sheet.dart';
import 'package:viax/src/features/auth/data/services/colombia_location_service.dart';

/// Formulario para crear o editar una empresa de transporte.
/// Alineado con la lógica de EmpresaRegisterScreen para consistencia.
class EmpresaForm extends StatefulWidget {
  final EmpresaTransporte? empresa;
  final Function(EmpresaFormData) onSubmit;
  final VoidCallback? onCancel;
  final bool isLoading;

  const EmpresaForm({
    super.key,
    this.empresa,
    required this.onSubmit,
    this.onCancel,
    this.isLoading = false,
  });

  @override
  State<EmpresaForm> createState() => _EmpresaFormState();
}

class _EmpresaFormState extends State<EmpresaForm> {
  final _formKey = GlobalKey<FormState>();
  late EmpresaFormData _formData;
  
  // Controladores
  late TextEditingController _nombreController;
  late TextEditingController _nitController;
  late TextEditingController _razonSocialController;
  late TextEditingController _emailController;
  late TextEditingController _telefonoController;
  late TextEditingController _telefonoSecundarioController;
  late TextEditingController _direccionController;
  late TextEditingController _representanteNombreController;
  late TextEditingController _representanteApellidoController;
  late TextEditingController _representanteTelefonoController;
  late TextEditingController _representanteEmailController;
  late TextEditingController _descripcionController;
  late TextEditingController _notasAdminController;
  
  // Password controllers (Solo para creación)
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Location Service
  final _locationService = ColombiaLocationService();
  List<Department> _departments = [];
  List<City> _cities = [];
  Department? _selectedDepartment;
  City? _selectedCity;
  bool _isLoadingDepartments = false;
  bool _isLoadingCities = false;

  // Tipos de vehículos disponibles
  final List<String> _tiposVehiculoDisponibles = [
    'moto',
    'motocarro',
    'taxi',
    'carro',
  ];

  @override
  void initState() {
    super.initState();
    _formData = widget.empresa != null 
        ? EmpresaFormData.fromEmpresa(widget.empresa!)
        : EmpresaFormData();
    
    _initControllers();
    _loadDepartments();
  }
  
  Future<void> _loadDepartments() async {
    setState(() => _isLoadingDepartments = true);
    try {
      final deps = await _locationService.getDepartments();
      if (mounted) {
        setState(() {
          _departments = deps;
          // Pre-select if editing
          if (_formData.departamento != null) {
            try {
              final dep = deps.firstWhere((d) => d.name == _formData.departamento);
              _selectedDepartment = dep;
              _loadCities(dep.id);
            } catch (_) {}
          }
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
      _cities = []; 
      // Don't reset selected city immediately if we are initializing form data
      if (_formData.municipio == null) _selectedCity = null;
    });
    try {
      final cities = await _locationService.getCitiesByDepartment(departmentId);
      if (mounted) {
        setState(() {
          _cities = cities;
          // Pre-select if editing and matches
          if (_formData.municipio != null) {
            try {
              final city = cities.firstWhere((c) => c.name == _formData.municipio);
              _selectedCity = city;
            } catch (_) {
              // If city not found in list (maybe name mismatch), keep selectedCity null or handle gracefully
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading cities: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCities = false);
    }
  }

  bool _isPickingImage = false;

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    
    setState(() {
      _isPickingImage = true;
    });

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _formData.logoFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  void _initControllers() {
    _nombreController = TextEditingController(text: _formData.nombre);
    _nitController = TextEditingController(text: _formData.nit ?? '');
    _razonSocialController = TextEditingController(text: _formData.razonSocial ?? '');
    _emailController = TextEditingController(text: _formData.email ?? '');
    _telefonoController = TextEditingController(text: _formData.telefono ?? '');
    _telefonoSecundarioController = TextEditingController(text: _formData.telefonoSecundario ?? '');
    _direccionController = TextEditingController(text: _formData.direccion ?? '');
    // Municipio/Departamento managed by selection state, not controllers
    _representanteNombreController = TextEditingController(text: _formData.representanteNombre ?? '');
    _representanteApellidoController = TextEditingController(text: _formData.representanteApellido ?? '');
    _representanteTelefonoController = TextEditingController(text: _formData.representanteTelefono ?? '');
    _representanteEmailController = TextEditingController(text: _formData.representanteEmail ?? '');
    _descripcionController = TextEditingController(text: _formData.descripcion ?? '');
    _notasAdminController = TextEditingController(text: _formData.notasAdmin ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _nitController.dispose();
    _razonSocialController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _telefonoSecundarioController.dispose();
    _direccionController.dispose();
    _representanteNombreController.dispose();
    _representanteApellidoController.dispose();
    _representanteTelefonoController.dispose();
    _representanteEmailController.dispose();
    _descripcionController.dispose();
    _notasAdminController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updateFormData() {
    _formData.nombre = _nombreController.text;
    _formData.nit = _nitController.text.isEmpty ? null : _nitController.text;
    _formData.razonSocial = _razonSocialController.text.isEmpty ? null : _razonSocialController.text;
    _formData.email = _emailController.text.isEmpty ? null : _emailController.text;
    _formData.telefono = _telefonoController.text.isEmpty ? null : _telefonoController.text;
    _formData.telefonoSecundario = _telefonoSecundarioController.text.isEmpty ? null : _telefonoSecundarioController.text;
    _formData.direccion = _direccionController.text.isEmpty ? null : _direccionController.text;
    
    _formData.municipio = _selectedCity?.name;
    _formData.departamento = _selectedDepartment?.name;
    
    _formData.representanteNombre = _representanteNombreController.text.isEmpty ? null : _representanteNombreController.text;
    _formData.representanteApellido = _representanteApellidoController.text.isEmpty ? null : _representanteApellidoController.text;
    _formData.representanteTelefono = _representanteTelefonoController.text.isEmpty ? null : _representanteTelefonoController.text;
    _formData.representanteEmail = _representanteEmailController.text.isEmpty ? null : _representanteEmailController.text;
    _formData.descripcion = _descripcionController.text.isEmpty ? null : _descripcionController.text;
    _formData.notasAdmin = _notasAdminController.text.isEmpty ? null : _notasAdminController.text;
    
    if (widget.empresa == null) {
      _formData.password = _passwordController.text;
    }
  }

  void _submitForm() {
    debugPrint('Attempting to submit form...');
    if (_formKey.currentState!.validate()) {
      debugPrint('Form validation passed. Updating data...');
      _updateFormData();
      debugPrint('Calling onSubmit with data: ${_formData.toJson()}');
      widget.onSubmit(_formData);
    } else {
      debugPrint('Form validation FAILED');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor corrige los errores en el formulario'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.grey[200],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2,
                        ),
                        image: _formData.logoFile != null
                            ? DecorationImage(
                                image: FileImage(_formData.logoFile!),
                                fit: BoxFit.cover,
                              )
                            : (_formData.logoUrl != null
                                ? DecorationImage(
                                    image: _formData.logoUrl!.startsWith('http')
                                        ? NetworkImage(_formData.logoUrl!)
                                        : NetworkImage(
                                            '${AppConfig.baseUrl}/${_formData.logoUrl}',
                                          ),
                                    fit: BoxFit.cover,
                                  )
                                : null),
                      ),
                      child: _formData.logoFile == null && _formData.logoUrl == null
                          ? const Icon(
                              Icons.add_a_photo,
                              size: 40,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(context, 'Información Básica', Icons.business),
            const SizedBox(height: 16),
            
            AuthTextField(
              controller: _nombreController,
              label: 'Nombre de la Empresa *',
              icon: Icons.business_rounded,
              textCapitalization: TextCapitalization.words,
              validator: (v) => v == null || v.trim().isEmpty ? 'El nombre es requerido' : null,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _nitController,
              label: 'NIT *',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => v == null || v.trim().isEmpty ? 'El NIT es requerido' : null,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _razonSocialController,
              label: 'Razón Social *',
              icon: Icons.article_outlined,
              textCapitalization: TextCapitalization.words,
              validator: (v) => v == null || v.trim().isEmpty ? 'La razón social es requerida' : null,
            ),

            const SizedBox(height: 24),
            
            _buildSectionTitle(context, 'Contacto', Icons.contact_phone),
            const SizedBox(height: 16),
            
            AuthTextField(
              controller: _emailController,
              label: 'Email Corporativo *',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'El email es requerido';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                  return 'Email inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AuthTextField(
                    controller: _telefonoController,
                    label: 'Teléfono Principal *',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AuthTextField(
                    controller: _telefonoSecundarioController,
                    label: 'Teléfono Secundario',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            _buildSectionTitle(context, 'Ubicación', Icons.location_on),
            const SizedBox(height: 16),
            
            AuthTextField(
              controller: _direccionController,
              label: 'Dirección *',
              icon: Icons.location_on_outlined,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => v!.trim().isEmpty ? 'La dirección es requerida' : null,
            ),
            const SizedBox(height: 16),
            
             // Departments Selector
            _buildSearchableSelector<Department>(
              context: context,
              label: 'Departamento',
              hint: 'Seleccionar departamento',
              value: _selectedDepartment,
              items: _departments,
              itemLabel: (dep) => dep.name,
              isLoading: _isLoadingDepartments,
              onChanged: (newValue) {
                 setState(() {
                   _selectedDepartment = newValue;
                   _selectedCity = null; // reset city
                 });
                 _loadCities(newValue.id);
              },
            ),
            
            const SizedBox(height: 16),

            // Cities Selector
            _buildSearchableSelector<City>(
              context: context,
              label: 'Municipio',
              hint: _selectedDepartment == null 
                  ? 'Seleccionar departamento primero' 
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

            const SizedBox(height: 24),
            
            _buildSectionTitle(context, 'Representante Legal', Icons.person),
            const SizedBox(height: 16),
            
            AuthTextField(
              controller: _representanteNombreController,
              label: 'Nombres *',
              icon: Icons.person_outline,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]')),
              ],
              validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _representanteApellidoController,
              label: 'Apellidos *',
              icon: Icons.person_outline,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]')),
              ],
              validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AuthTextField(
                    controller: _representanteTelefonoController,
                    label: 'Teléfono Directo',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AuthTextField(
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
                ),
              ],
            ),
            
            if (widget.empresa == null) ...[
              const SizedBox(height: 24),
              _buildSectionTitle(context, 'Seguridad (Cuenta)', Icons.security),
              const SizedBox(height: 16),
              
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
            ],

            const SizedBox(height: 24),
            
            _buildSectionTitle(context, 'Tipos de Vehículos', Icons.directions_car),
            const SizedBox(height: 16),
            _buildVehicleTypeSelector(context, isDark),
            const SizedBox(height: 24),
            
            _buildSectionTitle(context, 'Información Adicional', Icons.info),
            const SizedBox(height: 16),
            AuthTextArea(
              controller: _descripcionController,
              label: 'Descripción (Opcional)',
              icon: Icons.description_outlined,
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            _buildEstadoSelector(context, isDark),
            const SizedBox(height: 16),
            AuthTextArea(
              controller: _notasAdminController,
              label: 'Notas del Administrador',
              icon: Icons.note_outlined,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 32),
            
            _buildButtons(context),
            const SizedBox(height: 20),
          ],
        ),
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
          child: Icon(
            icon,
            size: 20,
            color: AppColors.primary,
          ),
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

  Widget _buildSearchableSelector<T>({
    required BuildContext context,
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
                    Text(
                      label,
                      style: TextStyle(
                         color: isDark ? Colors.white54 : Colors.black54,
                         fontSize: 13,
                         fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
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
              const SizedBox(width: 8), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleTypeSelector(BuildContext context, bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _tiposVehiculoDisponibles.map((tipo) {
        final isSelected = _formData.tiposVehiculo.contains(tipo);
        
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _formData.tiposVehiculo = List.from(_formData.tiposVehiculo)..remove(tipo);
              } else {
                _formData.tiposVehiculo = List.from(_formData.tiposVehiculo)..add(tipo);
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
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEstadoSelector(BuildContext context, bool isDark) {
    final estados = ['activo', 'inactivo', 'pendiente'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estado de la Empresa',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: estados.map((estado) {
            final isSelected = _formData.estado == estado;
            
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _formData.estado = estado;
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(
                    right: estado != estados.last ? 10 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _getEstadoColor(estado).withValues(alpha: 0.15)
                        : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? _getEstadoColor(estado)
                          : (isDark ? Colors.white12 : Colors.black12),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getEstadoColor(estado),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatEstado(estado),
                        style: TextStyle(
                          color: isSelected
                              ? _getEstadoColor(estado)
                              : Theme.of(context).textTheme.bodyMedium?.color,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      children: [
        if (widget.onCancel != null)
          Expanded(
            child: OutlinedButton(
              onPressed: widget.isLoading ? null : widget.onCancel,
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
                'Cancelar',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (widget.onCancel != null) const SizedBox(width: 16),
        Expanded(
          flex: widget.onCancel != null ? 1 : 2,
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    widget.empresa != null ? 'Actualizar Empresa' : 'Crear Empresa',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ],
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

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'activo':
        return AppColors.success;
      case 'inactivo':
        return Colors.grey;
      case 'pendiente':
        return AppColors.warning;
      default:
        return Colors.grey;
    }
  }

  String _formatEstado(String estado) {
    return estado[0].toUpperCase() + estado.substring(1).toLowerCase();
  }
}
