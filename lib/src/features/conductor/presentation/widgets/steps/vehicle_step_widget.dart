import 'dart:io';
import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/features/conductor/presentation/widgets/components/image_upload_card.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/features/conductor/presentation/widgets/components/vehicle_searchable_sheet.dart';
import 'package:viax/src/features/company/presentation/widgets/company_logo.dart';
import 'package:viax/src/core/utils/colombian_plate_utils.dart';

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
  final String? vehiclePhotoUrl;
  final VoidCallback onPickPhoto;
  final Map<String, dynamic>? selectedCompany;
  final TextEditingController companyController;
  final VoidCallback onShowCompanyPicker;
  final bool isEditing;

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
    this.vehiclePhotoUrl,
    required this.onPickPhoto,
    required this.selectedCompany,
    required this.companyController,
    required this.onShowCompanyPicker,
    this.isEditing = false,
  });

  @override
  State<VehicleStepWidget> createState() => _VehicleStepWidgetState();
}

class _VehicleStepWidgetState extends State<VehicleStepWidget> {
  List<Map<String, dynamic>> _colors = [];
  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _models = [];
  bool _isLoadingColors = true;
  bool _isLoadingBrands = true;
  bool _isLoadingModels = false;
  String? _selectedColorName;
  String? _selectedBrandId;
  String? _selectedModelId;

  @override
  void initState() {
    super.initState();
    _loadColors();
    _syncInitialVehicleSelectors();
    _loadBrands();
    widget.plateController.text = ColombianPlateUtils.normalize(widget.plateController.text);
    // Initialize local state from controller if present
    if (widget.colorController.text.isNotEmpty) {
      _selectedColorName = widget.colorController.text;
    }
  }

