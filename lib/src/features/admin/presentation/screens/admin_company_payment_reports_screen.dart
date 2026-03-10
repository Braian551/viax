import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/features/admin/services/admin_company_commissions_service.dart';
import 'package:viax/src/features/company/presentation/widgets/company_logo.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/dialogs/critical_action_dialog.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'package:viax/src/features/admin/presentation/screens/document_viewer_screen.dart';

/// Pantalla de administración de comprobantes de pago empresa→admin.
/// Muestra empresas deudoras y comprobantes pendientes de revisión.
class AdminCompanyPaymentReportsScreen extends StatefulWidget {
  final int adminId;
  final Map<String, dynamic> adminUser;

  const AdminCompanyPaymentReportsScreen({
    super.key,
    required this.adminId,
    required this.adminUser,
  });

  @override
  State<AdminCompanyPaymentReportsScreen> createState() =>
      _AdminCompanyPaymentReportsScreenState();
}

class _AdminCompanyPaymentReportsScreenState
    extends State<AdminCompanyPaymentReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  // — Pestaña Empresas Deudoras —
  List<Map<String, dynamic>> _empresas = [];
  Map<String, dynamic> _resumenDeudoras = {};

  // — Pestaña Comprobantes —
  List<Map<String, dynamic>> _reportes = [];
  Map<String, dynamic> _resumenReportes = {};
  String _filtroEstado = '';

  // — Pestaña Facturas —
  List<Map<String, dynamic>> _facturas = [];
  Map<String, dynamic> _resumenFacturas = {};

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'es_CO');
  static const double _debtEpsilonCop = 1.0;

  double _normalizeSaldoCop(dynamic value) {
    final saldo = double.tryParse(value?.toString() ?? '0') ?? 0;
    return saldo.abs() < _debtEpsilonCop ? 0 : saldo;
  }

  bool _hasActiveDebt(Map<String, dynamic> empresa) {
    final deudaActivaRaw = empresa['deuda_activa'];
    if (deudaActivaRaw is bool) {
      return deudaActivaRaw;
    }
    final deudaActivaNum = int.tryParse(deudaActivaRaw?.toString() ?? '');
    if (deudaActivaNum != null) {
      return deudaActivaNum == 1;
    }
    return _normalizeSaldoCop(empresa['saldo_pendiente']) >= _debtEpsilonCop;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadTabData(_tabController.index);
      }
    });
    _loadTabData(0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTabData(int tabIndex) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      switch (tabIndex) {
        case 0:
          await _loadEmpresasDeudoras();
          break;
        case 1:
          await _loadComprobantes();
          break;
        case 2:
          await _loadFacturas();
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error de conexión: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadEmpresasDeudoras() async {
    final result = await AdminCompanyCommissionsService.getEmpresasDeudoras();
    if (!mounted) return;

    if (result['success'] == true) {
      final rawData = result['data'];
      final empresasRaw = rawData is List
          ? rawData
          : (rawData is Map<String, dynamic>
              ? (rawData['empresas'] ?? [])
              : []);
      final resumenRaw = result['resumen'] ??
          (rawData is Map<String, dynamic> ? rawData['resumen'] : {});

      setState(() {
        _empresas = List<Map<String, dynamic>>.from(empresasRaw);
        _resumenDeudoras = Map<String, dynamic>.from(resumenRaw ?? {});
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['message'] ?? 'Error al cargar empresas';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadComprobantes() async {
    final result = await AdminCompanyCommissionsService.getPaymentReports(
      estado: _filtroEstado.isEmpty ? null : _filtroEstado,
    );
    if (!mounted) return;

    if (result['success'] == true) {
      final rawData = result['data'];
      final reportesRaw = rawData is List
          ? rawData
          : (rawData is Map<String, dynamic>
              ? (rawData['reportes'] ?? [])
              : []);
      final resumenRaw = result['resumen'] ??
          (rawData is Map<String, dynamic> ? rawData['resumen'] : {});

      setState(() {
        _reportes = List<Map<String, dynamic>>.from(reportesRaw);
        _resumenReportes = Map<String, dynamic>.from(resumenRaw ?? {});
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['message'] ?? 'Error al cargar comprobantes';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFacturas() async {
    final result = await AdminCompanyCommissionsService.getFacturas();
    if (!mounted) return;

    if (result['success'] == true) {
      final rawData = result['data'];
      final facturasRaw = rawData is List
          ? rawData
          : (rawData is Map<String, dynamic>
              ? (rawData['facturas'] ?? [])
              : []);
      final resumenRaw = result['resumen'] ??
          (rawData is Map<String, dynamic> ? rawData['resumen'] : {});

      setState(() {
        _facturas = List<Map<String, dynamic>>.from(facturasRaw);
        _resumenFacturas = Map<String, dynamic>.from(resumenRaw ?? {});
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['message'] ?? 'Error al cargar facturas';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Pagos de Empresas'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_rounded),
            onPressed: () => _showBankConfigSheet(isDark),
            tooltip: 'Configurar cuenta bancaria',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadTabData(_tabController.index),
            tooltip: 'Actualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor:
              isDark ? Colors.white54 : AppColors.lightTextSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Empresas', icon: Icon(Icons.business_rounded, size: 18)),
            Tab(
                text: 'Comprobantes',
                icon: Icon(Icons.receipt_long_rounded, size: 18)),
            Tab(
                text: 'Facturas',
                icon: Icon(Icons.description_rounded, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _isLoading && _tabController.index == 0
              ? _buildLoading()
              : _error != null && _tabController.index == 0
                  ? _buildError()
                  : _buildEmpresasTab(isDark),
          _isLoading && _tabController.index == 1
              ? _buildLoading()
              : _error != null && _tabController.index == 1
                  ? _buildError()
                  : _buildComprobantesTab(isDark),
          _isLoading && _tabController.index == 2
              ? _buildLoading()
              : _error != null && _tabController.index == 2
                  ? _buildError()
                  : _buildFacturasTab(isDark),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // Pestaña 1: Empresas Deudoras
  // ════════════════════════════════════════
  Widget _buildEmpresasTab(bool isDark) {
    final totalDeuda = double.tryParse(
            _resumenDeudoras['deuda_total']?.toString() ?? '0') ??
        0;
    final totalPagado = double.tryParse(
            _resumenDeudoras['total_pagado_global']?.toString() ?? '0') ??
        0;

    return RefreshIndicator(
      onRefresh: () => _loadTabData(0),
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        children: [
          // Tarjeta resumen
          _buildResumenDeudaCard(isDark, totalDeuda, totalPagado),
          const SizedBox(height: 20),

          _buildSectionHeader('Empresas con deuda', Icons.business_rounded),
          const SizedBox(height: 12),

          if (_empresas.isEmpty)
            _buildEmptyCard('No hay empresas con deuda pendiente 🎉')
          else
            ..._empresas.map((e) => _buildEmpresaDeudoraCard(e, isDark)),
        ],
      ),
    );
  }

  Widget _buildResumenDeudaCard(
      bool isDark, double totalDeuda, double totalPagado) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 24),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_resumenDeudoras['total_empresas'] ?? 0} empresas',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Total por Cobrar',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            _currencyFormat.format(totalDeuda),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniStat(
                  'Pagado', _currencyFormat.format(totalPagado), Colors.white),
              const SizedBox(width: 20),
              _buildMiniStat(
                'Pendientes',
                '${_resumenDeudoras['reportes_pendientes'] ?? 0}',
                Colors.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }

  Widget _buildEmpresaDeudoraCard(
      Map<String, dynamic> empresa, bool isDark) {
    final nombre = empresa['nombre'] ?? 'Empresa';
    final saldo = _normalizeSaldoCop(empresa['saldo_pendiente']);
    final deudaActiva = _hasActiveDebt(empresa);
    final reportesPendientes =
        int.tryParse(empresa['reportes_pendientes']?.toString() ?? '0') ?? 0;
    final logoKey = empresa['logo_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: deudaActiva
              ? AppColors.warning.withValues(alpha: 0.4)
              : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CompanyLogo(
              logoKey: logoKey,
              nombreEmpresa: nombre,
              size: 48,
              fontSize: 18,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  if (reportesPendientes > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$reportesPendientes comprobante${reportesPendientes > 1 ? 's' : ''} pendiente${reportesPendientes > 1 ? 's' : ''}',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600),
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
                    color:
                        deudaActiva ? AppColors.warning : AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  deudaActiva ? 'Pendiente' : 'Al día',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        deudaActiva ? AppColors.warning : AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════
  // Pestaña 2: Comprobantes
  // ════════════════════════════════════════
  Widget _buildComprobantesTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: () => _loadTabData(1),
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        children: [
          // Filtros de estado
          _buildEstadoFilters(isDark),
          const SizedBox(height: 16),

          // Resumen
          _buildComprobantesResumen(isDark),
          const SizedBox(height: 16),

          if (_reportes.isEmpty)
            _buildEmptyCard('No hay comprobantes para mostrar')
          else
            ..._reportes.map((r) => _buildReporteCard(r, isDark)),
        ],
      ),
    );
  }

  Widget _buildEstadoFilters(bool isDark) {
    final estados = [
      {'value': '', 'label': 'Todos', 'icon': Icons.all_inclusive},
      {
        'value': 'pendiente_revision',
        'label': 'Pendientes',
        'icon': Icons.pending_rounded
      },
      {
        'value': 'comprobante_aprobado',
        'label': 'Aprobados',
        'icon': Icons.check_circle_outline
      },
      {
        'value': 'pagado_confirmado',
        'label': 'Confirmados',
        'icon': Icons.verified_rounded
      },
      {
        'value': 'rechazado',
        'label': 'Rechazados',
        'icon': Icons.cancel_outlined
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: estados.map((e) {
          final isSelected = e['value'] == _filtroEstado;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(e['icon'] as IconData,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white54 : Colors.grey)),
              label: Text(e['label'] as String),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _filtroEstado = e['value'] as String);
                _loadTabData(1);
              },
              backgroundColor:
                  isDark ? AppColors.darkCard : Colors.grey.shade100,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildComprobantesResumen(bool isDark) {
    final pendientes =
        int.tryParse(_resumenReportes['pendientes']?.toString() ?? '0') ?? 0;
    final aprobados =
        int.tryParse(_resumenReportes['aprobados']?.toString() ?? '0') ?? 0;
    final montoPendiente = double.tryParse(
            _resumenReportes['monto_pendiente']?.toString() ?? '0') ??
        0;

    return Row(
      children: [
        Expanded(
          child: _buildStatChip(
              isDark, '$pendientes', 'Pendientes', AppColors.warning),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatChip(
              isDark, '$aprobados', 'Aprobados', AppColors.info),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatChip(isDark,
              _currencyFormat.format(montoPendiente), 'Por cobrar', AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildStatChip(
      bool isDark, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildReporteCard(Map<String, dynamic> reporte, bool isDark) {
    final empresaNombre = reporte['empresa_nombre'] ?? 'Empresa';
    final monto =
        double.tryParse(reporte['monto_reportado']?.toString() ?? reporte['monto']?.toString() ?? '0') ?? 0;
    final estado = reporte['estado'] ?? 'pendiente_revision';
    final fechaStr = reporte['created_at'] ?? '';
    final reporteId =
        int.tryParse(reporte['id']?.toString() ?? '0') ?? 0;
    final comprobanteUrl = reporte['comprobante_url'];

    DateTime? fecha;
    try {
      fecha = DateTime.parse(fechaStr);
    } catch (_) {}

    Color estadoColor;
    String estadoLabel;
    IconData estadoIcon;
    switch (estado) {
      case 'pendiente_revision':
        estadoColor = AppColors.warning;
        estadoLabel = 'Pendiente';
        estadoIcon = Icons.pending_rounded;
        break;
      case 'comprobante_aprobado':
        estadoColor = AppColors.info;
        estadoLabel = 'Aprobado';
        estadoIcon = Icons.check_circle_outline;
        break;
      case 'pagado_confirmado':
        estadoColor = AppColors.success;
        estadoLabel = 'Confirmado';
        estadoIcon = Icons.verified_rounded;
        break;
      case 'rechazado':
        estadoColor = AppColors.error;
        estadoLabel = 'Rechazado';
        estadoIcon = Icons.cancel_outlined;
        break;
      default:
        estadoColor = Colors.grey;
        estadoLabel = estado;
        estadoIcon = Icons.help_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: estadoColor.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () =>
              _showReporteDetailSheet(reporte, isDark),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: estadoColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(estadoIcon, color: estadoColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(empresaNombre,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          )),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: estadoColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(estadoLabel,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: estadoColor,
                                    fontWeight: FontWeight.w600)),
                          ),
                          if (fecha != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _dateFormat.format(fecha),
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  _currencyFormat.format(monto),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: estadoColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════
  // Pestaña 3: Facturas
  // ════════════════════════════════════════
  Widget _buildFacturasTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: () => _loadTabData(2),
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        children: [
          // Resumen facturas
          _buildFacturasResumen(isDark),
          const SizedBox(height: 16),

          _buildSectionHeader('Facturas generadas', Icons.description_rounded),
          const SizedBox(height: 12),

          if (_facturas.isEmpty)
            _buildEmptyCard('No hay facturas generadas aún')
          else
            ..._facturas.map((f) => _buildFacturaCard(f, isDark)),
        ],
      ),
    );
  }

  Widget _buildFacturasResumen(bool isDark) {
    final totalFacturas =
        int.tryParse(_resumenFacturas['total_facturas']?.toString() ?? '0') ??
            0;
    final totalFacturado = double.tryParse(
            _resumenFacturas['total_facturado']?.toString() ?? '0') ??
        0;

    return Row(
      children: [
        Expanded(
          child: _buildStatChip(
              isDark, '$totalFacturas', 'Total facturas', AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatChip(isDark,
              _currencyFormat.format(totalFacturado), 'Facturado', AppColors.success),
        ),
      ],
    );
  }

  Widget _buildFacturaCard(Map<String, dynamic> factura, bool isDark) {
    final numero = factura['numero_factura'] ?? '';
    final monto =
        double.tryParse(factura['total']?.toString() ?? factura['monto']?.toString() ?? '0') ?? 0;
    final estado = factura['estado'] ?? 'emitida';
    final emisor = factura['emisor_nombre'] ?? '';
    final fechaStr = factura['fecha_emision'] ?? '';
    final pdfRuta = factura['pdf_ruta'];
    final pdfUrl = factura['pdf_url'];

    // Resolver URL del PDF a través del R2 proxy
    String? resolvedPdfUrl;
    if (pdfRuta != null && pdfRuta.toString().isNotEmpty) {
      resolvedPdfUrl = '${AppConfig.baseUrl}/r2_proxy.php?key=$pdfRuta';
    } else if (pdfUrl != null && pdfUrl.toString().isNotEmpty) {
      resolvedPdfUrl = pdfUrl;
    }

    DateTime? fecha;
    try {
      fecha = DateTime.parse(fechaStr);
    } catch (_) {}

    return GestureDetector(
      onTap: resolvedPdfUrl != null
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentViewerScreen(
                    documentUrl: resolvedPdfUrl!,
                    documentName: numero.isNotEmpty ? numero : 'Factura',
                    tipoArchivo: 'pdf',
                  ),
                ),
              )
          : null,
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(numero,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                    )),
                const SizedBox(height: 2),
                Text(emisor,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    )),
                if (fecha != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _dateFormat.format(fecha),
                    style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4)),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currencyFormat.format(monto),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.success),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (estado == 'pagada'
                          ? AppColors.success
                          : AppColors.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  estado == 'pagada' ? 'Pagada' : 'Emitida',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: estado == 'pagada'
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          if (resolvedPdfUrl != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.download_rounded,
                  size: 20,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4)),
            ),
        ],
      ),
    ),
    );
  }

  // ════════════════════════════════════════
  // Detalle de comprobante (Bottom Sheet)
  // ════════════════════════════════════════
  void _showReporteDetailSheet(
      Map<String, dynamic> reporte, bool isDark) {
    final estado = reporte['estado'] ?? 'pendiente_revision';
    final monto =
        double.tryParse(reporte['monto_reportado']?.toString() ?? reporte['monto']?.toString() ?? '0') ?? 0;
    final empresaNombre = reporte['empresa_nombre'] ?? 'Empresa';
    final observaciones = reporte['observaciones_empresa'] ?? reporte['observaciones'] ?? '';
    final reporteId =
        int.tryParse(reporte['id']?.toString() ?? '0') ?? 0;
    final comprobanteUrl = reporte['comprobante_url'];
    final motivoRechazo = reporte['motivo_rechazo'] ?? '';

    final motivoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Título
              Text(
                'Comprobante de $empresaNombre',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(sheetContext).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),

              // Monto
              _buildDetailRow(
                  'Monto', _currencyFormat.format(monto), isDark),
              _buildDetailRow('Estado', _getEstadoLabel(estado), isDark),
              if (observaciones.isNotEmpty)
                _buildDetailRow('Observaciones', observaciones, isDark),
              if (motivoRechazo.isNotEmpty)
                _buildDetailRow(
                    'Motivo rechazo', motivoRechazo, isDark),

              const SizedBox(height: 12),
              _buildSectionHeader('Trazabilidad', Icons.timeline_rounded),
              const SizedBox(height: 8),
              _buildTimelineTile(
                isDark: isDark,
                title: 'Reporte creado',
                timestamp: reporte['created_at']?.toString(),
                subtitle: 'Empresa envió comprobante',
                icon: Icons.upload_file_rounded,
                color: AppColors.info,
              ),
              _buildTimelineTile(
                isDark: isDark,
                title: 'Aprobación de comprobante',
                timestamp: reporte['aprobado_en']?.toString(),
                subtitle: _actorLabel('Aprobado por', reporte['aprobado_por']),
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
              ),
              _buildTimelineTile(
                isDark: isDark,
                title: 'Rechazo de comprobante',
                timestamp: reporte['rechazado_en']?.toString(),
                subtitle: _actorLabel('Rechazado por', reporte['rechazado_por']),
                icon: Icons.cancel_outlined,
                color: AppColors.error,
              ),
              _buildTimelineTile(
                isDark: isDark,
                title: 'Pago confirmado',
                timestamp: reporte['confirmado_en']?.toString(),
                subtitle: _actorLabel('Confirmado por', reporte['confirmado_por']),
                icon: Icons.verified_rounded,
                color: AppColors.primary,
              ),

              const SizedBox(height: 20),

              // Imagen del comprobante
              if (comprobanteUrl != null && comprobanteUrl.isNotEmpty) ...[
                Text('Comprobante adjunto',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Theme.of(sheetContext).colorScheme.onSurface,
                    )),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocumentViewerScreen(
                          documentUrl: comprobanteUrl,
                          documentName: 'Comprobante #${reporte['id']}',
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      comprobanteUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 100,
                        color: Colors.grey.withValues(alpha: 0.1),
                        child: const Center(
                            child: Icon(Icons.broken_image_rounded,
                                size: 40, color: Colors.grey)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DocumentViewerScreen(
                            documentUrl: comprobanteUrl,
                            documentName: 'Comprobante #${reporte['id']}',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.fullscreen_rounded),
                    label: const Text('Ver comprobante completo'),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Acciones según estado
              if (estado == 'pendiente_revision') ...[
                // APROBAR
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmAndPerformAction(
                      sheetContext,
                      reporteId,
                      'approve',
                      title: 'Aprobar comprobante',
                      message:
                          'Vas a aprobar este comprobante. Luego solo faltará confirmar el pago final.',
                    ),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Aprobar comprobante'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // RECHAZAR con motivo
                TextField(
                  controller: motivoController,
                  decoration: InputDecoration(
                    hintText: 'Motivo del rechazo...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (motivoController.text.trim().isEmpty) {
                        CustomSnackbar.show(
                          sheetContext,
                          message: 'Escribe el motivo del rechazo',
                          type: SnackbarType.warning,
                        );
                        return;
                      }
                      _confirmAndPerformAction(
                        sheetContext,
                        reporteId,
                        'reject',
                        title: 'Rechazar comprobante',
                        message:
                            'Vas a rechazar este comprobante. La empresa deberá enviar uno nuevo.',
                        motivo: motivoController.text.trim(),
                      );
                    },
                    icon: const Icon(Icons.cancel_rounded),
                    label: const Text('Rechazar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],

              if (estado == 'comprobante_aprobado') ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmAndPerformAction(
                      sheetContext,
                      reporteId,
                      'confirm_payment',
                      title: 'Confirmar pago recibido',
                      message:
                          'Esta acción impacta saldos y factura. Solo confirma si el dinero ya está verificado.',
                    ),
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text('Confirmar pago recibido'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performAction(
    BuildContext sheetContext,
    int reporteId,
    String action, {
    String? motivo,
  }) async {
    Navigator.of(sheetContext).pop();

    setState(() => _isLoading = true);

    try {
      final result = await AdminCompanyCommissionsService.performAction(
        reporteId: reporteId,
        action: action,
        actorUserId: widget.adminId,
        motivo: motivo,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        CustomSnackbar.show(
          context,
          message: result['message'] ?? 'Acción realizada',
          type: SnackbarType.success,
        );
      } else {
        CustomSnackbar.show(
          context,
          message: result['message'] ?? 'Error',
          type: SnackbarType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context,
          message: 'Error: $e',
          type: SnackbarType.error,
        );
      }
    }

    // Recargar datos de la pestaña actual
    _loadTabData(_tabController.index);
  }

  Future<void> _confirmAndPerformAction(
    BuildContext sheetContext,
    int reporteId,
    String action, {
    String? motivo,
    required String title,
    required String message,
  }) async {
    final isDanger = action == 'reject';
    final confirmed = await CriticalActionDialog.show(
      sheetContext,
      title: title,
      message: message,
      confirmText: isDanger ? 'Sí, continuar' : 'Sí, confirmar',
      isDanger: isDanger,
      icon: isDanger ? Icons.report_problem_rounded : Icons.verified_rounded,
    );

    if (!confirmed) return;
    await _performAction(sheetContext, reporteId, action, motivo: motivo);
  }

  Widget _buildTimelineTile({
    required bool isDark,
    required String title,
    required String? timestamp,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final formatted = _formatTimelineTimestamp(timestamp);
    final isDone = formatted != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDone ? color : Colors.grey).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDone ? color : Colors.grey).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (isDone ? color : Colors.grey).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: isDone ? color : Colors.grey),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDone ? '$subtitle · $formatted' : 'Pendiente',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _actorLabel(String prefix, dynamic actorId) {
    final raw = actorId?.toString() ?? '';
    if (raw.isEmpty || raw == '0') return prefix;
    return '$prefix #$raw';
  }

  String? _formatTimelineTimestamp(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      final parsed = DateTime.parse(value).toLocal();
      return _dateFormat.format(parsed);
    } catch (_) {
      return value;
    }
  }

  String _getEstadoLabel(String estado) {
    switch (estado) {
      case 'pendiente_revision':
        return 'Pendiente de revisión';
      case 'comprobante_aprobado':
        return 'Comprobante aprobado';
      case 'pagado_confirmado':
        return 'Pago confirmado';
      case 'rechazado':
        return 'Rechazado';
      default:
        return estado;
    }
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? Colors.white54
                        : AppColors.lightTextSecondary,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white
                        : AppColors.lightTextPrimary)),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // Configurar cuenta bancaria admin
  // ════════════════════════════════════════
  void _showBankConfigSheet(bool isDark) {
    final bancoController = TextEditingController();
    final cuentaController = TextEditingController();
    final titularController = TextEditingController();
    final tipoController = TextEditingController();
    final documentoController = TextEditingController();
    final referenciaController = TextEditingController();
    String metodoRecaudo = 'cuenta_bancaria';
    bool hasInitialized = false;
    bool isLoadingBanks = true;
    List<Map<String, String>> banks = [];
    Map<String, String>? selectedBank;
    bool isLoadingConfig = true;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (!hasInitialized) {
            hasInitialized = true;
            Future<void>(() async {
              // Cargar catálogo de bancos (misma API usada por Empresa).
              try {
                final banksRes = await http.get(
                  Uri.parse('${AppConfig.baseUrl}/company/colombia_banks.php'),
                  headers: {'Accept': 'application/json'},
                );
                if (banksRes.statusCode == 200) {
                  final body = json.decode(banksRes.body);
                  if (body['success'] == true && body['data'] is List) {
                    banks = List<Map<String, String>>.from(
                      (body['data'] as List).map(
                        (item) => {
                          'codigo': item['codigo']?.toString() ?? '',
                          'nombre': item['nombre']?.toString() ?? '',
                        },
                      ),
                    ).where((e) => (e['nombre'] ?? '').isNotEmpty).toList();
                  }
                }
              } catch (_) {
                banks = [];
              } finally {
                if (ctx.mounted) {
                  setSheetState(() => isLoadingBanks = false);
                }
              }

              final result = await AdminCompanyCommissionsService.getBankConfig(
                adminId: widget.adminId,
              );

              if (result['success'] == true) {
                final config = result['data'] as Map<String, dynamic>? ?? {};
                final metodoRaw = (config['metodo_recaudo']?.toString() ?? '').trim();
                final tipoRaw = (config['tipo_cuenta']?.toString() ?? '').toLowerCase();
                final bancoRaw = (config['banco_nombre']?.toString() ?? '').toLowerCase();
                metodoRecaudo = metodoRaw.isNotEmpty
                    ? metodoRaw
                    : ((tipoRaw == 'nequi' || bancoRaw == 'nequi')
                        ? 'nequi'
                        : 'cuenta_bancaria');

                bancoController.text = config['banco_nombre']?.toString() ?? '';
                cuentaController.text = config['numero_cuenta']?.toString() ?? '';
                titularController.text = config['titular_cuenta']?.toString() ?? '';
                tipoController.text = config['tipo_cuenta']?.toString() ?? '';
                documentoController.text = config['documento_titular']?.toString() ?? '';
                referenciaController.text = config['referencia_transferencia']?.toString() ?? '';

                final codigoConfig = config['banco_codigo']?.toString();
                if (banks.isNotEmpty) {
                  final candidates = banks.where((b) {
                    final byCode = codigoConfig != null && codigoConfig.isNotEmpty && b['codigo'] == codigoConfig;
                    final byName = (b['nombre'] ?? '').toLowerCase() == bancoController.text.trim().toLowerCase();
                    return byCode || byName;
                  }).toList();
                  selectedBank = candidates.isNotEmpty ? candidates.first : null;
                }
              }

              if (ctx.mounted) {
                setSheetState(() => isLoadingConfig = false);
              }
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, controller) => Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Cuenta bancaria de la plataforma',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            Theme.of(ctx).colorScheme.onSurface,
                      )),
                  const SizedBox(height: 6),
                  Text(
                    'Las empresas verán estos datos para pagar a la plataforma',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 24),

                  if (isLoadingConfig)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    Text(
                      'Método de recaudo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(ctx).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'cuenta_bancaria',
                          label: Text('Cuenta bancaria'),
                          icon: Icon(Icons.account_balance_rounded),
                        ),
                        ButtonSegment<String>(
                          value: 'nequi',
                          label: Text('Nequi'),
                          icon: Icon(Icons.phone_android_rounded),
                        ),
                      ],
                      selected: <String>{metodoRecaudo},
                      onSelectionChanged: (selection) {
                        setSheetState(() {
                          metodoRecaudo = selection.first;
                          if (metodoRecaudo == 'nequi') {
                            bancoController.text = 'Nequi';
                            if (tipoController.text.trim().isEmpty) {
                              tipoController.text = 'nequi';
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    if (metodoRecaudo == 'cuenta_bancaria') ...[
                      if (isLoadingBanks)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: LinearProgressIndicator(minHeight: 3),
                        )
                      else if (banks.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: DropdownButtonFormField<String>(
                            value: selectedBank?['codigo'],
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Banco',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            items: banks
                                .map((b) => DropdownMenuItem<String>(
                                      value: b['codigo'],
                                      child: Text(b['nombre'] ?? ''),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              final candidates = banks.where((b) => b['codigo'] == value).toList();
                              final match = candidates.isNotEmpty ? candidates.first : null;
                              setSheetState(() {
                                selectedBank = match;
                                bancoController.text = match?['nombre'] ?? '';
                              });
                            },
                          ),
                        )
                      else
                        _buildConfigField('Banco', bancoController, 'Nombre del banco'),
                      _buildConfigField('Tipo de cuenta',
                          tipoController, 'Ahorros / Corriente'),
                      _buildConfigField('Número de cuenta',
                          cuentaController, 'Ej: 123-456-789'),
                    ] else ...[
                      _buildConfigField(
                          'Número de Nequi', cuentaController, 'Ej: 3001234567'),
                    ],
                    _buildConfigField('Titular',
                        titularController, 'Nombre del titular'),
                    _buildConfigField('Documento titular',
                        documentoController, 'CC / NIT'),
                    _buildConfigField('Referencia transferencia',
                        referenciaController,
                        'Código o referencia (opcional)'),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isSaving
                            ? null
                            : () async {
                            final cuentaValue = cuentaController.text.trim();
                            final titularValue = titularController.text.trim();
                            final bancoValue = bancoController.text.trim();
                            final tipoValue = tipoController.text.trim();

                            final missingBankFields = metodoRecaudo == 'cuenta_bancaria' &&
                              (bancoValue.isEmpty || tipoValue.isEmpty || cuentaValue.isEmpty || titularValue.isEmpty);
                            final missingNequiFields = metodoRecaudo == 'nequi' &&
                              (cuentaValue.isEmpty || titularValue.isEmpty);

                            if (missingBankFields || missingNequiFields) {
                                    CustomSnackbar.show(ctx,
                                      message:
                                  metodoRecaudo == 'nequi'
                                    ? 'Número de Nequi y titular son obligatorios'
                                    : 'Banco, tipo de cuenta, número de cuenta y titular son obligatorios',
                                      type: SnackbarType.warning);
                                  return;
                                }
                                setSheetState(
                                    () => isSaving = true);
                                final result =
                                    await AdminCompanyCommissionsService
                                        .updateBankConfig(
                                  adminId: widget.adminId,
                                    metodoRecaudo: metodoRecaudo,
                                  bancoNombre: metodoRecaudo == 'nequi'
                                    ? 'Nequi'
                                    : bancoValue,
                                  numeroCuenta: cuentaValue,
                                  titularCuenta: titularValue,
                                  tipoCuenta: metodoRecaudo == 'nequi'
                                    ? 'nequi'
                                    : tipoValue,
                                    bancoCodigo: metodoRecaudo == 'nequi'
                                      ? 'NEQUI'
                                      : (selectedBank?['codigo'] ?? ''),
                                  documentoTitular:
                                      documentoController.text.trim(),
                                  referencia:
                                      referenciaController.text
                                          .trim(),
                                );
                                setSheetState(
                                    () => isSaving = false);

                                if (result['success'] == true) {
                                  if (ctx.mounted) {
                                    CustomSnackbar.show(ctx,
                                        message:
                                            'Cuenta actualizada',
                                        type:
                                            SnackbarType.success);
                                    Navigator.of(ctx).pop();
                                  }
                                } else {
                                  if (ctx.mounted) {
                                    CustomSnackbar.show(ctx,
                                        message:
                                            result['message'] ??
                                                'Error',
                                        type:
                                            SnackbarType.error);
                                  }
                                }
                              },
                        icon: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.save_rounded),
                        label: Text(isSaving
                            ? 'Guardando...'
                            : 'Guardar cuenta'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConfigField(
      String label, TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ════════════════════════════════════════
  // Widgets compartidos
  // ════════════════════════════════════════
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
        color:
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_rounded,
                size: 38, color: Colors.grey.withValues(alpha: 0.55)),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.grey.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
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
        ...List.generate(
          4,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 70,
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
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(_error ?? 'Error desconocido'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _loadTabData(_tabController.index),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
