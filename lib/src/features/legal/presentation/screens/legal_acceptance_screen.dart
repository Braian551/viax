import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/legal/providers/legal_provider.dart';
import 'package:viax/src/features/legal/services/legal_content_service.dart';
import 'package:viax/src/global/services/legal/legal_links_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/shared/widgets/global_overlay_message.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:viax/src/theme/app_colors.dart';

class LegalAcceptanceScreen extends StatefulWidget {
  final String role;
  final int? userId;
  final String version;
  final bool returnResultOnAccept;
  final bool isBlocking;

  const LegalAcceptanceScreen({
    super.key,
    required this.role, 
    required this.version,
    this.userId,
    this.returnResultOnAccept = false,
    this.isBlocking = true,
  });

  @override
  State<LegalAcceptanceScreen> createState() => _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends State<LegalAcceptanceScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasReadToBottom = false;
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _isSubmitting = false;
  bool _isLoadingDocuments = true;

  String _termsText = '';
  String _privacyText = '';
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadLegalDocuments();
  }

  Future<void> _loadLegalDocuments() async {
    setState(() {
      _isLoadingDocuments = true;
      _loadError = null;
    });

    try {
      final role = LegalLinksService.fromString(widget.role);
      final terms = await LegalContentService.fetchTerms(role: role);
      final privacy = await LegalContentService.fetchPrivacy(role: role);

      if (!mounted) return;
      setState(() {
        _termsText = terms;
        _privacyText = privacy;
        _isLoadingDocuments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'No se pudieron cargar los documentos legales. Revisa tu conexion e intenta de nuevo.';
        _isLoadingDocuments = false;
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent && !_hasReadToBottom) {
      setState(() {
        _hasReadToBottom = true;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleAcceptance() async {
    setState(() => _isSubmitting = true);

    final userId = widget.userId ?? 0;
    bool success = true;

    if (userId > 0) {
      final legalProv = context.read<LegalProvider>();
      String deviceId = 'unknown_flutter_device';

      try {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
        } else if (Platform.isIOS) {
          IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor ?? 'ios_unknown';
        }
      } catch (_) {}

      success = await legalProv.acceptTerms(
        userId: userId,
        role: widget.role,
        deviceId: deviceId,
        version: widget.version,
      );
    }

    if (success && mounted) {
      if (widget.returnResultOnAccept) {
        Navigator.of(context).pop(true);
        return;
      }

      // Si es conductor, redirigir al Disclosure de Ubicación antes de entrar a la Home
      if (widget.role == 'conductor') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.backgroundLocationDisclosure,
          (route) => false,
        );
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.home,
          (route) => false,
        );
      }
    } else {
      if (mounted) {
        final legalProv = context.read<LegalProvider>();
        final backendMessage = legalProv.lastError?.trim();
        setState(() => _isSubmitting = false);
        GlobalOverlayMessage.showError(
          context,
          (backendMessage != null && backendMessage.isNotEmpty)
            ? backendMessage
            : 'Error al procesar la aceptación. Intenta de nuevo.',
        );
      }
    }
  }

  Widget _buildDocumentBlock({
    required String title,
    required String content,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        _buildStructuredContent(
          content,
          textColor: textColor,
          subtitleColor: subtitleColor,
        ),
      ],
    );
  }

  Widget _buildStructuredContent(
    String content, {
    required Color textColor,
    required Color subtitleColor,
  }) {
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final widgets = <Widget>[];

    for (final line in lines) {
      final isNumberedHeading = RegExp(r'^\d+\.\s+').hasMatch(line);
      final isBullet = line.startsWith('* ');
      final isDateLine = line.toLowerCase().startsWith('ultima actualizacion') ||
          line.toLowerCase().startsWith('última actualización');

      if (isNumberedHeading) {
        widgets.add(const SizedBox(height: 14));
        widgets.add(
          Text(
            line,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textColor,
              height: 1.35,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      if (isBullet) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    line.substring(2).trim(),
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            line,
            style: TextStyle(
              fontSize: isDateLine ? 13 : 14,
              color: isDateLine ? subtitleColor : textColor,
              fontStyle: isDateLine ? FontStyle.italic : FontStyle.normal,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkCard : Colors.white;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtitleColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Términos y Condiciones (${widget.version})'),
        automaticallyImplyLeading: !widget.isBlocking,
        centerTitle: true,
        backgroundColor: surfaceColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(bottom: BorderSide(color: subtitleColor.withValues(alpha: 0.2))),
              ),
              child: _isLoadingDocuments
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _loadError != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _loadError!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: subtitleColor),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadLegalDocuments,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Actualizamos nuestras políticas',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Para continuar en Viax debes revisar y aceptar los documentos legales vigentes para tu rol: ${widget.role}.',
                                  style: TextStyle(fontSize: 14, color: subtitleColor),
                                ),
                                const Divider(height: 32),
                                _buildDocumentBlock(
                                  title: 'TÉRMINOS Y CONDICIONES',
                                  content: _termsText,
                                  textColor: textColor,
                                  subtitleColor: subtitleColor,
                                ),
                                const SizedBox(height: 24),
                                _buildDocumentBlock(
                                  title: 'POLÍTICA DE PRIVACIDAD',
                                  content: _privacyText,
                                  textColor: textColor,
                                  subtitleColor: subtitleColor,
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_hasReadToBottom)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Por favor, desplázate hasta el final para habilitar la aceptación.',
                      style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                CheckboxListTile(
                  title: Text(
                    'He leído y acepto los Términos y Condiciones',
                    style: TextStyle(fontSize: 13, color: textColor),
                  ),
                  value: _acceptedTerms,
                  onChanged: _hasReadToBottom ? (val) => setState(() => _acceptedTerms = val ?? false) : null,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: Text(
                    'Acepto la Política de Tratamiento de Datos',
                    style: TextStyle(fontSize: 13, color: textColor),
                  ),
                  value: _acceptedPrivacy,
                  onChanged: _hasReadToBottom ? (val) => setState(() => _acceptedPrivacy = val ?? false) : null,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    onPressed: (_isLoadingDocuments || _loadError != null || !_acceptedTerms || !_acceptedPrivacy || _isSubmitting) 
                      ? null 
                      : _handleAcceptance,
                    child: _isSubmitting 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ACEPTAR Y CONTINUAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
