import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taker/data/settings_repository.dart';
import 'package:taker/data/vault_repository.dart';
import 'package:taker/logic/vault_controller.dart';
import 'package:taker/ui/shell/pane_widths.dart';
import 'package:taker/ui/shell/shell.dart';
import 'package:taker/ui/sidebar/sidebar.dart';

void main() {
  group('tierForWidth', () {
    test('matches layout doc breakpoints', () {
      expect(tierForWidth(360), WindowTier.stack);
      expect(tierForWidth(719), WindowTier.stack);
      expect(tierForWidth(720), WindowTier.full);
      expect(tierForWidth(1119), WindowTier.full);
      expect(tierForWidth(1120), WindowTier.expanded);
    });
  });

  group('PaneWidths', () {
    test('defaults match the design spec', () {
      final w = PaneWidths();
      expect(w.sidebar, 240);
      expect(w.list, 340);
      expect(w.sidebarCollapsed, isFalse);
    });

    test('clamps drags to documented ranges', () {
      final w = PaneWidths()
        ..sidebar = 100
        ..list = 999;
      expect(w.sidebar, 200); // min 200
      expect(w.list, 420); // max 420
      w.sidebar = 500;
      expect(w.sidebar, 320); // max 320
      w.list = 100;
      expect(w.list, 300); // min 300
    });
  });

  group('shell widget', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('taker_shell_test');
    });

    tearDown(() async => tempDir.delete(recursive: true));

    Future<void> pumpShell(
      WidgetTester tester, {
      required double width,
      required double height,
      PaneWidths? paneWidths,
    }) async {
      final controller = VaultController(
        settings: SettingsRepository(file: File('${tempDir.path}/settings.json')),
        vaultFactory: (path) => VaultRepository(root: Directory(path)),
      );
      await tester.runAsync(controller.initialize);
      addTearDown(controller.dispose);

      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, height)),
            child: Shell(controller: controller, paneWidths: paneWidths ?? PaneWidths()),
          ),
        ),
      );
    }

    testWidgets('expanded shows sidebar + list + editor', (tester) async {
      await pumpShell(tester, width: 1280, height: 800);

      expect(find.byType(Sidebar), findsOneWidget);
      expect(find.byKey(const Key('pane-list')), findsOneWidget);
      expect(find.byKey(const Key('pane-editor')), findsOneWidget);
    });

    testWidgets('full tier swaps sidebar for a 64dp rail', (tester) async {
      await pumpShell(tester, width: 900, height: 700);

      expect(find.byType(Sidebar), findsNothing);
      expect(find.byKey(const Key('rail')), findsOneWidget);
    });

    testWidgets('stack tier hides the rail entirely', (tester) async {
      await pumpShell(tester, width: 600, height: 700);

      expect(find.byType(Sidebar), findsNothing);
      expect(find.byKey(const Key('rail')), findsNothing);
      expect(find.byKey(const Key('pane-list')), findsOneWidget);
    });

    testWidgets('collapse toggle swaps between sidebar and rail', (tester) async {
      final widths = PaneWidths();
      await pumpShell(tester, width: 1280, height: 800, paneWidths: widths);

      expect(find.byType(Sidebar), findsOneWidget);

      widths.toggleSidebar();
      await tester.pump();
      expect(find.byKey(const Key('rail')), findsOneWidget);

      widths.toggleSidebar();
      await tester.pump();
      expect(find.byType(Sidebar), findsOneWidget);
    });
  });
}
