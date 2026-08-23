import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../logic/search_controller.dart';
import '../../logic/vault_controller.dart';
import '../../models/note.dart';
import '../../theme/quire_theme.dart';
import '../common/context_menus.dart';

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
  final _filter = TextEditingController();
  bool _filterOpen = false;
  final _filterFocus = FocusNode();
  final _listFocus = FocusNode();
  final _rowKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _listFocus.requestFocus();
  }

  @override
  void dispose() {
    _filter.dispose();
    _filterFocus.dispose();
    _listFocus.dispose();
    super.dispose();
  }

  /// Notes in current display order (post-filter, ranked).
  List<Note> get _orderedNotes =>
      searchAndSort(widget.controller.visibleNotes.toList(), _filter.text);

  /// Deletes [note] and offers an undo toast backed by the trash.
  Future<void> _deleteWithUndo(Note note) async {
    final controller = widget.controller;
    await controller.deleteNote(note.path);
    if (!mounted) return;
    final entries = await controller.trash();
    if (!mounted || entries.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${note.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => controller.restoreFromTrash(entries.first.trashedName),
        ),
      ),
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

    // While the filter is open only Esc applies here — arrows belong to the
    // text field.
    if (_filterOpen) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _closeFilter(clear: true);
        return KeyEventResult.handled;
      }
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

  void _closeFilter({required bool clear}) {
    if (clear) _filter.clear();
    setState(() => _filterOpen = false);
    _listFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyF, control: true): FindFilterIntent(),
      },
      child: Actions(
        actions: {
          FindFilterIntent: CallbackAction<FindFilterIntent>(
            onInvoke: (intent) {
              setState(() => _filterOpen = true);
              _filterFocus.requestFocus();
              return null;
            },
          ),
        },
        child: Focus(
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
                  // Toolbar: filter + New note
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: _FilterField(
                            controller: _filter,
                            focusNode: _filterFocus,
                            open: _filterOpen,
                            onToggle: () => setState(() => _filterOpen = !_filterOpen),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: widget.onCreateNote == null
                              ? null
                              : () => widget.onCreateNote!(),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('New note'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            textStyle: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w600, fontSize: 13),
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
        ),
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final notes = searchAndSort(controller.visibleNotes.toList(), _filter.text);

        if (notes.isEmpty) {
          final hasQuery = _filter.text.trim().isNotEmpty;
          if (hasQuery) {
            return _NoResults(query: _filter.text);
          }
          return _EmptyState(onCreate: widget.onCreateNote);
        }

        // Group into consecutive day buckets (list is already newest-first).
        final groups = <String, List<Note>>{};
        String? lastLabel;
        for (final n in notes) {
          final label = dayLabel(n.updatedAt ?? DateTime.now());
          if (label != lastLabel) groups[label] = [];
          groups[label]!.add(n);
          lastLabel = label;
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: groups.entries.length,
          itemBuilder: (context, index) {
            final entry = groups.entries.elementAt(index);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: GoogleFonts.splineSansMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.9,
                      height: 16 / 11,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                for (final note in entry.value)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: _NoteRow(
                      key: _rowKeys.putIfAbsent(note.path, GlobalKey.new),
                      note: note,
                      selected: controller.selectedNotePath == note.path,
                      onTap: () => controller.selectNote(note),
                      onDelete: () => _deleteWithUndo(note),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _NoteRow extends StatefulWidget {
  const _NoteRow({
    super.key,
    required this.note,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_NoteRow> createState() => _NoteRowState();
}

class _NoteRowState extends State<_NoteRow> {
  bool _hover = false;

  ContextMenu<Object?> get _menu => quireMenu([
    menuItem('Open', value: 'open', icon: Icons.description_outlined),
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
                          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
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
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
                              _HoverIcon(icon: Icons.push_pin_outlined, onTap: () {}, tooltip: 'Pin'),
                              const SizedBox(width: 4),
                              _HoverIcon(icon: Icons.delete_outline, onTap: widget.onDelete, tooltip: 'Delete'),
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
  const _HoverIcon({required this.icon, required this.onTap, required this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

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
          child: Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({
    required this.controller,
    required this.focusNode,
    required this.open,
    required this.onToggle,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          tooltip: 'Search notes',
          onPressed: () {
            onToggle();
            focusNode.requestFocus();
          },
          icon: const Icon(Icons.search),
        ),
      );
    }
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      onChanged: onChanged,
      style: GoogleFonts.hankenGrotesk(fontSize: 14, color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: 'Filter…',
        hintStyle: GoogleFonts.hankenGrotesk(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
        prefixIcon: Icon(Icons.search, size: 18, color: theme.colorScheme.onSurfaceVariant),
        suffixIcon: IconButton(
          tooltip: 'Close search',
          icon: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurfaceVariant),
          onPressed: () {
            controller.clear();
            onChanged('');
            onToggle();
          },
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(QuireRadius.m), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(QuireRadius.m), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.2)),
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

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 32, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              "No notes match '$query'.",
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Try fewer words, or check the spelling.',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ctrl+F — expand and focus the filter field.
class FindFilterIntent extends Intent {
  const FindFilterIntent();
}
