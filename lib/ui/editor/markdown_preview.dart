import 'dart:io';

import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:path/path.dart' as p;

import '../../theme/quire_theme.dart';

/// Rendered markdown for the read mode of the editor.
///
/// Images resolve vault-relative paths against [vaultRoot]; the Obsidian
/// `![alt|400]` width syntax constrains display width.
class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({super.key, required this.body, required this.vaultRoot});

  final String body;
  final Directory vaultRoot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = MarkdownConfig(
      configs: [
        ImgConfig(builder: _image),
        PConfig(textStyle: _style(theme.textTheme.bodyLarge, theme)),
        H1Config(
          style: _style(
            theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            theme,
          ),
        ),
        H2Config(
          style: _style(
            theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            theme,
          ),
        ),
        H3Config(
          style: _style(theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600), theme),
        ),
        const CodeConfig(style: TextStyle(fontFamily: 'monospace')),
        PreConfig(
          textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(QuireRadius.s),
          ),
        ),
        BlockquoteConfig(
          sideColor: theme.colorScheme.primary,
          textColor: theme.colorScheme.onSurface,
        ),
        TableConfig(
          headerStyle: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
          bodyStyle: TextStyle(color: theme.colorScheme.onSurface),
        ),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(QuireSpace.xl),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: MarkdownGenerator(
            linesMargin: const EdgeInsets.symmetric(vertical: QuireSpace.s),
          ).buildWidgets(body, config: config),
        ),
      ),
    );
  }

  TextStyle _style(TextStyle? base, ThemeData theme) =>
      (base ?? theme.textTheme.bodyLarge!).copyWith(color: theme.colorScheme.onSurface);

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
        builder: (context) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, size: 18, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: QuireSpace.xs),
            Text(alt, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    } else {
      image = Image.file(
        file,
        width: width?.toDouble(),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
      );
    }

    return KeyedSubtree(key: Key(width == null ? 'md-img-natural' : 'md-img-$width'), child: image);
  }
}
