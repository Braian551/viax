import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/features/conductor/presentation/widgets/steps/vehicle_step_widget.dart';
import 'package:viax/src/features/conductor/presentation/widgets/components/image_upload_card.dart';
import 'package:viax/src/features/conductor/presentation/widgets/components/company_picker_sheet.dart';
import 'package:viax/src/features/conductor/presentation/widgets/document_upload_widget.dart'; // Helper for picking documents
import 'package:viax/src/features/auth/presentation/widgets/register_step_indicator.dart';
import '../../models/vehicle_model.dart';
import '../../models/driver_license_model.dart';
import '../../providers/conductor_profile_provider.dart';

class VehicleOnlyRegistrationScreen extends StatefulWidget {
  final int conductorId;
  final VehicleModel? existingVehicle;
  final DriverLicenseModel? existingLicense; // Add license
  final Map<String, dynamic>? conductorUser;

  final int initialStep;

  const VehicleOnlyRegistrationScreen({
    super.key,
    required this.conductorId,
    this.existingVehicle,
    this.existingLicense,
    this.conductorUser,
    this.initialStep = 0,
  });

  @override
  State<VehicleOnlyRegistrationScreen> createState() => _VehicleOnlyRegistrationScreenState();
}

class _VehicleOnlyRegistrationScreenState extends State<VehicleOnlyRegistrationScreen> {
  late int _currentStep;
  final int _totalSteps = 3; // Vehicle, License, Documents
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // --- Step 1: Vehicle Data ---
  final _placaController = TextEditingController();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anioController = TextEditingController();
  final _colorController = TextEditingController();
  String _selectedType = 'moto';
  // Company
  final _companyController = TextEditingController();
  Map<String, dynamic>? _selectedCompany;
  // Photo
  File? _vehiclePhoto;
  String? _vehiclePhotoUrl;

  // --- Step 2: License Data ---
  final _licenseNumberController = TextEditingController();
  String _selectedCategory = 'A2';
  File? _licensePhoto;
  String? _licensePhotoUrl;
  
  // --- Step 3: Documents Data ---
  final _soatNumberController = TextEditingController();
  DateTime? _soatVencimiento;
  File? _soatPhoto;
  String? _soatPhotoUrl;

  final _tecnomecanicaNumberController = TextEditingController();
  DateTime? _tecnomecanicaVencimiento;
  File? _tecnomecanicaPhoto;
  String? _tecnomecanicaPhotoUrl;

