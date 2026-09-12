import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sheaf/data/markdown_parser.dart';
import 'package:sheaf/models/note.dart';

/// A folder in the vault tree.
class FolderNode {
  const FolderNode({required this.name, required this.relPath, this.children = const []});

  final String name;

  /// Vault-relative path, e.g. `work/q3`.
  final String relPath;
  final List<FolderNode> children;
}

/// One item sitting in the vault trash.
class TrashEntry {
  const TrashEntry({
    required this.trashedName,
    required this.isFolder,
    required this.originalPath,
    required this.trashedAt,
  });

  /// File (or folder) name inside `.trash/`.
  final String trashedName;
  final bool isFolder;

  /// Where the item lived before deletion, vault-relative.
  final String originalPath;
  final DateTime trashedAt;
}

class _TrashIndex {
  _TrashIndex(this.items);

  final List<TrashEntry> items;
}

/// All filesystem access for the note vault.
///
/// The vault is an ordinary directory of markdown files; everything this class
/// writes could be opened in any text editor. Paths handed in and returned are
/// vault-relative with POSIX separators. Dot-directories (`.trash`,
/// user-hidden folders) never appear in listings, and path arguments may not
/// escape the vault root.
class VaultRepository {
  VaultRepository({required Directory root}) : root = _absolute(root);

  static const trashDirName = '.trash';
  static const attachmentsDirName = 'attachments';
  static const metaDirName = '.sheaf';
  static const _indexFileName = 'index.json';
  static const _metaFileName = 'meta.json';

  /// The vault root as given (made absolute).
  final Directory root;

  Directory get _trash => Directory(p.join(root.path, trashDirName));
  File get _indexFile => File(p.join(_trash.path, _indexFileName));
  Directory get _metaDir => Directory(p.join(root.path, metaDirName));
  File get _metaFile => File(p.join(_metaDir.path, _metaFileName));

  // ---------- notes ----------

  Future<Note> createNote({required String title, String? body, String? folder}) async {
    final relFolder = _normalizeFolder(folder);
    if (relFolder != null && relFolder.isNotEmpty) {
      await createFolder(relFolder);
    }
    final base = slugify(title);
    final relPath = await _uniqueNotePath(
      relFolder == null || relFolder.isEmpty ? '' : '$relFolder/',
      base,
    );
    final file = fileOf(relPath);
    await file.create(recursive: true);
    if (body != null && body.isNotEmpty) await file.writeAsString(body);
    return _noteFrom(relPath, file);
  }

