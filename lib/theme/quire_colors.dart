import 'package:flutter/material.dart';

/// Quire semantic colors that have no home in Material's [ColorScheme]:
/// the highlighter set (state washes) and the focus ring.
///
/// Every value comes from `docs/design/color.md`. Never hardcode these
/// elsewhere — resolve through `Theme.of(context).extension<QuireColors>()`.
@immutable
class QuireColors extends ThemeExtension<QuireColors> {
  const QuireColors({
    required this.hlPinBase,
    required this.hlPinFg,
    required this.hlPinWash,
    required this.hlAlertBase,
    required this.hlAlertFg,
    required this.hlAlertWash,
    required this.hlGrowBase,
    required this.hlGrowFg,
    required this.hlGrowWash,
    required this.hlWaitBase,
    required this.hlWaitFg,
    required this.hlWaitWash,
    required this.focusRing,
    required this.textTertiary,
    required this.inkPressed,
  });

  final Color hlPinBase;
  final Color hlPinFg;
  final Color hlPinWash;
  final Color hlAlertBase;
  final Color hlAlertFg;
  final Color hlAlertWash;
  final Color hlGrowBase;
  final Color hlGrowFg;
  final Color hlGrowWash;
  final Color hlWaitBase;
  final Color hlWaitFg;
  final Color hlWaitWash;
  final Color focusRing;

  /// Disabled text, hints — large/mono only (color.md).
  final Color textTertiary;

  /// Pressed fills, visited links.
  final Color inkPressed;

  @override
  QuireColors copyWith({
    Color? hlPinBase,
    Color? hlPinFg,
    Color? hlPinWash,
    Color? hlAlertBase,
    Color? hlAlertFg,
    Color? hlAlertWash,
    Color? hlGrowBase,
    Color? hlGrowFg,
    Color? hlGrowWash,
    Color? hlWaitBase,
    Color? hlWaitFg,
    Color? hlWaitWash,
    Color? focusRing,
    Color? textTertiary,
    Color? inkPressed,
  }) {
    return QuireColors(
      hlPinBase: hlPinBase ?? this.hlPinBase,
      hlPinFg: hlPinFg ?? this.hlPinFg,
      hlPinWash: hlPinWash ?? this.hlPinWash,
      hlAlertBase: hlAlertBase ?? this.hlAlertBase,
      hlAlertFg: hlAlertFg ?? this.hlAlertFg,
      hlAlertWash: hlAlertWash ?? this.hlAlertWash,
      hlGrowBase: hlGrowBase ?? this.hlGrowBase,
      hlGrowFg: hlGrowFg ?? this.hlGrowFg,
      hlGrowWash: hlGrowWash ?? this.hlGrowWash,
      hlWaitBase: hlWaitBase ?? this.hlWaitBase,
      hlWaitFg: hlWaitFg ?? this.hlWaitFg,
      hlWaitWash: hlWaitWash ?? this.hlWaitWash,
      focusRing: focusRing ?? this.focusRing,
      textTertiary: textTertiary ?? this.textTertiary,
      inkPressed: inkPressed ?? this.inkPressed,
    );
  }

  @override
  QuireColors lerp(QuireColors? other, double t) {
    if (other == null) return this;
    return QuireColors(
      hlPinBase: Color.lerp(hlPinBase, other.hlPinBase, t)!,
      hlPinFg: Color.lerp(hlPinFg, other.hlPinFg, t)!,
      hlPinWash: Color.lerp(hlPinWash, other.hlPinWash, t)!,
      hlAlertBase: Color.lerp(hlAlertBase, other.hlAlertBase, t)!,
      hlAlertFg: Color.lerp(hlAlertFg, other.hlAlertFg, t)!,
      hlAlertWash: Color.lerp(hlAlertWash, other.hlAlertWash, t)!,
      hlGrowBase: Color.lerp(hlGrowBase, other.hlGrowBase, t)!,
      hlGrowFg: Color.lerp(hlGrowFg, other.hlGrowFg, t)!,
      hlGrowWash: Color.lerp(hlGrowWash, other.hlGrowWash, t)!,
      hlWaitBase: Color.lerp(hlWaitBase, other.hlWaitBase, t)!,
      hlWaitFg: Color.lerp(hlWaitFg, other.hlWaitFg, t)!,
      hlWaitWash: Color.lerp(hlWaitWash, other.hlWaitWash, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      inkPressed: Color.lerp(inkPressed, other.inkPressed, t)!,
    );
  }
}

/// Daylight highlighters — color.md semantic table.
const quireColorsLight = QuireColors(
  hlPinBase: Color(0xFFF2C94C),
  hlPinFg: Color(0xFF7A5E00),
  hlPinWash: Color(0x4DF2C94C), // base @ 30%
  hlAlertBase: Color(0xFFE5484D),
  hlAlertFg: Color(0xFFB02A30),
  hlAlertWash: Color(0x24E5484D), // base @ 14%
  hlGrowBase: Color(0xFF3FB97F),
  hlGrowFg: Color(0xFF17603E),
  hlGrowWash: Color(0x293FB97F), // base @ 16%
  hlWaitBase: Color(0xFFED8B16),
  hlWaitFg: Color(0xFF8F5606),
  hlWaitWash: Color(0x29ED8B16), // base @ 16%
  focusRing: Color(0xFF2F4BD7),
  textTertiary: Color(0xFF8A91A3),
  inkPressed: Color(0xFF2439AC),
);

/// Lamplight highlighters — same meanings, lifted for warm charcoal.
const quireColorsDark = QuireColors(
  hlPinBase: Color(0xFFE8C34A),
  hlPinFg: Color(0xFFF4DC86),
  hlPinWash: Color(0x33E8C34A), // base @ 20%
  hlAlertBase: Color(0xFFFF8A85),
  hlAlertFg: Color(0xFFFFC2BE),
  hlAlertWash: Color(0x2EFF8A85), // base @ 18%
  hlGrowBase: Color(0xFF6FCB98),
  hlGrowFg: Color(0xFFA8E0C2),
  hlGrowWash: Color(0x2E6FCB98), // base @ 18%
  hlWaitBase: Color(0xFFF2A65A),
  hlWaitFg: Color(0xFFF8CF9E),
  hlWaitWash: Color(0x2EF2A65A), // base @ 18%
  focusRing: Color(0xFF93A8F0),
  textTertiary: Color(0xFF6E685C),
  inkPressed: Color(0xFFB7C4F5),
);
