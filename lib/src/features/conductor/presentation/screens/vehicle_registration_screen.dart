import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vehicle_model.dart';
import '../../models/driver_license_model.dart';
import '../../providers/conductor_profile_provider.dart';
import '../../../../core/config/app_config.dart';
import '../widgets/document_upload_widget.dart';
import 'package:viax/src/global/services/auth/user_service.dart';

class VehicleRegistrationScreen extends StatefulWidget {
  final int conductorId;
  final VehicleModel? existingVehicle;

  const VehicleRegistrationScreen({
    super.key,
    required this.conductorId,
    this.existingVehicle,
  });

  @override
  State<VehicleRegistrationScreen> createState() => _VehicleRegistrationScreenState();
}

class _VehicleRegistrationScreenState extends State<VehicleRegistrationScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // License data
  final _licenseNumberController = TextEditingController();
  DateTime? _licenseExpedicion;
  DateTime? _licenseVencimiento;
  LicenseCategory _selectedCategory = LicenseCategory.c1;

  // Vehicle data
  final _placaController = TextEditingController();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anioController = TextEditingController();
  final _colorController = TextEditingController();
  VehicleType _selectedType = VehicleType.moto;

  // Document data
  final _soatNumberController = TextEditingController();
  DateTime? _soatVencimiento;
  String? _soatFotoPath;
  final _tecnomecanicaNumberController = TextEditingController();
  DateTime? _tecnomecanicaVencimiento;
  String? _tecnomecanicaFotoPath;
  final _tarjetaPropiedadController = TextEditingController();
  String? _tarjetaPropiedadFotoPath;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    if (widget.existingVehicle != null) {
      final vehicle = widget.existingVehicle!;
      _placaController.text = vehicle.placa;
      _selectedType = vehicle.tipo;
      _marcaController.text = vehicle.marca ?? '';
      _modeloController.text = vehicle.modelo ?? '';
      _anioController.text = vehicle.anio?.toString() ?? '';
      _colorController.text = vehicle.color ?? '';
      _soatNumberController.text = vehicle.soatNumero ?? '';
      _soatVencimiento = vehicle.soatVencimiento;
      _tecnomecanicaNumberController.text = vehicle.tecnomecanicaNumero ?? '';
      _tecnomecanicaVencimiento = vehicle.tecnomecanicaVencimiento;
      _tarjetaPropiedadController.text = vehicle.tarjetaPropiedadNumero ?? '';
      
      // Cargar las URLs de las fotos si existen
      if (vehicle.fotoSoat != null && vehicle.fotoSoat!.isNotEmpty) {
        _soatFotoPath = _buildFullUrl(vehicle.fotoSoat!);
      }
      if (vehicle.fotoTecnomecanica != null && vehicle.fotoTecnomecanica!.isNotEmpty) {
        _tecnomecanicaFotoPath = _buildFullUrl(vehicle.fotoTecnomecanica!);
      }
      if (vehicle.fotoTarjetaPropiedad != null && vehicle.fotoTarjetaPropiedad!.isNotEmpty) {
        _tarjetaPropiedadFotoPath = _buildFullUrl(vehicle.fotoTarjetaPropiedad!);
      }
    }
  }

  /// Construye la URL completa del documento
  String _buildFullUrl(String relativeUrl) {
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }
    // Las URLs relativas vienen como 'uploads/documentos/...'
    // Necesitamos construir la URL base sin el '/backend' del path
  final baseUrlWithoutPath = AppConfig.baseUrl.replaceAll('/viax/backend', '');
    return '$baseUrlWithoutPath/$relativeUrl';
  }

  /// Verifica si una ruta es una URL remota
  bool _isRemoteUrl(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  @override
  void dispose() {
    _licenseNumberController.dispose();
    _placaController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _anioController.dispose();
    _colorController.dispose();
    _soatNumberController.dispose();
    _tecnomecanicaNumberController.dispose();
    _tarjetaPropiedadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Consumer<ConductorProfileProvider>(
        builder: (context, provider, child) {
          return SafeArea(
            child: Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: _buildCurrentStep(),
                    ),
                  ),
                ),
                _buildNavigationButtons(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Registrar Vehículo',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _buildStepCircle(0, 'Licencia'),
          _buildStepLine(0),
          _buildStepCircle(1, 'Vehí­culo'),
          _buildStepLine(1),
          _buildStepCircle(2, 'Documentos'),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;
    
    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted
                  ? const Color(0xFFFFFF00)
                  : isActive
                      ? const Color(0xFFFFFF00).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive || isCompleted 
                    ? const Color(0xFFFFFF00) 
                    : Colors.white.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.black, size: 20)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: isActive ? const Color(0xFFFFFF00) : Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white54,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(int step) {
    return Expanded(
      flex: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: 2,
        margin: const EdgeInsets.only(bottom: 30),
        color: step < _currentStep
            ? const Color(0xFFFFFF00)
            : Colors.white.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildLicenseStep();
      case 1:
        return _buildVehicleStep();
      case 2:
        return _buildDocumentsStep();
      default:
        return Container();
    }
  }

  Widget _buildLicenseStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionHeader(
          'Licencia de Conducción',
          Icons.badge_rounded,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _licenseNumberController,
          label: 'Número de Licencia',
          hint: 'Ej: 12345678',
          icon: Icons.numbers_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor ingresa el número de licencia';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildCategorySelector(),
        const SizedBox(height: 16),
        _buildDateField(
          label: 'Fecha de Expedición',
          selectedDate: _licenseExpedicion,
          onTap: () => _selectDate(context, isExpedicion: true),
        ),
        const SizedBox(height: 16),
        _buildDateField(
          label: 'Fecha de Vencimiento',
          selectedDate: _licenseVencimiento,
          onTap: () => _selectDate(context, isExpedicion: false),
        ),
      ],
    );
  }

  Widget _buildVehicleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionHeader(
          'Información del Vehículo',
          Icons.directions_car_rounded,
        ),
        const SizedBox(height: 24),
        _buildVehicleTypeSelector(),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _placaController,
          label: 'Placa',
          hint: 'Ej: ABC123',
          icon: Icons.pin_rounded,
          textCapitalization: TextCapitalization.characters,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor ingresa la placa';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _marcaController,
                label: 'Marca',
                hint: 'Ej: Toyota',
                icon: Icons.branding_watermark_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Requerido';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                controller: _modeloController,
                label: 'Modelo',
                hint: 'Ej: Corolla',
                icon: Icons.description_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Requerido';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _anioController,
                label: 'Año',
                hint: '2020',
                icon: Icons.calendar_today_rounded,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Requerido';
                  }
                  final year = int.tryParse(value);
                  if (year == null || year < 1900 || year > DateTime.now().year + 1) {
                    return 'Año inválido';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                controller: _colorController,
                label: 'Color',
                hint: 'Ej: Blanco',
                icon: Icons.palette_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Requerido';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDocumentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionHeader(
          'Documentos del Vehículo',
          Icons.description_rounded,
        ),
        const SizedBox(height: 24),
        
        // SOAT
        _buildTextField(
          controller: _soatNumberController,
          label: 'Número SOAT',
          hint: 'Número de póliza SOAT',
          icon: Icons.shield_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor ingresa el número SOAT';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildDateField(
          label: 'Vencimiento SOAT',
          selectedDate: _soatVencimiento,
          onTap: () => _selectSOATDate(context),
        ),
        const SizedBox(height: 16),
        DocumentUploadWidget(
          label: 'Documento SOAT',
          subtitle: 'Foto o PDF del SOAT',
          filePath: _soatFotoPath,
          icon: Icons.shield_rounded,
          acceptedType: DocumentType.any,
          isRequired: false,
          allowGallery: false, // Strict: Camera only
          onTap: () async {
            final path = await DocumentPickerHelper.pickDocument(
              context: context,
              documentType: DocumentType.any,
              allowGallery: false,
            );
            if (path != null) {
              setState(() {
                _soatFotoPath = path;
              });
            }
          },
          onRemove: () {
            setState(() {
              _soatFotoPath = null;
            });
          },
        ),
        
        const SizedBox(height: 24),
        const Divider(color: Colors.white24, thickness: 1),
        const SizedBox(height: 24),
        
        // Tecnomecánica
        _buildTextField(
          controller: _tecnomecanicaNumberController,
          label: 'Número Tecnomecánica',
          hint: 'Número de certificado',
          icon: Icons.build_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor ingresa el número de tecnomecánica';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildDateField(
          label: 'Vencimiento Tecnomecánica',
          selectedDate: _tecnomecanicaVencimiento,
          onTap: () => _selectTecnomecanicaDate(context),
        ),
        const SizedBox(height: 16),
        DocumentUploadWidget(
          label: 'Certificado Tecnomecánica',
          subtitle: 'Foto o PDF del certificado',
          filePath: _tecnomecanicaFotoPath,
          icon: Icons.build_rounded,
          acceptedType: DocumentType.any,
          isRequired: false,
          allowGallery: false, // Strict: Camera only
          onTap: () async {
            final path = await DocumentPickerHelper.pickDocument(
              context: context,
              documentType: DocumentType.any,
              allowGallery: false,
            );
            if (path != null) {
              setState(() {
                _tecnomecanicaFotoPath = path;
              });
            }
          },
          onRemove: () {
            setState(() {
              _tecnomecanicaFotoPath = null;
            });
          },
        ),
        
        const SizedBox(height: 24),
        const Divider(color: Colors.white24, thickness: 1),
        const SizedBox(height: 24),
        
        // Tarjeta de propiedad
        _buildTextField(
          controller: _tarjetaPropiedadController,
          label: 'Tarjeta de Propiedad',
          hint: 'Número de tarjeta',
          icon: Icons.credit_card_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor ingresa el número de tarjeta de propiedad';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DocumentUploadWidget(
          label: 'Tarjeta de Propiedad',
          subtitle: 'Foto o PDF de la tarjeta',
          filePath: _tarjetaPropiedadFotoPath,
          icon: Icons.credit_card_rounded,
          acceptedType: DocumentType.any,
          isRequired: false,
          allowGallery: false, // Strict: Camera only
          onTap: () async {
            final path = await DocumentPickerHelper.pickDocument(
              context: context,
              documentType: DocumentType.any,
              allowGallery: false,
            );
            if (path != null) {
              setState(() {
                _tarjetaPropiedadFotoPath = path;
              });
            }
          },
          onRemove: () {
            setState(() {
              _tarjetaPropiedadFotoPath = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFF00).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFFFFF00), size: 24),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              prefixIcon: Icon(icon, color: const Color(0xFFFFFF00)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
              errorStyle: const TextStyle(color: Colors.redAccent),
            ),
            validator: validator,
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleTypeSelector() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tipo de Vehículo',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: VehicleType.values.map((type) {
                  final isSelected = _selectedType == type;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFFFF00).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFFFF00)
                              : Colors.white.withValues(alpha: 0.1),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type.icon,
                            size: 20,
                            color: isSelected ? const Color(0xFFFFFF00) : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            type.label,
                            style: TextStyle(
                              color: isSelected ? const Color(0xFFFFFF00) : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: DropdownButtonFormField<LicenseCategory>(
            value: _selectedCategory,
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Categoría de Licencia',
              labelStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.category_rounded, color: Color(0xFFFFFF00)),
            ),
            isExpanded: true,
            items: LicenseCategory.values
                .where((cat) => cat != LicenseCategory.ninguna)
                .map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(
                  '${category.label} - ${category.description}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedCategory = value);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: Color(0xFFFFFF00)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedDate != null
                            ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'
                            : 'Seleccionar fecha',
                        style: TextStyle(
                          color: selectedDate != null ? Colors.white : Colors.white54,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(ConductorProfileProvider provider) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => _currentStep--),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Atrás',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: provider.isLoading ? null : () => _handleNext(provider),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFFFFFF00),
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: provider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : Text(
                            _currentStep < 2 ? 'Siguiente' : 'Guardar',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, {required bool isExpedicion}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: isExpedicion ? DateTime(1950) : DateTime.now(),
      lastDate: isExpedicion ? DateTime.now() : DateTime(2050),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFFF00),
              onPrimary: Colors.black,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isExpedicion) {
          _licenseExpedicion = picked;
        } else {
          _licenseVencimiento = picked;
        }
      });
    }
  }

  Future<void> _selectSOATDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFFF00),
              onPrimary: Colors.black,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _soatVencimiento = picked);
    }
  }

  Future<void> _selectTecnomecanicaDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFFF00),
              onPrimary: Colors.black,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _tecnomecanicaVencimiento = picked);
    }
  }

  Future<void> _handleNext(ConductorProfileProvider provider) async {
    if (_currentStep < 2) {
      if (_validateCurrentStep()) {
        setState(() => _currentStep++);
      }
    } else {
      // Save all data
      await _saveData(provider);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _licenseNumberController.text.isNotEmpty &&
            _licenseExpedicion != null &&
            _licenseVencimiento != null;
      case 1:
        return _formKey.currentState?.validate() ?? false;
      case 2:
        return _soatNumberController.text.isNotEmpty &&
            _soatVencimiento != null &&
            _tecnomecanicaNumberController.text.isNotEmpty &&
            _tecnomecanicaVencimiento != null &&
            _tarjetaPropiedadController.text.isNotEmpty;
      default:
        return false;
    }
  }

  Future<void> _saveData(ConductorProfileProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    // Save license
    final license = DriverLicenseModel(
      numero: _licenseNumberController.text,
      fechaExpedicion: _licenseExpedicion!,
      fechaVencimiento: _licenseVencimiento!,
      categoria: _selectedCategory,
    );

    final licenseSuccess = await provider.updateLicense(
      conductorId: widget.conductorId,
      license: license,
    );

    if (!licenseSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Error al guardar licencia'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Subir fotos de documentos del vehículo si existen
    if (_soatFotoPath != null || _tecnomecanicaFotoPath != null || _tarjetaPropiedadFotoPath != null) {
      // Filtrar solo las fotos que son archivos locales (no URLs remotas)
      final Map<String, String> documentsToUpload = {};
      
      if (_soatFotoPath != null && !_isRemoteUrl(_soatFotoPath!)) {
        documentsToUpload['soat'] = _soatFotoPath!;
      }
      if (_tecnomecanicaFotoPath != null && !_isRemoteUrl(_tecnomecanicaFotoPath!)) {
        documentsToUpload['tecnomecanica'] = _tecnomecanicaFotoPath!;
      }
      if (_tarjetaPropiedadFotoPath != null && !_isRemoteUrl(_tarjetaPropiedadFotoPath!)) {
        documentsToUpload['tarjeta_propiedad'] = _tarjetaPropiedadFotoPath!;
      }

      // Solo subir si hay documentos nuevos
      if (documentsToUpload.isNotEmpty) {
        final uploadResults = await provider.uploadVehicleDocuments(
          conductorId: widget.conductorId,
          soatFotoPath: documentsToUpload['soat'],
          tecnomecanicaFotoPath: documentsToUpload['tecnomecanica'],
          tarjetaPropiedadFotoPath: documentsToUpload['tarjeta_propiedad'],
        );

        // Verificar si algún upload falló
        final failedUploads = uploadResults.entries.where((e) => e.value == null).toList();
        if (failedUploads.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Advertencia: No se pudieron subir algunas fotos: ${failedUploads.map((e) => e.key).join(", ")}',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }

    final empresaId = await UserService.getCurrentEmpresaId();
    if (empresaId == null || empresaId <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes seleccionar una empresa de transporte'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Save vehicle
    final vehicle = VehicleModel(
      placa: _placaController.text,
      tipo: _selectedType,
      marca: _marcaController.text,
      modelo: _modeloController.text,
      anio: int.parse(_anioController.text),
      color: _colorController.text,
      soatNumero: _soatNumberController.text,
      soatVencimiento: _soatVencimiento,
      tecnomecanicaNumero: _tecnomecanicaNumberController.text,
      tecnomecanicaVencimiento: _tecnomecanicaVencimiento,
      tarjetaPropiedadNumero: _tarjetaPropiedadController.text,
      empresaId: empresaId,
    );

    final vehicleSuccess = await provider.updateVehicle(
      conductorId: widget.conductorId,
      vehicle: vehicle,
    );

    if (mounted) {
      if (vehicleSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Información guardada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Error al guardar vehículo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

