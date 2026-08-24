import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/logic/find_controller.dart';

void main() {
  group('matchOffsets', () {
    test('finds case-insensitive matches', () {
      expect(matchOffsets('Ab ab aB', 'ab'), [0, 3, 6]);
    });

    test('returns empty for blank queries', () {
      expect(matchOffsets('anything', ''), isEmpty);
      expect(matchOffsets('anything', '   '), isEmpty);
    });

    test('returns empty when nothing matches', () {
      expect(matchOffsets('hello world', 'nope'), isEmpty);
    });

    test('matches are non-overlapping and advance by query length', () {
      expect(matchOffsets('aaaa', 'aa'), [0, 2]);
    });
  });
}
