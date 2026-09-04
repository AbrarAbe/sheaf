import 'package:flutter/material.dart';

/// Wraps a scrollable with a scrollbar that shows a hand cursor on
/// thumb hover and grabbing while dragging. Hover/drag color is
/// driven by [ScrollbarThemeData.thumbColor] via WidgetState.
class HoverScrollbar extends StatefulWidget {
  const HoverScrollbar({super.key, required this.child});

  final Widget child;

  @override
  State<HoverScrollbar> createState() => _HoverScrollbarState();
}

class _HoverScrollbarState extends State<HoverScrollbar> {
  bool _hoveringThumb = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    // Use RawScrollbar to get thumb visibility callbacks via Notification?
    // Simpler: MouseRegion over the whole scrollable that switches cursor
    // when near the right edge (thumb area).
    return LayoutBuilder(
      builder: (context, constraints) {
        return MouseRegion(
          cursor: _dragging
              ? SystemMouseCursors.grabbing
              : _hoveringThumb
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          onHover: (e) {
            final nearEdge = e.localPosition.dx > constraints.maxWidth - 16;
            if (nearEdge != _hoveringThumb && !_dragging) {
              setState(() => _hoveringThumb = nearEdge);
            } else if (!nearEdge && _hoveringThumb) {
              setState(() => _hoveringThumb = false);
            }
          },
          onExit: (_) {
            if (_hoveringThumb) setState(() => _hoveringThumb = false);
          },
          child: Listener(
            onPointerDown: (_) {
              if (_hoveringThumb) setState(() => _dragging = true);
            },
            onPointerUp: (_) {
              if (_dragging) setState(() => _dragging = false);
            },
            child: RawScrollbar(
              thumbVisibility: false,
              thickness: 6,
              radius: const Radius.circular(4),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
