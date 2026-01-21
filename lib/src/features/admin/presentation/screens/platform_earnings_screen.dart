import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:viax/src/global/services/admin/admin_service.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/features/admin/presentation/widgets/empresa_payment_sheet.dart';

/// Pantalla de Ganancias de la Plataforma (Admin)
/// Muestra:
/// - Total que le deben las empresas
/// - Ganancias del período
/// - Lista de empresas deudoras
/// - Historial de pagos recibidos
class PlatformEarningsScreen extends StatefulWidget {
  final int adminId;

  const PlatformEarningsScreen({
    super.key,
    required this.adminId,
  });

  @override
  State<PlatformEarningsScreen> createState() => _PlatformEarningsScreenState();
}

class _PlatformEarningsScreenState extends State<PlatformEarningsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String? _error;
  String _selectedPeriod = 'mes';
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'es_CO');

  final List<Map<String, String>> _periods = [
    {'value': 'hoy', 'label': 'Hoy'},
    {'value': 'semana', 'label': 'Semana'},
    {'value': 'mes', 'label': 'Mes'},
    {'value': 'anio', 'label': 'Año'},
    {'value': 'todo', 'label': 'Todo'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await AdminService.getPlatformEarnings(periodo: _selectedPeriod);
      
      if (result['success'] == true) {
        setState(() {
          _data = result['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['message'] ?? 'Error al cargar datos';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  void _changePeriod(String period) {
    if (period != _selectedPeriod) {
      setState(() => _selectedPeriod = period);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Ganancias Plataforma'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildContent(isDark),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey.withValues(alpha: 0.1),
          highlightColor: Colors.grey.withValues(alpha: 0.05),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(3, (index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.withValues(alpha: 0.1),
            highlightColor: Colors.grey.withValues(alpha: 0.05),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(_error ?? 'Error desconocido'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final resumen = _data?['resumen'];
    final empresas = List<Map<String, dynamic>>.from(_data?['empresas_deudoras'] ?? []);
    final movimientos = List<Map<String, dynamic>>.from(_data?['ultimos_movimientos'] ?? []);
    final stats = _data?['estadisticas_viajes'];

    final totalPorCobrar = double.tryParse(resumen?['total_por_cobrar']?.toString() ?? '0') ?? 0;
    final gananciasPeriodo = double.tryParse(resumen?['ganancias_periodo']?.toString() ?? '0') ?? 0;
    final pagosRecibidos = double.tryParse(resumen?['pagos_recibidos_periodo']?.toString() ?? '0') ?? 0;
    final totalViajes = int.tryParse(stats?['total_viajes']?.toString() ?? '0') ?? 0;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          // Period Selector
          _buildPeriodSelector(isDark),
          const SizedBox(height: 20),

          // Main Balance Card
          _buildMainBalanceCard(isDark, totalPorCobrar),
          const SizedBox(height: 16),

          // Stats Row
          _buildStatsRow(isDark, gananciasPeriodo, pagosRecibidos, totalViajes),
          const SizedBox(height: 24),

          // Empresas Deudoras Section
          _buildSectionHeader('Empresas con Saldo Pendiente', Icons.business_rounded),
          const SizedBox(height: 12),
          if (empresas.isEmpty)
            _buildEmptyCard('No hay empresas con saldo pendiente 🎉')
          else
            ...empresas.map((e) => _buildEmpresaCard(e, isDark)),

          const SizedBox(height: 24),

          // Últimos Movimientos
          _buildSectionHeader('Últimos Movimientos', Icons.history_rounded),
          const SizedBox(height: 12),
          if (movimientos.isEmpty)
            _buildEmptyCard('Sin movimientos registrados')
          else
            ...movimientos.take(10).map((m) => _buildMovimientoCard(m, isDark)),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _periods.map((p) {
          final isSelected = p['value'] == _selectedPeriod;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(p['label']!),
              selected: isSelected,
              onSelected: (_) => _changePeriod(p['value']!),
              backgroundColor: isDark ? AppColors.darkCard : Colors.grey.shade100,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainBalanceCard(bool isDark, double totalPorCobrar) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 28),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Por Cobrar',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Cuentas por Cobrar',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(totalPorCobrar),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total que deben todas las empresas',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark, double ganancias, double pagos, int viajes) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            isDark,
            'Ganancias',
            _currencyFormat.format(ganancias),
            Icons.trending_up_rounded,
            AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            isDark,
            'Pagos Recibidos',
            _currencyFormat.format(pagos),
            Icons.payments_rounded,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            isDark,
            'Viajes',
            viajes.toString(),
            Icons.directions_car_rounded,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(bool isDark, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.grey.withValues(alpha: 0.7)),
        ),
      ),
    );
  }

  Widget _buildEmpresaCard(Map<String, dynamic> empresa, bool isDark) {
    final nombre = empresa['nombre'] ?? 'Empresa';
    final saldo = double.tryParse(empresa['saldo_pendiente']?.toString() ?? '0') ?? 0;
    final comision = double.tryParse(empresa['comision_porcentaje']?.toString() ?? '0') ?? 0;
    final totalViajes = int.tryParse(empresa['total_viajes']?.toString() ?? '0') ?? 0;
    final empresaId = int.tryParse(empresa['id']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: saldo > 0 
              ? AppColors.warning.withValues(alpha: 0.4) 
              : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showPaymentDialog(empresaId, nombre, saldo, comision),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : 'E',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalViajes viajes • ${comision.toStringAsFixed(1)}% comisión',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currencyFormat.format(saldo),
                      style: TextStyle(
                        color: saldo > 0 ? AppColors.warning : AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (saldo > 0)
                      Text(
                        'Pendiente',
                        style: TextStyle(fontSize: 11, color: AppColors.warning),
                      )
                    else
                      Text(
                        'Al día',
                        style: TextStyle(fontSize: 11, color: AppColors.success),
                      ),
                  ],
                ),
                if (saldo > 0) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: AppColors.warning.withValues(alpha: 0.5)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMovimientoCard(Map<String, dynamic> mov, bool isDark) {
    final monto = double.tryParse(mov['monto']?.toString() ?? '0') ?? 0;
    final tipo = mov['tipo'] ?? 'cargo';
    final empresaNombre = mov['empresa_nombre'] ?? 'Empresa';
    final fecha = mov['fecha'] ?? '';
    final esPago = tipo == 'pago';

    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(fecha);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (esPago ? AppColors.success : Colors.orange).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (esPago ? AppColors.success : Colors.orange).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              esPago ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: esPago ? AppColors.success : Colors.orange,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esPago ? 'Pago recibido' : 'Comisión generada',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  empresaNombre,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (parsedDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _dateFormat.format(parsedDate),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${esPago ? '+' : ''}${_currencyFormat.format(monto)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: esPago ? AppColors.success : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentDialog(int empresaId, String empresaNombre, double saldoActual, double comisionPorcentaje) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => EmpresaPaymentSheet(
          empresaId: empresaId,
          empresaNombre: empresaNombre,
          saldoPendiente: saldoActual,
          comisionPorcentaje: comisionPorcentaje,
          adminId: widget.adminId,
          onPaymentRegistered: _loadData,
        ),
      ),
    );
  }
}
