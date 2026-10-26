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
    final entries = _flatten().toList();

    return AlertDialog(
      title: const Text('New note'),
      content: Column(
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
          DropdownButtonFormField<String>(
            initialValue: _location,
            decoration: const InputDecoration(labelText: 'Location'),
            items: [
              const DropdownMenuItem<String>(value: '', child: Text('Vault root')),
              for (final entry in entries)
                DropdownMenuItem<String>(
                  value: entry.$1,
                  child: Padding(
                    padding: EdgeInsets.only(left: entry.$2 * 16.0),
                    child: Text(entry.$1),
                  ),
                ),
            ],
            onChanged: (value) {
              setState(() => _location = value ?? '');
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}
