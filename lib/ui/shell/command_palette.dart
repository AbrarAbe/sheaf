import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../logic/search_controller.dart';
import '../../logic/vault_controller.dart';
import '../../models/note.dart';
import 'widgets/palette_row.dart';

/// Opens the quick-switcher over the current context (feedback F12).
///
/// Empty query lists every vault note newest-first, so row one is always the
/// last-edited note; typing narrows via [searchAndSort] ranking.
Future<void> showCommandPalette(BuildContext context, VaultController controller) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (_) => CommandPalette(controller: controller),
  );
}

/// ⌘K quick-switcher: one field, ranked note rows, keyboard-first.
class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key, required this.controller});

  final VaultController controller;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  static const _pageSize = 15;
  final _scroll = ScrollController();
  // Uniform row budget: PaletteRow (~34px incl. padding) + outer bottom
  // pad (2px) + rounding margin → ListView itemExtent. Container height for
  // exactly 12 rows = 12 * extent + list vertical padding (12px).
  static const _rowExtent = 38.0;
  final _query = TextEditingController();
  final _rowKeys = <String, GlobalKey>{};
  int _index = 0;

  @override
  void dispose() {
    _scroll.dispose();
    _query.dispose();
    super.dispose();
  }

  /// Whole-vault scope: the palette ignores sidebar folder/tag filters so a
  /// jump is always possible from any scoping state.
  List<Note> get _results =>
      searchAndSort(widget.controller.notes.toList(growable: false), _query.text);

  void _open(Note note) {
    Navigator.of(context).pop();
    widget.controller.selectNote(note);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final results = _results;
    if (results.isEmpty) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(() {
          // Clamp at the end — no wrap-around.
          _index = (_index + 1).clamp(0, results.length - 1);
        });
        // Pin to bottom edge (1.0) so visible rows don't scroll; only
        // beyond-viewport rows pull the list, highlight staying at bottom.
        _reveal(results[_index].path, alignment: 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        setState(() {
          // Clamp at the start — no wrap-around.
          _index = (_index - 1).clamp(0, results.length - 1);
        });
        // Pin to top edge (0.0) — symmetric to arrow-down.
        _reveal(results[_index].path, alignment: 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        _open(results[_index.clamp(0, results.length - 1)]);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _reveal(String path, {double alignment = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final keyContext = _rowKeys[path]?.currentContext;
      if (keyContext == null) return;
      final rowBox = keyContext.findRenderObject() as RenderBox?;
      final scrollBox = _scroll.position.context.storageContext.findRenderObject() as RenderBox?;
      if (rowBox == null || scrollBox == null || !rowBox.attached) return;
      // Caret-like: only scroll when the selected row has reached (or
      // passed) the top/bottom edge of the viewport. Fully-visible rows
      // never move the list.
      final rowTop = rowBox.localToGlobal(Offset.zero, ancestor: scrollBox).dy;
      final rowBottom = rowTop + rowBox.size.height;
      final viewTop = scrollBox.paintBounds.top;
      final viewBottom = scrollBox.paintBounds.bottom;
      const epsilon = 0.5;
      final fullyVisible = rowTop >= viewTop - epsilon && rowBottom <= viewBottom + epsilon;
      if (fullyVisible) return;
      Scrollable.ensureVisible(
        keyContext,
        alignment: alignment,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        duration: Duration.zero,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _results;
    final clampedIndex = results.isEmpty ? 0 : _index.clamp(0, results.length - 1);

    return Dialog(
      key: const Key('palette-dialog'),
      backgroundColor: Colors.transparent,
      elevation: 2,
      alignment: Alignment.topCenter,
      insetPadding: EdgeInsets.only(top: 5, left: 24, right: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Material(
          color: theme.colorScheme.surfaceContainerHigh,
          clipBehavior: Clip.antiAlias,
          elevation: 6,
          shadowColor: theme.shadowColor.withValues(alpha: .4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: .5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Query field. The Focus wrapper sees arrows/Enter before the
              // text field can turn them into caret moves.
              Focus(
                onKeyEvent: _onKey,
                child: TextField(
                  key: const Key('palette-field'),
                  controller: _query,
                  autofocus: true,
                  style: GoogleFonts.hankenGrotesk(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search notes…',
                    hintStyle: GoogleFonts.hankenGrotesk(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        width: 2,
                        color: theme.colorScheme.outline.withValues(alpha: .2),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  ),
                  onChanged: (_) {
                    setState(() => _index = 0);
                  },
                ),
              ),
              if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No matching notes.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Builder(
                  builder: (context) {
                    final shown = results.length;
                    // Dynamically match content height up to exactly 12 rows;
                    // beyond that the list scrolls inside the fixed window.
                    final fifteenRowHeight = _pageSize * _rowExtent;
                    final maxH = MediaQuery.of(context).size.height * 0.7;
                    final contentH = shown * _rowExtent;
                    final listH = contentH.clamp(0.0, fifteenRowHeight).clamp(0.0, maxH);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: SizedBox(
                        height: listH,
                        child: ListView.builder(
                          controller: _scroll,
                          // padding: const EdgeInsets.symmetric(vertical: 6),
                          itemExtent: _rowExtent,
                          itemCount: shown,
                          itemBuilder: (context, i) {
                            final note = results[i];
                            final selected = i == clampedIndex;
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
                              child: PaletteRow(
                                key: _rowKeys.putIfAbsent(note.path, GlobalKey.new),
                                note: note,
                                selected: selected,
                                onTap: () => _open(note),
                                onHover: () => setState(() => _index = i),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
