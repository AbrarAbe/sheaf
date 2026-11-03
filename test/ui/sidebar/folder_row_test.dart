import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/logic/vault_controller.dart';
import 'package:sheaf/ui/sidebar/widgets/folder_row.dart';
import 'package:sheaf/ui/sidebar/widgets/hover_row.dart';
import 'package:sheaf/ui/sidebar/widgets/text_prompt.dart';

import '../../helpers/spy_vault_controller.dart';

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

  group('auto-expand on selection (v0.3.7)', () {
    const node = FolderNode(
      name: 'proj',
      relPath: 'proj',
      children: [FolderNode(name: 'sub', relPath: 'proj/sub')],
    );

    // SpyVaultController records mutations without touching disk, so these
    // tests avoid the real vault's filesystem watchers (which hang under the
    // test FakeAsync zone) while still exercising real selectFolder/notify.
    VaultController controller() => SpyVaultController('/tmp/sheaf_folder_test.json');

    testWidgets('tapping a collapsed folder row reveals its subfolders', (tester) async {
      final c = controller();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: c,
              builder: (context, _) => FolderRow(controller: c, node: node),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('sub'), findsNothing);

      await tester.tap(find.text('proj'));
      await tester.pump();

      expect(c.selectedFolder, 'proj');
      expect(find.text('sub'), findsOneWidget);
    });

    testWidgets('selecting a collapsed folder externally auto-expands it', (tester) async {
      final c = controller();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: c,
              builder: (context, _) => FolderRow(controller: c, node: node),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('sub'), findsNothing);

      // Selection changes without tapping the row — e.g. the sidebar selects a
      // folder right after creating it.
      c.selectFolder('proj');
      await tester.pump();

      expect(find.text('sub'), findsOneWidget);
    });
  });
}
