/// Markdown formatting toggles for the editor (spec story 10).
///
/// Pure string/offset math — no Flutter imports — so wrap/unwrap rules are
/// unit-testable headlessly. The editor layer maps these onto a live
/// `TextEditingController`.
library;

/// Result of a toggle: the new text plus where the selection should land.
class FormatEdit {
  const FormatEdit(this.text, this.selStart, this.selEnd, this.caret);

  final String text;
  final int selStart;
  final int selEnd;

  /// Restored caret position for a *collapsed* (bare-caret) toggle: the original
  /// caret, mapped into the new text so it sits on the same character it
  /// started on. A selection keeps `selStart`/`selEnd` instead (feedback F28).
  final int caret;
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
// Unicode word char — letters/digits from any script + underscore.
// Dart RegExp \p{L}/\p{N} requires unicode:true.
final RegExp _wordChar = RegExp(r'[\p{L}\p{N}_]', unicode: true);

FormatEdit toggleWrap({
  required String text,
  required int selStart,
  required int selEnd,
  required String open,
  String? close,
}) {
  final end = close ?? open;
  final a = selStart.clamp(0, text.length);
  final b = selEnd.clamp(0, text.length);
  final start = a <= b ? a : b;
  final stop = a <= b ? b : a;

  if (stop > start) {
    return _toggleAroundSelection(
      text,
      start,
      stop,
      open,
      end,
      wasCollapsed: false,
      origCaret: start,
    );
  }
  // Collapsed caret: if it rests on a word, format that whole word (F10)
  // instead of splicing an empty pair into it; the original caret offset is
  // remembered so the parked caret lands on the same character afterwards.
  final origCaret = start;
  final (wordStart, wordEnd) = wordBoundary(text, start);
  if (wordEnd > wordStart && _wordChar.hasMatch(text[wordStart])) {
    return _toggleAroundSelection(
      text,
      wordStart,
      wordEnd,
      open,
      end,
      wasCollapsed: true,
      origCaret: origCaret,
    );
  }
  return _toggleAtCaret(text, start, open, end);
}

FormatEdit _toggleAroundSelection(
  String text,
  int start,
  int stop,
  String open,
  String end, {
  required bool wasCollapsed,
  required int origCaret,
}) {
  final selected = text.substring(start, stop);
  if (selected.startsWith(open) &&
      selected.endsWith(end) &&
      selected.length >= open.length + end.length) {
    final inner = selected.substring(open.length, selected.length - end.length);
    if (inner.trim().isEmpty) {
      // Don't unwrap whitespace-only inner — treat as plain wrap attempt
      // to avoid "****" -> "" collapse.
    } else {
      final unwrapped = text.replaceRange(start, stop, inner);
      return FormatEdit(
        unwrapped,
        start,
        start + inner.length,
        start + inner.length,
      );
    }
  }

  // Selection sits (even partially) inside an existing span → unwrap it.
  final enclosing = _enclosingSpan(
    text,
    start,
    stop,
    open,
    end,
    origCaret: wasCollapsed ? origCaret : null,
  );
  if (enclosing != null) return enclosing;

  // For combinable styles: bold/italic (*, **) should wrap *outside* existing
  // underline <u> so that **<u>word</u>** is canonical (bold outer). Detect if
  // selection is strictly inside an underline span and expand to its bounds.
  var wrapStart = start;
  var wrapStop = stop;
  var wrapSelected = selected;
  if ((open == '*' && end == '*') || (open == '**' && end == '**')) {
    final underlineSpan = _findEnclosingUnderline(text, start, stop);
    if (underlineSpan != null) {
      wrapStart = underlineSpan.start;
      wrapStop = underlineSpan.end;
      wrapSelected = text.substring(wrapStart, wrapStop);
    }
  }

  final wrapped =
      '${text.substring(0, wrapStart)}$open$wrapSelected$end${text.substring(wrapStop)}';
  // A collapsed caret parks back on its original character (origCaret shifts
  // with the open marker); a real selection keeps the inner text highlighted
  // so a second press toggles the formatting back off (feedback F28).
  final caret = wasCollapsed
      ? origCaret + open.length + (wrapStart - start)
      : wrapStop + open.length + end.length;
  return FormatEdit(
    wrapped,
    wrapStart + open.length,
    wrapStop + open.length,
    caret,
  );
}

FormatEdit _toggleAtCaret(String text, int caret, String open, String end) {
  final before = text.substring(0, caret);
  final after = text.substring(caret);
  if (before.endsWith(open) && after.startsWith(end)) {
    // Empty pair around the caret: remove both markers.
    final removed =
        before.substring(0, before.length - open.length) +
        after.substring(end.length);
    final at = caret - open.length;
    return FormatEdit(removed, at, at, at);
  }

  // Caret rests inside an existing span → unwrap that span.
  final enclosing = _enclosingSpan(text, caret, caret, open, end);
  if (enclosing != null) return enclosing;

  // Collapsed caret merely TOUCHING a span's markers (e.g. line-start
  // before the opener): splicing an empty pair here would nest markers and
  // render as the wrong style (`***word***` reads bold). Toggle the touched
  // span off instead (feedback F25).
  final touched = _enclosingSpan(
    text,
    caret,
    caret,
    open,
    end,
    touchingOnly: true,
  );
  if (touched != null) return touched;

  final inserted = '$before$open$end$after';
  return FormatEdit(
    inserted,
    caret + open.length,
    caret + open.length,
    caret + open.length,
  );
}

/// Finds the smallest <u>...</u> span that strictly encloses [start]/[stop]
/// (selection inside its inner text). Used to make bold/italic wrap outside
/// underline so that **<u>word</u>** is canonical regardless of order.
RegExpMatch? _findEnclosingUnderline(String text, int start, int stop) {
  final pattern = RegExp('<u>(.*?)</u>');
  RegExpMatch? best;
  for (final m in pattern.allMatches(text)) {
    final innerStart = m.start + 3; // '<u>'.length
    final innerEnd = m.end - 4; // '</u>'.length
    if (start >= innerStart && stop <= innerEnd && start < stop) {
      // Strictly inside inner, not covering markers
      if (best == null || m.group(1)!.length < best.group(1)!.length) best = m;
    } else if (start == stop && start > m.start && stop < m.end) {
      // Collapsed caret inside underline span
      if (best == null || m.group(1)!.length < best.group(1)!.length) best = m;
    }
  }
  return best;
}

/// Unwraps the `<open>…<end>` span best matching the given range, remapping
/// the selection into unwrapped coordinates. Null when no span qualifies.
///
FormatEdit? _enclosingSpan(
  String text,
  int start,
  int stop,
  String open,
  String end, {
  bool touchingOnly = false,
  int? origCaret,
}) {
  // Italic needs overlapping-aware scanning: RegExp's non-overlapping
  // allMatches would consume a '**' opener or a list marker '* ' and hide
  // the valid '*word*' span.
  if (open == '*' && end == '*') {
    int? bestStart;
    int? bestEnd;
    String? bestInner;
    for (var i = 0; i < text.length; i++) {
      if (text[i] != '*') continue;
      if (i + 1 < text.length &&
          (text[i + 1].trim().isEmpty || text[i + 1] == '*')) {
        continue;
      }
      if ((i == 0 || text[i - 1] == '\n') &&
          i + 1 < text.length &&
          text[i + 1] == ' ') {
        continue;
      }
      if (i > 0 && text[i - 1] == '*') continue;
      var j = i + 1;
      while (j < text.length && text[j] != '*') {
        if (text[j] == '\n') break;
        j++;
      }
      if (j >= text.length || text[j] != '*') continue;
      var hasNewline = false;
      for (var k = i + 1; k < j; k++) {
        if (text[k] == '\n') {
          hasNewline = true;
          break;
        }
        if (text[k] == '*') {
          hasNewline = true;
          break;
        }
      }
      if (hasNewline) continue;
      final inner = text.substring(i + 1, j);
      if (inner.isEmpty || inner.trim().isEmpty) continue;
      if (inner.contains('\n')) continue;
      // Allow "**" (bold) inside italic for combinable styles, but reject
      // lone "*" which would break the simple single-star scan.
      // Lone star = "*" not part of "**".
      if (RegExp(r'(?<!\*)\*(?!\*)').hasMatch(inner)) continue;
      final mStart = i;
      final mEnd = j + 1;
      final innerStart = i + 1;
      final innerEnd = j;
      final bool qualifies;
      if (touchingOnly) {
        // Caret strictly inside marker bounds [mStart, mEnd), not at mEnd
        // which is the gap between spans. Prevents "*a* *b*" caret at 3
        // unwrapping first span. Exception: caret at text end after closer
        // (e.g. "<u>go</u>" at 9) should still unwrap.
        final atEnd = start == text.length && start == mEnd;
        qualifies = start == stop && (start >= mStart && start < mEnd || atEnd);
      } else {
        qualifies = start <= innerEnd && stop >= innerStart;
      }
      if (qualifies && (bestInner == null || inner.length < bestInner.length)) {
        bestStart = mStart;
        bestEnd = mEnd;
        bestInner = inner;
      }
    }
    if (bestStart == null || bestEnd == null || bestInner == null) {
      return null;
    }
    final spanStart = bestStart;
    final innerStart = spanStart + open.length;
    final innerEnd = innerStart + bestInner.length;
    final spanEnd = bestEnd;
    final unwrapped = text
        .replaceRange(spanEnd - end.length, spanEnd, '')
        .replaceRange(spanStart, innerStart, '');
    int map(int o) {
      if (o <= spanStart) return o;
      if (o < innerStart) return spanStart;
      if (o <= innerEnd) return o - open.length;
      if (o < spanEnd) return innerEnd - open.length;
      return o - open.length - end.length;
    }

    final caret = map(origCaret ?? stop).clamp(0, unwrapped.length);
    return FormatEdit(
      unwrapped,
      map(start).clamp(0, unwrapped.length),
      caret,
      caret,
    );
  }
  final pattern = RegExp('${RegExp.escape(open)}(.*?)${RegExp.escape(end)}');
  Match? best;
  for (final m in pattern.allMatches(text)) {
    final inner = m.group(1)!;
    if (inner.isEmpty) continue;
    final innerStart = m.start + open.length;
    final innerEnd = innerStart + inner.length;
    final bool qualifies;
    if (touchingOnly) {
      final atEnd = start == text.length && start == m.end;
      qualifies = start == stop && (start >= m.start && start < m.end || atEnd);
    } else {
      qualifies = start <= innerEnd && stop >= innerStart;
    }
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

  final caret = map(origCaret ?? stop).clamp(0, unwrapped.length);
  return FormatEdit(
    unwrapped,
    map(start).clamp(0, unwrapped.length),
    caret,
    caret,
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

  bool isWord(int i) =>
      i >= 0 && i < text.length && _wordChar.hasMatch(text[i]);
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
