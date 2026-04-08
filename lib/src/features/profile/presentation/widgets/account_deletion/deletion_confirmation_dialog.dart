import 'package:flutter/material.dart';

class DeletionConfirmationDialog extends StatelessWidget {
  const DeletionConfirmationDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DeletionConfirmationDialog(),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmar eliminación de cuenta'),
      content: const Text(
        'Esta acción iniciará un período de eliminación de 15 días. Durante ese tiempo podrás reactivar tu cuenta. ¿Deseas continuar?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
