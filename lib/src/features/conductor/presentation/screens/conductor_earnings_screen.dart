import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_colors.dart';
import '../../providers/conductor_earnings_provider.dart';
import '../widgets/conductor_drawer.dart';
import '../widgets/earnings/earnings_widgets.dart';
import '../../../user/presentation/widgets/trip_preview/trip_price_formatter.dart';

/// Pantalla de Ganancias del Conductor
/// 
/// Muestra las ganancias en efectivo con filtros por período,
/// estadísticas y desglose. Solo efectivo, sin retiro de fondos.
class ConductorEarningsScreen extends StatefulWidget {
  final int conductorId;
  final Map<String, dynamic>? conductorUser;

  const ConductorEarningsScreen({
    super.key,
    required this.conductorId,
    this.conductorUser,
  });

  @override
  State<ConductorEarningsScreen> createState() => _ConductorEarningsScreenState();
}

class _ConductorEarningsScreenState extends State<ConductorEarningsScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _headerController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _headerController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadEarnings();
      });
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  Future<void> _loadEarnings() async {
    if (!mounted) return;
    final provider = context.read<ConductorEarningsProvider>();
    await provider.loadEarnings(widget.conductorId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: widget.conductorUser != null
          ? ConductorDrawer(conductorUser: widget.conductorUser!)
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            _buildPeriodSelector(),
            Expanded(
              child: _buildBody(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return AnimatedBuilder(
      animation: _headerController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _headerFadeAnimation,
          child: SlideTransition(
            position: _headerSlideAnimation,
            child: child,
          ),
        );
      },
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBackground.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.9),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (widget.conductorUser != null)
                  IconButton(
                    icon: Icon(
                      Icons.menu_rounded,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  )
                else
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mis Ganancias',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Solo efectivo',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white60
                              : AppColors.lightTextSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Icono de efectivo
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.payments_rounded,
                    color: AppColors.success,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Consumer<ConductorEarningsProvider>(
      builder: (context, provider, _) {
        return EarningsPeriodSelector(
          selectedPeriod: _mapPeriodToType(provider.selectedPeriod),
          onPeriodChanged: (type) {
            final period = _mapTypeToPeriod(type);
            provider.setPeriod(period, widget.conductorId);
          },
        );
      },
    );
  }

  Widget _buildBody(bool isDark) {
    return Consumer<ConductorEarningsProvider>(
      builder: (context, provider, _) {
        // Loading state
        if (provider.isLoading && provider.earnings == null) {
          return const EarningsShimmer();
        }

        // Error state
        if (provider.errorMessage != null && provider.earnings == null) {
          return EarningsEmptyState(
            isError: true,
            errorMessage: provider.errorMessage,
            onRetry: _loadEarnings,
          );
        }

        final earnings = provider.earnings;

        // Empty state
        if (earnings == null || (earnings.total == 0 && earnings.totalViajes == 0)) {
          return RefreshIndicator(
            onRefresh: _loadEarnings,
            color: AppColors.primary,
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: const EarningsEmptyState(isError: false),
              ),
            ),
          );
        }

        // Success state
        return RefreshIndicator(
          onRefresh: _loadEarnings,
          color: AppColors.primary,
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                EarningsTotalCard(
                  total: earnings.total,
                  periodLabel: _getPeriodLabel(provider.selectedPeriod),
                  totalTrips: earnings.totalViajes,
                ),
                // Card de comisión adeudada
                if (earnings.comisionAdeudada > 0)
                  _buildCommissionCard(earnings.comisionAdeudada, isDark),
                const SizedBox(height: 24),
                EarningsStatsGrid(
                  totalTrips: earnings.totalViajes,
                  averagePerTrip: earnings.promedioPorViaje,
                  comisionPeriodo: earnings.comisionPeriodo,
                ),
                const SizedBox(height: 28),
                EarningsBreakdownSection(
                  total: earnings.total,
                  dailyBreakdown: earnings.desgloseDiario,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getPeriodLabel(EarningsPeriod period) {
    switch (period) {
      case EarningsPeriod.today:
        return 'Hoy';
      case EarningsPeriod.week:
        return 'Esta semana';
      case EarningsPeriod.month:
        return 'Este mes';
    }
  }

  EarningsPeriodType _mapPeriodToType(EarningsPeriod period) {
    switch (period) {
      case EarningsPeriod.today:
        return EarningsPeriodType.today;
      case EarningsPeriod.week:
        return EarningsPeriodType.week;
      case EarningsPeriod.month:
        return EarningsPeriodType.month;
    }
  }

  EarningsPeriod _mapTypeToPeriod(EarningsPeriodType type) {
    switch (type) {
      case EarningsPeriodType.today:
        return EarningsPeriod.today;
      case EarningsPeriodType.week:
        return EarningsPeriod.week;
      case EarningsPeriodType.month:
        return EarningsPeriod.month;
    }
  }

  Widget _buildCommissionCard(double comisionAdeudada, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.orange.withValues(alpha: 0.15) 
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comisión adeudada a empresa',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total acumulado pendiente de pago',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatCurrency(comisionAdeudada),
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
