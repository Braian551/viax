import 'dart:io';
import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/features/conductor/presentation/widgets/components/image_upload_card.dart';
import 'package:viax/src/global/services/auth/user_service.dart';

class VehicleStepWidget extends StatefulWidget {
  final bool isDark;
  final String selectedVehicleType;
  final Function(String) onTypeSelected;
  final TextEditingController brandController;
  final TextEditingController modelController;
  final TextEditingController yearController;
  final TextEditingController colorController;
  final TextEditingController plateController;
  final File? vehiclePhoto;
  final VoidCallback onPickPhoto;
  final Map<String, dynamic>? selectedCompany;
  final TextEditingController companyController;
  final VoidCallback onShowCompanyPicker;

  const VehicleStepWidget({
    super.key,
    required this.isDark,
    required this.selectedVehicleType,
    required this.onTypeSelected,
    required this.brandController,
    required this.modelController,
    required this.yearController,
    required this.colorController,
    required this.plateController,
    required this.vehiclePhoto,
    required this.onPickPhoto,
    required this.selectedCompany,
    required this.companyController,
    required this.onShowCompanyPicker,
  });

  @override
  State<VehicleStepWidget> createState() => _VehicleStepWidgetState();
}

class _VehicleStepWidgetState extends State<VehicleStepWidget> {
  List<Map<String, dynamic>> _colors = [];
  bool _isLoadingColors = true;
  String? _selectedColorName;

  @override
  void initState() {
    super.initState();
    _loadColors();
    // Initialize local state from controller if present
    if (widget.colorController.text.isNotEmpty) {
      _selectedColorName = widget.colorController.text;
    }
  }

  Future<void> _loadColors() async {
    final colors = await UserService.getVehicleColors();
    if (mounted) {
      setState(() {
        _colors = colors;
        _isLoadingColors = false;
        
        // Auto-select if current text matches one
        if (widget.colorController.text.isNotEmpty && 
            !_colors.any((c) => c['nombre'] == widget.colorController.text)) {
              // Custom logic fallback if needed
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 24),
        
        Text(
          'Tipo de Vehículo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _buildVehicleTypeSelector(context),
        const SizedBox(height: 24),

        _buildVehicleDetailsForm(context),
        const SizedBox(height: 32),
        
        _buildPhotoUploadSection(context),
        const SizedBox(height: 24),
        
        _buildCompanySection(context),
        const SizedBox(height: 20),
      ],
    )
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tu Vehículo',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Selecciona el tipo de vehículo y completa los detalles para comenzar.',
          style: TextStyle(
            fontSize: 16,
            color: widget.isDark ? Colors.white60 : Colors.black54,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleTypeSelector(BuildContext context) {
    final List<Map<String, dynamic>> types = [
      {'id': 'moto', 'icon': Icons.two_wheeler_rounded, 'label': 'Moto'},
      {'id': 'carro', 'icon': Icons.directions_car_rounded, 'label': 'Carro'},
      {'id': 'taxi', 'icon': Icons.local_taxi_rounded, 'label': 'Taxi'},
      {'id': 'motocarro', 'icon': Icons.electric_rickshaw_rounded, 'label': 'Motocarro'},
    ];

    return SizedBox(
      height: 110,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
           crossAxisCount: 1,
           childAspectRatio: 1.2, 
           mainAxisSpacing: 12,
        ),
        itemCount: types.length,
        itemBuilder: (context, index) {
          final type = types[index];
          final isSelected = widget.selectedVehicleType == type['id'];
          return _buildTypeCard(context, type['id'] as String, type['icon'] as IconData, type['label'] as String, isSelected);
        },
      ),
    );
  }

  Widget _buildTypeCard(BuildContext context, String id, IconData icon, String label, bool isSelected) {
    return GestureDetector(
      onTap: () => widget.onTypeSelected(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (widget.isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
             color: isSelected 
                 ? AppColors.primary 
                 : (widget.isDark ? Colors.white12 : Colors.grey.shade200),
             width: isSelected ? 2 : 1.5
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                    spreadRadius: -2
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? Colors.white : (widget.isDark ? Colors.white70 : Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : (widget.isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleDetailsForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSurface.withValues(alpha: 0.5) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isDark ? Colors.white10 : Colors.grey.shade100,
        ),
        boxShadow: [
           BoxShadow(
             color: Colors.black.withValues(alpha: 0.05),
             blurRadius: 20,
             offset: const Offset(0, 10),
           )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.commute_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Detalles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AuthTextField(
            controller: widget.brandController,
            label: 'Marca',
            icon: Icons.branding_watermark_rounded,
            validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: widget.modelController,
            label: 'Modelo (Ref)',
            icon: Icons.model_training_rounded,
             validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: widget.yearController,
            label: 'Año',
            icon: Icons.calendar_today_rounded,
            keyboardType: TextInputType.number,
            validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          _isLoadingColors 
             ? Center(child: CircularProgressIndicator(strokeWidth: 2)) 
             : _buildColorDropdown(context),
          const SizedBox(height: 16),
          AuthTextField(
            controller: widget.plateController,
            label: 'Placa',
            icon: Icons.tag_rounded,
            textCapitalization: TextCapitalization.characters,
            validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
          ),
        ],
      ),
    );
  }


  
  Widget _buildColorDropdown(BuildContext context) {
    // Determine isDark from context or widget prop (widget.isDark seems reliable)
    final bool isDark = widget.isDark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark 
              ? AppColors.darkSurface.withValues(alpha: 0.8) 
              : AppColors.lightSurface.withValues(alpha: 0.8),
            isDark 
              ? AppColors.darkCard.withValues(alpha: 0.4) 
              : AppColors.lightCard.withValues(alpha: 0.4),
          ],
        ),
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
      child: DropdownButtonFormField<String>(
        value: _selectedColorName,
        items: _colors.map((color) {
          return DropdownMenuItem<String>(
            value: color['nombre'],
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color(int.parse(color['hex_code'].replaceAll('#', '0xFF'))),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300)
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  color['nombre'],
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            setState(() => _selectedColorName = val);
            widget.colorController.text = val;
          }
        },
        validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
        decoration: InputDecoration(
          labelText: 'Color',
          labelStyle: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
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
            child: Icon(Icons.palette_rounded, color: Colors.white, size: 20),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
        dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
      ),
    );
  }

  Widget _buildPhotoUploadSection(BuildContext context) {
    return ImageUploadCard(
      label: 'Foto del Vehículo',
      file: widget.vehiclePhoto,
      onTap: widget.onPickPhoto,
      isDark: widget.isDark,
    );
  }

  Widget _buildCompanySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Empresa de Transporte',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        GestureDetector(
          onTap: widget.onShowCompanyPicker,
          child: Container(
            padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
              color: widget.isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
              ),
              boxShadow: [
                 BoxShadow(
                   color: Colors.black.withValues(alpha: 0.03),
                   blurRadius: 10,
                   offset: const Offset(0, 4),
                 )
              ]
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.business_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                         widget.companyController.text.isEmpty ? 'Seleccionar Empresa' : widget.companyController.text,
                         style: TextStyle(
                           fontSize: 16,
                           fontWeight: FontWeight.bold,
                           color: widget.isDark ? Colors.white : Colors.black87,
                         ),
                      ),
                      if (widget.companyController.text.isEmpty)
                      Text(
                        'Opcional',
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: widget.isDark ? Colors.white38 : Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
