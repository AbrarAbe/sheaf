import 'package:flutter/material.dart';

/// A draggable divider between panes. Hairline visual, generous hit target,
/// column-resize cursor — pointer behavior per layout-and-space.md.
class DragDivider extends StatelessWidget {
  const DragDivider({super.key, required this.onDrag});

  /// Called with the horizontal delta of the drag.
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hairline = theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: Center(child: Container(width: 1, color: hairline)),
      ),
    );
  }
}
