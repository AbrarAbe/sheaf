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
    // The end divider is deliberately narrower (6 dp) and flush to the pane edge
    // for a lighter boundary; the regular divider keeps the full 12 dp grab
    // strip. Each renders a hairline: 2 px at the end, 1 px centered otherwise.
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: SizedBox(
          width: isEnd == true ? 6 : hitWidth,
          child: Row(
            mainAxisAlignment: isEnd == true ? .end : .center,
            children: [VerticalDivider(width: isEnd == true ? 2 : 1, color: hairline)],
          ),
        ),
      ),
    );
  }
}
