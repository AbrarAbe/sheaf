import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show TextSelection;
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/logic/undo_history.dart';
import 'package:sheaf/models/note.dart';
import 'package:sheaf/models/settings.dart';

/// Save lifecycle of the open note.
enum EditorStatus { clean, dirty, saving, saved }

/// Owns all writes for the currently open note.
///
/// Single-writer rule: only this controller writes the file being edited,
/// which keeps autosave from racing renames or deletes handled elsewhere.
class EditorController extends ChangeNotifier {
  EditorController({
    required this._vault,
    this.autosaveDelay = const Duration(seconds: 1),
    this.initialMode = EditorMode.normal,
    this.onModeChanged,
  });

  final VaultRepository _vault;

  /// Debounce window between the last keystroke and the write.
  final Duration autosaveDelay;

  /// Mode the editor opens in; persisted by the shell via settings.
  final EditorMode initialMode;

  /// Called after a real mode change so the shell can persist it.
  final void Function(EditorMode mode)? onModeChanged;

  Note? _current;
  String _body = '';
  Timer? _timer;
  EditorStatus _status = EditorStatus.clean;
  DateTime? _lastSavedAt;
  late EditorMode _mode = initialMode;

  /// In-memory record of the last body caret offset per note path. Never
  /// written to disk — it only survives the current session so reopening or
  /// cycling a note can return the caret to where the user left off.
  final Map<String, int> _caretByPath = {};

  /// In-memory record of the last preview scroll offset per note path.
  /// Written when the user scrolls the preview surface; restored when
  /// they return to preview (mode switch or note reopen) so the viewport
  /// lands where they left it instead of jumping back to the top.
  /// Uncached notes start at 0 — the default.
  final Map<String, double> _previewScrollByPath = {};

  /// Remembers the current preview scroll offset for the open note.
  /// Called on mode switch away from Preview.
  void savePreviewScroll(double offset) {
    final path = _current?.path;
    if (path == null) return;
    _previewScrollByPath[path] = offset;
  }

  /// The last remembered preview scroll offset for [path], or null when
  /// none is known (an uncached note starts at 0).
  double? previewScrollFor(String path) => _previewScrollByPath[path];

  /// Per-note undo/redo history. Each note has an independent stack;
  /// switching notes swaps which stack is active. Histories are in-memory
  /// only — closing and reopening the app starts a fresh session.
  final Map<String, UndoHistory> _historyByPath = {};

  Note? get current => _current;
  String get body => _body;
  EditorStatus get status => _status;

  /// Which surface the editor renders right now (spec story 12).
  EditorMode get mode => _mode;

  /// Switches surfaces; no-op when [value] equals the current mode.
  void setMode(EditorMode value) {
    if (value == _mode) return;
    _mode = value;
    onModeChanged?.call(value);
    notifyListeners();
  }

  void cycleMode() {
    final next = switch (_mode) {
      EditorMode.normal => EditorMode.markdown,
      EditorMode.markdown => EditorMode.preview,
      EditorMode.preview => EditorMode.normal,
    };
    setMode(next);
  }

  /// Vault directory, for resolving vault-relative image links.
  Directory get vaultRoot => _vault.root;

  /// Copies [source] into `<vault>/attachments/` and returns the
  /// vault-relative path of the copy.
  Future<String> importAttachment(File source) => _vault.importAttachment(source);

  /// When the current note was last written to disk, for the mono footer.
  DateTime? get lastSavedAt => _lastSavedAt;

  /// Remembers the last body caret offset for [path] (in-memory only).
  void rememberCaret(String path, int offset) => _caretByPath[path] = offset;

  /// The last remembered caret offset for [path], or null when none is known.
  int? lastCaretFor(String path) => _caretByPath[path];

  /// The undo history for the currently open note, or null when no note is
  /// open. A new history is created lazily on the first call.
  UndoHistory? get currentHistory {
    final path = _current?.path;
    if (path == null) return null;
    return _historyByPath.putIfAbsent(path, () => UndoHistory());
  }

  /// Seeds the undo history for [path] with [text] as the baseline state
  /// (the note-as-opened). Called when a note is opened so an undo has
  /// somewhere to go back to. Idempotent — a second call for a path that
  /// already has a non-empty history is a no-op.
  void seedHistory(String path, String text) {
    final existing = _historyByPath[path];
    if (existing != null && !existing.isEmpty) return;
    _historyByPath[path] = UndoHistory()
      ..seed(UndoEntry(text, TextSelection.collapsed(offset: text.length), DateTime.now()));
  }

