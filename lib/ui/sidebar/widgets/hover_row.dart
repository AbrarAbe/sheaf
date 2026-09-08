import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/quire_theme.dart';

/// Quick filters, folder tree, tags, and trash — the leftmost pane.
/// The desk drawer: quiet until touched, tint and weight do the talking.

class HoverRow extends StatefulWidget {
  const HoverRow({
    super.key,
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.label,
  });
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String label;

  @override
  State<HoverRow> createState() => HoverRowState();
}

class HoverRowState extends State<HoverRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: widget.selected
            ? theme.colorScheme.secondaryContainer
            : _hover
            ? theme.colorScheme.surfaceContainerLowest
            : Colors.transparent,
        borderRadius: BorderRadius.circular(QuireRadius.m),
        child: InkWell(
          borderRadius: BorderRadius.circular(QuireRadius.m),
          onTap: widget.onTap,
          child: Container(
            decoration: widget.selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(QuireRadius.l),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.0),
                    ),
                  )
                : _hover
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(QuireRadius.l),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 1),
                    ),
                  )
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(QuireRadius.l),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.0),
                    ),
                  ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 18,
                  color: widget.selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13.5,
                      fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                      height: 20 / 13.5,
                      color: theme.colorScheme.onSurface,
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
}
