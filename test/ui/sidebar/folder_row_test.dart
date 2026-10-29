import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sheaf/ui/sidebar/widgets/hover_row.dart';
import 'package:sheaf/ui/sidebar/widgets/text_prompt.dart';

void main() {
  testWidgets('long folder label ellipsizes inside a narrow row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: HoverRow(
                selected: false,
                onTap: () {},
                icon: Icons.folder_outlined,
                label: 'a-folder-name-that-is-much-too-long-to-fit',
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(
      find.descendant(of: find.byType(HoverRow), matching: find.byType(Text)),
    );
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.maxLines, 1);
  });

  testWidgets('textPrompt caps dialog width on a wide surface', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => textPrompt(
                context,
                // Both a long single-line initial value (the real rename
                // scenario) and a long title (the "New folder inside <long
                // folder>" scenario) used to blow the dialog out to full
                // width: AlertDialog wraps its content in IntrinsicWidth, so
                // an unconstrained TextField/title reported an unbounded
                // intrinsic width and ignored any wrapper cap.
                title: 'New folder inside a-very-long-folder-name-that-could-stretch-the-title',
                initial: 'e same Still the same Still the same Still the same Still the same Still the same Still the same Still the same Still the same Still the same Still the same Still the same',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    // The dialog surface is the card Material inside the AlertDialog. Without
    // the 400px cap on a 1200px surface it would stretch to fill the window;
    // the cap leaves a surface at most 400px wide that stays centered rather
    // than filling the screen.
    final surface = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byWidgetPredicate((w) => w is Material && w.type == MaterialType.card),
    );
    final surfaceRect = tester.getRect(surface);
    expect(surfaceRect.width, lessThanOrEqualTo(400));
    expect(surfaceRect.center.dx, closeTo(600, 1));
  });
}
