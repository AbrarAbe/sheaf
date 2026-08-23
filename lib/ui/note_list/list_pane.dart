import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(QuireSpace.m, QuireSpace.m, QuireSpace.m, 0),
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
                        const SizedBox(width: QuireSpace.s),
                        FilledButton.tonalIcon(
                          onPressed: widget.onCreateNote == null
                              ? null
                              : () => widget.onCreateNote!(),
                          icon: const Icon(Icons.note_add_outlined, size: 18),
                          label: const Text('New note'),
                        ),
                      ],
                    ),
                  ),
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
          itemCount: groups.entries.length,
          itemBuilder: (context, index) {
            final entry = groups.entries.elementAt(index);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    QuireSpace.xl,
                    QuireSpace.m,
                    QuireSpace.xl,
                    QuireSpace.xs,
                  ),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                for (final note in entry.value)
                  _NoteRow(
                    key: _rowKeys.putIfAbsent(note.path, GlobalKey.new),
                    note: note,
                    selected: controller.selectedNotePath == note.path,
                    onTap: () => controller.selectNote(note),
                    onDelete: () => _deleteWithUndo(note),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _NoteRow extends StatelessWidget {
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

  ContextMenu<Object?> get _menu => quireMenu([
    menuItem('Open', value: 'open', icon: Icons.description_outlined),
    menuDivider,
    menuItem('Delete', value: 'delete', icon: Icons.delete_outline, shortcut: deleteActivator),
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return QuireContextMenuRegion(
      menu: _menu,
      onItemSelected: (value) {
        if (value == 'open') onTap();
        if (value == 'delete') onDelete();
      },
      child: Material(
        color: selected ? theme.colorScheme.secondaryContainer : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: QuireSpace.xl),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      if (snippetOf(note.body).isNotEmpty)
                        Text(
                          snippetOf(note.body),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: QuireSpace.s),
                Text(
                  clockLabel(note.updatedAt ?? DateTime.now()),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
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

/// Collapsed-by-default search: icon until opened, then a filter field that
/// clears and collapses from its own close button.
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
      decoration: InputDecoration(
        hintText: 'Filter…',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: IconButton(
          tooltip: 'Close search',
          icon: const Icon(Icons.close, size: 18),
          onPressed: () {
            controller.clear();
            onChanged('');
            onToggle();
          },
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Nothing here yet.', style: theme.textTheme.titleMedium),
          const SizedBox(height: QuireSpace.m),
          FilledButton.tonal(
            onPressed: onCreate == null ? null : () => onCreate!(),
            child: const Text('Write the first note'),
          ),
        ],
      ),
    );
  }
}

/// Ctrl+F — expand and focus the filter field.
class FindFilterIntent extends Intent {
  const FindFilterIntent();
}