  /// Every markdown note in the vault, excluding dot-directories.
  /// Returned newest-first by file modification time (spec story 13).
  Future<List<Note>> listNotes() async {
    final notes = <Note>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final rel = _relOf(entity.path);
      if (rel == null || !rel.endsWith('.md')) continue;
      notes.add(await _noteFrom(rel, entity));
    }
    notes.sort((a, b) {
      final am = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bm = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final cmp = bm.compareTo(am);
      if (cmp != 0) return cmp;
      return b.path.compareTo(a.path);
    });
    return notes;
  }

  Future<Note> readNote(String relPath) async {
    final file = fileOf(relPath);
    return _noteFrom(_normalizeRel(relPath), file);
  }

  Future<void> writeNote(String relPath, String body) async {
    final file = fileOf(relPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(body);
  }

  /// Renames a note by moving its file; returns the new vault-relative path.
  Future<String> renameNote(String relPath, String newTitle) async {
    final oldFile = fileOf(relPath);
    final dir = p.dirname(oldFile.path);
    final base = slugify(newTitle);
    var candidate = p.join(dir, '$base.md');
    var n = 2;
    while (candidate != oldFile.path && File(candidate).existsSync()) {
      candidate = p.join(dir, '$base-${n++}.md');
    }
    await oldFile.rename(candidate);
    final newRel = _relOf(candidate)!;

    // A pinned note keeps its pin under the new path.
    final pins = await pinnedPaths();
    if (pins.remove(_normalizeRel(relPath))) {
      pins.add(newRel);
      await _savePins(pins);
    }
    return newRel;
  }

  Future<void> trashNote(String relPath) async {
    await _trashItem(fileOf(relPath).path);
    // A deleted note carries no pin into the trash (spec story 13).
    await setPinned(relPath, false);
  }

  /// Permanently deletes a note file without sending it to trash.
  Future<void> deleteNote(String relPath) async {
    final file = fileOf(relPath);
    if (file.existsSync()) await file.delete();
    await setPinned(relPath, false);
  }

  /// Restores a trashed item to where it was before deletion.
  /// [trashedName] is a top-level item name inside `.trash/`.
  Future<void> restore(String trashedName) async {
    final index = await _loadIndex();
    TrashEntry? entry;
    for (final e in index.items) {
      if (e.trashedName == trashedName) {
        entry = e;
        break;
      }
    }
    if (entry == null) throw StateError('No trash entry for $trashedName');

    final source = p.join(_trash.path, trashedName);
    final destination = p.join(root.path, entry.originalPath);
    await Directory(p.dirname(destination)).create(recursive: true);

    if (entry.isFolder) {
      await Directory(source).rename(destination);
    } else {
      await File(source).rename(destination);
    }
    await _saveIndex(_TrashIndex(index.items.where((e) => !identical(e, entry)).toList()));
  }

  Future<List<TrashEntry>> listTrash() => _loadIndex().then((i) => i.items);

  /// Permanently removes a trashed item and forgets its index entry.
  Future<void> deleteForever(String trashedName) async {
    final index = await _loadIndex();
    TrashEntry? entry;
    for (final e in index.items) {
      if (e.trashedName == trashedName) {
        entry = e;
        break;
      }
    }
    if (entry == null) throw StateError('No trash entry for $trashedName');

    final source = p.join(_trash.path, trashedName);
    final entity = FileSystemEntity.isDirectorySync(source) ? Directory(source) : File(source);
    await entity.delete(recursive: true);

    index.items.removeWhere((e) => identical(e, entry));
    await _saveIndex(index);
  }

  // ---------- folders ----------

  Future<void> createFolder(String relPath) async {
    await Directory(p.join(root.path, _normalizeRel(relPath))).create(recursive: true);
  }

  Future<void> renameFolder(String relPath, String newName) async {
    final normalized = _normalizeRel(relPath);
    final dir = Directory(p.join(root.path, normalized));
    final parent = p.dirname(dir.path);
    await dir.rename(p.join(parent, slugify(newName)));
  }

  Future<void> deleteFolder(String relPath) =>
      _trashItem(Directory(p.join(root.path, _normalizeRel(relPath))).path);

  /// Immediate children folders of [folder] ('' = root), sorted by name.
  Future<List<FolderNode>> folderTree() async {
    final nodes = <FolderNode>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      nodes.add(await _buildNode(entity, name));
    }
    nodes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return nodes;
  }

  Future<FolderNode> _buildNode(Directory dir, String name) async {
    final children = <FolderNode>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final childName = p.basename(entity.path);
      if (childName.startsWith('.')) continue;
      children.add(await _buildNode(entity, childName));
    }
    children.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final rel = _relOf(dir.path)!;
    return FolderNode(name: name, relPath: rel, children: children);
  }

  // ---------- attachments ----------

  Directory get attachmentsDir => Directory(p.join(root.path, attachmentsDirName));

  /// Copies [source] into `<vault>/attachments/`, deduping names.
  /// Returns the vault-relative path of the copy.
  Future<String> importAttachment(File source) async {
    await attachmentsDir.create(recursive: true);
    final ext = p.extension(source.path);
    final base = slugify(p.basenameWithoutExtension(source.path));
    var candidate = '$base$ext';
    var n = 2;
    while (fileOf('attachments/$candidate').existsSync()) {
      candidate = '$base-${n++}$ext';
    }
    final target = fileOf('attachments/$candidate');
    await source.copy(target.path);
    return 'attachments/$candidate';
  }

  // ---------- helpers ----------

  /// Resolves a vault-relative path to an absolute [File], refusing traversal.
  File fileOf(String relPath) => File(p.join(root.path, _normalizeRel(relPath)));

  static Directory _absolute(Directory d) => Directory(d.absolute.path);

  String _normalizeRel(String relPath) {
    if (p.isAbsolute(relPath)) {
      throw ArgumentError.value(relPath, 'relPath', 'must be vault-relative');
    }
    final normalized = p.normalize(relPath);
    if (normalized == '..' || normalized.startsWith('../')) {
      throw ArgumentError.value(relPath, 'relPath', 'escapes the vault');
    }
    return normalized;
  }

  String? _normalizeFolder(String? folder) {
    if (folder == null || folder.isEmpty) return null;
    final normalized = _normalizeRel(folder);
    return normalized == '.' ? '' : normalized;
  }

  /// Vault-relative path of an absolute path, or null when outside the vault
  /// or inside a dot-directory.
  String? _relOf(String absolutePath) {
    final rel = p.relative(absolutePath, from: root.path);
    if (rel == '.' || rel.startsWith('..') || p.isAbsolute(rel)) return null;
    for (final part in p.split(rel)) {
      if (part.startsWith('.')) return null;
    }
    return rel;
  }

  Future<String> _uniqueNotePath(String folderPrefix, String base) async {
    var candidate = '$folderPrefix$base.md';
    var n = 2;
    while (fileOf(candidate).existsSync()) {
      candidate = '$folderPrefix$base-${n++}.md';
    }
    return candidate;
  }

  Future<Note> _noteFrom(String relPath, File file) async {
    final body = await file.readAsString();
    final stat = await file.stat();
    return Note(
      path: relPath,
      title: extractTitle(body, p.basename(relPath)),
      body: body,
      tags: extractTags(body),
      updatedAt: stat.modified,
    );
  }

  Future<void> _trashItem(String absoluteSourcePath) async {
    await _trash.create(recursive: true);
    final index = await _loadIndex();

    final itemName = p.basename(absoluteSourcePath);
    final taken = {
      ...index.items.map((e) => e.trashedName),
      ..._trash.listSync().map((e) => p.basename(e.path)),
    };
    var trashedName = itemName;
    var n = 2;
    while (taken.contains(trashedName)) {
      final ext = p.extension(itemName);
      trashedName = '${p.basenameWithoutExtension(itemName)}-${n++}$ext';
    }

    final entity = FileSystemEntity.isDirectorySync(absoluteSourcePath)
        ? Directory(absoluteSourcePath)
        : File(absoluteSourcePath);
    await entity.rename(p.join(_trash.path, trashedName));

    index.items.add(
      TrashEntry(
        trashedName: trashedName,
        isFolder: entity is Directory,
        originalPath: _relOf(absoluteSourcePath)!,
        trashedAt: DateTime.now(),
      ),
    );
    await _saveIndex(index);
  }

  Future<_TrashIndex> _loadIndex() async {
    try {
      final raw = await _indexFile.readAsString();
      final json = jsonDecode(raw) as Map<String, Object?>;
      final items = [
        for (final item in (json['items'] as List? ?? []))
          _trashEntryFromJson(item as Map<String, Object?>),
      ];
      return _TrashIndex(items);
    } on FileSystemException {
      return _TrashIndex([]);
    } on FormatException {
      return _TrashIndex([]);
    } on TypeError {
      return _TrashIndex([]);
    }
  }

  Future<void> _saveIndex(_TrashIndex index) async {
    await _trash.create(recursive: true);
    await _indexFile.writeAsString(
      jsonEncode({
        'items': [
          for (final e in index.items)
            {
              'trashedName': e.trashedName,
              'isFolder': e.isFolder,
              'originalPath': e.originalPath,
              'trashedAt': e.trashedAt.toIso8601String(),
            },
        ],
      }),
    );
  }

  // ---------- pins (spec story 13) ----------

  /// Vault-relative paths of pinned notes, from `<vault>/.sheaf/meta.json`.
  /// A missing or corrupt file recovers to an empty set — pins are a
  /// convenience, never a reason to refuse the vault.
  Future<Set<String>> pinnedPaths() async {
    try {
      final raw = await _metaFile.readAsString();
      final json = jsonDecode(raw) as Map<String, Object?>;
      return {
        for (final item in json['pinned'] as List? ?? [])
          if (item is String) _normalizeRel(item),
      };
    } on FileSystemException {
      return {};
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  /// Adds or removes [relPath] from the pin set. No-op when already in state.
  Future<void> setPinned(String relPath, bool pinned) async {
    final rel = _normalizeRel(relPath);
    final pins = await pinnedPaths();
    final changed = pinned ? pins.add(rel) : pins.remove(rel);
    if (!changed) return;
    await _savePins(pins);
  }

  Future<void> _savePins(Set<String> pins) async {
    await _metaDir.create(recursive: true);
    await _metaFile.writeAsString(jsonEncode({'pinned': pins.toList()..sort()}));
  }

  static TrashEntry _trashEntryFromJson(Map<String, Object?> json) => TrashEntry(
    trashedName: json['trashedName'] as String,
    isFolder: json['isFolder'] as bool? ?? false,
    originalPath: json['originalPath'] as String,
    trashedAt:
        DateTime.tryParse(json['trashedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Turns any title into a safe file-name stem.
String slugify(String title) {
  var s = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.length > 120) s = s.substring(0, 120).trim();
  s = s.replaceAll(RegExp(r'^\.+|\.+$'), '');
  return s.isEmpty ? 'untitled' : s;
}
