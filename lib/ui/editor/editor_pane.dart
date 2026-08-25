import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;

import '../../data/markdown_parser.dart';
import '../../logic/editor_controller.dart';
import '../../logic/find_controller.dart';
import '../../logic/formatting.dart';
import '../../logic/image_link.dart';
import '../../logic/list_continuation.dart';
import '../../logic/search_controller.dart';
import '../../models/settings.dart';
import '../../theme/quire_colors.dart';
import '../../theme/quire_theme.dart';
import 'highlighting_controller.dart';
import 'markdown_preview.dart';

/// The editor pane: title row (renames file), tag chips, prose editor with
/// debounced autosave, and the mono status footer.
/// Paper on the desk: ink is constant, title is display, body is reading.
class EditorPane extends StatelessWidget {
  const EditorPane({
    super.key,
    required this.controller,
    this.pickImage,
    this.importImage,
    this.baseFontSize,
    this.userFontFamily,
  });

  /// Null while no vault is open; renders the placeholder.
  final EditorController? controller;

  /// Injectable image chooser for tests; production uses the file picker.
  final Future<File?> Function()? pickImage;

  /// Injectable copier into `<vault>/attachments/`; defaults to the
  /// controller's repository call. Tests inject a fake to stay zone-safe.
  final Future<String> Function(File file)? importImage;

  /// Editor body base size from settings (story 16); null = 16.
  final double? baseFontSize;

  /// Family of a user-loaded font; null keeps the bundled Hanken stack.
  final String? userFontFamily;

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
        return _Editor(
          controller: editor,
          pickImage: pickImage,
          importImage: importImage,
          baseFontSize: baseFontSize,
          userFontFamily: userFontFamily,
        );
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
  const _Editor({
    required this.controller,
    this.pickImage,
    this.importImage,
    this.baseFontSize,
    this.userFontFamily,
  });

