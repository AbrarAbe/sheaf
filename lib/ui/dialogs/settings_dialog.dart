import 'package:flutter/material.dart';

import '../../logic/vault_controller.dart';
import '../../logic/zoom.dart';
import '../../models/settings.dart';
import '../../theme/quire_theme.dart';
import '../../theme/worlds.dart';
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
        // New appearance controls outgrew a fixed-height dialog.
        child: SingleChildScrollView(
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
                  const SizedBox(height: QuireSpace.xs),
                  // Theme world (spec story 16): curated color sets.
                  Wrap(
                    spacing: QuireSpace.s,
                    runSpacing: QuireSpace.xs,
                    children: [
                      for (final world in themeWorlds)
                        ChoiceChip(
                          key: Key('world-${world.id}'),
                          label: Text(world.label),
                          selected: controller.settings.themeWorld == world.id,
                          onSelected: (_) => controller.setThemeWorld(world.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: QuireSpace.s),
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
                  const SizedBox(height: QuireSpace.s),
                  // Type size (story 16): editor body base in px.
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final size = controller.settings.editorFontSize;
                      return Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text('Type size', style: theme.textTheme.bodySmall),
                          ),
                          Expanded(
                            child: Slider(
                              key: const Key('type-size-slider'),
                              value: size,
                              min: 12,
                              max: 24,
                              divisions: 12,
                              label: '${size.round()} px',
                              onChanged: controller.setEditorFontSize,
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text(
                              '${size.round()} px',
                              textAlign: TextAlign.end,
                              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  // Zoom stepper (story 11/16): mirrors Ctrl+= / Ctrl+-.
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final percent = (controller.settings.zoomFactor * 100).round();
                      return Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text('Zoom', style: theme.textTheme.bodySmall),
                          ),
                          IconButton(
                            key: const Key('zoom-out'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => controller.setZoom(
                              stepZoom(controller.settings.zoomFactor, up: false),
                            ),
                            icon: const Icon(Icons.remove_circle_outline, size: 18),
                          ),
                          SizedBox(
                            width: 52,
                            child: Text(
                              '$percent%',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                          IconButton(
                            key: const Key('zoom-in'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => controller.setZoom(
                              stepZoom(controller.settings.zoomFactor, up: true),
                            ),
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                          ),
                          TextButton(
                            onPressed: () => controller.setZoom(1.0),
                            child: const Text('Reset'),
                          ),
                        ],
                      );
                    },
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
