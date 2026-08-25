import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sheaf/logic/search_controller.dart';
import 'package:sheaf/models/note.dart';

Note note(String title, {String? body, DateTime? at}) => Note(
  path: '$title.md',
  title: title,
  body: body ?? '',
  updatedAt: at ?? DateTime(2026, 1, 1, 10),
);

void main() {
  group('ageLabel (feedback F16)', () {
    final now = DateTime(2026, 8, 26, 12);
    DateTime ago(Duration d) => now.subtract(d);

    test('relative buckets inside the first week', () {
      expect(ageLabel(ago(const Duration(seconds: 10)), now: now), 'just now');
      expect(ageLabel(ago(const Duration(minutes: 5)), now: now), '5m ago');
      expect(ageLabel(ago(const Duration(hours: 3)), now: now), '3h ago');
      expect(ageLabel(ago(const Duration(days: 2)), now: now), '2d ago');
    });

    test('absolute date beyond a week', () {
      expect(ageLabel(DateTime(2026, 1, 1), now: now), 'Jan 1, 2026');
    });
  });
  group('searchAndSort', () {
    final a = note('Alpha', at: DateTime(2026, 3, 2));
    final b = note('Beta', body: 'talks about alpha', at: DateTime(2026, 3, 3));
    final c = note('Gamma', body: 'nothing here', at: DateTime(2026, 3, 4));

    test('empty query returns all notes, newest first', () {
      expect(searchAndSort([a, c, b], ''), [c, b, a]);
    });

    test('title hits outrank body hits regardless of recency', () {
      expect(searchAndSort([b, c, a], 'alpha'), [a, b]);
    });

    test('matching is case-insensitive', () {
      expect(searchAndSort([c], 'GAMMA'), [c]);
    });
  });

  group('snippetOf', () {
    test('uses first non-empty line and strips markdown markers', () {
      expect(snippetOf('# Heading\n\nreal text'), 'Heading');
      expect(snippetOf('> quote **bold**'), 'quote bold');
      expect(snippetOf('- item one'), 'item one');
      expect(snippetOf(''), '');
    });

    test('collapses to a single line', () {
      final s = snippetOf('first\nsecond');
      expect(s.contains('\n'), isFalse);
      expect(s, 'first');
    });
  });

  group('dayLabel', () {
    test('labels today and yesterday, dates otherwise', () {
      final now = DateTime(2026, 5, 4, 15);
      expect(dayLabel(DateTime(2026, 5, 4, 9), now: now), 'Today');
      expect(dayLabel(DateTime(2026, 5, 3, 9), now: now), 'Yesterday');
      expect(
        dayLabel(DateTime(2026, 2, 1), now: now),
        DateFormat.yMMMd().format(DateTime(2026, 2, 1)),
      );
    });

    test('clock label uses HH:mm for list rows', () {
      expect(clockLabel(DateTime(2026, 1, 1, 9, 41)), '09:41');
    });
  });
}
