import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../logic/vault_controller.dart';
import '../../../models/settings.dart';
import '../../../theme/quire_colors.dart';
import '../window_controls.dart';
import 'win_dot.dart';

/// The desktop shell: sidebar | note list | editor, folding through the three
/// window tiers of layout-and-space.md. Owns the editor controller and keeps
/// it in sync with the selected note.

class HeaderBar extends StatelessWidget {
  const HeaderBar({
    super.key,
    required this.controller,
    required this.tier,
    required this.sidebarVisible,
    required this.focusMode,
    required this.onToggleSidebar,
    required this.onToggleFocusMode,
    required this.windowControls,
    required this.showWindowControls,
    required this.onOpenPalette,
  });
  final VaultController controller;
  final WindowTier tier;
  final bool sidebarVisible;
  final bool focusMode;
  final VoidCallback onToggleSidebar;
  final VoidCallback onToggleFocusMode;
  final WindowControls windowControls;
  final bool showWindowControls;
  final VoidCallback onOpenPalette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    // Highlighter tokens double as the window-dot palette (feedback F15).
    final quire = theme.extension<QuireColors>() ?? (isLight ? quireColorsLight : quireColorsDark);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      // Layered header (round 6): the search pill floats dead-center so
      // neither side's width can move it; window chrome packs tight right.
      // expand keeps the base Row filling the bar (loose fit pinned it to
      // the top, eating the vertical padding).
      child: Stack(
        fit: StackFit.expand,
        children: [
          Row(
            children: [
              // Sidebar visibility toggle — user-owned in every tier (task 10).
              Tooltip(
                message: sidebarVisible ? 'Hide sidebar  (Ctrl+\\)' : 'Show sidebar  (Ctrl+\\)',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    key: const Key('sidebar-toggle'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: onToggleSidebar,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        sidebarVisible ? Icons.menu_open_rounded : Icons.menu_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Wordmark
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'S',
                        style: GoogleFonts.bricolageGrotesque(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: theme.colorScheme.onPrimary,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sheaf',
                    style: GoogleFonts.bricolageGrotesque(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: -0.3,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      'QUIRE',
                      style: GoogleFonts.splineSansMono(
                        fontSize: 9,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Right controls. Focus mode lives here too (feedback F14):
              // window-level chrome clusters on the right, away from navigation.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Focus mode (task 12): editor-only surface.
                  Tooltip(
                    message: focusMode ? 'Exit focus mode  (F10)' : 'Focus mode  (F10)',
                    child: Material(
                      color: focusMode ? theme.colorScheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        key: const Key('focus-toggle'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: onToggleFocusMode,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            focusMode ? Icons.center_focus_weak : Icons.center_focus_strong,
                            size: 18,
                            color: focusMode
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Cycle theme  (Ctrl+Shift+L)',
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        key: const Key('theme-toggle'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => controller.cycleTheme(),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showWindowControls)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          WinDot(
                            key: const Key('win-minimize'),
                            color: quire.hlPinBase,
                            glyph: Icons.remove_rounded,
                            tooltip: 'Minimize',
                            onTap: () => windowControls.minimize(),
                          ),
                          WinDot(
                            key: const Key('win-maximize'),
                            color: quire.hlGrowBase,
                            glyph: Icons.crop_square_rounded,
                            tooltip: 'Maximize',
                            onTap: () => windowControls.toggleMaximize(),
                          ),
                          WinDot(
                            key: const Key('win-close'),
                            color: quire.hlAlertBase,
                            glyph: Icons.close_rounded,
                            tooltip: 'Close',
                            onTap: () => windowControls.close(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Quick-switcher pill (feedback F12): vault-wide search entry.
          // Hidden on stack tier where space is scarce — Ctrl+K still works.
          if (tier != WindowTier.stack)
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Material(
                  color: theme.colorScheme.surfaceContainerLowest,
                  shape: StadiumBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: .7)),
                  ),
                  child: InkWell(
                    key: const Key('palette-pill'),
                    customBorder: const StadiumBorder(),
                    onTap: onOpenPalette,
                    hoverColor: theme.colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, size: 16, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(
                            'Search notes…',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: .6),
                              ),
                            ),
                            child: Text(
                              'Ctrl K',
                              style: GoogleFonts.splineSansMono(
                                fontSize: 10,
                                letterSpacing: 0.4,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One traffic-light control: a colored dot that grows slightly on hover and
/// reveals its glyph (feedback F15). Tap area stays fixed so the gesture
/// doesn't shift mid-press.
