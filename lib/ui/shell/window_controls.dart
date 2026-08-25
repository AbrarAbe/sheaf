import 'package:window_manager/window_manager.dart';

/// Drives the native window for the header's traffic-light controls
/// (feedback F15). Injectable so widget tests record calls instead of
/// touching the real window manager.
abstract interface class WindowControls {
  Future<void> minimize();
  Future<void> toggleMaximize();
  Future<void> close();
}

/// Production implementation over window_manager. The compositor title bar
/// stays; these are in-app controls for setups that hide it.
class WindowManagerControls implements WindowControls {
  const WindowManagerControls();

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Future<void> close() => windowManager.close();
}
