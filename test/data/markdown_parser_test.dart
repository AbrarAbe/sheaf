import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/data/markdown_parser.dart';
import 'package:sheaf/models/note.dart';

void main() {
  group('extractTitle', () {
    test('prefers the first H1', () {
      expect(extractTitle('# Meeting notes\n\nbody', '2024.md'), 'Meeting notes');
    });

    test('ignores H2 and later headings', () {
      expect(extractTitle('## Not this\n## Nor this', 'a.md'), 'a');
    });

    test('falls back to filename stem without extension', () {
      expect(extractTitle('', 'grocery list.md'), 'grocery list');
      expect(extractTitle('no heading here', 'ideas.md'), 'ideas');
    });

    test('trims surrounding whitespace of the heading text', () {
      expect(extractTitle('#   Spaced out   \n', 'x.md'), 'Spaced out');
    });

    test('does not treat fenced code hash lines as titles', () {
      expect(extractTitle('```\n# comment\n```', 'code.md'), 'code');
    });
  });

  group('extractTags', () {
    test('finds simple inline tags', () {
      expect(extractTags('hello #work world'), ['work']);
      expect(extractTags('#work and #q3 planning'), ['work', 'q3']);
    });

    test('supports underscores, hyphens and nested slashes', () {
      expect(extractTags('#my_tag #second-round #parent/child'), [
        'my_tag',
        'second-round',
        'parent/child',
      ]);
    });

    test('deduplicates while preserving first-seen order', () {
      expect(extractTags('#b #a #b #a/c #a'), ['b', 'a', 'a/c']);
    });

    test('requires a leading letter or underscore', () {
      expect(extractTags('#123 #42abc ok'), isEmpty);
    });

    test('ignores bare hashes and lone punctuation', () {
      expect(extractTags('# ## ### C# style'), isEmpty);
    });

    test('skips tags inside fenced code blocks', () {
      expect(extractTags('#real\n```\n#fake_in_fence\n```'), ['real']);
    });

    test('skips tags inside inline code', () {
      expect(extractTags('run `grep #todo file` now #real'), ['real']);
    });

    test('skips url fragments', () {
      expect(extractTags('see https://ex.com/page#section'), isEmpty);
      expect(extractTags('see https://ex.com/page#section #a'), ['a']);
    });
  });

  group('extractImages', () {
    test('parses a plain image ref', () {
      final imgs = extractImages('![a photo](attachments/photo.png)');
      expect(imgs, [const ImageRef(alt: 'a photo', path: 'attachments/photo.png')]);
    });

    test('parses obsidian width syntax', () {
      final imgs = extractImages('![shot|400](attachments/shot.png)');
      expect(imgs.single, const ImageRef(alt: 'shot', path: 'attachments/shot.png', width: 400));
    });

    test('parses multiple images and preserves order', () {
      final imgs = extractImages('![one|250](a.png) text ![two](dir/b.png) ![three|80](c.png)');
      expect(imgs, [
        const ImageRef(alt: 'one', path: 'a.png', width: 250),
        const ImageRef(alt: 'two', path: 'dir/b.png'),
        const ImageRef(alt: 'three', path: 'c.png', width: 80),
      ]);
    });

    test('ignores regular links', () => expect(extractImages('[not an image](page.md)'), isEmpty));

    test('ignores malformed refs', () => expect(extractImages('![unclosed](a.png'), isEmpty));
  });

  group('Note', () {
    test('copyWith replaces only given fields', () {
      const note = Note(path: 'ideas/a.md', title: 'A', body: '# A', tags: ['x']);
      final renamed = note.copyWith(title: 'B');
      expect(renamed.title, 'B');
      expect(renamed.path, 'ideas/a.md');
      expect(renamed.tags, ['x']);
    });
  });
}
