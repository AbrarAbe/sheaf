import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/data/settings_repository.dart';
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/logic/vault_controller.dart';
import 'package:sheaf/models/settings.dart';
import 'package:sheaf/ui/shell/drag_divider.dart';
import 'package:sheaf/ui/shell/pane_widths.dart';
import 'package:sheaf/ui/shell/shell.dart';
import 'package:sheaf/ui/shell/window_controls.dart';
import 'package:sheaf/ui/sidebar/sidebar.dart';

import '../helpers/test_vault.dart';

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
      expect(w.isSidebarVisible(WindowTier.expanded), isTrue);
      expect(w.isSidebarVisible(WindowTier.full), isFalse);
      expect(w.isSidebarVisible(WindowTier.stack), isFalse);
    });

    test('per-tier visibility toggles independently and fires callback', () {
      final w = PaneWidths();
      final seen = <(WindowTier, bool)>[];
      w.onVisibilityChanged = (tier, visible) => seen.add((tier, visible));

      w.toggleSidebarFor(WindowTier.full);
      expect(w.isSidebarVisible(WindowTier.full), isTrue);
      expect(seen.single, (WindowTier.full, true));

      w.toggleSidebarFor(WindowTier.expanded); // hide expanded; full untouched
      expect(w.isSidebarVisible(WindowTier.expanded), isFalse);
      expect(w.isSidebarVisible(WindowTier.full), isTrue);
      expect(seen.length, 2);
    });

    test('restoreVisibility seeds without firing callbacks', () {
      final w = PaneWidths();
      var fired = false;
      w.onVisibilityChanged = (_, _) => fired = true;
      w.restoreVisibility(expanded: false, full: true, stack: true);
      expect(fired, isFalse);
      expect(w.isSidebarVisible(WindowTier.expanded), isFalse);
      expect(w.isSidebarVisible(WindowTier.full), isTrue);
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
      tempDir = await Directory.systemTemp.createTemp('sheaf_shell_test');
    });

    tearDown(() async => tempDir.delete(recursive: true));

    Future<void> pumpShell(
      WidgetTester tester, {
      required double width,
      required double height,
      PaneWidths? paneWidths,
      VaultController? controller,
      bool showWindowControls = true,
      WindowControls? windowControls,
    }) async {
      if (!showWindowControls) {
        // Real disk IO must leave the FakeAsync zone (test-harness rule).
        await tester.runAsync(
          () =>
              File('${tempDir.path}/settings.json')
                  .writeAsString(jsonEncode({'showWindowControls': false})),
        );
      }
      final ctrl =
          controller ??
          VaultController(
            settings: SettingsRepository(file: File('${tempDir.path}/settings.json')),
            vaultFactory: (path) => VaultRepository(root: Directory(path)),
          );
      await tester.runAsync(ctrl.initialize);
      addTearDown(ctrl.dispose);

      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, height)),
            child: Shell(
              controller: ctrl,
              paneWidths: paneWidths ?? PaneWidths(),
              windowControls: windowControls,
            ),
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

    testWidgets('full tier hides the sidebar by default; toggle reveals it', (tester) async {
      final controller = VaultController(
        settings: SettingsRepository(file: File('${tempDir.path}/settings.json')),
        vaultFactory: (path) => VaultRepository(root: Directory(path)),
      );
      await tester.runAsync(controller.initialize);
      await pumpShell(tester, width: 900, height: 700, controller: controller);

      expect(find.byType(Sidebar), findsNothing);
      expect(find.byKey(const Key('sidebar-toggle')), findsOneWidget);

      await tester.tap(find.byKey(const Key('sidebar-toggle')));
      await tester.pump();
      expect(find.byType(Sidebar), findsOneWidget);
      expect(controller.settings.sidebarFull, isTrue, reason: 'visibility persists');
    });

    testWidgets('stack tier opens the sidebar as an overlay drawer', (tester) async {
      final controller = VaultController(
        settings: SettingsRepository(file: File('${tempDir.path}/settings.json')),
        vaultFactory: (path) => VaultRepository(root: Directory(path)),
      );
      await tester.runAsync(controller.initialize);
      await pumpShell(tester, width: 600, height: 700, controller: controller);

      expect(find.byType(Sidebar), findsNothing);
      expect(find.byKey(const Key('pane-list')), findsOneWidget);

      await tester.tap(find.byKey(const Key('sidebar-toggle')));
      await tester.pump();
      expect(find.byType(Sidebar), findsOneWidget);
      expect(controller.settings.sidebarStack, isTrue);

      // Tapping the scrim (left of the 320dp drawer) closes it.
      await tester.tapAt(const Offset(140, 350));
      await tester.pump();
      expect(find.byType(Sidebar), findsNothing);
    });

    testWidgets('collapse toggle fully hides and restores the sidebar', (tester) async {
      final widths = PaneWidths();
      await pumpShell(tester, width: 1280, height: 800, paneWidths: widths);

      expect(find.byType(Sidebar), findsOneWidget);

      widths.toggleSidebarFor(WindowTier.expanded);
      await tester.pump();
      expect(find.byType(Sidebar), findsNothing);
      expect(find.byKey(const Key('rail')), findsNothing, reason: 'rail is retired');

      widths.toggleSidebarFor(WindowTier.expanded);
      await tester.pump();
      expect(find.byType(Sidebar), findsOneWidget);
    });

    testWidgets('drag dividers have a generous hit target (>= 12 dp wide)', (tester) async {
      await pumpShell(tester, width: 1280, height: 800);

      final dividers = find.byType(DragDivider);
      expect(dividers, findsNWidgets(2));

      for (final divider in dividers.evaluate()) {
        final box = divider.renderObject! as RenderBox;
        expect(box.size.width, greaterThanOrEqualTo(12), reason: 'divider hit target too narrow');
      }
    });

    testWidgets('selecting a note in the list opens it in the editor', (tester) async {
      final controller = (await tester.runAsync(
        () => TestVault.seeded(
          tempDir,
          seed: (vault) async {
            await vault.createNote(title: 'Wire me', body: 'body text');
          },
        ),
      ))!;
      addTearDown(controller.dispose);

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: Shell(controller: controller)));
      await tester.pump();

      await tester.tap(find.text('Wire me'));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Wire me'), findsOneWidget);
    });

    testWidgets('New note button creates and opens a note', (tester) async {
      final controller = (await tester.runAsync(
        () => TestVault.seeded(tempDir, seed: (vault) async {}),
      ))!;
      addTearDown(controller.dispose);

      // Create through real I/O up front; the factory below just hands it
      // back so the widget flow stays zone-safe.
      final created = (await tester.runAsync(() => controller.createNote(title: 'Untitled')))!;
      var calls = 0;

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Shell(
            controller: controller,
            onCreateNote: () async {
              calls++;
              return created;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New note'));
      await tester.pump();

      expect(calls, 1);
      expect(controller.selectedNotePath, 'Untitled.md');
      expect(find.widgetWithText(TextField, 'Untitled'), findsOneWidget);
    });

    testWidgets('traffic-light dots drive the injected window seam (F15)', (tester) async {
      final controls = RecordingControls();
      await pumpShell(tester, width: 1280, height: 800, windowControls: controls);

      await tester.tap(find.byKey(const Key('win-minimize')));
      await tester.tap(find.byKey(const Key('win-maximize')));
      await tester.tap(find.byKey(const Key('win-close')));
      await tester.pump();

      expect(controls.calls, ['minimize', 'maximize', 'close']);
    });

    testWidgets('window dots hide when the setting disables them (F15)', (tester) async {
      await pumpShell(tester, width: 1280, height: 800, showWindowControls: false);

      expect(find.byKey(const Key('win-minimize')), findsNothing);
      expect(find.byKey(const Key('win-maximize')), findsNothing);
      expect(find.byKey(const Key('win-close')), findsNothing);
    });
  });
}

/// Records chrome calls instead of touching the real window manager.
class RecordingControls implements WindowControls {
  final calls = <String>[];

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<void> toggleMaximize() async => calls.add('maximize');

  @override
  Future<void> close() async => calls.add('close');
}
