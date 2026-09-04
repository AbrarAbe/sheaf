import 'package:flutter/material.dart';

import '../../logic/vault_controller.dart';
import '../../logic/zoom.dart';
import '../../models/settings.dart';
import '../../models/shortcut_settings.dart';
import '../../theme/quire_theme.dart';
import '../../theme/worlds.dart';
import 'welcome_screen.dart';
import 'widgets/section_label.dart';
import 'widgets/shortcut_row.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;
    final dialogWidth = isWide ? 760.0 : 380.0;
    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: dialogWidth,
        height: isWide ? 480 : null,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final theme = Theme.of(context);
            final pathStyle = TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            );

            final appearanceVault = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Appearance'),
                const SizedBox(height: QuireSpace.xs),
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
                          key: const Key('zoom-reset'),
                          onPressed: () => controller.setZoom(1.0),
                          child: const Text('Reset'),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: QuireSpace.s),
                SwitchListTile(
                  key: const Key('window-controls-switch'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Show window controls', style: theme.textTheme.bodySmall),
                  value: controller.settings.showWindowControls,
                  onChanged: (value) => controller.setShowWindowControls(value),
                ),
                const Divider(height: QuireSpace.xl),
                const SectionLabel('Vault'),
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

            final shortcutsContent = Builder(
              builder: (context) {
                final overrides = controller.settings.shortcutOverrides;
                final visible = ShortcutAction.values.where((a) => a != ShortcutAction.continueList).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final action in visible)
                      ShortcutRow(
                        action: action,
                        overrides: overrides,
                        controller: controller,
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('reset-all-shortcuts'),
                        onPressed: overrides.isEmpty ? null : () => controller.resetAllShortcuts(),
                        child: const Text('Reset all'),
                      ),
                    ),
                  ],
                );
              },
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(child: appearanceVault),
                  ),
                  const VerticalDivider(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('Keyboard Shortcuts'),
                        const SizedBox(height: QuireSpace.xs),
                        Expanded(
                          child: SingleChildScrollView(child: shortcutsContent),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  appearanceVault,
                  const Divider(height: QuireSpace.xl),
                  const SectionLabel('Keyboard Shortcuts'),
                  const SizedBox(height: QuireSpace.xs),
                  shortcutsContent,
                ],
              ),
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

