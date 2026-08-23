import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/vault_repository.dart' show FolderNode;
import '../../logic/vault_controller.dart';
import '../../theme/quire_theme.dart';
import '../common/context_menus.dart';
import '../shell/pane_widths.dart';

/// Quick filters, folder tree, tags, and trash — the leftmost pane.
/// The desk drawer: quiet until touched, tint and weight do the talking.
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
    final theme = Theme.of(context);
    final hairline = theme.colorScheme.outlineVariant;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(right: BorderSide(color: hairline, width: 1)),
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final counts = controller.tagCounts;
          final tags = counts.keys.toList()..sort();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top inset: quick filter + sort placeholder
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: _Entry(
                  label: 'All notes',
                  icon: Icons.view_quilt_outlined,
                  selected: controller.selectedFolder == null && controller.selectedTag == null,
                  onTap: () => controller
                    ..selectFolder(null)
                    ..selectTag(null),
                ),
              ),
              Divider(height: 1, color: hairline),
              Expanded(
                child: QuireContextMenuRegion(
                  menu: quireMenu([
                    menuItem(
                      'New folder',
                      value: 'new-folder-root',
                      icon: Icons.create_new_folder_outlined,
                    ),
                  ]),
                  onItemSelected: (value) {
                    if (value == 'new-folder-root') _newFolderDialog(context);
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Section(
                          label: 'FOLDERS',
                          trailing: IconButton(
                            tooltip: 'New folder',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.create_new_folder_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                            onPressed: () => _newFolderDialog(context),
                          ),
                          child: controller.folders.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                                  child: Text(
                                    'No folders yet.\nCreate one to organize.',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 12,
                                      height: 16 / 12,
                                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                    ),
                                  ),
                                )
                              : Column(children: [
                                  for (final folder in controller.folders)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: _FolderRow(controller: controller, node: folder),
                                    ),
                                ]),
                        ),
                        const SizedBox(height: 20),
                        if (tags.isNotEmpty)
                          _Section(
                            label: 'TAGS',
                            child: Column(
                              children: [
                                for (final tag in tags)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: _TagRow(controller: controller, tag: tag, count: counts[tag]!),
                                  ),
                              ],
                            ),
                          )
                        else
                          _Section(
                            label: 'TAGS',
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                              child: Text(
                                'Inline #tags appear here.',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 12,
                                  height: 16 / 12,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: hairline),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _Entry(
                        label: 'Trash',
                        icon: Icons.delete_outline,
                        onTap: onTrashTapped ?? () {},
                      ),
                    ),
                    const SizedBox(width: 4),
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onSettingsTapped,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.settings_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _newFolderDialog(BuildContext context, {String parent = ''}) async {
    final name = await _textPrompt(context, title: 'New folder');
    if (name != null && name.trim().isNotEmpty) {
      await controller.createFolderAt(parent, name.trim());
    }
  }
}

/// The collapsed sidebar: a 64 dp icon rail (Full tier).
class Rail extends StatelessWidget {
  const Rail({super.key, this.onExpand});

  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hairline = theme.colorScheme.outlineVariant;
    return Container(
      key: const Key('rail'),
      width: PaneWidths.railWidth,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(right: BorderSide(color: hairline)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          IconButton(
            tooltip: 'Expand sidebar  (Ctrl+\\ )',
            onPressed: onExpand,
            icon: const Icon(Icons.menu_open),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: hairline),
          const SizedBox(height: 12),
          IconButton(
            tooltip: 'All notes',
            onPressed: () {},
            icon: Icon(Icons.view_quilt_outlined, color: theme.colorScheme.primary),
          ),
          IconButton(
            tooltip: 'Folders',
            onPressed: () {},
            icon: Icon(Icons.folder_outlined, color: theme.colorScheme.onSurfaceVariant),
          ),
          const Spacer(),
          Divider(height: 1, color: hairline),
          IconButton(
            tooltip: 'Trash',
            onPressed: () {},
            icon: Icon(Icons.delete_outline, color: theme.colorScheme.onSurfaceVariant),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {},
            icon: Icon(Icons.settings_outlined, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
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
      title: Text(title, style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w600)),
      content: TextField(
        controller: field,
        autofocus: true,
        onSubmitted: (v) => Navigator.of(context).pop(v),
        style: GoogleFonts.hankenGrotesk(fontSize: 14),
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label!,
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
                if (trailing != null) trailing!,
              ],
            ),
          ),
        child,
      ],
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
    final ink = theme.colorScheme.primary;
    return Material(
      color: selected ? theme.colorScheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(QuireRadius.m),
      child: InkWell(
        borderRadius: BorderRadius.circular(QuireRadius.m),
        onTap: onTap,
        hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: selected ? ink : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    height: 20 / 13.5,
                    letterSpacing: 0.1,
                    color: selected ? theme.colorScheme.onSurface : theme.colorScheme.onSurface,
                  ),
                ),
              ),
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

  ContextMenu<Object?> get _menu => quireMenu([
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
      child: _HoverRow(
        selected: isSelected,
        onTap: () => controller.selectFolder(node.relPath),
        icon: isSelected ? Icons.folder_rounded : Icons.folder_outlined,
        label: node.name,
      ),
    );
  }

  Future<void> _promptAndCreate(BuildContext context) async {
    final name = await _textPrompt(context, title: 'New folder inside "${node.name}"');
    if (name != null && name.trim().isNotEmpty) {
      await controller.createFolderAt(node.relPath, name.trim());
    }
  }

  Future<void> _promptAndRename(BuildContext context) async {
    final name = await _textPrompt(
      context,
      title: 'Rename folder',
      initial: node.name,
    );
    if (name != null && name.trim().isNotEmpty && name.trim() != node.name) {
      await controller.renameFolder(node.relPath, name.trim());
    }
  }
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.selected, required this.onTap, required this.icon, required this.label});
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String label;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: widget.selected
            ? theme.colorScheme.secondaryContainer
            : _hover
                ? theme.colorScheme.onSurface.withValues(alpha: 0.04)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(QuireRadius.m),
        child: InkWell(
          borderRadius: BorderRadius.circular(QuireRadius.m),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(widget.icon, size: 18, color: widget.selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13.5,
                      fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                      height: 20 / 13.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (_hover && !widget.selected)
                  Icon(Icons.more_horiz, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
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
    return Material(
      color: selected ? theme.colorScheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(QuireRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(QuireRadius.pill),
        onTap: () => controller.selectTag(selected ? null : tag),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '#$tag',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 20 / 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? theme.colorScheme.primary.withValues(alpha: 0.14) : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.splineSansMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
