import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/models/settings.dart';

void main() {
  group('AppSettings v2 defaults', () {
    test('new fields carry sensible defaults', () {
      const s = AppSettings();
      expect(s.editorMode, EditorMode.normal);
      expect(s.zoomFactor, 1.0);
      expect(s.editorFontSize, 16.0);
      expect(s.themeWorld, 'quire');
      expect(s.fontFamily, isNull);
      expect(s.fontPath, isNull);
    });
  });

  group('EditorMode', () {
    test('serializes both ways', () {
      for (final m in EditorMode.values) {
        expect(EditorMode.fromJson(m.toJson()), m);
      }
    });

    test('unknown or missing strings fall back to normal', () {
      expect(EditorMode.fromJson('wysiwyg'), EditorMode.normal);
      expect(EditorMode.fromJson(null), EditorMode.normal);
    });
  });

  group('copyWith', () {
    test('replaces each v2 field', () {
      const base = AppSettings();
      final s = base.copyWith(
        editorMode: EditorMode.preview,
        zoomFactor: 1.3,
        editorFontSize: 19.0,
        themeWorld: 'sepia',
        fontFamily: 'Iosevka',
        fontPath: '/usr/share/fonts/iosevka.ttf',
      );
      expect(s.editorMode, EditorMode.preview);
      expect(s.zoomFactor, 1.3);
      expect(s.editorFontSize, 19.0);
      expect(s.themeWorld, 'sepia');
      expect(s.fontFamily, 'Iosevka');
      expect(s.fontPath, '/usr/share/fonts/iosevka.ttf');
    });

    test('null keeps existing value', () {
      const s = AppSettings(zoomFactor: 1.5);
      expect(s.copyWith().zoomFactor, 1.5);
    });
  });

  group('equality', () {
    test('includes every v2 field', () {
      const a = AppSettings();
      expect(a, a.copyWith());
      expect(a, isNot(a.copyWith(editorMode: EditorMode.markdown)));
      expect(a, isNot(a.copyWith(zoomFactor: 1.1)));
      expect(a, isNot(a.copyWith(editorFontSize: 17)));
      expect(a, isNot(a.copyWith(themeWorld: 'graphite')));
      expect(a, isNot(a.copyWith(fontFamily: 'X')));
      expect(a, isNot(a.copyWith(fontPath: '/x.ttf')));
    });
  });

  group('fromJson tolerance', () {
    test('missing v2 keys yield defaults', () {
      final s = AppSettings.fromJson({'vaultPath': '/v', 'theme': 'dark'});
      expect(s.vaultPath, '/v');
      expect(s.theme, ThemeSetting.dark);
      expect(s.editorMode, EditorMode.normal);
      expect(s.zoomFactor, 1.0);
      expect(s.editorFontSize, 16.0);
      expect(s.themeWorld, 'quire');
    });

    test('accepts whole-number json values for numeric fields', () {
      final s = AppSettings.fromJson({'zoomFactor': 2, 'editorFontSize': 14});
      expect(s.zoomFactor, 2.0);
      expect(s.editorFontSize, 14.0);
    });
  });

  group('sidebar visibility per tier (task 10)', () {
    test('defaults: expanded shown, full and stack hidden', () {
      const s = AppSettings();
      expect(s.sidebarExpanded, isTrue);
      expect(s.sidebarFull, isFalse);
      expect(s.sidebarStack, isFalse);
    });

    test('copyWith replaces each flag', () {
      const base = AppSettings();
      final s = base.copyWith(sidebarFull: true, sidebarStack: true, sidebarExpanded: false);
      expect(s.sidebarExpanded, isFalse);
      expect(s.sidebarFull, isTrue);
      expect(s.sidebarStack, isTrue);
    });

    test('equality covers the flags', () {
      const a = AppSettings();
      expect(a, isNot(a.copyWith(sidebarFull: true)));
    });

    test('round-trips through json with tolerant defaults', () {
      const s = AppSettings(sidebarFull: true);
      final restored = AppSettings.fromJson(s.toJson());
      expect(restored, s);

      final legacy = AppSettings.fromJson({'vaultPath': '/v'});
      expect(legacy.sidebarExpanded, isTrue);
      expect(legacy.sidebarFull, isFalse);
    });
  });

  group('v0.1 backward compatibility', () {
    test('payload written by v0.1 loads with v2 defaults intact', () {
      final s = AppSettings.fromJson({'vaultPath': '/old/vault', 'theme': 'light'});
      expect(s.vaultPath, '/old/vault');
      expect(s.theme, ThemeSetting.light);
      expect(s.editorMode, EditorMode.normal);
      expect(s.zoomFactor, 1.0);
      expect(s.themeWorld, 'quire');
      expect(s.fontFamily, isNull);
    });

    test('default toJson carries every persisted key', () {
      final keys = const AppSettings().toJson().keys.toSet();
      expect(
        keys,
        containsAll([
          'vaultPath',
          'theme',
          'editorMode',
          'zoomFactor',
          'editorFontSize',
          'themeWorld',
        ]),
      );
    });
  });
}
