import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A removable scope indicator (feedback F13): folder/tag filter as a pill
/// with a clear affordance.
class ScopeChip extends StatelessWidget {
  const ScopeChip({super.key, required this.icon, required this.label, required this.onClear});

  final IconData icon;
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onClear,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.close_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
