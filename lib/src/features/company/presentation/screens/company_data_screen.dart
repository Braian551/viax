import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/widgets/auth_text_area.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/features/auth/data/services/colombia_location_service.dart';
import 'package:viax/src/features/auth/presentation/widgets/searchable_dropdown_sheet.dart';

class CompanyDataScreen extends StatefulWidget {
  const CompanyDataScreen({super.key});

  @override
  State<CompanyDataScreen> createState() => _CompanyDataScreenState();
}

class _CompanyDataScreenState extends State<CompanyDataScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Services
  final _locationService = ColombiaLocationService();

  // State
  bool _initialized = false;
  File? _logoFile;
  String? _currentLogoUrl;
  
  // Location State
  List<Department> _departments = [];
  List<City> _cities = [];
  Department? _selectedDepartment;
  City? _selectedCity;
  bool _isLoadingDepartments = false;
  bool _isLoadingCities = false;

  // Controllers
  final _nitController = TextEditingController();
  final _razonSocialController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _telefonoSecundarioController = TextEditingController();
  final _emailController = TextEditingController();
  final _descripcionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Start loading departments immediately, data filtering happens after
    _loadDepartments();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _loadData();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nitController.dispose();
    _razonSocialController.dispose();
    _direccionController.dispose();
    _telefonoController.dispose();
    _telefonoSecundarioController.dispose();
    _emailController.dispose();
    _descripcionController.dispose();
    super.dispose();
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
      _cities = [];
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

  Future<void> _loadData() async {
    final company = context.read<CompanyProvider>().company;
    if (company != null) {
      _nitController.text = company['nit'] ?? '';
      _razonSocialController.text = company['razon_social'] ?? '';
      _direccionController.text = company['direccion'] ?? '';
      _telefonoController.text = company['telefono'] ?? '';
      _telefonoSecundarioController.text = company['telefono_secundario'] ?? '';
      _emailController.text = company['email'] ?? '';
      _descripcionController.text = company['descripcion'] ?? '';
      _currentLogoUrl = company['logo_url'];

      final deptName = company['departamento'];
      final cityName = company['municipio'];
      
      // Wait for departments to be loaded if they aren't already
      if (_departments.isEmpty) {
        await _loadDepartments();
      }

      if (deptName != null && _departments.isNotEmpty) {
        try {
           // Find matching department
           final matchingDept = _departments.where((d) => d.name == deptName).firstOrNull;
           
           if (matchingDept != null) {
              setState(() => _selectedDepartment = matchingDept);
              
              // Load cities for this department
              await _loadCities(matchingDept.id);
              
              if (cityName != null && _cities.isNotEmpty) {
                 final matchingCity = _cities.where((c) => c.name == cityName).firstOrNull;
                 if (matchingCity != null) {
                    setState(() => _selectedCity = matchingCity);
                 }
              }
           }
        } catch (e) {
            print('Error matching location data: $e');
        }
      }
    }
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

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedDepartment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selecciona un departamento')),
        );
        return;
    }
    if (_selectedCity == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selecciona un municipio')),
        );
        return;
    }

    final provider = context.read<CompanyProvider>();
    final success = await provider.updateCompanyProfile({
      'nit': _nitController.text.trim(),
      'razon_social': _razonSocialController.text.trim(),
      'direccion': _direccionController.text.trim(),
      'municipio': _selectedCity?.name ?? '',
      'departamento': _selectedDepartment?.name ?? '',
      'telefono': _telefonoController.text.trim(),
      'telefono_secundario': _telefonoSecundarioController.text.trim(),
      'email': _emailController.text.trim(),
      'descripcion': _descripcionController.text.trim(),
    }, logoFile: _logoFile);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos actualizados exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Error al guardar'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<CompanyProvider>();
    final isLoading = provider.isSaving;
    final isInitialLoading = provider.isLoadingCompany && provider.company == null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Datos de Empresa',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLogoSection(isDark),
                    const SizedBox(height: 32),
                    
                    _buildSectionTitle('Información Legal', isDark),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _nitController,
                      label: 'NIT',
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _razonSocialController,
                      label: 'Razón Social',
                      icon: Icons.business_rounded,
                      validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('Ubicación y Contacto', isDark),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _direccionController,
                      label: 'Dirección Principal',
                      icon: Icons.location_on_outlined,
                      validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Location Selectors - Stacked vertically as requested
                    _buildSearchableSelector<Department>(
                      label: 'Departamento',
                      hint: 'Seleccionar',
                      value: _selectedDepartment,
                      items: _departments,
                      isLoading: _isLoadingDepartments,
                      itemLabel: (d) => d.name,
                      onChanged: (d) {
                        setState(() {
                          _selectedDepartment = d;
                          _selectedCity = null;
                        });
                        _loadCities(d.id);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSearchableSelector<City>(
                      label: 'Municipio',
                      hint: 'Seleccionar',
                      value: _selectedCity,
                      items: _cities,
                      isLoading: _isLoadingCities,
                      itemLabel: (c) => c.name,
                      onChanged: (c) => setState(() => _selectedCity = c),
                    ),

                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _telefonoController,
                      label: 'Teléfono Principal',
                      keyboardType: TextInputType.phone,
                      icon: Icons.phone_outlined,
                      validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _telefonoSecundarioController,
                      label: 'Teléfono Secundario (Opcional)',
                      keyboardType: TextInputType.phone,
                      icon: Icons.phone_android_outlined,
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _emailController,
                      label: 'Correo Electrónico',
                      keyboardType: TextInputType.emailAddress,
                      icon: Icons.email_outlined,
                      validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
                    ),

                    const SizedBox(height: 24),
                    _buildSectionTitle('Información Adicional', isDark),
                    const SizedBox(height: 16),
                    // Use AuthTextArea here for reuse
                    AuthTextArea(
                      controller: _descripcionController,
                      label: 'Descripción de la Empresa',
                      icon: Icons.description_outlined,
                      minLines: 3,
                      maxLines: 5,
                    ),

                    const SizedBox(height: 40),
                    _buildSubmitButton(isLoading),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLogoSection(bool isDark) {
    return Center(
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
                    : (_currentLogoUrl != null 
                        ? DecorationImage(
                            image: NetworkImage(_currentLogoUrl!),
                            fit: BoxFit.cover,
                          ) 
                        : null),
              ),
              child: (_logoFile == null && _currentLogoUrl == null)
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
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.lightTextPrimary,
      ),
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _saveData,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Guardar Cambios',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
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
               // Prefix Icon Container (Matches AuthTextField/Register Screen)
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
                    // Label
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
                Icon(Icons.arrow_drop_down, color: isDark ? Colors.white54 : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
