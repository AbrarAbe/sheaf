import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taker/data/vault_repository.dart';
import 'package:taker/logic/editor_controller.dart';

void main() {
  late Directory tempDir;
  late VaultRepository vault;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('taker_editor_test');
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
}
