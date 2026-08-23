import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taker/data/settings_repository.dart';
import 'package:taker/data/vault_repository.dart';
import 'package:taker/logic/vault_controller.dart';
import 'package:taker/models/settings.dart';

void main() {
  late Directory tempDir;
  late File settingsFile;
  late Directory vaultDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('taker_vaultctl_test');
    settingsFile = File('${tempDir.path}/settings.json');
    vaultDir = Directory('${tempDir.path}/vault')..createSync();
  });

  tearDown(() async => tempDir.delete(recursive: true));

  VaultController makeController() => VaultController(
    settings: SettingsRepository(file: settingsFile),
    vaultFactory: (path) => VaultRepository(root: Directory(path)),
  );

  test('starts with no vault when none was chosen before', () async {
    final controller = makeController();
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.hasVault, isFalse);
    expect(controller.notes, isEmpty);
  });

  test('openVault scans notes and folders and persists the choice', () async {
    await Directory('${vaultDir.path}/work').create();
    await File('${vaultDir.path}/work/plan.md').writeAsString('# Plan\n#urgent');
    await File('${vaultDir.path}/loose.md').writeAsString('plain');

    final controller = makeController();
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.openVault(vaultDir.path);

    expect(controller.hasVault, isTrue);
    expect(controller.vaultPath, vaultDir.path);
    expect(controller.notes.map((n) => n.title), containsAll(['Plan', 'loose']));
    expect(controller.folders.single.name, 'work');
  });

  test('initialize reopens a previously saved vault', () async {
    final first = makeController();
    addTearDown(first.dispose);
    await first.initialize();
    await first.openVault(vaultDir.path);
    await first.createNote(title: 'Persisted');

    final second = makeController();
    addTearDown(second.dispose);
    await second.initialize();

    expect(second.hasVault, isTrue);
    expect(second.notes.single.title, 'Persisted');
  });

  test('openVault falls back to no-vault when the path vanished', () async {
    final ghost = '${tempDir.path}/ghost'.toString();
    final controller = makeController();
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.openVault(ghost);

    expect(controller.hasVault, isTrue); // opened even though empty/new
    // Now simulate the folder disappearing between sessions.
    await Directory(ghost).delete(recursive: true);
    final next = makeController();
    addTearDown(next.dispose);
    await next.initialize();
    expect(next.hasVault, isFalse);
  });

  test('createNote adds to the visible list', () async {
    final controller = makeController();
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.openVault(vaultDir.path);

    await controller.createNote(title: 'Fresh');

    expect(controller.notes.single.title, 'Fresh');
  });

  test('deleteNote removes it from the list', () async {
    final controller = makeController();
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.openVault(vaultDir.path);
    final note = await controller.createNote(title: 'Gone');

    await controller.deleteNote(note.path);

    expect(controller.notes, isEmpty);
  });

  test('refresh picks up external changes and rescans tags', () async {
    final controller = makeController();
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.openVault(vaultDir.path);
    final note = await controller.createNote(title: 'Tagged');

    await File('${controller.vaultPath}/${note.path}').writeAsString('now #tagged');
    await controller.refresh();

    expect(controller.notes.single.tags, ['tagged']);
  });

  test('theme setting persists through the controller', () async {
    final controller = makeController();
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.setTheme(ThemeSetting.dark);
    expect(controller.settings.theme, ThemeSetting.dark);

    final reloaded = makeController();
    addTearDown(reloaded.dispose);
    await reloaded.initialize();
    expect(reloaded.settings.theme, ThemeSetting.dark);
  });
}
