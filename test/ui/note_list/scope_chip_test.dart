import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/ui/note_list/widgets/scope_chip.dart';

void main() {
  Widget host(String label, {double width = 136}) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: ScopeChip(icon: Icons.folder_outlined, label: label, onClear: () {}),
        ),
      ),
    ),
  );

  testWidgets('long scope label ellipsizes instead of overflowing a narrow chip', (tester) async {
    await tester.pumpWidget(host('in this-is-a-very-long-folder-name-that-must-truncate'));

    // The 136px clamp previously produced a RenderFlex overflow of ~14px.
    expect(tester.takeException(), isNull);

    final text = tester.widget<Text>(
      find.descendant(of: find.byType(ScopeChip), matching: find.byType(Text)),
    );
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.maxLines, 1);
    expect(text.softWrap, isFalse);
  });

  testWidgets('short scope label stays fully visible', (tester) async {
    await tester.pumpWidget(host('in proj'));
    expect(tester.takeException(), isNull);

    final text = tester.widget<Text>(
      find.descendant(of: find.byType(ScopeChip), matching: find.byType(Text)),
    );
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
