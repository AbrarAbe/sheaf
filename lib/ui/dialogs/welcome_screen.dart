import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../logic/vault_controller.dart';
import '../../theme/quire_colors.dart';
import '../../theme/quire_theme.dart';

/// First-run screen when no vault folder has been chosen yet.
/// A quiet, paper-first welcome that states what Taker *is* before asking
/// for a folder — plain Markdown files in an ordinary folder.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.controller, this.pickFolder = defaultPickFolder});

  final VaultController controller;

  /// Injectable for tests; production opens the native folder dialog.
  final Future<String?> Function() pickFolder;

  static Future<String?> defaultPickFolder() =>
      FilePicker.getDirectoryPath(dialogTitle: 'Choose a vault folder');

  Future<void> _choose() async {
    final path = await pickFolder();
    if (path != null) await controller.openVault(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final quire = theme.extension<QuireColors>() ?? (theme.brightness == Brightness.dark ? quireColorsDark : quireColorsLight);
    final onSurface = theme.colorScheme.onSurface;
    final onVariant = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(QuireSpace.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Eyebrow
                Text(
                  'QUIRE  ·  A GATHERING OF FOLDED PAGES',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.splineSansMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                    height: 16 / 11,
                    color: onVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Taker',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                // Wordmark + paper stack
                _PaperStack(isLight: isLight, primary: theme.colorScheme.primary, card: theme.colorScheme.surfaceContainerLowest, hairline: theme.colorScheme.outlineVariant),
                const SizedBox(height: 28),
                Text(
                  'Your notes,',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: -0.8,
                    color: onSurface,
                  ),
                ),
                Text(
                  'on paper that keeps.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 40,
                    fontWeight: FontWeight.w400,
                    height: 1.0,
                    letterSpacing: -0.8,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Taker keeps a vault — an ordinary folder of plain Markdown files.\n'
                  'No database. No lock-in. Just files you can open anywhere.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 24 / 15,
                    color: onVariant,
                  ),
                ),
                const SizedBox(height: 32),
                // Card with CTA
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(QuireRadius.l),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.folder_open_rounded, size: 18, color: theme.colorScheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choose a vault folder',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 20 / 14,
                                    color: onSurface,
                                  ),
                                ),
                                Text(
                                  'You can change this anytime in Settings.',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    height: 16 / 12,
                                    color: onVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _choose,
                        icon: const Icon(Icons.folder_outlined, size: 18),
                        label: const Text('Choose folder…'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Creates the folder if it does not exist. Files stay readable in any editor.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.splineSansMono(
                          fontSize: 11,
                          height: 16 / 11,
                          letterSpacing: 0.2,
                          color: quire.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description_outlined, size: 12, color: quire.textTertiary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Plain .md files  ·  #tags  ·  ![image|400] resizing',
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: GoogleFonts.splineSansMono(
                          fontSize: 11,
                          letterSpacing: 0.3,
                          color: quire.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaperStack extends StatelessWidget {
  const _PaperStack({required this.isLight, required this.primary, required this.card, required this.hairline});
  final bool isLight;
  final Color primary;
  final Color card;
  final Color hairline;

  @override
  Widget build(BuildContext context) {
    // Three layered paper sheets, offset — the quire metaphor.
    // Top sheet carries a single ink stroke (primary) as a signature.
    return SizedBox(
      width: 120,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Back sheet
          Positioned(
            top: 12,
            child: Transform.rotate(
              angle: -0.07,
              child: Container(
                width: 96,
                height: 68,
                decoration: BoxDecoration(
                  color: card.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: hairline),
                ),
              ),
            ),
          ),
          // Middle sheet
          Positioned(
            top: 6,
            child: Transform.rotate(
              angle: 0.05,
              child: Container(
                width: 96,
                height: 68,
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: hairline),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
              ),
            ),
          ),
          // Front sheet
          Container(
            width: 96,
            height: 68,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: hairline),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 8, width: 42, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                ...List.generate(3, (i) => Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: hairline.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2C94C).withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '#quire',
                      style: GoogleFonts.splineSansMono(fontSize: 7, letterSpacing: 0.4, color: const Color(0xFF7A5E00)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
