import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../logic/editor_controller.dart';
import '../../../logic/vault_controller.dart';
import '../../../models/note.dart';
import '../../editor/editor_pane.dart';
import '../../note_list/list_pane.dart';

/// The desktop shell: sidebar | note list | editor, folding through the three
/// window tiers of layout-and-space.md. Owns the editor controller and keeps
/// it in sync with the selected note.

class StackShell extends StatelessWidget {
  const StackShell({
    super.key,
    required this.controller,
    required this.onCreateNote,
    required this.editor,
  });

  final VaultController controller;
  final EditorController? editor;
  final Future<Note?> Function() onCreateNote;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selected = controller.selectedNote;
        // If a note is selected, show editor with back affordance.
        if (selected != null && editor != null) {
          return Column(
            children: [
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  border: Border(
                    bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      tooltip: 'Back to list',
                      onPressed: () => controller.selectNote(null),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        selected.title.isEmpty ? 'Untitled' : selected.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: EditorPane(controller: editor, settings: controller.settings),
              ),
            ],
          );
        }
        return SizedBox(
          key: const Key('pane-list'),
          child: ListPane(controller: controller, onCreateNote: onCreateNote),
        );
      },
    );
  }
}
