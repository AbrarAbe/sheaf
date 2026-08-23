import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:taker/data/settings_repository.dart';
import 'package:taker/data/vault_repository.dart';
import 'package:taker/models/note.dart';
import 'package:taker/models/settings.dart';

/// App-wide state: which vault is open, what's in it, and user settings.
class VaultController extends ChangeNotifier {
  VaultController({required SettingsRepository settings, required this._vaultFactory})
    : _settingsRepo = settings;

  final SettingsRepository _settingsRepo;
  final VaultRepository Function(String path) _vaultFactory;

  AppSettings _settings = const AppSettings();
  VaultRepository? _vault;
  List<Note> _notes = [];
  List<FolderNode> _folders = [];

  /// Currently scoped folder, or null for the all-notes view.
  String? selectedFolder;
  String? selectedTag;
  String? selectedNotePath;

  AppSettings get settings => _settings;
  List<Note> get notes => List.unmodifiable(_notes);
  List<FolderNode> get folders => List.unmodifiable(_folders);
  bool get hasVault => _vault != null;
  String get vaultPath => _vault?.root.path ?? '';

  /// Notes passing the active folder + tag filters.
  Iterable<Note> get visibleNotes => _notes.where((n) {
    if (selectedFolder != null && !n.path.startsWith('$selectedFolder/')) {
      return false;
    }
    if (selectedTag != null && !n.tags.contains(selectedTag)) return false;
    return true;
  });

  /// Tag → note count across the whole vault (sidebar list).
  Map<String, int> get tagCounts {
    final counts = <String, int>{};
    for (final note in _notes) {
      for (final tag in note.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  void selectFolder(String? relPath) {
    if (selectedFolder == relPath) return;
    selectedFolder = relPath;
    notifyListeners();
  }

  void selectTag(String? tag) {
    if (selectedTag == tag) return;
    selectedTag = tag;
    notifyListeners();
  }

  void selectNote(String? relPath) {
    if (selectedNotePath == relPath) return;
    selectedNotePath = relPath;
    notifyListeners();
  }

  /// Loads persisted settings and reopens the last vault if it still exists.
  Future<void> initialize() async {
    _settings = await _settingsRepo.load();
    final path = _settings.vaultPath;
    if (path != null) {
      if (Directory(path).existsSync()) {
        await _open(path);
      } else {
        // The folder vanished since last session; forget the stale path.
        _settings = _settings.copyWith(vaultPath: null);
        await _settingsRepo.save(_settings);
      }
    }
    notifyListeners();
  }

  /// Opens (creating if needed) a vault folder and persists the choice.
  Future<void> openVault(String path) async {
    await Directory(path).create(recursive: true);
    await _open(Directory(path).absolute.path);
    notifyListeners();
  }

  Future<void> setTheme(ThemeSetting theme) async {
    _settings = _settings.copyWith(theme: theme);
    await _settingsRepo.save(_settings);
    notifyListeners();
  }

  Future<Note> createNote({required String title, String? body, String? folder}) async {
    final note = await _requireVault().createNote(
      title: title,
      body: body,
      folder: folder ?? selectedFolder,
    );
    await refresh();
    return note;
  }

  Future<void> deleteNote(String relPath) async {
    await _requireVault().deleteNote(relPath);
    if (selectedNotePath == relPath) selectedNotePath = null;
    await refresh();
  }

  Future<void> createFolder(String name) async {
    final base = selectedFolder;
    final rel = base == null || base.isEmpty ? name : '$base/$name';
    await _requireVault().createFolder(rel);
    await refresh();
  }

  Future<void> renameFolder(String relPath, String newName) async {
    await _requireVault().renameFolder(relPath, newName);
    if (selectedFolder == relPath || selectedFolder?.startsWith('$relPath/') == true) {
      // The scoped path no longer exists; fall back to all notes.
      selectedFolder = null;
    }
    await refresh();
  }

  Future<void> deleteFolder(String relPath) async {
    await _requireVault().deleteFolder(relPath);
    if (selectedFolder == relPath || selectedFolder?.startsWith('$relPath/') == true) {
      selectedFolder = null;
    }
    await refresh();
  }

  /// Trash entries, for the sidebar trash view.
  Future<List<TrashEntry>> trash() => _requireVault().listTrash();

  /// Rescans the vault from disk.
  Future<void> refresh() async {
    final vault = _requireVault();
    _notes = await vault.listNotes();
    _folders = await vault.folderTree();
    notifyListeners();
  }

  Future<void> _open(String absolutePath) async {
    _vault = _vaultFactory(absolutePath);
    _settings = _settings.copyWith(vaultPath: absolutePath);
    await _settingsRepo.save(_settings);
    selectedFolder = null;
    selectedTag = null;
    selectedNotePath = null;
    await refresh();
  }

  VaultRepository _requireVault() {
    final vault = _vault;
    if (vault == null) throw StateError('No vault open');
    return vault;
  }
}
