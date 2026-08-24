/// Enter-key list continuation for the editing surfaces (spec story 15).
///
/// Pure string/offset math — no Flutter imports. The editor calls this when
/// Enter is pressed; a null result means "not a list item" and a plain
/// newline is inserted instead.
library;

/// Matches an optional indent, then a list marker: `- `, `* `, `+ `,
/// `- [ ] ` / `- [x] ` tasks, or ordered `1. ` / `1) `.
final RegExp _markerPattern = RegExp(r'^(\s*)([-*+] \[[ xX]\] |[-*+] |\d+[.)] )');

/// Result of pressing Enter at the end of a list item: the new text plus
/// where the caret lands.
class FormatEdit {
  const FormatEdit(this.text, this.selStart);

  final String text;
  final int selStart;
}

/// Computes the effect of Enter pressed at [caret] (expected at end of its
/// line). Returns null when the current line is not a list item, or when the
/// caret is not at line end.
FormatEdit? continueList({required String text, required int caret}) {
  if (caret <= 0 || caret > text.length) return null;

  final lineStart = text.lastIndexOf('\n', caret - 1) + 1;
  // Continuation applies only when pressing Enter at the end of the line.
  final lineEnd = text.indexOf('\n', caret);
  if (lineEnd != -1) return null;

  final line = text.substring(lineStart, caret);
  final match = _markerPattern.firstMatch(line);
  if (match == null) return null;

  final indent = match.group(1)!;
  final marker = match.group(2)!;
  final content = line.substring(match.end);

  // Smart exit: the item holds nothing but its marker — clear it instead.
  if (content.trim().isEmpty) {
    final withoutMarker = text.replaceRange(lineStart + indent.length, caret, '');
    return FormatEdit(withoutMarker, lineStart + indent.length);
  }

  final nextMarker = _nextMarker(marker);
  final insertion = '\n$indent$nextMarker';
  final withBreak = text.replaceRange(caret, caret, insertion);
  return FormatEdit(withBreak, caret + insertion.length);
}

String _nextMarker(String marker) {
  final task = RegExp(r'^([-*+]) \[[xX ]\] $').firstMatch(marker);
  if (task != null) return '${task.group(1)} [ ] ';

  final ordered = RegExp(r'^(\d+)([.)]) $').firstMatch(marker);
  if (ordered != null) {
    final n = int.parse(ordered.group(1)!) + 1;
    return '$n${ordered.group(2)} ';
  }

  return marker;
}
