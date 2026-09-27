import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sheaf/ui/common/widgets/hover_scrollbar.dart';

import '../../data/markdown_parser.dart';
import '../../logic/editor_controller.dart';
import '../../logic/find_controller.dart';
import '../../logic/formatting.dart';
import '../../logic/image_link.dart';
import '../../logic/line_edit.dart';
import '../../logic/list_continuation.dart';
import '../../logic/vault_controller.dart';
import '../../models/note.dart';
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
import 'widgets/go_to_top_fab.dart';
import 'widgets/mode_switch.dart';
import 'widgets/placeholder.dart';
import 'widgets/status_footer.dart';
import 'widgets/tag_chip_bar.dart';

export 'intents.dart';

/// Suppresses the [TextField]'s built-in overlay scrollbar so the body can
/// supply its own padded [Scrollbar] (mirroring preview mode).
///
/// Load-bearing: material [TextField] exposes no `scrollBehavior` parameter,
/// and its internal `EditableText` forces
/// `ScrollConfiguration.of(context).copyWith(scrollbars: true)` for multiline
/// fields — so an ancestor `copyWith(scrollbars: false)` is overwritten back
/// to true. A custom behavior survives because `_WrappedScrollBehavior`
/// delegates `buildScrollbar` to this override even when the flag is true.
class _NoScrollbarBehavior extends MaterialScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

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
    this.vaultController,
  });

  /// Null while no vault is open; renders the placeholder.
  final EditorController? controller;

  /// Injectable copier into `<vault>/.attachments/`; defaults to the
  /// controller's repository call. Tests inject a fake to stay zone-safe.
  final Future<String> Function(File file)? importImage;

  /// Editor body base size from settings (story 16); null = 16.
  final double? baseFontSize;

  /// When true, the body column is centered and slightly wider (focus mode).
  final bool focusMode;

  /// Settings for shortcut customization; if null, defaults are used.
  final AppSettings? settings;

  /// Vault controller for tag-filter focus (tag chips).
  final VaultController? vaultController;
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
          vaultController: vaultController,
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
    this.vaultController,
  });

  final EditorController controller;
  final Future<String> Function(File file)? importImage;
  final double? baseFontSize;
  final bool focusMode;
  final AppSettings? settings;
  final VaultController? vaultController;

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
  late final FocusNode _findFocus;

  /// Focus *intent*: true once the body has been focused, sticky across mode
  /// switches (Preview unmounts the TextField, so hasFocus is false on return).
  bool _wantBodyFocus = false;
  late final FocusNode _titleFocus;
  late ScrollController _editScroll;
  late ScrollController _previewScroll;
  String? _loadedPath;
  Note? _loadedNote;
  bool _loading = false;
  bool _committing = false;
  EditorMode? _syncedMode;
  bool _dragging = false;
  bool _findOpen = false;
  TextEditingController? _findCtrl;
  List<int> _matches = [];
  int _matchIndex = -1;
  String _lastQuery = '';
  bool _caseSensitive = false;

  /// Suppresses undo-history recording while the pane is programmatically
  /// applying text (undo/redo). See [_undo]/[_redo].
  bool _suppressHistory = false;

  /// When true, the next [_load] skips restoring the cached caret — the
  /// note opens at offset 0. Used on the first load after a fresh pane
  /// mount (i.e. right after app start) so a long document's caret doesn't
  /// land at the bottom from a previous session. Mid-session note switches
  /// still restore the caret to where the user left off.
  bool _skipCaretRestoreOnNextLoad = true;

  /// Records a body change and its current selection into the per-note
  /// undo history. Called from the TextField's onChanged and from every
  /// programmatic body change (format, indent, list continuation, image
  /// insert). Skipped when [_suppressHistory] is set — that's the
  /// undo/redo path, which already has the history to restore.
  ///
  /// [coalesce] lets the caller decide whether this edit may merge into
  /// the user's preceding typing run (default true — typing). Programmatic
  /// edits (format, indent, list, image) pass false so each one is its
  /// own undo step.
  void _recordBodyChange({bool coalesce = true}) {
    if (_suppressHistory) return;
    widget.controller.updateBody(_body.value.text, selection: _body.selection, coalesce: coalesce);
  }

  /// Undo handler. Restores the previous text and caret position; suppresses
  /// further recording so the undo itself doesn't pollute the stack.
  void _undo() {
    final entry = widget.controller.undoCurrent();
    if (entry == null) return;
    _suppressHistory = true;
    _body.value = TextEditingValue(
      text: entry.text,
      selection: entry.selection.isValid
          ? entry.selection
          : TextSelection.collapsed(offset: entry.text.length),
    );
    _suppressHistory = false;
  }

  /// Redo handler. Mirror of [_undo].
  void _redo() {
    final entry = widget.controller.redoCurrent();
    if (entry == null) return;
    _suppressHistory = true;
    _body.value = TextEditingValue(
      text: entry.text,
      selection: entry.selection.isValid
          ? entry.selection
          : TextSelection.collapsed(offset: entry.text.length),
    );
    _suppressHistory = false;
  }

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
    _findFocus = FocusNode(debugLabel: 'find');
    _titleFocus = FocusNode();
    _titleFocus.addListener(_onTitleFocusChange);
    _syncedMode = widget.controller.mode;
    final path = widget.controller.current?.path;
    final cachedPreview =
        path != null ? widget.controller.previewScrollFor(path) ?? 0.0 : 0.0;
    final cachedEdit =
        path != null ? widget.controller.editScrollFor(path) ?? 0.0 : 0.0;
    _editScroll = ScrollController(initialScrollOffset: cachedEdit);
    _editScroll.addListener(_onBodyScroll);
    _previewScroll = ScrollController(initialScrollOffset: cachedPreview);
    _previewScroll.addListener(_onBodyScroll);
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
    final oldPath = _loadedPath;
    final newPath = widget.controller.current?.path;
    final noteChanged = oldPath != newPath;
    if (noteChanged) _load();
    if (_syncedMode != widget.controller.mode || noteChanged) {
      final fromPreview = _syncedMode == EditorMode.preview;
      final fromEditable = _syncedMode == EditorMode.normal || _syncedMode == EditorMode.markdown;
      final toPreview = widget.controller.mode == EditorMode.preview;
      final path = newPath;
      // Capture the outgoing branch's live scroll offset BEFORE we
      // dispose its controller - after dispose the position is gone
      // and we'd lose the user's scroll for the note. Save to the OLD
      // note's path, not the new one: the controller still holds the
      // old note's scroll position, and saving under the new path
      // would corrupt the new note's cache.
      if (oldPath != null) {
        if (fromPreview && _previewScroll.hasClients) {
          widget.controller.savePreviewScroll(_previewScroll.offset, path: oldPath);
        } else if (fromEditable && _editScroll.hasClients) {
          widget.controller.saveEditScroll(_editScroll.offset, path: oldPath);
        }
      }
      // Replace the incoming branch's controller with a fresh one
      // seeded from the per-note cache. Rebuild on mode change OR
      // note change - same-mode note switch would otherwise reuse the
      // old controller with the old scroll. Cache miss defaults to 0.
      if (toPreview) {
        final cached =
            path != null ? widget.controller.previewScrollFor(path) ?? 0.0 : 0.0;
        _previewScroll.removeListener(_onBodyScroll);
        _previewScroll.dispose();
        _previewScroll = ScrollController(initialScrollOffset: cached);
        _previewScroll.addListener(_onBodyScroll);
      } else {
        final cached =
            path != null ? widget.controller.editScrollFor(path) ?? 0.0 : 0.0;
        _editScroll.removeListener(_onBodyScroll);
        _editScroll.dispose();
        _editScroll = ScrollController(initialScrollOffset: cached);
        _editScroll.addListener(_onBodyScroll);
      }
      _syncedMode = widget.controller.mode;
      _body.highlight = _syncedMode == EditorMode.normal;
      final editable = _syncedMode != EditorMode.preview;
      if (mounted) {
        setState(() {});
        // Spec story 51/52: the new controller's initialScrollOffset honors
        // the cached value at attach time, so there's no flicker at first
        // paint. EditableText's showCaretOnScreen animation still fires
        // after focus is restored and can override the offset, so this
        // re-asserts the target for a bounded number of hops to win the
        // race. Preview mode needs only 1 hop (no caret animation); edit
        // mode needs ~12 hops to span the ~100ms animation. Cache miss
        // coalesces to 0 (the controller's construction value), so the
        // retry chain is a no-op for uncached notes.
        final restoredPath = widget.controller.current?.path;
        if (restoredPath != null) {
          final targetScroll = _syncedMode == EditorMode.preview ? _previewScroll : _editScroll;
          final cached = _syncedMode == EditorMode.preview
              ? widget.controller.previewScrollFor(restoredPath) ?? 0.0
              : widget.controller.editScrollFor(restoredPath) ?? 0.0;
          _scheduleScrollRestore(targetScroll, restoredPath, cached, _syncedMode == EditorMode.preview ? 1 : 12);
        }
      }
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

  /// Saves the current preview scroll offset to the per-note cache when
  /// the user scrolls in preview mode. Uncached offsets (edit-mode
  /// scrolls) are ignored — the cache is preview-only. Note that
  /// programmatic [ScrollPosition.jumpTo] uses forcePixels and does not
  /// notify listeners, so this listener covers user-driven scrolls;
  /// `_syncFromController` captures the offset on leaving preview for
  /// programmatic jumps.
  /// Re-asserts a scroll target on [scroll] for a bounded number of
  /// post-frame hops. Used to win a race against EditableText's
  /// showCaretOnScreen animation, which fires after focus is restored
  /// and animates the offset to the caret's rect. The target is
  /// snapshotted at call time so later cache writes don't corrupt it.
  ///
  /// [scroll] is captured at call time so the chain keeps targeting the
  /// same controller even if the mode changes mid-chain — _activeScroll
  /// would return the new mode's controller, which is wrong.
  ///
  /// Preview mode needs only one hop (no caret animation). Edit mode
  /// needs enough hops to span the ~100ms caret animation.
  void _scheduleScrollRestore(
    ScrollController scroll,
    String path,
    double offset,
    int attemptsLeft,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || attemptsLeft <= 0) return;
      if (_loadedPath != path) return;
      if (!scroll.hasClients) return;
      final pos = scroll.position;
      if (pos.pixels != offset) pos.jumpTo(offset);
      _scheduleScrollRestore(scroll, path, offset, attemptsLeft - 1);
    });
  }

  void _onBodyScroll() {
    final mode = widget.controller.mode;
    if (mode != EditorMode.preview && mode != EditorMode.normal && mode != EditorMode.markdown) {
      return;
    }
    // Use _loadedPath, not controller.current — a note switch advances
    // controller.current before the outgoing note's scroll listener has
    // settled, so a late _onBodyScroll would save under the wrong path.
    final path = _loadedPath;
    if (path == null) return;
    if (mode == EditorMode.preview) {
      widget.controller.savePreviewScroll(_previewScroll.offset);
    } else {
      widget.controller.saveEditScroll(_editScroll.offset);
    }
  }

  /// Losing focus commits the pending rename — clicking the body, Tab out, or
  /// opening another note all commit at once instead of waiting for Enter.
  /// Enter still commits immediately (`onSubmitted`/`onEditingComplete`); the
  /// `_commitRename` guards make the double call after an Enter no-op.
  void _onTitleFocusChange() {
    if (_titleFocus.hasFocus) {
      _wantBodyFocus = false;
      return;
    }
    _commitTitleRename();
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
        const SingleActivator(LogicalKeyboardKey.numpadEnter): const FindNextIntent(),
        const SingleActivator(LogicalKeyboardKey.enter, shift: true): const FindPrevIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const CloseFindIntent(),
        a(ShortcutAction.openFind): const OpenFindIntent(),
        a(ShortcutAction.selectWord): const SelectWordIntent(),
        a(ShortcutAction.copySelection): CopySelectionTextIntent.copy,
        a(ShortcutAction.pasteSelection): const PasteTextIntent(SelectionChangedCause.keyboard),
        if (widget.controller.mode != EditorMode.preview) ...{
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
    }
    return {
      a(ShortcutAction.continueList): const ContinueListIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadEnter): const ContinueListIntent(),
      a(ShortcutAction.openFind): const OpenFindIntent(),
      a(ShortcutAction.selectWord): const SelectWordIntent(),
      a(ShortcutAction.copySelection): CopySelectionTextIntent.copy,
      a(ShortcutAction.pasteSelection): const PasteTextIntent(SelectionChangedCause.keyboard),
      // Undo/redo: bound explicitly here so they dispatch to the pane's
      // custom UndoHistory (per-note cache). Flutter's default text editing
      // shortcuts bind Ctrl+Z / Ctrl+Shift+Z to the TextField's own internal
      // stack; overriding at this scope gives our intent priority.
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true): const UndoIntent(),
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
          const RedoIntent(),
      if (widget.controller.mode != EditorMode.preview) ...{
        // Formatting (Ctrl+B/I/U) excluded from customization.
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): const FormatIntent(
          FormatKind.bold,
        ),
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): const FormatIntent(
          FormatKind.italic,
        ),
        const SingleActivator(LogicalKeyboardKey.keyU, control: true): const FormatIntent(
          FormatKind.underline,
        ),
        const SingleActivator(LogicalKeyboardKey.tab): const IndentIntent(indentIn: true),
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): const IndentIntent(
          indentIn: false,
        ),
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

  void _applyIndent(IndentIntent intent) {
    final selection = _body.selection;
    if (!selection.isValid) return;
    final result = intent.indentIn
        ? indentBlock(text: _body.text, selStart: selection.start, selEnd: selection.end)
        : outdentBlock(text: _body.text, selStart: selection.start, selEnd: selection.end);
    if (result.text == _body.text) return;
    final next = result.selStart == result.selEnd
        ? TextSelection.collapsed(offset: result.selStart)
        : TextSelection(baseOffset: result.selStart, extentOffset: result.selEnd);
    _body.value = TextEditingValue(text: result.text, selection: next);
    _recordBodyChange(coalesce: false);
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
        : TextSelection(baseOffset: result.selStart, extentOffset: result.selEnd);
    _body.value = TextEditingValue(text: result.text, selection: next);
    _recordBodyChange(coalesce: false);
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
      _recordBodyChange(coalesce: false);
      return;
    }
    if (start != end) {
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
    _recordBodyChange(coalesce: false);
    // Spec story 43: a plain newline whose caret lands at the very end of the
    // document must reveal the blank line before any character is typed. List
    // continuation is excluded (returns above). Post-frame so maxScrollExtent
    // reflects the freshly inserted newline.
    if (_body.selection.isValid && _body.selection.start >= _body.text.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_editScroll.hasClients) return;
        _editScroll.jumpTo(_editScroll.position.maxScrollExtent);
      });
    }
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
    _body.addListener(_recomputeFind);
    _runFind(prefill);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _findFocus.requestFocus();
    });
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
    final newMatches = matchOffsets(_body.text, _lastQuery, caseSensitive: _caseSensitive);
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
    _matches = matchOffsets(_body.text, _lastQuery, caseSensitive: _caseSensitive);
    _matchIndex = _matches.isEmpty ? -1 : 0;
    _jumpToCurrentMatch();
    if (mounted) setState(() {});
  }

  void _toggleCaseSensitive() {
    setState(() => _caseSensitive = !_caseSensitive);
    if (_lastQuery.isNotEmpty) _runFind(_lastQuery);
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

  void _focusTag(String tag) {
    final needle = '#$tag';
    final body = _body.text;
    // Find first occurrence, prefer word boundary.
    var idx = body.indexOf(needle);
    if (idx == -1) {
      // Fallback: case-insensitive search for tag without #
      idx = body.toLowerCase().indexOf(needle.toLowerCase());
    }
    if (idx == -1) return;
    // Expand to include trailing word chars if tag is followed by more word chars? Keep exact.
    final end = idx + needle.length;
    _body.value = TextEditingValue(
      text: body,
      selection: TextSelection(baseOffset: idx, extentOffset: end),
    );
    _bodyFocus.requestFocus();
    // Ensure the selection is visible (TextField auto-scrolls to selection).
  }

  Future<void> _load() async {
    if (_loading) return;
    final note = widget.controller.current;
    if (note == null || note.path == _loadedPath) return;
    _loading = true;
    try {
      // Remember the caret in the note we're leaving (in-memory only).
      final prev = _loadedNote;
      if (prev != null && _body.selection.isValid && _body.selection.baseOffset >= 0) {
        widget.controller.rememberCaret(prev.path, _body.selection.start);
      }
      // Spec story 45: switching notes while a title edit is pending must
      // not drop it. `open()` has already swapped `current` to the incoming
      // note, so a commit routed through `current` would rename the wrong
      // file; commit against the note the fields still hold, before
      // overwriting them.
      if (prev != null && _title.text != prev.title) {
        await _commitRename(_title.text, prev);
      }
      if (!mounted) return;
      _loadedPath = note.path;
      _loadedNote = note;
      _body.text = note.body;
      _title.text = note.title;
    } finally {
      _loading = false;
    }
    // Restore the last caret for this note (Task 7). When there is no
    // cached caret (or the first-load flag is set on a fresh pane mount),
    // place the caret at offset 0 so long documents open at the top —
    // EditableText would otherwise default to the end on focus.
    final skipRestore = _skipCaretRestoreOnNextLoad;
    _skipCaretRestoreOnNextLoad = false;
    final restored = skipRestore ? null : widget.controller.lastCaretFor(note.path);
    final caretOffset = restored != null ? restored.clamp(0, _body.text.length) : 0;
    _body.value = TextEditingValue(
      text: _body.text,
      selection: TextSelection.collapsed(offset: caretOffset),
      composing: TextRange.empty,
    );
    if (mounted) {
      setState(() {});
      // Spec story 44: opening a note places the caret in the body so
      // typing starts immediately. Post-frame because the text field is
      // not attached yet during initState. In Preview the preview
      // segment is focused; the sticky intent restores the caret when
      // the user returns to an edit mode.
      //
      // No jumpTo(0): the controllers are constructed with the cached
      // offset as initialScrollOffset (in _syncFromController), so the
      // first paint is at the right place. EditableText's
      // showCaretOnScreen animation then scrolls to the caret when
      // focus is requested; the retry hop chain in _syncFromController
      // re-asserts the cached offset to win that race.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final openMode = widget.controller.mode;
        if (openMode == EditorMode.preview) {
          _previewFocus.requestFocus();
          // Spec story 51: the preview ScrollController is constructed
          // with the cached offset as initialScrollOffset (see
          // _syncFromController / initState), so the preview branch
          // starts at the right place on first paint.
        } else {
          _wantBodyFocus = true;
          _bodyFocus.requestFocus();
          // Spec story 52: the edit ScrollController is constructed
          // with the cached offset as initialScrollOffset — the
          // editor branch starts at the right place on first paint.
        }
      });
    }
  }

  @override
  void dispose() {
    // Remember the caret of the note we're leaving if the pane is torn down
    // (mode rebuilds, focus toggle) without going through a note switch.
    final leaving = widget.controller.current;
    if (leaving != null && _body.selection.isValid && _body.selection.baseOffset >= 0) {
      widget.controller.rememberCaret(leaving.path, _body.selection.start);
    }
    widget.controller.removeListener(_syncFromController);
    _bodyFocus.removeListener(_onBodyFocusChange);
    _titleFocus.removeListener(_onTitleFocusChange);
    _body.removeListener(_recomputeFind);
    _body.dispose();
    _title.dispose();
    _bodyFocus.dispose();
    _previewFocus.dispose();
    _findFocus.dispose();
    _titleFocus.dispose();
    _editScroll.removeListener(_onBodyScroll);
    _editScroll.dispose();
    _previewScroll.removeListener(_onBodyScroll);
    _previewScroll.dispose();
    _findCtrl?.dispose();
    super.dispose();
  }

  /// Commits the rename of [target] to [newTitle]. [target] is passed rather
  /// than read from `current` so a commit racing a note switch still renames
  /// the note that was actually edited (spec story 45). Idempotent: empty or
  /// unchanged titles revert the field and skip the rename. On success the
  /// in-memory cache is advanced to the freshly-renamed note so a later
  /// commit — including the `_load` fired by the rename's own
  /// `notifyListeners` — does not try to rename the now-missing file.
  /// Guarded by `_committing`: a second commit racing the first would otherwise
  /// try to rename a file the first already moved (PathNotFoundException on
  /// the live vault). Both callers — Enter/blur via `_commitTitleRename` and
  /// a note switch via `_load` — funnel through here.
  Future<void> _commitRename(String newTitle, Note target) async {
    if (_committing) return;
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty || trimmed == extractTitle(target.body, target.fileName)) {
      _title.text = target.title;
      return;
    }
    _committing = true;
    try {
      await widget.controller.flush();
      await widget.controller.renameNoteAt(target.path, trimmed);
      // Pull the freshly-read note back into the cache. If `current` has
      // since moved on, keep the last cached note so the commit is still
      // recorded against the file the user was editing.
      if (_loadedNote?.path == target.path) {
        _loadedNote = widget.controller.current ?? _loadedNote;
        _loadedPath = _loadedNote?.path;
      }
    } finally {
      _committing = false;
    }
  }

  /// Enter / blur wrapper that commits against whatever the fields currently
  /// hold. Returns immediately if the pane shows no note; re-entrance is
  /// handled inside `_commitRename` so the same guard covers `_load`-driven
  /// commits and a rapid Enter+blur pair.
  Future<void> _commitTitleRename() async {
    final target = _loadedNote;
    if (target == null) return;
    await _commitRename(_title.text, target);
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
  /// the cursor (or end of the body). The vault-relative path is URL-encoded
  /// so filenames with whitespace (e.g. `My Photo.png`) round-trip through
  /// the markdown parser — `![x](attachments/My Photo.png)` is rejected
  /// because spaces aren't valid in markdown URLs, but
  /// `![x](attachments/My%20Photo.png)` is. The preview resolver decodes
  /// the URL back to a filesystem path before lookup.
  Future<void> _insertImage(File file) async {
    final doImport = widget.importImage ?? widget.controller.importAttachment;
    final rel = await doImport(file);
    final encoded = Uri.encodeFull(rel);
    final name = p.basenameWithoutExtension(rel);
    final result = insertImageLink(
      body: _body.text,
      link: '![$name]($encoded)',
      offset: _body.selection.baseOffset,
    );
    _body.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.caret),
    );
    _recordBodyChange(coalesce: false);
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
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              border: (tags.isEmpty && _findOpen == false && _findCtrl == null)
                  ? Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    )
                  : null,
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
                              onSubmitted: (_) => _commitTitleRename(),
                              onEditingComplete: _commitTitleRename,
                            ),
                          ),
                          ModeSwitch(mode: controller.mode, onSelected: controller.setMode),
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
                          onSubmitted: (_) => _commitTitleRename(),
                          onEditingComplete: _commitTitleRename,
                        ),
                      ),
                      ModeSwitch(mode: controller.mode, onSelected: controller.setMode),
                    ],
                  ),
          ),
          // Tag bar container
          if (tags.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                border: (_findOpen == false && _findCtrl == null)
                    ? Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                      )
                    : null,
              ),
              child: Align(
                alignment: widget.focusMode ? Alignment.topCenter : Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: widget.focusMode ? 740 : double.infinity),
                  child: TagChipBar(tags: tags, onTap: _focusTag),
                ),
              ),
            ),
          // Find bar
          if (_findOpen && _findCtrl != null)
            Container(
              key: const Key('find-bar'),
              padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Align(
                alignment: widget.focusMode ? Alignment.topCenter : Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: widget.focusMode ? 740 : double.infinity),
                  child: FindBar(
                    controller: _findCtrl!,
                    focusNode: _findFocus,
                    counter: _counterLabel,
                    hasMatches: _matches.isNotEmpty,
                    onChanged: _runFind,
                    onNext: _nextMatch,
                    onPrev: _prevMatch,
                    onClose: _closeFind,
                    settings: widget.settings,
                    caseSensitive: _caseSensitive,
                    onCaseSensitiveChanged: (_) => _toggleCaseSensitive(),
                  ),
                ),
              ),
            ),
          // Body
          Expanded(
            child: Align(
              alignment: widget.focusMode ? Alignment.topCenter : Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.focusMode ? 740 : double.infinity),
                child: switch (controller.mode) {
                  EditorMode.preview => Stack(
                    alignment: Alignment.topLeft,
                    children: [
                      Builder(
                        builder: (context) {
                          final overrides = widget.settings?.shortcutOverrides ?? const {};
                          final cycleActivator = activatorFor(
                            ShortcutAction.cycleEditorMode,
                            overrides,
                          );
                          return Focus(
                            focusNode: _previewFocus,
                            autofocus: true,
                            child: Shortcuts(
                              shortcuts: {cycleActivator: const CycleEditorModeIntent()},
                              child: Actions(
                                actions: {
                                  CycleEditorModeIntent: CallbackAction<CycleEditorModeIntent>(
                                    onInvoke: (intent) {
                                      widget.controller.cycleMode();
                                      return null;
                                    },
                                  ),
                                },
                                child: ScrollConfiguration(
                                  behavior: const _NoScrollbarBehavior(),
                                  child: HoverScrollbar(
                                    child: Scrollbar(
                                      interactive: true,
                                      controller: _previewScroll,
                                      child: MarkdownPreview(
                                        scrollController: _previewScroll,
                                        body: _body.text,
                                        vaultRoot: controller.vaultRoot,
                                        baseFontSize: widget.baseFontSize ?? 16,
                                        previewPadding: widget.focusMode
                                            ? const EdgeInsets.fromLTRB(0, 8, 24, 10)
                                            : const EdgeInsets.fromLTRB(24, 8, 24, 10),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      GoToTopFab(scrollController: _previewScroll),
                    ],
                  ),
                  _ => Shortcuts(
                    shortcuts: _editShortcuts(),
                    child: Actions(
                      actions: {
                        FormatIntent: CallbackAction<FormatIntent>(
                          onInvoke: (intent) => _applyFormat(intent),
                        ),
                        IndentIntent: CallbackAction<IndentIntent>(
                          onInvoke: (intent) => _applyIndent(intent),
                        ),
                        UndoIntent: CallbackAction<UndoIntent>(
                          onInvoke: (intent) {
                            _undo();
                            return null;
                          },
                        ),
                        RedoIntent: CallbackAction<RedoIntent>(
                          onInvoke: (intent) {
                            _redo();
                            return null;
                          },
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
                          // TextField's inner overlay scrollbar cannot take
                          // padding (it paints over the text) and wrapping
                          // the field in a second Scrollbar doubles it.
                          // _NoScrollbarBehavior kills the inner one; the
                          // outer Scrollbar + right padding reserves the
                          // gutter, mirroring preview mode above.
                          child: ScrollConfiguration(
                            behavior: const _NoScrollbarBehavior(),
                            child: HoverScrollbar(
                              child: Scrollbar(
                                interactive: true,
                                controller: _editScroll,
                                child: TextField(
                                  key: const Key('editor-body'),
                                  controller: _body,
                                  focusNode: _bodyFocus,
                                  scrollController: _editScroll,
                                  onChanged: (_) => _recordBodyChange(),
                                  // Quire-styled cut/copy/paste menu (round 6):
                                  // defer into our own overlay route; the inline
                                  // toolbar slot stays empty. The gate keeps
                                  // builder re-fires from stacking menus.
                                  contextMenuBuilder: (context, editableState) {
                                    if (_editMenuOpen) {
                                      return const SizedBox.shrink();
                                    }
                                    _editMenuOpen = true;
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
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
                                  expands: false,
                                  textAlignVertical: TextAlignVertical.top,
                                  keyboardType: TextInputType.multiline,
                                  // v0.3.1 Task 3: the non-web default is
                                  // ui.BoxWidthStyle.max, which pads every selected
                                  // line's highlight out to the widest line in the
                                  // paragraph. tight hugs each line's glyph run, so a
                                  // multi-line selection stops painting the empty
                                  // tail of short lines.
                                  selectionWidthStyle: ui.BoxWidthStyle.tight,
                                  style: _bodyStyle(theme),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Take a note…  Type #tags, drag images, write in Markdown.',
                                    hintStyle: safeHanken(
                                      TextStyle(
                                        fontSize: 16,
                                        height: 26 / 16,
                                        color: quire.textTertiary.withValues(alpha: 0.9),
                                      ),
                                    ),
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: widget.focusMode
                                        ? const EdgeInsets.fromLTRB(0, 16, 18, 16)
                                        : const EdgeInsets.fromLTRB(24, 16, 18, 16),
                                  ),
                                  cursorColor: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                },
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