  final _tarjetaPropiedadController = TextEditingController();
  File? _tarjetaPropiedadPhoto;
  String? _tarjetaPropiedadPhotoUrl;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _loadExistingData();
  }

  void _loadExistingData() {
    // 1. Load Vehicle Data
    if (widget.existingVehicle != null) {
      final vehicle = widget.existingVehicle!;
      _placaController.text = vehicle.placa;
      _selectedType = vehicle.tipo.value;
      _marcaController.text = vehicle.marca ?? '';
      _modeloController.text = vehicle.modelo ?? '';
      _anioController.text = vehicle.anio?.toString() ?? '';
      _colorController.text = vehicle.color ?? '';
      
      _soatNumberController.text = vehicle.soatNumero ?? '';
      _soatVencimiento = vehicle.soatVencimiento;
      _tecnomecanicaNumberController.text = vehicle.tecnomecanicaNumero ?? '';
      _tecnomecanicaVencimiento = vehicle.tecnomecanicaVencimiento;
      _tarjetaPropiedadController.text = vehicle.tarjetaPropiedadNumero ?? '';
      
      _vehiclePhotoUrl = UserService.getR2ImageUrl(vehicle.fotoVehiculo);
      _soatPhotoUrl = UserService.getR2ImageUrl(vehicle.fotoSoat);
      _tecnomecanicaPhotoUrl = UserService.getR2ImageUrl(vehicle.fotoTecnomecanica);
      _tarjetaPropiedadPhotoUrl = UserService.getR2ImageUrl(vehicle.fotoTarjetaPropiedad);

      if (_selectedCompany == null && vehicle.empresaId != null) {
        _selectedCompany = {
          'id': vehicle.empresaId,
          'nombre': 'Empresa seleccionada'
        };
        _companyController.text = _selectedCompany!['nombre'];
      }
    }

    // 2. Load License Data
    if (widget.existingLicense != null) {
      final license = widget.existingLicense!;
      _licenseNumberController.text = license.numero;
      _selectedCategory = license.categoria.value;
      _licensePhotoUrl = UserService.getR2ImageUrl(license.foto);
    }

    // 3. Load Company Info
    if (widget.conductorUser != null) {
      if (widget.conductorUser!['empresa_id'] != null) {
        _selectedCompany = {
          'id': widget.conductorUser!['empresa_id'],
          'nombre': widget.conductorUser!['empresa_nombre'] ?? 'Empresa Actual'
        };
        _companyController.text = _selectedCompany!['nombre'];
      }
    }
  }

  @override
  void dispose() {
    // Step 1
    _placaController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _anioController.dispose();
    _colorController.dispose();
    _companyController.dispose();
    // Step 2
    _licenseNumberController.dispose();
    // Step 3
    _soatNumberController.dispose();
    _tecnomecanicaNumberController.dispose();
    _tarjetaPropiedadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Instead of reusing VehicleOnlyRegistrationScreen logic, I am implementing
    // a multi-step editing screen similar to DriverRegistrationScreen
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Editar Mis Documentos', // Changed Title
          style: TextStyle(
             color: isDark ? Colors.white : Colors.black87,
             fontWeight: FontWeight.bold,
          ),
        ), 
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Reused Step Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: RegisterStepIndicator(
                currentStep: _currentStep,
                totalSteps: _totalSteps,
                lineWidth: 40,
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildCurrentStep(isDark),
                ),
              ),
            ),

            _buildBottomBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep(bool isDark) {
    switch (_currentStep) {
      case 0:
        return VehicleStepWidget(
          isDark: isDark,
          selectedVehicleType: _selectedType,
          onTypeSelected: (val) => setState(() => _selectedType = val),
          brandController: _marcaController,
          modelController: _modeloController,
          yearController: _anioController,
          colorController: _colorController,
          plateController: _placaController,
          vehiclePhoto: _vehiclePhoto,
          vehiclePhotoUrl: _vehiclePhotoUrl,
          onPickPhoto: () => _pickSecurePhoto((file) => setState(() => _vehiclePhoto = file)),
          selectedCompany: _selectedCompany,
          companyController: _companyController,
          onShowCompanyPicker: () => _showCompanyPicker(isDark),
          isEditing: widget.existingVehicle != null,
        );
      case 1:
        return _buildLicenseStep(isDark);
      case 2:
        return _buildDocumentsStep(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Step 2: License UI ---
  Widget _buildLicenseStep(bool isDark) {
    return Form(
      key: ValueKey('license_form'),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Licencia de Conducción',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Actualiza los datos de tu licencia.',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 32),

          AuthTextField(
            controller: _licenseNumberController, 
            label: 'Número de Licencia', 
            icon: Icons.card_membership_rounded,
            keyboardType: TextInputType.number,
            validator: (value) => value == null || value.isEmpty ? 'El número de licencia es requerido' : null,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 24),
        
          Text(
            'Categoría',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 120, // Approximate height for grid
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: ['A1', 'A2', 'B1', 'C1'].map((cat) => _buildCategoryChip(cat, isDark)).toList(),
            ),
          ),
          const SizedBox(height: 24),

          ImageUploadCard(
            label: 'Foto de la Licencia',
            file: _licensePhoto,
            networkUrl: _licensePhotoUrl,
            onTap: () => _pickDocumentPhoto((file) => setState(() => _licensePhoto = file)),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, bool isDark) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: 1.5
          ),
        ),
        child: Center(
          child: Text(
            category,
            style: TextStyle(
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  // --- Step 3: Documents UI ---
  Widget _buildDocumentsStep(bool isDark) {
    return Form(
      key: ValueKey('docs_form'),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documentos del Vehículo',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Asegúrate de que toda la documentación esté vigente.',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 32),

          // SOAT
          AuthTextField(
            controller: _soatNumberController,
            label: 'Número del SOAT',
            icon: Icons.health_and_safety_rounded,
            validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          _buildDatePickerField(
            label: 'Vencimiento SOAT',
            selectedDate: _soatVencimiento,
            onTap: () => _pickDate((date) => setState(() => _soatVencimiento = date)),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          ImageUploadCard(
            label: 'Foto del SOAT',
            file: _soatPhoto,
            networkUrl: _soatPhotoUrl,
            onTap: () => _pickDocumentPhoto((file) => setState(() => _soatPhoto = file)),
            isDark: isDark,
          ),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Tecnomecanica
          AuthTextField(
            controller: _tecnomecanicaNumberController,
            label: 'N° Tecnomecánica',
            icon: Icons.build_circle_rounded,
            keyboardType: TextInputType.number,
            validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 12),
          _buildDatePickerField(
            label: 'Vencimiento Tecnomecánica',
            selectedDate: _tecnomecanicaVencimiento,
            onTap: () => _pickDate((date) => setState(() => _tecnomecanicaVencimiento = date)),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          ImageUploadCard(
            label: 'Foto Tecnomecánica',
            file: _tecnomecanicaPhoto,
            networkUrl: _tecnomecanicaPhotoUrl,
            onTap: () => _pickDocumentPhoto((file) => setState(() => _tecnomecanicaPhoto = file)),
            isDark: isDark,
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Tarjeta Propiedad
          AuthTextField(
            controller: _tarjetaPropiedadController,
            label: 'N° Tarjeta Propiedad',
            icon: Icons.folder_shared_rounded,
            keyboardType: TextInputType.number,
            validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 12),
          ImageUploadCard(
            label: 'Foto Tarjeta Propiedad',
            file: _tarjetaPropiedadPhoto,
            networkUrl: _tarjetaPropiedadPhotoUrl,
            onTap: () => _pickDocumentPhoto((file) => setState(() => _tarjetaPropiedadPhoto = file)),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface.withOpacity(0.5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, 
              color: selectedDate == null 
                  ? (isDark ? Colors.white38 : Colors.grey) 
                  : AppColors.primary
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedDate != null
                        ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'
                        : 'Seleccionar fecha',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white24 : Colors.grey[300]),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: TextButton(
                onPressed: _isLoading ? null : () => setState(() => _currentStep--),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Atrás', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700], fontSize: 16)),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleNextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_currentStep == _totalSteps - 1 ? 'Guardar Todo' : 'Siguiente', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNextStep() async {
    // 1. Validate Step
    if (!_validateCurrentStep()) return;

    // 2. Proceed or Save
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      await _saveAllData();
    }
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) { // Vehicle
      if (_marcaController.text.isEmpty || _modeloController.text.isEmpty || 
          _anioController.text.isEmpty || _colorController.text.isEmpty || 
          _placaController.text.isEmpty) {
        CustomSnackbar.showError(context, message: 'Completa los datos del vehículo');
        return false;
      }
      if (_selectedCompany == null) {
        CustomSnackbar.showError(context, message: 'Selecciona una empresa');
        return false;
      }
    } else if (_currentStep == 1) { // License
      if (_licenseNumberController.text.isEmpty) {
        CustomSnackbar.showError(context, message: 'Ingresa tu número de licencia');
        return false;
      }
    } else if (_currentStep == 2) { // Documents
      if (_soatNumberController.text.isEmpty || _soatVencimiento == null ||
          _tecnomecanicaNumberController.text.isEmpty || _tecnomecanicaVencimiento == null ||
          _tarjetaPropiedadController.text.isEmpty) {
        CustomSnackbar.showError(context, message: 'Completa la información de documentos');
        return false;
      }
    }
    return true;
  }

  Future<void> _saveAllData() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<ConductorProfileProvider>(context, listen: false);

    try {
      // --- Save Vehicle Info ---
      final vehicle = VehicleModel(
        placa: _placaController.text,
        tipo: VehicleType.fromString(_selectedType),
        marca: _marcaController.text,
        modelo: _modeloController.text,
        anio: int.tryParse(_anioController.text),
        color: _colorController.text,
        soatNumero: _soatNumberController.text,
        soatVencimiento: _soatVencimiento,
        tecnomecanicaNumero: _tecnomecanicaNumberController.text,
        tecnomecanicaVencimiento: _tecnomecanicaVencimiento,
        tarjetaPropiedadNumero: _tarjetaPropiedadController.text,
        empresaId: _selectedCompany?['id'] != null
            ? int.tryParse(_selectedCompany!['id'].toString())
            : null,
      );

      // This provider method likely updates basic info + doc info in database
      final vehicleSuccess = await provider.updateVehicle(
        conductorId: widget.conductorId,
        vehicle: vehicle,
      );
      
      if (!vehicleSuccess) throw Exception(provider.errorMessage ?? 'Error al vehículo');

      // --- Save License Info ---
      // We use RegisterDriverLicense to update (it is likely an upsert or we just recall it)
      final licenseResult = await UserService.registerDriverLicense(
        userId: widget.conductorId,
        licenseNumber: _licenseNumberController.text,
        category: _selectedCategory,
      );
      
      if (licenseResult['success'] != true) {
         throw Exception('Error licencia: ${licenseResult['message']}');
      }

      // --- Upload Photos ---
      // 1. Vehicle Photo
      if (_vehiclePhoto != null) {
         await UserService.uploadVehiclePhoto(conductorId: widget.conductorId, filePath: _vehiclePhoto!.path);
      }
      
      // 2. License Photo
      if (_licensePhoto != null) {
        await UserService.uploadDriverDocument(userId: widget.conductorId, docType: 'licencia_conduccion', filePath: _licensePhoto!.path);
      }

      // 3. Vehicle Documents
      Map<String, String> docsToUpload = {};
      if (_soatPhoto != null) docsToUpload['soat'] = _soatPhoto!.path;
      if (_tecnomecanicaPhoto != null) docsToUpload['tecnomecanica'] = _tecnomecanicaPhoto!.path;
      if (_tarjetaPropiedadPhoto != null) docsToUpload['tarjeta_propiedad'] = _tarjetaPropiedadPhoto!.path;

      if (docsToUpload.isNotEmpty) {
        await provider.uploadVehicleDocuments(
          conductorId: widget.conductorId,
          soatFotoPath: docsToUpload['soat'],
          tecnomecanicaFotoPath: docsToUpload['tecnomecanica'],
          tarjetaPropiedadFotoPath: docsToUpload['tarjeta_propiedad'],
        );
      }
      
      if (mounted) {
        CustomSnackbar.showSuccess(context, message: '¡Información actualizada correctamente!');
        Navigator.pop(context, true);
      }

    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, message: 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // Helpers
  Future<void> _pickDate(Function(DateTime) onPicked) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.darkSurface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _pickSecurePhoto(Function(File) onPicked) async {
     final path = await DocumentPickerHelper.pickDocument(
        context: context,
        documentType: DocumentType.image,
        allowGallery: false, 
      );
      if (path != null) onPicked(File(path));
  }

  Future<void> _pickDocumentPhoto(Function(File) onPicked) async {
      final path = await DocumentPickerHelper.pickDocument(
        context: context,
        documentType: DocumentType.any, // Allows PDF or Image
        allowGallery: false,
      );
      if (path != null) onPicked(File(path));
  }

  void _showCompanyPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CompanyPickerSheet(
        isDark: isDark, 
        onSelected: (company) {
           if (company != null) {
             setState(() {
               _selectedCompany = company;
               _companyController.text = company['nombre'];
             });
           }
        }
      ),
    );
  }
}
