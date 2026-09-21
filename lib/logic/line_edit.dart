/// Two-space indent / outdent primitives for the editor (spec story 46).
///
/// Pure string/offset math — no Flutter imports. The editor calls these when
/// Tab / Shift+Tab is pressed; they return the new text with the selection
/// remapped to its new position. Per-line transforms: each touched line
/// (from the selection's start line to its end line, inclusive) gets the
/// prefix added or removed; other lines are untouched.
library;

import 'formatting.dart';

const String _indentUnit = '  ';

/// Indents every touched line by two spaces. Touched = from the selection's
/// start line to its end line, inclusive. Returns [FormatEdit] with the new
/// text and the selection remapped.
FormatEdit indentBlock({
  required String text,
  required int selStart,
  required int selEnd,
}) {
  return _mapLinePrefixes(
    text,
    selStart,
    selEnd,
    (line) => _indentUnit + line,
  );
}

/// Removes up to two leading spaces from every touched line. No-op on lines
/// with no leading space (or fewer than two). Returns [FormatEdit] with the
/// new text and the selection remapped.
FormatEdit outdentBlock({
  required String text,
  required int selStart,
  required int selEnd,
}) {
  return _mapLinePrefixes(
    text,
    selStart,
    selEnd,
    (line) {
      if (line.length >= 2 && line[0] == ' ' && line[1] == ' ') {
        return line.substring(2);
      }
      if (line.isNotEmpty && line[0] == ' ') {
        return line.substring(1);
      }
      return line;
    },
  );
}

/// Shared line-boundary walk for [indentBlock] / [outdentBlock].
///
/// Transforms [lineFn] runs only on lines within the touched range
/// `[startLine, endLine]` (derived from the selection offsets); every other
/// line is copied verbatim. Anchors are remapped using the same line index:
/// `newPos = oldPos + sum(deltas[0..lineOf(pos)])`, which includes the
/// anchor's own line — required because an anchor at a line's end gets
/// shifted by that line's length change.
FormatEdit _mapLinePrefixes(
  String text,
  int selStart,
  int selEnd,
  String Function(String line) lineFn,
) {
  if (text.isEmpty) return FormatEdit('', 0, 0, 0);

  final a = selStart.clamp(0, text.length);
  final b = selEnd.clamp(0, text.length);
  final start = a <= b ? a : b;
  final stop = a <= b ? b : a;

  final startLine = _lineOf(text, start);
  final endLine = _lineOf(text, stop);

  final deltas = <int>[];
  final buf = StringBuffer();
  var lineStart = 0;
  var i = 0;
  while (lineStart <= text.length) {
    final lineEnd = text.indexOf('\n', lineStart);
    final end = lineEnd == -1 ? text.length : lineEnd;
    final line = text.substring(lineStart, end);
    final transformed =
        (i >= startLine && i <= endLine) ? lineFn(line) : line;
    deltas.add(transformed.length - line.length);
    buf.write(transformed);
    if (end < text.length) buf.write('\n');
    lineStart = end + 1;
    i++;
  }

  final newText = buf.toString();
  final newStart = _shiftAnchor(text, deltas, start, startLine).clamp(
    0,
    newText.length,
  );
  final newEnd = _shiftAnchor(text, deltas, stop, endLine).clamp(
    0,
    newText.length,
  );
  return FormatEdit(newText, newStart, newEnd, newStart);
}

/// Line index (0-based) containing `pos`. The newline character at offset
/// `pos` terminates the preceding line, so an anchor at a newline boundary
/// belongs to the earlier line.
int _lineOf(String text, int pos) {
  var count = 0;
  for (var i = 0; i < pos && i < text.length; i++) {
    if (text[i] == '\n') count++;
  }
  return count;
}

/// New position of an anchor after the walk. Sum of length deltas for all
/// lines up to and including the anchor's own line.
int _shiftAnchor(String text, List<int> deltas, int pos, int anchorLine) {
  var sum = 0;
  for (var j = 0; j <= anchorLine && j < deltas.length; j++) {
    sum += deltas[j];
  }
  return pos + sum;
}
