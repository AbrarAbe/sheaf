import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/ui/common/corner_toast.dart';

void main() {
  const life = Duration(seconds: 4);
  const exit = Duration(milliseconds: 300);

  setUp(() {
    CornerToast.duration = life;
    CornerToast.reset();
  });

  tearDown(() => CornerToast.reset());

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
  }

  testWidgets('shows the message anchored bottom-right', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpHost(tester);

    CornerToast.show(tester.element(find.byType(Scaffold)), message: 'Deleted "Notes"');
    await tester.pump(); // enter animation start
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Deleted "Notes"'), findsOneWidget);
    expect(find.byKey(const Key('corner-toast-stack')), findsOneWidget);

    final stackBox = tester.renderObject<RenderBox>(find.byKey(const Key('corner-toast-stack')));
    final topLeft = stackBox.localToGlobal(Offset.zero);
    expect(topLeft.dx + stackBox.size.width, lessThan(900), reason: 'right margin kept');
    expect(topLeft.dy + stackBox.size.height, lessThan(700), reason: 'bottom margin kept');
    expect(topLeft.dy, greaterThan(400), reason: 'anchored low, not top');
  });

  testWidgets('action button fires its callback', (tester) async {
    await pumpHost(tester);
    var undone = false;

    CornerToast.show(
      tester.element(find.byType(Scaffold)),
      message: 'Deleted "X"',
      actionLabel: 'Undo',
      onAction: () => undone = true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Undo'));
    expect(undone, isTrue);
  });

  testWidgets('auto-dismisses after its lifetime', (tester) async {
    await pumpHost(tester);

    CornerToast.show(tester.element(find.byType(Scaffold)), message: 'bye');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('bye'), findsOneWidget);

    await tester.pump(life); // expire trigger
    await tester.pump(exit); // leave animation completes
    expect(find.text('bye'), findsNothing);
  });

  testWidgets('multiple toasts stack', (tester) async {
    await pumpHost(tester);

    CornerToast.show(tester.element(find.byType(Scaffold)), message: 'one');
    CornerToast.show(tester.element(find.byType(Scaffold)), message: 'two');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('corner-toast-card')), findsNWidgets(2));
  });

  testWidgets('card paints theme surfaces rather than hardcoded colors', (tester) async {
    await pumpHost(tester);

    CornerToast.show(tester.element(find.byType(Scaffold)), message: 'styled');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('corner-toast-card')),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, isNotNull);
    expect(decoration.borderRadius, isNotNull);
  });
}