  /// Undoes the last edit on the current note. Returns the new entry, or
  /// null when there is nothing to undo. Does not record a new history entry;
  /// the pane is responsible for applying the text and selection to the
  /// [HighlightingController].
  UndoEntry? undoCurrent() {
    final path = _current?.path;
    if (path == null) return null;
    final entry = _historyByPath[path]?.undo();
    if (entry == null) return null;
    _body = entry.text;
    _status = EditorStatus.dirty;
    _timer?.cancel();
    _timer = Timer(autosaveDelay, () => _save());
    notifyListeners();
    return entry;
  }

  /// Redoes the last undone edit on the current note. Returns the new entry,
  /// or null when there is nothing to redo.
  UndoEntry? redoCurrent() {
    final path = _current?.path;
    if (path == null) return null;
    final entry = _historyByPath[path]?.redo();
    if (entry == null) return null;
    _body = entry.text;
    _status = EditorStatus.dirty;
    _timer?.cancel();
    _timer = Timer(autosaveDelay, () => _save());
    notifyListeners();
    return entry;
  }

  Future<void> open(Note note) async {
    // Persist the previous note before switching. Without this, edits made
    // to the previous note would be lost the moment the autosave timer is
    // cancelled (the timer writes via `_save()` which reads `_current` at
    // execution time, so an old timer would write against the new note
    // once we swap).
    await flush();
    _timer?.cancel();
    _timer = null;
    _current = note;
    _body = note.body;
    _status = EditorStatus.clean;
    _lastSavedAt = note.updatedAt;
    // Seed the undo history with the note-as-opened state so an undo has
    // somewhere to go back to. If a history already exists for this path,
    // leave it alone — the pane is switching back to a note that already
    // had edits.
    seedHistory(note.path, note.body);
    notifyListeners();
  }

  Future<void> close() async {
    await flush();
    _timer?.cancel();
    _timer = null;
    _current = null;
    _body = '';
    _status = EditorStatus.clean;
    notifyListeners();
  }

  void updateBody(String value, {TextSelection? selection, bool coalesce = true}) {
    final note = _current;
    if (note == null || value == _body) return;
    _body = value;
    _status = EditorStatus.dirty;
    _timer?.cancel();
    _timer = Timer(autosaveDelay, () => _save());
    // Record the change in the per-note undo history when a selection was
    // provided (the pane drives recording so we capture the caret alongside
    // the text). Undo/redo paths bypass recording — see undoCurrent/redoCurrent.
    // [coalesce] = false forces a distinct step for programmatic edits
    // (format, indent, list continuation) so they don't merge into the
    // user's typing run.
    if (selection != null) {
      _historyByPath
          .putIfAbsent(note.path, () => UndoHistory())
          .setState(UndoEntry(value, selection, DateTime.now()), coalesce: coalesce);
    }
    notifyListeners();
  }

  /// Saves immediately if there are unsaved changes (used before switching
  /// notes, closing the app, or destructive actions).
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    return _save();
  }

  /// Renames the file of the currently open note and reopens it.
  Future<void> renameCurrent(String newTitle) async {
    final note = _current;
    if (note == null) return;
    await flush();
    final newPath = await _vault.renameNote(note.path, newTitle);
    await open(await _vault.readNote(newPath));
  }

  /// Renames the note at [path] on disk. When [path] is the note currently
  /// being edited, the in-memory title/body are re-synced to the new file;
  /// when it is not (a note switch raced the commit) `current` is left
  /// alone. Used by title autosave on blur.
  Future<void> renameNoteAt(String path, String newTitle) async {
    await flush();
    final newPath = await _vault.renameNote(path, newTitle);
    if (path == _current?.path) {
      _current = await _vault.readNote(newPath);
      _body = _current!.body;
      _status = EditorStatus.saved;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final note = _current;
    if (note == null) return;
    // When the body is already at the note-on-disk state (e.g. the user
    // undid an edit back to the baseline), mark saved without writing.
    if (_body == note.body) {
      _status = EditorStatus.saved;
      notifyListeners();
      return;
    }

    _status = EditorStatus.saving;
    notifyListeners();

    await _vault.writeNote(note.path, _body);
    _current = await _vault.readNote(note.path);
    _lastSavedAt = _current!.updatedAt ?? DateTime.now();
    _status = EditorStatus.saved;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
