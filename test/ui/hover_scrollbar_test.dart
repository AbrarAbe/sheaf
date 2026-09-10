import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/ui/common/widgets/hover_scrollbar.dart';

void main() {
  /// A fixed 200px-tall viewport over [itemCount] 40px rows: two rows fit,
  /// forty overflow.
  Future<void> pumpScrollbar(WidgetTester tester, {required int itemCount}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: HoverScrollbar(
                child: ListView.builder(
                  itemCount: itemCount,
                  itemBuilder: (context, i) => SizedBox(height: 40, child: Text('row $i')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Metrics arrive on a scroll notification; the overlay is rebuilt on the
    // following frame.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows no thumb overlay while the content fits', (tester) async {
    await pumpScrollbar(tester, itemCount: 2);
    expect(find.byKey(HoverScrollbar.thumbKey), findsNothing);
  });

  testWidgets('thumb overlay shows a hand cursor once content overflows', (tester) async {
    await pumpScrollbar(tester, itemCount: 40);

    final overlay = find.byKey(HoverScrollbar.thumbKey);
    expect(overlay, findsOneWidget);
    expect(tester.widget<MouseRegion>(overlay).cursor, SystemMouseCursors.click);
  });

  testWidgets('thumb overlay sits over the thumb, not over the content', (tester) async {
    await pumpScrollbar(tester, itemCount: 40);

    final overlay = find.byKey(HoverScrollbar.thumbKey);
    final overlayRect = tester.getRect(overlay);
    final listRect = tester.getRect(find.byType(ListView));

    // Right-hugging, white-box: thumb is 8px at the scrollable's right edge
    // with 4px slop on the right only (see HoverScrollbar). Any left-inflate
    // would widen the overlay and put the hand cursor over words.
    expect(overlayRect.left, listRect.right - 8);
    expect(overlayRect.width, 12);
  });

  testWidgets('thumb overlay follows the scroll position', (tester) async {
    await pumpScrollbar(tester, itemCount: 40);

    final overlay = find.byKey(HoverScrollbar.thumbKey);
    final initialTop = tester.getTopLeft(overlay).dy;

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    // Metrics arrive on a scroll notification; the overlay rebuilds on the
    // following frame (same cadence as the pump helper above).
    await tester.pump();
    await tester.pump();

    expect(tester.getTopLeft(overlay).dy, greaterThan(initialTop));
  });

  testWidgets('thumb overlay shows a grabbing cursor while dragged', (tester) async {
    await pumpScrollbar(tester, itemCount: 40);

    final overlay = find.byKey(HoverScrollbar.thumbKey);
    final gesture = await tester.startGesture(
      tester.getCenter(overlay),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(tester.widget<MouseRegion>(overlay).cursor, SystemMouseCursors.grabbing);

    await gesture.up();
    await tester.pump();
    expect(tester.widget<MouseRegion>(overlay).cursor, SystemMouseCursors.click);
  });
}
