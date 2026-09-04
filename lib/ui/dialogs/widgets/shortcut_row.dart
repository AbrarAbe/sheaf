import 'package:flutter/material.dart';

import '../../../logic/shortcut_serializer.dart';
import '../../../logic/vault_controller.dart';
import '../../../models/shortcut_settings.dart';
import 'shortcut_recorder_dialog.dart';

class ShortcutRow extends StatelessWidget {
  const ShortcutRow({
    super.key,
    required this.action,
    required this.overrides,
    required this.controller,
  });

  final ShortcutAction action;
  final Map<String, String> overrides;
  final VaultController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverridden = overrides.containsKey(action.name);
    final activator = activatorFor(action, overrides);
    final label = serializeActivator(activator);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              action.label,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: isOverridden
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            key: Key('edit-${action.name}'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => ShortcutRecorderDialog(
                action: action,
                controller: controller,
              ),
            ),
            child: const Text('Edit', style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            key: Key('reset-${action.name}'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: isOverridden
                ? () => controller.setShortcutOverride(action, null)
                : null,
            child: const Text('Reset', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
