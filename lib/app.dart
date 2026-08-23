import 'package:flutter/material.dart';

import 'logic/theme_setting_x.dart';
import 'logic/vault_controller.dart';
import 'theme/quire_theme.dart';
import 'ui/shell/shell.dart';
import 'ui/dialogs/welcome_screen.dart';

/// Root widget: wires Quire themes to the persisted [ThemeSetting] and gates
/// between the welcome (choose-vault) screen and the three-pane shell.
class TakerApp extends StatelessWidget {
  const TakerApp({super.key, required this.controller});

  final VaultController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        title: 'Taker',
        debugShowCheckedModeBanner: false,
        theme: buildQuireLight(),
        darkTheme: buildQuireDark(),
        // Theme switches never animate (theming.md).
        themeAnimationDuration: Duration.zero,
        themeMode: toThemeMode(controller.settings.theme),
        home: controller.hasVault
            ? Shell(controller: controller)
            : WelcomeScreen(controller: controller),
      ),
    );
  }
}
