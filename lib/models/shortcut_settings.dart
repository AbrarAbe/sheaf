import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../logic/shortcut_serializer.dart';

/// Actions that can be rebound via Settings → Keyboard Shortcuts.
///
/// Formatting (Ctrl+B/I/U) is intentionally excluded — see plan.
enum ShortcutAction {
  createNote,
  toggleSidebar,
  cycleTheme,
  deleteNote,
  zoomIn,
  zoomOut,
  zoomReset,
  cycleEditorMode,
  cycleNoteNext,
  cycleNotePrev,
  toggleFocusMode,
  toggleFullscreen,
  openPalette,
  openFind,
  selectWord,
  copySelection,
  pasteSelection,
  continueList,
  findNext,
  findPrev,
  closeFind;

  String get label => switch (this) {
    createNote => 'Create note',
    toggleSidebar => 'Toggle sidebar',
    cycleTheme => 'Cycle theme',
    deleteNote => 'Delete note',
    zoomIn => 'Zoom in',
    zoomOut => 'Zoom out',
    zoomReset => 'Reset zoom',
    cycleEditorMode => 'Cycle editor mode',
    cycleNoteNext => 'Next note',
    cycleNotePrev => 'Previous note',
    toggleFocusMode => 'Toggle focus mode',
    toggleFullscreen => 'Toggle fullscreen',
    openPalette => 'Open palette',
    openFind => 'Find in note',
    selectWord => 'Select word',
    copySelection => 'Copy',
    pasteSelection => 'Paste',
    continueList => 'Continue list',
    findNext => 'Find next',
    findPrev => 'Find previous',
    closeFind => 'Close find',
  };

  SingleActivator get defaultActivator => switch (this) {
    createNote => const SingleActivator(LogicalKeyboardKey.keyN, control: true),
    toggleSidebar => const SingleActivator(
      LogicalKeyboardKey.backslash,
      control: true,
    ),
    cycleTheme => const SingleActivator(
      LogicalKeyboardKey.keyL,
      control: true,
      shift: true,
    ),
    deleteNote => const SingleActivator(LogicalKeyboardKey.delete),
    zoomIn => const SingleActivator(LogicalKeyboardKey.equal, control: true),
    zoomOut => const SingleActivator(LogicalKeyboardKey.minus, control: true),
    zoomReset => const SingleActivator(
      LogicalKeyboardKey.digit0,
      control: true,
    ),
    cycleEditorMode => const SingleActivator(
      LogicalKeyboardKey.keyM,
      control: true,
      shift: true,
    ),
    cycleNoteNext => const SingleActivator(
      LogicalKeyboardKey.tab,
      control: true,
    ),
    cycleNotePrev => const SingleActivator(
      LogicalKeyboardKey.tab,
      control: true,
      shift: true,
    ),
    toggleFocusMode => const SingleActivator(LogicalKeyboardKey.f10),
    toggleFullscreen => const SingleActivator(LogicalKeyboardKey.f11),
    openPalette => const SingleActivator(
      LogicalKeyboardKey.keyK,
      control: true,
    ),
    openFind => const SingleActivator(LogicalKeyboardKey.keyF, control: true),
    selectWord => const SingleActivator(LogicalKeyboardKey.keyD, control: true),
    copySelection => const SingleActivator(
      LogicalKeyboardKey.keyC,
      control: true,
      shift: true,
    ),
    pasteSelection => const SingleActivator(
      LogicalKeyboardKey.keyV,
      control: true,
      shift: true,
    ),
    continueList => const SingleActivator(LogicalKeyboardKey.enter),
    findNext => const SingleActivator(LogicalKeyboardKey.enter),
    findPrev => const SingleActivator(LogicalKeyboardKey.enter, shift: true),
    closeFind => const SingleActivator(LogicalKeyboardKey.escape),
  };

  String get defaultActivatorLabel => serializeActivator(defaultActivator);
}

/// Returns the effective activator for [action] given current overrides.
SingleActivator activatorFor(
  ShortcutAction action,
  Map<String, String> overrides,
) {
  final raw = overrides[action.name];
  if (raw != null) {
    final parsed = tryParseActivator(raw);
    if (parsed != null) return parsed;
  }
  return action.defaultActivator;
}

/// Keys that are reserved for formatting and must not be rebound.
const reservedFormattingLabels = {'Ctrl+B', 'Ctrl+I', 'Ctrl+U'};
