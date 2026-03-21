import 'package:flutter/material.dart';

import '../../global/services/user_block_service.dart';

class UserBlockActionButton extends StatefulWidget {
  final int actorId;
  final int otherUserId;
  final int? solicitudId;
  final String targetLabel;

  const UserBlockActionButton({
    super.key,
    required this.actorId,
    required this.otherUserId,
    required this.targetLabel,
    this.solicitudId,
  });

  @override
  State<UserBlockActionButton> createState() => _UserBlockActionButtonState();
}

class _UserBlockActionButtonState extends State<UserBlockActionButton> {
  UserBlockState? _blockState;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBlockState();
  }

  Future<void> _loadBlockState() async {
    try {
      final state = await UserBlockService.getBlockState(
        actorId: widget.actorId,
        otherUserId: widget.otherUserId,
      );
      if (!mounted) return;
      setState(() => _blockState = state);
    } catch (_) {
      // Si falla la carga inicial, el botón sigue disponible y reintenta al presionar.
    }
  }

  Future<void> _toggleBlockState() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      var currentState = _blockState;
      if (currentState == null) {
        currentState = await UserBlockService.getBlockState(
          actorId: widget.actorId,
          otherUserId: widget.otherUserId,
        );
      }

      final isBlockedByMe = currentState.blockedByMe;
      final action = isBlockedByMe ? 'desbloquear' : 'bloquear';

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            '${isBlockedByMe ? 'Desbloquear' : 'Bloquear'} ${widget.targetLabel}',
          ),
          content: Text(
            isBlockedByMe
                ? '¿Deseas desbloquear a este ${widget.targetLabel} para permitir futuras coincidencias?'
                : '¿Deseas bloquear a este ${widget.targetLabel}? No volverán a emparejarse en viajes futuros.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action[0].toUpperCase() + action.substring(1)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final nextState = isBlockedByMe
          ? await UserBlockService.unblockUser(
              actorId: widget.actorId,
              blockedUserId: widget.otherUserId,
            )
          : await UserBlockService.blockUser(
              actorId: widget.actorId,
              blockedUserId: widget.otherUserId,
              solicitudId: widget.solicitudId,
            );

      if (!mounted) return;
      setState(() => _blockState = nextState);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBlockedByMe
                ? '${widget.targetLabel[0].toUpperCase()}${widget.targetLabel.substring(1)} desbloqueado correctamente.'
                : '${widget.targetLabel[0].toUpperCase()}${widget.targetLabel.substring(1)} bloqueado correctamente.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UserBlockService.friendlyFromError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBlockedByMe = _blockState?.blockedByMe == true;
    final label = isBlockedByMe
        ? 'Desbloquear ${widget.targetLabel}'
        : 'Bloquear ${widget.targetLabel}';

    return OutlinedButton.icon(
      onPressed: _isLoading ? null : _toggleBlockState,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              isBlockedByMe ? Icons.lock_open_rounded : Icons.block_rounded,
            ),
      label: Text(label),
    );
  }
}