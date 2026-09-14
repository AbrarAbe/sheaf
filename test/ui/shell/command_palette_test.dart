import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/models/note.dart';
import 'package:sheaf/ui/shell/command_palette.dart';
import 'package:sheaf/ui/shell/shell.dart';

import '../../helpers/spy_vault_controller.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sheaf_palette_test');
  });

  tearDown(() async => tempDir.delete(recursive: true));

  Note note(String title, {DateTime? at, String body = ''}) =>
      Note(path: '$title.md', title: title, body: body, updatedAt: at);

  /// Pumps past the open transition WITHOUT pumpAndSettle — the focused
  /// query field's cursor blink never settles.
  Future<void> openPump(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<SpyVaultController> pumpHost(WidgetTester tester, {List<Note> notes = const []}) async {
    final controller = SpyVaultController('${tempDir.path}/settings.json')..fakeNotes = notes;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showCommandPalette(context, controller),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await openPump(tester);
    return controller;
  }

  double rowTop(WidgetTester tester, Note n) => tester.getTopLeft(find.text(n.title)).dy;

  testWidgets('empty query lists notes newest-first — row one is last edited', (tester) async {
    final a = note('Alpha', at: DateTime(2026, 8, 20));
    final b = note('Beta', at: DateTime(2026, 8, 25));
    final c = note('Gamma', at: DateTime(2026, 8, 22));
    await pumpHost(tester, notes: [a, b, c]);

    // Beta (newest) sits above Gamma, which sits above Alpha.
    expect(rowTop(tester, b), lessThan(rowTop(tester, c)));
    expect(rowTop(tester, c), lessThan(rowTop(tester, a)));
  });

  testWidgets('typing narrows the results', (tester) async {
    await pumpHost(
      tester,
      notes: [
        note('Shopping list', at: DateTime(2026, 8, 21)),
        note('Ideas', at: DateTime(2026, 8, 22)),
      ],
    );

    await tester.enterText(find.byKey(const Key('palette-field')), 'shop');
    await tester.pump();

    expect(find.text('Shopping list'), findsOneWidget);
    expect(find.text('Ideas'), findsNothing);
    expect(find.text('No matching notes.'), findsNothing);
  });

  testWidgets('no matches shows an empty hint', (tester) async {
    await pumpHost(tester, notes: [note('Only', at: DateTime(2026, 8, 21))]);

    await tester.enterText(find.byKey(const Key('palette-field')), 'zzz');
    await tester.pump();

    expect(find.text('No matching notes.'), findsOneWidget);
  });

  testWidgets('arrow down moves the highlight; Enter opens that note', (tester) async {
    final first = note('First', at: DateTime(2026, 8, 25));
    final second = note('Second', at: DateTime(2026, 8, 24));
    final controller = await pumpHost(tester, notes: [first, second]);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await openPump(tester);

    expect(controller.selectedNotePath, second.path);
    expect(find.byKey(const Key('palette-dialog')), findsNothing);
  });

  testWidgets('enter with the default highlight opens the first row', (tester) async {
    final first = note('First', at: DateTime(2026, 8, 25));
    final controller = await pumpHost(tester, notes: [first]);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await openPump(tester);

    expect(controller.selectedNotePath, first.path);
  });

  testWidgets('typing instantly highlights the first result', (tester) async {
    final a = note('Alpha', at: DateTime(2026, 8, 25));
    final b = note('Beta', at: DateTime(2026, 8, 24));
    await pumpHost(tester, notes: [a, b]);

    // Default: first row selected.
    bool firstSelected() {
      final ctx = tester.element(find.text('Alpha'));
      final wanted = Theme.of(ctx).colorScheme.secondaryContainer;
      return tester
          .widgetList<Container>(
            find.ancestor(of: find.text('Alpha'), matching: find.byType(Container)),
          )
          .where((c) => c.decoration is BoxDecoration)
          .any((c) => (c.decoration! as BoxDecoration).color == wanted);
    }

    expect(firstSelected(), isTrue);

    // Type to narrow — first result picks up highlight immediately.
    await tester.enterText(find.byKey(const Key('palette-field')), 'Bet');
    await tester.pump();

    bool betaSelected() {
      final ctx = tester.element(find.text('Beta'));
      final wanted = Theme.of(ctx).colorScheme.secondaryContainer;
      return tester
          .widgetList<Container>(
            find.ancestor(of: find.text('Beta'), matching: find.byType(Container)),
          )
          .where((c) => c.decoration is BoxDecoration)
          .any((c) => (c.decoration! as BoxDecoration).color == wanted);
    }

    expect(betaSelected(), isTrue);
  });

  testWidgets('arrow down at last item does not wrap around', (tester) async {
    final first = note('First', at: DateTime(2026, 8, 25));
    final second = note('Second', at: DateTime(2026, 8, 24));
    await pumpHost(tester, notes: [first, second]);

    // First row selected by default.
    bool firstSel() {
      final ctx = tester.element(find.text('First'));
      final wanted = Theme.of(ctx).colorScheme.secondaryContainer;
      return tester
          .widgetList<Container>(
            find.ancestor(of: find.text('First'), matching: find.byType(Container)),
          )
          .where((c) => c.decoration is BoxDecoration)
          .any((c) => (c.decoration! as BoxDecoration).color == wanted);
    }

    bool secondSel() {
      final ctx = tester.element(find.text('Second'));
      final wanted = Theme.of(ctx).colorScheme.secondaryContainer;
      return tester
          .widgetList<Container>(
            find.ancestor(of: find.text('Second'), matching: find.byType(Container)),
          )
          .where((c) => c.decoration is BoxDecoration)
          .any((c) => (c.decoration! as BoxDecoration).color == wanted);
    }

    // Arrow down once to second.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(firstSel(), isFalse);
    expect(secondSel(), isTrue);

    // Arrow down again — should stay at second (no wrap).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(firstSel(), isFalse);
    expect(secondSel(), isTrue);
  });

  testWidgets('escape closes without changing the selection', (tester) async {
    final controller = await pumpHost(tester, notes: [note('Solo', at: DateTime(2026, 8, 21))]);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await openPump(tester);

    expect(find.byKey(const Key('palette-dialog')), findsNothing);
    expect(controller.selectedNotePath, isNull);
  });

  testWidgets('Ctrl+K opens the palette from anywhere in the shell', (tester) async {
    final controller = SpyVaultController('${tempDir.path}/settings.json');
    addTearDown(controller.dispose);

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: Shell(controller: controller)));
    await tester.pumpAndSettle();

    // Even with an editor note focused the global binding must win; with no
    // note open this exercises the bare-shell path.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await openPump(tester);

    expect(find.byKey(const Key('palette-dialog')), findsOneWidget);
  });

  testWidgets('row highlight switches instantly after one pump', (tester) async {
    final first = note('First', at: DateTime(2026, 8, 25));
    final second = note('Second', at: DateTime(2026, 8, 24));
    await pumpHost(tester, notes: [first, second]);

    // Animated backgrounds cross-fade between rows while arrowing — reads as
    // background flicker. Highlight must be a plain paint.
    expect(
      find.descendant(
        of: find.byKey(const Key('palette-dialog')),
        matching: find.byType(AnimatedContainer),
      ),
      findsNothing,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(); // a single frame must land the new highlight

    bool highlighted(String title) {
      final context = tester.element(find.text(title));
      final wanted = Theme.of(context).colorScheme.secondaryContainer;
      return tester
          .widgetList<Container>(
            find.ancestor(of: find.text(title), matching: find.byType(Container)),
          )
          .where((c) => c.decoration is BoxDecoration)
          .any((c) => (c.decoration! as BoxDecoration).color == wanted);
    }

    expect(highlighted('Second'), isTrue);
    expect(highlighted('First'), isFalse);
  });

  testWidgets('header pill opens the palette on expanded tier', (tester) async {
    final controller = SpyVaultController('${tempDir.path}/settings.json');
    addTearDown(controller.dispose);

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: Shell(controller: controller)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('palette-pill')));
    await openPump(tester);

    expect(find.byKey(const Key('palette-dialog')), findsOneWidget);
  });

  testWidgets('stack tier hides the pill', (tester) async {
    final controller = SpyVaultController('${tempDir.path}/settings.json');
    addTearDown(controller.dispose);

    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: Shell(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('palette-pill')), findsNothing);
  });
}
