import 'package:flutter/foundation.dart';

import '../../models/settings.dart';

WindowTier tierForWidth(double width) {
  if (width >= 1120) return WindowTier.expanded;
  if (width >= 720) return WindowTier.full;
  return WindowTier.stack;
}

/// Sidebar/list widths with their clamps, plus per-tier sidebar visibility
/// (task 10). The shell listens to this to re-layout; visibility changes are
/// echoed through [onVisibilityChanged] so the controller can persist them.
class PaneWidths extends ChangeNotifier {
  double _sidebar = 240; // spec default
  double _list = 340; // spec default

  bool _expandedSidebar = true;
  bool _fullSidebar = false;
  bool _stackSidebar = false;

  void Function(WindowTier tier, bool visible)? onVisibilityChanged;

  static const sidebarMin = 200.0;
  static const sidebarMax = 320.0;
  static const listMin = 300.0;
  static const listMax = 420.0;

  double get sidebar => _sidebar;
  set sidebar(double value) {
    final clamped = value.clamp(sidebarMin, sidebarMax);
    if (clamped == _sidebar) return;
    _sidebar = clamped;
    notifyListeners();
  }

  double get list => _list;
  set list(double value) {
    final clamped = value.clamp(listMin, listMax);
    if (clamped == _list) return;
    _list = clamped;
    notifyListeners();
  }

  bool isSidebarVisible(WindowTier tier) => switch (tier) {
    WindowTier.expanded => _expandedSidebar,
    WindowTier.full => _fullSidebar,
    WindowTier.stack => _stackSidebar,
  };

  void setSidebarVisible(WindowTier tier, bool visible) {
    if (isSidebarVisible(tier) == visible) return;
    switch (tier) {
      case WindowTier.expanded:
        _expandedSidebar = visible;
      case WindowTier.full:
        _fullSidebar = visible;
      case WindowTier.stack:
        _stackSidebar = visible;
    }
    onVisibilityChanged?.call(tier, visible);
    notifyListeners();
  }

  void toggleSidebarFor(WindowTier tier) => setSidebarVisible(tier, !isSidebarVisible(tier));

  /// Seeds state from persisted settings without firing change callbacks.
  void restoreVisibility({bool? expanded, bool? full, bool? stack}) {
    if (expanded != null) _expandedSidebar = expanded;
    if (full != null) _fullSidebar = full;
    if (stack != null) _stackSidebar = stack;
    notifyListeners();
  }

  /// Restores previously persisted pane widths.
  void restore({double? sidebar, double? list}) {
    if (sidebar != null) _sidebar = sidebar.clamp(sidebarMin, sidebarMax);
    if (list != null) _list = list.clamp(listMin, listMax);
    notifyListeners();
  }
}
