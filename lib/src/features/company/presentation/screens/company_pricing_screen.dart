import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/theme/app_colors.dart';
import '../widgets/pricing/company_pricing_card.dart';
import '../widgets/pricing/company_pricing_sheet.dart';

class CompanyPricingTab extends StatefulWidget {
  final Map<String, dynamic> user;

  const CompanyPricingTab({super.key, required this.user});

  @override
  State<CompanyPricingTab> createState() => _CompanyPricingTabState();
}

class _CompanyPricingTabState extends State<CompanyPricingTab>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pricingConfigs = [];
  Map<String, dynamic>? _empresaInfo;
  String? _errorMessage;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Note: vehicle names/icons are also in CompanyPricingCard, 
  // but we keep names here for passing to EditSheet if needed (or use static from Card if public)
  // Actually CompanyPricingCard handles presentation. EditSheet needs name string.
  final Map<String, String> _vehicleTypeNames = {
    'moto': 'Moto',
    'auto': 'Auto',
    'motocarro': 'Motocarro',
  };

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadPricing();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadPricing() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final empresaId = widget.user['empresa_id'] ?? widget.user['id'];
      final url = Uri.parse('${AppConfig.baseUrl}/company/pricing.php?empresa_id=$empresaId');
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _pricingConfigs = List<Map<String, dynamic>>.from(data['data']['precios'] ?? []);
            _empresaInfo = data['data']['empresa'];
            _isLoading = false;
          });
          _fadeController.forward();
        } else {
          setState(() {
            _errorMessage = data['message'];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) return _buildShimmerLoading();
    if (_errorMessage != null) return _buildErrorState();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _loadPricing,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: [
            // Admin Commission Info Card
            if (_empresaInfo != null) _buildAdminCommissionCard(isDark),
            const SizedBox(height: 20),

            // Balance Card
            if (_empresaInfo != null) _buildBalanceCard(isDark),
            const SizedBox(height: 24),

            // Section Header
            Row(
              children: [
                Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Tus Tarifas',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pricing Cards
            if (_pricingConfigs.isEmpty)
              _buildEmptyState()
            else
              ...List.generate(_pricingConfigs.length, (index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + (index * 100)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: CompanyPricingCard(
                            config: _pricingConfigs[index],
                            onTap: () => _showEditSheet(_pricingConfigs[index]),
                          ),
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
    );
  }

  Widget _buildShimmerLoading() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Shimmer for Admin Card
        Shimmer.fromColors(
          baseColor: Colors.grey.withValues(alpha: 0.1),
          highlightColor: Colors.grey.withValues(alpha: 0.05),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Shimmer for Balance Card
        Shimmer.fromColors(
          baseColor: Colors.grey.withValues(alpha: 0.1),
          highlightColor: Colors.grey.withValues(alpha: 0.05),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const SizedBox(height: 30),
        // Shimmer for Pricing Cards
         ...List.generate(3, (index) => Padding(
           padding: const EdgeInsets.only(bottom: 16),
           child: Shimmer.fromColors(
             baseColor: Colors.grey.withValues(alpha: 0.1),
             highlightColor: Colors.grey.withValues(alpha: 0.05),
             child: Container(
               height: 180,
               decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(20),
               ),
             ),
           ),
         )),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: AppColors.error),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'Error desconocido'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadPricing,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay tarifas configuradas',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCommissionCard(bool isDark) {
    // Keep existing layout but ensure it matches modern style if not already
    final comisionAdmin = _empresaInfo?['comision_admin_porcentaje'] ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primaryDark.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.percent_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comisión Plataforma',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${comisionAdmin.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'de tu comisión a conductores',
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
    );
  }

  Widget _buildBalanceCard(bool isDark) {
    final saldo = _empresaInfo?['saldo_pendiente'] ?? 0.0;
    final hasDebt = saldo > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasDebt
              ? [AppColors.warning.withValues(alpha: 0.15), AppColors.warning.withValues(alpha: 0.05)]
              : [AppColors.success.withValues(alpha: 0.15), AppColors.success.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasDebt
              ? AppColors.warning.withValues(alpha: 0.3)
              : AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (hasDebt ? AppColors.warning : AppColors.success).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              hasDebt ? Icons.account_balance_wallet_outlined : Icons.check_circle_outline,
              color: hasDebt ? AppColors.warning : AppColors.success,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasDebt ? 'Saldo Pendiente' : 'Cuenta al día',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${saldo.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: hasDebt ? AppColors.warning : AppColors.success,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditSheet(Map<String, dynamic> config) async {
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
      'umbral_km_descuento': TextEditingController(text: config['umbral_km_descuento']?.toString() ?? '15'),
      'comision_plataforma': TextEditingController(text: config['comision_plataforma']?.toString() ?? '0'),
      'distancia_minima': TextEditingController(text: config['distancia_minima']?.toString() ?? '1'),
      'distancia_maxima': TextEditingController(text: config['distancia_maxima']?.toString() ?? '50'),
      'tiempo_espera_gratis': TextEditingController(text: config['tiempo_espera_gratis']?.toString() ?? '3'),
      'costo_tiempo_espera': TextEditingController(text: config['costo_tiempo_espera']?.toString() ?? '0'),
    };

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CompanyPricingSheet(
        config: config,
        controllers: controllers,
        vehicleTypeName: _vehicleTypeNames[config['tipo_vehiculo']] ?? config['tipo_vehiculo'] ?? 'Vehículo',
        empresaId: widget.user['empresa_id'] ?? widget.user['id'],
      ),
    );

    for (var controller in controllers.values) {
      controller.dispose();
    }

    if (result == true) {
      _fadeController.reset();
      _loadPricing();
    }
  }
}
