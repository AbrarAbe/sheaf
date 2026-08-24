import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/app.dart';
import 'package:sheaf/data/settings_repository.dart';
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/logic/vault_controller.dart';
import 'package:sheaf/ui/dialogs/welcome_screen.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sheaf_app_test');
  });

  tearDown(() async => tempDir.delete(recursive: true));

  VaultController makeController() => VaultController(
    settings: SettingsRepository(file: File('${tempDir.path}/settings.json')),
    vaultFactory: (path) => VaultRepository(root: Directory(path)),
  );

  testWidgets('with no vault set, shows the welcome screen', (tester) async {
    final controller = makeController();
    addTearDown(controller.dispose);
    // Real file I/O must run outside the test FakeAsync zone.
    await tester.runAsync(controller.initialize);

    await tester.pumpWidget(SheafApp(controller: controller));
    await tester.pump();

    expect(find.text('Sheaf'), findsOneWidget);
    expect(find.text('Choose folder…'), findsOneWidget);
  });

  testWidgets('opening a vault swaps to the shell', (tester) async {
    final vaultDir = Directory('${tempDir.path}/vault')..createSync();
    final controller = makeController();
    addTearDown(controller.dispose);
    await tester.runAsync(controller.initialize);

    await tester.pumpWidget(SheafApp(controller: controller));
    await tester.pump();
    await tester.runAsync(() => controller.openVault(vaultDir.path));
    await tester.pump();

    expect(find.byType(WelcomeScreen), findsNothing);
  });

  testWidgets('applies the persisted zoom as the inherited text scaler', (tester) async {
    final controller = makeController();
    addTearDown(controller.dispose);
    await tester.runAsync(() async {
      controller.initialize;
      await controller.setZoom(1.5);
    });

    late TextScaler observed;
    await tester.pumpWidget(
      SheafApp(
        controller: controller,
        // Probe sits under MaterialApp's navigator, i.e. inside the builder's
        // MediaQuery override — exactly where user surfaces live.
        homeOverride: Builder(
          builder: (context) {
            observed = MediaQuery.textScalerOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();

    expect(observed, TextScaler.linear(1.5));
  });
}
