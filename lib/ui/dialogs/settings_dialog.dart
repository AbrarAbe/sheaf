import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/shortcut_serializer.dart';
import '../../logic/vault_controller.dart';
import '../../logic/zoom.dart';
import '../../models/settings.dart';
import '../../models/shortcut_settings.dart';
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
                const _SectionLabel('Appearance'),
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

            final shortcutsContent = Builder(
              builder: (context) {
                final overrides = controller.settings.shortcutOverrides;
                final visible = ShortcutAction.values.where((a) => a != ShortcutAction.continueList).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final action in visible)
                      _ShortcutRow(
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
                        const _SectionLabel('Keyboard Shortcuts'),
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
                  const _SectionLabel('Keyboard Shortcuts'),
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

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.action,
    required this.overrides,
    required this.controller,
  });

  final ShortcutAction action;
  final Map<String, String> overrides;
  final VaultController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverridden = overrides.containsKey(action.name);
    final activator = activatorFor(action, overrides);
    final label = serializeActivator(activator);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              action.label,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: isOverridden ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            key: Key('edit-${action.name}'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => _ShortcutRecorderDialog(action: action, controller: controller),
            ),
            child: const Text('Edit', style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            key: Key('reset-${action.name}'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: isOverridden ? () => controller.setShortcutOverride(action, null) : null,
            child: const Text('Reset', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRecorderDialog extends StatefulWidget {
  const _ShortcutRecorderDialog({required this.action, required this.controller});
  final ShortcutAction action;
  final VaultController controller;
  @override
  State<_ShortcutRecorderDialog> createState() => _ShortcutRecorderDialogState();
}

class _ShortcutRecorderDialogState extends State<_ShortcutRecorderDialog> {
  SingleActivator? _captured;
  String? _error;

  bool _isModifier(LogicalKeyboardKey key) => {
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.controlRight,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.shiftRight,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.altRight,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.metaRight,
      }.contains(key);

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (_isModifier(key)) return;
    final control = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    final activator = SingleActivator(key, control: control, shift: shift, alt: alt, meta: meta);
    final label = serializeActivator(activator);
    String? error;
    if (reservedFormattingLabels.contains(label)) {
      error = 'Reserved for formatting';
    } else if (const {'Ctrl+C', 'Ctrl+V', 'Ctrl+X'}.contains(label)) {
      error = 'Reserved system shortcut';
    } else {
      final overrides = widget.controller.settings.shortcutOverrides;
      for (final other in ShortcutAction.values) {
        if (other == widget.action) continue;
        if (other == ShortcutAction.continueList) continue;
        final otherAct = activatorFor(other, overrides);
        if (serializeActivator(otherAct) == label) {
          error = 'Already used by ${other.label}';
          break;
        }
      }
    }
    setState(() {
      _captured = activator;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentLabel = serializeActivator(activatorFor(widget.action, widget.controller.settings.shortcutOverrides));
    final capturedLabel = _captured == null ? 'Press new shortcut…' : serializeActivator(_captured!);
    return AlertDialog(
      title: Text('Edit ${widget.action.label}'),
      content: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          _handleKey(event);
          return KeyEventResult.handled;
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current: $currentLabel', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _error != null ? Colors.red : Colors.transparent),
              ),
              child: Text(capturedLabel, style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 8),
            const Text('Press keys, then Save. Single chord only.', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _captured == null || _error != null
              ? null
              : () async {
                  await widget.controller.setShortcutOverride(widget.action, _captured);
                  if (context.mounted) Navigator.of(context).pop();
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
