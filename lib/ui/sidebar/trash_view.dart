import 'package:flutter/material.dart';

import '../../data/vault_repository.dart' show TrashEntry;
import '../../logic/vault_controller.dart';

/// Modal trash view: restore items or delete them forever.
///
/// Loads current entries first (await this outside any test FakeAsync zone),
/// then shows the dialog.
Future<void> showTrashDialog(BuildContext context, VaultController controller) async {
  final entries = await controller.trash();
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => TrashDialogContent(controller: controller, initial: entries),
    ),
  );
}

/// The dialog contents. Public for direct testing with a pre-loaded list.
class TrashDialogContent extends StatefulWidget {
  const TrashDialogContent({super.key, required this.controller, required this.initial});

  final VaultController controller;

  /// Entries captured when the view opened; mutations reload from [controller].
  final List<TrashEntry> initial;

  @override
  State<TrashDialogContent> createState() => _TrashDialogContentState();
}

class _TrashDialogContentState extends State<TrashDialogContent> {
  late List<TrashEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Trash'),
      content: SizedBox(
        width: 420,
        height: 320,
        child: _entries.isEmpty
            ? Center(
                child: Text(
                  'Trash is empty.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      entry.isFolder ? Icons.folder_off_outlined : Icons.description_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(entry.trashedName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      entry.originalPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Restore',
                          icon: const Icon(Icons.restore, size: 20),
                          onPressed: () =>
                              _mutate(() => widget.controller.restoreFromTrash(entry.trashedName)),
                        ),
                        IconButton(
                          tooltip: 'Delete forever',
                          icon: Icon(
                            Icons.delete_forever_outlined,
                            size: 20,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: () =>
                              _mutate(() => widget.controller.emptyTrashItem(entry.trashedName)),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }

  /// Runs the mutation, then refreshes the visible list from disk.
  Future<void> _mutate(Future<void> Function() action) async {
    await action();
    _entries = await widget.controller.trash();
    if (mounted) setState(() {});
  }
}
