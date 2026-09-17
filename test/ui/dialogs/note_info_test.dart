import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
        .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
        .map((w) => w.data ?? '')
        .firstWhere((t) => t.isNotEmpty && t != label, orElse: () => '');
  }

  group('NoteInfoDialog', () {
    testWidgets('renders header and all metadata rows', (tester) async {
      final (controller, note) = await createNote('info-note.md', 'Hello world\nSecond line');

      await pumpDialog(tester, controller, note);

      expect(find.text('Note Info'), findsOneWidget);
      expect(find.byIcon(Icons.info_outlined), findsOneWidget);
      // Every labelled row is present.
      for (final label in [
        'Title',
        'Filename',
        'Path',
        'Lines',
        'Created',
        'Modified',
        'Words',
        'Characters',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'expected row "$label"');
      }
      expect(find.text('Close'), findsOneWidget);

      // A single-level path shows the same name in Filename and Path.
      expect(valueOf(tester, 'Filename'), 'info-note.md');
      expect(valueOf(tester, 'Path'), 'info-note.md');
      expect(valueOf(tester, 'Title'), 'Info Note');
    });

    testWidgets('counts lines, words, characters correctly', (tester) async {
      const body = 'hello  world\nsecond line\nthird';
      final (controller, note) = await createNote('count.md', body);

      await pumpDialog(tester, controller, note);

      expect(valueOf(tester, 'Lines'), '3');
      expect(valueOf(tester, 'Words'), '5'); // split on whitespace runs
      expect(valueOf(tester, 'Characters'), body.length.toString());
    });

    testWidgets('Created and Modified both include time via shared formatter', (tester) async {
      final (controller, note) = await createNote('time.md', 'body');

      await pumpDialog(tester, controller, note);

      final created = valueOf(tester, 'Created');
      final modified = valueOf(tester, 'Modified');
      expect(created, contains(' at '));
      expect(modified, contains(' at '));
      expect(created, anyOf(contains(' ago'), contains('just now')));
      expect(modified, anyOf(contains(' ago'), contains('just now')));
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
      expect(find.text('Created'), findsOneWidget);
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

    testWidgets('Path and Filename are URL-decoded', (tester) async {
      final controller = makeSpy();
      const encodedPath = 'folder%20name/note%20file.md';
      // Back the note with a real file at the (literal) encoded path so
      // controller.fileOf() finds it when statting.
      final file = File('${vaultDir.path}/$encodedPath')..createSync(recursive: true);
      file.writeAsStringSync('b');
      final encodedNote = Note(path: encodedPath, title: 'T', body: 'b');

      await pumpDialog(tester, controller, encodedNote);

      expect(valueOf(tester, 'Path'), 'folder name/note file.md');
      expect(valueOf(tester, 'Filename'), 'note file.md');
      expect(find.textContaining('%20'), findsNothing);
    });
  });
}
