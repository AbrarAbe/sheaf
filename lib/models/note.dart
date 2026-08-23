import 'package:flutter/foundation.dart';

/// A single markdown note in the vault.
///
/// [path] is vault-relative with POSIX separators (`folder/note.md`) so it is
/// stable across platforms and serializes cleanly.
@immutable
class Note {
  const Note({
    required this.path,
    required this.title,
    required this.body,
    this.tags = const [],
    this.updatedAt,
  });

  final String path;
  final String title;
  final String body;

  /// Inline `#tags` found in [body], without the leading hash.
  final List<String> tags;

  /// File modification time, when known.
  final DateTime? updatedAt;

  /// File name including extension, e.g. `note.md`.
  String get fileName => path.split('/').last;

  Note copyWith({String? title, String? body, List<String>? tags, Object? updatedAt = _sentinel}) {
    return Note(
      path: path,
      title: title ?? this.title,
      body: body ?? this.body,
      tags: tags ?? this.tags,
      updatedAt: identical(updatedAt, _sentinel) ? this.updatedAt : updatedAt as DateTime?,
    );
  }

  static const _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.path == path &&
      other.title == title &&
      other.body == body &&
      listEquals(other.tags, tags);

  @override
  int get hashCode => Object.hash(path, title, body, Object.hashAll(tags));
}
