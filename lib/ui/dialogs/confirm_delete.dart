import 'package:flutter/material.dart';

/// Confirmation dialog before a destructive delete action.
///
/// Shows the item name and a warning. Returns `true` on confirm, `false` on
/// cancel / barrier-dismiss / Esc.
Future<bool> showConfirmDeleteDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  IconData? confirmIcon,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _ConfirmDeleteDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      confirmIcon: confirmIcon,
    ),
  ).then((result) => result ?? false);
}

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.confirmIcon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final IconData? confirmIcon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Icon(confirmIcon ?? Icons.delete_outline, size: 16, color: cs.error),
              Text(
                confirmLabel,
                style: TextStyle(color: cs.error, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
