import 'package:flutter/material.dart';

import '../../logic/vault_controller.dart';
import '../../models/settings.dart';
import '../../theme/quire_theme.dart';
import 'welcome_screen.dart';

/// App settings: theme selection and vault location.
///
/// [pickFolder] is injectable for tests; production opens the native chooser.
Future<void> showSettingsDialog(
  BuildContext context,
  VaultController controller, {
  Future<String?> Function()? pickFolder,
}) {
  return showDialog(
    context: context,
    builder: (_) => _SettingsDialog(
      controller: controller,
      pickFolder: pickFolder ?? WelcomeScreen.defaultPickFolder,
    ),
  );
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog({required this.controller, required this.pickFolder});

  final VaultController controller;
  final Future<String?> Function() pickFolder;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 380,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final theme = Theme.of(context);
            final pathStyle = TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('Appearance'),
                RadioGroup<ThemeSetting>(
                  groupValue: controller.settings.theme,
                  onChanged: (value) {
                    if (value != null) controller.setTheme(value);
                  },
                  child: Column(
                    children: [
                      for (final setting in ThemeSetting.values)
                        RadioListTile<ThemeSetting>(
                          dense: true,
                          title: Text(switch (setting) {
                            ThemeSetting.system => 'System',
                            ThemeSetting.light => 'Light',
                            ThemeSetting.dark => 'Dark',
                          }),
                          value: setting,
                        ),
                    ],
                  ),
                ),
                const Divider(height: QuireSpace.xl),
                const _SectionLabel('Vault'),
                const SizedBox(height: QuireSpace.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        controller.vaultPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: pathStyle,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await pickFolder();
                        if (picked != null) await controller.openVault(picked);
                      },
                      child: const Text('Change vault…'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: QuireSpace.xs),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
