import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sheaf/data/vault_repository.dart';
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

  Future<void> open(Note note) async {
    await flush();
    _timer?.cancel();
    _timer = null;
    _current = note;
    _body = note.body;
    _status = EditorStatus.clean;
    _lastSavedAt = note.updatedAt;
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

  void updateBody(String value) {
    final note = _current;
    if (note == null || value == _body) return;
    _body = value;
    _status = EditorStatus.dirty;
    _timer?.cancel();
    _timer = Timer(autosaveDelay, () => _save());
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

  Future<void> _save() async {
    final note = _current;
    if (note == null || _body == note.body) return;

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
