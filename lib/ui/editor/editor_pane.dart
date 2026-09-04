import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../data/markdown_parser.dart';
import '../../logic/editor_controller.dart';
import '../../logic/find_controller.dart';
import '../../logic/formatting.dart';
import '../../logic/image_link.dart';
import '../../logic/list_continuation.dart';
import '../../models/settings.dart';
import '../../models/shortcut_settings.dart';
import '../../theme/quire_colors.dart';
import '../../theme/quire_theme.dart';
import '../shell/shortcuts.dart';
import 'edit_menu.dart';
import 'highlighting_controller.dart';
import 'intents.dart';
import 'markdown_preview.dart';
import 'widgets/find_bar.dart';
import 'widgets/mode_switch.dart';
import 'widgets/placeholder.dart';
import 'widgets/status_footer.dart';

export 'intents.dart';

/// The editor pane: title row (renames file), tag chips, prose editor with
/// debounced autosave, and the mono status footer.
/// Paper on the desk: ink is constant, title is display, body is reading.
class EditorPane extends StatelessWidget {
  const EditorPane({
    super.key,
    required this.controller,
    this.importImage,
    this.baseFontSize,
    this.focusMode = false,
    this.settings,
  });

  /// Null while no vault is open; renders the placeholder.
  final EditorController? controller;

  /// Injectable copier into `<vault>/attachments/`; defaults to the
  /// controller's repository call. Tests inject a fake to stay zone-safe.
  final Future<String> Function(File file)? importImage;

  /// Editor body base size from settings (story 16); null = 16.
  final double? baseFontSize;

  /// When true, the body column is centered and slightly wider (focus mode).
  final bool focusMode;

  /// Settings for shortcut customization; if null, defaults are used.
  final AppSettings? settings;
  @override
  Widget build(BuildContext context) {
    final editor = controller;
    if (editor == null) {
      return const EditorPlaceholder();
    }
    return ListenableBuilder(
      listenable: editor,
      builder: (context, _) {
        if (editor.current == null) {
          return const EditorPlaceholder();
        }
        return _Editor(
          controller: editor,
          importImage: importImage,
          baseFontSize: baseFontSize,
          focusMode: focusMode,
          settings: settings,
        );
      },
    );
  }
}

class _Editor extends StatefulWidget {
  const _Editor({
    required this.controller,
    this.importImage,
    this.baseFontSize,
    this.focusMode = false,
    this.settings,
  });

  final EditorController controller;
  final Future<String> Function(File file)? importImage;
  final double? baseFontSize;
  final bool focusMode;
  final AppSettings? settings;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final HighlightingController _body;

  /// Guards the edit-menu overlay: contextMenuBuilder re-fires on every
  /// field rebuild while a menu is open, and each fire used to stack
  /// another route (round 6 bug).
  bool _editMenuOpen = false;
  late final TextEditingController _title;
  late final FocusNode _bodyFocus;

  /// Focus node for preview mode so `Ctrl+Shift+M` remains dispatchable
  /// when the TextField is unmounted.
  late final FocusNode _previewFocus;

