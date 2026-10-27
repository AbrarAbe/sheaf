import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/theme/quire_theme.dart';
import 'package:sheaf/ui/dialogs/new_note_dialog.dart';

import '../../helpers/spy_vault_controller.dart';

void main() {
  late SpyVaultController controller;

  // DropdownMenu keeps its menu items in the tree even when closed (it needs
  // them to size the panel), so find.text matches both the field's EditableText
  // and the hidden items. Scope finders to the field's EditableText to assert
  // the displayed value, and tap the whole field to open the menu.
  Finder dropdownField() =>
      find.descendant(of: find.byType(DropdownMenu<String>), matching: find.byType(EditableText));

  String dropdownFieldValue(WidgetTester tester) =>
      tester.widget<EditableText>(dropdownField()).controller.text;

  setUp(() {
    controller = SpyVaultController('unused');
    controller.fakeFolders = const [
      FolderNode(
        name: 'work',
        relPath: 'work',
        children: [FolderNode(name: 'q3', relPath: 'work/q3')],
      ),
    ];
    controller.selectedFolder = null;
  });

  testWidgets('default submit returns Untitled and empty folder', (tester) async {
    NewNoteRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                result = await showNewNoteDialog(context, controller);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.showKeyboard(find.byType(TextFormField));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.title, 'Untitled');
    expect(result!.relFolder, '');
  });

  testWidgets('empty name normalizes to Untitled', (tester) async {
    NewNoteRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                result = await showNewNoteDialog(context, controller);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.byType(TextFormField), '');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.title, 'Untitled');
  });

  testWidgets('whitespace trimmed', (tester) async {
    NewNoteRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                result = await showNewNoteDialog(context, controller);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.byType(TextFormField), '  hello  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.title, 'hello');
  });

  testWidgets('location default when a folder is selected', (tester) async {
    controller.selectedFolder = 'work/q3';
    NewNoteRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                result = await showNewNoteDialog(context, controller);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(dropdownFieldValue(tester), 'work/q3');

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.title, 'Untitled');
    expect(result!.relFolder, 'work/q3');
  });

  testWidgets('dropdown content flattened and selection submitted', (tester) async {
    NewNoteRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                result = await showNewNoteDialog(context, controller);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(dropdownFieldValue(tester), 'Vault root');

    // open the dropdown
    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('work/q3').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.relFolder, 'work/q3');
  });

  testWidgets('cancel via barrier dismiss returns null', (tester) async {
    NewNoteRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                result = await showNewNoteDialog(context, controller);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tapAt(const Offset(0, 0));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('cancel via Esc returns null', (tester) async {
    NewNoteRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                result = await showNewNoteDialog(context, controller);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('long nested paths do not overflow the location dropdown', (tester) async {
    tester.view.physicalSize = const Size(300, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final longPath = '${'a' * 40}/${'b' * 40}';
    controller.fakeFolders = [
      FolderNode(
        name: 'a' * 40,
        relPath: 'a' * 40,
        children: [FolderNode(name: 'b' * 40, relPath: longPath)],
      ),
    ];
    controller.selectedFolder = longPath;

    NewNoteRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                result = await showNewNoteDialog(context, controller);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // no RenderFlex overflow from the wide, deeply-indented items
    expect(tester.takeException(), isNull);

    // the long path is still selectable and round-trips as the location
    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(longPath).last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.relFolder, longPath);
  });

  testWidgets('location dropdown uses compact M3 rows and body text (v0.3.6)', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildQuireDark(),
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showNewNoteDialog(context, controller),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final menu = tester.widget<DropdownMenu<String>>(find.byType(DropdownMenu<String>));
    // The picker is a button, not a focusable search field, and each row is a
    // 36px MenuItemButton with body text. DropdownButton rows were hard-floored
    // at kMinInteractiveDimension (48px) with 16px text, which is why the
    // picker looked oversized next to the dense dialog.
    expect(menu.requestFocusOnTap, isFalse);
    // The panel width must be pinned to the dialog's available width — without
    // it the menu sizes to the widest item's intrinsic text width (ellipsis is
    // ignored there) and the panel blows out past the modal on long paths.
    expect(menu.width, isNotNull);
    expect(menu.width, greaterThan(0));
    final itemStyle = menu.dropdownMenuEntries.first.style;
    expect(itemStyle?.minimumSize?.resolve({})?.height, 36);
    expect(itemStyle?.textStyle?.resolve({})?.fontSize, 14);
  });

  testWidgets('no stale state after prior submit', (tester) async {
    NewNoteRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                result = await showNewNoteDialog(context, controller);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    // first submit
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextFormField), 'First');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(result!.title, 'First');

    // reopen
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 200));

    // default name should be Untitled again
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller!.text, 'Untitled');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.title, 'Untitled');
    expect(result!.relFolder, '');
  });
}
