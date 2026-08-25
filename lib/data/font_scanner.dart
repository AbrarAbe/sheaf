import 'dart:io';

import 'package:path/path.dart' as p;

/// One discoverable font file: [name] is the human-facing label (file stem),
/// [path] the absolute location handed to FontLoader at startup.
class DiscoveredFont {
  const DiscoveredFont({required this.name, required this.path});

  final String name;
  final String path;
}

const _extensions = {'.ttf', '.otf', '.ttc'};

/// Standard Linux font locations scanned for the settings picker
/// (spec story 16 — user decision: standard dirs only, no file browser).
List<String> defaultFontRoots() {
  final home = Platform.environment['HOME'] ?? '';
  return [
    if (home.isNotEmpty) '$home/.fonts',
    if (home.isNotEmpty) '$home/.local/share/fonts',
    '/usr/share/fonts',
    '/usr/local/share/fonts',
  ];
}

/// Recursively scans [roots] for font files. Missing roots are skipped so a
/// headless machine or trimmed system never breaks the picker.
Future<List<DiscoveredFont>> scanFonts({List<String>? roots}) async {
  final searchIn = roots ?? defaultFontRoots();
  final found = <String, DiscoveredFont>{};

  for (final rootPath in searchIn) {
    final root = Directory(rootPath);
    if (!root.existsSync()) continue;

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!_extensions.contains(p.extension(entity.path).toLowerCase())) continue;
      final name = p.basenameWithoutExtension(entity.path);
      found.putIfAbsent(entity.path, () => DiscoveredFont(name: name, path: entity.path));
    }
  }

  final list = found.values.toList();
  list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
}