  /// Focus *intent*: true once the body has been focused, sticky across mode
  /// switches (Preview unmounts the TextField, so hasFocus is false on return).
  bool _wantBodyFocus = false;
  late final FocusNode _titleFocus;
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
    _bodyFocus.addListener(_onBodyFocusChange);
    _previewFocus = FocusNode(debugLabel: 'preview');
    _titleFocus = FocusNode();
    _titleFocus.addListener(_onTitleFocusChange);
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
      final editable = _syncedMode != EditorMode.preview;
      if (mounted) setState(() {});
      // Preview unmounts the body TextField, so _bodyFocus.hasFocus is already
      // false when we come back from it — reading it here would never restore the
      // caret. Track intent on the FocusNode instead (feedback F29): whenever we
      // land back in an editable mode with that intent, hand focus back.
      if (editable && _wantBodyFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _bodyFocus.requestFocus();
        });
      } else if (!editable) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _previewFocus.requestFocus();
        });
      }
    }
  }

  void _onBodyFocusChange() {
    if (_bodyFocus.hasFocus) _wantBodyFocus = true;
  }

  void _onTitleFocusChange() {
    if (_titleFocus.hasFocus) _wantBodyFocus = false;
  }

  /// Key map for the editing surfaces. Formatting keys are bound in both
  /// editing modes (Normal and Markdown), inert only in Preview.
  /// Non-formatting shortcuts are settings-driven; formatting (Ctrl+B/I/U)
  /// remains hard-coded and excluded from customization.
  Map<ShortcutActivator, Intent> _editShortcuts() {
    final overrides = widget.settings?.shortcutOverrides ?? const {};
    SingleActivator a(ShortcutAction action) => activatorFor(action, overrides);
    // When find bar is open, Enter navigates matches, not list continuation.
    if (_findOpen) {
      return {
        const SingleActivator(LogicalKeyboardKey.enter): const FindNextIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter):
            const FindNextIntent(),
        const SingleActivator(LogicalKeyboardKey.enter, shift: true):
            const FindPrevIntent(),
        const SingleActivator(LogicalKeyboardKey.escape):
            const CloseFindIntent(),
        a(ShortcutAction.openFind): const OpenFindIntent(),
        a(ShortcutAction.selectWord): const SelectWordIntent(),
        a(ShortcutAction.copySelection): CopySelectionTextIntent.copy,
        a(ShortcutAction.pasteSelection): const PasteTextIntent(
          SelectionChangedCause.keyboard,
        ),
        if (widget.controller.mode != EditorMode.preview) ...{
          const SingleActivator(LogicalKeyboardKey.keyB, control: true):
              const FormatIntent(FormatKind.bold),
          const SingleActivator(LogicalKeyboardKey.keyI, control: true):
              const FormatIntent(FormatKind.italic),
          const SingleActivator(LogicalKeyboardKey.keyU, control: true):
              const FormatIntent(FormatKind.underline),
        },
      };
    }
    return {
      a(ShortcutAction.continueList): const ContinueListIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadEnter):
          const ContinueListIntent(),
      a(ShortcutAction.openFind): const OpenFindIntent(),
      a(ShortcutAction.selectWord): const SelectWordIntent(),
      a(ShortcutAction.copySelection): CopySelectionTextIntent.copy,
      a(ShortcutAction.pasteSelection): const PasteTextIntent(
        SelectionChangedCause.keyboard,
      ),
      if (widget.controller.mode != EditorMode.preview) ...{
        // Formatting (Ctrl+B/I/U) excluded from customization.
        const SingleActivator(LogicalKeyboardKey.keyB, control: true):
            const FormatIntent(FormatKind.bold),
        const SingleActivator(LogicalKeyboardKey.keyI, control: true):
            const FormatIntent(FormatKind.italic),
        const SingleActivator(LogicalKeyboardKey.keyU, control: true):
            const FormatIntent(FormatKind.underline),
      },
    };
  }

  /// Body text style for the current mode, honoring the settings' base size.
  TextStyle _bodyStyle(ThemeData theme) {
    final base = widget.baseFontSize ?? 16.0;
    if (widget.controller.mode == EditorMode.markdown) {
      return safeMono(
        TextStyle(
          fontSize: base - 1.5,
          height: 24 / (base - 1.5),
          fontWeight: FontWeight.w400,
          color: theme.colorScheme.onSurface,
        ),
      );
    }
    return safeHanken(
      TextStyle(
        fontSize: base,
        height: 26 / base,
        fontWeight: FontWeight.w400,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  void _applyFormat(FormatIntent intent) {
    final selection = _body.selection;
    if (!selection.isValid || selection.start < 0 || selection.end < 0) return;

    final result = toggleWrap(
      text: _body.text,
      selStart: selection.start,
      selEnd: selection.end,
      open: intent.kind.open,
      close: intent.kind.close,
    );
    // A bare caret parks back on the character it started on (so the toggle
    // visibly does nothing to caret position); a real selection keeps the
    // formatted range highlighted so a second press can toggle it back off.
    final next = selection.isCollapsed
        ? TextSelection.collapsed(offset: result.caret)
        : TextSelection(
            baseOffset: result.selStart,
            extentOffset: result.selEnd,
          );
    _body.value = TextEditingValue(text: result.text, selection: next);
    widget.controller.updateBody(result.text);
  }

  /// Enter handler: continues markdown lists (story 15); outside lists a
  /// plain newline is inserted so normal typing is unaffected.
  void _handleEnter() {
    final selection = _body.selection;
    if (!selection.isValid) return;
    final start = selection.start.clamp(0, _body.text.length);
    final end = selection.end.clamp(0, _body.text.length);
    final result = continueList(text: _body.text, selStart: start, selEnd: end);
    if (result != null) {
      _body.value = TextEditingValue(
        text: result.text,
        selection: TextSelection.collapsed(offset: result.selStart),
      );
    } else if (start != end) {
      // Selection non-collapsed but not a list: replace with plain newline.
      final replaced = _body.text.replaceRange(start, end, '\n');
      _body.value = TextEditingValue(
        text: replaced,
        selection: TextSelection.collapsed(offset: start + 1),
      );
    } else {
      final caret = start;
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
    if (selection.isValid &&
        selection.start >= 0 &&
        selection.end > selection.start) {
      prefill = _body.text.substring(selection.start, selection.end);
    }
    _findCtrl?.dispose();
    _findCtrl = TextEditingController(text: prefill);
    setState(() => _findOpen = true);
    _body.addListener(_recomputeFind);
    _runFind(prefill);
  }

  void _closeFind() {
    _body.removeListener(_recomputeFind);
    _findCtrl?.dispose();
    _findCtrl = null;
    setState(() => _findOpen = false);
    _bodyFocus.requestFocus();
  }

  void _recomputeFind() {
    if (!_findOpen || _lastQuery.isEmpty) return;
    final newMatches = matchOffsets(_body.text, _lastQuery);
    // Preserve index clamped.
    if (newMatches.isEmpty) {
      _matches = [];
      _matchIndex = -1;
    } else {
      _matches = newMatches;
      _matchIndex = _matchIndex.clamp(0, _matches.length - 1);
    }
    if (mounted) setState(() {});
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
    _bodyFocus.requestFocus();
    if (mounted) setState(() {});
  }

  void _jumpToCurrentMatch() {
    if (_matchIndex < 0 || _matchIndex >= _matches.length) return;
    final start = _matches[_matchIndex];
    _body.value = TextEditingValue(
      text: _body.text,
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + _lastQuery.length,
      ),
    );
  }

  String get _counterLabel =>
      _matches.isEmpty ? '0/0' : '${_matchIndex + 1}/${_matches.length}';

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
    _bodyFocus.removeListener(_onBodyFocusChange);
    _titleFocus.removeListener(_onTitleFocusChange);
    _body.removeListener(_recomputeFind);
    _body.dispose();
    _title.dispose();
    _bodyFocus.dispose();
    _previewFocus.dispose();
    _titleFocus.dispose();
    _findCtrl?.dispose();
    super.dispose();
  }

  Future<void> _commitRename(String newTitle) async {
    final current = widget.controller.current;
    if (current == null) return;
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty ||
        trimmed == extractTitle(current.body, current.fileName)) {
      _title.text = current.title;
      return;
    }
    await widget.controller.flush();
    await widget.controller.renameCurrent(trimmed);
  }

  Future<void> _insertDroppedImages(List<dynamic> items) async {
    setState(() => _dragging = false);
    for (final item in items) {
      if (item is! DropItemFile) continue;
      final path = item.path;
      if ([
        '.png',
        '.jpg',
        '.jpeg',
        '.gif',
        '.webp',
      ].contains(p.extension(path).toLowerCase())) {
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
        (theme.brightness == Brightness.dark
            ? quireColorsDark
            : quireColorsLight);
    final tags = extractTags(_body.text);
    final words = _body.text.trim().isEmpty
        ? 0
        : _body.text.trim().split(RegExp(r'\s+')).length;

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
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
            ),
            child: widget.focusMode
                ? Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 740),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _title,
                              focusNode: _titleFocus,
                              style: safeBricolage(
                                TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  height: 30 / 24,
                                  letterSpacing: -0.3,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Title',
                                hintStyle: safeBricolage(
                                  TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: quire.textTertiary,
                                  ),
                                ),
                                filled: false,
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                              onSubmitted: _commitRename,
                              onEditingComplete: () =>
                                  _commitRename(_title.text),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const SizedBox(width: 8),
                          ModeSwitch(
                            mode: controller.mode,
                            onSelected: controller.setMode,
                          ),
                        ],
                      ),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _title,
                          focusNode: _titleFocus,
                          style: safeBricolage(
                            TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              height: 30 / 24,
                              letterSpacing: -0.3,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Title',
                            hintStyle: safeBricolage(
                              TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: quire.textTertiary,
                              ),
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
                      const SizedBox(width: 8),
                      ModeSwitch(
                        mode: controller.mode,
                        onSelected: controller.setMode,
                      ),
                    ],
                  ),
          ),
          // Find bar (story 14)
          if (_findOpen && _findCtrl != null)
            FindBar(
              controller: _findCtrl!,
              counter: _counterLabel,
              hasMatches: _matches.isNotEmpty,
              onChanged: _runFind,
              onNext: _nextMatch,
              onPrev: _prevMatch,
              onClose: _closeFind,
              settings: widget.settings,
            ),
          // Tag chips: highlighter washes
          if (tags.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '#$tag',
                        style: safeHanken(
                          TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 16 / 12.5,
                            color: theme.colorScheme.onSurface,
                          ),
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
              // Top-left aligned (feedback F3 + "top left aligned"): the preview
              // scroll view shrink-wraps its content; Center would float it mid
              // pane. The 680px column is now anchored to the left gutter
              // instead of hovering in the middle of a wide window.
              child: Align(
                alignment: widget.focusMode
                    ? Alignment.topCenter
                    : Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: widget.focusMode ? 740 : 680,
                  ),
                  child: switch (controller.mode) {
                    EditorMode.preview => Builder(
                      builder: (context) {
                        final overrides =
                            widget.settings?.shortcutOverrides ?? const {};
                        final cycleActivator = activatorFor(
                          ShortcutAction.cycleEditorMode,
                          overrides,
                        );
                        return Focus(
                          focusNode: _previewFocus,
                          autofocus: true,
                          child: Shortcuts(
                            shortcuts: {
                              cycleActivator: const CycleEditorModeIntent(),
                            },
                            child: Actions(
                              actions: {
                                CycleEditorModeIntent:
                                    CallbackAction<CycleEditorModeIntent>(
                                      onInvoke: (intent) {
                                        widget.controller.cycleMode();
                                        return null;
                                      },
                                    ),
                              },
                              child: MarkdownPreview(
                                body: _body.text,
                                vaultRoot: controller.vaultRoot,
                                baseFontSize: widget.baseFontSize ?? 16,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    _ => Shortcuts(
                      shortcuts: _editShortcuts(),
                      child: Actions(
                        actions: {
                          FormatIntent: CallbackAction<FormatIntent>(
                            onInvoke: (intent) => _applyFormat(intent),
                          ),
                          ContinueListIntent:
                              CallbackAction<ContinueListIntent>(
                                onInvoke: (intent) => _handleEnter(),
                              ),
                          OpenFindIntent: CallbackAction<OpenFindIntent>(
                            onInvoke: (intent) => _openFind(),
                          ),
                          SelectWordIntent: CallbackAction<SelectWordIntent>(
                            onInvoke: (intent) => _selectWord(),
                          ),
                          FindNextIntent: CallbackAction<FindNextIntent>(
                            onInvoke: (intent) {
                              _nextMatch();
                              return null;
                            },
                          ),
                          FindPrevIntent: CallbackAction<FindPrevIntent>(
                            onInvoke: (intent) {
                              _prevMatch();
                              return null;
                            },
                          ),
                          CloseFindIntent: CallbackAction<CloseFindIntent>(
                            onInvoke: (intent) {
                              _closeFind();
                              return null;
                            },
                          ),
                        },
                        child: DropTarget(
                          onDragDone: (details) =>
                              _insertDroppedImages(details.files),
                          onDragEntered: (_) =>
                              setState(() => _dragging = true),
                          onDragExited: (_) =>
                              setState(() => _dragging = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            decoration: BoxDecoration(
                              color: _dragging
                                  ? theme.colorScheme.secondaryContainer
                                        .withValues(alpha: 0.3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                QuireRadius.m,
                              ),
                              border: _dragging
                                  ? Border.all(
                                      color: theme.colorScheme.primary,
                                      width: 1.6,
                                    )
                                  : Border.all(color: Colors.transparent),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              key: const Key('editor-body'),
                              controller: _body,
                              focusNode: _bodyFocus,
                              onChanged: controller.updateBody,
                              // Quire-styled cut/copy/paste menu (round 6):
                              // defer into our own overlay route; the inline
                              // toolbar slot stays empty. The gate keeps
                              // builder re-fires from stacking menus.
                              contextMenuBuilder: (context, editableState) {
                                if (_editMenuOpen) {
                                  return const SizedBox.shrink();
                                }
                                _editMenuOpen = true;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!context.mounted) {
                                    _editMenuOpen = false;
                                    return;
                                  }
                                  unawaited(
                                    showBodyEditMenu(
                                      context,
                                      editableState,
                                    ).whenComplete(() => _editMenuOpen = false),
                                  );
                                });
                                return const SizedBox.shrink();
                              },
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              keyboardType: TextInputType.multiline,
                              style: _bodyStyle(theme),
                              decoration: InputDecoration(
                                hintText: 'Take a note…  Type #tags, drag images, write in Markdown.',
                                hintStyle: safeHanken(
                                  TextStyle(
                                    fontSize: 16,
                                    height: 26 / 16,
                                    color: quire.textTertiary.withValues(
                                      alpha: 0.9,
                                    ),
                                  ),
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
          StatusFooter(controller: controller, words: words),
        ],
      ),
    );
  }
}
