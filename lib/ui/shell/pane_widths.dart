import 'package:flutter/foundation.dart';

/// Which window tier the shell renders, per layout-and-space.md.
enum WindowTier { expanded, full, stack }

WindowTier tierForWidth(double width) {
  if (width >= 1120) return WindowTier.expanded;
  if (width >= 720) return WindowTier.full;
  return WindowTier.stack;
}

/// Sidebar and note-list widths with their documented clamps, plus the
/// collapsed flag. The shell listens to this to re-layout.
class PaneWidths extends ChangeNotifier {
  double _sidebar = 240; // spec default
  double _list = 340; // spec default
  bool _sidebarCollapsed = false;

  static const sidebarMin = 200.0;
  static const sidebarMax = 320.0;
  static const listMin = 300.0;
  static const listMax = 420.0;
  static const railWidth = 64.0;

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

  bool get sidebarCollapsed => _sidebarCollapsed;

  void toggleSidebar() {
    _sidebarCollapsed = !_sidebarCollapsed;
    notifyListeners();
  }

  /// Restores a previously persisted state.
  void restore({double? sidebar, double? list, bool? sidebarCollapsed}) {
    if (sidebar != null) _sidebar = sidebar.clamp(sidebarMin, sidebarMax);
    if (list != null) _list = list.clamp(listMin, listMax);
    if (sidebarCollapsed != null) _sidebarCollapsed = sidebarCollapsed;
    notifyListeners();
  }
}
