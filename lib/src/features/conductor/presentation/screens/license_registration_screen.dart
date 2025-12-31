import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/driver_license_model.dart';
import '../../providers/conductor_profile_provider.dart';
import '../../../../core/config/app_config.dart';
import 'vehicle_only_registration_screen.dart';
import '../widgets/document_upload_widget.dart';

class LicenseRegistrationScreen extends StatefulWidget {
  final int conductorId;
  final DriverLicenseModel? existingLicense;

  const LicenseRegistrationScreen({
    super.key,
    required this.conductorId,
    this.existingLicense,
  });

  @override
  State<LicenseRegistrationScreen> createState() => _LicenseRegistrationScreenState();
}

class _LicenseRegistrationScreenState extends State<LicenseRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _licenseNumberController = TextEditingController();
  DateTime? _licenseExpedicion;
  DateTime? _licenseVencimiento;
  LicenseCategory _selectedCategory = LicenseCategory.c1;
  String? _licenceFotoPath;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    if (widget.existingLicense != null) {
      final license = widget.existingLicense!;
      _licenseNumberController.text = license.numero;
      _licenseExpedicion = license.fechaExpedicion;
      _licenseVencimiento = license.fechaVencimiento;
      _selectedCategory = license.categoria;
      
      // Cargar la URL de la foto si existe
      if (license.foto != null && license.foto!.isNotEmpty) {
        _licenceFotoPath = _buildFullUrl(license.foto!);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingLicense != null;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(isEditing),
      body: Consumer<ConductorProfileProvider>(
        builder: (context, provider, child) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(isEditing),
                    const SizedBox(height: 32),
                    _buildLicenseForm(),
                    const SizedBox(height: 32),
                    _buildSaveButton(provider, isEditing),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isEditing) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        isEditing ? 'Editar Licencia' : 'Registrar Licencia',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEditing) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFF00).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFFFF00).withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFF00).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.badge_rounded,
                  color: Color(0xFFFFFF00),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Actualizar InformaciÃ³n' : 'Licencia de ConducciÃ³n',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEditing ? 'Modifica los datos de tu licencia' : 'Ingresa los datos de tu licencia',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _licenseNumberController,
          label: 'NÃºmero de Licencia',
          hint: 'Ej: 12345678',
          icon: Icons.numbers_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor ingresa el nÃºmero de licencia';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildCategorySelector(),
        const SizedBox(height: 16),
        _buildDateField(
          label: 'Fecha de ExpediciÃ³n',
          selectedDate: _licenseExpedicion,
          onTap: () => _selectDate(context, isExpedicion: true),
        ),
        const SizedBox(height: 16),
        _buildDateField(
          label: 'Fecha de Vencimiento',
          selectedDate: _licenseVencimiento,
          onTap: () => _selectDate(context, isExpedicion: false),
        ),
        const SizedBox(height: 16),
        DocumentUploadWidget(
          label: 'Foto de la Licencia',
          subtitle: 'Imagen o PDF del documento',
          filePath: _licenceFotoPath,
          icon: Icons.badge_rounded,
          acceptedType: DocumentType.any,
          isRequired: false,
          allowGallery: false,
          onTap: () async {
            final path = await DocumentPickerHelper.pickDocument(
              context: context,
              documentType: DocumentType.any,
              allowGallery: false,
            );
            if (path != null) {
              setState(() {
                _licenceFotoPath = path;
              });
            }
          },
          onRemove: () {
            setState(() {
              _licenceFotoPath = null;
            });
          },
        ),
        if (_licenseVencimiento != null && _licenseVencimiento!.isBefore(DateTime.now()))
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_rounded, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Tu licencia estÃ¡ vencida. Debes renovarla para poder recibir viajes.',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
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
    String? Function(String?)? validator,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
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
              labelText: 'Categorï¿½a de Licencia',
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
                  '${ category.label} - ${category.description}',
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
          child: Container(
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

  Widget _buildSaveButton(ConductorProfileProvider provider, bool isEditing) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: provider.isLoading ? null : () => _handleSave(provider, isEditing),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: const Color(0xFFFFFF00),
          disabledBackgroundColor: Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
                isEditing ? 'Actualizar Licencia' : 'Guardar Licencia',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, {required bool isExpedicion}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isExpedicion
          ? (_licenseExpedicion ?? DateTime.now().subtract(const Duration(days: 365 * 5)))
          : (_licenseVencimiento ?? DateTime.now().add(const Duration(days: 365 * 5))),
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

  Future<void> _handleSave(ConductorProfileProvider provider, bool isEditing) async {
    if (!_formKey.currentState!.validate()) return;

    if (_licenseExpedicion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona la fecha de expediciÃ³n'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_licenseVencimiento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona la fecha de vencimiento'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Primero guardar los datos de la licencia
    final license = DriverLicenseModel(
      numero: _licenseNumberController.text,
      fechaExpedicion: _licenseExpedicion!,
      fechaVencimiento: _licenseVencimiento!,
      categoria: _selectedCategory,
    );

    final success = await provider.updateLicense(
      conductorId: widget.conductorId,
      license: license,
    );

    if (!success) {
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

    // Subir la foto si existe (despuÃ©s de guardar los datos)
    bool photoUploaded = true;
    if (_licenceFotoPath != null && !_isRemoteUrl(_licenceFotoPath!)) {
      // Solo subir si es un archivo local (no una URL remota existente)
      final uploadResult = await provider.uploadLicensePhoto(
        conductorId: widget.conductorId,
        licenciaFotoPath: _licenceFotoPath!,
      );

      if (uploadResult == null) {
        photoUploaded = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Licencia guardada pero no se pudo subir la foto. Puedes intentar subirla despuÃ©s.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }

    if (mounted) {
      if (success) {
        // Solo mostrar Ã©xito si no hubo problema con la foto o si no habÃ­a foto
        if (photoUploaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing ? 'Licencia actualizada exitosamente' : 'Licencia guardada exitosamente',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // Si es registro nuevo (no ediciÃ³n), verificar si falta el vehÃ­culo
        if (!isEditing && provider.profile != null) {
          final hasVehicle = provider.profile!.vehiculo != null && 
                             provider.profile!.vehiculo!.isBasicComplete;
          
          if (!hasVehicle) {
            // Mostrar diÃ¡logo para ir a registrar vehÃ­culo
            final goToVehicle = await showDialog<bool>(
              context: context,
              builder: (context) => _buildNavigationDialog(
                icon: Icons.directions_car_rounded,
                title: 'Registrar VehÃ­culo',
                message: 'Â¡Licencia guardada! Â¿Deseas continuar registrando tu vehÃ­culo ahora?',
              ),
            );

            if (goToVehicle == true && mounted) {
              // Ir a la pantalla de registro de vehÃ­culo
              final vehicleResult = await Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => VehicleOnlyRegistrationScreen(
                    conductorId: widget.conductorId,
                  ),
                ),
              );
              // Si guardÃ³ el vehÃ­culo, retornar true
              if (vehicleResult == true) {
                return;
              }
            }
          }
        }
        
        Navigator.pop(context, true);
      }
    }
  }

  Widget _buildNavigationDialog({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFF00).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFFFFFF00),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'DespuÃ©s',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFFFFFF00),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continuar',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
