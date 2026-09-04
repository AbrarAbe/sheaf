import 'package:flutter/material.dart';

import '../../../data/vault_repository.dart' show FolderNode;
import '../../../logic/vault_controller.dart';
import '../../common/context_menus.dart';
import 'hover_row.dart';
import 'text_prompt.dart';

/// Quick filters, folder tree, tags, and trash — the leftmost pane.
/// The desk drawer: quiet until touched, tint and weight do the talking.

class FolderRow extends StatelessWidget {
  const FolderRow({super.key, required this.controller, required this.node});

  final VaultController controller;
  final FolderNode node;

  ContextMenu<Object?> get _menu => quireMenu([
    menuItem('New folder inside', value: 'new-inside', icon: Icons.create_new_folder_outlined),
    menuItem('Rename', value: 'rename', icon: Icons.drive_file_rename_outline),
    menuDivider,
    menuItem('Delete', value: 'delete', icon: Icons.delete_outline, shortcut: deleteActivator),
  ]);

  @override
  Widget build(BuildContext context) {
    final isSelected = controller.selectedFolder == node.relPath;
    return QuireContextMenuRegion(
      menu: _menu,
      onItemSelected: (value) async {
        switch (value) {
          case 'new-inside':
            await _promptAndCreate(context);
          case 'rename':
            await _promptAndRename(context);
          case 'delete':
            await controller.deleteFolder(node.relPath);
        }
      },
      child: HoverRow(
        selected: isSelected,
        onTap: () => controller.selectFolder(node.relPath),
        icon: isSelected ? Icons.folder_rounded : Icons.folder_outlined,
        label: node.name,
      ),
    );
  }

  Future<void> _promptAndCreate(BuildContext context) async {
    final name = await textPrompt(context, title: 'New folder inside "${node.name}"');
    if (name != null && name.trim().isNotEmpty) {
      await controller.createFolderAt(node.relPath, name.trim());
    }
  }

  Future<void> _promptAndRename(BuildContext context) async {
    final name = await textPrompt(context, title: 'Rename folder', initial: node.name);
    if (name != null && name.trim().isNotEmpty && name.trim() != node.name) {
      await controller.renameFolder(node.relPath, name.trim());
    }
  }
}
