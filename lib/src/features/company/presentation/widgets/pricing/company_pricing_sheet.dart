import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/features/user/presentation/widgets/trip_preview/trip_price_formatter.dart';
import 'package:viax/src/theme/app_colors.dart';

class CompanyPricingSheet extends StatefulWidget {
  final Map<String, dynamic> config;
  final Map<String, TextEditingController> controllers;
  final String vehicleTypeName;
  final dynamic empresaId;

  const CompanyPricingSheet({
    super.key,
    required this.config,
    required this.controllers,
    required this.vehicleTypeName,
    required this.empresaId,
  });

  @override
  State<CompanyPricingSheet> createState() => _CompanyPricingSheetState();
}

class _CompanyPricingSheetState extends State<CompanyPricingSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  int _currentSection = 0;
  bool _isFormattingCop = false;

  final List<Map<String, dynamic>> _sections = [
    {'title': 'Tarifas', 'icon': Icons.attach_money_rounded},
    {'title': 'Distancia', 'icon': Icons.straighten_rounded},
    {'title': 'Recargos', 'icon': Icons.trending_up_rounded},
    {'title': 'Descuentos', 'icon': Icons.local_offer_rounded},
    {'title': 'Comisión', 'icon': Icons.percent_rounded},
    {'title': 'Espera', 'icon': Icons.timer_rounded},
  ];

  static final _decimalRegex = RegExp(r'^\d+\.?\d{0,2}');
  static final _optionalDecimalRegex = RegExp(r'^(\d+\.?\d{0,2})?');
  static final _percentDecimalRegex = RegExp(r'^\d{0,3}(\.\d{0,2})?');

  static const Set<String> _copKeys = {
    'tarifa_base',
    'tarifa_minima',
    'tarifa_maxima',
    'costo_por_km',
    'costo_por_minuto',
    'costo_tiempo_espera',
  };

  @override
  void initState() {
    super.initState();
    _normalizeInitialValues();
    _bindCopFormatters();
  }

  @override
  void dispose() {
    for (final key in _copKeys) {
      final controller = widget.controllers[key];
      if (controller != null) {
        controller.removeListener(() => _formatCopValue(controller));
      }
    }
    super.dispose();
  }

  void _normalizeInitialValues() {
    for (final key in _copKeys) {
      final controller = widget.controllers[key];
      if (controller == null) continue;

      final value = _parseCop(controller.text);
      if (value <= 0 && key == 'tarifa_maxima') {
        controller.text = '';
      } else if (value > 0) {
        controller.text = formatCurrency(value, withSymbol: false);
      }
    }
  }

  void _bindCopFormatters() {
    for (final key in _copKeys) {
      final controller = widget.controllers[key];
      if (controller == null) continue;
      controller.addListener(() => _formatCopValue(controller));
    }
  }

  void _formatCopValue(TextEditingController controller) {
    if (_isFormattingCop) return;

    final rawDigits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (rawDigits.isEmpty) {
      return;
    }

    final value = double.tryParse(rawDigits) ?? 0;
    final formatted = formatCurrency(value, withSymbol: false);

    if (controller.text == formatted) return;

    _isFormattingCop = true;
    controller.value = controller.value.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
    _isFormattingCop = false;
  }

  double _parseCop(String text) {
    final raw = text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(raw) ?? 0;
  }

  double _parseDecimal(String text) {
    final normalized = text.replaceAll(',', '.').trim();
    return double.tryParse(normalized) ?? 0;
  }

  double _valueOf(String key) {
    final text = widget.controllers[key]?.text ?? '';
    if (_copKeys.contains(key)) {
      return _parseCop(text);
    }
    return _parseDecimal(text);
  }

  List<String> _validateBusinessRules() {
    final errors = <String>[];

    final tarifaBase = _valueOf('tarifa_base');
    final tarifaMinima = _valueOf('tarifa_minima');
    final tarifaMaximaText = widget.controllers['tarifa_maxima']?.text.trim() ?? '';
    final tarifaMaxima = tarifaMaximaText.isEmpty ? 0 : _valueOf('tarifa_maxima');
    final costoKm = _valueOf('costo_por_km');
    final costoMin = _valueOf('costo_por_minuto');

    final hp = _valueOf('recargo_hora_pico');
    final noct = _valueOf('recargo_nocturno');
    final fest = _valueOf('recargo_festivo');
    final desc = _valueOf('descuento_distancia_larga');
    final comision = _valueOf('comision_plataforma');

    final distMin = _valueOf('distancia_minima');
    final distMax = _valueOf('distancia_maxima');
    final umbral = _valueOf('umbral_km_descuento');
    final esperaGratis = _valueOf('tiempo_espera_gratis');
    final esperaCosto = _valueOf('costo_tiempo_espera');

    if (tarifaBase <= 0) errors.add('La tarifa base debe ser mayor a 0.');
    if (tarifaMinima < tarifaBase) {
      errors.add('La tarifa mínima no puede ser menor que la tarifa base.');
    }
    if (tarifaMaximaText.isNotEmpty && tarifaMaxima > 0 && tarifaMaxima < tarifaMinima) {
      errors.add('La tarifa máxima no puede ser menor que la tarifa mínima.');
    }
    if (costoKm <= 0) errors.add('El costo por km debe ser mayor a 0.');
    if (costoMin <= 0) errors.add('El costo por minuto debe ser mayor a 0.');

    if (distMin <= 0) errors.add('La distancia mínima debe ser mayor a 0 km.');
    if (distMax < distMin) errors.add('La distancia máxima no puede ser menor que la mínima.');
    if (distMax > 1000) errors.add('La distancia máxima no debe superar 1000 km.');

    if (umbral < distMin) {
      errors.add('El umbral de descuento no puede ser menor que la distancia mínima.');
    }

    if (hp < 0 || hp > 100) errors.add('El recargo de hora pico debe estar entre 0% y 100%.');
    if (noct < 0 || noct > 100) errors.add('El recargo nocturno debe estar entre 0% y 100%.');
    if (fest < 0 || fest > 100) errors.add('El recargo festivo debe estar entre 0% y 100%.');
    if (desc < 0 || desc > 80) errors.add('El descuento por distancia larga debe estar entre 0% y 80%.');
    if (comision < 0 || comision > 100) errors.add('La comisión debe estar entre 0% y 100%.');

    if (esperaGratis < 0 || esperaGratis > 180) {
      errors.add('El tiempo de espera gratis debe estar entre 0 y 180 minutos.');
    }
    if (esperaCosto < 0) errors.add('El costo por tiempo de espera no puede ser negativo.');

    return errors;
  }

  Map<String, dynamic> _buildPayload() {
    final tarifaMaximaText = widget.controllers['tarifa_maxima']?.text.trim() ?? '';

    return {
      'empresa_id': widget.empresaId,
      'tipo_vehiculo': widget.config['tipo_vehiculo'],
      'tarifa_base': _valueOf('tarifa_base'),
      'tarifa_minima': _valueOf('tarifa_minima'),
      'tarifa_maxima': tarifaMaximaText.isEmpty ? null : _valueOf('tarifa_maxima'),
      'costo_por_km': _valueOf('costo_por_km'),
      'costo_por_minuto': _valueOf('costo_por_minuto'),
      'recargo_hora_pico': _valueOf('recargo_hora_pico'),
      'recargo_nocturno': _valueOf('recargo_nocturno'),
      'recargo_festivo': _valueOf('recargo_festivo'),
      'descuento_distancia_larga': _valueOf('descuento_distancia_larga'),
      'umbral_km_descuento': _valueOf('umbral_km_descuento'),
      'comision_plataforma': _valueOf('comision_plataforma'),
      'comision_metodo_pago': 0,
      'distancia_minima': _valueOf('distancia_minima'),
      'distancia_maxima': _valueOf('distancia_maxima'),
      'tiempo_espera_gratis': _valueOf('tiempo_espera_gratis').toInt(),
      'costo_tiempo_espera': _valueOf('costo_tiempo_espera'),
      'activo': 1,
    };
  }

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showError('Revisa los campos marcados antes de guardar.');
      return;
    }

    final businessErrors = _validateBusinessRules();
    if (businessErrors.isNotEmpty) {
      _showError(businessErrors.first);
      return;
    }

    setState(() => _isSaving = true);
    
    bool shouldResetState = true;

    try {
      final body = _buildPayload();

      final url = Uri.parse('${AppConfig.baseUrl}/company/pricing.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          shouldResetState = false; // Don't reset state if we are closing
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text('Tarifas actualizadas'),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            Navigator.pop(context, true);
          }
        } else {
          _showError(data['message']);
        }
      } else {
        _showError('Error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted && shouldResetState) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle - Draggable area
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (_) {},
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editar Tarifas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          widget.vehicleTypeName,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white60
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: isDark
                          ? Colors.white60
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar - Simple and clean
            SizedBox(
              height: 42,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _sections.length,
                itemBuilder: (context, index) {
                  final isSelected = _currentSection == index;
                  return GestureDetector(
                    onTap: () => setState(() => _currentSection = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.grey.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _sections[index]['icon'] as IconData,
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                      ? Colors.white60
                                      : AppColors.lightTextSecondary),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _sections[index]['title'] as String,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                        ? Colors.white60
                                        : AppColors.lightTextSecondary),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Form - Uses the scroll controller from DraggableScrollableSheet
            Expanded(
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomPadding),
                  children: [
                    _buildLiveSummaryCard(isDark),
                    const SizedBox(height: 14),
                    _buildCurrentSection(),
                  ],
                ),
              ),
            ),

            // Buttons
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppColors.darkDivider
                        : AppColors.lightDivider,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: isDark
                            ? Colors.white60
                            : AppColors.lightTextSecondary,
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Guardar',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSection() {
    switch (_currentSection) {
      case 0:
        return Column(
          key: const ValueKey('tarifas'),
          children: [
            _buildField('Tarifa base', widget.controllers['tarifa_base']!, fieldKey: 'tarifa_base', unit: 'COP'),
            _buildField(
              'Tarifa mínima',
              widget.controllers['tarifa_minima']!,
              fieldKey: 'tarifa_minima',
              unit: 'COP',
            ),
            _buildField(
              'Tarifa máxima (opcional)',
              widget.controllers['tarifa_maxima']!,
              fieldKey: 'tarifa_maxima',
              unit: 'COP',
              optional: true,
            ),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey('distancia'),
          children: [
            _buildField(
              'Costo por km',
              widget.controllers['costo_por_km']!,
              fieldKey: 'costo_por_km',
              unit: 'COP',
            ),
            _buildField(
              'Costo por minuto',
              widget.controllers['costo_por_minuto']!,
              fieldKey: 'costo_por_minuto',
              unit: 'COP',
            ),
            _buildField(
              'Distancia Mínima (km)',
              widget.controllers['distancia_minima']!,
              fieldKey: 'distancia_minima',
              unit: 'km',
            ),
            _buildField(
              'Distancia Máxima (km)',
              widget.controllers['distancia_maxima']!,
              fieldKey: 'distancia_maxima',
              unit: 'km',
            ),
          ],
        );
      case 2:
        return Column(
          key: const ValueKey('recargos'),
          children: [
            _buildField(
              'Recargo Hora Pico (%)',
              widget.controllers['recargo_hora_pico']!,
              fieldKey: 'recargo_hora_pico',
              unit: '%',
            ),
            _buildField(
              'Recargo Nocturno (%)',
              widget.controllers['recargo_nocturno']!,
              fieldKey: 'recargo_nocturno',
              unit: '%',
            ),
            _buildField(
              'Recargo Festivo (%)',
              widget.controllers['recargo_festivo']!,
              fieldKey: 'recargo_festivo',
              unit: '%',
            ),
          ],
        );
      case 3:
        return Column(
          key: const ValueKey('descuentos'),
          children: [
            _buildField(
              'Descuento Distancia Larga (%)',
              widget.controllers['descuento_distancia_larga']!,
              fieldKey: 'descuento_distancia_larga',
              unit: '%',
            ),
            _buildField(
              'Umbral Descuento (km)',
              widget.controllers['umbral_km_descuento']!,
              fieldKey: 'umbral_km_descuento',
              unit: 'km',
            ),
          ],
        );
      case 4:
        return Column(
          key: const ValueKey('comision'),
          children: [
            _buildField(
              'Comisión a Conductores (%)',
              widget.controllers['comision_plataforma']!,
              fieldKey: 'comision_plataforma',
              unit: '%',
            ),
            AnimatedBuilder(
              animation: widget.controllers['comision_plataforma']!,
              builder: (context, _) {
                double value = double.tryParse(
                      widget.controllers['comision_plataforma']!.text,
                    ) ??
                    0.0;
                // Securely clamp the value between 0 and 100
                if (value < 0) value = 0;
                if (value > 100) value = 100;

                return Slider(
                  value: value,
                  min: 0,
                  max: 100,
                  divisions: 200, // 0.5 steps
                  label: value.toStringAsFixed(1),
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.primary.withValues(alpha: 0.2),
                  onChanged: (newValue) {
                    widget.controllers['comision_plataforma']!.text =
                        newValue.toStringAsFixed(1);
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Esta es la comisión que cobras a tus conductores.',
                      style: TextStyle(fontSize: 13, color: AppColors.blue800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case 5:
        return Column(
          key: const ValueKey('espera'),
          children: [
            _buildField(
              'Tiempo Espera Gratis (min)',
              widget.controllers['tiempo_espera_gratis']!,
              fieldKey: 'tiempo_espera_gratis',
              unit: 'min',
            ),
            _buildField(
              'Costo/Min Extra',
              widget.controllers['costo_tiempo_espera']!,
              fieldKey: 'costo_tiempo_espera',
              unit: 'COP',
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    required String fieldKey,
    required String unit,
    bool optional = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCop = _copKeys.contains(fieldKey);
    final isPercent = unit == '%';
    final isInteger = unit == 'min';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: !isCop && !isInteger),
            inputFormatters: [
              if (isCop || isInteger) FilteringTextInputFormatter.digitsOnly,
              if (!isCop && !isInteger)
                FilteringTextInputFormatter.allow(
                  isPercent ? _percentDecimalRegex : (optional ? _optionalDecimalRegex : _decimalRegex),
                ),
            ],
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
            validator: (value) {
              final raw = (value ?? '').trim();
              if (!optional && raw.isEmpty) {
                return 'Campo obligatorio';
              }
              if (optional && raw.isEmpty) return null;

              final parsed = _valueOf(fieldKey);
              if (isCop && parsed <= 0) {
                return 'Debe ser mayor a 0';
              }
              if (isInteger && parsed < 0) {
                return 'No puede ser negativo';
              }
              if (isPercent && (parsed < 0 || parsed > 100)) {
                return 'Rango permitido: 0 - 100';
              }
              return null;
            },
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixText: unit,
              suffixStyle: TextStyle(
                color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSummaryCard(bool isDark) {
    final tarifaBase = _valueOf('tarifa_base');
    final tarifaMin = _valueOf('tarifa_minima');
    final costoKm = _valueOf('costo_por_km');
    final costoMin = _valueOf('costo_por_minuto');
    final requiereConfig = widget.config['requiere_configuracion'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.blue50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : AppColors.blue100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Resumen de configuración',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.blue900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip('Base ${formatCurrency(tarifaBase)}', isDark),
              _summaryChip('Mínima ${formatCurrency(tarifaMin)}', isDark),
              _summaryChip('Km ${formatCurrency(costoKm)}', isDark),
              _summaryChip('Min ${formatCurrency(costoMin)}', isDark),
            ],
          ),
          if (requiereConfig) ...[
            const SizedBox(height: 10),
            Text(
              'Este vehículo está usando tarifa heredada. Guarda para dejar su configuración propia.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.orange[200] : Colors.orange[800],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? Colors.white12 : AppColors.blue100,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
        ),
      ),
    );
  }
}
