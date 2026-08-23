import 'package:flutter/foundation.dart';

/// Pure functions for reading structure out of markdown note bodies.
///
/// All of these operate on strings so they are trivially unit-testable and
/// usable from both the data layer (indexing) and the UI layer (chips, preview).

final _fenceLine = RegExp(r'^\s{0,3}(```|~~~)');
final _inlineCode = RegExp('`[^`]*`');
final _heading1 = RegExp(r'^#\s+(.+)$');
final _tagToken = RegExp(r'#([A-Za-z_][A-Za-z0-9_/-]*)');
final _imageRef = RegExp(r'!\[([^\]]*)\]\(\s*(?:<([^>]*)>|([^)\s]+))(?:\s+"[^"]*")?\s*\)');

/// Removes fenced code blocks and inline code spans so tag/title scans do not
/// match example content.
@visibleForTesting
String stripCode(String body) {
  final out = StringBuffer();
  var inFence = false;
  for (final line in body.split('\n')) {
    if (_fenceLine.hasMatch(line)) {
      inFence = !inFence;
      continue;
    }
    if (!inFence) out.writeln(line);
  }
  return out.toString().replaceAll(_inlineCode, '');
}

/// The note title: first H1 outside code fences, else the file-name stem.
String extractTitle(String body, String fileName) {
  for (final line in stripCode(body).split('\n')) {
    final m = _heading1.firstMatch(line);
    if (m != null) return m.group(1)!.trim();
  }
  final dot = fileName.lastIndexOf('.');
  final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
  return stem;
}

/// Unique inline `#tags` in first-seen order.
///
/// A tag must start with a letter or underscore; the preceding character may
/// not be a word character, another hash, or a slash — this keeps URL
/// fragments (`page#anchor`) and C#-style text out. Tags may nest with `/`
/// like Obsidian's `#parent/child`.
List<String> extractTags(String body) {
  final tags = <String>[];
  final text = stripCode(body);
  for (final m in _tagToken.allMatches(text)) {
    final before = m.start == 0 ? ' ' : text[m.start - 1];
    if (RegExp(r'[A-Za-z0-9_/#]').hasMatch(before)) continue;
    var tag = m.group(1)!;
    while (tag.endsWith('-') || tag.endsWith('/')) {
      tag = tag.substring(0, tag.length - 1);
    }
    if (tag.isNotEmpty && !tags.contains(tag)) tags.add(tag);
  }
  return tags;
}

/// An embedded image reference with its optional display width.
@immutable
class ImageRef {
  const ImageRef({required this.alt, required this.path, this.width});

  final String alt;
  final String path;

  /// Display width in pixels from Obsidian `![alt|400]` syntax, if present.
  final int? width;

  @override
  bool operator ==(Object other) =>
      other is ImageRef && other.alt == alt && other.path == path && other.width == width;

  @override
  int get hashCode => Object.hash(alt, path, width);
}

List<ImageRef> extractImages(String body) {
  return [for (final m in _imageRef.allMatches(body)) _imageRefFrom(m)];
}

ImageRef _imageRefFrom(RegExpMatch m) {
  final rawAlt = m.group(1)!;
  final path = (m.group(2) ?? m.group(3))!;

  // Obsidian width syntax lives at the end of the alt text: `alt|400`.
  String alt = rawAlt;
  int? width;
  final pipe = rawAlt.lastIndexOf('|');
  if (pipe != -1 && pipe < rawAlt.length - 1) {
    final maybeWidth = int.tryParse(rawAlt.substring(pipe + 1).trim());
    if (maybeWidth != null && maybeWidth > 0) {
      alt = rawAlt.substring(0, pipe);
      width = maybeWidth;
    }
  }
  return ImageRef(alt: alt.trim(), path: path, width: width);
}
