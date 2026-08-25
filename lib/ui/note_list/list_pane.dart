import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../logic/search_controller.dart';
import '../../logic/vault_controller.dart';
import '../../models/note.dart';
import '../../theme/quire_theme.dart';
import '../common/context_menus.dart';
import '../common/corner_toast.dart';

/// The note list pane: filter field, day-grouped compact rows, full keyboard
/// navigation (arrows move selection, Enter opens, Esc dismisses, Ctrl+F
/// focuses the filter).
class ListPane extends StatefulWidget {
  const ListPane({super.key, required this.controller, this.onCreateNote});

  final VaultController controller;

  /// Hook for the compose action; wired to the shared shell handler.
  final Future<Note?> Function()? onCreateNote;

  @override
  State<ListPane> createState() => _ListPaneState();
}

class _ListPaneState extends State<ListPane> {
  final _listFocus = FocusNode();
  final _rowKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _listFocus.requestFocus();
  }

  @override
  void dispose() {
    _listFocus.dispose();
    super.dispose();
  }

  /// Notes in current display order (scope-filtered, newest-first).
  List<Note> get _orderedNotes => widget.controller.visibleNotes.toList();

  /// Deletes [note] and offers an undo toast backed by the trash.
  Future<void> _deleteWithUndo(Note note) async {
    final controller = widget.controller;
    await controller.deleteNote(note.path);
    if (!mounted) return;
    final entries = await controller.trash();
    if (!mounted || entries.isEmpty) return;
    CornerToast.show(
      context,
      message: 'Deleted "${note.title}"',
      actionLabel: 'Undo',
      icon: Icons.delete_outline_rounded,
      onAction: () => controller.restoreFromTrash(entries.first.trashedName),
    );
  }

  ContextMenu<Object?> get _scaffoldMenu => quireMenu([
    menuItem(
      'New note',
      value: 'new-note',
      icon: Icons.note_add_outlined,
      shortcut: newNoteActivator,
    ),
  ]);

  /// Arrow-key navigation over the visible list; clamps at both ends.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final notes = _orderedNotes;
    if (notes.isEmpty) return KeyEventResult.ignored;

    final currentPath = widget.controller.selectedNotePath;
    var index = notes.indexWhere((n) => n.path == currentPath);

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        index = (index + 1).clamp(0, notes.length - 1);
      case LogicalKeyboardKey.arrowUp:
        index = index <= 0 ? 0 : index - 1;
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        index = index < 0 ? 0 : index;
      default:
        return KeyEventResult.ignored;
    }

    widget.controller.selectNote(notes[index]);
    _revealRow(notes[index].path);
    return KeyEventResult.handled;
  }

  void _revealRow(String path) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyContext = _rowKeys[path]?.currentContext;
      if (keyContext != null) Scrollable.ensureVisible(keyContext);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Focus(
      focusNode: _listFocus,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: QuireContextMenuRegion(
        menu: _scaffoldMenu,
        onItemSelected: (value) {
          if (value == 'new-note') widget.onCreateNote?.call();
        },
        child: Container(
          color: theme.colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Toolbar: scope chips + New note (feedback F13 — vault-wide
              // search moved to the Ctrl+K palette).
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: ListenableBuilder(
                        listenable: widget.controller,
                        builder: (context, _) => _scopeChips(theme),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: widget.onCreateNote == null ? null : () => widget.onCreateNote!(),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('New note'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        textStyle: GoogleFonts.hankenGrotesk(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
              Expanded(child: _buildList(theme)),
            ],
          ),
        ),
      ),
    );
  }

  /// Removable scope indicators; a dim caption when the vault is unscoped.
  Widget _scopeChips(ThemeData theme) {
    final controller = widget.controller;
    final folder = controller.selectedFolder;
    final tag = controller.selectedTag;
    if (folder == null && tag == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          'All notes',
          style: GoogleFonts.splineSansMono(
            fontSize: 11,
            letterSpacing: 0.5,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .7),
          ),
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (folder != null)
          _ScopeChip(
            key: const Key('scope-chip-folder'),
            icon: Icons.folder_outlined,
            label: 'in $folder',
            onClear: () => controller.selectFolder(null),
          ),
        if (tag != null)
          _ScopeChip(
            key: const Key('scope-chip-tag'),
            icon: Icons.sell_outlined,
            label: '#$tag',
            onClear: () => controller.selectTag(null),
          ),
      ],
    );
  }

  Widget _buildList(ThemeData theme) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final sorted = controller.visibleNotes.toList();

        if (sorted.isEmpty) {
          return _EmptyState(onCreate: widget.onCreateNote);
        }

        // Pinned notes float above everything as their own section (story 13);
        // the rest keeps its day-grouping, newest-first.
        final pinned = sorted.where((n) => controller.isPinned(n.path)).toList();
        final rest = sorted.where((n) => !controller.isPinned(n.path)).toList();

        final blocks = <Widget>[];
        if (pinned.isNotEmpty) {
          blocks.add(_eyebrow(theme, 'PINNED'));
          for (final note in pinned) {
            blocks.add(_rowFor(controller, note));
          }
        }

        // Group into consecutive day buckets (list is already newest-first).
        final groups = <String, List<Note>>{};
        String? lastLabel;
        for (final n in rest) {
          final label = dayLabel(n.updatedAt ?? DateTime.now());
          if (label != lastLabel) groups[label] = [];
          groups[label]!.add(n);
          lastLabel = label;
        }
        for (final entry in groups.entries) {
          blocks.add(_eyebrow(theme, entry.key.toUpperCase()));
          for (final note in entry.value) {
            blocks.add(_rowFor(controller, note));
          }
        }

        return ListView(children: blocks);
      },
    );
  }

  Padding _eyebrow(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
    child: Text(
      text,
      style: GoogleFonts.splineSansMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.9,
        height: 16 / 11,
        color: theme.colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );

  Padding _rowFor(VaultController controller, Note note) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
    child: _NoteRow(
      key: _rowKeys.putIfAbsent(note.path, GlobalKey.new),
      note: note,
      selected: controller.selectedNotePath == note.path,
      pinned: controller.isPinned(note.path),
      onTogglePin: () => controller.togglePin(note.path),
      onTap: () => controller.selectNote(note),
      onDelete: () => _deleteWithUndo(note),
    ),
  );
}

