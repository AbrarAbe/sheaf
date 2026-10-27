import 'package:material_ui/material_ui.dart';
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/logic/vault_controller.dart';

/// Request payload returned by [showNewNoteDialog] on submit.
class NewNoteRequest {
  const NewNoteRequest({required this.title, required this.relFolder});

  final String title;
  final String relFolder;

  @override
  bool operator ==(Object other) =>
      other is NewNoteRequest && other.title == title && other.relFolder == relFolder;

  @override
  int get hashCode => Object.hash(title, relFolder);
}

Future<NewNoteRequest?> showNewNoteDialog(BuildContext context, VaultController controller) {
  return showDialog<NewNoteRequest>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) =>
        _NewNoteDialog(defaultFolder: controller.selectedFolder ?? '', folders: controller.folders),
  );
}

class _NewNoteDialog extends StatefulWidget {
  const _NewNoteDialog({required this.defaultFolder, required this.folders});

  final String defaultFolder;
  final List<FolderNode> folders;

  @override
  State<_NewNoteDialog> createState() => _NewNoteDialogState();
}

class _NewNoteDialogState extends State<_NewNoteDialog> {
  late final TextEditingController _nameController = TextEditingController(text: 'Untitled');
  late final FocusNode _nameFocus = FocusNode();
  late String _location = widget.defaultFolder;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  NewNoteRequest _buildRequest() {
    final raw = _nameController.text.trim();
    final title = raw.isEmpty ? 'Untitled' : raw;
    return NewNoteRequest(title: title, relFolder: _location);
  }

  void _submit() {
    Navigator.of(context).pop(_buildRequest());
  }

  Iterable<(String, int)> _flatten() sync* {
    for (final node in widget.folders) {
      yield* _flattenNode(node, 0);
    }
  }

  Iterable<(String, int)> _flattenNode(FolderNode node, int depth) sync* {
    yield (node.relPath, depth);
    for (final child in node.children) {
      yield* _flattenNode(child, depth + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _flatten().toList();
    // M3 menu rows are MenuItemButtons. Size them to 36px with body text so
    // the picker matches the dialog's dense density — DropdownButton rows are
    // hard-floored at kMinInteractiveDimension (48px) and ignore this.
    final menuItemStyle = MenuItemButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      textStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
    );

    return AlertDialog(
      title: const Text('New note'),
      content: SizedBox(
        width: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              focusNode: _nameFocus,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            // Without an explicit width the M3 menu sizes its panel to the
            // widest item's *intrinsic* text width (ellipsis is ignored there)
            // and our Row/Expanded labelWidget makes every row fill it, so the
            // panel blows out past the modal on long paths. Feed the dialog's
            // real available width in so the panel hugs the field and long
            // paths ellipsize inside it instead.
            LayoutBuilder(
              builder: (context, constraints) => DropdownMenu<String>(
                width: constraints.maxWidth,
                initialSelection: _location,
                requestFocusOnTap: false,
                enableFilter: false,
                enableSearch: false,
                label: const Text('Location'),
                onSelected: (value) => setState(() => _location = value ?? ''),
                dropdownMenuEntries: [
                  DropdownMenuEntry<String>(value: '', label: 'Vault root', style: menuItemStyle),
                  for (final entry in entries)
                    DropdownMenuEntry<String>(
                      value: entry.$1,
                      label: entry.$1,
                      style: menuItemStyle,
                      labelWidget: Row(
                        children: [
                          SizedBox(width: entry.$2 * 8.0),
                          Expanded(
                            child: Text(entry.$1, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}
