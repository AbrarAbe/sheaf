import 'package:flutter/material.dart';

import 'quire_colors.dart';

/// Radius scale from layout-and-space.md.
abstract final class QuireRadius {
  static const pill = 999.0;
  static const xl = 20.0; // sheets, dialogs, command palette
  static const l = 16.0; // note cards, expanded composer
  static const m = 12.0; // inputs, menus
  static const s = 8.0; // small buttons, code spans
}

/// Spacing ramp — 8 pt grid with 4 pt half-steps.
abstract final class QuireSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

/// Builds the Daylight (light) theme by hand from Quire tokens.
/// Brand tokens always win over any dynamic/seeded scheme (theming.md).
ThemeData buildQuireLight() {
  const canvas = Color(0xFFF3F4F7);
  const card = Color(0xFFFFFFFF);
  const raised = Color(0xFFEAEDF1);
  const inset = Color(0xFFE4E8EF);
  const textPrimary = Color(0xFF191C24);
  const textSecondary = Color(0xFF565D6E);
  const hairline = Color(0xFFD8DDE6);
  const ink = Color(0xFF2F4BD7);

  return _build(
    brightness: Brightness.light,
    surface: canvas,
    card: card,
    raised: raised,
    inset: inset,
    onSurface: textPrimary,
    onSurfaceVariant: textSecondary,
    outlineVariant: hairline,
    primary: ink,
    onPrimary: Colors.white,
    secondaryContainer: ink.withValues(alpha: 0.10), // accent.wash
    error: quireColorsLight.hlAlertFg,
    focusColor: quireColorsLight.focusRing,
    selection: ink.withValues(alpha: 0.24),
    extensions: [quireColorsLight],
  );
}

/// Builds the Lamplight (dark) theme — warm charcoal, brightened ink.
ThemeData buildQuireDark() {
  const canvas = Color(0xFF131110);
  const card = Color(0xFF1D1B17);
  const raised = Color(0xFF26231D);
  const inset = Color(0xFF0E0D0C);
  const textPrimary = Color(0xFFECE7DC);
  const textSecondary = Color(0xFFA69F8F);
  const hairline = Color(0xFF33302A);
  const ink = Color(0xFF93A8F0);

  return _build(
    brightness: Brightness.dark,
    surface: canvas,
    card: card,
    raised: raised,
    // Dark mapping per theming.md: inset → surfaceContainerLow.
    containerLow: inset,
    containerHighest: raised,
    onSurface: textPrimary,
    onSurfaceVariant: textSecondary,
    outlineVariant: hairline,
    primary: ink,
    onPrimary: const Color(0xFF10131F), // inverted onInk
    secondaryContainer: ink.withValues(alpha: 0.16), // accent.wash
    error: quireColorsDark.hlAlertFg,
    focusColor: quireColorsDark.focusRing,
    selection: ink.withValues(alpha: 0.24),
    extensions: [quireColorsDark],
  );
}

ThemeData _build({
  required Brightness brightness,
  required Color surface,
  required Color card,
  required Color raised,
  Color? inset,
  Color? containerLow,
  Color? containerHighest,
  required Color onSurface,
  required Color onSurfaceVariant,
  required Color outlineVariant,
  required Color primary,
  required Color onPrimary,
  required Color secondaryContainer,
  required Color error,
  required Color focusColor,
  required Color selection,
  required List<ThemeExtension> extensions,
}) {
  final isLight = brightness == Brightness.light;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    secondary: primary,
    onSecondary: onPrimary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSurface,
    error: error,
    onError: isLight ? Colors.white : const Color(0xFF131110),
    surface: surface,
    onSurface: onSurface,
    surfaceContainerLowest: card,
    surfaceContainerLow: containerLow ?? inset ?? raised,
    surfaceContainer: isLight ? (inset ?? raised) : raised,
    surfaceContainerHigh: raised,
    surfaceContainerHighest: containerHighest ?? inset,
    onSurfaceVariant: onSurfaceVariant,
    outline: onSurfaceVariant,
    outlineVariant: outlineVariant,
    inverseSurface: isLight ? const Color(0xFF26231D) : const Color(0xFFFFFFFF),
    onInverseSurface: isLight ? const Color(0xFFECE7DC) : const Color(0xFF191C24),
    inversePrimary: isLight ? const Color(0xFF93A8F0) : const Color(0xFF2F4BD7),
    surfaceTint: primary,
  );

  final baseText = Typography.material2021(platform: TargetPlatform.linux).englishLike
      .apply(bodyColor: onSurface, displayColor: onSurface);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    focusColor: focusColor,
    splashFactory: InkSparkle.splashFactory,
    extensions: extensions,
    scaffoldBackgroundColor: surface,
    textTheme: baseText,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: primary,
      selectionColor: selection,
      selectionHandleColor: primary,
    ),
    dividerTheme: DividerThemeData(color: outlineVariant, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(QuireRadius.l),
        side: BorderSide(color: outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(QuireRadius.xl)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inset,
      hintStyle: TextStyle(color: onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(QuireRadius.m),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(QuireRadius.m),
        borderSide: BorderSide(color: focusColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: QuireSpace.m,
        vertical: QuireSpace.m - 2,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: secondaryContainer,
      labelStyle: TextStyle(color: onSurface),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(card),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(24),
        shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.18)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(QuireRadius.m)),
        ),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFF26231D) : card,
        borderRadius: BorderRadius.circular(QuireRadius.s),
      ),
      textStyle: TextStyle(color: isLight ? const Color(0xFFECE7DC) : onSurface),
    ),
  );
}
