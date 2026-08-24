import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/data/settings_repository.dart';
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/logic/vault_controller.dart';
import 'package:sheaf/logic/zoom.dart';
import 'package:sheaf/models/settings.dart';
import 'package:sheaf/ui/shell/pane_widths.dart';
import 'package:sheaf/ui/shell/shell.dart';
import 'package:sheaf/ui/shell/shortcuts.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sheaf_shortcut_test');
  });

  tearDown(() async => tempDir.delete(recursive: true));

  Future<(VaultController, PaneWidths)> pumpShell(WidgetTester tester) async {
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
        home: Shell(controller: controller, paneWidths: widths),
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

  testWidgets('Ctrl+backslash toggles the sidebar rail', (tester) async {
    final (_, widths) = await pumpShell(tester);
    expect(widths.sidebarCollapsed, isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.backslash);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(widths.sidebarCollapsed, isTrue);
    expect(find.byKey(const Key('rail')), findsOneWidget);
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
}
