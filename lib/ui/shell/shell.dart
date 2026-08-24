import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../logic/editor_controller.dart';
import '../../logic/vault_controller.dart';
import '../../logic/zoom.dart';
import '../../models/note.dart';
import '../../theme/quire_theme.dart';
import '../dialogs/settings_dialog.dart';
import '../editor/editor_pane.dart';
import '../note_list/list_pane.dart';
import '../sidebar/sidebar.dart';
import '../sidebar/trash_view.dart';
import 'drag_divider.dart';
import 'pane_widths.dart';
import 'shortcuts.dart';

/// The desktop shell: sidebar | note list | editor, folding through the three
/// window tiers of layout-and-space.md. Owns the editor controller and keeps
/// it in sync with the selected note.
class Shell extends StatefulWidget {
  Shell({super.key, required this.controller, PaneWidths? paneWidths, this.onCreateNote})
    : paneWidths = paneWidths ?? _default;

  final VaultController controller;
  final PaneWidths paneWidths;

  /// Injectable note factory for tests; defaults to creating 'Untitled'
  /// in the selected folder.
  final Future<Note?> Function()? onCreateNote;

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
      _editor = EditorController(
        vault: widget.controller.repository,
        initialMode: widget.controller.settings.editorMode,
        onModeChanged: widget.controller.setEditorMode,
      );
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
      body: Actions(
        actions: sheafActions(
          onCreateNote: _createNote,
          onToggleSidebar: widths.toggleSidebar,
          onCycleTheme: () => controller.cycleTheme(),
          onDeleteSelectedNote: () {
            // Del keeps its text-editing meaning while an editor holds focus
            // (feedback F7): re-dispatch the native character-delete so the
            // shell binding doesn't swallow it.
            if (_focusInsideEditable()) {
              final editCtx = FocusManager.instance.primaryFocus?.context;
              if (editCtx != null && editCtx.mounted) {
                Actions.invoke(editCtx, const DeleteCharacterIntent(forward: true));
              }
              return;
            }
            _deleteSelectedWithUndo(context);
          },
          onZoomIn: () => controller.setZoom(stepZoom(controller.settings.zoomFactor, up: true)),
          onZoomOut: () => controller.setZoom(stepZoom(controller.settings.zoomFactor, up: false)),
          onZoomReset: () => controller.setZoom(1.0),
          onCycleEditorMode: () => _editor?.cycleMode(),
          onCycleNote: _cycleNote,
        ),
        child: Shortcuts(
          shortcuts: sheafShortcuts(),
          child: Focus(
            autofocus: true,
            child: ListenableBuilder(
              listenable: widths,
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) {
                  final tier = tierForWidth(constraints.maxWidth);
                  return Column(
                    children: [
                      _HeaderBar(controller: controller, tier: tier),
                      Expanded(
                        child: switch (tier) {
                          WindowTier.expanded => Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!widths.sidebarCollapsed)
                                Sidebar(
                                  controller: controller,
                                  width: widths.sidebar,
                                  onTrashTapped: () => showTrashDialog(context, controller),
                                  onSettingsTapped: () => showSettingsDialog(context, controller),
                                )
                              else
                                Rail(onExpand: widths.toggleSidebar),
                              if (!widths.sidebarCollapsed)
                                DragDivider(onDrag: (dx) => widths.sidebar += dx),
                              Expanded(child: _listAndEditor(controller, widths)),
                            ],
                          ),
                          WindowTier.full => Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Rail(onExpand: widths.toggleSidebar),
                              Expanded(child: _listAndEditor(controller, widths)),
                            ],
                          ),
                          WindowTier.stack => _StackShell(
                            controller: controller,
                            editor: _editor,
                            onCreateNote: _createNote,
                          ),
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Shared by Ctrl+N and the list pane's New-note affordance.
  Future<Note?> _createNote() async {
    final custom = widget.onCreateNote;
    final controller = widget.controller;
    final note = await (custom != null ? custom() : controller.createNote(title: 'Untitled'));
    if (note != null) controller.selectNote(note);
    return note;
  }

  /// True when the primary focus sits inside any text field.
  bool _focusInsideEditable() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null || !ctx.mounted) return false;
    var inside = false;
    ctx.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        inside = true;
        return false;
      }
      return true;
    });
    return inside;
  }

  /// Moves the selection through the visible list order, wrapping at the
  /// ends (story 11). With nothing selected, forward picks the first and
  /// backward picks the last note.
  void _cycleNote(bool forward) {
    final controller = widget.controller;
    final visible = controller.visibleNotes.toList(growable: false);
    if (visible.isEmpty) return;

    final current = controller.selectedNote;
    final index = current == null ? -1 : visible.indexWhere((n) => n.path == current.path);
    final step = forward ? 1 : -1;
    // +visible.length keeps negative indexes (nothing selected) in range.
    final next = visible[(index + step + visible.length) % visible.length];
    controller.selectNote(next);
  }

  /// Deletes the selected note and offers an undo toast backed by trash.
  Future<void> _deleteSelectedWithUndo(BuildContext context) async {
    final controller = widget.controller;
    final note = controller.selectedNote;
    if (note == null) return;

    await controller.deleteNote(note.path);
    final entries = await controller.trash();
    if (!context.mounted || entries.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${note.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => controller.restoreFromTrash(entries.first.trashedName),
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
          child: ListPane(controller: controller, onCreateNote: _createNote),
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

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.controller, required this.tier});
  final VaultController controller;
  final WindowTier tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Wordmark
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'T',
                    style: GoogleFonts.bricolageGrotesque(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: theme.colorScheme.onPrimary,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sheaf',
                style: GoogleFonts.bricolageGrotesque(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: -0.3,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  'QUIRE',
                  style: GoogleFonts.splineSansMono(
                    fontSize: 9,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Global search (center) — only on expanded/full
          if (tier != WindowTier.stack)
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(QuireRadius.pill),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Search notes…  ⌘K',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '⌘K',
                            style: GoogleFonts.splineSansMono(
                              fontSize: 10,
                              letterSpacing: 0.4,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (tier == WindowTier.stack) const Spacer(),
          // Right controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Cycle theme  (Ctrl+Shift+L)',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => controller.cycleTheme(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Window controls',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WinDot(color: const Color(0xFFEB6A5E)),
                    const SizedBox(width: 6),
                    _WinDot(color: const Color(0xFFF2C94C)),
                    const SizedBox(width: 6),
                    _WinDot(color: const Color(0xFF3FB97F)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WinDot extends StatelessWidget {
  const _WinDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
    );
  }
}

class _StackShell extends StatelessWidget {
  const _StackShell({required this.controller, required this.onCreateNote, required this.editor});

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
              Expanded(child: EditorPane(controller: editor)),
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
