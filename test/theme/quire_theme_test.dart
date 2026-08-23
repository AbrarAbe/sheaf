import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taker/theme/quire_colors.dart';
import 'package:taker/theme/quire_theme.dart';

void main() {
  group('Daylight (light) ColorScheme mapping', () {
    final scheme = buildQuireLight().colorScheme;

    test('maps Quire tokens to roles per theming.md', () {
      expect(scheme.surface, const Color(0xFFF3F4F7)); // surface.canvas
      expect(scheme.surfaceContainerLowest, const Color(0xFFFFFFFF)); // card
      expect(scheme.surfaceContainerHigh, const Color(0xFFEAEDF1)); // raised
      expect(scheme.surfaceContainerHighest, const Color(0xFFE4E8EF)); // inset
      expect(scheme.onSurface, const Color(0xFF191C24)); // text.primary
      expect(scheme.onSurfaceVariant, const Color(0xFF565D6E)); // text.secondary
      expect(scheme.outlineVariant, const Color(0xFFD8DDE6)); // line.hairline
      expect(scheme.primary, const Color(0xFF2F4BD7)); // accent.ink
      expect(scheme.onPrimary, const Color(0xFFFFFFFF)); // accent.onInk
      expect(scheme.error, const Color(0xFFB02A30)); // hl.alert fg
    });

    test('secondaryContainer is ink wash (ink @ 10%)', () {
      expect(scheme.secondaryContainer, const Color(0xFF2F4BD7).withValues(alpha: 0.10));
    });
  });

  group('Lamplight (dark) ColorScheme mapping', () {
    final scheme = buildQuireDark().colorScheme;

    test('maps Quire tokens to roles per theming.md', () {
      expect(scheme.surface, const Color(0xFF131110));
      expect(scheme.surfaceContainerLowest, const Color(0xFF1D1B17)); // card
      expect(scheme.surfaceContainerHigh, const Color(0xFF26231D)); // raised
      expect(scheme.surfaceContainerLow, const Color(0xFF0E0D0C)); // inset
      expect(scheme.onSurface, const Color(0xFFECE7DC)); // warm paper-white
      expect(scheme.onSurfaceVariant, const Color(0xFFA69F8F));
      expect(scheme.outlineVariant, const Color(0xFF33302A));
      expect(scheme.primary, const Color(0xFF93A8F0)); // brightened ink
      expect(scheme.onPrimary, const Color(0xFF10131F)); // inverted onInk
      expect(scheme.error, const Color(0xFFFFC2BE)); // hl.alert fg (dark)
    });

    test('secondaryContainer is ink wash (ink @ 16%)', () {
      expect(scheme.secondaryContainer, const Color(0xFF93A8F0).withValues(alpha: 0.16));
    });

    test('never uses pure black/white text in Lamplight', () {
      expect(scheme.onSurface, isNot(const Color(0xFFFFFFFF)));
      expect(scheme.onSurface, isNot(const Color(0xFF000000)));
    });
  });

  group('QuireColors extension', () {
    test('present in both themes', () {
      expect(buildQuireLight().extension<QuireColors>(), isNotNull);
      expect(buildQuireDark().extension<QuireColors>(), isNotNull);
    });

    test('highlighter bases match color.md ledger (light)', () {
      final q = buildQuireLight().extension<QuireColors>()!;
      expect(q.hlPinBase, const Color(0xFFF2C94C));
      expect(q.hlPinFg, const Color(0xFF7A5E00));
      expect(q.hlAlertBase, const Color(0xFFE5484D));
      expect(q.hlAlertFg, const Color(0xFFB02A30));
      expect(q.hlGrowBase, const Color(0xFF3FB97F));
      expect(q.hlGrowFg, const Color(0xFF17603E));
      expect(q.hlWaitBase, const Color(0xFFED8B16));
      expect(q.hlWaitFg, const Color(0xFF8F5606));
    });

    test('highlighter bases match color.md ledger (dark)', () {
      final q = buildQuireDark().extension<QuireColors>()!;
      expect(q.hlPinBase, const Color(0xFFE8C34A));
      expect(q.hlPinFg, const Color(0xFFF4DC86));
      expect(q.hlAlertBase, const Color(0xFFFF8A85));
      expect(q.hlAlertFg, const Color(0xFFFFC2BE));
      expect(q.hlGrowBase, const Color(0xFF6FCB98));
      expect(q.hlGrowFg, const Color(0xFFA8E0C2));
      expect(q.hlWaitBase, const Color(0xFFF2A65A));
      expect(q.hlWaitFg, const Color(0xFFF8CF9E));
    });

    test('washes are translucent at documented alphas', () {
      final light = buildQuireLight().extension<QuireColors>()!;
      expect(light.hlPinWash, const Color(0xFFF2C94C).withValues(alpha: 0.30));
      expect(light.hlAlertWash, const Color(0xFFE5484D).withValues(alpha: 0.14));

      final dark = buildQuireDark().extension<QuireColors>()!;
      expect(dark.hlPinWash, const Color(0xFFE8C34A).withValues(alpha: 0.20));
      expect(dark.hlAlertWash, const Color(0xFFFF8A85).withValues(alpha: 0.18));
    });

    test('focus ring follows ink', () {
      expect(buildQuireLight().extension<QuireColors>()!.focusRing, const Color(0xFF2F4BD7));
      expect(buildQuireDark().extension<QuireColors>()!.focusRing, const Color(0xFF93A8F0));
    });

    test('lerp interpolates every field', () {
      final light = buildQuireLight().extension<QuireColors>()!;
      final dark = buildQuireDark().extension<QuireColors>()!;
      final mid = light.lerp(dark, 0.5);

      expect(mid.hlPinBase, Color.lerp(light.hlPinBase, dark.hlPinBase, 0.5));
      expect(mid.focusRing, Color.lerp(light.focusRing, dark.focusRing, 0.5));
      expect(identical(mid, light), isFalse);
    });
  });

  group('component theming', () {
    test('cards use radius.l (16)', () {
      expect(buildQuireLight().cardTheme.shape, isA<RoundedRectangleBorder>());
      expect(
        (buildQuireLight().cardTheme.shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(16),
      );
    });

    test('selection color is ink @ 24%', () {
      final theme = buildQuireLight();
      // TextSelectionTheme carries the selection color.
      expect(
        theme.textSelectionTheme.selectionColor,
        const Color(0xFF2F4BD7).withValues(alpha: 0.24),
      );
    });

    test('focus color is the ring color', () {
      expect(buildQuireLight().focusColor, const Color(0xFF2F4BD7));
      expect(buildQuireDark().focusColor, const Color(0xFF93A8F0));
    });
  });
}
