import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sheaf/data/settings_repository.dart';
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/logic/theme_setting_x.dart';
import 'package:sheaf/logic/zoom.dart';
import 'package:sheaf/models/note.dart';
import 'package:sheaf/models/settings.dart';
import 'package:watcher/watcher.dart';

/// App-wide state: which vault is open, what's in it, and user settings.
class VaultController extends ChangeNotifier {
  VaultController({required SettingsRepository settings, required this._vaultFactory})
    : _settingsRepo = settings;

  final SettingsRepository _settingsRepo;
  final VaultRepository Function(String path) _vaultFactory;

  AppSettings _settings = const AppSettings();
  VaultRepository? _vault;
  StreamSubscription<WatchEvent>? _watchSub;
  Timer? _refreshDebounce;
  bool _disposed = false;
  List<Note> _notes = [];
  Set<String> _pinned = {};
  List<FolderNode> _folders = [];

  /// Currently scoped folder, or null for the all-notes view.
  String? selectedFolder;
  String? selectedTag;

  /// Selected note object (full body already parsed) and its path.
  Note? selectedNote;
  String? get selectedNotePath => selectedNote?.path;

  AppSettings get settings => _settings;
  List<Note> get notes => List.unmodifiable(_notes);
  List<FolderNode> get folders => List.unmodifiable(_folders);
  bool get hasVault => _vault != null;
  String get vaultPath => _vault?.root.path ?? '';

  /// Direct repository access for panes that own their controllers
  /// (the editor). Only valid while [hasVault].
  VaultRepository get repository {
    final vault = _vault;
    if (vault == null) throw StateError('No vault open');
    return vault;
  }

  /// Notes passing the active folder + tag filters, pinned notes floated to
  /// the top (recency order preserved within each group — spec story 13).
  Iterable<Note> get visibleNotes {
    final filtered = _notes.where((n) {
      if (selectedFolder != null && !n.path.startsWith('$selectedFolder/')) {
        return false;
      }
      if (selectedTag != null && !n.tags.contains(selectedTag)) return false;
      return true;
    });
    // _notes is newest-first; a stable partition keeps that order inside
    // each group.
    return [
      ...filtered.where((n) => _pinned.contains(n.path)),
      ...filtered.where((n) => !_pinned.contains(n.path)),
    ];
  }

  /// Vault-relative paths of the currently pinned notes.
  Set<String> get pinnedPaths => Set.unmodifiable(_pinned);

  bool isPinned(String relPath) => _pinned.contains(relPath);

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

