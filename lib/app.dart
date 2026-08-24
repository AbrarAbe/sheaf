import 'package:flutter/material.dart';

import 'logic/theme_setting_x.dart';
import 'logic/vault_controller.dart';
import 'logic/zoom.dart';
import 'theme/quire_theme.dart';
import 'ui/dialogs/welcome_screen.dart';
import 'ui/shell/shell.dart';

/// Root widget: wires Quire themes to the persisted [ThemeSetting] and gates
/// between the welcome (choose-vault) screen and the three-pane shell.
class SheafApp extends StatelessWidget {
  const SheafApp({super.key, required this.controller, this.homeOverride});

  final VaultController controller;

  /// Injectable test seam replacing the computed home widget.
  final Widget? homeOverride;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        title: 'Sheaf',
        debugShowCheckedModeBanner: false,
        theme: buildQuireLight(),
        darkTheme: buildQuireDark(),
        // Theme switches never animate (theming.md).
        themeAnimationDuration: Duration.zero,
        themeMode: toThemeMode(controller.settings.theme),
        builder: (context, child) {
          // App-wide view zoom (spec story 11): scale every text surface
          // through one inherited scaler. Fixed-dp icons/layout stay constant.
          final media = MediaQuery.of(context);
          final scaled = media.copyWith(
            textScaler: TextScaler.linear(clampZoom(controller.settings.zoomFactor)),
          );
          return MediaQuery(data: scaled, child: child ?? const SizedBox.shrink());
        },
        home:
            homeOverride ??
            (controller.hasVault
                ? Shell(controller: controller)
                : WelcomeScreen(controller: controller)),
      ),
    );
  }
}
