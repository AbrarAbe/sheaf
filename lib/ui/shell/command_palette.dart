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
  final _query = TextEditingController();
  final _rowKeys = <String, GlobalKey>{};
  int _index = 0;

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
        setState(() => _index = (_index + 1) % results.length);
        _reveal(results[_index].path);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        setState(() => _index = (_index - 1 + results.length) % results.length);
        _reveal(results[_index].path);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        _open(results[_index.clamp(0, results.length - 1)]);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _reveal(String path) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyContext = _rowKeys[path]?.currentContext;
      if (keyContext != null) Scrollable.ensureVisible(keyContext);
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
      elevation: 0,
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 96, left: 24, right: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Material(
          color: theme.colorScheme.surfaceContainerHigh,
          clipBehavior: Clip.antiAlias,
          elevation: 6,
          shadowColor: theme.shadowColor.withValues(alpha: .4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: .7)),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
                  ),
                  onChanged: (_) => setState(() => _index = 0),
                ),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: .6)),
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
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 480),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final note = results[i];
                      final selected = i == clampedIndex;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 2),
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
            ],
          ),
        ),
      ),
    );
  }
}
