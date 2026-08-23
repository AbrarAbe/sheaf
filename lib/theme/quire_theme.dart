import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

TextStyle _safeBricolage(TextStyle s) => safeBricolage(s);
TextStyle _safeHanken(TextStyle s) => safeHanken(s);
TextStyle _safeMono(TextStyle s) => safeMono(s);

TextStyle safeBricolage(TextStyle s) {
  if (!GoogleFonts.config.allowRuntimeFetching) return s.copyWith(fontFamily: 'BricolageGrotesque');
  try {
    return GoogleFonts.bricolageGrotesque(textStyle: s);
  } catch (_) {
    return s.copyWith(fontFamily: 'BricolageGrotesque');
  }
}

TextStyle safeHanken(TextStyle s) {
  if (!GoogleFonts.config.allowRuntimeFetching) return s.copyWith(fontFamily: 'HankenGrotesk');
  try {
    return GoogleFonts.hankenGrotesk(textStyle: s);
  } catch (_) {
    return s.copyWith(fontFamily: 'HankenGrotesk');
  }
}

TextStyle safeMono(TextStyle s) {
  if (!GoogleFonts.config.allowRuntimeFetching) return s.copyWith(fontFamily: 'SplineSansMono');
  try {
    return GoogleFonts.splineSansMono(textStyle: s);
  } catch (_) {
    return s.copyWith(fontFamily: 'SplineSansMono');
  }
}

TextTheme _quireTextTheme(Color onSurface, Color onSurfaceVariant) {
  // Bricolage Grotesque — display moments
  // Hanken Grotesk — reading / UI
  // Spline Sans Mono — machine-recorded facts
  return TextTheme(
    // display.lg — Bricolage 600 34/40 -0.5% · Empty-state headlines
    displayLarge: _safeBricolage(TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 34,
      height: 40 / 34,
      letterSpacing: -0.17,
      color: onSurface,
    )),
    // display.sm — Bricolage 600 24/30 -0.25% · Title / screen heads
    displaySmall: _safeBricolage(TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 24,
      height: 30 / 24,
      letterSpacing: -0.06,
      color: onSurface,
    )),
    headlineSmall: _safeBricolage(TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 24,
      height: 30 / 24,
      letterSpacing: -0.06,
      color: onSurface,
    )),
    // heading — Hanken 700 20/28 · Card titles
    titleLarge: _safeHanken(TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 20,
      height: 28 / 20,
      letterSpacing: 0,
      color: onSurface,
    )),
    titleMedium: _safeHanken(TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 17,
      height: 24 / 17,
      color: onSurface,
    )),
    // body — Hanken 400 16/26 · Note bodies, editor
    bodyLarge: _safeHanken(TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 16,
      height: 26 / 16,
      letterSpacing: 0,
      color: onSurface,
    )),
    bodyMedium: _safeHanken(TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 14,
      height: 20 / 14,
      letterSpacing: 0.14,
      color: onSurface,
    )),
    // label — Hanken 500 14/20 +1% · Buttons, metadata
    labelLarge: _safeHanken(TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 14,
      height: 20 / 14,
      letterSpacing: 0.14,
      color: onSurface,
    )),
    // caption — Hanken 400 13/18 +1%
    bodySmall: _safeHanken(TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 13,
      height: 18 / 13,
      letterSpacing: 0.13,
      color: onSurfaceVariant,
    )),
    // mono — Spline Sans Mono 400 13/18 +2% · Timestamps, counts, footer
    labelSmall: _safeMono(TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 13,
      height: 18 / 13,
      letterSpacing: 0.26,
      color: onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    )),
    // labelMedium used for some chips
    labelMedium: _safeHanken(TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 13,
      height: 18 / 13,
      letterSpacing: 0.13,
      color: onSurface,
    )),
    headlineMedium: _safeBricolage(TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 28,
      height: 34 / 28,
      letterSpacing: -0.14,
      color: onSurface,
    )),
  );
}

/// Eyebrow style — Spline Mono 500 11/16 uppercase +8% — date groups, section labels.
/// Not part of TextTheme (uppercase transform required at callsite).
TextStyle quireEyebrow(BuildContext context) {
  final theme = Theme.of(context);
  final base = TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 11,
    height: 16 / 11,
    letterSpacing: 0.88,
    color: theme.colorScheme.onSurfaceVariant,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  return _safeMono(base);
}

/// Mono utility style — 13/18 +2% for footers, counts.
TextStyle quireMono(BuildContext context, {Color? color}) {
  final base = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 18 / 13,
    letterSpacing: 0.26,
    color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  return _safeMono(base);
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

  final textTheme = _quireTextTheme(onSurface, onSurfaceVariant);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    focusColor: focusColor,
    splashFactory: InkSparkle.splashFactory,
    extensions: extensions,
    scaffoldBackgroundColor: surface,
    textTheme: textTheme,
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
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isLight ? const Color(0xFF191C24) : const Color(0xFFECE7DC),
      contentTextStyle: _safeHanken(TextStyle(
        fontSize: 14,
        color: isLight ? Colors.white : const Color(0xFF131110),
      )),
      actionTextColor: isLight ? const Color(0xFF93A8F0) : const Color(0xFF2F4BD7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(QuireRadius.m)),
      behavior: SnackBarBehavior.floating,
      elevation: 8,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: raised,
      scrolledUnderElevation: 0,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: _safeBricolage(TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: -0.12,
        color: onSurface,
      )),
      iconTheme: IconThemeData(color: onSurfaceVariant, size: 20),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inset ?? raised,
      hintStyle: _safeHanken(TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: onSurfaceVariant,
        letterSpacing: 0.14,
      )),
      prefixIconColor: onSurfaceVariant,
      suffixIconColor: onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(QuireRadius.m),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(QuireRadius.m),
        borderSide: BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(QuireRadius.m),
        borderSide: BorderSide(color: primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: QuireSpace.m,
        vertical: QuireSpace.s + 2,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: secondaryContainer,
      labelStyle: _safeHanken(TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 13,
        color: onSurface,
      )),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        textStyle: _safeHanken(TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(QuireRadius.pill)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: _safeHanken(TextStyle(fontWeight: FontWeight.w500, fontSize: 14, letterSpacing: 0.14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(QuireRadius.s)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(onSurfaceVariant),
        overlayColor: WidgetStatePropertyAll(primary.withValues(alpha: 0.08)),
        iconSize: const WidgetStatePropertyAll(20),
      ),
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
      textStyle: _safeHanken(TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: isLight ? const Color(0xFFECE7DC) : onSurface,
      )),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(onSurfaceVariant.withValues(alpha: 0.28)),
      trackColor: const WidgetStatePropertyAll(Colors.transparent),
      radius: const Radius.circular(4),
      thickness: const WidgetStatePropertyAll(6),
    ),
  );
}
