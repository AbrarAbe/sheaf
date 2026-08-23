import 'package:flutter/material.dart';

import '../../logic/editor_controller.dart';
import '../../logic/vault_controller.dart';
import '../editor/editor_pane.dart';
import '../note_list/list_pane.dart';
import '../sidebar/sidebar.dart';
import 'drag_divider.dart';
import 'pane_widths.dart';

/// The desktop shell: sidebar | note list | editor, folding through the three
/// window tiers of layout-and-space.md. Owns the editor controller and keeps
/// it in sync with the selected note.
class Shell extends StatefulWidget {
  Shell({super.key, required this.controller, PaneWidths? paneWidths})
    : paneWidths = paneWidths ?? _default;

  final VaultController controller;
  final PaneWidths paneWidths;

  static final PaneWidths _default = PaneWidths();

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  EditorController? _editor;
  String? _syncedPath;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncSelection);
    _ensureEditor();
  }

  void _ensureEditor() {
    if (_editor == null && widget.controller.hasVault) {
      _editor = EditorController(vault: widget.controller.repository);
    }
  }

  @override
  void didUpdateWidget(Shell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncSelection);
      widget.controller.addListener(_syncSelection);
      _editor?.dispose();
      _editor = null;
      _syncedPath = null;
      _ensureEditor();
      _syncSelection();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncSelection);
    _editor?.dispose();
    super.dispose();
  }

  void _syncSelection() {
    _ensureEditor();
    final editor = _editor;
    if (editor == null) return;

    final note = widget.controller.selectedNote;
    if (note?.path == _syncedPath) return;
    _syncedPath = note?.path;

    // The note object is already parsed in memory — no disk round-trip,
    // so opening stays safe in any synchronous context.
    if (note == null) {
      editor.close();
    } else {
      editor.open(note);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final widths = widget.paneWidths;

    return Scaffold(
      body: ListenableBuilder(
        listenable: widths,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final tier = tierForWidth(constraints.maxWidth);
            return switch (tier) {
              WindowTier.expanded => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widths.sidebarCollapsed)
                    Sidebar(controller: controller, width: widths.sidebar)
                  else
                    const Rail(),
                  if (!widths.sidebarCollapsed) DragDivider(onDrag: (dx) => widths.sidebar += dx),
                  Expanded(child: _listAndEditor(controller, widths)),
                ],
              ),
              WindowTier.full => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Rail(),
                  Expanded(child: _listAndEditor(controller, widths)),
                ],
              ),
              WindowTier.stack => _StackShell(controller: controller),
            };
          },
        ),
      ),
    );
  }

  Widget _listAndEditor(VaultController controller, PaneWidths widths) {
    return Row(
      children: [
        SizedBox(
          key: const Key('pane-list'),
          width: widths.list,
          child: ListPane(controller: controller),
        ),
        DragDivider(onDrag: (dx) => widths.list += dx),
        Expanded(
          key: const Key('pane-editor'),
          child: EditorPane(controller: _editor),
        ),
      ],
    );
  }
}

class _StackShell extends StatelessWidget {
  const _StackShell({required this.controller});

  final VaultController controller;

  @override
  Widget build(BuildContext context) {
    // One pane at a time below 720 dp; list first, editor swaps in place.
    return SizedBox(
      key: const Key('pane-list'),
      child: ListPane(controller: controller),
    );
  }
}
