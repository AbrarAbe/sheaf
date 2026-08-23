import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../data/markdown_parser.dart';
import '../../logic/editor_controller.dart';
import '../../logic/image_link.dart';
import '../../logic/search_controller.dart';
import '../../theme/quire_theme.dart';
import 'markdown_preview.dart';

/// The editor pane: title row (renames file), tag chips, monospace body with
/// debounced autosave, and the mono status footer.
class EditorPane extends StatelessWidget {
  const EditorPane({super.key, required this.controller, this.pickImage, this.importImage});

  /// Null while no vault is open; renders the placeholder.
  final EditorController? controller;

  /// Injectable image chooser for tests; production uses the file picker.
  final Future<File?> Function()? pickImage;

  /// Injectable copier into `<vault>/attachments/`; defaults to the
  /// controller's repository call. Tests inject a fake to stay zone-safe.
  final Future<String> Function(File file)? importImage;

  @override
  Widget build(BuildContext context) {
    final editor = controller;
    if (editor == null) {
      return const _Placeholder();
    }
    return ListenableBuilder(
      listenable: editor,
      builder: (context, _) {
        if (editor.current == null) {
          return const _Placeholder();
        }
        return _Editor(controller: editor, pickImage: pickImage, importImage: importImage);
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        'Select a note',
        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _Editor extends StatefulWidget {
  const _Editor({required this.controller, this.pickImage, this.importImage});

  final EditorController controller;
  final Future<File?> Function()? pickImage;
  final Future<String> Function(File file)? importImage;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final TextEditingController _body;
  late final TextEditingController _title;
  String? _loadedPath;
  bool _preview = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncFromController);
    _body = TextEditingController();
    _title = TextEditingController();
    _load();
  }

  @override
  void didUpdateWidget(_Editor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromController);
      widget.controller.addListener(_syncFromController);
      _load();
    }
  }

  void _syncFromController() {
    if (_loadedPath != widget.controller.current?.path) _load();
  }

  Future<void> _load() async {
    final note = widget.controller.current;
    if (note == null || note.path == _loadedPath) return;
    _loadedPath = note.path;
    _body.text = note.body;
    _title.text = note.title;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    _body.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _commitRename(String newTitle) async {
    final current = widget.controller.current;
    if (current == null) return;
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty || trimmed == extractTitle(current.body, current.fileName)) {
      _title.text = current.title;
      return;
    }
    await widget.controller.flush();
    await widget.controller.renameCurrent(trimmed);
  }

  Future<void> _insertImageFromPicker() async {
    final file = await widget.pickImage?.call();
    if (file != null) await _insertImage(file);
  }

  Future<void> _insertDroppedImages(List<dynamic> items) async {
    setState(() => _dragging = false);
    for (final item in items) {
      if (item is! DropItemFile) continue;
      final path = item.path;
      if (['.png', '.jpg', '.jpeg', '.gif', '.webp'].contains(p.extension(path).toLowerCase())) {
        await _insertImage(File(path));
      }
    }
  }

  /// Copies the image into the vault and inserts an Obsidian-style link at
  /// the cursor (or end of the body).
  Future<void> _insertImage(File file) async {
    final doImport = widget.importImage ?? widget.controller.importAttachment;
    final rel = await doImport(file);
    final name = p.basenameWithoutExtension(rel);
    final result = insertImageLink(
      body: _body.text,
      link: '![$name]($rel)',
      offset: _body.selection.baseOffset,
    );
    _body.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.caret),
    );
    widget.controller.updateBody(result.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final tags = extractTags(_body.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(QuireSpace.xl, QuireSpace.l, QuireSpace.xl, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _title,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(filled: false),
                  onSubmitted: _commitRename,
                ),
              ),
              IconButton(
                tooltip: 'Insert image',
                onPressed: _insertImageFromPicker,
                icon: const Icon(Icons.image_outlined),
              ),
              IconButton(
                tooltip: _preview ? 'Edit' : 'Preview',
                isSelected: _preview,
                onPressed: () => setState(() => _preview = !_preview),
                icon: const Icon(Icons.visibility_outlined),
                selectedIcon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(QuireSpace.xl, QuireSpace.s, QuireSpace.xl, 0),
            child: Wrap(
              spacing: QuireSpace.s,
              runSpacing: QuireSpace.xs,
              children: [
                for (final tag in tags)
                  Chip(
                    label: Text('#$tag', style: theme.textTheme.labelMedium),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(QuireSpace.xl),
            child: _preview
                ? MarkdownPreview(body: _body.text, vaultRoot: controller.vaultRoot)
                : DropTarget(
                    onDragDone: (details) => _insertDroppedImages(details.files),
                    onDragEntered: (_) => setState(() => _dragging = true),
                    onDragExited: (_) => setState(() => _dragging = false),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(QuireRadius.m),
                        border: _dragging
                            ? Border.all(color: theme.colorScheme.primary, width: 2)
                            : null,
                      ),
                      child: TextField(
                        key: const Key('editor-body'),
                        controller: _body,
                        onChanged: controller.updateBody,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        keyboardType: TextInputType.multiline,
                        style: theme.textTheme.bodyLarge?.copyWith(fontFamily: 'monospace'),
                        decoration: const InputDecoration(filled: false),
                      ),
                    ),
                  ),
          ),
        ),
        _StatusFooter(controller: controller),
      ],
    );
  }
}

class _StatusFooter extends StatelessWidget {
  const _StatusFooter({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.labelSmall?.copyWith(
      fontFamily: 'monospace',
      color: theme.colorScheme.onSurfaceVariant,
    );
    final status = switch (controller.status) {
      EditorStatus.clean => '',
      EditorStatus.dirty => 'unsaved…',
      EditorStatus.saving => 'saving…',
      EditorStatus.saved => 'saved ${clockLabel(controller.lastSavedAt ?? DateTime.now())}',
    };
    if (status.isEmpty) return const SizedBox(height: QuireSpace.l + 8);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: QuireSpace.xl, vertical: QuireSpace.xs + 2),
      child: Text(status, style: mono),
    );
  }
}
