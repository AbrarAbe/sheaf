import 'package:flutter/material.dart';

import '../../models/settings.dart';
import '../../models/shortcut_settings.dart';
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

/// Intent for the quick-switcher overlay (`Ctrl+K`, feedback F12).
class OpenPaletteIntent extends Intent {
  const OpenPaletteIntent();
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
  required VoidCallback onOpenPalette,
}) {
  return {
    CreateNoteIntent: CallbackAction<CreateNoteIntent>(
      onInvoke: (intent) => onCreateNote(),
    ),
    ToggleSidebarIntent: CallbackAction<ToggleSidebarIntent>(
      onInvoke: (intent) => onToggleSidebar(),
    ),
    CycleThemeIntent: CallbackAction<CycleThemeIntent>(
      onInvoke: (intent) => onCycleTheme(),
    ),
    DeleteNoteIntent: CallbackAction<DeleteNoteIntent>(
      onInvoke: (intent) => onDeleteSelectedNote(),
    ),
    ZoomInIntent: CallbackAction<ZoomInIntent>(
      onInvoke: (intent) => onZoomIn(),
    ),
    ZoomOutIntent: CallbackAction<ZoomOutIntent>(
      onInvoke: (intent) => onZoomOut(),
    ),
    ZoomResetIntent: CallbackAction<ZoomResetIntent>(
      onInvoke: (intent) => onZoomReset(),
    ),
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
    OpenPaletteIntent: CallbackAction<OpenPaletteIntent>(
      onInvoke: (intent) => onOpenPalette(),
    ),
  };
}

Map<ShortcutActivator, Intent> sheafShortcuts([
  AppSettings settings = const AppSettings(),
]) {
  SingleActivator a(ShortcutAction action) =>
      activatorFor(action, settings.shortcutOverrides);
  return {
    a(ShortcutAction.createNote): const CreateNoteIntent(),
    a(ShortcutAction.toggleSidebar): const ToggleSidebarIntent(),
    a(ShortcutAction.cycleTheme): const CycleThemeIntent(),
    a(ShortcutAction.deleteNote): const DeleteNoteIntent(),
    a(ShortcutAction.zoomIn): const ZoomInIntent(),
    a(ShortcutAction.zoomOut): const ZoomOutIntent(),
    a(ShortcutAction.zoomReset): const ZoomResetIntent(),
    a(ShortcutAction.cycleEditorMode): const CycleEditorModeIntent(),
    a(ShortcutAction.cycleNoteNext): const CycleNoteIntent(forward: true),
    a(ShortcutAction.cycleNotePrev): const CycleNoteIntent(forward: false),
    a(ShortcutAction.toggleFocusMode): const ToggleFocusModeIntent(),
    a(ShortcutAction.toggleFullscreen): const ToggleFullscreenIntent(),
    a(ShortcutAction.openPalette): const OpenPaletteIntent(),
  };
}
