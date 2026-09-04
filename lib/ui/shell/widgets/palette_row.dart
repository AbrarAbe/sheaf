import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../models/note.dart';

class PaletteRow extends StatelessWidget {
  const PaletteRow({
    super.key,
    required this.note,
    required this.selected,
    required this.onTap,
    required this.onHover,
  });

  final Note note;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folder = note.path.contains('/')
        ? note.path.substring(0, note.path.lastIndexOf('/'))
        : null;
    final updated = note.updatedAt;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        // Our own background carries the highlight; ripple/hover washes
        // double-paint it and read as flicker while arrowing through rows.
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.surfaceContainerHighest : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 16,
                color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  note.title.isEmpty ? 'Untitled' : note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (folder != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    folder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.splineSansMono(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .85),
                    ),
                  ),
                ),
              if (updated != null)
                Text(
                  DateFormat.MMMd().format(updated),
                  style: GoogleFonts.splineSansMono(
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
