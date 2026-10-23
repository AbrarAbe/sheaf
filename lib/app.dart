import 'package:material_ui/material_ui.dart';

import 'logic/theme_setting_x.dart';
import 'logic/vault_controller.dart';
import 'logic/zoom.dart';
import 'theme/worlds.dart';
import 'ui/dialogs/welcome_screen.dart';
import 'ui/shell/shell.dart';

/// Root widget: resolves the persisted theme world + mode into ThemeData,
/// applies the app-wide view zoom, and gates between the welcome
/// (choose-vault) screen and the three-pane shell.
class SheafApp extends StatelessWidget {
  const SheafApp({super.key, required this.controller, this.homeOverride});

  final VaultController controller;

  /// Injectable test seam replacing the computed home widget.
  final Widget? homeOverride;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final world = worldById(controller.settings.themeWorld);
        return MaterialApp(
          title: 'Sheaf',
          debugShowCheckedModeBanner: false,
          theme: world.light(),
          darkTheme: world.dark(),
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
            // Bridge the modern `package:material_ui` theme to legacy packages
            // (flutter_context_menu, file_picker, desktop_drop, markdown_widget,
            // window_manager, ...) that still resolve `package:flutter/material`
            // Theme/Localizations. Required after the material_ui migration so
            // legacy subtrees inherit the app theme instead of falling back to
            // defaults.
            return MediaQuery(
              data: scaled,
              // ignore: deprecated_member_use
              child: MaterialUiCompatibilityBridge(child: child ?? const SizedBox.shrink()),
            );
          },
          home:
              homeOverride ??
              (controller.hasVault
                  ? Shell(controller: controller)
                  : WelcomeScreen(controller: controller)),
        );
      },
    );
  }
}
