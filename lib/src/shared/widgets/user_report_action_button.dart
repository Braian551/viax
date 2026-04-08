import 'package:flutter/material.dart';

import '../../global/services/user_report_service.dart';
import 'global_overlay_message.dart';

class UserReportActionButton extends StatefulWidget {
  final int reporterUserId;
  final int reportedUserId;
  final int? solicitudId;
  final String targetLabel;

  const UserReportActionButton({
    super.key,
    required this.reporterUserId,
    required this.reportedUserId,
    required this.targetLabel,
    this.solicitudId,
  });

  @override
  State<UserReportActionButton> createState() => _UserReportActionButtonState();
}

class _UserReportActionButtonState extends State<UserReportActionButton> {
  bool _isLoading = false;

  Future<void> _openReportDialog() async {
    if (_isLoading) return;

    final reasons = <String, String>{
      'comportamiento_inapropiado': 'Comportamiento inapropiado',
      'acoso_o_amenaza': 'Acoso o amenaza',
      'fraude_o_estafa': 'Fraude o estafa',
      'incumplimiento_servicio': 'Incumplimiento del servicio',
      'contenido_inapropiado_chat': 'Contenido inapropiado en chat',
      'otro': 'Otro',
    };

    String selectedReason = reasons.keys.first;
    final detailsController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text('Reportar ${widget.targetLabel}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tu reporte será revisado por el equipo de soporte y moderación.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: const InputDecoration(labelText: 'Motivo'),
                  items: reasons.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setModalState(() => selectedReason = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: detailsController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Detalles (opcional)',
                    hintText:
                        'Describe brevemente lo ocurrido para facilitar la revisión.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar reporte'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      detailsController.dispose();
      return;
    }

    setState(() => _isLoading = true);
    try {
      await UserReportService.reportUser(
        reporterUserId: widget.reporterUserId,
        reportedUserId: widget.reportedUserId,
        solicitudId: widget.solicitudId,
        motivo: selectedReason,
        descripcion: detailsController.text,
      );

      if (!mounted) return;
      GlobalOverlayMessage.showSuccess(
        context,
        'Reporte enviado correctamente. Gracias por ayudarnos a mejorar la seguridad.',
      );
    } catch (e) {
      if (!mounted) return;
      GlobalOverlayMessage.showError(
        context,
        UserReportService.friendlyFromError(e),
      );
    } finally {
      detailsController.dispose();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : _openReportDialog,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.flag_rounded),
      label: Text('Reportar ${widget.targetLabel}'),
    );
  }
}
