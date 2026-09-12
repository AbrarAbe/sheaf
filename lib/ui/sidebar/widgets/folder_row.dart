import 'package:flutter/material.dart';

import '../../../data/vault_repository.dart' show FolderNode;
import '../../../logic/vault_controller.dart';
import '../../common/context_menus.dart';
import '../../common/widgets/loading_overlay.dart';
import '../../dialogs/confirm_delete.dart';
import 'hover_row.dart';
import 'text_prompt.dart';

/// A folder tree row that renders recursively with indent and
/// expand/collapse chevron. Stateless before v0.3.1 — now Stateful
/// so each subtree remembers expanded state in-memory.
class FolderRow extends StatefulWidget {
  const FolderRow({
    super.key,
    required this.controller,
    required this.node,
    this.depth = 0,
    this.expandVersion = 0,
    this.expandValue = false,
  });

  final VaultController controller;
  final FolderNode node;
  final int depth;
  final int expandVersion;
  final bool expandValue;

  @override
  State<FolderRow> createState() => _FolderRowState();
}

class _FolderRowState extends State<FolderRow> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant FolderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expandVersion != oldWidget.expandVersion) {
      _expanded = widget.expandValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final node = widget.node;
    final depth = widget.depth;
    final isSelected = controller.selectedFolder == node.relPath;
    final hasChildren = node.children.isNotEmpty;

    return Column(
      spacing: 2,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 16.0),
          child: Row(
            children: [
              if (hasChildren)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: AnimatedRotation(
                        turns: _expanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 26),
              Expanded(
                child: QuireContextMenuRegion(
                  menu: quireMenu([
                    menuItem(
                      'New folder inside',
                      value: 'new-inside',
                      icon: Icons.create_new_folder_outlined,
                    ),
                    menuItem('Rename', value: 'rename', icon: Icons.drive_file_rename_outline),
                    menuDivider,
                    menuItem(
                      'Delete',
                      value: 'delete',
                      icon: Icons.delete_outline,
                      shortcut: deleteActivator,
                    ),
                  ]),
                  onItemSelected: (value) async {
                    switch (value) {
                      case 'new-inside':
                        await _promptAndCreate(context);
                      case 'rename':
                        await _promptAndRename(context);
                      case 'delete':
                        final confirmed = await showConfirmDeleteDialog(
                          context,
                          title: 'Move folder to trash?',
                          message:
                              'Entire folder "${node.name}" and ALL its contents (subdirectories, notes, files) will be moved to trash.',
                          confirmLabel: 'Move folder to trash',
                        );
                        if (!confirmed || !context.mounted) return;
                        await showLoadingOverlay(context, controller.deleteFolder(node.relPath));
                    }
                  },
                  child: HoverRow(
                    selected: isSelected,
                    onTap: () => controller.selectFolder(node.relPath),
                    icon: isSelected ? Icons.folder_rounded : Icons.folder_outlined,
                    label: node.name,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_expanded && hasChildren)
          Column(
            children: [
              for (final child in node.children)
                FolderRow(
                  key: ValueKey(child.relPath),
                  controller: controller,
                  node: child,
                  depth: depth + 1,
                  expandVersion: widget.expandVersion,
                  expandValue: widget.expandValue,
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _promptAndCreate(BuildContext context) async {
    final name = await textPrompt(context, title: 'New folder inside "${widget.node.name}"');
    if (name != null && name.trim().isNotEmpty) {
      await widget.controller.createFolderAt(widget.node.relPath, name.trim());
    }
  }

  Future<void> _promptAndRename(BuildContext context) async {
    final name = await textPrompt(context, title: 'Rename folder', initial: widget.node.name);
    if (name != null && name.trim().isNotEmpty && name.trim() != widget.node.name) {
      await widget.controller.renameFolder(widget.node.relPath, name.trim());
    }
  }
}
