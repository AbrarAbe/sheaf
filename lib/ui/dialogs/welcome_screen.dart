import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../logic/vault_controller.dart';
import '../../theme/quire_colors.dart';
import '../../theme/quire_theme.dart';
import 'widgets/paper_stack.dart';

/// First-run screen when no vault folder has been chosen yet.
/// A quiet, paper-first welcome that states what Sheaf *is* before asking
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
                  'Sheaf',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                // Wordmark + paper stack
                PaperStack(isLight: isLight, primary: theme.colorScheme.primary, card: theme.colorScheme.surfaceContainerLowest, hairline: theme.colorScheme.outlineVariant),
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
                  'Sheaf keeps a vault — an ordinary folder of plain Markdown files.\n'
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
