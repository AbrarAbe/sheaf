import 'package:flutter/material.dart';

import '../../../models/settings.dart';
import '../../../theme/quire_theme.dart';

class ModeSwitch extends StatelessWidget {
  const ModeSwitch({super.key, required this.mode, required this.onSelected});

  final EditorMode mode;
  final ValueChanged<EditorMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget segment(
      EditorMode value,
      IconData icon,
      String label,
      String tooltip,
    ) {
      final selected = mode == value;
      return Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(QuireRadius.s),
          child: InkWell(
            key: Key('mode-${value.name}'),
            borderRadius: BorderRadius.circular(QuireRadius.s),
            onTap: () => onSelected(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: safeHanken(
                      TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(QuireRadius.s + 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(
            EditorMode.normal,
            Icons.notes_outlined,
            'Normal',
            'Word-like editing (Ctrl+Shift+M)',
          ),
          segment(
            EditorMode.markdown,
            Icons.code_outlined,
            'Markdown',
            'Raw markdown source',
          ),
          segment(
            EditorMode.preview,
            Icons.visibility_outlined,
            'Preview',
            'Rendered output',
          ),
        ],
      ),
    );
  }
}
