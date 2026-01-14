import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'package:viax/src/features/conductor/presentation/widgets/components/image_upload_card.dart';
import 'package:viax/src/features/conductor/presentation/widgets/document_upload_widget.dart';
import '../../providers/conductor_profile_provider.dart';
import '../../models/vehicle_model.dart';
import '../../../../global/services/auth/user_service.dart';

class DocumentsManagementScreen extends StatefulWidget {
  final int conductorId;
  final VehicleModel vehicle;

  const DocumentsManagementScreen({
    super.key,
    required this.conductorId,
    required this.vehicle,
  });

  @override
  State<DocumentsManagementScreen> createState() => _DocumentsManagementScreenState();
}

class _DocumentsManagementScreenState extends State<DocumentsManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // SOAT
  late TextEditingController _soatNumberController;
  DateTime? _soatVencimiento;
  File? _soatPhoto;
  String? _soatPhotoUrl;

  // Tecnomecánica
  late TextEditingController _tecnomecanicaNumberController;
  DateTime? _tecnomecanicaVencimiento;
  File? _tecnomecanicaPhoto;
  String? _tecnomecanicaPhotoUrl;

  // Tarjeta Propiedad
  late TextEditingController _tarjetaPropiedadNumberController;
  File? _tarjetaPropiedadPhoto;
  String? _tarjetaPropiedadPhotoUrl;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    // Initialize controllers with existing data
    _soatNumberController = TextEditingController(text: widget.vehicle.soatNumero);
    _soatVencimiento = widget.vehicle.soatVencimiento;
    _soatPhotoUrl = UserService.getR2ImageUrl(widget.vehicle.fotoSoat);

    _tecnomecanicaNumberController = TextEditingController(text: widget.vehicle.tecnomecanicaNumero);
    _tecnomecanicaVencimiento = widget.vehicle.tecnomecanicaVencimiento;
    _tecnomecanicaPhotoUrl = UserService.getR2ImageUrl(widget.vehicle.fotoTecnomecanica);

    _tarjetaPropiedadNumberController = TextEditingController(text: widget.vehicle.tarjetaPropiedadNumero);
    _tarjetaPropiedadPhotoUrl = UserService.getR2ImageUrl(widget.vehicle.fotoTarjetaPropiedad);
  }

  @override
  void dispose() {
    _soatNumberController.dispose();
    _tecnomecanicaNumberController.dispose();
    _tarjetaPropiedadNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Gestionar Documentos',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('SOAT', Icons.health_and_safety_rounded, isDark),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _soatNumberController,
                label: 'Número de Póliza',
                icon: Icons.numbers_rounded,
                validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              _buildDatePicker(
                label: 'Fecha de Vencimiento',
                selectedDate: _soatVencimiento,
                onTap: () => _pickDate((date) => setState(() => _soatVencimiento = date)),
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              ImageUploadCard(
                label: 'Foto del SOAT',
                file: _soatPhoto,
                networkUrl: _soatPhotoUrl,
                onTap: () => _pickPhoto((file) => setState(() => _soatPhoto = file)),
                isDark: isDark,
              ),

              const SizedBox(height: 32),
              _buildSectionHeader('Tecnomecánica', Icons.build_circle_rounded, isDark),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _tecnomecanicaNumberController,
                label: 'Número de Certificado',
                icon: Icons.numbers_rounded,
                validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              _buildDatePicker(
                label: 'Fecha de Vencimiento',
                selectedDate: _tecnomecanicaVencimiento,
                onTap: () => _pickDate((date) => setState(() => _tecnomecanicaVencimiento = date)),
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              ImageUploadCard(
                label: 'Foto Tecnomecánica',
                file: _tecnomecanicaPhoto,
                networkUrl: _tecnomecanicaPhotoUrl,
                onTap: () => _pickPhoto((file) => setState(() => _tecnomecanicaPhoto = file)),
                isDark: isDark,
              ),

              const SizedBox(height: 32),
              _buildSectionHeader('Tarjeta de Propiedad', Icons.card_membership_rounded, isDark),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _tarjetaPropiedadNumberController,
                label: 'Número de Tarjeta',
                icon: Icons.numbers_rounded,
                validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              ImageUploadCard(
                label: 'Foto Tarjeta Propiedad',
                file: _tarjetaPropiedadPhoto,
                networkUrl: _tarjetaPropiedadPhotoUrl,
                onTap: () => _pickPhoto((file) => setState(() => _tarjetaPropiedadPhoto = file)),
                isDark: isDark,
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveDocuments,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Guardar Cambios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker({
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
          color: isDark ? AppColors.darkSurface.withValues(alpha: 0.5) : Colors.white,
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

  Future<void> _pickDate(Function(DateTime) onPicked) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 365)), // Permitir fechas pasadas si el backend lo requiere? Usualmente debe ser futuro.
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _pickPhoto(Function(File) onPicked) async {
    final path = await DocumentPickerHelper.pickDocument(
      context: context,
      documentType: DocumentType.image,
      allowGallery: false,
    );
    if (path != null) onPicked(File(path));
  }

  Future<void> _saveDocuments() async {
    if (!_formKey.currentState!.validate()) return;
    if (_soatVencimiento == null || _tecnomecanicaVencimiento == null) {
      CustomSnackbar.showError(context, message: 'Por favor selecciona las fechas de vencimiento');
      return;
    }

    setState(() => _isLoading = true);
    final provider = context.read<ConductorProfileProvider>();

    try {
      // 1. Update text data (numbers/dates)
      final updatedVehicle = widget.vehicle.copyWith(
        soatNumero: _soatNumberController.text,
        soatVencimiento: _soatVencimiento,
        tecnomecanicaNumero: _tecnomecanicaNumberController.text,
        tecnomecanicaVencimiento: _tecnomecanicaVencimiento,
        tarjetaPropiedadNumero: _tarjetaPropiedadNumberController.text,
      );

      final success = await provider.updateVehicle(
        conductorId: widget.conductorId,
        vehicle: updatedVehicle,
      );

      if (!success) throw Exception(provider.errorMessage ?? 'Error actualizando datos');

      // 2. Upload photos if changed
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
        CustomSnackbar.showSuccess(context, message: 'Documentos actualizados correctamente');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) CustomSnackbar.showError(context, message: 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
