/// List formatting toggles for editor action bar / context menu.
///
/// Pure string/offset math — no Flutter imports.
library;

import 'formatting.dart';

enum ListKind { bullet, bulletStar, numbered, task }

final _bulletDash = RegExp(r'^(\s*)- (.*)$');
final _bulletStar = RegExp(r'^(\s*)\* (.*)$');
final _numbered = RegExp(r'^(\s*)\d+[.)] (.*)$');
final _task = RegExp(r'^(\s*)- \[[ xX]\] (.*)$');

/// Toggles list formatting for lines intersecting [selStart]/[selEnd].
FormatEdit toggleList(String text, int selStart, int selEnd, ListKind kind) {
  final a = selStart.clamp(0, text.length);
  final b = selEnd.clamp(0, text.length);
  final start = a <= b ? a : b;
  final stop = a <= b ? b : a;
  // Expand to full line boundaries.
  final lineStart = text.lastIndexOf('\n', start == 0 ? 0 : start - 1) + 1;
  final lineEndPos = text.indexOf('\n', stop);
  final effectiveEnd = lineEndPos == -1 ? text.length : lineEndPos;
  // If collapsed and line is empty, just insert marker.
  if (start == stop && text.substring(lineStart, effectiveEnd).trim().isEmpty) {
    final marker = _markerFor(kind, 1);
    // ignore: unused_local_variable
    final indent = text.substring(lineStart, start);
    final before = text.substring(0, start);
    final after = text.substring(stop);
    final inserted = marker;
    // If line empty, replace whole line with marker
    if (lineStart == 0 && effectiveEnd == text.length && text.trim().isEmpty) {
      return FormatEdit(marker, marker.length, marker.length, marker.length);
    }
    return FormatEdit(
      '$before$inserted$after',
      start + inserted.length,
      start + inserted.length,
      start + inserted.length,
    );
  }
  final lines = text.substring(lineStart, effectiveEnd).split('\n');
  final allSameKind = lines.every((l) => _isKind(l, kind));
  final newLines = <String>[];
  var nextNum = 1;
  // Determine starting number for numbered continuity: look back for previous numbered line.
  if (kind == ListKind.numbered && !allSameKind) {
    // Find previous numbered line before lineStart
    final before = text.substring(0, lineStart);
    final prevMatch = RegExp(r'(\d+)[.)] [^\n]*$').firstMatch(before);
    if (prevMatch != null) {
      try {
        nextNum = int.parse(prevMatch.group(1)!) + 1;
      } catch (_) {}
    }
  }
  for (final line in lines) {
    if (allSameKind) {
      newLines.add(_unwrap(line));
    } else {
      if (_isAnyList(line)) {
        final unwrapped = _unwrap(line);
        newLines.add(_wrap(unwrapped, kind, nextNum++));
      } else {
        newLines.add(_wrap(line, kind, nextNum++));
      }
    }
  }
  final newBlock = newLines.join('\n');
  final newText = text.replaceRange(lineStart, effectiveEnd, newBlock);
  final newEnd = lineStart + newBlock.length;
  return FormatEdit(newText, lineStart, newEnd, newEnd);
}

bool _isKind(String line, ListKind kind) {
  switch (kind) {
    case ListKind.bullet:
      return _bulletDash.hasMatch(line) && !_task.hasMatch(line);
    case ListKind.bulletStar:
      return _bulletStar.hasMatch(line);
    case ListKind.numbered:
      return _numbered.hasMatch(line);
    case ListKind.task:
      return _task.hasMatch(line);
  }
}

bool _isAnyList(String line) =>
    _task.hasMatch(line) ||
    _bulletDash.hasMatch(line) ||
    _bulletStar.hasMatch(line) ||
    _numbered.hasMatch(line);

String _unwrap(String line) {
  final mTask = _task.firstMatch(line);
  if (mTask != null) return '${mTask.group(1)}${mTask.group(2)}';
  final mDash = _bulletDash.firstMatch(line);
  if (mDash != null) return '${mDash.group(1)}${mDash.group(2)}';
  final mStar = _bulletStar.firstMatch(line);
  if (mStar != null) return '${mStar.group(1)}${mStar.group(2)}';
  final mNum = _numbered.firstMatch(line);
  if (mNum != null) return '${mNum.group(1)}${mNum.group(2)}';
  return line;
}

String _wrap(String line, ListKind kind, int num) {
  final indentMatch = RegExp(r'^(\s*)').firstMatch(line);
  final indent = indentMatch?.group(1) ?? '';
  final content = line.substring(indent.length);
  final marker = _markerFor(kind, num);
  return '$indent$marker$content';
}

String _markerFor(ListKind kind, int num) {
  switch (kind) {
    case ListKind.bullet:
      return '- ';
    case ListKind.bulletStar:
      return '* ';
    case ListKind.numbered:
      return '$num. ';
    case ListKind.task:
      return '- [ ] ';
  }
}
