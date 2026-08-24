import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;

import '../../data/markdown_parser.dart';
import '../../logic/editor_controller.dart';
import '../../logic/formatting.dart';
import '../../logic/image_link.dart';
import '../../logic/search_controller.dart';
import '../../models/settings.dart';
import '../../theme/quire_colors.dart';
import '../../theme/quire_theme.dart';
import 'markdown_preview.dart';

/// The editor pane: title row (renames file), tag chips, prose editor with
/// debounced autosave, and the mono status footer.
/// Paper on the desk: ink is constant, title is display, body is reading.
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
    return Container(
      color: theme.colorScheme.surfaceContainerLowest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.article_outlined, size: 32, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Select a note',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose from the list, or create a new one.\nYour words live as plain Markdown files.',
                textAlign: TextAlign.center,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  height: 18 / 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.keyboard_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Ctrl+N  ·  Ctrl+K  ·  Ctrl+Shift+L',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.splineSansMono(
                          fontSize: 11,
                          letterSpacing: 0.3,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
  EditorMode? _syncedMode;
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
    if (_syncedMode != widget.controller.mode) {
      _syncedMode = widget.controller.mode;
      if (mounted) setState(() {});
    }
  }

  /// Key map for the editing surfaces. Formatting keys are bound only in
  /// Normal mode (story 12: Markdown is raw source, keys inert).
  Map<ShortcutActivator, Intent> _editShortcuts() => {
    const SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true):
        CopySelectionTextIntent.copy,
    const SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true):
        const PasteTextIntent(SelectionChangedCause.keyboard),
    if (widget.controller.mode == EditorMode.normal) ...{
      const SingleActivator(LogicalKeyboardKey.keyB, control: true): const FormatIntent(
        FormatKind.bold,
      ),
      const SingleActivator(LogicalKeyboardKey.keyI, control: true): const FormatIntent(
        FormatKind.italic,
      ),
      const SingleActivator(LogicalKeyboardKey.keyU, control: true): const FormatIntent(
        FormatKind.underline,
      ),
    },
  };

  void _applyFormat(FormatIntent intent) {
    final selection = _body.selection;
    if (!selection.isValid) return;
    final result = toggleWrap(
      text: _body.text,
      selStart: selection.start < 0 ? 0 : selection.start,
      selEnd: selection.end < 0 ? 0 : selection.end,
      open: intent.kind.open,
      close: intent.kind.close,
    );
    _body.value = TextEditingValue(
      text: result.text,
      selection: TextSelection(baseOffset: result.selStart, extentOffset: result.selEnd),
    );
    widget.controller.updateBody(result.text);
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
    final quire =
        theme.extension<QuireColors>() ??
        (theme.brightness == Brightness.dark ? quireColorsDark : quireColorsLight);
    final tags = extractTags(_body.text);
    final words = _body.text.trim().isEmpty ? 0 : _body.text.trim().split(RegExp(r'\s+')).length;

    return Container(
      color: theme.colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: title + actions
          Container(
            padding: const EdgeInsets.fromLTRB(24, 18, 16, 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _title,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      height: 30 / 24,
                      letterSpacing: -0.3,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Title',
                      hintStyle: GoogleFonts.bricolageGrotesque(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: quire.textTertiary,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onSubmitted: _commitRename,
                    onEditingComplete: () => _commitRename(_title.text),
                  ),
                ),
                const SizedBox(width: 12),
                // Actions
                Tooltip(
                  message: 'Insert image',
                  child: Material(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(QuireRadius.s),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(QuireRadius.s),
                      onTap: _insertImageFromPicker,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.image_outlined,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ModeSwitch(mode: controller.mode, onSelected: controller.setMode),
              ],
            ),
          ),
          // Tag chips: highlighter washes
          if (tags.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in tags)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '#$tag',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 16 / 12.5,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          // Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: switch (controller.mode) {
                    EditorMode.preview => MarkdownPreview(
                      body: _body.text,
                      vaultRoot: controller.vaultRoot,
                    ),
                    _ => Shortcuts(
                      shortcuts: _editShortcuts(),
                      child: Actions(
                        actions: {
                          FormatIntent: CallbackAction<FormatIntent>(
                            onInvoke: (intent) => _applyFormat(intent),
                          ),
                        },
                        child: DropTarget(
                          onDragDone: (details) => _insertDroppedImages(details.files),
                          onDragEntered: (_) => setState(() => _dragging = true),
                          onDragExited: (_) => setState(() => _dragging = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            decoration: BoxDecoration(
                              color: _dragging
                                  ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(QuireRadius.m),
                              border: _dragging
                                  ? Border.all(color: theme.colorScheme.primary, width: 1.6)
                                  : Border.all(color: Colors.transparent),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              key: const Key('editor-body'),
                              controller: _body,
                              onChanged: controller.updateBody,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              keyboardType: TextInputType.multiline,
                              style: controller.mode == EditorMode.markdown
                                  ? GoogleFonts.splineSansMono(
                                      fontSize: 14.5,
                                      height: 24 / 14.5,
                                      fontWeight: FontWeight.w400,
                                      color: theme.colorScheme.onSurface,
                                    )
                                  : GoogleFonts.hankenGrotesk(
                                      fontSize: 16,
                                      height: 26 / 16,
                                      fontWeight: FontWeight.w400,
                                      color: theme.colorScheme.onSurface,
                                    ),
                              decoration: InputDecoration(
                                hintText:
                                    'Take a note…  Type #tags, drag images, write in Markdown.',
                                hintStyle: GoogleFonts.hankenGrotesk(
                                  fontSize: 16,
                                  height: 26 / 16,
                                  color: quire.textTertiary.withValues(alpha: 0.9),
                                ),
                                filled: false,
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              cursorColor: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  },
                ),
              ),
            ),
          ),
          // Status footer: mono
          _StatusFooter(controller: controller, words: words),
        ],
      ),
    );
  }
}