class _NoteRow extends StatefulWidget {
  const _NoteRow({
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
  State<_NoteRow> createState() => _NoteRowState();
}

class _NoteRowState extends State<_NoteRow> {
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
                              _HoverIcon(
                                key: Key('row-pin-${Uri.encodeComponent(widget.note.path)}'),
                                icon: widget.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                                color: widget.pinned ? theme.colorScheme.primary : null,
                                onTap: widget.onTogglePin,
                                tooltip: widget.pinned ? 'Unpin' : 'Pin',
                              ),
                              const SizedBox(width: 4),
                              _HoverIcon(
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

class _HoverIcon extends StatelessWidget {
  const _HoverIcon({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: color ?? theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onCreate});

  final Future<Note?> Function()? onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.edit_note_rounded, size: 28, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing here yet.',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 28 / 22,
                letterSpacing: -0.3,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture a thought in seconds —\nthen find it when you need it.',
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                height: 18 / 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate == null ? null : () => onCreate!(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Write the first note'),
            ),
            const SizedBox(height: 12),
            Text(
              'Takes about 10 seconds',
              style: GoogleFonts.splineSansMono(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A removable scope indicator (feedback F13): folder/tag filter as a pill
/// with a clear affordance.
class _ScopeChip extends StatelessWidget {
  const _ScopeChip({super.key, required this.icon, required this.label, required this.onClear});

  final IconData icon;
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onClear,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.close_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
