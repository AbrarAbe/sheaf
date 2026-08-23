import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/settings_repository.dart';
import 'data/vault_repository.dart';
import 'logic/vault_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final configDir = await getApplicationSupportDirectory();
  final controller = VaultController(
    settings: SettingsRepository(file: File('${configDir.path}/settings.json')),
    vaultFactory: (path) => VaultRepository(root: Directory(path)),
  );
  await controller.initialize();

  runApp(SheafApp(controller: controller));
}