  final EditorController controller;
  final Future<File?> Function()? pickImage;
  final Future<String> Function(File file)? importImage;
  final double? baseFontSize;
  final String? userFontFamily;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final HighlightingController _body;
  late final TextEditingController _title;
  late final FocusNode _bodyFocus;
  String? _loadedPath;
  EditorMode? _syncedMode;
  bool _dragging = false;
  bool _findOpen = false;
  TextEditingController? _findCtrl;
  List<int> _matches = [];
  int _matchIndex = -1;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncFromController);
    _body = HighlightingController();
    _body.highlight = widget.controller.mode == EditorMode.normal;
    _title = TextEditingController();
    _bodyFocus = FocusNode();
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
      _body.highlight = _syncedMode == EditorMode.normal;
      if (mounted) setState(() {});
    }
  }

  /// Key map for the editing surfaces. Formatting keys are bound only in
  /// Normal mode (story 12: Markdown is raw source, keys inert).
  Map<ShortcutActivator, Intent> _editShortcuts() => {
    const SingleActivator(LogicalKeyboardKey.enter): const ContinueListIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter): const ContinueListIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF, control: true): const OpenFindIntent(),
    const SingleActivator(LogicalKeyboardKey.keyD, control: true): const SelectWordIntent(),
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

  /// Body text style for the current mode, honoring the settings' base size
  /// and user typeface (story 16).
  TextStyle _bodyStyle(ThemeData theme) {
    final base = widget.baseFontSize ?? 16.0;
    if (widget.controller.mode == EditorMode.markdown) {
      if (widget.userFontFamily != null) {
        return TextStyle(
          fontFamily: widget.userFontFamily,
          fontSize: base - 1.5,
          height: 24 / (base - 1.5),
          color: theme.colorScheme.onSurface,
        );
      }
      return GoogleFonts.splineSansMono(
        fontSize: base - 1.5,
        height: 24 / (base - 1.5),
        fontWeight: FontWeight.w400,
        color: theme.colorScheme.onSurface,
      );
    }
    if (widget.userFontFamily != null) {
      return TextStyle(
        fontFamily: widget.userFontFamily,
        fontSize: base,
        height: 26 / base,
        color: theme.colorScheme.onSurface,
      );
    }
    return GoogleFonts.hankenGrotesk(
      fontSize: base,
      height: 26 / base,
      fontWeight: FontWeight.w400,
      color: theme.colorScheme.onSurface,
    );
  }

  void _applyFormat(FormatIntent intent) {
    final selection = _body.selection;
    if (!selection.isValid || selection.start < 0 || selection.end < 0) return;
    var start = selection.start;
    var end = selection.end;

    // Bare caret on a word → format that whole word rather than splicing an
    // empty pair into it (feedback F10; also why Ctrl+U looked dead — its
    // inserted pair rendered hidden).
    if (start == end) {
      final (wordStart, wordEnd) = wordBoundary(_body.text, start);
      if (wordEnd > wordStart && RegExp(r'\w').hasMatch(_body.text[wordStart])) {
        start = wordStart;
        end = wordEnd;
      }
    }

    final result = toggleWrap(
      text: _body.text,
      selStart: start,
      selEnd: end,
      open: intent.kind.open,
      close: intent.kind.close,
    );
    _body.value = TextEditingValue(
      text: result.text,
      selection: TextSelection(baseOffset: result.selStart, extentOffset: result.selEnd),
    );
    widget.controller.updateBody(result.text);
  }

  /// Enter handler: continues markdown lists (story 15); outside lists a
  /// plain newline is inserted so normal typing is unaffected.
  void _handleEnter() {
    final selection = _body.selection;
    var caret = selection.isValid ? selection.baseOffset : -1;
    if (caret < 0 || caret > _body.text.length) caret = _body.text.length;

    final result = continueList(text: _body.text, caret: caret);
    if (result != null) {
      _body.value = TextEditingValue(
        text: result.text,
        selection: TextSelection.collapsed(offset: result.selStart),
      );
    } else {
      _body.value = TextEditingValue(
        text: _body.text.replaceRange(caret, caret, '\n'),
        selection: TextSelection.collapsed(offset: caret + 1),
      );
    }
    widget.controller.updateBody(_body.text);
  }

  // --- Find in note (spec story 14) ---------------------------------------

  void _openFind() {
    final selection = _body.selection;
    var prefill = '';
    if (selection.isValid && selection.start >= 0 && selection.end > selection.start) {
      prefill = _body.text.substring(selection.start, selection.end);
    }
    _findCtrl?.dispose();
    _findCtrl = TextEditingController(text: prefill);
    setState(() => _findOpen = true);
    _runFind(prefill);
  }

  void _closeFind() {
    _findCtrl?.dispose();
    _findCtrl = null;
    setState(() => _findOpen = false);
    _bodyFocus.requestFocus();
  }

  void _runFind(String query) {
    _lastQuery = query.trim();
    _matches = matchOffsets(_body.text, _lastQuery);
    _matchIndex = _matches.isEmpty ? -1 : 0;
    _jumpToCurrentMatch();
    if (mounted) setState(() {});
  }

  void _nextMatch() => _stepMatch(1);

  void _prevMatch() => _stepMatch(-1);

  void _stepMatch(int step) {
    if (_matches.isEmpty) return;
    _matchIndex = (_matchIndex + step) % _matches.length;
    _jumpToCurrentMatch();
    if (mounted) setState(() {});
  }

  void _jumpToCurrentMatch() {
    if (_matchIndex < 0 || _matchIndex >= _matches.length) return;
    final start = _matches[_matchIndex];
    _body.value = TextEditingValue(
      text: _body.text,
      selection: TextSelection(baseOffset: start, extentOffset: start + _lastQuery.length),
    );
  }

  String get _counterLabel => _matches.isEmpty ? '0/0' : '${_matchIndex + 1}/${_matches.length}';

  /// Ctrl+D — select the word at the caret (story 11, F6).
  void _selectWord() {
    final selection = _body.selection;
    var offset = selection.isValid ? selection.baseOffset : -1;
    if (offset < 0 || offset > _body.text.length) offset = _body.text.length;

    final (start, end) = wordBoundary(_body.text, offset);
    _body.value = TextEditingValue(
      text: _body.text,
      selection: TextSelection(baseOffset: start, extentOffset: end),
    );
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
    _bodyFocus.dispose();
    _findCtrl?.dispose();
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
          // Find bar (story 14)
          if (_findOpen && _findCtrl != null)
            _FindBar(
              controller: _findCtrl!,
              counter: _counterLabel,
              hasMatches: _matches.isNotEmpty,
              onChanged: _runFind,
              onNext: _nextMatch,
              onPrev: _prevMatch,
              onClose: _closeFind,
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
              // Top-aligned (feedback F3): the preview's scroll view shrink-
              // wraps its content, and Center would float it mid-pane.
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: switch (controller.mode) {
                    EditorMode.preview => MarkdownPreview(
                      body: _body.text,
                      vaultRoot: controller.vaultRoot,
                      baseFontSize: widget.baseFontSize ?? 16,
                      userFontFamily: widget.userFontFamily,
                    ),
                    _ => Shortcuts(
                      shortcuts: _editShortcuts(),
                      child: Actions(
                        actions: {
                          FormatIntent: CallbackAction<FormatIntent>(
                            onInvoke: (intent) => _applyFormat(intent),
                          ),
                          ContinueListIntent: CallbackAction<ContinueListIntent>(
                            onInvoke: (intent) => _handleEnter(),
                          ),
                          OpenFindIntent: CallbackAction<OpenFindIntent>(
                            onInvoke: (intent) => _openFind(),
                          ),
                          SelectWordIntent: CallbackAction<SelectWordIntent>(
                            onInvoke: (intent) => _selectWord(),
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
                              focusNode: _bodyFocus,
                              onChanged: controller.updateBody,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              keyboardType: TextInputType.multiline,
                              style: _bodyStyle(theme),
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

/// Enter pressed inside an editing surface; handled as list continuation.
class ContinueListIntent extends Intent {
  const ContinueListIntent();
}

/// Ctrl+D — select the word at the caret.
class SelectWordIntent extends Intent {
  const SelectWordIntent();
}

/// Ctrl+F — open the find-in-note bar.
class OpenFindIntent extends Intent {
  const OpenFindIntent();
}

/// Enter in the find bar — jump to the next match.
class FindNextIntent extends Intent {
  const FindNextIntent();
}

/// Shift+Enter in the find bar — jump to the previous match.
class FindPrevIntent extends Intent {
  const FindPrevIntent();
}

/// Escape in the find bar — close it and restore editor focus.
class CloseFindIntent extends Intent {
  const CloseFindIntent();
}

/// Slim query bar docked under the editor header: live count, prev/next,
/// Esc to close (spec story 14).
class _FindBar extends StatelessWidget {
  const _FindBar({
    required this.controller,
    required this.counter,
    required this.hasMatches,
    required this.onChanged,
    required this.onNext,
    required this.onPrev,
    required this.onClose,
  });

  final TextEditingController controller;
  final String counter;
  final bool hasMatches;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): FindNextIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): FindNextIntent(),
        SingleActivator(LogicalKeyboardKey.enter, shift: true): FindPrevIntent(),
        SingleActivator(LogicalKeyboardKey.escape): CloseFindIntent(),
      },
      child: Actions(
        actions: {
          FindNextIntent: CallbackAction<FindNextIntent>(onInvoke: (_) => onNext()),
          FindPrevIntent: CallbackAction<FindPrevIntent>(onInvoke: (_) => onPrev()),
          CloseFindIntent: CallbackAction<CloseFindIntent>(onInvoke: (_) => onClose()),
        },
        child: Container(
          key: const Key('find-bar'),
          padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 15, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('find-field'),
                  controller: controller,
                  autofocus: true,
                  onChanged: onChanged,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Find in note…',
                    hintStyle: GoogleFonts.hankenGrotesk(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    filled: false,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
              Text(
                counter,
                style: GoogleFonts.splineSansMono(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                key: const Key('find-prev'),
                tooltip: 'Previous match (Shift+Enter)',
                visualDensity: VisualDensity.compact,
                onPressed: hasMatches ? onPrev : null,
                icon: const Icon(Icons.keyboard_arrow_up, size: 18),
              ),
              IconButton(
                key: const Key('find-next'),
                tooltip: 'Next match (Enter)',
                visualDensity: VisualDensity.compact,
                onPressed: hasMatches ? onNext : null,
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              ),
              IconButton(
                key: const Key('find-close'),
                tooltip: 'Close (Esc)',
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
