import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';

export 'package:flutter_context_menu/flutter_context_menu.dart'
    show ContextMenu, ContextMenuEntry, MenuItem, MenuDivider;

/// Wraps [child] so secondary-click opens [menu].
class QuireContextMenuRegion extends StatelessWidget {
  const QuireContextMenuRegion({
    super.key,
    required this.menu,
    required this.onItemSelected,
    required this.child,
  });

  final ContextMenu<Object?> menu;
  final ValueChanged<Object?> onItemSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ContextMenuRegion<Object?>(
      contextMenu: menu,
      onItemSelected: onItemSelected,
      child: child,
    );
  }
}

/// Base styling applied to every Taker context menu.
ContextMenu<Object?> quireMenu(List<ContextMenuEntry<Object?>> entries) {
  return ContextMenu<Object?>(entries: entries, maxWidth: 220, padding: EdgeInsets.zero);
}

ContextMenuEntry<Object?> menuItem(
  String label, {
  required Object value,
  IconData? icon,
  bool destructive = false,
  SingleActivator? shortcut,
}) {
  return MenuItem<Object?>(
    label: Text(label),
    value: value,
    icon: icon == null ? null : Icon(icon),
    shortcut: shortcut,
  );
}

const MenuDivider menuDivider = MenuDivider();

// ---- Shortcut activators reused by menus and the key map ----
const deleteActivator = SingleActivator(LogicalKeyboardKey.delete);
const renameActivator = SingleActivator(LogicalKeyboardKey.f2);
const newNoteActivator = SingleActivator(LogicalKeyboardKey.keyN, control: true);
