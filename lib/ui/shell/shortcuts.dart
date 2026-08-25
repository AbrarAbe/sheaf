import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/note.dart';

/// Intent for creating a new note (`Ctrl+N`).
class CreateNoteIntent extends Intent {
  const CreateNoteIntent();
}

/// Intent for collapsing/expanding the sidebar (`Ctrl+\`).
class ToggleSidebarIntent extends Intent {
  const ToggleSidebarIntent();
}

/// Intent for cycling theme mode (`Ctrl+Shift+L`).
class CycleThemeIntent extends Intent {
  const CycleThemeIntent();
}

/// Intent for deleting the selected note (`Del`).
class DeleteNoteIntent extends Intent {
  const DeleteNoteIntent();
}

/// Intent for selecting the note at [index] from the keyboard.
class SelectNoteIntent extends Intent {
  const SelectNoteIntent(this.note);
  final Note? note;
}

/// Intent for stepping the app-wide view zoom up (`Ctrl+=`/`Ctrl++`).
class ZoomInIntent extends Intent {
  const ZoomInIntent();
}

/// Intent for stepping the app-wide view zoom down (`Ctrl+-`).
class ZoomOutIntent extends Intent {
  const ZoomOutIntent();
}

/// Intent for resetting the view zoom to 100% (`Ctrl+0`).
class ZoomResetIntent extends Intent {
  const ZoomResetIntent();
}

/// Intent for cycling Normal → Markdown → Preview (`Ctrl+Shift+M`).
class CycleEditorModeIntent extends Intent {
  const CycleEditorModeIntent();
}

/// Intent to select the next ([forward]) or previous note in list order
/// (`Ctrl+Tab` / `Ctrl+Shift+Tab`).
class CycleNoteIntent extends Intent {
  const CycleNoteIntent({required this.forward});

  final bool forward;
}

/// Intent for focus mode — hide sidebar + list so the editor fills the
/// window (`F10`, spec story 15).
class ToggleFocusModeIntent extends Intent {
  const ToggleFocusModeIntent();
}

/// Intent for OS fullscreen (`F11`, spec story 15).
class ToggleFullscreenIntent extends Intent {
  const ToggleFullscreenIntent();
}

Map<Type, Action<Intent>> sheafActions({
  required Future<Note?> Function() onCreateNote,
  required VoidCallback onToggleSidebar,
  required VoidCallback onCycleTheme,
  required VoidCallback onDeleteSelectedNote,
  required VoidCallback onZoomIn,
  required VoidCallback onZoomOut,
  required VoidCallback onZoomReset,
  required VoidCallback onCycleEditorMode,
  required ValueChanged<bool> onCycleNote,
  required VoidCallback onToggleFocusMode,
  required VoidCallback onToggleFullscreen,
}) {
  return {
    CreateNoteIntent: CallbackAction<CreateNoteIntent>(onInvoke: (intent) => onCreateNote()),
    ToggleSidebarIntent: CallbackAction<ToggleSidebarIntent>(
      onInvoke: (intent) => onToggleSidebar(),
    ),
    CycleThemeIntent: CallbackAction<CycleThemeIntent>(onInvoke: (intent) => onCycleTheme()),
    DeleteNoteIntent: CallbackAction<DeleteNoteIntent>(
      onInvoke: (intent) => onDeleteSelectedNote(),
    ),
    ZoomInIntent: CallbackAction<ZoomInIntent>(onInvoke: (intent) => onZoomIn()),
    ZoomOutIntent: CallbackAction<ZoomOutIntent>(onInvoke: (intent) => onZoomOut()),
    ZoomResetIntent: CallbackAction<ZoomResetIntent>(onInvoke: (intent) => onZoomReset()),
    CycleEditorModeIntent: CallbackAction<CycleEditorModeIntent>(
      onInvoke: (intent) => onCycleEditorMode(),
    ),
    CycleNoteIntent: CallbackAction<CycleNoteIntent>(
      onInvoke: (intent) => onCycleNote(intent.forward),
    ),
    ToggleFocusModeIntent: CallbackAction<ToggleFocusModeIntent>(
      onInvoke: (intent) => onToggleFocusMode(),
    ),
    ToggleFullscreenIntent: CallbackAction<ToggleFullscreenIntent>(
      onInvoke: (intent) => onToggleFullscreen(),
    ),
  };
}

Map<ShortcutActivator, Intent> sheafShortcuts() => {
  const SingleActivator(LogicalKeyboardKey.keyN, control: true): const CreateNoteIntent(),
  const SingleActivator(LogicalKeyboardKey.backslash, control: true): const ToggleSidebarIntent(),
  const SingleActivator(LogicalKeyboardKey.keyL, control: true, shift: true):
      const CycleThemeIntent(),
  // Del deletes the SELECTED NOTE — but never while an editor holds focus;
  // the action guards on focus context so Del keeps its text-editing meaning
  // inside fields (feedback F7).
  const SingleActivator(LogicalKeyboardKey.delete): const DeleteNoteIntent(),
  // Ctrl+= and Ctrl++ (shifted plus) and numpad add all zoom in.
  const SingleActivator(LogicalKeyboardKey.equal, control: true): const ZoomInIntent(),
  const SingleActivator(LogicalKeyboardKey.equal, control: true, shift: true): const ZoomInIntent(),
  const SingleActivator(LogicalKeyboardKey.add, control: true): const ZoomInIntent(),
  const SingleActivator(LogicalKeyboardKey.minus, control: true): const ZoomOutIntent(),
  const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true): const ZoomOutIntent(),
  const SingleActivator(LogicalKeyboardKey.digit0, control: true): const ZoomResetIntent(),
  const SingleActivator(LogicalKeyboardKey.keyM, control: true, shift: true):
      const CycleEditorModeIntent(),
  const SingleActivator(LogicalKeyboardKey.tab, control: true): const CycleNoteIntent(
    forward: true,
  ),
  const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true): const CycleNoteIntent(
    forward: false,
  ),
  const SingleActivator(LogicalKeyboardKey.f10): const ToggleFocusModeIntent(),
  const SingleActivator(LogicalKeyboardKey.f11): const ToggleFullscreenIntent(),
};
