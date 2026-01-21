import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
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
  bool _isSaving = false;
  int _currentSection = 0;

  final List<Map<String, dynamic>> _sections = [
    {'title': 'Tarifas', 'icon': Icons.attach_money_rounded},
    {'title': 'Distancia', 'icon': Icons.straighten_rounded},
    {'title': 'Recargos', 'icon': Icons.trending_up_rounded},
    {'title': 'Descuentos', 'icon': Icons.local_offer_rounded},
    {'title': 'Comisión', 'icon': Icons.percent_rounded},
    {'title': 'Espera', 'icon': Icons.timer_rounded},
  ];

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    
    bool shouldResetState = true;

    try {
      final body = {
        'empresa_id': widget.empresaId,
        'tipo_vehiculo': widget.config['tipo_vehiculo'],
        'tarifa_base':
            double.tryParse(widget.controllers['tarifa_base']!.text) ?? 0,
        'tarifa_minima':
            double.tryParse(widget.controllers['tarifa_minima']!.text) ?? 0,
        'tarifa_maxima': widget.controllers['tarifa_maxima']!.text.isEmpty
            ? null
            : double.tryParse(widget.controllers['tarifa_maxima']!.text),
        'costo_por_km':
            double.tryParse(widget.controllers['costo_por_km']!.text) ?? 0,
        'costo_por_minuto':
            double.tryParse(widget.controllers['costo_por_minuto']!.text) ?? 0,
        'recargo_hora_pico':
            double.tryParse(widget.controllers['recargo_hora_pico']!.text) ?? 0,
        'recargo_nocturno':
            double.tryParse(widget.controllers['recargo_nocturno']!.text) ?? 0,
        'recargo_festivo':
            double.tryParse(widget.controllers['recargo_festivo']!.text) ?? 0,
        'descuento_distancia_larga':
            double.tryParse(
              widget.controllers['descuento_distancia_larga']!.text,
            ) ??
            0,
        'umbral_km_descuento':
            double.tryParse(widget.controllers['umbral_km_descuento']!.text) ??
            15,
        'comision_plataforma':
            double.tryParse(widget.controllers['comision_plataforma']!.text) ??
            0,
        'comision_metodo_pago': 0,
        'distancia_minima':
            double.tryParse(widget.controllers['distancia_minima']!.text) ?? 1,
        'distancia_maxima':
            double.tryParse(widget.controllers['distancia_maxima']!.text) ?? 50,
        'tiempo_espera_gratis':
            int.tryParse(widget.controllers['tiempo_espera_gratis']!.text) ?? 3,
        'costo_tiempo_espera':
            double.tryParse(widget.controllers['costo_tiempo_espera']!.text) ??
            0,
        'activo': 1,
      };

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

  static final _numberRegex = RegExp(r'^\d+\.?\d{0,2}');
  static final _optionalNumberRegex = RegExp(r'^(\d+\.?\d{0,2})?');

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
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomPadding),
                children: [_buildCurrentSection()],
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
            _buildField('Tarifa Base (\$)', widget.controllers['tarifa_base']!),
            _buildField(
              'Tarifa Mínima (\$)',
              widget.controllers['tarifa_minima']!,
            ),
            _buildField(
              'Tarifa Máxima (\$) - Opcional',
              widget.controllers['tarifa_maxima']!,
              optional: true,
            ),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey('distancia'),
          children: [
            _buildField(
              'Costo por Km (\$)',
              widget.controllers['costo_por_km']!,
            ),
            _buildField(
              'Costo por Minuto (\$)',
              widget.controllers['costo_por_minuto']!,
            ),
            _buildField(
              'Distancia Mínima (km)',
              widget.controllers['distancia_minima']!,
            ),
            _buildField(
              'Distancia Máxima (km)',
              widget.controllers['distancia_maxima']!,
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
            ),
            _buildField(
              'Recargo Nocturno (%)',
              widget.controllers['recargo_nocturno']!,
            ),
            _buildField(
              'Recargo Festivo (%)',
              widget.controllers['recargo_festivo']!,
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
            ),
            _buildField(
              'Umbral Descuento (km)',
              widget.controllers['umbral_km_descuento']!,
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
            ),
            _buildField(
              'Costo/Min Extra (\$)',
              widget.controllers['costo_tiempo_espera']!,
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
    bool optional = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                optional ? _optionalNumberRegex : _numberRegex,
              ),
            ],
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
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
}
