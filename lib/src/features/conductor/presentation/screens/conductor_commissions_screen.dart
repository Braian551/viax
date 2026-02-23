import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_debt_payment_screen.dart';
import 'package:viax/src/features/conductor/presentation/widgets/conductor_drawer.dart';
import 'package:viax/src/features/conductor/services/debt_payment_service.dart';
import 'package:viax/src/features/conductor/services/conductor_earnings_service.dart';
import 'package:viax/src/features/user/presentation/widgets/trip_preview/trip_price_formatter.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

enum CommissionPeriod { today, week, month }

class ConductorCommissionsScreen extends StatefulWidget {
  final int conductorId;
  final Map<String, dynamic>? conductorUser;

  const ConductorCommissionsScreen({
    super.key,
    required this.conductorId,
    this.conductorUser,
  });

  @override
  State<ConductorCommissionsScreen> createState() =>
      _ConductorCommissionsScreenState();
}

class _ConductorCommissionsScreenState extends State<ConductorCommissionsScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _headerController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  bool _isLoading = false;
  String? _errorMessage;
  EarningsModel? _commissions;
  Map<String, dynamic>? _debtContext;
  bool _hasShownMandatoryDialog = false;
  CommissionPeriod _period = CommissionPeriod.month;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic> response;

      switch (_period) {
        case CommissionPeriod.today:
          response = await ConductorEarningsService.getTodayEarnings(
            conductorId: widget.conductorId,
          );
          break;
        case CommissionPeriod.week:
          response = await ConductorEarningsService.getWeekEarnings(
            conductorId: widget.conductorId,
          );
          break;
        case CommissionPeriod.month:
          response = await ConductorEarningsService.getMonthEarnings(
            conductorId: widget.conductorId,
          );
          break;
      }

      final debtContext = await DebtPaymentService.getContext(
        conductorId: widget.conductorId,
      );

      if (!mounted) return;

      setState(() {
        if (response['success'] == true && response['ganancias'] is EarningsModel) {
          _commissions = response['ganancias'] as EarningsModel;
          if (debtContext['success'] == true && debtContext['data'] is Map<String, dynamic>) {
            _debtContext = Map<String, dynamic>.from(debtContext['data'] as Map);
          }
        } else {
          _errorMessage = response['message']?.toString() ??
              'No se pudieron cargar las comisiones.';
        }
      });

      _handleMandatoryPaymentFlow();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudieron cargar las comisiones.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _isMandatoryPayment {
    final alerta = _debtContext?['alerta'] as Map<String, dynamic>?;
    return alerta?['obligatoria'] == true;
  }

  String get _reportStatus => _debtContext?['estado_reporte']?.toString() ?? 'sin_reporte';

  bool get _isReportInReview =>
      _reportStatus == 'pendiente_revision' || _reportStatus == 'comprobante_aprobado';

  Future<void> _handleMandatoryPaymentFlow() async {
    if (!_isMandatoryPayment || _hasShownMandatoryDialog || !mounted) {
      return;
    }

    _hasShownMandatoryDialog = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Pago de deuda obligatorio'),
        content: const Text(
          'Tu deuda está vencida. Debes reportar el pago con comprobante para continuar.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _openDebtPayment();
            },
            child: const Text('Ir a pagar deuda'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDebtPayment() async {
    if (_debtContext == null) return;

    final cuenta = (_debtContext!['cuenta_transferencia'] as Map<String, dynamic>?);
    final configurada = cuenta?['configurada'] == true;
    if (!configurada) {
      CustomSnackbar.showError(
        context,
        message: 'La empresa no ha configurado una cuenta bancaria de transferencia',
      );
      return;
    }

    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ConductorDebtPaymentScreen(
          conductorId: widget.conductorId,
          contextData: _debtContext!,
        ),
      ),
    );

    if (refreshed == true) {
      _loadData();
    }
  }

  String _periodLabel(CommissionPeriod period) {
    switch (period) {
      case CommissionPeriod.today:
        return 'Hoy';
      case CommissionPeriod.week:
        return 'Semana';
      case CommissionPeriod.month:
        return 'Mes';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            _buildPeriodSelector(isDark),
            Expanded(child: _buildBody(isDark)),
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
                  : Colors.white.withValues(alpha: 0.92),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.15),
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
                        'Comisiones',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Deuda y detalle con la empresa',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppColors.warning,
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

  Widget _buildPeriodSelector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: CommissionPeriod.values.map((period) {
          final selected = period == _period;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _period = period);
                _loadData();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: isDark ? 0.28 : 0.18)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.85)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.25)),
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      Icon(Icons.check_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _periodLabel(period),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.primary
                            : (isDark ? Colors.white70 : AppColors.lightTextPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading && _commissions == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _commissions == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final commissions = _commissions;
    if (commissions == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _glassCard(
              isDark: isDark,
              borderColor: (commissions.comisionAdeudada > 0
                      ? AppColors.warning
                      : AppColors.success)
                  .withValues(alpha: 0.35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: commissions.comisionAdeudada > 0
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Deuda actual con empresa',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    formatCurrency(commissions.comisionAdeudada),
                    style: TextStyle(
                      color: commissions.comisionAdeudada > 0
                          ? AppColors.warning
                          : AppColors.success,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
            if (_debtContext != null &&
              (double.tryParse(_debtContext!['deuda_actual']?.toString() ?? '0') ?? 0) > 0 &&
              ((_debtContext!['alerta'] as Map<String, dynamic>?)?['mostrar'] == true)) ...[
              const SizedBox(height: 12),
              _buildDebtAlertCard(isDark),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _glassCard(
                    isDark: isDark,
                    borderColor: AppColors.primary.withValues(alpha: 0.28),
                    child: _statBlock(
                      isDark: isDark,
                      icon: Icons.percent_rounded,
                      title: 'Comisión del periodo',
                      value: formatCurrency(commissions.comisionPeriodo),
                      valueColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _glassCard(
                    isDark: isDark,
                    borderColor: AppColors.info.withValues(alpha: 0.28),
                    child: _statBlock(
                      isDark: isDark,
                      icon: Icons.pie_chart_rounded,
                      title: 'Porcentaje comisión',
                      value: '${commissions.comisionPromedioPorcentaje.toStringAsFixed(1)}%',
                      valueColor: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _glassCard(
              isDark: isDark,
              child: Row(
                children: [
                  Icon(Icons.local_taxi_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Viajes considerados',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${commissions.totalViajes} viajes',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Detalle diario de comisiones',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (commissions.desgloseDiario.isEmpty)
              _glassCard(
                isDark: isDark,
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.info),
                    const SizedBox(width: 10),
                    Text(
                      'No hay comisiones en este periodo.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...commissions.desgloseDiario.map(
                (day) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _glassCard(
                    isDark: isDark,
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            day.fecha,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${day.viajes} viajes',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          formatCurrency(day.comision),
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtAlertCard(bool isDark) {
    final alerta = (_debtContext?['alerta'] as Map<String, dynamic>?) ?? {};
    final cuenta = (_debtContext?['cuenta_transferencia'] as Map<String, dynamic>?) ?? {};
    final isMandatory = alerta['obligatoria'] == true;
    final configured = cuenta['configurada'] == true;
    final isInReview = _isReportInReview;
    final isApprovedPendingFinal = _reportStatus == 'comprobante_aprobado';
    final isRejected = _reportStatus == 'rechazado';

    final color = isMandatory ? AppColors.error : AppColors.warning;
    final message = isApprovedPendingFinal
      ? 'Tu comprobante fue aprobado. Falta la confirmación final del pago por la empresa.'
      : isInReview
      ? 'Tu comprobante ya fue enviado y está en revisión por la empresa.'
      : isMandatory
        ? 'Debes reportar el pago de deuda ahora. Esta alerta es obligatoria.'
        : isRejected
          ? 'Tu comprobante fue rechazado. Corrige y vuelve a subir un nuevo comprobante.'
          : 'Tienes deuda pendiente. Reporta tu pago con comprobante.';

    return _glassCard(
      isDark: isDark,
      borderColor: color.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isMandatory ? Icons.gpp_bad_rounded : Icons.notifications_active_rounded,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isMandatory ? 'Alerta obligatoria de deuda' : 'Recordatorio de deuda',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            configured
                ? message
                : 'La empresa no ha configurado cuenta de transferencia. Intenta nuevamente más tarde o contacta soporte.',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
            ),
          ),
          if (configured) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isInReview ? null : _openDebtPayment,
                icon: Icon(
                  isApprovedPendingFinal
                      ? Icons.verified_rounded
                      : isInReview
                          ? Icons.hourglass_top_rounded
                          : Icons.upload_file_rounded,
                ),
                label: Text(
                  isApprovedPendingFinal
                      ? 'Comprobante aprobado, pendiente confirmación final'
                      : isInReview
                      ? 'Tu comprobante está en revisión'
                      : isRejected
                          ? 'Volver a subir comprobante'
                          : 'Pagar deuda y subir comprobante',
                ),
                style: FilledButton.styleFrom(backgroundColor: color),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _glassCard({
    required bool isDark,
    required Widget child,
    Color? borderColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor ??
                  (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.2)),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _statBlock({
    required bool isDark,
    required IconData icon,
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: valueColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}