  @override
  void didUpdateWidget(covariant VehicleStepWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedVehicleType != widget.selectedVehicleType) {
      _selectedBrandId = null;
      _selectedModelId = null;
      widget.brandController.clear();
      widget.modelController.clear();
      _models = [];
      _loadBrands();
    }
  }

  void _syncInitialVehicleSelectors() {
    final initialBrand = widget.brandController.text.trim();
    final initialModel = widget.modelController.text.trim();

    if (initialBrand.isNotEmpty) {
      _selectedBrandId = initialBrand.toUpperCase();
    }
    if (initialModel.isNotEmpty) {
      _selectedModelId = initialModel.toUpperCase();
    }
  }

  Future<void> _loadColors() async {
    final colors = await UserService.getVehicleColors();
    // Deduplicate colors locally to prevent DropdownButton errors
    final uniqueColors = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final color in colors) {
      final colorName = (color['nombre'] ?? '').toString().trim();
      if (colorName.isEmpty) continue;

      final key = colorName.toUpperCase();
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueColors.add(color);
      }
    }

    if (!seen.contains('MULTICOLOR')) {
      uniqueColors.add({'nombre': 'Multicolor', 'hex_code': '#9E9E9E'});
    }

    if (mounted) {
      setState(() {
        _colors = uniqueColors;
        _isLoadingColors = false;

        if (widget.colorController.text.isNotEmpty) {
          final current = widget.colorController.text.trim().toUpperCase();
          final match = _colors.cast<Map<String, dynamic>?>().firstWhere(
            (c) => (c?['nombre']?.toString().trim().toUpperCase() ?? '') == current,
            orElse: () => null,
          );
          _selectedColorName = (match?['nombre'] as String?) ?? _selectedColorName;
        }
      });
    }
  }

  Future<void> _loadBrands() async {
    if (!mounted) return;
    setState(() {
      _isLoadingBrands = true;
    });

    final brands = await UserService.getVehicleBrands(
      vehicleType: widget.selectedVehicleType,
    );

    if (!mounted) return;
    setState(() {
      _brands = brands;
      _isLoadingBrands = false;

      final selectedStillExists = _selectedBrandId != null &&
          _brands.any((brand) => brand['id'] == _selectedBrandId);
      if (!selectedStillExists) {
        _selectedBrandId = null;
        widget.brandController.clear();
      }
    });

    if (_selectedBrandId != null) {
      await _loadModels();
    }
  }

  Future<void> _loadModels() async {
    final brandId = _selectedBrandId;
    if (brandId == null || brandId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _models = [];
        _selectedModelId = null;
      });
      widget.modelController.clear();
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingModels = true;
    });

    final models = await UserService.getVehicleModels(
      vehicleType: widget.selectedVehicleType,
      brand: brandId,
      year: widget.yearController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _models = models;
      _isLoadingModels = false;

      final selectedStillExists = _selectedModelId != null &&
          _models.any((model) => model['id'] == _selectedModelId);
      if (!selectedStillExists) {
        _selectedModelId = null;
        widget.modelController.clear();
      }
    });
  }

  Future<List<Map<String, dynamic>>> _searchModels(String query) async {
    final brandId = _selectedBrandId;
    if (brandId == null || brandId.isEmpty) {
      return [];
    }

    return UserService.getVehicleModels(
      vehicleType: widget.selectedVehicleType,
      brand: brandId,
      year: widget.yearController.text.trim(),
      query: query,
    );
  }

  Future<void> _pickVehicleYear() async {
    final now = DateTime.now();
    final currentYear = int.tryParse(widget.yearController.text.trim()) ?? now.year;

    final pickedYear = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Seleccionar año'),
          content: SizedBox(
            width: 320,
            height: 320,
            child: YearPicker(
              firstDate: DateTime(1980),
              lastDate: DateTime(now.year + 1),
              selectedDate: DateTime(currentYear.clamp(1980, now.year + 1)),
              currentDate: DateTime(now.year),
              onChanged: (DateTime date) {
                Navigator.of(context).pop(date.year);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (pickedYear == null) return;

    widget.yearController.text = pickedYear.toString();
    await _loadModels();
  }

  Color _parseColor(String? hexCode) {
    final normalized = (hexCode ?? '').toString().trim();
    if (normalized.isEmpty) {
      return Colors.grey;
    }

    final hex = normalized.replaceAll('#', '');
    final withAlpha = hex.length == 6 ? 'FF$hex' : hex;
    final value = int.tryParse(withAlpha, radix: 16);
    if (value == null) {
      return Colors.grey;
    }
    return Color(value);
  }

  IconData _vehicleTypeIcon() {
    switch (widget.selectedVehicleType) {
      case 'motocarro':
        return Icons.electric_rickshaw_rounded;
      case 'moto':
      case 'mototaxi':
        return Icons.two_wheeler_rounded;
      case 'taxi':
        return Icons.local_taxi_rounded;
      case 'carro':
      default:
        return Icons.directions_car_rounded;
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
        
        if (!widget.isEditing) ...[
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
        ],

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
          widget.isEditing ? 'Editar Información' : 'Tu Vehículo',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.isEditing 
              ? 'Actualiza los datos de tu vehículo.'
              : 'Selecciona el tipo de vehículo y completa los detalles para comenzar.',
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

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
         crossAxisCount: 2,
         childAspectRatio: 1.5, 
         crossAxisSpacing: 12,
         mainAxisSpacing: 12,
      ),
      itemCount: types.length,
      itemBuilder: (context, index) {
        final type = types[index];
        final isSelected = widget.selectedVehicleType == type['id'];
        return _buildTypeCard(context, type['id'] as String, type['icon'] as IconData, type['label'] as String, isSelected);
      },
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
            _buildBrandSelector(context),
          const SizedBox(height: 16),
            _buildModelSelector(context),
          const SizedBox(height: 16),
          _buildYearPickerField(),
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
            hintText: 'Ej: ABC123 o ABC12D',
            validator: ColombianPlateUtils.validate,
            inputFormatters: [
              ColombianPlateInputFormatter(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandSelector(BuildContext context) {
    final bool isDark = widget.isDark;
    final selectedBrand = _brands.cast<Map<String, dynamic>?>().firstWhere(
      (brand) => brand?['id'] == _selectedBrandId,
      orElse: () => null,
    );
    final selectedBrandName = selectedBrand?['name'] as String?;

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
      ),
      child: GestureDetector(
        onTap: _isLoadingBrands || _brands.isEmpty
            ? null
            : () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => VehicleSearchableSheet<Map<String, dynamic>>(
                    title: 'Seleccionar Marca',
                    items: _brands,
                    itemLabel: (item) => (item['name'] as String?) ?? (item['id'] as String),
                    selectedLabel: selectedBrandName,
                    headerIcon: Icons.branding_watermark_rounded,
                    itemIcon: _vehicleTypeIcon(),
                    onSelected: (selected) async {
                      final selectedId = selected['id'] as String;
                      final selectedName = (selected['name'] as String?) ?? selectedId;

                      setState(() {
                        _selectedBrandId = selectedId;
                        _selectedModelId = null;
                        _models = [];
                      });

                      widget.brandController.text = selectedName;
                      widget.modelController.clear();
                      await _loadModels();
                    },
                    searchHint: 'Buscar marca...',
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
                child: const Icon(Icons.branding_watermark_rounded, color: Colors.white, size: 20),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Marca',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedBrandName ?? 'Seleccionar marca',
                      style: TextStyle(
                        color: selectedBrandName != null
                            ? (isDark ? Colors.white : Colors.black87)
                            : Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_isLoadingBrands)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.arrow_drop_down, color: Colors.grey),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelSelector(BuildContext context) {
    final bool isDark = widget.isDark;
    final bool isDisabled = _selectedBrandId == null || _selectedBrandId!.isEmpty;
    final selectedBrand = _brands.cast<Map<String, dynamic>?>().firstWhere(
      (brand) => brand?['id'] == _selectedBrandId,
      orElse: () => null,
    );
    final selectedBrandName = selectedBrand?['name'] as String?;
    final selectedModel = _models.cast<Map<String, dynamic>?>().firstWhere(
      (model) => model?['id'] == _selectedModelId,
      orElse: () => null,
    );
    final selectedModelName = selectedModel?['name'] as String?;

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
      ),
      child: GestureDetector(
        onTap: isDisabled || _isLoadingModels || _models.isEmpty
            ? null
            : () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => VehicleSearchableSheet<Map<String, dynamic>>(
                    title: 'Seleccionar Modelo',
                    items: _models,
                    itemLabel: (item) => (item['name'] as String?) ?? (item['id'] as String),
                    searchText: (item) {
                      final modelName = (item['name'] as String?) ?? (item['id'] as String);
                      return '${selectedBrandName ?? ''} $modelName';
                    },
                    onSearch: _searchModels,
                    selectedLabel: selectedModelName,
                    headerIcon: Icons.model_training_rounded,
                    itemIcon: _vehicleTypeIcon(),
                    onSelected: (selected) {
                      final selectedId = selected['id'] as String;
                      final selectedName = (selected['name'] as String?) ?? selectedId;
                      setState(() {
                        _selectedModelId = selectedId;
                        if (!_models.any((model) => model['id'] == selectedId)) {
                          _models = [selected, ..._models];
                        }
                      });
                      widget.modelController.text = selectedName;
                    },
                    searchHint: 'Buscar modelo...',
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
                child: const Icon(Icons.model_training_rounded, color: Colors.white, size: 20),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Modelo (Ref)',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedModelName ?? (isDisabled ? 'Selecciona marca primero' : 'Seleccionar modelo'),
                      style: TextStyle(
                        color: selectedModelName != null
                            ? (isDark ? Colors.white : Colors.black87)
                            : Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_isLoadingModels)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.arrow_drop_down, color: Colors.grey),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYearPickerField() {
    return GestureDetector(
      onTap: _pickVehicleYear,
      child: AbsorbPointer(
        child: AuthTextField(
          controller: widget.yearController,
          label: 'Año',
          icon: Icons.calendar_today_rounded,
          readOnly: true,
          validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
          suffixIcon: Icon(
            Icons.arrow_drop_down_rounded,
            color: widget.isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ),
    );
  }


  
  Widget _buildColorDropdown(BuildContext context) {
    // Determine isDark from context or widget prop (widget.isDark seems reliable)
    final bool isDark = widget.isDark;
    final selectedValue = _colors.any(
      (color) => (color['nombre'] ?? '').toString() == _selectedColorName,
    )
        ? _selectedColorName
        : null;

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
        menuMaxHeight: 300, // Limit height to allow scrolling
        initialValue: selectedValue,
        items: _colors.map((color) {
          return DropdownMenuItem<String>(
            value: color['nombre'],
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _parseColor(color['hex_code']?.toString()),
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
      networkUrl: widget.vehiclePhotoUrl,
      onTap: widget.onPickPhoto,
      isDark: widget.isDark,
      placeholderText: 'Toca para subir foto',
    );
  }

  Widget _buildCompanySection(BuildContext context) {
    final bool hasCompany = widget.selectedCompany != null;
    final companyName = widget.companyController.text.trim();
    final companyLogoKey = hasCompany
        ? (widget.selectedCompany!['logo_url'] ?? widget.selectedCompany!['logo'])?.toString()
        : null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'Empresa de Transporte',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white70 : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'OBLIGATORIO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Info banner
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Todos los conductores deben estar vinculados a una empresa de transporte autorizada.',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                  ),
                ),
              ),
            ],
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
                color: hasCompany 
                    ? AppColors.primary 
                    : (widget.isDark ? Colors.red.withOpacity(0.5) : Colors.red.withOpacity(0.3)),
                width: hasCompany ? 2 : 1.5,
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
                    color: hasCompany 
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: hasCompany
                      ? CompanyLogo(
                          logoKey: companyLogoKey,
                          nombreEmpresa: companyName,
                          size: 28,
                          fontSize: 12,
                        )
                      : Icon(
                          Icons.business_rounded,
                          color: Colors.red,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                         widget.companyController.text.isEmpty 
                             ? 'Seleccionar Empresa' 
                             : widget.companyController.text,
                         style: TextStyle(
                           fontSize: 16,
                           fontWeight: FontWeight.bold,
                           color: hasCompany 
                               ? (widget.isDark ? Colors.white : Colors.black87)
                               : Colors.red,
                         ),
                      ),
                      if (!hasCompany)
                        Text(
                          'Toca para seleccionar',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.withOpacity(0.7),
                          ),
                        ),
                      if (hasCompany)
                        Text(
                          'Empresa seleccionada ✓',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded, 
                  size: 16, 
                  color: hasCompany 
                      ? AppColors.primary 
                      : Colors.red.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
