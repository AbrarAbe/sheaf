import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart' show ContextMenu, showContextMenu;

import '../common/context_menus.dart';

/// Opens the Quire-styled Cut/Copy/Paste/Select-all menu for an editable body
/// field (round 6 F21).
///
/// Bridges Flutter's `TextField.contextMenuBuilder` — which wants an inline
/// toolbar widget — to flutter_context_menu, which renders its own overlay.
/// The builder defers into this call and returns a zero-size widget, so the
/// stock Material toolbar never paints. All actions go through the field's
/// own [EditableTextState] methods, keeping autosave/highlighting intact.
Future<void> showBodyEditMenu(BuildContext context, EditableTextState state) async {
  final menu = _buildEditMenu(state)..position = _anchorFor(state);
  await showContextMenu<Object?>(
    context,
    contextMenu: menu,
    onItemSelected: (value) => _apply(value, state),
  );
}

ContextMenu<Object?> _buildEditMenu(EditableTextState state) {
  final hasSelection =
      !state.textEditingValue.selection.isCollapsed && state.textEditingValue.selection.isValid;
  return quireMenu([
    if (hasSelection)
      menuItem(
        'Cut',
        value: 'cut',
        icon: Icons.content_cut_outlined,
        shortcut: const SingleActivator(LogicalKeyboardKey.keyX, control: true),
      ),
    if (hasSelection)
      menuItem(
        'Copy',
        value: 'copy',
        icon: Icons.copy_outlined,
        shortcut: const SingleActivator(LogicalKeyboardKey.keyC, control: true),
      ),
    menuItem(
      'Paste',
      value: 'paste',
      icon: Icons.content_paste_outlined,
      shortcut: const SingleActivator(LogicalKeyboardKey.keyV, control: true),
    ),
    menuDivider,
    menuItem(
      'Select all',
      value: 'select-all',
      icon: Icons.select_all_outlined,
      shortcut: const SingleActivator(LogicalKeyboardKey.keyA, control: true),
    ),
  ]);
}

Future<void> _apply(Object? value, EditableTextState state) async {
  const cause = SelectionChangedCause.toolbar;
  switch (value) {
    case 'cut':
      state.cutSelection(cause);
    case 'copy':
      state.copySelection(cause);
    case 'paste':
      await state.pasteText(cause);
    case 'select-all':
      state.selectAll(cause);
  }
}

/// Global offset just under the selection's leading edge (caret when
/// collapsed).
Offset _anchorFor(EditableTextState state) {
  final renderEditable = state.renderEditable;
  final selection = state.textEditingValue.selection;
  var extent = selection.extent.offset;
  if (!selection.isValid || extent < 0 || extent > state.textEditingValue.text.length) {
    extent = state.textEditingValue.text.length;
  }

  Rect rect;
  final range = !selection.isCollapsed && selection.isValid
      ? TextRange(start: selection.start, end: selection.end)
      : null;
  try {
    rect =
        range?.let(renderEditable.getRectForComposingRange) ??
        renderEditable.getLocalRectForCaret(TextPosition(offset: extent));
  } on Exception {
    rect = renderEditable.getLocalRectForCaret(const TextPosition(offset: 0));
  }
  return renderEditable.localToGlobal(rect.bottomLeft + const Offset(0, 6));
}

extension on TextRange {
  Rect? let(Rect? Function(TextRange) f) => f(this);
}
