import 'dart:io';

import 'package:flutter/material.dart';
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

  runApp(SheafApp(controller: controller));
}
