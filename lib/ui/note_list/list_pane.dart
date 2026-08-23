import 'package:flutter/material.dart';

import '../../logic/search_controller.dart';
import '../../logic/vault_controller.dart';
import '../../models/note.dart';
import '../../theme/quire_theme.dart';

/// The note list pane: filter field, day-grouped compact rows.
class ListPane extends StatefulWidget {
  const ListPane({super.key, required this.controller, this.onCreateNote});

  final VaultController controller;

  /// Hook for the compose action (wired to the editor in Task 10).
  final Future<Note?> Function()? onCreateNote;

  @override
  State<ListPane> createState() => _ListPaneState();
}

class _ListPaneState extends State<ListPane> {
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(QuireSpace.m, QuireSpace.m, QuireSpace.m, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _filter,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Filter…',
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: QuireSpace.s),
                FilledButton.tonalIcon(
                  onPressed: widget.onCreateNote == null ? null : () => widget.onCreateNote!(),
                  icon: const Icon(Icons.note_add_outlined, size: 18),
                  label: const Text('New note'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildList(theme)),
        ],
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
                    note: note,
                    selected: controller.selectedNotePath == note.path,
                    onTap: () => controller.selectNote(note),
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
  const _NoteRow({required this.note, required this.selected, required this.onTap});

  final Note note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
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
