import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'data/settings_repository.dart';
import 'data/vault_repository.dart';
import 'logic/vault_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only needed so F11 can drive the native window; we keep the
  // compositor-drawn title bar and never touch window chrome options.
  await windowManager.ensureInitialized();

  final configDir = await getApplicationSupportDirectory();
  final controller = VaultController(
    settings: SettingsRepository(file: File('${configDir.path}/settings.json')),
    vaultFactory: (path) => VaultRepository(root: Directory(path)),
  );
  await controller.initialize();
  await _loadUserFont(controller);

  runApp(SheafApp(controller: controller));
}

/// Registers the user's chosen font file under its display name so editor
/// styles can reference it as a plain fontFamily (story 16). A missing or
/// unloadable file falls back silently to the bundled stack.
Future<void> _loadUserFont(VaultController controller) async {
  final path = controller.settings.fontPath;
  final family = controller.settings.fontFamily;
  if (path == null || family == null) return;

  final file = File(path);
  if (!file.existsSync()) return;

  try {
    final bytes = await file.readAsBytes();
    final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  } catch (_) {
    // Font stays unregistered; styles referencing it fall back.
  }
}
