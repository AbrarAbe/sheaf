import 'package:intl/intl.dart';

import '../models/note.dart';

/// Filters [notes] by [query] and ranks them: title matches first, then
/// body-only matches; each group is newest-first. An empty query returns
/// everything newest-first.
List<Note> searchAndSort(List<Note> notes, String query) {
  final q = query.trim().toLowerCase();
  final sorted = [...notes]
    ..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
  if (q.isEmpty) return sorted;

  bool inTitle(Note n) => n.title.toLowerCase().contains(q);
  bool inBody(Note n) => n.body.toLowerCase().contains(q);

  return [...sorted.where(inTitle), ...sorted.where((n) => !inTitle(n) && inBody(n))];
}

/// One-line preview for list rows: first non-empty line with markdown
/// markers stripped.
String snippetOf(String body) {
  for (final rawLine in body.split('\n')) {
    var line = rawLine.trim();
    if (line.isEmpty) continue;
    line = line.replaceFirst(RegExp(r'^(#{1,6}\s+|>\s?|[-*+]\s+|\d+\.\s+)'), '');
    line = line.replaceAll(RegExp(r'[*_`~]'), '');
    return line.isEmpty ? '' : line;
  }
  return '';
}

/// Eyebrow label for day groups in the note list.
String dayLabel(DateTime day, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final local = DateTime(day.year, day.month, day.day);
  final today = DateTime(ref.year, ref.month, ref.day);
  if (local == today) return 'Today';
  if (local == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat.yMMMd().format(day);
}

/// Mono clock label for a row timestamp.
String clockLabel(DateTime time) => DateFormat.Hm().format(time);

/// Compact age label for trash entries (feedback F16): relative inside the
/// first week, absolute date beyond it.
String ageLabel(DateTime when, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final delta = ref.difference(when);
  if (delta < const Duration(minutes: 1)) return 'just now';
  if (delta < const Duration(hours: 1)) return '${delta.inMinutes}m ago';
  if (delta < const Duration(days: 1)) return '${delta.inHours}h ago';
  if (delta < const Duration(days: 7)) return '${delta.inDays}d ago';
  return DateFormat.yMMMd().format(when);
}
