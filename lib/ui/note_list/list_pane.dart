import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../logic/search_controller.dart';
import '../../logic/vault_controller.dart';
import '../../models/note.dart';
import '../common/context_menus.dart';
import '../common/corner_toast.dart';
import '../common/widgets/hover_scrollbar.dart';
import 'widgets/empty_state.dart';
import 'widgets/note_row.dart';
import 'widgets/scope_chip.dart';

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
          ScopeChip(
            key: const Key('scope-chip-folder'),
            icon: Icons.folder_outlined,
            label: 'in $folder',
            onClear: () => controller.selectFolder(null),
          ),
        if (tag != null)
          ScopeChip(
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
          return EmptyState(onCreate: widget.onCreateNote);
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

        return HoverScrollbar(child: ListView(children: blocks));
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
    child: NoteRow(
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
