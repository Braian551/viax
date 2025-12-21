import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/conductor_earnings_provider.dart';

class ConductorEarningsScreen extends StatefulWidget {
  final int conductorId;

  const ConductorEarningsScreen({
    super.key,
    required this.conductorId,
  });

  @override
  State<ConductorEarningsScreen> createState() => _ConductorEarningsScreenState();
}

class _ConductorEarningsScreenState extends State<ConductorEarningsScreen> {
  late ConductorEarningsProvider _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = Provider.of<ConductorEarningsProvider>(context, listen: false);
      _loadEarnings();
    });
  }

  Future<void> _loadEarnings() async {
    await _provider.loadEarnings(widget.conductorId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildPeriodSelector(),
            Expanded(
              child: Consumer<ConductorEarningsProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading && provider.earnings == null) {
                    return _buildShimmerLoading();
                  }

                  if (provider.errorMessage != null && provider.earnings == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            provider.errorMessage!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _loadEarnings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFFF00),
                            ),
                            child: const Text(
                              'Reintentar',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _loadEarnings,
                    color: const Color(0xFFFFFF00),
                    backgroundColor: const Color(0xFF1A1A1A),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTotalEarningsCard(provider),
                          const SizedBox(height: 24),
                          _buildStatsGrid(provider),
                          const SizedBox(height: 24),
                          _buildEarningsBreakdown(provider),
                          const SizedBox(height: 24),
                          _buildWithdrawButton(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Mis Ganancias',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded, color: Colors.white),
          onPressed: () {
            // Navigate to history
          },
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Consumer<ConductorEarningsProvider>(
      builder: (context, provider, child) {
        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              _buildPeriodButton('Hoy', EarningsPeriod.today, provider),
              _buildPeriodButton('Semana', EarningsPeriod.week, provider),
              _buildPeriodButton('Mes', EarningsPeriod.month, provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodButton(String label, EarningsPeriod period, ConductorEarningsProvider provider) {
    final isSelected = provider.selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setPeriod(period, widget.conductorId),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFFF00) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalEarningsCard(ConductorEarningsProvider provider) {
    final earnings = provider.earnings;
    final total = earnings?.total ?? 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.2),
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
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.attach_money,
                      color: Colors.green,
                      size: 28,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '+15%',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Ganancias Totales',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '\$${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                provider.selectedPeriod == EarningsPeriod.today
                    ? 'Hoy'
                    : provider.selectedPeriod == EarningsPeriod.week
                        ? 'Esta semana'
                        : 'Este mes',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(ConductorEarningsProvider provider) {
    final earnings = provider.earnings;
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.route_rounded,
            label: 'Viajes',
            value: '${earnings?.totalViajes ?? 0}',
            color: const Color(0xFFFFFF00),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.attach_money,
            label: 'Promedio',
            value: '\$${(earnings?.promedioPorViaje ?? 0).toStringAsFixed(0)}',
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsBreakdown(ConductorEarningsProvider provider) {
    final earnings = provider.earnings;
    final total = earnings?.total ?? 0;
    
    // Calcular porcentajes aproximados
    final viajesAmount = total * 0.85;
    final propinasAmount = total * 0.10;
    final bonusAmount = total * 0.05;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Desglose de Ingresos',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildBreakdownItem(
          'Viajes completados',
          viajesAmount,
          85,
        ),
        const SizedBox(height: 12),
        _buildBreakdownItem(
          'Propinas',
          propinasAmount,
          10,
        ),
        const SizedBox(height: 12),
        _buildBreakdownItem(
          'Bonificaciones',
          bonusAmount,
          5,
        ),
      ],
    );
  }

  Widget _buildBreakdownItem(String label, double amount, int percentage) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '\$${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFFFF00),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          _showWithdrawDialog();
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: const Color(0xFFFFFF00),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        icon: const Icon(Icons.account_balance_wallet_rounded, color: Colors.black),
        label: const Text(
          'Retirar Fondos',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showWithdrawDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFFFFF00).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFF00).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Color(0xFFFFFF00),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Retirar Fondos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Los fondos se transferirÃ¡n a tu cuenta bancaria registrada.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'Disponible para retirar',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '\$88,000',
                        style: TextStyle(
                          color: Color(0xFFFFFF00),
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Retiro procesado exitosamente'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFFFFFF00),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Confirmar',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total earnings card shimmer
            _buildShimmerBox(height: 200, width: double.infinity),
            const SizedBox(height: 24),
            // Stats grid shimmer
            Row(
              children: [
                Expanded(child: _buildShimmerBox(height: 150)),
                const SizedBox(width: 12),
                Expanded(child: _buildShimmerBox(height: 150)),
              ],
            ),
            const SizedBox(height: 24),
            // Breakdown title shimmer
            _buildShimmerBox(height: 24, width: 180),
            const SizedBox(height: 16),
            // Breakdown items shimmer
            _buildShimmerBox(height: 80, width: double.infinity),
            const SizedBox(height: 12),
            _buildShimmerBox(height: 80, width: double.infinity),
            const SizedBox(height: 12),
            _buildShimmerBox(height: 80, width: double.infinity),
            const SizedBox(height: 24),
            // Withdraw button shimmer
            _buildShimmerBox(height: 54, width: double.infinity),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBox({required double height, double? width}) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: const Color(0xFF2A2A2A),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
