import 'dart:io';

import 'package:flutter/services.dart' show TextSelection;
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/logic/editor_controller.dart';
import 'package:sheaf/logic/undo_history.dart';
import 'package:sheaf/models/settings.dart';

void main() {
  late Directory tempDir;
  late VaultRepository vault;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sheaf_editor_test');
    vault = VaultRepository(root: tempDir);
  });

  tearDown(() async => tempDir.delete(recursive: true));

  test('open loads note into state and reports clean', () async {
    final note = await vault.createNote(title: 'A', body: '# A\nhello');
    final controller = EditorController(vault: vault);
    addTearDown(controller.dispose);

    await controller.open(note);

    expect(controller.current?.path, note.path);
    expect(controller.body, '# A\nhello');
    expect(controller.status, EditorStatus.clean);
  });

  test('close clears state', () async {
    final note = await vault.createNote(title: 'C');
    final controller = EditorController(vault: vault);
    addTearDown(controller.dispose);
    await controller.open(note);

    await controller.close();

    expect(controller.current, isNull);
  });

  test('typing marks dirty, then autosave writes within debounce', () async {
    final note = await vault.createNote(title: 'B', body: 'start');
    final controller = EditorController(vault: vault);
    addTearDown(controller.dispose);
    await controller.open(note);

    controller.updateBody('start edited');
    expect(controller.status, EditorStatus.dirty);

    // Wait past the default 1 s debounce.
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(controller.status, EditorStatus.saved);
    expect((await vault.readNote(note.path)).body, 'start edited');
  });

  test('flush forces an immediate save of pending edits', () async {
    final note = await vault.createNote(title: 'F', body: 'x');
    final controller = EditorController(vault: vault);
    addTearDown(controller.dispose);
    await controller.open(note);

    controller.updateBody('y');
    await controller.flush();

    expect(controller.status, EditorStatus.saved);
    expect((await vault.readNote(note.path)).body, 'y');
  });

  test('renameCurrent flushes, renames the file, and reopens it', () async {
    final note = await vault.createNote(title: 'Old Name', body: 'keep me');
    final controller = EditorController(vault: vault);
    addTearDown(controller.dispose);
    await controller.open(note);
    controller.updateBody('keep me!');

    await controller.renameCurrent('New Name');

    expect(File('${tempDir.path}/New Name.md').existsSync(), isTrue);
    expect(File('${tempDir.path}/Old Name.md').existsSync(), isFalse);
    expect((await vault.readNote('New Name.md')).body, 'keep me!');
    expect(controller.current?.path, 'New Name.md');
  });

  test('rapid edits reset the debounce timer', () async {
    final note = await vault.createNote(title: 'R', body: 'a');
    final controller = EditorController(
      vault: vault,
      autosaveDelay: const Duration(milliseconds: 300),
    );
    addTearDown(controller.dispose);
    await controller.open(note);

    controller.updateBody('b');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    controller.updateBody('c');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    // First timer would have fired by now if not reset; nothing saved yet.
    expect(controller.status, EditorStatus.dirty);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(controller.status, EditorStatus.saved);
    expect((await vault.readNote(note.path)).body, 'c');
  });

  test('opening another note flushes the previous one first', () async {
    final a = await vault.createNote(title: 'A1', body: 'one');
    final b = await vault.createNote(title: 'B2', body: 'two');
    final controller = EditorController(vault: vault);
    addTearDown(controller.dispose);
    await controller.open(a);

    controller.updateBody('one!');
    await controller.open(b);

    expect((await vault.readNote(a.path)).body, 'one!');
    expect(controller.current?.path, b.path);
  });

  group('editor mode (spec story 12)', () {
    test('defaults to normal and notifies only on real changes', () {
      final controller = EditorController(vault: vault);
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.mode, EditorMode.normal);
      controller.setMode(EditorMode.markdown);
      expect(controller.mode, EditorMode.markdown);
      expect(notifications, 1);

      controller.setMode(EditorMode.markdown);
      expect(notifications, 1);
    });

    test('cycles normal → markdown → preview → normal', () {
      final controller = EditorController(vault: vault);
      addTearDown(controller.dispose);

      expect(controller.mode, EditorMode.normal);
      controller.cycleMode();
      expect(controller.mode, EditorMode.markdown);
      controller.cycleMode();
      expect(controller.mode, EditorMode.preview);
      controller.cycleMode();
      expect(controller.mode, EditorMode.normal);
    });

    test('mode change reaches the persistence callback', () {
      final seen = <EditorMode>[];
      final controller = EditorController(
        vault: vault,
        initialMode: EditorMode.preview,
        onModeChanged: seen.add,
      );
      addTearDown(controller.dispose);

      expect(controller.mode, EditorMode.preview);
      controller.setMode(EditorMode.normal);
      expect(seen, [EditorMode.normal]);
    });
  });  group('undo history (spec story 50)', () {
    test('undo returns the note-as-opened state', () async {
      final note = await vault.createNote(title: 'A', body: 'original');
      final controller = EditorController(vault: vault);
      addTearDown(controller.dispose);
      await controller.open(note);

      // Seed history was done in open(). An edit produces a new state.
      controller.updateBody(
        'original!',
        selection: const TextSelection.collapsed(offset: 9),
      );
      expect(controller.body, 'original!');

      // Undo restores the note-as-opened state.
      final undone = controller.undoCurrent();
      expect(undone, isNotNull);
      expect(undone!.text, 'original');
      expect(controller.body, 'original');

      // Redo reapplies.
      final redone = controller.redoCurrent();
      expect(redone, isNotNull);
      expect(redone!.text, 'original!');
      expect(controller.body, 'original!');
    });

    test('undo/redo are per-note — switching notes switches stacks',
        () async {
      final a = await vault.createNote(title: 'A', body: 'a');
      final b = await vault.createNote(title: 'B', body: 'b');
      final controller = EditorController(vault: vault);
      addTearDown(controller.dispose);
      await controller.open(a);
      controller.updateBody(
        'a edit',
        selection: const TextSelection.collapsed(offset: 6),
      );
      await controller.flush();

      await controller.open(b);
      expect(controller.undoCurrent(), isNull);
      expect(controller.body, 'b');

      await controller.open(await vault.readNote(a.path));
      expect(controller.body, 'a edit');
      final undone = controller.undoCurrent();
      expect(undone, isNotNull);
      expect(undone!.text, 'a');
      expect(controller.body, 'a');
    });

    test('undo discards redo branch on new edit', () async {
      final note = await vault.createNote(title: 'A', body: 'x');
      final controller = EditorController(vault: vault);
      addTearDown(controller.dispose);
      await controller.open(note);

      // Each edit here is a "forced distinct" step (coalesce: false) so the
      // test exercises the redo-branch-discard path even though the calls
      // happen back-to-back in time. Real typing would coalesce them;
      // programmatic edits (format, indent, list continuation) opt out.
      controller.updateBody(
        'xy',
        selection: const TextSelection.collapsed(offset: 2),
        coalesce: false,
      );
      controller.updateBody(
        'xyz',
        selection: const TextSelection.collapsed(offset: 3),
        coalesce: false,
      );
      // Undo to 'xy'.
      expect(controller.undoCurrent()!.text, 'xy');
      // Edit instead of redoing — the 'xyz' branch is discarded.
      controller.updateBody(
        'xw',
        selection: const TextSelection.collapsed(offset: 2),
        coalesce: false,
      );
      // Redo should now be a no-op.
      expect(controller.redoCurrent(), isNull);
    });

    test('reopening the same note keeps its undo history', () async {
      final a = await vault.createNote(title: 'A', body: 'a');
      final b = await vault.createNote(title: 'B', body: 'b');
      final controller = EditorController(vault: vault);
      addTearDown(controller.dispose);
      await controller.open(a);
      controller.updateBody(
        'a!',
        selection: const TextSelection.collapsed(offset: 2),
      );
      await controller.flush();

      // Switch to B and back to A. Re-read a so the Note object reflects
      // the just-saved body.
      await controller.open(b);
      await controller.open(await vault.readNote(a.path));
      expect(controller.body, 'a!');
      final undone = controller.undoCurrent();
      expect(undone, isNotNull);
      expect(undone!.text, 'a');
      expect(controller.body, 'a');
    });

    test('history is seeded on open so undo has a baseline', () async {
      final note = await vault.createNote(title: 'A', body: 'hello');
      final controller = EditorController(vault: vault);
      addTearDown(controller.dispose);
      await controller.open(note);

      // Seed means one entry in the stack — undo is a no-op until an edit.
      expect(controller.currentHistory, isNotNull);
      expect(controller.undoCurrent(), isNull);
    });

    test('undo marks status dirty and schedules a save', () async {
      final note = await vault.createNote(title: 'A', body: 'keep');
      final controller = EditorController(vault: vault);
      addTearDown(controller.dispose);
      await controller.open(note);
      expect(controller.status, EditorStatus.clean);

      controller.updateBody(
        'keep!',
        selection: const TextSelection.collapsed(offset: 6),
      );
      expect(controller.status, EditorStatus.dirty);

      final undone = controller.undoCurrent();
      expect(undone, isNotNull);
      expect(undone!.text, 'keep');
      expect(controller.status, EditorStatus.dirty);
      await controller.flush();
      expect(controller.status, EditorStatus.saved);
      expect((await vault.readNote(note.path)).body, 'keep');
    });
  });

  group('undo_history unit (spec story 50)', () {
    test('setState appends a step', () {
      final h = UndoHistory();
      h.seed(UndoEntry('a', const TextSelection.collapsed(offset: 1), DateTime(2026, 9, 24)));
      h.setState(UndoEntry('ab', const TextSelection.collapsed(offset: 2), DateTime(2026, 9, 24, 10)));
      expect(h.canUndo, isTrue);
      expect(h.canRedo, isFalse);
      expect(h.undo()!.text, 'a');
      expect(h.redo()!.text, 'ab');
    });

    test('undo returns null at the baseline', () {
      final h = UndoHistory();
      h.seed(UndoEntry('a', const TextSelection.collapsed(offset: 1), DateTime.now()));
      expect(h.canUndo, isFalse);
      expect(h.undo(), isNull);
    });

    test('redo returns null at the tip', () {
      final h = UndoHistory();
      h.seed(UndoEntry('a', const TextSelection.collapsed(offset: 1), DateTime.now()));
      h.setState(UndoEntry('b', const TextSelection.collapsed(offset: 1), DateTime.now()));
      expect(h.canRedo, isFalse);
      expect(h.redo(), isNull);
    });

    test('edit after undo discards the redo branch', () {
      final h = UndoHistory();
      h.seed(UndoEntry('a', const TextSelection.collapsed(offset: 1), DateTime(2026, 9, 24)));
      h.setState(UndoEntry('b', const TextSelection.collapsed(offset: 1), DateTime(2026, 9, 24, 10)));
      h.setState(UndoEntry('c', const TextSelection.collapsed(offset: 1), DateTime(2026, 9, 24, 11)));
      h.undo(); // back to 'b'
      h.setState(UndoEntry('x', const TextSelection.collapsed(offset: 1), DateTime(2026, 9, 24, 12)));
      // 'c' is gone.
      expect(h.canRedo, isFalse);
      expect(h.redo(), isNull);
    });

    test('typing within the coalesce window merges into one undo step', () {
      final h = UndoHistory(); // default 800 ms window
      final base = DateTime(2026, 9, 24, 10, 0, 0);
      h.seed(UndoEntry('a', const TextSelection.collapsed(offset: 1), base));
      h.setState(UndoEntry('ab', const TextSelection.collapsed(offset: 2),
          base.add(const Duration(milliseconds: 100))));
      h.setState(UndoEntry('abc', const TextSelection.collapsed(offset: 3),
          base.add(const Duration(milliseconds: 200))));
      // The two keystrokes coalesced into a single step, so undo jumps
      // straight back to the seed.
      expect(h.canUndo, isTrue);
      expect(h.undo()!.text, 'a');
      expect(h.canUndo, isFalse);
      expect(h.redo()!.text, 'abc');
    });

    test('edits spaced beyond the coalesce window are separate steps', () {
      final h = UndoHistory(coalesceWindow: const Duration(milliseconds: 500));
      final base = DateTime(2026, 9, 24, 10, 0, 0);
      h.seed(UndoEntry('a', const TextSelection.collapsed(offset: 1), base));
      // 100 ms after the seed — within the window — merges.
      h.setState(UndoEntry('ab', const TextSelection.collapsed(offset: 2),
          base.add(const Duration(milliseconds: 100))));
      // The previous entry keeps the seed's timestamp, so the next edit
      // (also within 500 ms of the seed) still merges.
      h.setState(UndoEntry('abc', const TextSelection.collapsed(offset: 3),
          base.add(const Duration(milliseconds: 400))));
      // 900 ms after the seed — beyond the window — appends a new step.
      h.setState(UndoEntry('abcd', const TextSelection.collapsed(offset: 4),
          base.add(const Duration(milliseconds: 900))));
      // Two undo steps: one for the coalesced 'a'→'abc' run, one for the
      // 'abc'→'abcd' edit.
      expect(h.canUndo, isTrue);
      expect(h.undo()!.text, 'abc');
      expect(h.canUndo, isTrue);
      expect(h.undo()!.text, 'a');
      expect(h.canUndo, isFalse);
    });

    test('selection is restored alongside the text', () {
      final h = UndoHistory();
      final sel1 = const TextSelection.collapsed(offset: 2);
      final sel2 = const TextSelection.collapsed(offset: 3);
      h.seed(UndoEntry('ab', sel1, DateTime.now()));
      h.setState(UndoEntry('abc', sel2, DateTime.now()));
      final undone = h.undo()!;
      expect(undone.text, 'ab');
      expect(undone.selection, sel1);
    });

    test('respects maxDepth', () {
      final h = UndoHistory(maxDepth: 3);
      final base = DateTime(2026, 9, 24, 10, 0, 0);
      h.seed(UndoEntry('a', const TextSelection.collapsed(offset: 1), base));
      for (var i = 2; i <= 10; i++) {
        h.setState(UndoEntry('a' * i, const TextSelection.collapsed(offset: 1), base.add(Duration(seconds: i * 60))));
      }
      var steps = 0;
      while (h.canUndo) {
        h.undo();
        steps++;
      }
      expect(steps, 2);
      expect(h.undo() == null, isTrue);
    });

    test('clear resets the stack', () {
      final h = UndoHistory();
      h.seed(UndoEntry('a', const TextSelection.collapsed(offset: 1), DateTime.now()));
      h.setState(UndoEntry('b', const TextSelection.collapsed(offset: 1), DateTime.now()));
      h.clear();
      expect(h.isEmpty, isTrue);
      expect(h.canUndo, isFalse);
      expect(h.canRedo, isFalse);
    });
  });
}
