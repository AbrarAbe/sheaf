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

  // Selection sits (even partially) inside an existing span → unwrap it.
  final enclosing = _enclosingSpan(text, start, stop, open, end);
  if (enclosing != null) return enclosing;

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

  // Caret rests inside an existing span → unwrap that span.
  final enclosing = _enclosingSpan(text, caret, caret, open, end);
  if (enclosing != null) return enclosing;

  final inserted = '$before$open$end$after';
  return FormatEdit(inserted, caret + open.length, caret + open.length);
}

/// Unwraps the `<open>…<end>` span best matching the given range, remapping
/// the selection into unwrapped coordinates. Null when no span qualifies.
///
/// A span qualifies when the range overlaps or even just touches its inner
/// region (`start <= innerEnd && stop >= innerStart`) — which subsumes
/// selections covering the whole span, so marker-inclusive toggles unwrap
/// instead of silently nesting a second layer (feedback F11/F20). The
/// smallest qualifying inner wins; zero-length inners are skipped so
/// adjacent bold markers never masquerade as an empty italic pair.
FormatEdit? _enclosingSpan(String text, int start, int stop, String open, String end) {
  final pattern = RegExp('${RegExp.escape(open)}(.*?)${RegExp.escape(end)}');
  Match? best;
  for (final m in pattern.allMatches(text)) {
    final inner = m.group(1)!;
    if (inner.isEmpty) continue;
    final innerStart = m.start + open.length;
    final innerEnd = innerStart + inner.length;
    final qualifies = start <= innerEnd && stop >= innerStart;
    if (qualifies && (best == null || inner.length < best.group(1)!.length)) {
      best = m;
    }
  }
  if (best == null) return null;

  final spanStart = best.start;
  final innerStart = spanStart + open.length;
  final innerEnd = innerStart + best.group(1)!.length;
  final spanEnd = best.end;

  final unwrapped = text
      .replaceRange(spanEnd - end.length, spanEnd, '')
      .replaceRange(spanStart, innerStart, '');

  // Piecewise remap across the two marker removals.
  int map(int o) {
    if (o <= spanStart) return o;
    if (o < innerStart) return spanStart; // inside the open marker
    if (o <= innerEnd) return o - open.length; // inner text
    if (o < spanEnd) return innerEnd - open.length; // inside the close marker
    return o - open.length - end.length; // past the span
  }

  return FormatEdit(
    unwrapped,
    map(start).clamp(0, unwrapped.length),
    map(stop).clamp(0, unwrapped.length),
  );
}

/// VS Code-style select-word bounds around [offset] (spec story 11, F6).
///
/// A word glyph under (or just behind) the caret selects that word — so
/// pressing Ctrl+D right after typing selects what you typed. Otherwise the
/// maximal whitespace/punctuation run under the caret is selected.
(int, int) wordBoundary(String text, int offset) {
  if (text.isEmpty) return (0, 0);
  var at = offset.clamp(0, text.length);

  bool isWord(int i) => i >= 0 && i < text.length && RegExp(r'\w').hasMatch(text[i]);
  int classOf(int i) {
    if (isWord(i)) return 0;
    return text[i].trim().isEmpty ? 1 : 2;
  }

  // Caret past the last glyph sits on it; caret on a non-word right after a
  // word belongs to that word (freshly-typed-word case).
  if (at == text.length || (!isWord(at) && isWord(at - 1))) at -= 1;

  final klass = classOf(at);
  var start = at;
  var end = at + 1;
  while (start > 0 && classOf(start - 1) == klass) {
    start--;
  }
  while (end < text.length && classOf(end) == klass) {
    end++;
  }
  return (start, end);
}
