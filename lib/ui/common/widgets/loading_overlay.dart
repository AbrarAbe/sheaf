import 'package:material_ui/material_ui.dart';

/// Shows a centred loading indicator that auto-closes when [future] completes.
///
/// The overlay is non-dismissible to prevent accidental double-delete. A
/// full-screen [MouseRegion] switches the pointer to a busy (wait) cursor for
/// the duration, so in-flight creates/deletes read as busy everywhere, not
/// just over the centred spinner card. Returns the result of [future].
Future<T> showLoadingOverlay<T>(BuildContext context, Future<T> future, {String? message}) {
  final overlay = OverlayEntry(
    builder: (_) => MouseRegion(
      cursor: SystemMouseCursors.wait,
      child: Center(
        child: Card(
          elevation: 2,
          // shape: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
    ),
  );

  final overlayState = Overlay.of(context, rootOverlay: true);
  overlayState.insert(overlay);

  return future.whenComplete(() {
    overlay.remove();
  });
}
