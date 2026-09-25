import 'package:flutter/material.dart';

/// A small floating "back to top" button that fades in when the scroll
/// offset crosses [threshold] and fades out otherwise. Spec story 54 —
/// Task 6: overlay in the preview's bottom-right corner, `arrow_up_rounded`
/// on the theme's primaryContainer, 200ms fade, `animateTo(0, 300ms, easeOut)`
/// on tap.
class GoToTopFab extends StatefulWidget {
  const GoToTopFab({required this.scrollController, super.key, this.threshold = 50});

  /// Scroll controller to watch and animate on tap.
  final ScrollController scrollController;

  /// The offset at which the FAB fades in (px). Below this, hidden.
  final double threshold;

  @override
  State<GoToTopFab> createState() => _GoToTopFabState();
}

class _GoToTopFabState extends State<GoToTopFab> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..value = widget.scrollController.offset > widget.threshold ? 1 : 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _fade.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = widget.scrollController.offset > widget.threshold;
    final isShown = _fade.value > 0.5;
    if (show == isShown) return;
    if (show) {
      _fade.forward();
    } else {
      _fade.reverse();
    }
  }

  Future<void> _goToTop() async {
    if (!widget.scrollController.hasClients) return;
    await widget.scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: theme.colorScheme.primaryContainer,
            elevation: 4,
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _goToTop,
              child: const SizedBox(width: 48, height: 48, child: Icon(Icons.arrow_upward_rounded)),
            ),
          ),
        ),
      ),
    );
  }
}
