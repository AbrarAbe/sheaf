import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sheaf/ui/common/widgets/loading_overlay.dart';

void main() {
  // `showLoadingOverlay` routes trash/delete/folder-delete/note-create. While a
  // wrapped future is in flight the pointer must read as busy (wait cursor),
  // not just over the centred spinner card but across the whole overlay.
  testWidgets('loading overlay shows a wait cursor while in flight', (tester) async {
    // Never completes, so the overlay stays up for the assertions below. The
    // pumpWidget teardown drops the tree (and overlay) at test end.
    final never = Completer<int>().future;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showLoadingOverlay<int>(context, never),
                child: const Text('start'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('start'));
    await tester.pump();

    // The busy cursor is carried by a MouseRegion in the overlay entry.
    final region = find.byWidgetPredicate(
      (w) => w is MouseRegion && w.cursor == SystemMouseCursors.wait,
    );
    expect(region, findsOneWidget);

    // The spinner card is still rendered alongside it.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
