import 'package:flutter/material.dart';

import '../../../logic/editor_controller.dart';
import '../../../logic/search_controller.dart';
import '../../../theme/quire_colors.dart';
import '../../../theme/quire_theme.dart';

class StatusFooter extends StatelessWidget {
  const StatusFooter({super.key, required this.controller, required this.words});

  final EditorController controller;
  final int words;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quire =
        theme.extension<QuireColors>() ??
        (theme.brightness == Brightness.dark
            ? quireColorsDark
            : quireColorsLight);
    final mono = safeMono(
      TextStyle(
        fontSize: 12,
        letterSpacing: 0.2,
        color: theme.colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final status = switch (controller.status) {
      EditorStatus.clean => '',
      EditorStatus.dirty => 'unsaved · $words words',
      EditorStatus.saving => 'saving… · $words words',
      EditorStatus.saved =>
        'saved ${clockLabel(controller.lastSavedAt ?? DateTime.now())} · $words words',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: controller.status == EditorStatus.saved
                ? quire.hlGrowBase
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(status.isEmpty ? '$words words' : status, style: mono),
          ),
          Text(
            'Markdown  ·  #tag  ·  ![image|400]',
            style: safeMono(
              TextStyle(
                fontSize: 11,
                letterSpacing: 0.3,
                color: quire.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ctrl+B / Ctrl+I / Ctrl+U formatting request (Normal mode only).
