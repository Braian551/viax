import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/features/auth/presentation/widgets/register_step_indicator.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/features/conductor/presentation/widgets/biometric_step_widget.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import 'package:viax/src/features/conductor/presentation/widgets/components/company_picker_sheet.dart';
import 'package:viax/src/features/conductor/presentation/widgets/steps/vehicle_step_widget.dart';
import 'package:viax/src/features/conductor/presentation/widgets/components/image_upload_card.dart';
import 'package:viax/src/features/conductor/presentation/widgets/document_upload_widget.dart';
import 'package:viax/src/core/utils/colombian_plate_utils.dart';

class DriverRegistrationScreen extends StatefulWidget {
  /// Optional initial data to pre-fill the form (used when correcting rejected application)
  final Map<String, dynamic>? initialData;
  
  const DriverRegistrationScreen({super.key, this.initialData});

  @override
  State<DriverRegistrationScreen> createState() => _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {

  int _currentStep = 0;
  final int _totalSteps = 4;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // Step 1: Vehicle Info
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  String _selectedVehicleType = 'moto'; // 'moto' or 'carro'
  
  // New Fields
  File? _vehiclePhoto;
  Map<String, dynamic>? _selectedCompany;
  final TextEditingController _companyController = TextEditingController();

  // Step 2: License Info
  final _licenseNumberController = TextEditingController();
  String _selectedCategory = 'A2'; // A2 for motorbikes initially

  // Step 3: Documents
  final _soatController = TextEditingController();
  final _tecnomechanicController = TextEditingController();
  final _propertyCardController = TextEditingController();

  // Files
  File? _licensePhoto;
  File? _soatPhoto;
  File? _tecnoPhoto;
  File? _propertyPhoto;
  File? _selfiePhoto;

  // Dates
  DateTime? _soatDate;
  DateTime? _tecnoDate;

  // Network URLs for existing images (display only, user must re-upload)
  String? _vehiclePhotoUrl;
  String? _licensePhotoUrl;
  String? _soatPhotoUrl;
  String? _tecnoPhotoUrl;
  String? _propertyPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    final data = widget.initialData;
    if (data == null) return;

    // Vehicle info
    final vehiculo = data['vehiculo'] as Map<String, dynamic>?;
    if (vehiculo != null) {
      _brandController.text = vehiculo['vehiculo_marca'] ?? '';
      _modelController.text = vehiculo['vehiculo_modelo'] ?? '';
      _yearController.text = vehiculo['vehiculo_anio']?.toString() ?? '';
      _colorController.text = vehiculo['vehiculo_color'] ?? '';
      _plateController.text = ColombianPlateUtils.normalize((vehiculo['vehiculo_placa'] ?? '').toString());
      _vehiclePhotoUrl = UserService.getR2ImageUrl(vehiculo['foto_vehiculo']);
      
      // Map vehicle type
      final tipo = vehiculo['vehiculo_tipo']?.toString().toLowerCase() ?? '';
      if (tipo.contains('carro') || tipo.contains('auto')) {
        _selectedVehicleType = 'carro';
      } else if (tipo.contains('taxi')) {
        _selectedVehicleType = 'taxi';
      } else if (tipo.contains('motocarro')) {
        _selectedVehicleType = 'motocarro';
      } else {
        _selectedVehicleType = 'moto';
      }
      
      // Document numbers and dates
      _soatController.text = vehiculo['soat_numero'] ?? '';
      _tecnomechanicController.text = vehiculo['tecnomecanica_numero'] ?? '';
      _propertyCardController.text = vehiculo['tarjeta_propiedad_numero'] ?? '';
      
      // Parse dates
      if (vehiculo['soat_vencimiento'] != null) {
        _soatDate = DateTime.tryParse(vehiculo['soat_vencimiento'].toString());
      }
      if (vehiculo['tecnomecanica_vencimiento'] != null) {
        _tecnoDate = DateTime.tryParse(vehiculo['tecnomecanica_vencimiento'].toString());
      }
      
      // Document photo URLs
      _soatPhotoUrl = UserService.getR2ImageUrl(vehiculo['soat_foto_url']);
      _tecnoPhotoUrl = UserService.getR2ImageUrl(vehiculo['tecnomecanica_foto_url']);
      _propertyPhotoUrl = UserService.getR2ImageUrl(vehiculo['tarjeta_propiedad_foto_url']);
    }

    // License info
    final licencia = data['licencia'] as Map<String, dynamic>?;
    if (licencia != null) {
      _licenseNumberController.text = licencia['licencia_conduccion'] ?? '';
      _selectedCategory = licencia['licencia_categoria'] ?? 'A2';
      _licensePhotoUrl = UserService.getR2ImageUrl(licencia['licencia_foto_url']);
    }
    
    // Company info - we'll need to fetch this separately or it comes in data
    // For now, we just show the name if available
    if (data['empresa_nombre'] != null) {
      _companyController.text = data['empresa_nombre'];
      _selectedCompany = {'id': data['empresa_id'], 'nombre': data['empresa_nombre']};
    }
  }

