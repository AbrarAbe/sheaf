import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/models/settings.dart';
import 'package:sheaf/ui/dialogs/settings_dialog.dart';

import '../../helpers/spy_vault_controller.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sheaf_settings_ui_test');
  });

  tearDown(() async => tempDir.delete(recursive: true));

  Future<SpyVaultController> pumpSettings(
    WidgetTester tester, {
    Future<String?> Function()? pickFolder,
  }) async {
    final controller = SpyVaultController('${tempDir.path}/settings.json');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showSettingsDialog(context, controller, pickFolder: pickFolder),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('shows current vault path and theme options', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('/old/vault'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('choosing Light calls setTheme', (tester) async {
    final controller = await pumpSettings(tester);

    await tester.tap(find.text('Light'));
    await tester.pump();

    expect(controller.themes.last, ThemeSetting.light);
  });

  testWidgets('world picker lists the launch set and persists selection', (tester) async {
    final controller = await pumpSettings(tester);

    expect(find.text('Quire'), findsOneWidget);
    expect(find.text('Graphite'), findsOneWidget);
    expect(find.text('Sepia'), findsOneWidget);

    await tester.tap(find.text('Graphite'));
    await tester.pump();

    expect(controller.settings.themeWorld, 'graphite');
    expect(controller.worlds, ['graphite']);
  });

  group('type settings (story 16 / task 14)', () {
    testWidgets('type size slider persists the editor base size', (tester) async {
      final controller = await pumpSettings(tester);
      expect(controller.settings.editorFontSize, 16.0);

      // Drag the slider right; any change lands inside the documented range.
      await tester.drag(find.byKey(const Key('type-size-slider')), const Offset(60, 0));
      await tester.pump();

      final size = controller.settings.editorFontSize;
      expect(size, greaterThan(16.0));
      expect(size, lessThanOrEqualTo(24.0));
    });

    testWidgets('zoom stepper steps and resets', (tester) async {
      final controller = await pumpSettings(tester);

      await tester.tap(find.byKey(const Key('zoom-in')));
      await tester.pump();
      expect(controller.settings.zoomFactor, closeTo(1.1, 1e-9));

      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(controller.settings.zoomFactor, 1.0);
    });
  });

  testWidgets('window controls switch records the hide choice', (tester) async {
    // Tall viewport so the lower Appearance controls are hittable.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await pumpSettings(tester);
    expect(controller.settings.showWindowControls, isTrue);

    await tester.tap(find.byKey(const Key('window-controls-switch')));
    await tester.pump();

    expect(controller.windowControlToggles, [false]);
    expect(controller.settings.showWindowControls, isFalse);
  });

  testWidgets('Change vault delegates to the controller with picked path', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await pumpSettings(tester, pickFolder: () async => '/new/vault');

    await tester.tap(find.text('Change vault…'));
    await tester.pump();

    expect(controller.openedVaults, ['/new/vault']);
  });
}
