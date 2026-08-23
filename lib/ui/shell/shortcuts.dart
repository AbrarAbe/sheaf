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

Map<Type, Action<Intent>> sheafActions({
  required Future<Note?> Function() onCreateNote,
  required VoidCallback onToggleSidebar,
  required VoidCallback onCycleTheme,
  required VoidCallback onDeleteSelectedNote,
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
  };
}

Map<ShortcutActivator, Intent> sheafShortcuts() => {
  const SingleActivator(LogicalKeyboardKey.keyN, control: true): const CreateNoteIntent(),
  const SingleActivator(LogicalKeyboardKey.backslash, control: true): const ToggleSidebarIntent(),
  const SingleActivator(LogicalKeyboardKey.keyL, control: true, shift: true):
      const CycleThemeIntent(),
  const SingleActivator(LogicalKeyboardKey.delete): const DeleteNoteIntent(),
};
