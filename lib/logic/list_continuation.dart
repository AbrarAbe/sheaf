/// Enter-key list continuation for the editing surfaces (spec story 15).
///
/// Pure string/offset math — no Flutter imports. The editor calls this when
/// Enter is pressed; a null result means "not a list item" and a plain
/// newline is inserted instead.
library;

/// Matches an optional indent, then a list marker: `- `, `* `, `+ `,
/// `- [ ] ` / `- [x] ` tasks, or ordered `1. ` / `1) `.
final RegExp _markerPattern = RegExp(
  r'^(\s*)([-*+] \[[ xX]\] |[-*+] |\d+[.)] )',
);
final RegExp _taskPattern = RegExp(r'^([-*+]) \[[xX ]\] $');
final RegExp _orderedPattern = RegExp(r'^(\d+)([.)]) $');

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
///
/// Also supports non-collapsed selection via [selStart]/[selEnd]: the selection
/// is replaced with a newline+marker insertion (mirrors normal typing).
FormatEdit? continueList({
  required String text,
  int? caret,
  int? selStart,
  int? selEnd,
}) {
  // Normalize to start/stop. Prefer selStart/selEnd when provided, else caret.
  final int start;
  final int stop;
  if (selStart != null || selEnd != null) {
    final a = (selStart ?? caret ?? text.length).clamp(0, text.length);
    final b = (selEnd ?? a).clamp(0, text.length);
    start = a <= b ? a : b;
    stop = a <= b ? b : a;
  } else if (caret != null) {
    final c = caret.clamp(0, text.length);
    start = c;
    stop = c;
  } else {
    return null;
  }
  if (start != stop) {
    final beforeSel = text.substring(0, start);
    final afterSel = text.substring(stop);
    final lineStart = beforeSel.lastIndexOf('\n') + 1;
    // Original line extent for smart-exit check.
    final origLineEnd = text.indexOf('\n', start);
    final origLine = text.substring(
      lineStart,
      origLineEnd == -1 ? text.length : origLineEnd,
    );
    final origMatch = _markerPattern.firstMatch(origLine);
    if (origMatch == null) return null;
    // Selection must be at line end to continue list; otherwise plain newline.
    final indent = origMatch.group(1)!;
    final marker = origMatch.group(2)!;
    final origContent = origLine.substring(origMatch.end);
    if (origContent.trim().isEmpty) {
      final without = text.replaceRange(lineStart, stop, '');
      final markerLen = indent.length + marker.length;
      final hasMarker =
          without.length >= lineStart + markerLen &&
          without.substring(lineStart, lineStart + markerLen) ==
              indent + marker;
      final cleaned = hasMarker
          ? without.replaceRange(lineStart, lineStart + markerLen, '')
          : without;
      return FormatEdit(cleaned, lineStart);
    }
    final nextMarker = _nextMarker(marker);
    final insertion = '\n$indent$nextMarker';
    final withBreak = beforeSel + insertion + afterSel;
    return FormatEdit(withBreak, start + insertion.length);
  }
  final caretPos = start;
  if (caretPos > text.length) return null;
  // Allow caret == 0? Original guard was caret <=0 return null, but that
  // prevents continuing at start of text? Keep but allow 0 if text starts with marker?
  // Preserve original: if caret==0 return null unless text starts with marker? Simpler keep <=0 -> null.
  if (caretPos <= 0 && text.isEmpty) return null;
  if (caretPos == 0) return null;
  if (caretPos > text.length) return null;

  final lineStart = text.lastIndexOf('\n', caretPos - 1) + 1;
  // Continuation applies only when pressing Enter at the end of the line.
  final lineEnd = text.indexOf('\n', caretPos);
  if (lineEnd != -1 && caretPos != lineEnd) return null;

  final line = text.substring(lineStart, caretPos);
  final match = _markerPattern.firstMatch(line);
  if (match == null) return null;

  final indent = match.group(1)!;
  final marker = match.group(2)!;
  final content = line.substring(match.end);

  // Smart exit: the item holds nothing but its marker — clear it instead.
  if (content.trim().isEmpty) {
    final withoutMarker = text.replaceRange(lineStart, caretPos, '');
    return FormatEdit(withoutMarker, lineStart);
  }

  final nextMarker = _nextMarker(marker);
  final insertion = '\n$indent$nextMarker';
  final withBreak = text.replaceRange(caretPos, caretPos, insertion);
  return FormatEdit(withBreak, caretPos + insertion.length);
}

String _nextMarker(String marker) {
  final task = _taskPattern.firstMatch(marker);
  if (task != null) return '${task.group(1)} [ ] ';

  final ordered = _orderedPattern.firstMatch(marker);
  if (ordered != null) {
    int n;
    try {
      n = int.parse(ordered.group(1)!);
    } catch (_) {
      return marker;
    }
    n = (n + 1).clamp(1, 9999);
    return '$n${ordered.group(2)} ';
  }

  return marker;
}
