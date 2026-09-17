import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sheaf/data/settings_repository.dart';
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/logic/editor_controller.dart';
import 'package:sheaf/logic/formatting.dart';
import 'package:sheaf/logic/vault_controller.dart';
import 'package:sheaf/models/settings.dart';
import 'package:sheaf/ui/editor/editor_pane.dart';
import 'package:sheaf/ui/editor/markdown_preview.dart';
import 'package:sheaf/ui/editor/widgets/tag_chip_bar.dart';

/// Widget tests must route every real-I/O call through [real] because
/// unwrapped awaits deadlock inside the tester's FakeAsync zone.
void main() {
  // Hermetic font handling (matches theme tests): resolve to plain family
  // names instead of hitting fonts.gstatic.com mid-test.
  GoogleFonts.config.allowRuntimeFetching = false;
  late Directory tempDir;
  late VaultController vaultController;
  late EditorController editorController;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sheaf_editor_ui_test');
    final repo = VaultRepository(root: Directory('${tempDir.path}/vault'));
    vaultController = VaultController(
      settings: SettingsRepository(file: File('${tempDir.path}/settings.json')),
      vaultFactory: (path) => VaultRepository(root: Directory(path)),
    );
    // Plain awaits are safe here: setUp runs outside the FakeAsync zone.
    await vaultController.initialize();
    await vaultController.openVault('${tempDir.path}/vault');
    editorController = EditorController(vault: repo);
  });

  tearDown(() async {
    editorController.dispose();
    vaultController.dispose();
    await tempDir.delete(recursive: true);
  });

  Future<T> real<T>(Future<T> Function() action, WidgetTester tester) async =>
      (await tester.runAsync(action)) as T;

  Future<void> pumpEditor(WidgetTester tester, {Future<String> Function(File)? importImage}) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPane(controller: editorController, importImage: importImage),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows placeholder when nothing is open', (tester) async {
    await pumpEditor(tester);

    expect(find.text('Select a note'), findsOneWidget);
  });

  testWidgets('opening a note shows title/body', (tester) async {
    final note = await real(() => vaultController.createNote(title: 'Draft'), tester);
    await real(() => editorController.open(note), tester);
    await pumpEditor(tester);

    expect(find.widgetWithText(TextField, 'Draft'), findsOneWidget);
    expect(find.widgetWithText(TextField, ''), findsOneWidget); // empty body
  });

  testWidgets('typing marks the note dirty; flush persists to disk', (tester) async {
    final note = await real(() => vaultController.createNote(title: 'Draft'), tester);
    await real(() => editorController.open(note), tester);
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).last, '# Draft\nhello world');
    await tester.pump();
    // Debounce timing itself is covered by editor_controller_test.
    expect(find.textContaining('unsaved'), findsOneWidget);

    await real(editorController.flush, tester);
    await tester.pump();

    final onDisk = File('${tempDir.path}/vault/${note.path}').readAsStringSync();
    expect(onDisk, '# Draft\nhello world');
    expect(find.textContaining('saved'), findsOneWidget);
  });

  testWidgets('title and body fields render without fill background', (tester) async {
    final note = await real(() => vaultController.createNote(title: 'Clean'), tester);
    await real(() => editorController.open(note), tester);
    await pumpEditor(tester);

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.length, 2); // title + body
    for (final field in fields) {
      expect(
        field.decoration?.filled,
        isFalse,
        reason: 'editor prose sits on the card, not in a well',
      );
    }
  });

  testWidgets('body prose column spans the pane width (unbounded)', (tester) async {
    final note = await real(
      () => vaultController.createNote(title: 'Prose', body: 'a short line'),
      tester,
    );
    await real(() => editorController.open(note), tester);
    await pumpEditor(tester);

    final editableState = tester.state<EditableTextState>(
      find.descendant(
        of: find.byKey(const Key('editor-body')),
        matching: find.byType(EditableText),
      ),
    );
    final editableWidth = editableState.renderEditable.size.width;
    final paneWidth = tester.getSize(find.byType(EditorPane)).width;

    // v0.3.1 Task 3/5: no capped reading measure — the column fills the pane
    // and the scrollbar gutter lives inside the content padding. Word-local
    // highlight comes from tight selection boxes (asserted by the next test).
    expect(
      editableWidth,
      greaterThan(paneWidth * 0.9),
      reason: 'body prose column is unbounded and fills the pane',
    );
  });

  testWidgets('body field uses tight selection boxes so multi-line highlight hugs text', (
    tester,
  ) async {
    final note = await real(() => vaultController.createNote(title: 'Tight'), tester);
    await real(() => editorController.open(note), tester);
    await pumpEditor(tester);

    final field = tester.widget<TextField>(find.byKey(const Key('editor-body')));
    expect(
      field.selectionWidthStyle,
      ui.BoxWidthStyle.tight,
      reason:
          'non-web default is BoxWidthStyle.max, which pads each selected '
          'line out to the widest line in the paragraph',
    );
  });

  testWidgets('tag chips render from body tags', (tester) async {
    final note = await real(
      () => vaultController.createNote(title: 'Tagged', body: '#work #q3\nbody'),
      tester,
    );
    await real(() => editorController.open(note), tester);
    await pumpEditor(tester);

    expect(find.text('#work'), findsOneWidget);
    expect(find.text('#q3'), findsOneWidget);
  });

  testWidgets('preview toggle swaps body field for rendered markdown', (tester) async {
    final note = await real(
      () => vaultController.createNote(title: 'Doc', body: '# Rendered Heading\nbody'),
      tester,
    );
    await real(() => editorController.open(note), tester);
    await pumpEditor(tester);

    expect(find.byKey(const Key('editor-body')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mode-preview')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('editor-body')), findsNothing);
    expect(find.byType(MarkdownPreview), findsOneWidget);
    expect(find.text('Rendered Heading', findRichText: true), findsWidgets);
  });

  testWidgets('image picker button is hidden (round 6 deferral)', (tester) async {
    await pumpEditor(tester);

    expect(find.byTooltip('Insert image'), findsNothing);
    expect(find.byIcon(Icons.image_outlined), findsNothing);
  });

  group('body edit menu (round 6 F21)', () {
    /// Runs [body] with a desktop platform override restored before the test
    /// ends (the binding checks debug invariants right after the body).
    Future<void> onDesktop(Future<void> Function() body) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    Future<void> openMenuAtSelection(WidgetTester tester, TextSelection selection) async {
      final note = await real(() => vaultController.createNote(title: 'Menu'), tester);
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);

      // Known body so selections below are valid.
      await tester.enterText(find.byKey(const Key('editor-body')), 'hello world');
      editorController.updateBody('hello world');
      await tester.pump();

      final state = tester.state<EditableTextState>(
        find.descendant(
          of: find.byKey(const Key('editor-body')),
          matching: find.byType(EditableText),
        ),
      );
      state.widget.controller.selection = selection;
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('editor-body'))),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await tester.pump();
      await gesture.up();
      await tester.pump(); // builder schedules the Quire route
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('secondary tap opens the Quire-styled edit menu', (tester) async {
      await onDesktop(() async {
        await openMenuAtSelection(tester, const TextSelection(baseOffset: 6, extentOffset: 11));

        for (final label in ['Cut', 'Copy', 'Paste', 'Select all']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }

        // The builder re-fires whenever the field rebuilds (clipboard status,
        // highlighting ticks); the menu must never stack a second copy.
        final field = tester.widget<TextField>(find.byKey(const Key('editor-body')));
        final editableState = tester.state<EditableTextState>(
          find.descendant(
            of: find.byKey(const Key('editor-body')),
            matching: find.byType(EditableText),
          ),
        );
        field.contextMenuBuilder!(
          tester.element(find.byKey(const Key('editor-body'))),
          editableState,
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Select all'), findsOneWidget);

        // Quire typography on our component, not stock Material chrome.
        final label = tester.widget<Text>(find.text('Copy'));
        expect(label.style?.fontSize, 13);
        expect(label.style?.fontWeight, FontWeight.w500);

        await tester.runAsync(editorController.flush); // settle autosave
      });
    });

    testWidgets('Copy puts the selection on the clipboard', (tester) async {
      Object? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        if (call.method == 'Clipboard.setData') {
          copied = call.arguments['text'];
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await onDesktop(() async {
        await openMenuAtSelection(tester, const TextSelection(baseOffset: 6, extentOffset: 11));
        await tester.tap(find.text('Copy'));
        await tester.pump();

        expect(copied, 'world');
        await tester.runAsync(editorController.flush); // settle autosave
      });
    });

    testWidgets('Paste replaces the selection from the clipboard', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async =>
            call.method == 'Clipboard.getData' ? <String, dynamic>{'text': 'there'} : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await onDesktop(() async {
        await openMenuAtSelection(tester, const TextSelection(baseOffset: 0, extentOffset: 11));
        await tester.tap(find.text('Paste'));
        await tester.pump();

        expect(editorController.body, 'there');
        await tester.runAsync(editorController.flush); // settle autosave
      });
    });
  });

  group('find in note (spec story 14)', () {
    Future<void> openBody(WidgetTester tester, String body) async {
      final note = await real(() => vaultController.createNote(title: 'F', body: body), tester);
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);
    }

    void invokeOpen(WidgetTester tester) {
      final ctx = tester.element(find.byKey(const Key('editor-body')));
      Actions.invoke(ctx, const OpenFindIntent());
    }

    testWidgets('Ctrl+F opens the bar and counts matches live', (tester) async {
      await openBody(tester, 'one two one');
      invokeOpen(tester);
      await tester.pump();

      expect(find.byKey(const Key('find-bar')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('find-field')), 'one');
      await tester.pump();
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('Enter walks matches and wraps around', (tester) async {
      await openBody(tester, 'one two one');
      invokeOpen(tester);
      await tester.pump();
      await tester.enterText(find.byKey(const Key('find-field')), 'one');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('2/2'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('no matches shows a friendly zero count', (tester) async {
      await openBody(tester, 'nothing here');
      invokeOpen(tester);
      await tester.pump();
      await tester.enterText(find.byKey(const Key('find-field')), 'zzz');
      await tester.pump();
      expect(find.text('0/0'), findsOneWidget);
    });

    testWidgets('close button dismisses the bar', (tester) async {
      await openBody(tester, 'some text');
      invokeOpen(tester);
      await tester.pump();

      await tester.tap(find.byKey(const Key('find-close')));
      await tester.pump();
      expect(find.byKey(const Key('find-bar')), findsNothing);
    });
  });

  group('list continuation (spec story 15)', () {
    testWidgets('Enter continues a dash list', (tester) async {
      final note = await real(() => vaultController.createNote(title: 'L', body: '- item'), tester);
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);

      await tester.enterText(find.byKey(const Key('editor-body')), '- item');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(editorController.body, '- item\n- ');
      await real(editorController.flush, tester);
    });

    testWidgets('Enter on prose inserts a plain newline', (tester) async {
      final note = await real(() => vaultController.createNote(title: 'P', body: ''), tester);
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);

      await tester.enterText(find.byKey(const Key('editor-body')), 'prose line');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(editorController.body, 'prose line\n');
      await real(editorController.flush, tester);
    });
  });

  group('auto-scroll on last-line Enter (spec story 43)', () {
    String longBody() => List.generate(80, (i) => 'paragraph line number $i').join('\n');

    // The body TextField scrolls on _bodyScroll; read its live position.
    ScrollPosition bodyPosition(WidgetTester tester) {
      final scrollable = find
          .descendant(of: find.byKey(const Key('editor-body')), matching: find.byType(Scrollable))
          .first;
      return tester.state<ScrollableState>(scrollable).position;
    }

    testWidgets('Enter at the very end reveals the new blank line', (tester) async {
      final note = await real(() => vaultController.createNote(title: 'Scroll', body: ''), tester);
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);

      // enterText leaves the caret on the last line of a long, overflowing body.
      await tester.enterText(find.byKey(const Key('editor-body')), longBody());
      await tester.pump();

      final maxBefore = bodyPosition(tester).maxScrollExtent;
      expect(maxBefore, greaterThan(0), reason: 'long body should overflow the editor');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();

      expect(editorController.body, '${longBody()}\n');
      // Viewport jumped to the bottom so the new line is visible immediately.
      expect(bodyPosition(tester).pixels, greaterThan(maxBefore));
      await real(editorController.flush, tester);
    });

    testWidgets('Enter mid-document does NOT auto-scroll', (tester) async {
      final note = await real(() => vaultController.createNote(title: 'Mid', body: ''), tester);
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);

      await tester.enterText(find.byKey(const Key('editor-body')), longBody());
      await tester.pump();
      // Move the caret into the middle of the document, away from the end.
      final field = tester.widget<TextField>(find.byKey(const Key('editor-body')));
      field.controller!.selection = TextSelection.collapsed(offset: 5);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();

      expect(bodyPosition(tester).pixels, 0, reason: 'caret is mid-document, keep the offset');
      await real(editorController.flush, tester);
    });

    testWidgets('list continuation at the end does NOT auto-scroll', (tester) async {
      final note = await real(() => vaultController.createNote(title: 'List', body: ''), tester);
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);

      // Long body whose last line is a list item, caret on that last item.
      final body = '${List.generate(40, (i) => 'line $i').join('\n')}\n- final item';
      await tester.enterText(find.byKey(const Key('editor-body')), body);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();

      // The list was continued (a marker line was appended) but the viewport stayed put.
      expect(editorController.body.length, greaterThan(body.length));
      expect(bodyPosition(tester).pixels, 0, reason: 'list continuation is excluded');
      await real(editorController.flush, tester);
    });
  });

  group('formatting keys (spec story 10)', () {
    Future<void> openNormal(WidgetTester tester, {String body = 'hello world'}) async {
      final note = await real(() => vaultController.createNote(title: 'Fmt', body: body), tester);
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);
    }

    void selectAll(WidgetTester tester) {
      final state = tester.state<EditableTextState>(
        find.descendant(
          of: find.byKey(const Key('editor-body')),
          matching: find.byType(EditableText),
        ),
      );
      state.widget.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: state.widget.controller.text.length,
      );
    }

    TextSelection currentSelection(WidgetTester tester) {
      final state = tester.state<EditableTextState>(
        find.descendant(
          of: find.byKey(const Key('editor-body')),
          matching: find.byType(EditableText),
        ),
      );
      return state.widget.controller.selection;
    }

    testWidgets('Ctrl+B wraps selection in bold markers', (tester) async {
      await openNormal(tester);
      selectAll(tester);
      await tester.pump();

      final ctx = tester.element(find.byKey(const Key('editor-body')));
      Actions.invoke(ctx, const FormatIntent(FormatKind.bold));
      await tester.pump();

      expect(editorController.body, '**hello world**');
      await real(editorController.flush, tester);
    });

    testWidgets('repeating the wrap on wrapped text unwraps', (tester) async {
      await openNormal(tester, body: '**bold**');
      selectAll(tester);
      await tester.pump();

      final ctx = tester.element(find.byKey(const Key('editor-body')));
      Actions.invoke(ctx, const FormatIntent(FormatKind.bold));
      await tester.pump();

      expect(editorController.body, 'bold');
      await real(editorController.flush, tester);
    });

    testWidgets('F20: select-all toggle rounds trip without right-shrink drift', (tester) async {
      await openNormal(tester, body: 'steady');

      for (var i = 0; i < 2; i++) {
        selectAll(tester);
        await tester.pump();
        Actions.invoke(
          tester.element(find.byKey(const Key('editor-body'))),
          const FormatIntent(FormatKind.bold),
        );
        await tester.pump();
        expect(editorController.body, '**steady**', reason: 'wrap $i');

        selectAll(tester);
        await tester.pump();
        Actions.invoke(
          tester.element(find.byKey(const Key('editor-body'))),
          const FormatIntent(FormatKind.bold),
        );
        await tester.pump();
        expect(editorController.body, 'steady', reason: 'unwrap $i');
        expect(
          currentSelection(tester),
          const TextSelection(baseOffset: 0, extentOffset: 6),
          reason: 'selection restored after cycle $i',
        );
      }
      await real(editorController.flush, tester);
    });

    testWidgets('italic and underline use their own markers', (tester) async {
      await openNormal(tester, body: 'word');
      selectAll(tester);
      await tester.pump();
      final ctx = tester.element(find.byKey(const Key('editor-body')));

      Actions.invoke(ctx, const FormatIntent(FormatKind.italic));
      expect(editorController.body, '*word*');

      // Unwrap italic, then underline the same span.
      selectAll(tester);
      Actions.invoke(ctx, const FormatIntent(FormatKind.italic));
      selectAll(tester);
      Actions.invoke(ctx, const FormatIntent(FormatKind.underline));
      await tester.pump();
      expect(editorController.body, '<u>word</u>');
      await real(editorController.flush, tester);
    });

    testWidgets('F25: italic triple-press cycles italic/plain without bolding', (tester) async {
      await openNormal(tester);

      // Natural flow: type a word (caret rests at its end, ON the word),
      // then keep hammering Ctrl+I without touching the mouse.
      await tester.enterText(find.byKey(const Key('editor-body')), 'word');
      await tester.pump();
      final ctx = tester.element(find.byKey(const Key('editor-body')));

      Actions.invoke(ctx, const FormatIntent(FormatKind.italic));
      await tester.pump();
      expect(editorController.body, '*word*', reason: 'P1 wraps italic');

      Actions.invoke(ctx, const FormatIntent(FormatKind.italic));
      await tester.pump();
      expect(editorController.body, 'word', reason: 'P2 unwraps — never bolds');

      Actions.invoke(ctx, const FormatIntent(FormatKind.italic));
      await tester.pump();
      expect(editorController.body, '*word*', reason: 'P3 re-wraps italic');

      // Caret parked at line start (Home) sits before the leading marker;
      // pressing again must unwrap/toggle, never splice a nested pair that
      // renders as bold.
      final state = tester.state<EditableTextState>(
        find.descendant(
          of: find.byKey(const Key('editor-body')),
          matching: find.byType(EditableText),
        ),
      );
      state.widget.controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();

      Actions.invoke(ctx, const FormatIntent(FormatKind.italic));
      await tester.pump();
      expect(editorController.body, isNot(contains('***')), reason: 'no nested splices');
      await real(editorController.flush, tester);
    });

    testWidgets('formatting keys work in markdown mode too (feedback F2)', (tester) async {
      final note = await real(
        () => vaultController.createNote(title: 'Raw', body: 'plain'),
        tester,
      );
      await real(() => editorController.open(note), tester);
      editorController.setMode(EditorMode.markdown);
      await pumpEditor(tester);

      selectAll(tester);
      await tester.pump();
      final ctx = tester.element(find.byKey(const Key('editor-body')));
      Actions.invoke(ctx, const FormatIntent(FormatKind.bold));
      await tester.pump();

      expect(editorController.body, '**plain**');
      await real(editorController.flush, tester);
    });

    testWidgets('F10: Ctrl+U with bare caret on a word underlines that word', (tester) async {
      final note = await real(
        () => vaultController.createNote(title: 'U', body: 'plain word here'),
        tester,
      );
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);

      // enterText leaves the caret at the end, sitting on 'here'.
      await tester.enterText(find.byKey(const Key('editor-body')), 'plain word here');
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(editorController.body, 'plain word <u>here</u>');
      await real(editorController.flush, tester);
    });

    testWidgets('F10: Ctrl+B mid-word bolds the whole word instead of splitting', (tester) async {
      final note = await real(
        () => vaultController.createNote(title: 'B', body: 'plain word'),
        tester,
      );
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);

      // Caret inside 'word' (offset 7), nothing selected.
      final state = tester.state<EditableTextState>(
        find.descendant(
          of: find.byKey(const Key('editor-body')),
          matching: find.byType(EditableText),
        ),
      );
      state.widget.controller.selection = const TextSelection.collapsed(offset: 7);
      await tester.pump();

      final ctx = tester.element(find.byKey(const Key('editor-body')));
      Actions.invoke(ctx, const FormatIntent(FormatKind.bold));
      await tester.pump();

      expect(editorController.body, 'plain **word**');
      await real(editorController.flush, tester);
    });

    testWidgets('Ctrl+U untoggles from a bare caret inside the span (feedback round 3)', (
      tester,
    ) async {
      final note = await real(
        () => vaultController.createNote(title: 'U2', body: '<u>under</u> rest'),
        tester,
      );
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);

      final state = tester.state<EditableTextState>(
        find.descendant(
          of: find.byKey(const Key('editor-body')),
          matching: find.byType(EditableText),
        ),
      );
      state.widget.controller.selection = const TextSelection.collapsed(offset: 6);
      state.widget.focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(editorController.body, 'under rest');
      await real(editorController.flush, tester);
    });
  });

  group('feedback round 1', () {
    testWidgets('F3: rendered output hugs the top of the pane', (tester) async {
      final note = await real(
        () => vaultController.createNote(title: 'Top', body: '# Topline\n\nshort body'),
        tester,
      );
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);
      await tester.tap(find.byKey(const Key('mode-preview')));
      await tester.pumpAndSettle();

      final heading = find
          .descendant(
            of: find.byType(MarkdownPreview),
            matching: find.text('Topline', findRichText: true),
          )
          .first;
      final box = tester.renderObject<RenderBox>(heading);
      // Vertically centered output would sit near ~350 px in this harness.
      expect(box.localToGlobal(Offset.zero).dy, lessThan(120));
    });

    testWidgets('F4a: Normal mode renders bold live; markers hidden untouched', (tester) async {
      final note = await real(
        () => vaultController.createNote(title: 'HL', body: '**loud** word'),
        tester,
      );
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);

      final spans = _bodySpans(tester);
      expect(
        spans.any(
          (ts) => (ts.text ?? '').contains('loud') && ts.style?.fontWeight == FontWeight.w700,
        ),
        isTrue,
        reason: 'inner bold text should carry a bold style',
      );
      final markers = spans.where((ts) => ts.text == '**').toList();
      expect(markers, isNotEmpty);
      expect(
        markers.every((ts) => ts.style?.fontSize == 0),
        isTrue,
        reason: 'untouched markers render zero-width (hidden)',
      );
    });

    testWidgets('F5: touching a span reveals its dimmed markers', (tester) async {
      final note = await real(
        () => vaultController.createNote(title: 'HL', body: '**loud** word'),
        tester,
      );
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);

      final state = tester.state<EditableTextState>(
        find.descendant(
          of: find.byKey(const Key('editor-body')),
          matching: find.byType(EditableText),
        ),
      );
      state.widget.controller.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();

      final markers = _bodySpans(tester).where((ts) => ts.text == '**').toList();
      expect(markers, isNotEmpty);
      expect(markers.every((ts) => (ts.style?.fontSize ?? 0) > 0), isTrue);
      expect(markers.every((ts) => (ts.style?.color?.a ?? 1) < 1), isTrue);
    });

    testWidgets('F5b: heading hashes hide until the line is touched', (tester) async {
      final note = await real(
        () => vaultController.createNote(title: 'H', body: '# Top\nnext'),
        tester,
      );
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);

      List<TextSpan> hashSpans() => _bodySpans(tester).where((ts) => ts.text == '#').toList();
      expect(hashSpans().every((ts) => ts.style?.fontSize == 0), isTrue);

      final state = tester.state<EditableTextState>(
        find.descendant(
          of: find.byKey(const Key('editor-body')),
          matching: find.byType(EditableText),
        ),
      );
      state.widget.controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();
      expect(hashSpans().every((ts) => (ts.style?.fontSize ?? 0) > 0), isTrue);
    });

    testWidgets('F6: Ctrl+D selects the word at the caret', (tester) async {
      final note = await real(() => vaultController.createNote(title: 'W', body: ''), tester);
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);

      // enterText focuses the field and leaves the caret at the end.
      await tester.enterText(find.byKey(const Key('editor-body')), 'foo bar baz');
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      final sel = editorController.current != null ? _bodySelection(tester) : null;
      expect(sel?.baseOffset, 8);
      expect(sel?.extentOffset, 11);
      await real(editorController.flush, tester);
    });

    testWidgets('F4b: Markdown mode shows unstyled source', (tester) async {
      final note = await real(
        () => vaultController.createNote(title: 'HM', body: '**loud** word'),
        tester,
      );
      await real(() => editorController.open(note), tester);
      editorController.setMode(EditorMode.markdown);
      await pumpEditor(tester);

      final spans = _bodySpans(tester);
      expect(
        spans.any(
          (ts) => (ts.text ?? '').contains('loud') && ts.style?.fontWeight == FontWeight.w700,
        ),
        isFalse,
      );
    });
  });

  group('editor modes (spec story 12)', () {
    Future<void> openAndPump(WidgetTester tester) async {
      final note = await real(
        () => vaultController.createNote(title: 'Modes', body: '# Modes\nbody text'),
        tester,
      );
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);
    }

    testWidgets('normal mode edits with proportional type by default', (tester) async {
      await openAndPump(tester);

      expect(find.byKey(const Key('editor-body')), findsOneWidget);
      final field = tester.widget<TextField>(find.byKey(const Key('editor-body')));
      expect(field.style?.fontFamily, isNot(contains('Spline Sans Mono')));
    });

    testWidgets('markdown segment switches to monospace source', (tester) async {
      await openAndPump(tester);

      await tester.tap(find.byKey(const Key('mode-markdown')));
      await tester.pump();

      expect(editorController.mode, EditorMode.markdown);
      final field = tester.widget<TextField>(find.byKey(const Key('editor-body')));
      expect(field.style?.fontFamily, contains('SplineSansMono'));
      // Still editable in markdown mode.
      await tester.enterText(find.byKey(const Key('editor-body')), 'raw');
      expect(editorController.body, 'raw');
      await real(editorController.flush, tester);
    });

    testWidgets('preview segment swaps to rendered output', (tester) async {
      await openAndPump(tester);

      await tester.tap(find.byKey(const Key('mode-preview')));
      await tester.pump();

      expect(editorController.mode, EditorMode.preview);
      expect(find.byKey(const Key('editor-body')), findsNothing);
      expect(find.byType(MarkdownPreview), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MarkdownPreview),
          matching: find.text('Modes', findRichText: true),
        ),
        findsOneWidget,
      );
    });

    testWidgets('mode survives reopening the pane via controller state', (tester) async {
      await openAndPump(tester);
      await tester.tap(find.byKey(const Key('mode-preview')));
      await tester.pump();

      // A brand-new pane reading the same controller opens in preview too.
      await pumpEditor(tester);
      expect(editorController.mode, EditorMode.preview);
    });
    group('find and tag bars container (focus mode)', () {
      testWidgets('find bar uses container in focus mode', (tester) async {
        await openAndPump(tester);
        expect(find.byKey(const Key('find-bar')), findsNothing);
        final ctx = tester.element(find.byKey(const Key('editor-body')));
        Actions.invoke(ctx, const OpenFindIntent());
        await tester.pump();
        expect(find.byKey(const Key('find-bar')), findsOneWidget);
        final container = tester.widget<Container>(find.byKey(const Key('find-bar')));
        expect(container.decoration, isA<BoxDecoration>());
      });

      testWidgets('tag bar only built when tags non-empty', (tester) async {
        final note = await real(
          () => vaultController.createNote(title: 'T', body: 'hello #tag'),
          tester,
        );
        await real(() => editorController.open(note), tester);
        await pumpEditor(tester);
        expect(find.text('#tag'), findsOneWidget);
        expect(find.byType(TagChipBar), findsOneWidget);
      });
    });
  });
}

/// Collects every TextSpan the body field paints (via its RenderEditable).
List<TextSpan> _bodySpans(WidgetTester tester) {
  final out = <TextSpan>[];
  void walk(InlineSpan span) {
    if (span is TextSpan) {
      out.add(span);
      span.children?.forEach(walk);
    }
  }

  final state = tester.state<EditableTextState>(
    find.descendant(of: find.byKey(const Key('editor-body')), matching: find.byType(EditableText)),
  );
  final root = state.renderEditable.text;
  if (root != null) walk(root);
  return out;
}

/// Current selection of the body field.
TextSelection? _bodySelection(WidgetTester tester) {
  final state = tester.state<EditableTextState>(
    find.descendant(of: find.byKey(const Key('editor-body')), matching: find.byType(EditableText)),
  );
  return state.widget.controller.selection;
}