  void selectNote(Note? note) {
    if (selectedNote?.path == note?.path) return;
    selectedNote = note;
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

  Future<void> cycleTheme() => setTheme(nextThemeSetting(_settings.theme));

  /// Persists the app-wide view zoom (spec story 11). Out-of-range input is
  /// clamped here so corrupt callers cannot poison the stored value.
  Future<void> setZoom(double factor) async {
    final clamped = clampZoom(factor);
    if (clamped == _settings.zoomFactor) return;
    _settings = _settings.copyWith(zoomFactor: clamped);
    await _settingsRepo.save(_settings);
    notifyListeners();
  }

  /// Persists the editor's opening surface (spec story 12).
  Future<void> setEditorMode(EditorMode mode) async {
    if (mode == _settings.editorMode) return;
    _settings = _settings.copyWith(editorMode: mode);
    await _settingsRepo.save(_settings);
  }

  /// Persists the selected theme world id (spec story 16). Unknown ids are
  /// tolerated at read time — resolution falls back to Quire.
  Future<void> setThemeWorld(String id) async {
    if (id == _settings.themeWorld) return;
    _settings = _settings.copyWith(themeWorld: id);
    await _settingsRepo.save(_settings);
    notifyListeners();
  }

  /// Persists the editor body base size, clamped to 12–24 (story 16).
  Future<void> setEditorFontSize(double size) async {
    final clamped = size.clamp(12.0, 24.0).toDouble();
    if (clamped == _settings.editorFontSize) return;
    _settings = _settings.copyWith(editorFontSize: clamped);
    await _settingsRepo.save(_settings);
    notifyListeners();
  }

  /// Selects the user font (registered under [family] at startup) or clears
  /// it with two nulls. Family and path are always set together.
  Future<void> setUserFont({String? family, String? path}) async {
    assert((family == null) == (path == null), 'font family and path move together');
    if (family == _settings.fontFamily && path == _settings.fontPath) return;
    _settings = _settings.copyWith(fontFamily: family, fontPath: path);
    await _settingsRepo.save(_settings);
    notifyListeners();
  }

  /// Persists per-tier sidebar visibility (spec story 15 / task 10).
  Future<void> setSidebarVisibility(WindowTier tier, bool visible) async {
    final next = switch (tier) {
      WindowTier.expanded => _settings.copyWith(sidebarExpanded: visible),
      WindowTier.full => _settings.copyWith(sidebarFull: visible),
      WindowTier.stack => _settings.copyWith(sidebarStack: visible),
    };
    if (next == _settings) return;
    _settings = next;
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
    if (selectedNote?.path == relPath) selectedNote = null;
    await refresh();
  }

  Future<void> createFolder(String name) async {
    final base = selectedFolder;
    final rel = base == null || base.isEmpty ? name : '$base/$name';
    await _requireVault().createFolder(rel);
    await refresh();
  }

  /// Creates [name] inside [parent] ('' = vault root), independent of the
  /// current selection so sidebar actions never nest unintentionally.
  Future<void> createFolderAt(String parent, String name) async {
    final rel = parent.isEmpty ? name : '$parent/$name';
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

  Future<void> restoreFromTrash(String trashedName) async {
    await _requireVault().restore(trashedName);
    await refresh();
  }

  Future<void> emptyTrashItem(String trashedName) async {
    await _requireVault().deleteForever(trashedName);
    await refresh();
  }

  /// Rescans the vault from disk. No-op when disposed or vault vanished.
  Future<void> refresh() async {
    final vault = _vault;
    if (_disposed || vault == null || !vault.root.existsSync()) return;
    final notes = await vault.listNotes();
    final folders = await vault.folderTree();
    // Dispose may land while the rescan above was in flight.
    if (_disposed) return;
    _notes = notes;
    _folders = folders;
    _pinned = await vault.pinnedPaths();
    if (_disposed) return;
    notifyListeners();
  }

  /// Flips the pin state of [relPath] and persists it to `.sheaf/meta.json`.
  Future<void> togglePin(String relPath) async {
    final target = !_pinned.contains(relPath);
    await _requireVault().setPinned(relPath, target);
    if (target) {
      _pinned.add(relPath);
    } else {
      _pinned.remove(relPath);
    }
    notifyListeners();
  }

  Future<void> _open(String absolutePath) async {
    _vault = _vaultFactory(absolutePath);
    _settings = _settings.copyWith(vaultPath: absolutePath);
    await _settingsRepo.save(_settings);
    selectedFolder = null;
    selectedTag = null;
    selectedNote = null;
    await refresh();
    _startWatching(absolutePath);
  }

  /// Rescans whenever anything inside the vault changes — internal edits
  /// (autosave, renames) and external editors alike.
  void _startWatching(String absolutePath) {
    _watchSub?.cancel();
    final subscription = Watcher(absolutePath).events.listen(_onWatchEvent);
    _watchSub = subscription;
  }

  void _onWatchEvent(WatchEvent event) {
    if (_disposed) return;
    // Debounce bursts (a single save can emit several events).
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_vault == null || _disposed) return;
      unawaited(refresh());
    });
  }

  VaultRepository _requireVault() {
    final vault = _vault;
    if (vault == null) throw StateError('No vault open');
    return vault;
  }

  @override
  void dispose() {
    _disposed = true;
    _watchSub?.cancel();
    _refreshDebounce?.cancel();
    super.dispose();
  }
}
