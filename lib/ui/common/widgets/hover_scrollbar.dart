import 'package:flutter/material.dart';

/// Wraps a scrollable so its scrollbar thumb shows a hand cursor on hover
/// and a grabbing cursor while the thumb is dragged.
///
/// The thumb's hover/drag *colour* is theme-owned — `ScrollbarThemeData`
/// resolves `thumbColor` against [WidgetState.hovered] and
/// [WidgetState.dragged] in `quire_theme.dart`. This widget supplies only
/// the cursor.
///
/// The cursor is applied by a translucent overlay laid over the thumb's
/// measured rect, not by a [MouseRegion] covering the whole child. That
/// distinction is load-bearing: Flutter takes the cursor from the first
/// non-deferring annotation in the hit-test path, and a descendant region —
/// the editor body's I-beam, for one — therefore outranks an ancestor's.
/// Sitting on top puts this overlay first.
///
/// Thumb geometry comes from the scrollable's own [ScrollMetrics], so the
/// cursor appears only where a thumb is actually painted, and only while the
/// content overflows.
class HoverScrollbar extends StatefulWidget {
  const HoverScrollbar({super.key, required this.child});

  /// Key on the thumb overlay, so tests can assert on its cursor.
  static const Key thumbKey = Key('hover-scrollbar-thumb');

  final Widget child;

  @override
  State<HoverScrollbar> createState() => _HoverScrollbarState();
}

class _HoverScrollbarState extends State<HoverScrollbar> {
  /// Close to Flutter's desktop scrollbar thickness.
  static const double _thumbThickness = 8;

  /// Slop around the thumb so the strip is forgiving to hit.
  static const double _slop = 4;

  /// Flutter clamps the thumb to a minimum length; mirror it so the overlay
  /// does not drift away from the painted thumb on long documents.
  static const double _minThumbLength = 24;

  bool _dragging = false;
  _Metrics? _metrics;
  _Metrics? _pending;
  bool _pendingScheduled = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final thumb = _thumbRect(constraints);
        return Stack(
          // Passthrough hands the child the same constraints it would have
          // received without the Stack, so wrapping is layout-neutral.
          fit: StackFit.passthrough,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _reportMetrics(notification.metrics);
                return false;
              },
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (notification) {
                  _reportMetrics(notification.metrics);
                  return false;
                },
                child: widget.child,
              ),
            ),
            if (thumb != null)
              Positioned.fromRect(
                rect: thumb,
                child: MouseRegion(
                  key: HoverScrollbar.thumbKey,
                  cursor: _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.click,
                  // Translucent so the overlay joins the hit path — and so
                  // wins the cursor — without swallowing the pointer the
                  // scrollbar underneath needs in order to drag the thumb.
                  hitTestBehavior: HitTestBehavior.translucent,
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) => _setDragging(true),
                    onPointerUp: (_) => _setDragging(false),
                    onPointerCancel: (_) => _setDragging(false),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _setDragging(bool value) {
    if (_dragging == value) return;
    setState(() => _dragging = value);
  }

  /// Records the newest metrics, rebuilding at most once per frame.
  ///
  /// Metrics notifications can be dispatched from
  /// `Scrollable.didChangeDependencies` — that is, during build — so the
  /// rebuild is deferred to keep `setState` out of that phase.
  void _reportMetrics(ScrollMetrics metrics) {
    if (!mounted) return;
    final next = _Metrics.of(metrics);
    if (next.sameAs(_metrics)) return;

    _pending = next;
    if (_pendingScheduled) return;
    _pendingScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingScheduled = false;
      if (!mounted) return;
      final pending = _pending;
      if (pending == null || pending.sameAs(_metrics)) return;
      setState(() => _metrics = pending);
    });
  }

  /// The thumb's rect inflated by [_slop], or null when there is no thumb to
  /// point at. Vertical only — every Sheaf scroll view scrolls vertically.
  Rect? _thumbRect(BoxConstraints constraints) {
    final metrics = _metrics;
    if (metrics == null) return null;

    final extent = metrics.max - metrics.min;
    final track = metrics.viewport;
    if (extent <= 0 || track <= 0 || !constraints.maxHeight.isFinite) return null;

    final minLength = _minThumbLength.clamp(0.0, track);
    final thumbLength = (track * track / (track + extent)).clamp(minLength, track);
    final progress = ((metrics.pixels - metrics.min) / extent).clamp(0.0, 1.0);

    final thumbRect = Rect.fromLTWH(
      constraints.maxWidth - _thumbThickness,
      progress * (track - thumbLength),
      _thumbThickness,
      thumbLength,
    );
    // Inflate right/top/bottom so the hit area is forgiving, but NOT left:
    // left-inflate would make the overlay cover text to the left of the
    // scrollbar, causing the hand cursor to appear while hovering words.
    return Rect.fromLTRB(
      thumbRect.left,
      thumbRect.top - _slop,
      thumbRect.right + _slop,
      thumbRect.bottom + _slop,
    );
  }
}

/// Snapshot of the [ScrollMetrics] numbers [HoverScrollbar] needs.
///
/// Copied rather than held: a live `ScrollPosition` nulls its fields on
/// dispose and would assert if they were read afterwards.
class _Metrics {
  const _Metrics({
    required this.pixels,
    required this.min,
    required this.max,
    required this.viewport,
  });

  factory _Metrics.of(ScrollMetrics metrics) => _Metrics(
    pixels: metrics.pixels,
    min: metrics.minScrollExtent,
    max: metrics.maxScrollExtent,
    viewport: metrics.viewportDimension,
  );

  final double pixels;
  final double min;
  final double max;
  final double viewport;

  bool sameAs(_Metrics? other) =>
      other != null &&
      other.pixels == pixels &&
      other.min == min &&
      other.max == max &&
      other.viewport == viewport;
}
