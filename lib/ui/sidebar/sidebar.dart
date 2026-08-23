import 'package:flutter/material.dart';

import '../../data/vault_repository.dart' show FolderNode;
import '../../logic/vault_controller.dart';
import '../../theme/quire_theme.dart';
import '../shell/pane_widths.dart';

/// Quick filters, folder tree, tags, and trash — the leftmost pane.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.controller,
    required this.width,
    this.onTrashTapped,
    this.onSettingsTapped,
  });

  final VaultController controller;
  final double width;
  final VoidCallback? onTrashTapped;
  final VoidCallback? onSettingsTapped;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final counts = controller.tagCounts;
          final tags = counts.keys.toList()..sort();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Section(
                child: _Entry(
                  label: 'All notes',
                  selected: controller.selectedFolder == null && controller.selectedTag == null,
                  onTap: () => controller
                    ..selectFolder(null)
                    ..selectTag(null),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  child: _Section(
                    label: 'Folders',
                    trailing: IconButton(
                      tooltip: 'New folder',
                      icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                      onPressed: () => _newFolderDialog(context),
                    ),
                    child: Column(
                      children: [
                        for (final folder in controller.folders)
                          _FolderRow(controller: controller, node: folder),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: QuireSpace.m),
                          _Section(
                            label: 'Tags',
                            child: Column(
                              children: [
                                for (final tag in tags)
                                  _TagRow(controller: controller, tag: tag, count: counts[tag]!),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Row(
                children: [
                  Expanded(
                    child: _Section(
                      child: _Entry(
                        label: 'Trash',
                        icon: Icons.delete_outline,
                        onTap: onTrashTapped ?? () {},
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: onSettingsTapped,
                    icon: const Icon(Icons.settings_outlined, size: 20),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _newFolderDialog(BuildContext context) async {
    final name = await _textPrompt(context, title: 'New folder');
    if (name != null && name.trim().isNotEmpty) {
      await controller.createFolder(name.trim());
    }
  }
}

/// The collapsed sidebar: a 64 dp icon rail (Full tier).
class Rail extends StatelessWidget {
  const Rail({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('rail'),
      width: PaneWidths.railWidth,
      child: Column(
        children: [
          IconButton(
            tooltip: 'Expand sidebar',
            onPressed: () {},
            icon: const Icon(Icons.menu_open),
          ),
        ],
      ),
    );
  }
}

Future<String?> _textPrompt(BuildContext context, {required String title, String? initial}) {
  final field = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: field,
        autofocus: true,
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(field.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.label, this.trailing});

  final Widget child;
  final String? label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: QuireSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      QuireSpace.m,
                      QuireSpace.l,
                      0,
                      QuireSpace.xs,
                    ),
                    child: Text(
                      label!.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          child,
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.label, required this.onTap, this.selected = false, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(QuireRadius.s),
      child: InkWell(
        borderRadius: BorderRadius.circular(QuireRadius.s),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: QuireSpace.m, vertical: QuireSpace.s + 2),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: QuireSpace.s),
              ],
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.controller, required this.node});

  final VaultController controller;
  final FolderNode node;

  @override
  Widget build(BuildContext context) {
    return _Entry(
      label: node.name,
      selected: controller.selectedFolder == node.relPath,
      icon: Icons.folder_outlined,
      onTap: () => controller.selectFolder(node.relPath),
      // Long-press/secondary-click opens the manage menu.
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.controller, required this.tag, required this.count});

  final VaultController controller;
  final String tag;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = controller.selectedTag == tag;
    final fg = theme.colorScheme.onSurfaceVariant;
    return Material(
      color: selected ? theme.colorScheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(QuireRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(QuireRadius.pill),
        onTap: () => controller.selectTag(selected ? null : tag),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: QuireSpace.m,
            vertical: QuireSpace.xs + 2,
          ),
          child: Row(
            children: [
              Expanded(child: Text('#$tag', style: theme.textTheme.bodyMedium)),
              Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(color: fg, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
