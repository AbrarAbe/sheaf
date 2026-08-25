import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sheaf/theme/quire_colors.dart';
import 'package:sheaf/theme/worlds.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('theme world registry', () {
    test('ships the launch set of three worlds', () {
      expect(themeWorlds.map((w) => w.id), containsAll(['quire', 'graphite', 'sepia']));
    });

    test('every world builds distinct light and dark themes', () {
      for (final world in themeWorlds) {
        final light = world.light();
        final dark = world.dark();

        expect(light.brightness, Brightness.light, reason: '${world.id} light');
        expect(dark.brightness, Brightness.dark, reason: '${world.id} dark');
        expect(
          light.colorScheme.surface,
          isNot(dark.colorScheme.surface),
          reason: '${world.id} modes must differ',
        );
        expect(light.extensions[QuireColors], isNotNull, reason: '${world.id} carries tokens');
      }
    });

    test('worlds are visually distinct from each other', () {
      final surfaces = {for (final w in themeWorlds) w.id: w.light().colorScheme.surface};
      expect(surfaces.values.toSet().length, themeWorlds.length);
    });

    test('unknown ids fall back to Quire', () {
      expect(worldById('nonexistent').id, 'quire');
      expect(worldById('graphite').id, 'graphite');
    });

    test('labels are user-facing strings', () {
      for (final w in themeWorlds) {
        expect(w.label.trim(), isNotEmpty);
      }
    });
  });
}
