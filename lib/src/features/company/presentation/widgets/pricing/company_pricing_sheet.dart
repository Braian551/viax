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
    setState(() => _isSaving = true);
    try {
      final body = {
        'empresa_id': widget.empresaId,
        'tipo_vehiculo': widget.config['tipo_vehiculo'],
        'tarifa_base': double.tryParse(widget.controllers['tarifa_base']!.text) ?? 0,
        'tarifa_minima': double.tryParse(widget.controllers['tarifa_minima']!.text) ?? 0,
        'tarifa_maxima': widget.controllers['tarifa_maxima']!.text.isEmpty ? null : double.tryParse(widget.controllers['tarifa_maxima']!.text),
        'costo_por_km': double.tryParse(widget.controllers['costo_por_km']!.text) ?? 0,
        'costo_por_minuto': double.tryParse(widget.controllers['costo_por_minuto']!.text) ?? 0,
        'recargo_hora_pico': double.tryParse(widget.controllers['recargo_hora_pico']!.text) ?? 0,
        'recargo_nocturno': double.tryParse(widget.controllers['recargo_nocturno']!.text) ?? 0,
        'recargo_festivo': double.tryParse(widget.controllers['recargo_festivo']!.text) ?? 0,
        'descuento_distancia_larga': double.tryParse(widget.controllers['descuento_distancia_larga']!.text) ?? 0,
        'umbral_km_descuento': double.tryParse(widget.controllers['umbral_km_descuento']!.text) ?? 15,
        'comision_plataforma': double.tryParse(widget.controllers['comision_plataforma']!.text) ?? 0,
        'comision_metodo_pago': 0,
        'distancia_minima': double.tryParse(widget.controllers['distancia_minima']!.text) ?? 1,
        'distancia_maxima': double.tryParse(widget.controllers['distancia_maxima']!.text) ?? 50,
        'tiempo_espera_gratis': int.tryParse(widget.controllers['tiempo_espera_gratis']!.text) ?? 3,
        'costo_tiempo_espera': double.tryParse(widget.controllers['costo_tiempo_espera']!.text) ?? 0,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context, true);
        } else {
          _showError(data['message']);
        }
      } else {
        _showError('Error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Editar Tarifas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(widget.vehicleTypeName, style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // Section Tabs
          SizedBox(
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _sections.length,
              itemBuilder: (context, index) {
                final isSelected = _currentSection == index;
                return GestureDetector(
                  onTap: () => setState(() => _currentSection = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_sections[index]['icon'] as IconData, size: 16, color: isSelected ? Colors.white : Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          _sections[index]['title'] as String,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
          const SizedBox(height: 8),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildCurrentSection(),
              ),
            ),
          ),
          // Buttons
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSection() {
    switch (_currentSection) {
      case 0:
        return Column(key: const ValueKey('tarifas'), children: [
          _buildField('Tarifa Base (\$)', widget.controllers['tarifa_base']!),
          _buildField('Tarifa Mínima (\$)', widget.controllers['tarifa_minima']!),
          _buildField('Tarifa Máxima (\$) - Opcional', widget.controllers['tarifa_maxima']!, optional: true),
        ]);
      case 1:
        return Column(key: const ValueKey('distancia'), children: [
          _buildField('Costo por Km (\$)', widget.controllers['costo_por_km']!),
          _buildField('Costo por Minuto (\$)', widget.controllers['costo_por_minuto']!),
          _buildField('Dist. Mínima (km)', widget.controllers['distancia_minima']!),
          _buildField('Dist. Máxima (km)', widget.controllers['distancia_maxima']!),
        ]);
      case 2:
        return Column(key: const ValueKey('recargos'), children: [
          _buildField('Recargo Hora Pico (%)', widget.controllers['recargo_hora_pico']!),
          _buildField('Recargo Nocturno (%)', widget.controllers['recargo_nocturno']!),
          _buildField('Recargo Festivo (%)', widget.controllers['recargo_festivo']!),
        ]);
      case 3:
        return Column(key: const ValueKey('descuentos'), children: [
          _buildField('Desc. Dist. Larga (%)', widget.controllers['descuento_distancia_larga']!),
          _buildField('Umbral Desc. (km)', widget.controllers['umbral_km_descuento']!),
        ]);
      case 4:
        return Column(key: const ValueKey('comision'), children: [
          _buildField('Tu Comisión a Conductores (%)', widget.controllers['comision_plataforma']!),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Esta es la comisión que cobras a tus conductores por cada viaje.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ]);
      case 5:
        return Column(key: const ValueKey('espera'), children: [
          _buildField('Espera Gratis (min)', widget.controllers['tiempo_espera_gratis']!),
          _buildField('Costo/Min Extra (\$)', widget.controllers['costo_tiempo_espera']!),
        ]);
      default:
        return const SizedBox();
    }
  }

  Widget _buildField(String label, TextEditingController controller, {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(optional ? r'^(\d+\.?\d{0,2})?' : r'^\d+\.?\d{0,2}'))],
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        ),
      ),
    );
  }
}
