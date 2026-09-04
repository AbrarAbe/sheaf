/// Match scanning for the find-in-note bar (spec story 14).
///
/// Pure functions — no Flutter imports. Traversal state (current match,
/// wrapping) lives with the widget; this module only locates matches.
library;

/// Returns non-overlapping start offsets of [query] in [text].
/// Blank queries yield no matches. Case-insensitive by default.
List<int> matchOffsets(String text, String query, {bool caseSensitive = false}) {
  final needle = query.trim();
  if (needle.isEmpty) return const [];

  final haystack = caseSensitive ? text : text.toLowerCase();
  final target = caseSensitive ? needle : needle.toLowerCase();
  if (target.isEmpty || target.length > haystack.length) return const [];

  final offsets = <int>[];
  var from = 0;
  while (from <= haystack.length - target.length) {
    final hit = haystack.indexOf(target, from);
    if (hit == -1) break;
    offsets.add(hit);
    from = hit + target.length;
  }
  return offsets;
}
