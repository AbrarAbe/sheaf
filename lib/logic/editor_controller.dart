import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:taker/data/vault_repository.dart';
import 'package:taker/models/note.dart';

/// Save lifecycle of the open note.
enum EditorStatus { clean, dirty, saving, saved }

/// Owns all writes for the currently open note.
///
/// Single-writer rule: only this controller writes the file being edited,
/// which keeps autosave from racing renames or deletes handled elsewhere.
class EditorController extends ChangeNotifier {
  EditorController({required this._vault, this.autosaveDelay = const Duration(seconds: 1)});

  final VaultRepository _vault;

  /// Debounce window between the last keystroke and the write.
  final Duration autosaveDelay;

  Note? _current;
  String _body = '';
  Timer? _timer;
  EditorStatus _status = EditorStatus.clean;
  DateTime? _lastSavedAt;

  Note? get current => _current;
  String get body => _body;
  EditorStatus get status => _status;

  /// Vault directory, for resolving vault-relative image links.
  Directory get vaultRoot => _vault.root;

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
