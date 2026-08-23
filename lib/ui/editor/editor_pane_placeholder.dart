import 'package:flutter/material.dart';

/// Editor pane placeholder — replaced by the real editor slice in Task 10.
class EditorPanePlaceholder extends StatelessWidget {
  const EditorPanePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Select a note',
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
