import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/data/settings_repository.dart';
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/logic/vault_controller.dart';
import 'package:sheaf/logic/zoom.dart';
import 'package:sheaf/models/settings.dart';
import 'package:sheaf/ui/common/corner_toast.dart';
import 'package:sheaf/ui/editor/editor_pane.dart';
import 'package:sheaf/ui/shell/pane_widths.dart';
import 'package:sheaf/ui/shell/shell.dart';
import 'package:sheaf/ui/shell/shortcuts.dart';
import 'package:sheaf/ui/sidebar/sidebar.dart';

void main() {
  // The shell paints Google Fonts; offline/flaky DNS turns their async fetch
  // failures into zone errors that fail whichever test is active. Swallow
  // exactly those — anything else still propagates.
  runZonedGuarded(_registerTests, (error, stack) {
    if (!stack.toString().contains('google_fonts')) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
    }
  });
}

void _registerTests() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sheaf_shortcut_test');
  });

  tearDown(() async {
    // Deletion flows spawn corner toasts; drop their timers before the
    // next test's FakeAsync zone can see them.
    CornerToast.reset();
    await tempDir.delete(recursive: true);
  });

  Future<(VaultController, PaneWidths)> pumpShell(
    WidgetTester tester, {
    Future<bool> Function()? isOsFullscreen,
    Future<void> Function(bool)? setOsFullscreen,
  }) async {
    final controller = VaultController(
      settings: SettingsRepository(file: File('${tempDir.path}/settings.json')),
      vaultFactory: (path) => VaultRepository(root: Directory(path)),
    );
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    await tester.runAsync(() => controller.openVault('${tempDir.path}/vault'));

    final widths = PaneWidths();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Shell(
          controller: controller,
          paneWidths: widths,
          isOsFullscreen: isOsFullscreen,
          setOsFullscreen: setOsFullscreen,
        ),
      ),
    );
    await tester.pump();
    return (controller, widths);
  }

  testWidgets('Ctrl+Shift+L cycles System to Light and persists', (tester) async {
    final (controller, _) = await pumpShell(tester);
    expect(controller.settings.theme, ThemeSetting.system);

    // Invoke through the Actions layer — key-to-intent matching is Flutter's
    // job; here we verify our wiring and persistence.
    final ctx = tester.element(find.byKey(const Key('pane-editor')));
    Actions.invoke(ctx, const CycleThemeIntent());
    await tester.pump();

    expect(controller.settings.theme, ThemeSetting.light);

    // Disk persistence of the setting is covered by
    // settings_repository/vault_controller unit tests.
  });

  testWidgets('Ctrl+backslash toggles the current tier sidebar visibility', (tester) async {
    final (controller, widths) = await pumpShell(tester);
    expect(widths.isSidebarVisible(WindowTier.expanded), isTrue);
    expect(find.byType(Sidebar), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.backslash);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(widths.isSidebarVisible(WindowTier.expanded), isFalse);
    expect(find.byType(Sidebar), findsNothing);
    expect(controller.settings.sidebarExpanded, isFalse, reason: 'persists per tier');
  });

  testWidgets('zoom intents step and reset the persisted factor', (tester) async {
    final (controller, _) = await pumpShell(tester);
    final ctx = tester.element(find.byKey(const Key('pane-editor')));

    Actions.invoke(ctx, const ZoomInIntent());
    await tester.pump();
    expect(controller.settings.zoomFactor, 1.1);

    Actions.invoke(ctx, const ZoomInIntent());
    await tester.pump();
    expect(controller.settings.zoomFactor, 1.2);

    Actions.invoke(ctx, const ZoomOutIntent());
    await tester.pump();
    expect(controller.settings.zoomFactor, 1.1);

    Actions.invoke(ctx, const ZoomResetIntent());
    await tester.pump();
    expect(controller.settings.zoomFactor, 1.0);
  });

  testWidgets('zoom respects its bounds through the shortcuts', (tester) async {
    final (controller, _) = await pumpShell(tester);
    final ctx = tester.element(find.byKey(const Key('pane-editor')));

    for (var i = 0; i < 30; i++) {
      await tester.runAsync(() async {});
      Actions.invoke(ctx, const ZoomInIntent());
      await tester.pump();
    }
    expect(controller.settings.zoomFactor, kZoomMax);
  });

  testWidgets('Ctrl+Shift+M cycles the editor mode and persists it', (tester) async {
    final (controller, _) = await pumpShell(tester);
    final ctx = tester.element(find.byKey(const Key('pane-editor')));
    expect(controller.settings.editorMode, EditorMode.normal);

    Actions.invoke(ctx, const CycleEditorModeIntent());
    await tester.pump();
    expect(controller.settings.editorMode, EditorMode.markdown);

    Actions.invoke(ctx, const CycleEditorModeIntent());
    await tester.pump();
    expect(controller.settings.editorMode, EditorMode.preview);
  });

  testWidgets('note intents walk visible notes and wrap at the ends', (tester) async {
    final (controller, _) = await pumpShell(tester);
    await tester.runAsync(() => controller.createNote(title: 'Alpha'));
    await tester.runAsync(() => controller.createNote(title: 'Beta'));
    await tester.runAsync(() => controller.createNote(title: 'Gamma'));
    await tester.pump();
    // List renders newest-first: Gamma, Beta, Alpha.

    final ctx = tester.element(find.byKey(const Key('pane-editor')));
    String? titles() => controller.selectedNote?.title;

    Actions.invoke(ctx, const CycleNoteIntent(forward: true)); // nothing → first
    await tester.pump();
    expect(titles(), 'Gamma');

    Actions.invoke(ctx, const CycleNoteIntent(forward: true));
    await tester.pump();
    expect(titles(), 'Beta');

    Actions.invoke(ctx, const CycleNoteIntent(forward: false)); // back to top
    await tester.pump();
    expect(titles(), 'Gamma');

    Actions.invoke(ctx, const CycleNoteIntent(forward: false)); // wraps to last
    await tester.pump();
    expect(titles(), 'Alpha');
  });

  testWidgets('Del while an editor holds focus edits text, not the note (F7)', (tester) async {
    final (controller, _) = await pumpShell(tester);
    final note = await tester.runAsync(() => controller.createNote(title: 'Keep', body: 'abc'));
    controller.selectNote(note!);
    await tester.pump();

    // Focus the body field with fresh text; caret sits at the end.
    await tester.enterText(find.byKey(const Key('editor-body')), 'abcd');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    expect(controller.notes.length, 1, reason: 'the note must survive');
    expect(controller.selectedNote?.title, 'Keep');
  });

  testWidgets('Del outside editors deletes the selected note (F7)', (tester) async {
    final (controller, _) = await pumpShell(tester);
    final note = await tester.runAsync(() => controller.createNote(title: 'Gone'));
    controller.selectNote(note!);
    await tester.pump();

    // No editable holds focus here — the shell-root focus wins.
    await tester.runAsync(() async {
      final ctx = tester.element(find.byKey(const Key('pane-editor')));
      Actions.invoke(ctx, const DeleteNoteIntent());
      // The action's awaited disk IO must progress in real time.
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();

    expect(controller.selectedNote, isNull);
    expect(controller.notes, isEmpty);
  });

  group('task 12 — focus mode & fullscreen', () {
    testWidgets('F10 collapses to an editor-only surface and restores', (tester) async {
      final (controller, _) = await pumpShell(tester);
      final note = await tester.runAsync(() => controller.createNote(title: 'Deep work'));
      controller.selectNote(note!);
      await tester.pump();
      expect(find.byKey(const Key('pane-list')), findsOneWidget);

      final ctx = tester.element(find.byKey(const Key('pane-editor')));
      Actions.invoke(ctx, const ToggleFocusModeIntent());
      await tester.pump();

      expect(find.byKey(const Key('pane-list')), findsNothing);
      expect(find.byType(Sidebar), findsNothing);
      expect(find.byType(EditorPane), findsOneWidget);
      expect(find.text('Deep work'), findsOneWidget);

      // The rebuild replaces elements — resolve a fresh context to restore.
      final restoredCtx = tester.element(find.byKey(const Key('pane-editor')));
      Actions.invoke(restoredCtx, const ToggleFocusModeIntent());
      await tester.pump();
      expect(find.byKey(const Key('pane-list')), findsOneWidget);
    });

    testWidgets('focus toggle button mirrors and drives the mode', (tester) async {
      await pumpShell(tester);

      await tester.tap(find.byKey(const Key('focus-toggle')));
      await tester.pump();
      expect(find.byKey(const Key('pane-list')), findsNothing);

      await tester.tap(find.byKey(const Key('focus-toggle')));
      await tester.pump();
      expect(find.byKey(const Key('pane-list')), findsOneWidget);
    });

    testWidgets('F11 drives the injected fullscreen seam both ways', (tester) async {
      var full = false;
      final calls = <bool>[];
      final (_, _) = await pumpShell(
        tester,
        isOsFullscreen: () async => full,
        setOsFullscreen: (v) async {
          calls.add(v);
          full = v;
        },
      );

      final ctx = tester.element(find.byKey(const Key('pane-editor')));
      Actions.invoke(ctx, const ToggleFullscreenIntent());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      Actions.invoke(ctx, const ToggleFullscreenIntent());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      expect(calls, [true, false]);
    });
  });
}
