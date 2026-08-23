import 'dart:io';

import 'package:taker/data/settings_repository.dart';
import 'package:taker/data/vault_repository.dart';
import 'package:taker/logic/vault_controller.dart';
import 'package:taker/models/settings.dart';

/// Records mutations without touching disks — lets widget tests verify that
/// UI wiring calls the right controller methods despite the FakeAsync zone.
class SpyVaultController extends VaultController {
  SpyVaultController(String settingsPath)
    : super(
        settings: SettingsRepository(file: File(settingsPath)),
        vaultFactory: (path) => throw UnimplementedError(),
      );

  final restored = <String>[];
  final emptied = <String>[];
  final themes = <ThemeSetting>[];
  final openedVaults = <String>[];
  List<TrashEntry> entries = const [];
  ThemeSetting theme = ThemeSetting.system;
  @override
  String vaultPath = '/old/vault';

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
  AppSettings get settings => AppSettings(vaultPath: vaultPath, theme: theme);

  @override
  Future<void> setTheme(ThemeSetting value) async {
    themes.add(value);
    theme = value;
  }

  @override
  bool get hasVault => true;

  @override
  Future<void> openVault(String path) async {
    openedVaults.add(path);
    vaultPath = path;
  }
}
