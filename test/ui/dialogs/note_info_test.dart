import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sheaf/models/note.dart';
import 'package:sheaf/ui/dialogs/note_info.dart';

import '../../helpers/spy_vault_controller.dart';

void main() {
  late Directory tempDir;
  late Directory vaultDir;

  setUp(() async {
    // setUp runs outside the widget test's FakeAsync zone, so real async IO
    // (createTemp) is fine here.
    tempDir = await Directory.systemTemp.createTemp('sheaf_note_info_test');
    vaultDir = Directory('${tempDir.path}/vault')..createSync(recursive: true);
  });

  tearDown(() async => tempDir.delete(recursive: true));

  SpyVaultController makeSpy() {
    final c = SpyVaultController('${tempDir.path}/settings.json', vaultDir: vaultDir);
    addTearDown(c.dispose);
    return c;
  }

  /// Creates a note on disk (sync — real async IO deadlocks inside a widget
  /// test's FakeAsync zone) and returns its controller + note.
  Future<(SpyVaultController, Note)> createNote(String path, String body) async {
    final controller = makeSpy();
    final file = File('${vaultDir.path}/$path')..createSync(recursive: true);
    file.writeAsStringSync(body);
    final note = Note(path: path, title: 'Info Note', body: body);
    controller.fakeNotes = [note];
    return (controller, note);
  }

  Future<void> pumpDialog(WidgetTester tester, SpyVaultController controller, Note note) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteInfoDialog(controller: controller, note: note),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Returns the value text of the labelled row (the non-label Text inside the
  /// row's [Row]).
  String valueOf(WidgetTester tester, String label) {
    final row = find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
    return tester
        .widgetList<SelectableText>(find.descendant(of: row, matching: find.byType(SelectableText)))
        .map((w) => w.data ?? '')
        .firstWhere((t) => t.isNotEmpty, orElse: () => '');
  }

  group('NoteInfoDialog', () {
    testWidgets('renders header and all metadata rows', (tester) async {
      final (controller, note) = await createNote('info-note.md', 'Hello world\nSecond line');

      await pumpDialog(tester, controller, note);

      expect(find.text('Note Info'), findsOneWidget);
      expect(find.byIcon(Icons.info_outlined), findsOneWidget);
      // Every labelled row is present.
      for (final label in ['Title', 'Path', 'Size', 'Modified', 'Lines', 'Words', 'Characters']) {
        expect(find.text(label), findsOneWidget, reason: 'expected row "$label"');
      }
      expect(find.text('Close'), findsOneWidget);

      // Filename is gone: the Path row is the single source for the name.
      expect(find.text('Filename'), findsNothing);
      expect(valueOf(tester, 'Path'), 'info-note.md');
      expect(valueOf(tester, 'Title'), 'Info Note');
    });

    testWidgets('value text is selectable via SelectableText', (tester) async {
      final (controller, note) = await createNote('selectable.md', 'Hello world\nSecond line');

      await pumpDialog(tester, controller, note);

      // Every metadata row exposes its value through a SelectableText surface.
      expect(find.byType(SelectableText), findsNWidgets(7));
    });

    testWidgets('counts lines, words, characters correctly', (tester) async {
      const body = 'hello  world\nsecond line\nthird';
      final (controller, note) = await createNote('count.md', body);

      await pumpDialog(tester, controller, note);

      expect(valueOf(tester, 'Lines'), '3');
      expect(valueOf(tester, 'Words'), '5'); // split on whitespace runs
      expect(valueOf(tester, 'Characters'), body.length.toString());
    });

    testWidgets('Modified includes time via the shared formatter', (tester) async {
      final (controller, note) = await createNote('time.md', 'body');

      await pumpDialog(tester, controller, note);

      final modified = valueOf(tester, 'Modified');
      expect(modified, contains(' at '));
      expect(modified, anyOf(contains(' ago'), contains('just now')));
    });

    testWidgets('Size shows a human-readable file size', (tester) async {
      final (controller, note) = await createNote('size.md', 'body');

      await pumpDialog(tester, controller, note);

      final size = valueOf(tester, 'Size');
      // The on-disk file is a few bytes, so it renders in bytes, not 0 or a
      // raw integer.
      expect(size, matches(RegExp(r'^\d+(\.\d+)? B$')));
      expect(size, isNot('0 B'));
    });

    testWidgets('reads distinct stat fields without throwing', (tester) async {
      final (controller, note) = await createNote('distinct.md', 'distinct times');
      final file = controller.fileOf(note.path);
      final statBefore = file.statSync();
      // Real time must elapse for mtime/ctime to move; runAsync escapes the
      // FakeAsync zone so the delay actually fires instead of deadlocking.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      file.writeAsStringSync('distinct times v2');
      final statAfter = file.statSync();
      expect(
        statAfter.modified.isAfter(statBefore.modified) ||
            statAfter.changed.isAfter(statBefore.changed),
        isTrue,
      );

      await pumpDialog(tester, controller, note);
      expect(find.text('Modified'), findsOneWidget);
    });

    testWidgets('Close button dismisses the dialog', (tester) async {
      final (controller, note) = await createNote('close.md', 'close me');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => NoteInfoDialog(controller: controller, note: note),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Note Info'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Note Info'), findsNothing);
    });

    testWidgets('handles empty body gracefully', (tester) async {
      final (controller, note) = await createNote('empty.md', '');

      await pumpDialog(tester, controller, note);

      expect(find.text('Note Info'), findsOneWidget);
      expect(valueOf(tester, 'Lines'), '0');
      expect(valueOf(tester, 'Words'), '0');
      expect(valueOf(tester, 'Characters'), '0');
    });

    testWidgets('Path is URL-decoded', (tester) async {
      final controller = makeSpy();
      const encodedPath = 'folder%20name/note%20file.md';
      // Back the note with a real file at the (literal) encoded path so
      // controller.fileOf() finds it when statting.
      final file = File('${vaultDir.path}/$encodedPath')..createSync(recursive: true);
      file.writeAsStringSync('b');
      final encodedNote = Note(path: encodedPath, title: 'T', body: 'b');

      await pumpDialog(tester, controller, encodedNote);

      expect(valueOf(tester, 'Path'), 'folder name/note file.md');
      expect(find.textContaining('%20'), findsNothing);
    });
  });
}