  Future<void> _pickDate(Function(DateTime) onPicked) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 90)),
      firstDate: now, // Document must be valid now
      lastDate: now.add(const Duration(days: 365 * 5)),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  bool _isBiometricActive = false; // Controls embedded camera view

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _licenseNumberController.dispose();
    _soatController.dispose();
    _tecnomechanicController.dispose();
    _propertyCardController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Always validate the current step before proceeding
    if (!_validateStep(_currentStep)) return;

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _submitRegistration();
    }
  }

  bool _validateStep(int step) {
    if (step == 0) {
      if (_brandController.text.isEmpty || _modelController.text.isEmpty || 
          _yearController.text.isEmpty || _colorController.text.isEmpty || 
          _plateController.text.isEmpty) {
        CustomSnackbar.showError(context, message: 'Completa todos los datos del vehículo.');
        return false;
      }
      if (!ColombianPlateUtils.isValid(_plateController.text)) {
        CustomSnackbar.showError(context, message: 'Placa inválida. Usa formato ABC123 o ABC12D.');
        return false;
      }
      if (_vehiclePhoto == null && _vehiclePhotoUrl == null) {
        CustomSnackbar.showError(context, message: 'Debes subir una foto del vehículo.');
        return false;
      }
      // Validación obligatoria de empresa
      if (_selectedCompany == null) {
        CustomSnackbar.showError(context, message: 'Debes seleccionar una empresa de transporte. Ya no se permite trabajar como independiente.');
        return false;
      }
    } else if (step == 1) {
      if (_licenseNumberController.text.isEmpty) {
         CustomSnackbar.showError(context, message: 'Ingresa el número de tu licencia.');
         return false;
      }
      if (_licensePhoto == null && _licensePhotoUrl == null) {
        CustomSnackbar.showError(context, message: 'Debes subir la foto de tu licencia.');
        return false;
      }
    } else if (step == 2) {
      if (_soatController.text.isEmpty || _tecnomechanicController.text.isEmpty || _propertyCardController.text.isEmpty) {
         CustomSnackbar.showError(context, message: 'Faltan números de documentos.');
         return false;
      }
      if (_soatDate == null || _tecnoDate == null) {
         CustomSnackbar.showError(context, message: 'Selecciona las fechas de vencimiento.');
         return false;
      }
      // Check individual document photos
      if ((_soatPhoto == null && _soatPhotoUrl == null) || 
          (_tecnoPhoto == null && _tecnoPhotoUrl == null) || 
          (_propertyPhoto == null && _propertyPhotoUrl == null)) {
         CustomSnackbar.showError(context, message: 'Faltan fotos de los documentos.');
         return false;
      }
    } else if (step == 3) {
      if (_selfiePhoto == null) {
         CustomSnackbar.showError(context, message: 'Biometría requerida. Tómate la selfie.');
         return false;
      }
    }
    return true;
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submitRegistration() async {
    setState(() => _isLoading = true);

    try {
      final session = await UserService.getSavedSession();
      final userId = session?['id'];

      if (userId == null) {
        CustomSnackbar.showError(context, message: 'Error de sesión. Intenta reconectar.');
        setState(() => _isLoading = false);
        return;
      }

      final uid = userId is int ? userId : int.tryParse(userId.toString()) ?? 0;
      
      // 1. Register Data
      final licenseResult = await UserService.registerDriverLicense(
        userId: uid,
        licenseNumber: _licenseNumberController.text,
        category: _selectedCategory,
      );

      if (licenseResult['success'] != true) {
         CustomSnackbar.showError(context, message: 'Error licencia: ${licenseResult['message']}');
         setState(() => _isLoading = false);
         return;
      }

      final result = await UserService.registerDriverVehicle(
        userId: uid,
        type: _selectedVehicleType,
        brand: _brandController.text,
        model: _modelController.text,
        year: _yearController.text,
        color: _colorController.text,
        plate: ColombianPlateUtils.normalize(_plateController.text),

        soatNumber: _soatController.text,
        soatDate: _soatDate!.toIso8601String().split('T')[0],
        tecnomecanicaNumber: _tecnomechanicController.text,
        tecnomecanicaDate: _tecnoDate!.toIso8601String().split('T')[0],
        propertyCardNumber: _propertyCardController.text,
        companyId: _selectedCompany!['id'], // Obligatorio - ya validado en _validateStep
      );

      if (result['success'] == true) {
        // Upload Vehicle Photo if exists
        print('Registration Debug: Vehicle registration success. Checking photo...');
        if (_vehiclePhoto != null) {
          print('Registration Debug: Uploading vehicle photo from ${_vehiclePhoto!.path}');
          final uploadResult = await UserService.uploadVehiclePhoto(conductorId: uid, filePath: _vehiclePhoto!.path);
          print('Registration Debug: Upload result: $uploadResult');
        } else {
          print('Registration Debug: Vehicle photo is null!');
        }
      } else {
         print('Registration Debug: Vehicle registration failed: ${result['message']}');
         CustomSnackbar.showError(context, message: 'Error datos basico: ${result['message']}');
         setState(() => _isLoading = false);
         return;
      }

      // 2. Upload Documents
      // We process uploads sequentially to ensure ID/License is there before biometrics
      if (_licensePhoto != null) {
        await UserService.uploadDriverDocument(userId: uid, docType: 'licencia_conduccion', filePath: _licensePhoto!.path);
      }
      if (_soatPhoto != null) {
        await UserService.uploadDriverDocument(userId: uid, docType: 'soat', filePath: _soatPhoto!.path);
      }
      if (_tecnoPhoto != null) {
        await UserService.uploadDriverDocument(userId: uid, docType: 'tecnomecanica', filePath: _tecnoPhoto!.path);
      }
      if (_propertyPhoto != null) {
        await UserService.uploadDriverDocument(userId: uid, docType: 'tarjeta_propiedad', filePath: _propertyPhoto!.path);
      }

      // 3. Biometric Verification
      if (_selfiePhoto != null) {
        final bioResult = await UserService.verifyBiometrics(userId: uid, selfiePath: _selfiePhoto!.path);
        
        if (bioResult['success'] == true) {
             if (mounted) {
               setState(() => _isLoading = false);
               CustomSnackbar.showSuccess(context, message: '¡Verificado! Solicitud enviada.');
               await Future.delayed(const Duration(seconds: 2));
               if (mounted) Navigator.pop(context);
             }
        } else {
             // Handle blocked or mismatch or other errors
             final status = bioResult['biometric_status'] ?? 'unknown';
             String errorMsg = bioResult['message'] ?? 'Error en verificación biométrica.';
             
             if (status == 'blocked') errorMsg = 'Cuenta bloqueada por seguridad.';
             if (status == 'mismatch') errorMsg = 'El rostro no coincide con documentos.';
             
             if (mounted) {
                CustomSnackbar.showError(context, message: errorMsg);
                setState(() => _isLoading = false);
             }
        }
      } else {
         // Should not happen due to validation, but safe fallback
         setState(() => _isLoading = false);
         CustomSnackbar.showSuccess(context, message: 'Solicitud enviada (Sin biometría).');
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackbar.showError(context, message: 'Ocurrió un error inesperado: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
           // Background decoration
           Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Responsive Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Back Button - Compact
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded, 
                            color: isDark ? Colors.white : Colors.black87, size: 18),
                          onPressed: _prevStep,
                          style: IconButton.styleFrom(
                            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            padding: EdgeInsets.zero, // Remove internal padding
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Step Indicator - Flexible
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: RegisterStepIndicator(
                              currentStep: _currentStep,
                              totalSteps: _totalSteps,
                            ),
                          ),
                        ),
                      ),
                       // Spacer to balance the row (40width + 16gap)
                       const SizedBox(width: 56), 
                    ],
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _buildCurrentStep(isDark),
                    ),
                  ),
                ),

                // Bottom Button
                 Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_isLoading || (_currentStep == 3 && _selfiePhoto == null)) 
                          ? null 
                          : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _currentStep == _totalSteps - 1 ? 'Enviar Solicitud' : 'Siguiente',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildCurrentStep(bool isDark) {
    switch (_currentStep) {
      case 0: return _buildVehicleStep(isDark);
      case 1: return _buildLicenseStep(isDark);
      case 2: return _buildDocumentsStep(isDark);
      case 3: return _buildBiometricStep(isDark);
      default: return const SizedBox.shrink();
    }
  }

  /// Para fotos de identidad/selfie - SOLO cámara (seguridad)
  Future<void> _pickSecurePhoto(Function(File) onPicked) async {
    try {
      // Use DocumentPickerHelper with allowGallery: false to enforce camera and show visual guides
      final path = await DocumentPickerHelper.pickDocument(
        context: context,
        documentType: DocumentType.image,
        allowGallery: false, // Strict: Camera only
      );
      
      if (path != null) {
        onPicked(File(path));
      }
    } catch (e) {
      CustomSnackbar.showError(context, message: 'Error al capturar foto: $e');
    }
  }

  /// Para documentos legales - permite cámara O PDF
  Future<void> _pickDocumentPhoto(Function(File) onPicked) async {
    try {
      // Use DocumentType.any to allow camera or PDF selection
      final path = await DocumentPickerHelper.pickDocument(
        context: context,
        documentType: DocumentType.any,
        allowGallery: false, // No galería, pero sí cámara y PDF
      );
      
      if (path != null) {
        onPicked(File(path));
      }
    } catch (e) {
      CustomSnackbar.showError(context, message: 'Error al seleccionar documento: $e');
    }
  }

  Widget _buildStepTitle(String title, String subtitle, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 28, 
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 16, 
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildVehicleStep(bool isDark) {
    return VehicleStepWidget(
      isDark: isDark,
      selectedVehicleType: _selectedVehicleType,
      onTypeSelected: (type) => setState(() => _selectedVehicleType = type),
      brandController: _brandController,
      modelController: _modelController,
      yearController: _yearController,
      colorController: _colorController,
      plateController: _plateController,
      vehiclePhoto: _vehiclePhoto,
      vehiclePhotoUrl: _vehiclePhotoUrl,
      onPickPhoto: () => _pickSecurePhoto((file) => setState(() => _vehiclePhoto = file)),
      selectedCompany: _selectedCompany,
      companyController: _companyController,
      onShowCompanyPicker: () => _showCompanyPicker(isDark),
    );
  }

  void _showCompanyPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Let sheet handle styling
      builder: (context) => CompanyPickerSheet(
        isDark: isDark, 
        onSelected: (company) {
           if (company == null) {
             // Ya no permitido - mostrar mensaje
             CustomSnackbar.showError(context, message: 'Debes seleccionar una empresa de transporte');
             return;
           }
           setState(() {
             _selectedCompany = company;
             _companyController.text = company['nombre'];
           });
        }
      ),
    );
  }



  Widget _buildLicenseStep(bool isDark) {
    return Form(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        key: const ValueKey(1),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Licencia', 'Datos de tu permiso de conducción.', isDark),
          
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
        SizedBox(
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

  Widget _buildDocumentsStep(bool isDark) {
    return Form(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        key: const ValueKey(2),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Documentos', 'Sube fotos claras de tus documentos.', isDark),
          
          // SOAT
          AuthTextField(
            controller: _soatController,
            label: 'Número del SOAT',
            icon: Icons.health_and_safety_rounded,
            validator: (value) => value == null || value.isEmpty ? 'El número de SOAT es requerido' : null,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            ],
          ),
          const SizedBox(height: 12),
          _buildDatePickerField(
            label: 'Vencimiento SOAT',
            selectedDate: _soatDate,
            onTap: () => _pickDate((date) => setState(() => _soatDate = date)),
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

          // Tecnomecánica
          AuthTextField(
            controller: _tecnomechanicController,
            label: 'N° Revisión Tecnomecánica',
            icon: Icons.build_circle_rounded,
            keyboardType: TextInputType.number,
            validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 12),
          _buildDatePickerField(
            label: 'Vencimiento Tecnomecánica',
            selectedDate: _tecnoDate,
            onTap: () => _pickDate((date) => setState(() => _tecnoDate = date)),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          ImageUploadCard(
            label: 'Foto Tecnomecánica',
            file: _tecnoPhoto,
            networkUrl: _tecnoPhotoUrl,
            onTap: () => _pickDocumentPhoto((file) => setState(() => _tecnoPhoto = file)),
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // Tarjeta Propiedad
          AuthTextField(
            controller: _propertyCardController,
            label: 'N° Tarjeta de Propiedad',
            icon: Icons.folder_shared_rounded,
            keyboardType: TextInputType.number,
            validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 12),
          ImageUploadCard(
            label: 'Foto Tarjeta Propiedad',
            file: _propertyPhoto,
            networkUrl: _propertyPhotoUrl,
            onTap: () => _pickDocumentPhoto((file) => setState(() => _propertyPhoto = file)),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricStep(bool isDark) {
    return Column(
      key: const ValueKey(3),
      children: [
        if (!_isBiometricActive && _selfiePhoto == null) ...[
          _buildStepTitle('Verificación', 'Tómate una selfie para verificar tu identidad.', isDark),
          
          const SizedBox(height: 20),
        
        // Instruction Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'El sistema activará la cámara aquí mismo. Sigue las instrucciones (girar, sonreír) para validar tu identidad.',
                  style: TextStyle(
                    color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),
        ],

        if (_isBiometricActive)
           BiometricStepWidget(
             isDark: isDark,
             onVerificationComplete: (file) {
               setState(() {
                 _selfiePhoto = file;
                 _isBiometricActive = false;
               });
               CustomSnackbar.showSuccess(context, message: '¡Identidad verificada correctamente!');
             },
           )
        else
        // Action Button
        Center(
          child: GestureDetector(
            onTap: () {
              // Simply reopen camera to retake
              setState(() => _isBiometricActive = true);
            },
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Glow Ring (if photo not taken yet)
                    if (_selfiePhoto == null)
                      Container(
                         width: 210,
                         height: 210,
                         decoration: BoxDecoration(
                           shape: BoxShape.circle,
                           border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1),
                           boxShadow: [
                             BoxShadow(
                               color: AppColors.primary.withOpacity(0.2),
                               blurRadius: 20,
                               spreadRadius: 5,
                             )
                           ]
                         ),
                      ),
                    
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                        border: Border.all(
                          color: _selfiePhoto != null ? Colors.green : AppColors.primary,
                          width: _selfiePhoto != null ? 3 : 2,
                        ),
                        image: _selfiePhoto != null 
                          ? DecorationImage(image: FileImage(_selfiePhoto!), fit: BoxFit.cover)
                          : null,
                      ),
                      child: _selfiePhoto == null 
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.face_retouching_natural_rounded, size: 50, color: AppColors.primary),
                                const SizedBox(height: 8),
                                Text(
                                  "INICIAR\nVALIDACIÓN", 
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.primary, 
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16
                                  )
                                )
                              ],
                            ) 
                          : Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black38,
                              ),
                              child: Center(
                                child: Icon(Icons.check_circle, size: 50, color: Colors.greenAccent),
                              ),
                            ),
                    ),
                  ],
                ),
                if (_selfiePhoto == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      "Toca el círculo para activar la cámara",
                      style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 13),
                    ),
                  )
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _selfiePhoto != null 
              ? '¡Validación exitosa! Tu identidad ha sido confirmada. Puedes continuar.' 
              : 'Asegúrate de tener buena iluminación y no usar gafas oscuras o gorra. Esto es necesario para validar que eres tú.',
          textAlign: TextAlign.center,
          style: TextStyle(
             color: _selfiePhoto != null ? Colors.green : (isDark ? Colors.white70 : Colors.black87),
             fontSize: 14,
             fontWeight: _selfiePhoto != null ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }





  Widget _buildCategoryChip(String category, bool isDark) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? Colors.white24 : Colors.black12),
          ),
        ),
        child: Text(
          category,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
          ),
        ),
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
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: isDark ? Colors.white70 : Colors.black54,
              size: 20,
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
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedDate != null
                        ? "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"
                        : "Seleccionar fecha",
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: selectedDate != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}
