/// Link and image formatting toggles.
///
/// Pure string/offset math.
library;

import 'formatting.dart';

enum LinkKind { link, image }

/// Toggles [selection] to/from markdown link/image.
/// If [url] is null/empty and wrapping, inserts placeholder "https://".
/// Collapsed caret on a word wraps that word; otherwise inserts empty link.
FormatEdit toggleLink(
  String text,
  int selStart,
  int selEnd,
  LinkKind kind, {
  String? url,
}) {
  final a = selStart.clamp(0, text.length);
  final b = selEnd.clamp(0, text.length);
  final start = a <= b ? a : b;
  final stop = a <= b ? b : a;
  final isImage = kind == LinkKind.image;
  final prefix = isImage ? '![' : '[';
  final mid = '](';
  final suffix = ')';
  final u = (url == null || url.trim().isEmpty) ? 'https://' : url.trim();

  // Check if selection already wrapped as link/image.
  // Expand to detect enclosing.
  if (stop > start) {
    final sel = text.substring(start, stop);
    // Already wrapped? e.g. "[word](url)" or "![word](url)"
    if (isImage) {
      if (sel.startsWith('![') && sel.contains('](') && sel.endsWith(')')) {
        final inner = sel.substring(2, sel.lastIndexOf(']('));
        final unwrapped = text.replaceRange(start, stop, inner);
        return FormatEdit(
          unwrapped,
          start,
          start + inner.length,
          start + inner.length,
        );
      }
    } else {
      if (sel.startsWith('[') && sel.contains('](') && sel.endsWith(')')) {
        final inner = sel.substring(1, sel.lastIndexOf(']('));
        final unwrapped = text.replaceRange(start, stop, inner);
        return FormatEdit(
          unwrapped,
          start,
          start + inner.length,
          start + inner.length,
        );
      }
    }
    // Enclosing span check: find "[sel](url)" that contains selection inner.
    final pat = RegExp(
      '${RegExp.escape(prefix)}(.*?)${RegExp.escape(mid)}(.*?)${RegExp.escape(suffix)}',
    );
    Match? best;
    for (final m in pat.allMatches(text)) {
      final innerStart = m.start + prefix.length;
      final innerEnd = m.start + prefix.length + m.group(1)!.length;
      if (start <= innerEnd && stop >= innerStart && m.group(1)!.isNotEmpty) {
        if (best == null || m.group(1)!.length < best.group(1)!.length)
          best = m;
      }
    }
    if (best != null) {
      final inner = best.group(1)!;
      final b = best;
      final unwrapped = text.replaceRange(b.start, b.end, inner);
      int map(int o) {
        if (o <= b.start) return o;
        if (o < b.start + prefix.length) return b.start;
        if (o <= b.start + prefix.length + inner.length)
          return o - prefix.length;
        return o -
            prefix.length -
            mid.length -
            b.group(2)!.length -
            suffix.length;
      }

      return FormatEdit(
        unwrapped,
        map(start).clamp(0, unwrapped.length),
        map(stop).clamp(0, unwrapped.length),
        map(stop).clamp(0, unwrapped.length),
      );
    }
    // Wrap selection as link.
    final wrapped = '$prefix$sel$mid$u$suffix';
    final newText = text.replaceRange(start, stop, wrapped);
    return FormatEdit(
      newText,
      start + prefix.length,
      start + prefix.length + sel.length,
      start + prefix.length + sel.length,
    );
  }
  // Collapsed: word-aware.
  final (wStart, wEnd) = wordBoundary(text, start);
  final isWord =
      wEnd > wStart &&
      RegExp(r'[\p{L}\p{N}_]', unicode: true).hasMatch(text[wStart]);
  if (isWord) {
    final word = text.substring(wStart, wEnd);
    // If word already inside link, unwrap (reuse enclosing check above with wStart/wEnd)
    final pat = RegExp(
      '${RegExp.escape(prefix)}(.*?)${RegExp.escape(mid)}(.*?)${RegExp.escape(suffix)}',
    );
    for (final m in pat.allMatches(text)) {
      final inner = m.group(1)!;
      if (inner == word && m.start <= wStart && m.end >= wEnd) {
        final unwrapped = text.replaceRange(m.start, m.end, inner);
        return FormatEdit(
          unwrapped,
          m.start,
          m.start + inner.length,
          m.start + inner.length,
        );
      }
    }
    final wrapped = '$prefix$word$mid$u$suffix';
    final newText = text.replaceRange(wStart, wEnd, wrapped);
    return FormatEdit(
      newText,
      wStart + prefix.length,
      wStart + prefix.length + word.length,
      wStart + prefix.length + word.length,
    );
  }
  // Empty caret: insert placeholder link with word placeholder.
  final placeholder = isImage ? '![alt]($u)' : '[](https://)';
  // For image with word not found, insert empty image markup.
  final insert = isImage ? '![]($u)' : '[]($u)';
  final at = start;
  final newText = text.replaceRange(at, at, insert);
  final caret = at + (isImage ? 2 : 1); // inside brackets
  return FormatEdit(newText, caret, caret, caret);
}
