import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/quire_theme.dart';

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

  static final ValueNotifier<List<_ToastData>> _queue = ValueNotifier(const []);
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
    _queue.value = [..._queue.value, _ToastData(UniqueKey(), message, actionLabel, onAction, icon)];
  }

  /// Drops every card immediately and tears the overlay down. Test suites
  /// must call this in tearDown so auto-dismiss timers cannot leak.
  static void reset() {
    _entry?.remove();
    _entry = null;
    _queue.value = const [];
  }

  static void _remove(Key key) {
    _queue.value = _queue.value.where((d) => d.key != key).toList();
  }

  static void _ensureOverlay(BuildContext context) {
    if (_entry != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _entry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<List<_ToastData>>(
        valueListenable: _queue,
        builder: (_, cards, _) => Positioned(
          key: const Key('corner-toast-stack'),
          right: QuireSpace.m,
          bottom: QuireSpace.m,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [for (final data in cards) _CornerToastCard(key: data.key, data: data)],
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
  }
}

class _ToastData {
  const _ToastData(this.key, this.message, this.actionLabel, this.onAction, this.icon);

  final Key key;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;
}

/// One animated toast card (package-private; tests find it via key).
class _CornerToastCard extends StatefulWidget {
  const _CornerToastCard({super.key, required this.data});

  final _ToastData data;

  @override
  State<_CornerToastCard> createState() => _CornerToastCardState();
}

class _CornerToastCardState extends State<_CornerToastCard> {
  bool _leaving = false;
  Timer? _expireTimer;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    _expireTimer = Timer(CornerToast.duration, _beginExit);
  }

  void _beginExit() {
    if (!mounted) return;
    setState(() => _leaving = true);
    _exitTimer = Timer(const Duration(milliseconds: 260), () {
      if (mounted) CornerToast._remove(widget.data.key);
    });
  }

  void _handleAction() {
    widget.data.onAction?.call();
    _beginExit();
  }

  @override
  void dispose() {
    _expireTimer?.cancel();
    _exitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSlide(
      key: const Key('corner-toast-card'),
      offset: _leaving ? const Offset(0.4, 0) : Offset.zero,
      duration: const Duration(milliseconds: 220),
      curve: _leaving ? Curves.easeInCubic : Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _leaving ? 0 : 1,
        duration: const Duration(milliseconds: 220),
        // Enter animation: TweenAnimationBuilder runs once on mount without
        // needing a controller.
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          builder: (context, enter, child) => Opacity(opacity: enter, child: child),
          child: child(context, theme),
        ),
      ),
    );
  }

  Widget child(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: QuireSpace.s),
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(QuireRadius.m),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.data.icon, size: 17, color: theme.colorScheme.primary),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              widget.data.message,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                height: 18 / 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (widget.data.actionLabel != null)
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: theme.colorScheme.primary,
              ),
              onPressed: _handleAction,
              child: Text(
                widget.data.actionLabel!,
                style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
