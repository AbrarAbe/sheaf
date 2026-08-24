/// Markdown formatting toggles for the editor (spec story 10).
///
/// Pure string/offset math — no Flutter imports — so wrap/unwrap rules are
/// unit-testable headlessly. The editor layer maps these onto a live
/// `TextEditingController`.
library;

/// Result of a toggle: the new text plus where the selection should land.
class FormatEdit {
  const FormatEdit(this.text, this.selStart, this.selEnd);

  final String text;
  final int selStart;
  final int selEnd;
}

/// The three formatting toggles bound to Ctrl+B / Ctrl+I / Ctrl+U.
enum FormatKind {
  bold,
  italic,
  underline;

  String get open => switch (this) {
    FormatKind.bold => '**',
    FormatKind.italic => '*',
    FormatKind.underline => '<u>',
  };

  String get close => switch (this) {
    FormatKind.bold => '**',
    FormatKind.italic => '*',
    FormatKind.underline => '</u>',
  };
}

/// Toggles [open]…[close] (default [close] = [open]) around the selection.
///
/// - Non-empty selection already wrapped exactly → unwrap it.
/// - Non-empty plain selection → wrap it; selection covers the inner text.
/// - Collapsed caret between adjacent markers → remove them.
/// - Collapsed caret elsewhere → insert an empty pair; caret lands inside.
FormatEdit toggleWrap({
  required String text,
  required int selStart,
  required int selEnd,
  required String open,
  String? close,
}) {
  final end = close ?? open;
  final start = selStart.clamp(0, text.length);
  final stop = selEnd.clamp(start, text.length);

  if (stop > start) {
    return _toggleAroundSelection(text, start, stop, open, end);
  }
  return _toggleAtCaret(text, start, open, end);
}

FormatEdit _toggleAroundSelection(String text, int start, int stop, String open, String end) {
  final selected = text.substring(start, stop);
  if (selected.startsWith(open) &&
      selected.endsWith(end) &&
      selected.length >= open.length + end.length) {
    final innerLength = selected.length - open.length - end.length;
    final unwrapped = text.replaceRange(
      start,
      stop,
      selected.substring(open.length, selected.length - end.length),
    );
    return FormatEdit(unwrapped, start, start + innerLength);
  }

  final wrapped = '${text.substring(0, start)}$open$selected$end${text.substring(stop)}';
  return FormatEdit(wrapped, start + open.length, stop + open.length);
}

FormatEdit _toggleAtCaret(String text, int caret, String open, String end) {
  final before = text.substring(0, caret);
  final after = text.substring(caret);
  if (before.endsWith(open) && after.startsWith(end)) {
    // Empty pair around the caret: remove both markers.
    final removed = before.substring(0, before.length - open.length) + after.substring(end.length);
    final at = caret - open.length;
    return FormatEdit(removed, at, at);
  }

  final inserted = '$before$open$end$after';
  return FormatEdit(inserted, caret + open.length, caret + open.length);
}
