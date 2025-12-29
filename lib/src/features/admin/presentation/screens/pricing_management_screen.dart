import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/theme/app_colors.dart';

class PricingManagementScreen extends StatefulWidget {
  final Map<String, dynamic> adminUser;

  const PricingManagementScreen({
    super.key,
    required this.adminUser,
  });

  @override
  State<PricingManagementScreen> createState() => _PricingManagementScreenState();
}

class _PricingManagementScreenState extends State<PricingManagementScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pricingConfigs = [];
  String? _errorMessage;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final Map<String, String> _vehicleTypeNames = {
    'moto': 'Moto',
  };

  final Map<String, IconData> _vehicleTypeIcons = {
    'moto': Icons.two_wheeler_rounded,
  };

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadPricingConfigs();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadPricingConfigs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/admin/get_pricing_configs.php');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final allConfigs = List<Map<String, dynamic>>.from(data['data'] ?? []);

          // Filtrar para obtener solo la última configuración activa por tipo de vehículo
          final Map<String, Map<String, dynamic>> uniqueConfigs = {};

          for (var config in allConfigs) {
            final tipo = config['tipo_vehiculo'] as String;
            final isActive = config['activo'] == 1 || config['activo'] == '1';

            if (isActive) {
              if (!uniqueConfigs.containsKey(tipo) ||
                  (int.tryParse(config['id'].toString()) ?? 0) >
                      (int.tryParse(uniqueConfigs[tipo]!['id'].toString()) ?? 0)) {
                uniqueConfigs[tipo] = config;
              }
            }
          }

          setState(() {
            _pricingConfigs = uniqueConfigs.values.toList();
            _isLoading = false;
          });

          // Start animations
          _fadeController.forward();
          _slideController.forward();
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Error al cargar configuraciones';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error del servidor: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F7FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(isDark),
          if (_isLoading)
            SliverFillRemaining(child: _buildLoadingState())
          else if (_errorMessage != null)
            SliverFillRemaining(child: _buildErrorState())
          else
            SliverToBoxAdapter(child: _buildContent(isDark)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 170, // Increased height to prevent overflow
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primaryDark,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                right: -50,
                top: -30,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              // Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.attach_money_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Flexible(
                            child: Text(
                              'Tarifas y Precios',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: Text(
                          'Administra las tarifas de tus servicios',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            ),
            onPressed: () {
              _fadeController.reset();
              _slideController.reset();
              _loadPricingConfigs();
            },
            tooltip: 'Recargar',
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Cargando configuraciones...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, color: AppColors.error, size: 52),
            ),
            const SizedBox(height: 24),
            Text(
              'Error al cargar',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Error desconocido',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadPricingConfigs,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_pricingConfigs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                size: 80,
              ),
              const SizedBox(height: 20),
              Text(
                'No hay configuraciones',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Info card about payment method
              _buildPaymentMethodCard(isDark),
              const SizedBox(height: 20),
              // Pricing cards
              ...List.generate(_pricingConfigs.length, (index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + (index * 100)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _buildPricingCard(_pricingConfigs[index], isDark),
                        ),
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.success.withValues(alpha: 0.15),
            AppColors.success.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: AppColors.success,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Método de Pago',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Efectivo',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Activo',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(Map<String, dynamic> config, bool isDark) {
    final tipoVehiculo = config['tipo_vehiculo'] ?? '';
    final activo = config['activo'] == 1 || config['activo'] == '1';
    final icon = _vehicleTypeIcons[tipoVehiculo] ?? Icons.help_rounded;
    final nombre = _vehicleTypeNames[tipoVehiculo] ?? tipoVehiculo;

    return GestureDetector(
      onTap: () => _showEditDialog(config),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: activo
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : Colors.black.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: activo ? Colors.white : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  activo ? 'ACTIVO' : 'INACTIVO',
                                  style: TextStyle(
                                    color: activo ? Colors.white : Colors.grey[400],
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
              // Content
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Tarifas Base
                    _buildSection(
                      'Tarifas Base',
                      Icons.attach_money_rounded,
                      [
                        _buildDataRow('Tarifa Base', '\$${_formatNumber(config['tarifa_base'])}', isDark),
                        _buildDataRow('Tarifa Mínima', '\$${_formatNumber(config['tarifa_minima'])}', isDark),
                        _buildDataRow(
                          'Tarifa Máxima',
                          config['tarifa_maxima'] != null ? '\$${_formatNumber(config['tarifa_maxima'])}' : 'Sin límite',
                          isDark,
                          isSecondary: config['tarifa_maxima'] == null,
                        ),
                      ],
                      isDark,
                    ),

                    _buildDivider(isDark),

                    // Costos por Distancia y Tiempo
                    _buildSection(
                      'Distancia y Tiempo',
                      Icons.straighten_rounded,
                      [
                        _buildDataRow('Costo por Km', '\$${_formatNumber(config['costo_por_km'])}', isDark, isHighlight: true),
                        _buildDataRow('Costo por Minuto', '\$${_formatNumber(config['costo_por_minuto'])}', isDark, isHighlight: true),
                      ],
                      isDark,
                    ),

                    _buildDivider(isDark),

                    // Recargos
                    _buildSection(
                      'Recargos',
                      Icons.trending_up_rounded,
                      [
                        _buildDataRow('Hora Pico', '${config['recargo_hora_pico']}%', isDark, color: AppColors.warning),
                        _buildDataRow('Nocturno', '${config['recargo_nocturno']}%', isDark, color: const Color(0xFF5E5CE6)),
                        _buildDataRow('Festivo', '${config['recargo_festivo']}%', isDark, color: AppColors.success),
                      ],
                      isDark,
                    ),

                    _buildDivider(isDark),

                    // Descuentos
                    _buildSection(
                      'Descuentos',
                      Icons.local_offer_rounded,
                      [
                        _buildDataRow('Dist. Larga', '${config['descuento_distancia_larga']}%', isDark, color: AppColors.success),
                        _buildDataRow('Umbral', '${_formatNumber(config['umbral_km_descuento'])} km', isDark),
                      ],
                      isDark,
                    ),

                    _buildDivider(isDark),

                    // Comisiones - Ahora muestra 0%
                    _buildSection(
                      'Comisiones',
                      Icons.account_balance_wallet_rounded,
                      [
                        _buildDataRow('Plataforma', '0%', isDark, isSecondary: true),
                        _buildDataRow('Método de Pago', 'Efectivo (0%)', isDark, isSecondary: true),
                      ],
                      isDark,
                      subtitle: 'Sin cobro por el momento',
                    ),

                    _buildDivider(isDark),

                    // Límites
                    _buildSection(
                      'Límites',
                      Icons.route_rounded,
                      [
                        _buildDataRow('Dist. Mínima', '${_formatNumber(config['distancia_minima'])} km', isDark),
                        _buildDataRow('Dist. Máxima', '${_formatNumber(config['distancia_maxima'])} km', isDark),
                      ],
                      isDark,
                    ),

                    _buildDivider(isDark),

                    // Tiempo de Espera
                    _buildSection(
                      'Tiempo de Espera',
                      Icons.timer_rounded,
                      [
                        _buildDataRow('Espera Gratis', '${config['tiempo_espera_gratis']} min', isDark),
                        _buildDataRow('Costo/min Extra', '\$${_formatNumber(config['costo_tiempo_espera'])}', isDark),
                      ],
                      isDark,
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

  Widget _buildSection(String title, IconData icon, List<Widget> rows, bool isDark, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...rows,
      ],
    );
  }

  Widget _buildDataRow(String label, String value, bool isDark,
      {Color? color, bool isHighlight = false, bool isSecondary = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 44),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          Container(
            padding: isHighlight
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
                : EdgeInsets.zero,
            decoration: isHighlight
                ? BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Text(
              value,
              style: TextStyle(
                color: isSecondary
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                    : color ?? (isHighlight ? AppColors.primary : Theme.of(context).colorScheme.onSurface),
                fontSize: isHighlight ? 16 : 15,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final number = double.tryParse(value.toString()) ?? 0.0;
    return number.toStringAsFixed(0);
  }

  Future<void> _showEditDialog(Map<String, dynamic> config) async {
    final controllers = {
      'tarifa_base': TextEditingController(text: config['tarifa_base']?.toString() ?? '0'),
      'tarifa_minima': TextEditingController(text: config['tarifa_minima']?.toString() ?? '0'),
      'tarifa_maxima': TextEditingController(text: config['tarifa_maxima']?.toString() ?? ''),
      'costo_por_km': TextEditingController(text: config['costo_por_km']?.toString() ?? '0'),
      'costo_por_minuto': TextEditingController(text: config['costo_por_minuto']?.toString() ?? '0'),
      'recargo_hora_pico': TextEditingController(text: config['recargo_hora_pico']?.toString() ?? '0'),
      'recargo_nocturno': TextEditingController(text: config['recargo_nocturno']?.toString() ?? '0'),
      'recargo_festivo': TextEditingController(text: config['recargo_festivo']?.toString() ?? '0'),
      'descuento_distancia_larga': TextEditingController(text: config['descuento_distancia_larga']?.toString() ?? '0'),
      'umbral_km_descuento': TextEditingController(text: config['umbral_km_descuento']?.toString() ?? '0'),
      'hora_pico_inicio_manana': TextEditingController(text: config['hora_pico_inicio_manana']?.toString() ?? '07:00'),
      'hora_pico_fin_manana': TextEditingController(text: config['hora_pico_fin_manana']?.toString() ?? '09:00'),
      'hora_pico_inicio_tarde': TextEditingController(text: config['hora_pico_inicio_tarde']?.toString() ?? '17:00'),
      'hora_pico_fin_tarde': TextEditingController(text: config['hora_pico_fin_tarde']?.toString() ?? '19:00'),
      'hora_nocturna_inicio': TextEditingController(text: config['hora_nocturna_inicio']?.toString() ?? '22:00'),
      'hora_nocturna_fin': TextEditingController(text: config['hora_nocturna_fin']?.toString() ?? '06:00'),
      'distancia_minima': TextEditingController(text: config['distancia_minima']?.toString() ?? '0'),
      'distancia_maxima': TextEditingController(text: config['distancia_maxima']?.toString() ?? '0'),
      'tiempo_espera_gratis': TextEditingController(text: config['tiempo_espera_gratis']?.toString() ?? '0'),
      'costo_tiempo_espera': TextEditingController(text: config['costo_tiempo_espera']?.toString() ?? '0'),
      'notas': TextEditingController(text: config['notas']?.toString() ?? ''),
    };

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditPricingSheet(
        config: config,
        controllers: controllers,
        vehicleTypeName: _vehicleTypeNames[config['tipo_vehiculo']] ?? '',
      ),
    );

    await Future.delayed(const Duration(milliseconds: 100));
    for (var controller in controllers.values) {
      controller.dispose();
    }

    if (result == true) {
      _fadeController.reset();
      _slideController.reset();
      _loadPricingConfigs();
    }
  }
}

class _EditPricingSheet extends StatefulWidget {
  final Map<String, dynamic> config;
  final Map<String, TextEditingController> controllers;
  final String vehicleTypeName;

  const _EditPricingSheet({
    required this.config,
    required this.controllers,
    required this.vehicleTypeName,
  });

  @override
  State<_EditPricingSheet> createState() => _EditPricingSheetState();
}

class _EditPricingSheetState extends State<_EditPricingSheet> {
  bool _isSaving = false;
  int _currentSection = 0;

  final List<Map<String, dynamic>> _sections = [
    {'title': 'Tarifas Base', 'icon': Icons.attach_money_rounded},
    {'title': 'Distancia y Tiempo', 'icon': Icons.straighten_rounded},
    {'title': 'Recargos', 'icon': Icons.trending_up_rounded},
    {'title': 'Descuentos', 'icon': Icons.local_offer_rounded},
    {'title': 'Límites', 'icon': Icons.route_rounded},
    {'title': 'Tiempo de Espera', 'icon': Icons.timer_rounded},
  ];

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      final Map<String, dynamic> updateData = {
        'id': widget.config['id'],
      };

      void addField(String key, String controllerKey, {bool isDouble = true, bool isInt = false, bool required = true}) {
        final text = widget.controllers[controllerKey]!.text.trim();
        if (text.isEmpty) {
          if (required) {
            throw FormatException('El campo $key es obligatorio');
          }
          return;
        }
        if (isDouble) {
          updateData[key] = double.parse(text);
        } else if (isInt) {
          updateData[key] = int.parse(text);
        } else {
          updateData[key] = text;
        }
      }

      // Tarifas Base
      addField('tarifa_base', 'tarifa_base');
      addField('tarifa_minima', 'tarifa_minima');
      addField('tarifa_maxima', 'tarifa_maxima', required: false);

      // Costos
      addField('costo_por_km', 'costo_por_km');
      addField('costo_por_minuto', 'costo_por_minuto');

      // Recargos
      addField('recargo_hora_pico', 'recargo_hora_pico');
      addField('recargo_nocturno', 'recargo_nocturno');
      addField('recargo_festivo', 'recargo_festivo');

      // Descuentos
      addField('descuento_distancia_larga', 'descuento_distancia_larga');
      addField('umbral_km_descuento', 'umbral_km_descuento');

      // Horarios
      addField('hora_pico_inicio_manana', 'hora_pico_inicio_manana', isDouble: false);
      addField('hora_pico_fin_manana', 'hora_pico_fin_manana', isDouble: false);
      addField('hora_pico_inicio_tarde', 'hora_pico_inicio_tarde', isDouble: false);
      addField('hora_pico_fin_tarde', 'hora_pico_fin_tarde', isDouble: false);
      addField('hora_nocturna_inicio', 'hora_nocturna_inicio', isDouble: false);
      addField('hora_nocturna_fin', 'hora_nocturna_fin', isDouble: false);

      // Comisiones siempre en 0
      updateData['comision_plataforma'] = 0;
      updateData['comision_metodo_pago'] = 0;

      // Límites
      addField('distancia_minima', 'distancia_minima');
      addField('distancia_maxima', 'distancia_maxima');

      // Tiempo de Espera
      addField('tiempo_espera_gratis', 'tiempo_espera_gratis', isDouble: false, isInt: true);
      addField('costo_tiempo_espera', 'costo_tiempo_espera');

      // Notas
      final notas = widget.controllers['notas']!.text.trim();
      if (notas.isNotEmpty) {
        updateData['notas'] = notas;
      }

      final url = Uri.parse('${AppConfig.baseUrl}/admin/update_pricing_config.php');
      final client = http.Client();
      try {
        final response = await client.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(updateData),
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text('Configuración actualizada'),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ),
            );
            Navigator.pop(context, true);
          } else {
            _showError(data['message'] ?? 'Error al actualizar');
          }
        } else {
          _showError('Error del servidor: ${response.statusCode}');
        }
      } on TimeoutException {
        _showError('Tiempo de espera agotado');
      } catch (e) {
        _showError('Error: $e');
      } finally {
        client.close();
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Editar Tarifas',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.vehicleTypeName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Section tabs
          SizedBox(
            height: 50,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _sections[index]['icon'] as IconData,
                          size: 18,
                          color: isSelected ? Colors.white : Colors.grey,
                        ),
                        const SizedBox(width: 8),
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
          // Form content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomPadding),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildCurrentSection(),
              ),
            ),
          ),
          // Buttons
          Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Guardar Cambios',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
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

  Widget _buildCurrentSection() {
    switch (_currentSection) {
      case 0:
        return _buildTarifasSection();
      case 1:
        return _buildDistanciaSection();
      case 2:
        return _buildRecargosSection();
      case 3:
        return _buildDescuentosSection();
      case 4:
        return _buildLimitesSection();
      case 5:
        return _buildEsperaSection();
      default:
        return _buildTarifasSection();
    }
  }

  Widget _buildTarifasSection() {
    return Column(
      key: const ValueKey('tarifas'),
      children: [
        _buildTextField('Tarifa Base (\$)', widget.controllers['tarifa_base']!),
        _buildTextField('Tarifa Mínima (\$)', widget.controllers['tarifa_minima']!),
        _buildTextField('Tarifa Máxima (\$) - Opcional', widget.controllers['tarifa_maxima']!, optional: true),
      ],
    );
  }

  Widget _buildDistanciaSection() {
    return Column(
      key: const ValueKey('distancia'),
      children: [
        _buildTextField('Costo por Km (\$)', widget.controllers['costo_por_km']!),
        _buildTextField('Costo por Minuto (\$)', widget.controllers['costo_por_minuto']!),
      ],
    );
  }

  Widget _buildRecargosSection() {
    return Column(
      key: const ValueKey('recargos'),
      children: [
        _buildTextField('Recargo Hora Pico (%)', widget.controllers['recargo_hora_pico']!),
        _buildTextField('Recargo Nocturno (%)', widget.controllers['recargo_nocturno']!),
        _buildTextField('Recargo Festivo (%)', widget.controllers['recargo_festivo']!),
      ],
    );
  }

  Widget _buildDescuentosSection() {
    return Column(
      key: const ValueKey('descuentos'),
      children: [
        _buildTextField('Descuento Distancia Larga (%)', widget.controllers['descuento_distancia_larga']!),
        _buildTextField('Umbral para Descuento (km)', widget.controllers['umbral_km_descuento']!),
      ],
    );
  }

  Widget _buildLimitesSection() {
    return Column(
      key: const ValueKey('limites'),
      children: [
        _buildTextField('Distancia Mínima (km)', widget.controllers['distancia_minima']!),
        _buildTextField('Distancia Máxima (km)', widget.controllers['distancia_maxima']!),
      ],
    );
  }

  Widget _buildEsperaSection() {
    return Column(
      key: const ValueKey('espera'),
      children: [
        _buildTextField('Tiempo Espera Gratis (min)', widget.controllers['tiempo_espera_gratis']!),
        _buildTextField('Costo por Minuto Espera (\$)', widget.controllers['costo_tiempo_espera']!),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(optional ? r'^(\d+\.?\d{0,2})?' : r'^\d+\.?\d{0,2}')),
        ],
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}
