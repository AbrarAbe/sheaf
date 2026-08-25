import 'package:flutter/material.dart';

import 'quire_colors.dart';
import 'quire_theme.dart';

/// A named pair of hand-tuned light/dark themes (spec story 16).
///
/// Worlds are curated in code — never user-supplied hex — so the
/// no-colors-outside-lib/theme boundary holds. [id] is the stable settings
/// key; [label] is what the picker shows.
class ThemeWorld {
  const ThemeWorld({
    required this.id,
    required this.label,
    required this.light,
    required this.dark,
  });

  final String id;
  final String label;
  final ThemeData Function() light;
  final ThemeData Function() dark;
}

/// Re-tints only the world-specific chrome of a semantic highlighter set.
/// The hl* hues are meanings (pin/alert/grow/wait), constant across worlds.
QuireColors _chrome(
  QuireColors base, {
  required Color focusRing,
  required Color textTertiary,
  required Color inkPressed,
}) => base.copyWith(focusRing: focusRing, textTertiary: textTertiary, inkPressed: inkPressed);

// ---- Graphite — cool neutral grays, slate ink -------------------------------

ThemeData _graphiteLight() {
  return buildTokens(
    brightness: Brightness.light,
    surface: const Color(0xFFF4F5F6),
    card: Colors.white,
    raised: const Color(0xFFE9EBEE),
    inset: const Color(0xFFE3E6EA),
    onSurface: const Color(0xFF1A1D21),
    onSurfaceVariant: const Color(0xFF59616C),
    outlineVariant: const Color(0xFFD9DDE2),
    primary: const Color(0xFF3E4C59),
    onPrimary: Colors.white,
    secondaryContainer: const Color(0xFF3E4C59).withValues(alpha: 0.10),
    error: quireColorsLight.hlAlertFg,
    focusColor: const Color(0xFF3E4C59),
    selection: const Color(0xFF3E4C59).withValues(alpha: 0.22),
    extensions: [
      _chrome(
        quireColorsLight,
        focusRing: const Color(0xFF3E4C59),
        textTertiary: const Color(0xFF8B95A1),
        inkPressed: const Color(0xFF2F3944),
      ),
    ],
  );
}

ThemeData _graphiteDark() {
  return buildTokens(
    brightness: Brightness.dark,
    surface: const Color(0xFF14161A),
    card: const Color(0xFF1B1E23),
    raised: const Color(0xFF24282E),
    containerLow: const Color(0xFF101215),
    containerHighest: const Color(0xFF24282E),
    onSurface: const Color(0xFFE7EAEE),
    onSurfaceVariant: const Color(0xFF99A3AE),
    outlineVariant: const Color(0xFF2E333A),
    primary: const Color(0xFFA3B5C2),
    onPrimary: const Color(0xFF12161B),
    secondaryContainer: const Color(0xFFA3B5C2).withValues(alpha: 0.16),
    error: quireColorsDark.hlAlertFg,
    focusColor: const Color(0xFFA3B5C2),
    selection: const Color(0xFFA3B5C2).withValues(alpha: 0.24),
    extensions: [
      _chrome(
        quireColorsDark,
        focusRing: const Color(0xFFA3B5C2),
        textTertiary: const Color(0xFF646D77),
        inkPressed: const Color(0xFFB9CAD6),
      ),
    ],
  );
}

// ---- Sepia — warm paper, walnut ink ------------------------------------------

ThemeData _sepiaLight() {
  return buildTokens(
    brightness: Brightness.light,
    surface: const Color(0xFFF6F0E4),
    card: const Color(0xFFFDF9F0),
    raised: const Color(0xFFEFE7D7),
    inset: const Color(0xFFE9DFCC),
    onSurface: const Color(0xFF3B3428),
    onSurfaceVariant: const Color(0xFF6E6350),
    outlineVariant: const Color(0xFFDED2BC),
    primary: const Color(0xFF7A4E22),
    onPrimary: Colors.white,
    secondaryContainer: const Color(0xFF7A4E22).withValues(alpha: 0.12),
    error: quireColorsLight.hlAlertFg,
    focusColor: const Color(0xFF7A4E22),
    selection: const Color(0xFF7A4E22).withValues(alpha: 0.24),
    extensions: [
      _chrome(
        quireColorsLight,
        focusRing: const Color(0xFF7A4E22),
        textTertiary: const Color(0xFF9C8F79),
        inkPressed: const Color(0xFF5E3B19),
      ),
    ],
  );
}

ThemeData _sepiaDark() {
  return buildTokens(
    brightness: Brightness.dark,
    surface: const Color(0xFF171310),
    card: const Color(0xFF201A14),
    raised: const Color(0xFF29221A),
    containerLow: const Color(0xFF100D0A),
    containerHighest: const Color(0xFF29221A),
    onSurface: const Color(0xFFEDE3D2),
    onSurfaceVariant: const Color(0xFFB3A58D),
    outlineVariant: const Color(0xFF352C22),
    primary: const Color(0xFFD9A05B),
    onPrimary: const Color(0xFF201407),
    secondaryContainer: const Color(0xFFD9A05B).withValues(alpha: 0.18),
    error: quireColorsDark.hlAlertFg,
    focusColor: const Color(0xFFD9A05B),
    selection: const Color(0xFFD9A05B).withValues(alpha: 0.26),
    extensions: [
      _chrome(
        quireColorsDark,
        focusRing: const Color(0xFFD9A05B),
        textTertiary: const Color(0xFF7A7060),
        inkPressed: const Color(0xFFE5B273),
      ),
    ],
  );
}

/// The launch set, ordered as the settings picker shows them.
final List<ThemeWorld> themeWorlds = [
  ThemeWorld(id: 'quire', label: 'Quire', light: buildQuireLight, dark: buildQuireDark),
  ThemeWorld(id: 'graphite', label: 'Graphite', light: _graphiteLight, dark: _graphiteDark),
  ThemeWorld(id: 'sepia', label: 'Sepia', light: _sepiaLight, dark: _sepiaDark),
];

/// Resolves [id] to a world; unknown ids fall back to the Quire brand set.
ThemeWorld worldById(String id) =>
    themeWorlds.firstWhere((w) => w.id == id, orElse: () => themeWorlds.first);
