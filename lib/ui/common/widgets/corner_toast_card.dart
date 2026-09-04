import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/quire_theme.dart';
import '../corner_toast.dart';
import 'toast_data.dart';

/// One animated toast card (extracted from _CornerToastCard).
class CornerToastCard extends StatefulWidget {
  const CornerToastCard({super.key, required this.data});

  final ToastData data;

  @override
  State<CornerToastCard> createState() => CornerToastCardState();
}

class CornerToastCardState extends State<CornerToastCard> {
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
      if (mounted) CornerToast.remove(widget.data.key);
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
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          builder: (context, enter, child) =>
              Opacity(opacity: enter, child: child),
          child: _child(context, theme),
        ),
      ),
    );
  }

  Widget _child(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: QuireSpace.s),
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(QuireRadius.m),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
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
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
