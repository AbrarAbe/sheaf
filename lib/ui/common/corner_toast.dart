import 'package:flutter/material.dart';

import '../../theme/quire_theme.dart';
import 'widgets/corner_toast_card.dart';
import 'widgets/toast_data.dart';

/// Quire-styled toast stack anchored to the window's bottom-right corner
/// (spec F8, option a). Replaces SnackBars: cards slide in from the right,
/// auto-dismiss after [CornerToast.duration], and stack upward.
///
/// Drop-in API:
/// ```dart
/// CornerToast.show(context, message: 'Deleted "X"',
///   actionLabel: 'Undo', onAction: () => ...);
/// ```
class CornerToast {
  CornerToast._();

  static final ValueNotifier<List<ToastData>> _queue = ValueNotifier(const []);
  static OverlayEntry? _entry;

  /// How long a card stays on screen before sliding out. Tests may shrink it;
  /// call [reset] between tests so timers never leak across suites.
  static Duration duration = const Duration(seconds: 4);

  static void show(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    IconData icon = Icons.check_circle_rounded,
  }) {
    _ensureOverlay(context);
    _queue.value = [..._queue.value, ToastData(UniqueKey(), message, actionLabel, onAction, icon)];
  }

  /// Drops every card immediately and tears the overlay down. Test suites
  /// must call this in tearDown so auto-dismiss timers cannot leak.
  static void reset() {
    _entry?.remove();
    _entry = null;
    _queue.value = const [];
  }

  static void remove(Key key) => _remove(key);

  static void _remove(Key key) {
    _queue.value = _queue.value.where((d) => d.key != key).toList();
  }

  static void _ensureOverlay(BuildContext context) {
    if (_entry != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _entry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<List<ToastData>>(
        valueListenable: _queue,
        builder: (_, cards, _) => Positioned(
          key: const Key('corner-toast-stack'),
          right: QuireSpace.m,
          bottom: QuireSpace.m,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [for (final data in cards) CornerToastCard(key: data.key, data: data)],
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
  }
}

