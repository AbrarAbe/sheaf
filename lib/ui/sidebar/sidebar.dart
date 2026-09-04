import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../logic/vault_controller.dart';
import '../common/context_menus.dart';
import '../common/widgets/hover_scrollbar.dart';
import 'widgets/entry.dart';
import 'widgets/folder_row.dart';
import 'widgets/section.dart';
import 'widgets/tag_row.dart';
import 'widgets/text_prompt.dart';

/// Quick filters, folder tree, tags, and trash — the leftmost pane.
/// The desk drawer: quiet until touched, tint and weight do the talking.
class Sidebar extends StatefulWidget {
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
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  int _expandVersion = 0;
  bool _expandValue = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hairline = theme.colorScheme.outlineVariant;
    final controller = widget.controller;
    return Container(
      width: widget.width,
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
                child: Entry(
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
                  child: HoverScrollbar(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Section(
                          label: 'FOLDERS',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Expand all',
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.unfold_more,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                onPressed: () => setState(() {
                                  _expandVersion++;
                                  _expandValue = true;
                                }),
                              ),
                              IconButton(
                                tooltip: 'Collapse all',
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.unfold_less,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                onPressed: () => setState(() {
                                  _expandVersion++;
                                  _expandValue = false;
                                }),
                              ),
                              IconButton(
                                tooltip: 'New folder',
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.create_new_folder_outlined,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                onPressed: () => _newFolderDialog(context),
                              ),
                            ],
                          ),
                          child: controller.folders.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                                  child: Text(
                                    'No folders yet.\nCreate one to organize.',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 12,
                                      height: 16 / 12,
                                      color: theme.colorScheme.onSurfaceVariant.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                )
                              : Column(
                                  children: [
                                    for (final folder in controller.folders)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: FolderRow(
                                          controller: controller,
                                          node: folder,
                                          expandVersion: _expandVersion,
                                          expandValue: _expandValue,
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 20),
                        if (tags.isNotEmpty)
                          Section(
                            label: 'TAGS',
                            child: Column(
                              children: [
                                for (final tag in tags)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: TagRow(
                                      controller: controller,
                                      tag: tag,
                                      count: counts[tag]!,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        else
                          Section(
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
              ),
              Divider(height: 1, color: hairline),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Entry(
                        label: 'Trash',
                        icon: Icons.delete_outline,
                        onTap: widget.onTrashTapped ?? () {},
                      ),
                    ),
                    const SizedBox(width: 4),
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: widget.onSettingsTapped,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.settings_outlined,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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
    final name = await textPrompt(context, title: 'New folder');
    if (name != null && name.trim().isNotEmpty) {
      await widget.controller.createFolderAt(parent, name.trim());
    }
  }
}
