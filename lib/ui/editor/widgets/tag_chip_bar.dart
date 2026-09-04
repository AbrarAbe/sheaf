import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TagChipBar extends StatelessWidget {
  const TagChipBar({super.key, required this.tags, required this.onTap, this.focusMode = false});

  final List<String> tags;
  final ValueChanged<String> onTap;
  final bool focusMode;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final tag in tags)
            Tooltip(
              message: '#$tag',
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onTap(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '#$tag',
                    style: GoogleFonts.hankenGrotesk(
                      textStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 16 / 12.5,
                        color: theme.colorScheme.onSurface,
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
