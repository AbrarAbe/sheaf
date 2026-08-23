import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../logic/vault_controller.dart';
import '../../theme/quire_theme.dart';

/// First-run screen when no vault folder has been chosen yet.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.controller, this.pickFolder = defaultPickFolder});

  final VaultController controller;

  /// Injectable for tests; production opens the native folder dialog.
  final Future<String?> Function() pickFolder;

  static Future<String?> defaultPickFolder() =>
      FilePicker.getDirectoryPath(dialogTitle: 'Choose a vault folder');

  Future<void> _choose() async {
    final path = await pickFolder();
    if (path != null) await controller.openVault(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Taker', style: theme.textTheme.displaySmall),
            const SizedBox(height: QuireSpace.m),
            Text(
              'Pick a folder to keep your notes.',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: QuireSpace.xl),
            FilledButton(onPressed: _choose, child: const Text('Choose folder…')),
          ],
        ),
      ),
    );
  }
}
