import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/features/conductor/presentation/widgets/document_upload_widget.dart';
import 'package:viax/src/features/company/services/company_platform_payment_service.dart';
import 'package:viax/src/features/user/presentation/widgets/trip_preview/trip_price_formatter.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_area.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

/// Pantalla para que la empresa pague su deuda con la plataforma (admin).
/// Replica el flujo de ConductorDebtPaymentScreen pero para empresa→admin.
class CompanyPlatformPaymentScreen extends StatefulWidget {
  final int empresaId;
  final int userId;
  final Map<String, dynamic> contextData;

  const CompanyPlatformPaymentScreen({
    super.key,
    required this.empresaId,
    required this.userId,
    required this.contextData,
  });

  @override
  State<CompanyPlatformPaymentScreen> createState() =>
      _CompanyPlatformPaymentScreenState();
}

class _CompanyPlatformPaymentScreenState
    extends State<CompanyPlatformPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _observacionesController =
      TextEditingController();
  File? _comprobanteFile;
  bool _isSubmitting = false;
  bool _isFormattingMonto = false;
  bool _isLoadingDebt = false;
  double _resolvedDebt = 0;

  @override
  void initState() {
    super.initState();
    _resolvedDebt = double.tryParse(
            widget.contextData['deuda_actual']?.toString() ?? '0') ??
        0;
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

  // ─── Formato COP ───
  void _formatMontoAsCop() {
    if (_isFormattingMonto) return;
    final rawDigits =
        _montoController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (rawDigits.isEmpty) return;

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
    final rawDigits =
        _montoController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(rawDigits) ?? 0;
  }

  void _prefillAmountWithDebt(double debt) {
    if (debt <= 0) return;
    final formatted = formatCurrency(debt, withSymbol: false);
    _isFormattingMonto = true;
    _montoController.text = formatted;
    _isFormattingMonto = false;
  }

  // ─── Resolver deuda desde servidor ───
  Future<void> _refreshResolvedDebt() async {
    setState(() => _isLoadingDebt = true);
    try {
      final result = await CompanyPlatformPaymentService.getDebtContext(
        empresaId: widget.empresaId,
      );

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>? ?? {};
        final serverDebt =
            double.tryParse(data['deuda_actual']?.toString() ?? '0') ?? 0;
        if (serverDebt > _resolvedDebt) {
          _resolvedDebt = serverDebt;
        }
        if (_resolvedDebt > 0 && _parseMontoCop() <= 0) {
          _prefillAmountWithDebt(_resolvedDebt);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingDebt = false);
  }

  // ─── Enviar comprobante ───
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_comprobanteFile == null) {
      CustomSnackBar.show(
        context,
        message: 'Adjunta un comprobante de pago',
        type: SnackBarType.warning,
      );
      return;
    }

    final monto = _parseMontoCop();
    if (monto <= 0) {
      CustomSnackBar.show(
        context,
        message: 'Ingresa un monto válido',
        type: SnackBarType.warning,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result =
          await CompanyPlatformPaymentService.submitPaymentProof(
        empresaId: widget.empresaId,
        userId: widget.userId,
        monto: monto,
        comprobante: _comprobanteFile!,
        observaciones: _observacionesController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        CustomSnackBar.show(
          context,
          message: 'Comprobante enviado correctamente',
          type: SnackBarType.success,
        );
        Navigator.of(context).pop(true);
      } else {
        CustomSnackBar.show(
          context,
          message: result['message'] ?? 'Error al enviar',
          type: SnackBarType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Error: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cuentaTransferencia =
        widget.contextData['cuenta_transferencia'] as Map<String, dynamic>? ??
            {};
    final hasCuenta = cuentaTransferencia['configurada'] == true;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Pagar deuda plataforma'),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.lightTextPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Resumen de deuda ───
              _buildDebtSummaryCard(isDark),
              const SizedBox(height: 20),

              // ─── Cuenta destino ───
              if (hasCuenta) ...[
                _buildSectionTitle('Cuenta de transferencia', isDark),
                const SizedBox(height: 8),
                _buildTransferAccountCard(cuentaTransferencia, isDark),
                const SizedBox(height: 20),
              ],

              // ─── Monto ───
              _buildSectionTitle('Monto a pagar', isDark),
              const SizedBox(height: 8),
              AuthTextField(
                controller: _montoController,
                labelText: 'Monto (COP)',
                hintText: 'Ej: 150.000',
                prefixIcon: Icons.attach_money,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return 'Ingresa el monto';
                  if (_parseMontoCop() <= 0) return 'El monto debe ser mayor a 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ─── Comprobante ───
              _buildSectionTitle('Comprobante de pago', isDark),
              const SizedBox(height: 8),
              DocumentUploadWidget(
                label: 'Adjuntar comprobante',
                description: 'Foto o PDF del comprobante de transferencia',
                onFileSelected: (file) {
                  setState(() => _comprobanteFile = file);
                },
                selectedFile: _comprobanteFile,
              ),
              const SizedBox(height: 16),

              // ─── Observaciones ───
              _buildSectionTitle('Observaciones (opcional)', isDark),
              const SizedBox(height: 8),
              AuthTextArea(
                controller: _observacionesController,
                labelText: 'Notas adicionales',
                hintText: 'Referencia de transferencia, detalles...',
                maxLines: 3,
              ),
              const SizedBox(height: 30),

              // ─── Botón enviar ───
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ))
                      : const Icon(Icons.send_rounded),
                  label: Text(_isSubmitting ? 'Enviando...' : 'Enviar comprobante'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tarjeta de resumen de deuda ───
  Widget _buildDebtSummaryCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                'Deuda con la plataforma',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_isLoadingDebt) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white54,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatCurrency(_resolvedDebt),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Comisión: ${widget.contextData['comision_porcentaje'] ?? 0}%',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tarjeta de cuenta de transferencia ───
  Widget _buildTransferAccountCard(
      Map<String, dynamic> cuenta, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Banco', cuenta['banco_nombre'] ?? '-', isDark),
          _buildInfoRow('Tipo', cuenta['tipo_cuenta'] ?? '-', isDark),
          _buildInfoRow('Cuenta', cuenta['numero_cuenta'] ?? '-', isDark),
          _buildInfoRow('Titular', cuenta['titular_cuenta'] ?? '-', isDark),
          if ((cuenta['documento_titular'] ?? '').toString().isNotEmpty)
            _buildInfoRow(
                'Documento', cuenta['documento_titular'], isDark),
          if ((cuenta['referencia_transferencia'] ?? '').toString().isNotEmpty)
            _buildInfoRow(
                'Referencia', cuenta['referencia_transferencia'], isDark),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }
}
