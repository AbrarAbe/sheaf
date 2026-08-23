import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:path/path.dart' as p;

import '../../theme/quire_colors.dart';
import '../../theme/quire_theme.dart';

/// Rendered markdown for the read mode of the editor.
/// Paper prose: Hanken for reading, Bricolage for headings, mono for code.
/// Images resolve vault-relative paths against [vaultRoot]; the Obsidian
/// `![alt|400]` width syntax constrains display width.
class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({super.key, required this.body, required this.vaultRoot});

  final String body;
  final Directory vaultRoot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quire = theme.extension<QuireColors>() ?? (theme.brightness == Brightness.dark ? quireColorsDark : quireColorsLight);
    final onSurface = theme.colorScheme.onSurface;
    final inset = theme.colorScheme.surfaceContainerHighest;

    final config = MarkdownConfig(
      configs: [
        ImgConfig(builder: _image),
        PConfig(
          textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 16,
            height: 26 / 16,
            fontWeight: FontWeight.w400,
            color: onSurface,
          ),
        ),
        H1Config(
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 28,
            height: 34 / 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: onSurface,
          ),
        ),
        H2Config(
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 22,
            height: 28 / 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: onSurface,
          ),
        ),
        H3Config(
          style: GoogleFonts.hankenGrotesk(
            fontSize: 17,
            height: 24 / 17,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
        ),
        CodeConfig(
          style: GoogleFonts.splineSansMono(
            fontSize: 13,
            height: 18 / 13,
            color: onSurface,
            backgroundColor: inset,
          ),
        ),
        PreConfig(
          textStyle: GoogleFonts.splineSansMono(
            fontSize: 13,
            height: 18 / 13,
            color: onSurface,
          ),
          decoration: BoxDecoration(
            color: inset,
            borderRadius: BorderRadius.circular(QuireRadius.s),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          padding: const EdgeInsets.all(14),
          language: '',
        ),
        BlockquoteConfig(
          sideColor: theme.colorScheme.primary,
          textColor: onSurface,
        ),
        TableConfig(
          headerStyle: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w600, fontSize: 14, color: onSurface),
          bodyStyle: GoogleFonts.hankenGrotesk(fontSize: 14, height: 20 / 14, color: onSurface),
          wrapper: (child) => Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(QuireRadius.s),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
        ListConfig(
          marker: (isOrdered, depth, index) => Container(
            margin: const EdgeInsets.only(top: 10, right: 8),
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
          ),
        ),
        CheckBoxConfig(
          builder: (checked) => Icon(
            checked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
            size: 18,
            color: checked ? theme.colorScheme.primary : quire.textTertiary,
          ),
        ),
      ],
    );

    // Empty body placeholder inside preview
    if (body.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Nothing written yet.\nSwitch back to Edit to start.',
            textAlign: TextAlign.center,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 14,
              height: 20 / 14,
              color: quire.textTertiary,
            ),
          ),
        ),
      );
    }

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: MarkdownGenerator(
            linesMargin: const EdgeInsets.symmetric(vertical: 7),
          ).buildWidgets(body, config: config),
        ),
      ),
    );
  }

  Widget _image(String url, Map<String, String> attributes) {
    final rawAlt = attributes['alt'] ?? '';

    // Obsidian width syntax rides at the end of alt text: `pic|300`.
    String alt = rawAlt;
    int? width;
    final pipe = rawAlt.lastIndexOf('|');
    if (pipe != -1 && pipe < rawAlt.length - 1) {
      final parsed = int.tryParse(rawAlt.substring(pipe + 1).trim());
      if (parsed != null && parsed > 0) {
        alt = rawAlt.substring(0, pipe).trim();
        width = parsed;
      }
    }

    final file = File(p.join(vaultRoot.path, url));

    Widget image;
    if (!file.existsSync()) {
      image = Builder(
        builder: (context) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(QuireRadius.s),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, size: 16, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Text(
                alt.isEmpty ? url : alt,
                style: GoogleFonts.splineSansMono(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    } else {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(QuireRadius.s),
        child: Image.file(
          file,
          width: width?.toDouble(),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
        ),
      );
    }

    return KeyedSubtree(key: Key(width == null ? 'md-img-natural' : 'md-img-$width'), child: image);
  }
}
