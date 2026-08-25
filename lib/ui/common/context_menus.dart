import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart' hide MenuItem;
import 'package:google_fonts/google_fonts.dart';

export 'package:flutter_context_menu/flutter_context_menu.dart'
    show ContextMenu, ContextMenuEntry, ContextMenuItem, ContextMenuState, MenuHeader, MenuDivider;

// ---- Shortcut activators reused by menus and the key map ----
const deleteActivator = SingleActivator(LogicalKeyboardKey.delete);
const renameActivator = SingleActivator(LogicalKeyboardKey.f2);
const newNoteActivator = SingleActivator(LogicalKeyboardKey.keyN, control: true);

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

/// Base styling applied to every Sheaf context menu (feedback F18).
///
/// Structural knobs only — surface color/shadow stay with the package's
/// themed container since we build menus without a BuildContext here.
ContextMenu<Object?> quireMenu(List<ContextMenuEntry<Object?>> entries) {
  return ContextMenu<Object?>(
    entries: entries,
    maxWidth: 240,
    padding: const EdgeInsets.all(5),
    borderRadius: BorderRadius.circular(10),
  );
}

/// Hairline separator instead of the package's invisible zero-thickness one.
const MenuDivider menuDivider = MenuDivider(height: 9, thickness: 1, indent: 10, endIndent: 10);

/// Builds a Sheaf-styled entry. Signature mirrors the old MenuItem helper so
/// call sites don't change.
ContextMenuEntry<Object?> menuItem(
  String label, {
  required Object value,
  IconData? icon,
  bool destructive = false,
  SingleActivator? shortcut,
}) {
  return QuireMenuItem(
    label: label,
    value: value,
    icon: icon,
    destructive: destructive,
    shortcut: shortcut,
  );
}

/// A context-menu row that actually follows the Quire language.
///
/// The stock `MenuItem` reserves 32px icon AND trailing gutters on every row
/// and renders labels at 70% alpha — bloated and washed out. This subclass
/// renders compact 30px rows with aligned leading slots, full-contrast Hanken
/// labels, mono shortcut hints and a destructive tint, while reusing the
/// package's selection/focus/submenu machinery untouched.
final class QuireMenuItem extends ContextMenuItem<Object?> {
  const QuireMenuItem({
    required this._label,
    super.value,
    this._icon,
    this._destructive = false,
    this._shortcut,
    super.enabled,
  });

  final String _label;
  final IconData? _icon;
  final bool _destructive;
  final SingleActivator? _shortcut;

  @override
  String get debugLabel => 'QuireMenuItem($_label)';

  String _keyName(LogicalKeyboardKey key) => switch (key) {
    LogicalKeyboardKey.delete => 'Del',
    LogicalKeyboardKey.escape => 'Esc',
    LogicalKeyboardKey.arrowUp => '\u2191',
    LogicalKeyboardKey.arrowDown => '\u2193',
    LogicalKeyboardKey.backslash => '\\',
    _ => key.keyLabel,
  };

  String get _shortcutLabel {
    final s = _shortcut!;
    final mods = [
      if (s.control) 'Ctrl',
      if (s.meta) 'Meta',
      if (s.alt) 'Alt',
      if (s.shift) 'Shift',
    ];
    return [...mods, _keyName(s.trigger)].join('+');
  }

  @override
  Widget builder(
    BuildContext context,
    ContextMenuState<Object?> menuState, [
    FocusNode? focusNode,
  ]) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final focused = menuState.focusedEntry == this;
    final foreground = !enabled
        ? cs.onSurface.withValues(alpha: .35)
        : _destructive
        ? cs.error
        : cs.onSurface;

    return Material(
      color: enabled && focused ? cs.surfaceContainerHighest : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: enabled ? () => handleItemSelection(context, menuState) : null,
        child: SizedBox(
          height: 30,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                // Aligned leading slot keeps labels flush even icon-less.
                SizedBox.square(
                  dimension: 20,
                  child: _icon == null
                      ? null
                      : IconTheme(
                          data: IconThemeData(size: 15, color: foreground),
                          child: Icon(_icon),
                        ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                ),
                if (_shortcut != null)
                  Text(
                    _shortcutLabel,
                    style: GoogleFonts.splineSansMono(
                      fontSize: 11,
                      letterSpacing: 0.3,
                      color: foreground.withValues(alpha: enabled ? .62 : .3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
