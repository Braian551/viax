import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/widgets/auth_text_area.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/features/company/presentation/widgets/company_logo.dart';
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
  bool _isLoadingBanks = false;
  List<Map<String, String>> _banks = [];
  Map<String, String>? _selectedBank;

  // Controllers
  final _nitController = TextEditingController();
  final _razonSocialController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _telefonoSecundarioController = TextEditingController();
  final _emailController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _numeroCuentaController = TextEditingController();
  final _titularCuentaController = TextEditingController();
  final _documentoTitularController = TextEditingController();
  final _referenciaTransferenciaController = TextEditingController();
  String _tipoCuenta = 'ahorros';

  String? _validateRequiredText(String? value, {required String fieldName, int min = 2, int max = 120}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$fieldName es requerido';
    if (text.length < min) return '$fieldName debe tener al menos $min caracteres';
    if (text.length > max) return '$fieldName no puede superar $max caracteres';
    return null;
  }

  String? _validateNit(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'NIT es requerido';
    if (!RegExp(r'^\d{6,15}$').hasMatch(text)) {
      return 'NIT debe contener solo números (6 a 15 dígitos)';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Correo electrónico es requerido';
    if (text.length > 100) return 'Correo electrónico no puede superar 100 caracteres';
    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.[A-Za-z]{2,}$').hasMatch(text)) {
      return 'Correo electrónico no es válido';
    }
    return null;
  }

  String? _validatePhone(String? value, {required bool required}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return required ? 'Teléfono es requerido' : null;
    }
    if (!RegExp(r'^\d{7,15}$').hasMatch(text)) {
      return 'Teléfono debe tener entre 7 y 15 dígitos';
    }
    return null;
  }

  String? _validateAccountNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Número de cuenta es requerido';
    if (!RegExp(r'^\d{8,20}$').hasMatch(text)) {
      return 'Número de cuenta debe tener entre 8 y 20 dígitos';
    }
    return null;
  }

  String? _validateHolderDocument(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Documento titular es requerido';
    if (!RegExp(r'^[A-Za-z0-9\-]{5,20}$').hasMatch(text)) {
      return 'Documento debe tener entre 5 y 20 caracteres válidos';
    }
    return null;
  }

  String? _validateOptionalReference(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > 180) return 'Referencia no puede superar 180 caracteres';
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Start loading departments immediately, data filtering happens after
    _loadDepartments();
    _loadBanks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized && mounted) {
        _initialized = true;
        _loadData();
      }
    });
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
    _numeroCuentaController.dispose();
    _titularCuentaController.dispose();
    _documentoTitularController.dispose();
    _referenciaTransferenciaController.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    setState(() => _isLoadingBanks = true);
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/company/colombia_banks.php'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final items = List<Map<String, String>>.from(
            (data['data'] as List).map(
              (item) => {
                'codigo': item['codigo']?.toString() ?? '',
                'nombre': item['nombre']?.toString() ?? '',
              },
            ),
          );
          if (mounted) {
            setState(() {
              _banks = items.where((e) => (e['nombre'] ?? '').isNotEmpty).toList();
              if (_selectedBank != null && _banks.isNotEmpty) {
                final match = _banks.where((e) => e['codigo'] == _selectedBank!['codigo']).firstOrNull;
                if (match != null) {
                  _selectedBank = match;
                }
              }
            });
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingBanks = false);
      }
    }
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
    final provider = context.read<CompanyProvider>();
    await provider.loadSettings();
    if (!mounted) return;

    final company = provider.company;
    final settings = provider.settings;
    if (!mounted) return;

    if (company != null) {
      _nitController.text = company['nit'] ?? '';
      _razonSocialController.text = company['razon_social'] ?? '';
      _direccionController.text = company['direccion'] ?? '';
      _telefonoController.text = company['telefono'] ?? '';
      _telefonoSecundarioController.text = company['telefono_secundario'] ?? '';
      _emailController.text = company['email'] ?? '';
      _descripcionController.text = company['descripcion'] ?? '';
      _currentLogoUrl = company['logo_url'];

      _numeroCuentaController.text = settings['numero_cuenta']?.toString() ?? '';
      _titularCuentaController.text = settings['titular_cuenta']?.toString() ?? '';
      _documentoTitularController.text = settings['documento_titular']?.toString() ?? '';
      _referenciaTransferenciaController.text = settings['referencia_transferencia']?.toString() ?? '';
      _tipoCuenta = settings['tipo_cuenta']?.toString().toLowerCase() == 'corriente' ? 'corriente' : 'ahorros';

      final bankCode = settings['banco_codigo']?.toString();
      final bankName = settings['banco_nombre']?.toString();
      if (bankCode != null || bankName != null) {
        _selectedBank = {
          'codigo': bankCode ?? '',
          'nombre': bankName ?? '',
        };
      }

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
            debugPrint('Error matching location data: $e');
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
    if (_selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un banco')), 
      );
      return;
    }

    final provider = context.read<CompanyProvider>();
    final profileSaved = await provider.updateCompanyProfile({
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

    if (!profileSaved) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Error al guardar'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final settingsSaved = await provider.updateSettings({
      'banco_codigo': _selectedBank?['codigo'],
      'banco_nombre': _selectedBank?['nombre'],
      'tipo_cuenta': _tipoCuenta,
      'numero_cuenta': _numeroCuentaController.text.trim(),
      'titular_cuenta': _titularCuentaController.text.trim(),
      'documento_titular': _documentoTitularController.text.trim(),
      'referencia_transferencia': _referenciaTransferenciaController.text.trim(),
    });

    if (!mounted) return;

    if (settingsSaved) {
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
                    _buildOrganizedSections(isDark),

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
                    : null,
              ),
              child: _logoFile == null
                  ? (_currentLogoUrl != null && _currentLogoUrl!.isNotEmpty
                      ? CompanyLogo(
                          logoKey: _currentLogoUrl,
                          nombreEmpresa: _razonSocialController.text.trim(),
                          size: 96,
                          fontSize: 34,
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_rounded, size: 28, color: Colors.grey[500]),
                          ],
                        ))
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

  Widget _buildOrganizedSections(bool isDark) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionPanelList.radio(
        initialOpenPanelValue: 'legal',
        elevation: 0,
        expandedHeaderPadding: EdgeInsets.zero,
        animationDuration: const Duration(milliseconds: 220),
        children: [
          _buildSectionPanel(
            value: 'legal',
            title: '1. Información Legal',
            icon: Icons.gavel_rounded,
            isDark: isDark,
            child: Column(
              children: [
                AuthTextField(
                  controller: _nitController,
                  label: 'NIT',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  helperText: 'Solo números, entre 6 y 15 dígitos.',
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  validator: _validateNit,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _razonSocialController,
                  label: 'Razón Social',
                  icon: Icons.business_rounded,
                  helperText: 'Entre 3 y 120 caracteres.',
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(120)],
                  validator: (value) => _validateRequiredText(value, fieldName: 'Razón Social', min: 3, max: 120),
                ),
              ],
            ),
          ),
          _buildSectionPanel(
            value: 'contacto',
            title: '2. Ubicación y Contacto',
            icon: Icons.location_on_rounded,
            isDark: isDark,
            child: Column(
              children: [
                AuthTextField(
                  controller: _direccionController,
                  label: 'Dirección Principal',
                  icon: Icons.location_on_outlined,
                  helperText: 'Entre 5 y 140 caracteres.',
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [LengthLimitingTextInputFormatter(140)],
                  validator: (value) => _validateRequiredText(value, fieldName: 'Dirección', min: 5, max: 140),
                ),
                const SizedBox(height: 16),
                _buildSearchableSelector<Department>(
                  label: 'Departamento',
                  hint: 'Seleccionar',
                  value: _selectedDepartment,
                  items: _departments,
                  isLoading: _isLoadingDepartments,
                  itemLabel: (d) => d.name,
                  helperText: 'Selecciona el departamento de operación.',
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
                  helperText: 'Selecciona el municipio de operación.',
                  onChanged: (c) => setState(() => _selectedCity = c),
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _telefonoController,
                  label: 'Teléfono Principal',
                  keyboardType: TextInputType.phone,
                  icon: Icons.phone_outlined,
                  helperText: 'Solo números, entre 7 y 15 dígitos.',
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  validator: (value) => _validatePhone(value, required: true),
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _telefonoSecundarioController,
                  label: 'Teléfono Secundario (Opcional)',
                  keyboardType: TextInputType.phone,
                  icon: Icons.phone_android_outlined,
                  helperText: 'Opcional. Si lo ingresas, entre 7 y 15 dígitos.',
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  validator: (value) => _validatePhone(value, required: false),
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _emailController,
                  label: 'Correo Electrónico',
                  keyboardType: TextInputType.emailAddress,
                  icon: Icons.email_outlined,
                  helperText: 'Formato válido: nombre@dominio.com (máx. 100).',
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  validator: _validateEmail,
                ),
              ],
            ),
          ),
          _buildSectionPanel(
            value: 'adicional',
            title: '3. Información Adicional',
            icon: Icons.notes_rounded,
            isDark: isDark,
            child: AuthTextArea(
              controller: _descripcionController,
              label: 'Descripción de la Empresa',
              icon: Icons.description_outlined,
              helperText: 'Describe tu empresa en 10 a 500 caracteres.',
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
              minLines: 3,
              maxLines: 5,
              validator: (value) => _validateRequiredText(value, fieldName: 'Descripción', min: 10, max: 500),
            ),
          ),
          _buildSectionPanel(
            value: 'bancaria',
            title: '4. Cuenta bancaria para transferencias',
            icon: Icons.account_balance_rounded,
            isDark: isDark,
            child: Column(
              children: [
                _buildSearchableSelector<Map<String, String>>(
                  label: 'Banco (Colombia)',
                  hint: _isLoadingBanks ? 'Cargando bancos...' : 'Seleccionar banco',
                  value: _selectedBank,
                  items: _banks,
                  itemLabel: (item) => item['nombre'] ?? '',
                  helperText: 'Selecciona el banco de destino para transferencias.',
                  onChanged: (bank) => setState(() => _selectedBank = bank),
                  isLoading: _isLoadingBanks,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _tipoCuenta,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de cuenta',
                    helperText: 'Elige entre ahorros o corriente.',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ahorros', child: Text('Ahorros')),
                    DropdownMenuItem(value: 'corriente', child: Text('Corriente')),
                  ],
                  validator: (value) => value == null || value.isEmpty ? 'Selecciona un tipo de cuenta' : null,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _tipoCuenta = value);
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _numeroCuentaController,
                  label: 'Número de cuenta',
                  icon: Icons.account_balance_wallet_outlined,
                  keyboardType: TextInputType.number,
                  helperText: 'Solo números, entre 8 y 20 dígitos.',
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(20),
                  ],
                  validator: _validateAccountNumber,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _titularCuentaController,
                  label: 'Titular de la cuenta',
                  icon: Icons.person_outline,
                  helperText: 'Nombre completo del titular (3 a 100 caracteres).',
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  validator: (value) => _validateRequiredText(value, fieldName: 'Titular de la cuenta', min: 3, max: 100),
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _documentoTitularController,
                  label: 'Documento titular (CC/NIT)',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.text,
                  helperText: 'Entre 5 y 20 caracteres. Letras, números o guion.',
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [LengthLimitingTextInputFormatter(20)],
                  validator: _validateHolderDocument,
                ),
                const SizedBox(height: 16),
                AuthTextArea(
                  controller: _referenciaTransferenciaController,
                  label: 'Referencia de pago (opcional)',
                  icon: Icons.info_outline,
                  helperText: 'Opcional. Máximo 180 caracteres.',
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [LengthLimitingTextInputFormatter(180)],
                  minLines: 2,
                  maxLines: 4,
                  validator: _validateOptionalReference,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ExpansionPanelRadio _buildSectionPanel({
    required String value,
    required String title,
    required IconData icon,
    required bool isDark,
    required Widget child,
  }) {
    return ExpansionPanelRadio(
      value: value,
      canTapOnHeader: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      headerBuilder: (context, isExpanded) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Icon(icon, color: AppColors.primary),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
        );
      },
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        child: child,
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
    String? helperText,
    IconData icon = Icons.arrow_drop_down,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final showHelperText = helperText != null && helperText.isNotEmpty && value == null;
    
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
        onTap: isLoading ? null : () {
          if (items.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No hay opciones para $label. Intenta de nuevo.'),
              ),
            );
            if (label == 'Banco (Colombia)') {
              _loadBanks();
            }
            return;
          }
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  Icon(Icons.arrow_drop_down, color: isDark ? Colors.white54 : Colors.grey),
              ],
              ),
              if (showHelperText)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 6),
                  child: Text(
                    helperText!,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 12,
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
