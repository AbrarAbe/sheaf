import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taker/models/settings.dart';
import 'package:taker/ui/dialogs/settings_dialog.dart';

import '../../helpers/spy_vault_controller.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('taker_settings_ui_test');
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

  testWidgets('Change vault delegates to the controller with picked path', (tester) async {
    final controller = await pumpSettings(tester, pickFolder: () async => '/new/vault');

    await tester.tap(find.text('Change vault…'));
    await tester.pump();

    expect(controller.openedVaults, ['/new/vault']);
  });
}
