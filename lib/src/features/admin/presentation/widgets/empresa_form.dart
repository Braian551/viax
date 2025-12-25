import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/features/admin/data/models/empresa_transporte_model.dart';
import 'package:viax/src/features/admin/domain/entities/empresa_transporte.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Formulario para crear o editar una empresa de transporte
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
  
  // Controladores para campos de texto
  late TextEditingController _nombreController;
  late TextEditingController _nitController;
  late TextEditingController _razonSocialController;
  late TextEditingController _emailController;
  late TextEditingController _telefonoController;
  late TextEditingController _telefonoSecundarioController;
  late TextEditingController _direccionController;
  late TextEditingController _municipioController;
  late TextEditingController _departamentoController;
  late TextEditingController _representanteNombreController;
  late TextEditingController _representanteTelefonoController;
  late TextEditingController _representanteEmailController;
  late TextEditingController _descripcionController;
  late TextEditingController _notasAdminController;

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
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _formData.logoFile = File(pickedFile.path);
      });
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
    _municipioController = TextEditingController(text: _formData.municipio ?? '');
    _departamentoController = TextEditingController(text: _formData.departamento ?? '');
    _representanteNombreController = TextEditingController(text: _formData.representanteNombre ?? '');
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
    _municipioController.dispose();
    _departamentoController.dispose();
    _representanteNombreController.dispose();
    _representanteTelefonoController.dispose();
    _representanteEmailController.dispose();
    _descripcionController.dispose();
    _notasAdminController.dispose();
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
    _formData.municipio = _municipioController.text.isEmpty ? null : _municipioController.text;
    _formData.departamento = _departamentoController.text.isEmpty ? null : _departamentoController.text;
    _formData.representanteNombre = _representanteNombreController.text.isEmpty ? null : _representanteNombreController.text;
    _formData.representanteTelefono = _representanteTelefonoController.text.isEmpty ? null : _representanteTelefonoController.text;
    _formData.representanteEmail = _representanteEmailController.text.isEmpty ? null : _representanteEmailController.text;
    _formData.descripcion = _descripcionController.text.isEmpty ? null : _descripcionController.text;
    _formData.notasAdmin = _notasAdminController.text.isEmpty ? null : _notasAdminController.text;
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _updateFormData();
      widget.onSubmit(_formData);
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
                                    image: NetworkImage(
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
            _buildTextField(
              context,
              controller: _nombreController,
              label: 'Nombre de la Empresa *',
              hint: 'Ej: Transportes del Norte',
              icon: Icons.business_rounded,
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
                  child: _buildTextField(
                    context,
                    controller: _nitController,
                    label: 'NIT',
                    hint: 'Ej: 900123456-7',
                    icon: Icons.badge_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    context,
                    controller: _razonSocialController,
                    label: 'Razón Social',
                    hint: 'Nombre legal',
                    icon: Icons.article_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            _buildSectionTitle(context, 'Contacto', Icons.contact_phone),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    context,
                    controller: _emailController,
                    label: 'Email',
                    hint: 'empresa@email.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Email inválido';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    context,
                    controller: _telefonoController,
                    label: 'Teléfono Principal',
                    hint: '300 123 4567',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              context,
              controller: _telefonoSecundarioController,
              label: 'Teléfono Secundario',
              hint: 'Opcional',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            
            _buildSectionTitle(context, 'Ubicación', Icons.location_on),
            const SizedBox(height: 16),
            _buildTextField(
              context,
              controller: _direccionController,
              label: 'Dirección',
              hint: 'Calle/Carrera, número, barrio',
              icon: Icons.location_on_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    context,
                    controller: _municipioController,
                    label: 'Municipio',
                    hint: 'Ej: San Juan',
                    icon: Icons.location_city_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    context,
                    controller: _departamentoController,
                    label: 'Departamento',
                    hint: 'Ej: Cundinamarca',
                    icon: Icons.map_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            _buildSectionTitle(context, 'Representante Legal', Icons.person),
            const SizedBox(height: 16),
            _buildTextField(
              context,
              controller: _representanteNombreController,
              label: 'Nombre del Representante',
              hint: 'Nombre completo',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    context,
                    controller: _representanteTelefonoController,
                    label: 'Teléfono',
                    hint: '300 123 4567',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    context,
                    controller: _representanteEmailController,
                    label: 'Email',
                    hint: 'representante@email.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            _buildSectionTitle(context, 'Tipos de Vehículos', Icons.directions_car),
            const SizedBox(height: 16),
            _buildVehicleTypeSelector(context, isDark),
            const SizedBox(height: 24),
            
            _buildSectionTitle(context, 'Información Adicional', Icons.info),
            const SizedBox(height: 16),
            _buildTextField(
              context,
              controller: _descripcionController,
              label: 'Descripción',
              hint: 'Descripción de la empresa...',
              icon: Icons.description_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildEstadoSelector(context, isDark),
            const SizedBox(height: 16),
            _buildTextField(
              context,
              controller: _notasAdminController,
              label: 'Notas del Administrador',
              hint: 'Notas internas...',
              icon: Icons.note_outlined,
              maxLines: 2,
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

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(
        color: Theme.of(context).textTheme.bodyLarge?.color,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: AppColors.primary.withValues(alpha: 0.7))
            : null,
        filled: true,
        fillColor: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.5)
            : AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.error,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
