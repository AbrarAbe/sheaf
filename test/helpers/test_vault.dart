import 'dart:io';

import 'package:sheaf/data/settings_repository.dart';
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/logic/vault_controller.dart';

/// Shared helper for seeding a controller backed by a small real vault.
class TestVault {
  static Future<VaultController> seeded(
    Directory tempDir, {
    required Future<void> Function(VaultRepository vault) seed,
  }) async {
    final vaultDir = Directory('${tempDir.path}/vault');
    await vaultDir.create(recursive: true);
    final repo = VaultRepository(root: vaultDir);
    await seed(repo);

    final controller = VaultController(
      settings: SettingsRepository(file: File('${tempDir.path}/settings.json')),
      vaultFactory: (path) => VaultRepository(root: Directory(path)),
    );
    await controller.openVault(vaultDir.path);
    return controller;
  }
}
