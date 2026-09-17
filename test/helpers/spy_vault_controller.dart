import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:sheaf/data/settings_repository.dart';
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/logic/shortcut_serializer.dart';
import 'package:sheaf/logic/vault_controller.dart';
import 'package:sheaf/models/note.dart';
import 'package:sheaf/models/settings.dart';
import 'package:sheaf/models/shortcut_settings.dart';

/// Records mutations without touching disks — lets widget tests verify that
/// UI wiring calls the right controller methods despite the FakeAsync zone.
class SpyVaultController extends VaultController {
  SpyVaultController(String settingsPath, {Directory? vaultDir})
    : _vaultDir = vaultDir ?? File(settingsPath).parent,
      super(
        settings: SettingsRepository(file: File(settingsPath)),
        vaultFactory: (path) => throw UnimplementedError(),
      );

  /// Backs [repository] so widgets that build editors (Shell) can pump.
  final Directory _vaultDir;

  @override
  VaultRepository get repository => VaultRepository(root: _vaultDir);

  /// Delegates to repository so NoteInfoDialog can stat files via
  /// controller.fileOf() even when _vault is null (FakeAsync zone).
  @override
  File fileOf(String relPath) => repository.fileOf(relPath);

  final restored = <String>[];
  final emptied = <String>[];
  final deleted = <String>[];
  List<String>? deletedPermanently;
  final themes = <ThemeSetting>[];
  final worlds = <String>[];
  String themeWorld = 'quire';
  double editorFontSize = 16.0;
  double zoom = 1.0;
  bool showWindowControls = true;
  final windowControlToggles = <bool>[];
  final openedVaults = <String>[];
  List<TrashEntry> entries = const [];
  List<Note> fakeNotes = const [];
  ThemeSetting theme = ThemeSetting.system;
  @override
  String vaultPath = '/old/vault';
  Map<String, String> shortcutOverrides = {};
  final shortcutCalls = <String>[];

  @override
  List<Note> get notes => List.unmodifiable(fakeNotes);

  @override
  Iterable<Note> get visibleNotes => fakeNotes;

  @override
  Map<String, int> get tagCounts => const {};

  @override
  Future<List<TrashEntry>> trash() async => entries;

  @override
  Future<void> restoreFromTrash(String trashedName) async {
    restored.add(trashedName);
    entries = [
      for (final e in entries)
        if (e.trashedName != trashedName) e,
    ];
  }

  @override
  Future<void> emptyTrashItem(String trashedName) async {
    emptied.add(trashedName);
    entries = [
      for (final e in entries)
        if (e.trashedName != trashedName) e,
    ];
  }

  @override
  Future<void> trashNote(String relPath) async {
    deleted.add(relPath);
    fakeNotes = [
      for (final n in fakeNotes)
        if (n.path != relPath) n,
    ];
  }

  @override
  Future<void> deleteNote(String relPath) async {
    deletedPermanently ??= [];
    deletedPermanently!.add(relPath);
    fakeNotes = [
      for (final n in fakeNotes)
        if (n.path != relPath) n,
    ];
  }

  @override
  AppSettings get settings => AppSettings(
    vaultPath: vaultPath,
    theme: theme,
    themeWorld: themeWorld,
    editorFontSize: editorFontSize,
    zoomFactor: zoom,
    showWindowControls: showWindowControls,
    shortcutOverrides: Map.unmodifiable(shortcutOverrides),
  );

  @override
  Future<void> setTheme(ThemeSetting value) async {
    themes.add(value);
    theme = value;
  }

  @override
  Future<void> setThemeWorld(String id) async {
    worlds.add(id);
    themeWorld = id;
  }

  @override
  Future<void> setEditorFontSize(double size) async {
    editorFontSize = size;
  }

  @override
  Future<void> setZoom(double factor) async {
    zoom = factor;
  }

  @override
  Future<void> setShowWindowControls(bool value) async {
    windowControlToggles.add(value);
    showWindowControls = value;
  }

  @override
  Future<void> setShortcutOverride(ShortcutAction action, SingleActivator? activator) async {
    final serialized = activator == null ? null : serializeActivator(activator);
    shortcutCalls.add('${action.name}:${serialized ?? "reset"}');
    if (serialized == null) {
      shortcutOverrides.remove(action.name);
    } else {
      shortcutOverrides[action.name] = serialized;
    }
    notifyListeners();
  }

  @override
  Future<void> resetAllShortcuts() async {
    shortcutOverrides.clear();
    notifyListeners();
  }

  @override
  bool get hasVault => true;

  @override
  Future<void> openVault(String path) async {
    openedVaults.add(path);
    vaultPath = path;
  }
}
