/// Match scanning for the find-in-note bar (spec story 14).
///
/// Pure functions — no Flutter imports. Traversal state (current match,
/// wrapping) lives with the widget; this module only locates matches.
library;

/// Returns case-insensitive, non-overlapping start offsets of [query] in
/// [text]. Blank queries yield no matches.
List<int> matchOffsets(String text, String query) {
  final needle = query.trim();
  if (needle.isEmpty) return const [];

  final lower = text.toLowerCase();
  final target = needle.toLowerCase();
  if (target.isEmpty || target.length > lower.length) return const [];

  final offsets = <int>[];
  var from = 0;
  while (from <= lower.length - target.length) {
    final hit = lower.indexOf(target, from);
    if (hit == -1) break;
    offsets.add(hit);
    from = hit + target.length;
  }
  return offsets;
}
