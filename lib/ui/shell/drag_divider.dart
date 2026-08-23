import 'package:flutter/material.dart';

/// A draggable divider between panes: a generous invisible hit strip with a
/// 1 px hairline centered in it, column-resize cursor per layout-and-space.md.
class DragDivider extends StatelessWidget {
  const DragDivider({super.key, required this.onDrag});

  /// Called with the horizontal delta of the drag.
  final ValueChanged<double> onDrag;

  /// Full hit-target width; design floor for pointer targets is 8 dp gaps,
  /// 12 dp gives a comfortable grab without eating pane space visually.
  static const hitWidth = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hairline = theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: SizedBox(
          width: hitWidth,
          child: Center(child: Container(width: 1, color: hairline)),
        ),
      ),
    );
  }
}
