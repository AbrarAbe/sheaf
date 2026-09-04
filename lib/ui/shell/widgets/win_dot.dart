import 'package:flutter/material.dart';

/// The desktop shell: sidebar | note list | editor, folding through the three
/// window tiers of layout-and-space.md. Owns the editor controller and keeps
/// it in sync with the selected note.

class WinDot extends StatefulWidget {
  const WinDot({
    super.key,
    required this.color,
    required this.glyph,
    required this.tooltip,
    required this.onTap,
  });

  final Color color;
  final IconData glyph;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<WinDot> createState() => _WinDotState();
}

class _WinDotState extends State<WinDot> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onTap,
          child: SizedBox(
            width: 18,
            height: 28,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: _hover ? 13 : 11,
                height: _hover ? 13 : 11,
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                child: AnimatedOpacity(
                  opacity: _hover ? 1 : 0,
                  duration: const Duration(milliseconds: 100),
                  child: FittedBox(
                    child: Icon(widget.glyph, size: 8, color: Colors.black.withValues(alpha: .55)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
