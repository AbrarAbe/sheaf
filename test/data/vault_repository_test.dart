import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/data/vault_repository.dart';

void main() {
  late Directory tempDir;
  late VaultRepository vault;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sheaf_vault_test');
    vault = VaultRepository(root: tempDir);
  });

  tearDown(() async => tempDir.delete(recursive: true));

  group('notes', () {
    test('createNote writes a unique md file and returns its note', () async {
      final note = await vault.createNote(title: 'Meeting notes');
      expect(note.path, 'Meeting notes.md');
      expect(vault.fileOf(note.path).existsSync(), isTrue);

      final second = await vault.createNote(title: 'Meeting notes');
      expect(second.path, 'Meeting notes-2.md');
    });

    test('createNote creates missing parent folders', () async {
      final note = await vault.createNote(title: 'plan', folder: 'work/q3');
      expect(note.path, 'work/q3/plan.md');
      expect(vault.fileOf('work/q3/plan.md').existsSync(), isTrue);
    });

    test('listNotes parses titles and tags and skips dot dirs', () async {
      await vault.createNote(title: 'Tagged', body: '#real #parent/child\nbody text');
      await vault.writeNote('.trash/leftover.md', '# Should not appear');
      await vault.writeNote('scratch.txt', 'not a note');

      final notes = await vault.listNotes();
      final tagged = notes.singleWhere((n) => n.title == 'Tagged');
      expect(tagged.tags, ['real', 'parent/child']);
      expect(notes.where((n) => n.title == 'Should not appear'), isEmpty);
      expect(tagged.updatedAt, isNotNull);
    });

    test('writeNote round-trips body content', () async {
      final note = await vault.createNote(title: 'Draft');
      const body = '# Draft\n\nEdited **content** here.';
      await vault.writeNote(note.path, body);
      final reread = await vault.readNote(note.path);
      expect(reread.body, body);
      expect(reread.title, 'Draft');
    });

    test('readNote title is the filename stem (heading does not override)', () async {
      await vault.createNote(title: 'Stem', body: '# Real Title\n');
      final note = await vault.readNote('Stem.md');
      expect(note.title, 'Stem');
    });

    test('renameNote moves the file and keeps content', () async {
      final note = await vault.createNote(title: 'Old', body: '# Old\ncontent');
      final newPath = await vault.renameNote(note.path, 'New Name');

      expect(newPath, 'New Name.md');
      expect(vault.fileOf('Old.md').existsSync(), isFalse);
      expect((await vault.readNote(newPath)).body, contains('content'));
    });
  });

  group('trashNote', () {
    test('trash moves file to .trash and records origin', () async {
      final note = await vault.createNote(title: 'Doomed', folder: 'a/b');
      await vault.trashNote(note.path);

      expect(vault.fileOf('a/b/Doomed.md').existsSync(), isFalse);
      final trash = await vault.listTrash();
      expect(trash.single.originalPath, 'a/b/Doomed.md');
      expect(trash.single.isFolder, isFalse);
    });

    test('restoreNote returns the file to its original folder', () async {
      final note = await vault.createNote(title: 'Back', folder: 'keep');
      await vault.trashNote(note.path);
      final entry = (await vault.listTrash()).single;

      await vault.restore(entry.trashedName);

      expect(vault.fileOf('keep/Back.md').existsSync(), isTrue);
      expect(await vault.listTrash(), isEmpty);
    });

    test('deleting two same-named notes does not collide', () async {
      final first = await vault.createNote(title: 'Twin', folder: 'one');
      final second = await vault.createNote(title: 'Twin', folder: 'two');
      await vault.trashNote(first.path);
      await vault.trashNote(second.path);

      final entries = await vault.listTrash();
      expect(entries.map((e) => e.originalPath).toSet(), {'one/Twin.md', 'two/Twin.md'});
      expect(entries.map((e) => e.trashedName).toSet().length, 2);
    });

    test('deleteForever removes the file and its index entry', () async {
      final note = await vault.createNote(title: 'Goner');
      await vault.trashNote(note.path);
      final entry = (await vault.listTrash()).single;

      await vault.deleteForever(entry.trashedName);

      expect(File('${tempDir.path}/.trash/${entry.trashedName}').existsSync(), isFalse);
      expect(await vault.listTrash(), isEmpty);

      // Trashing another note afterwards must not resurrect stale entries.
      final other = await vault.createNote(title: 'Next');
      await vault.trashNote(other.path);
      expect((await vault.listTrash()).single.originalPath, 'Next.md');
    });
  });

  group('deleteNote (permanent)', () {
    test('permanently deletes the file without creating a trash entry', () async {
      final note = await vault.createNote(title: 'Goner');
      final path = note.path;

      await vault.deleteNote(path);

      expect(vault.fileOf(path).existsSync(), isFalse);
      expect(await vault.listTrash(), isEmpty);
    });

    test('drops the pin record on permanent delete', () async {
      final note = await vault.createNote(title: 'Pinned');
      await vault.setPinned(note.path, true);

      await vault.deleteNote(note.path);
      expect(await vault.pinnedPaths(), isEmpty);
    });
  });

  group('folders', () {
    test('folderTree lists nested folders only', () async {
      await vault.createFolder('work');
      await vault.createFolder('work/q3');
      await vault.createFolder('personal');
      await vault.createNote(title: 'loose');

      final tree = await vault.folderTree();
      final names = tree.map((f) => f.name).toSet();
      expect(names, {'work', 'personal'});
      final work = tree.singleWhere((f) => f.name == 'work');
      expect(work.children.single.name, 'q3');
      expect(work.children.single.relPath, 'work/q3');
    });

    test('renameFolder renames on disk including children', () async {
      await vault.createFolder('old/inner');
      await vault.renameFolder('old', 'renamed');
      expect(Directory('${tempDir.path}/renamed/inner').existsSync(), isTrue);
      expect(Directory('${tempDir.path}/old').existsSync(), isFalse);
    });

    test('deleteFolder trashes contents for restore', () async {
      await vault.createFolder('proj');
      await vault.createNote(title: 'Inside', folder: 'proj');

      await vault.deleteFolder('proj');

      expect(Directory('${tempDir.path}/proj').existsSync(), isFalse);
      expect(await vault.listNotes(), isEmpty);
      // The whole folder went to trash; restoring brings every note back.
      final entry = (await vault.listTrash()).single;
      expect(entry.isFolder, isTrue);
      expect(entry.originalPath, 'proj');
      await vault.restore(entry.trashedName);
      expect(vault.fileOf('proj/Inside.md').existsSync(), isTrue);
    });
  });

  group('attachments', () {
    test('importAttachment copies into attachments/ with dedupe', () async {
      final src = File('${tempDir.path}/_src/upload.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);

      final rel1 = await vault.importAttachment(src);
      final rel2 = await vault.importAttachment(src);

      expect(rel1, 'attachments/upload.png');
      expect(rel2, 'attachments/upload-2.png');
      expect(vault.fileOf(rel1).readAsBytesSync(), [1, 2, 3]);
    });
  });

  group('slugify', () {
    test('strips filesystem-hostile characters', () {
      expect(slugify('a/b: c*d?'), 'ab cd');
      expect(slugify('  trimmed  '), 'trimmed');
      expect(slugify(''), 'untitled');
    });
  });

  group('pins (.sheaf/meta.json, spec story 13)', () {
    test('pins and unpins a note, persisting across instances', () async {
      final note = await vault.createNote(title: 'Keep', folder: 'work');

      await vault.setPinned(note.path, true);
      expect(await vault.pinnedPaths(), {note.path});

      // A fresh repository over the same vault sees the pin.
      final other = VaultRepository(root: vault.root);
      expect(await other.pinnedPaths(), {note.path});

      await vault.setPinned(note.path, false);
      expect(await vault.pinnedPaths(), isEmpty);
    });

    test('pinning twice is idempotent', () async {
      final note = await vault.createNote(title: 'Twice');
      await vault.setPinned(note.path, true);
      await vault.setPinned(note.path, true);
      expect(await vault.pinnedPaths().then((s) => s.length), 1);
    });

    test('renaming a note moves its pin', () async {
      final note = await vault.createNote(title: 'Old Name');
      await vault.setPinned(note.path, true);

      final newPath = await vault.renameNote(note.path, 'New Name');
      expect(await vault.pinnedPaths(), {newPath});
    });

    test('deleting a note drops its pin record', () async {
      final note = await vault.createNote(title: 'Doomed');
      await vault.setPinned(note.path, true);

      await vault.deleteNote(note.path);
      expect(await vault.pinnedPaths(), isEmpty);
    });

    test('a corrupt meta file recovers to empty', () async {
      final note = await vault.createNote(title: 'C');
      final meta = File('${vault.root.path}/.sheaf/meta.json');
      await meta.parent.create(recursive: true);
      await meta.writeAsString('{not json');

      expect(await vault.pinnedPaths(), isEmpty);

      // And the vault still accepts new pins afterwards.
      await vault.setPinned(note.path, true);
      expect(await vault.pinnedPaths(), {note.path});
    });

    test('meta.json lives in .sheaf and never lists as a note', () async {
      await vault.createNote(title: 'Visible');
      final some = await vault.createNote(title: 'Some');
      await vault.setPinned(some.path, true);

      final names = (await vault.listNotes()).map((n) => n.fileName).toSet();
      expect(names.any((f) => f.contains('meta')), isFalse);
    });
  });
}
