import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/features/conductor/presentation/widgets/document_upload_widget.dart';
import 'package:viax/src/features/conductor/services/debt_payment_service.dart';
import 'package:viax/src/features/user/presentation/widgets/trip_preview/trip_price_formatter.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_area.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

class ConductorDebtPaymentScreen extends StatefulWidget {
  final int conductorId;
  final Map<String, dynamic> contextData;

  const ConductorDebtPaymentScreen({
    super.key,
    required this.conductorId,
    required this.contextData,
  });

  @override
  State<ConductorDebtPaymentScreen> createState() => _ConductorDebtPaymentScreenState();
}

class _ConductorDebtPaymentScreenState extends State<ConductorDebtPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();
  File? _comprobanteFile;
  bool _isSubmitting = false;
  bool _isFormattingMonto = false;
  bool _isLoadingDebt = false;
  double _resolvedDebt = 0;

  @override
  void initState() {
    super.initState();
    _resolvedDebt =
        double.tryParse(widget.contextData['deuda_actual']?.toString() ?? '0') ?? 0;
    _prefillAmountWithDebt(_resolvedDebt);
    _montoController.addListener(_formatMontoAsCop);
    _refreshResolvedDebt();
  }

  @override
  void dispose() {
    _montoController.removeListener(_formatMontoAsCop);
    _montoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  void _formatMontoAsCop() {
    if (_isFormattingMonto) return;
    final rawDigits = _montoController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (rawDigits.isEmpty) {
      return;
    }

    final value = double.tryParse(rawDigits) ?? 0;
    final formatted = formatCurrency(value, withSymbol: false);

    if (_montoController.text == formatted) return;

    _isFormattingMonto = true;
    _montoController.value = _montoController.value.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
    _isFormattingMonto = false;
  }

  double _parseMontoCop() {
    final rawDigits = _montoController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(rawDigits) ?? 0;
  }

  void _prefillAmountWithDebt(double debt) {
    if (debt <= 0) return;
    final current = _parseMontoCop();
    if (current > 0) return;
    _montoController.text = formatCurrency(debt, withSymbol: false);
  }

  Future<double> _fetchDebtFromTransactions() async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/company/get_conductor_transactions.php?conductor_id=${widget.conductorId}',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) return 0;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final rows = List<Map<String, dynamic>>.from(data['data'] ?? []);

      double totalCargos = 0;
      double totalAbonos = 0;

      for (final item in rows) {
        final monto = double.tryParse(item['monto']?.toString() ?? '0') ?? 0;
        final tipo = item['tipo']?.toString() ?? '';
        if (tipo == 'cargo') {
          totalCargos += monto;
        } else if (tipo == 'abono') {
          totalAbonos += monto;
        }
      }

      return (totalCargos - totalAbonos).clamp(0, double.infinity).toDouble();
    } catch (_) {
      return 0;
    }
  }

  Future<void> _refreshResolvedDebt() async {
    setState(() => _isLoadingDebt = true);
    try {
      final contextResponse = await DebtPaymentService.getContext(
        conductorId: widget.conductorId,
      );

      final debtFromPassed =
          double.tryParse(widget.contextData['deuda_actual']?.toString() ?? '0') ?? 0;
      final debtFromContext = double.tryParse(
            ((contextResponse['data'] as Map<String, dynamic>?)?['deuda_actual'])
                    ?.toString() ??
                '0',
          ) ??
          0;
      final debtFromTransactions = await _fetchDebtFromTransactions();

      double resolved = debtFromPassed;
      if (debtFromContext > resolved) resolved = debtFromContext;
      if (debtFromTransactions > resolved) resolved = debtFromTransactions;

      if (!mounted) return;
      setState(() => _resolvedDebt = resolved);
      _prefillAmountWithDebt(resolved);
    } finally {
      if (mounted) {
        setState(() => _isLoadingDebt = false);
      }
    }
  }

  Future<void> _pickProof() async {
    final path = await DocumentPickerHelper.pickDocument(
      context: context,
      documentType: DocumentType.any,
      allowGallery: true,
    );

    if (path == null || path.isEmpty) return;

    setState(() {
      _comprobanteFile = File(path);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final monto = _parseMontoCop();
    if (monto <= 0) {
      CustomSnackbar.showError(context, message: 'Ingresa un monto válido');
      return;
    }

    if (_comprobanteFile == null) {
      CustomSnackbar.showError(context, message: 'Debes adjuntar el comprobante');
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await DebtPaymentService.submitPaymentProof(
      conductorId: widget.conductorId,
      monto: monto,
      comprobante: _comprobanteFile!,
      observaciones: _observacionesController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      CustomSnackbar.showSuccess(context, message: result['message']?.toString() ?? 'Comprobante enviado');
      Navigator.pop(context, true);
      return;
    }

    CustomSnackbar.showError(context, message: result['message']?.toString() ?? 'No se pudo enviar el comprobante');
  }

  bool _isImageFile(File file) {
    final path = file.path.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
      path.endsWith('.heic') ||
      path.endsWith('.heif') ||
      path.endsWith('.jfif');
  }

  String _fileName(File file) => file.path.split(Platform.pathSeparator).last;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  void _showImagePreview(File file) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Container(
                color: Colors.black,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.file(file, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransferCard(
    bool isDark,
    String companyName,
    String banco,
    String tipoCuenta,
    String numeroCuenta,
    String titular,
    String documento,
    String referencia,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.primary.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.darkShadow : AppColors.lightShadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Transferir a $companyName',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Banco', banco, isDark),
          _buildInfoRow('Tipo de cuenta', tipoCuenta, isDark),
          _buildInfoRow('Número de cuenta', numeroCuenta, isDark),
          _buildInfoRow('Titular', titular, isDark),
          _buildInfoRow('Documento titular', documento, isDark),
          if (referencia.isNotEmpty) _buildInfoRow('Referencia', referencia, isDark),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtSummaryCard(bool isDark) {
    final deuda = _resolvedDebt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: deuda > 0
              ? Colors.orange.withValues(alpha: 0.35)
              : AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: deuda > 0
                  ? Colors.orange.withValues(alpha: 0.12)
                  : AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              deuda > 0 ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
              color: deuda > 0 ? Colors.orange : AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deuda pendiente con la empresa',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isLoadingDebt ? 'Calculando...' : formatCurrency(deuda),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: deuda > 0 ? Colors.orange : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required bool isDark,
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProofSection(bool isDark) {
    if (_comprobanteFile == null) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isSubmitting ? null : _pickProof,
          icon: const Icon(Icons.attach_file_rounded),
          label: const Text('Adjuntar comprobante (cámara, galería o archivo)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    }

    final file = _comprobanteFile!;
    final isImage = _isImageFile(file);
    final fileSize = file.existsSync() ? _formatFileSize(file.lengthSync()) : '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImage)
            GestureDetector(
              onTap: () => _showImagePreview(file),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  file,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _fileName(file),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Text(
            _fileName(file),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            fileSize,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _pickProof,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Cambiar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                            _comprobanteFile = null;
                          }),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Quitar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cuenta = (widget.contextData['cuenta_transferencia'] as Map<String, dynamic>?) ?? {};
    final empresa = (widget.contextData['empresa'] as Map<String, dynamic>?) ?? {};

    final banco = cuenta['banco_nombre']?.toString() ?? '-';
    final tipoCuenta = cuenta['tipo_cuenta']?.toString() ?? '-';
    final numeroCuenta = cuenta['numero_cuenta']?.toString() ?? '-';
    final titular = cuenta['titular_cuenta']?.toString() ?? '-';
    final documento = cuenta['documento_titular']?.toString() ?? '-';
    final referencia = cuenta['referencia_transferencia']?.toString() ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Pagar deuda'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDebtSummaryCard(isDark),
              const SizedBox(height: 14),
              _buildSectionTitle(
                isDark: isDark,
                icon: Icons.account_balance_rounded,
                title: 'Datos de transferencia',
                subtitle: 'Usa esta cuenta para realizar el pago',
              ),
              const SizedBox(height: 10),
              _buildTransferCard(
                isDark,
                empresa['nombre']?.toString() ?? 'empresa',
                banco,
                tipoCuenta,
                numeroCuenta,
                titular,
                documento,
                referencia,
              ),
              const SizedBox(height: 16),
              _buildSectionTitle(
                isDark: isDark,
                icon: Icons.payments_rounded,
                title: 'Registrar monto pagado',
              ),
              const SizedBox(height: 10),
              AuthTextField(
                controller: _montoController,
                label: 'Monto transferido (COP)',
                icon: Icons.payments_rounded,
                keyboardType: TextInputType.number,
                hintText: 'Ej: 12.500',
                helperText: 'Formato COP con punto de miles (ej: 12.500).',
                validator: (value) {
                  final monto = _parseMontoCop();
                  if (monto <= 0) return 'Ingresa un monto válido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AuthTextArea(
                controller: _observacionesController,
                label: 'Observaciones (opcional)',
                icon: Icons.notes_rounded,
                helperText: 'Puedes agregar detalles de la transferencia.',
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              _buildSectionTitle(
                isDark: isDark,
                icon: Icons.attachment_rounded,
                title: 'Comprobante de pago',
                subtitle: 'Adjunta imagen o archivo de la transferencia',
              ),
              const SizedBox(height: 10),
              _buildProofSection(isDark),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text(_isSubmitting ? 'Enviando...' : 'Enviar comprobante'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