class _StatusFooter extends StatelessWidget {
  const _StatusFooter({required this.controller, required this.words});

  final EditorController controller;
  final int words;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quire =
        theme.extension<QuireColors>() ??
        (theme.brightness == Brightness.dark ? quireColorsDark : quireColorsLight);
    final mono = GoogleFonts.splineSansMono(
      fontSize: 12,
      letterSpacing: 0.2,
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final status = switch (controller.status) {
      EditorStatus.clean => '',
      EditorStatus.dirty => 'unsaved · $words words',
      EditorStatus.saving => 'saving… · $words words',
      EditorStatus.saved =>
        'saved ${clockLabel(controller.lastSavedAt ?? DateTime.now())} · $words words',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: controller.status == EditorStatus.saved
                ? quire.hlGrowBase
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(status.isEmpty ? '$words words' : status, style: mono)),
          Text(
            'Markdown  ·  #tag  ·  ![image|400]',
            style: GoogleFonts.splineSansMono(
              fontSize: 11,
              letterSpacing: 0.3,
              color: quire.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ctrl+B / Ctrl+I / Ctrl+U formatting request (Normal mode only).
class FormatIntent extends Intent {
  const FormatIntent(this.kind);

  final FormatKind kind;
}

/// Normal / Markdown / Preview segmented control (spec story 12).
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onSelected});

  final EditorMode mode;
  final ValueChanged<EditorMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget segment(EditorMode value, IconData icon, String label, String tooltip) {
      final selected = mode == value;
      return Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(QuireRadius.s),
          child: InkWell(
            key: Key('mode-${value.name}'),
            borderRadius: BorderRadius.circular(QuireRadius.s),
            onTap: () => onSelected(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(QuireRadius.s + 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(
            EditorMode.normal,
            Icons.notes_outlined,
            'Normal',
            'Word-like editing (Ctrl+Shift+M)',
          ),
          segment(EditorMode.markdown, Icons.code_outlined, 'Markdown', 'Raw markdown source'),
          segment(EditorMode.preview, Icons.visibility_outlined, 'Preview', 'Rendered output'),
        ],
      ),
    );
  }
}
