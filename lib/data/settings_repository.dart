import 'dart:convert';
import 'dart:io';

import 'package:taker/models/settings.dart';

/// Persists [AppSettings] as a single JSON file.
///
/// Takes any [File] so production wires the platform config directory while
/// tests hand it a temp file. A missing or unreadable file yields defaults —
/// settings are a convenience, never a reason to refuse to start.
class SettingsRepository {
  SettingsRepository({required this._file});

  final File _file;

  Future<AppSettings> load() async {
    try {
      final raw = await _file.readAsString();
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on FormatException {
      return const AppSettings();
    } on TypeError {
      return const AppSettings();
    } on FileSystemException {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(const JsonEncoder.withIndent('  ').convert(settings.toJson()));
  }
}
