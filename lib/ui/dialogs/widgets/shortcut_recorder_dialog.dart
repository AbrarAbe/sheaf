import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../logic/shortcut_serializer.dart';
import '../../../logic/vault_controller.dart';
import '../../../models/shortcut_settings.dart';

class ShortcutRecorderDialog extends StatefulWidget {
  const ShortcutRecorderDialog({
    super.key,
    required this.action,
    required this.controller,
  });
  final ShortcutAction action;
  final VaultController controller;
  @override
  State<ShortcutRecorderDialog> createState() => ShortcutRecorderDialogState();
}

class ShortcutRecorderDialogState extends State<ShortcutRecorderDialog> {
  SingleActivator? _captured;
  String? _error;

  bool _isModifier(LogicalKeyboardKey key) => {
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  }.contains(key);

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (_isModifier(key)) return;
    final control = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    final activator = SingleActivator(
      key,
      control: control,
      shift: shift,
      alt: alt,
      meta: meta,
    );
    final label = serializeActivator(activator);
    String? error;
    if (reservedFormattingLabels.contains(label)) {
      error = 'Reserved for formatting';
    } else if (const {'Ctrl+C', 'Ctrl+V', 'Ctrl+X'}.contains(label)) {
      error = 'Reserved system shortcut';
    } else {
      final overrides = widget.controller.settings.shortcutOverrides;
      for (final other in ShortcutAction.values) {
        if (other == widget.action) continue;
        if (other == ShortcutAction.continueList) continue;
        final otherAct = activatorFor(other, overrides);
        if (serializeActivator(otherAct) == label) {
          error = 'Already used by ${other.label}';
          break;
        }
      }
    }
    setState(() {
      _captured = activator;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentLabel = serializeActivator(
      activatorFor(widget.action, widget.controller.settings.shortcutOverrides),
    );
    final capturedLabel = _captured == null
        ? 'Press new shortcut…'
        : serializeActivator(_captured!);
    return AlertDialog(
      title: Text('Edit ${widget.action.label}'),
      content: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          _handleKey(event);
          return KeyEventResult.handled;
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current: $currentLabel',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _error != null ? Colors.red : Colors.transparent,
                ),
              ),
              child: Text(
                capturedLabel,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Press keys, then Save. Single chord only.',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _captured == null || _error != null
              ? null
              : () async {
                  await widget.controller.setShortcutOverride(
                    widget.action,
                    _captured,
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
