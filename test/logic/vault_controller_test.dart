import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/data/settings_repository.dart';
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/logic/vault_controller.dart';
import 'package:sheaf/models/settings.dart';

void main() {
  late Directory tempDir;
  late File settingsFile;
  late Directory vaultDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sheaf_vaultctl_test');
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

  test('directory watcher auto-refreshes on external edits', () async {
    final controller = makeController();
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.openVault(vaultDir.path);
    final note = await controller.createNote(title: 'Watched');
    expect(controller.notes.single.body, '');

    // External edit — no manual refresh call.
    await File('${controller.vaultPath}/${note.path}').writeAsString('# Watched\nexternal edit');

    // Watcher debounce is 300 ms; poll up to 3 s.
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (controller.notes.single.body.contains('external edit')) break;
    }
    expect(controller.notes.single.body, contains('external edit'));
  }, timeout: const Timeout(Duration(seconds: 10)));

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

  group('selection and filtering', () {
    test('null folder shows every note, picking one scopes it', () async {
      final controller = makeController();
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.openVault(vaultDir.path);

      await controller.createNote(title: 'Root');
      await controller.createNote(title: 'Nested', folder: 'work');
      expect(controller.visibleNotes.length, 2);

      controller.selectFolder('work');
      expect(controller.visibleNotes.single.title, 'Nested');

      controller.selectFolder(null);
      expect(controller.visibleNotes.length, 2);
    });

    test('tag selection filters and counts are aggregated', () async {
      final controller = makeController();
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.openVault(vaultDir.path);

      await controller.createNote(title: 'A', body: '#x #y');
      await controller.createNote(title: 'B', body: 'also #y');

      expect(controller.tagCounts['y'], 2);
      expect(controller.tagCounts['x'], 1);

      controller.selectTag('x');
      expect(controller.visibleNotes.single.title, 'A');
      expect(controller.selectedTag, 'x');

      controller.selectTag(null);
      expect(controller.visibleNotes.length, 2);
    });

    test('renameFolder rescans and keeps scoped selection coherent', () async {
      final controller = makeController();
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.openVault(vaultDir.path);
      await controller.createNote(title: 'P', folder: 'proj');
      controller.selectFolder('proj');
      expect(controller.visibleNotes.length, 1);

      await controller.renameFolder('proj', 'project-x');
      expect(controller.folders.map((f) => f.name), ['project-x']);
      // Old path no longer exists; fall back to all-notes.
      expect(controller.selectedFolder, isNull);
    });

    test('createFolderAt places folders exactly where asked, not in selection', () async {
      final controller = makeController();
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.openVault(vaultDir.path);
      await controller.createFolder('existing');

      // User has 'existing' selected but hits the root "+" button.
      controller.selectFolder('existing');
      await controller.createFolderAt('', 'fresh');

      expect(controller.folders.map((f) => f.name).toSet(), {'existing', 'fresh'});
      expect(
        controller.folders.singleWhere((f) => f.name == 'existing').children,
        isEmpty,
        reason: 'root creation must not nest inside the selected folder',
      );
    });

    test('deleteFolder trashes contents', () async {
      final controller = makeController();
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.openVault(vaultDir.path);
      await controller.createFolder('temp');
      await controller.createNote(title: 'T', folder: 'temp');

      await controller.deleteFolder('temp');

      expect(controller.folders, isEmpty);
      expect(controller.notes, isEmpty);
      expect((await controller.trash()).single.isFolder, isTrue);
    });
  });
}
