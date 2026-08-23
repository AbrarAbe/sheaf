import 'package:flutter/material.dart';

import '../../logic/vault_controller.dart';
import '../editor/editor_pane_placeholder.dart';
import '../note_list/list_pane.dart';
import '../sidebar/sidebar.dart';
import 'drag_divider.dart';
import 'pane_widths.dart';

/// The desktop shell: sidebar | note list | editor, folding through the three
/// window tiers of layout-and-space.md.
class Shell extends StatelessWidget {
  Shell({super.key, required this.controller, PaneWidths? paneWidths})
    : paneWidths = paneWidths ?? _default;

  final VaultController controller;
  final PaneWidths paneWidths;

  static final PaneWidths _default = PaneWidths();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: paneWidths,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final tier = tierForWidth(constraints.maxWidth);
            return switch (tier) {
              WindowTier.expanded => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!paneWidths.sidebarCollapsed)
                    Sidebar(controller: controller, width: paneWidths.sidebar)
                  else
                    const Rail(),
                  if (!paneWidths.sidebarCollapsed)
                    DragDivider(onDrag: (dx) => paneWidths.sidebar += dx),
                  Expanded(child: _listAndEditor(controller, paneWidths)),
                ],
              ),
              WindowTier.full => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Rail(),
                  Expanded(child: _listAndEditor(controller, paneWidths)),
                ],
              ),
              WindowTier.stack => _StackShell(controller: controller),
            };
          },
        ),
      ),
    );
  }

  static Widget _listAndEditor(VaultController controller, PaneWidths widths) {
    return Row(
      children: [
        SizedBox(
          key: const Key('pane-list'),
          width: widths.list,
          child: ListPane(controller: controller),
        ),
        DragDivider(onDrag: (dx) => widths.list += dx),
        const Expanded(key: Key('pane-editor'), child: EditorPanePlaceholder()),
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
