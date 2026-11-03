import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

Future<String?> textPrompt(BuildContext context, {required String title, String? initial}) {
  final field = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 400),
      title: Text(title, style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w600)),
      content: TextField(
        controller: field,
        autofocus: true,
        onSubmitted: (v) => Navigator.of(context).pop(v),
        style: GoogleFonts.hankenGrotesk(fontSize: 14),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(enabledMouseCursor: SystemMouseCursors.click),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(enabledMouseCursor: SystemMouseCursors.click),
          onPressed: () => Navigator.of(context).pop(field.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
