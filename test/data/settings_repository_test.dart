import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/data/settings_repository.dart';
import 'package:sheaf/models/settings.dart';

void main() {
  late Directory tempDir;
  late SettingsRepository repo;
  late File file;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sheaf_settings_test');
    file = File('${tempDir.path}/settings.json');
    repo = SettingsRepository(file: file);
  });

  tearDown(() async => tempDir.delete(recursive: true));

  group('load', () {
    test('returns defaults when the file does not exist yet', () async {
      final s = await repo.load();
      expect(s.vaultPath, isNull);
      expect(s.theme, ThemeSetting.system);
    });

    test('round-trips a saved vault path and theme', () async {
      const s = AppSettings(vaultPath: '/home/me/notes', theme: ThemeSetting.dark);
      await repo.save(s);
      expect(await repo.load(), s);
    });

    test('falls back to defaults on corrupt json', () async {
      await file.writeAsString('{not valid json');
      final s = await repo.load();
      expect(s.vaultPath, isNull);
      expect(s.theme, ThemeSetting.system);
    });

    test('falls back to defaults when json shape is wrong', () async {
      await file.writeAsString(jsonEncode(['not', 'an', 'object']));
      final s = await repo.load();
      expect(s.theme, ThemeSetting.system);
    });

    test('maps unknown theme strings back to system', () async {
      await file.writeAsString(jsonEncode({'vaultPath': null, 'theme': 'sepia'}));
      expect((await repo.load()).theme, ThemeSetting.system);
    });

    test('creates the parent directory if it is missing', () async {
      final nested = File('${tempDir.path}/a/b/settings.json');
      final r = SettingsRepository(file: nested);
      await r.save(const AppSettings(vaultPath: '/v'));
      expect(nested.existsSync(), isTrue);
      expect((await r.load()).vaultPath, '/v');
    });
  });

  group('ThemeSetting', () {
    test('serializes both ways', () {
      for (final t in ThemeSetting.values) {
        expect(ThemeSetting.fromJson(t.toJson()), t);
      }
    });
  });
}
