import 'package:material_ui/material_ui.dart';

/// A draggable divider between panes: a generous invisible hit strip with a
/// 1 px hairline centered in it, column-resize cursor per layout-and-space.md.
class DragDivider extends StatelessWidget {
  final bool? isEnd;
  const DragDivider({super.key, this.isEnd, required this.onDrag});

  /// Called with the horizontal delta of the drag.
  final ValueChanged<double> onDrag;

  /// Full hit-target width; design floor for pointer targets is 8 dp gaps,
  /// 12 dp gives a comfortable grab without eating pane space visually.
  static const hitWidth = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hairline = theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;
    // The end variant renders a thinner hairline (2 px) flush to the pane edge,
    // but keeps the same 12 dp invisible grab strip as the regular divider so
    // pointer targets never fall below the 12 dp accessibility floor.
    final bool end = isEnd == true;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: SizedBox(
          width: hitWidth,
          child: Row(
            mainAxisAlignment: end ? .end : .center,
            children: [VerticalDivider(width: end ? 2 : 1, color: hairline)],
          ),
        ),
      ),
    );
  }
}
