import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../logic/search_controller.dart';
import '../../../models/note.dart';
import '../../../theme/quire_theme.dart';
import '../../common/context_menus.dart';
import 'hover_icon.dart';

class NoteRow extends StatefulWidget {
  const NoteRow({
    super.key,
    required this.note,
    required this.selected,
    required this.onTap,
    required this.onDelete,
    required this.pinned,
    required this.onTogglePin,
  });

  final Note note;
  final bool selected;
  final bool pinned;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  @override
  State<NoteRow> createState() => _NoteRowState();
}

class _NoteRowState extends State<NoteRow> {
  bool _hover = false;

  ContextMenu<Object?> get _menu => quireMenu([
    menuItem('Open', value: 'open', icon: Icons.description_outlined),
    menuItem(
      widget.pinned ? 'Unpin' : 'Pin',
      value: 'pin',
      icon: widget.pinned ? Icons.push_pin : Icons.push_pin_outlined,
    ),
    menuDivider,
    menuItem('Delete', value: 'delete', icon: Icons.delete_outline, shortcut: deleteActivator),
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snip = snippetOf(widget.note.body);
    return QuireContextMenuRegion(
      menu: _menu,
      onItemSelected: (value) {
        if (value == 'open') widget.onTap();
        if (value == 'pin') widget.onTogglePin();
        if (value == 'delete') widget.onDelete();
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          color: widget.selected
              ? theme.colorScheme.secondaryContainer
              : _hover
              ? theme.colorScheme.surfaceContainerLowest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(QuireRadius.l),
          child: InkWell(
            borderRadius: BorderRadius.circular(QuireRadius.l),
            onTap: widget.onTap,
            child: Container(
              decoration: widget.selected
                  ? null
                  : _hover
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(QuireRadius.l),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    )
                  : null,
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.note.title.isEmpty ? 'Untitled' : widget.note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 14,
                            fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w600,
                            height: 20 / 14,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (snip.isNotEmpty)
                          Text(
                            snip,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              height: 16 / 12.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        else
                          Text(
                            'No additional text',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              height: 16 / 12.5,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        if (widget.note.tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final t in widget.note.tags.take(3))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '#$t',
                                    style: GoogleFonts.splineSansMono(
                                      fontSize: 10.5,
                                      letterSpacing: 0.3,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              if (widget.note.tags.length > 3)
                                Text(
                                  '+${widget.note.tags.length - 3}',
                                  style: GoogleFonts.splineSansMono(
                                    fontSize: 10.5,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        clockLabel(widget.note.updatedAt ?? DateTime.now()),
                        style: GoogleFonts.splineSansMono(
                          fontSize: 11,
                          letterSpacing: 0.3,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      // Hover actions
                      AnimatedOpacity(
                        opacity: _hover || widget.selected ? 1 : 0,
                        duration: const Duration(milliseconds: 120),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HoverIcon(
                                key: Key('row-pin-${Uri.encodeComponent(widget.note.path)}'),
                                icon: widget.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                                color: widget.pinned ? theme.colorScheme.primary : null,
                                onTap: widget.onTogglePin,
                                tooltip: widget.pinned ? 'Unpin' : 'Pin',
                              ),
                              const SizedBox(width: 4),
                              HoverIcon(
                                icon: Icons.delete_outline,
                                onTap: widget.onDelete,
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
