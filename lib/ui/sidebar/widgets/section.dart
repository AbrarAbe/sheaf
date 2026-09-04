import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


/// Quick filters, folder tree, tags, and trash — the leftmost pane.
/// The desk drawer: quiet until touched, tint and weight do the talking.

class Section extends StatelessWidget {
  const Section({super.key, required this.child, this.label, this.trailing});

  final Widget child;
  final String? label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label!,
                    style: GoogleFonts.splineSansMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.9,
                      height: 16 / 11,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        child,
      ],
    );
  }
}
