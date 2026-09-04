import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<String?> textPrompt(
  BuildContext context, {
  required String title,
  String? initial,
}) {
  final field = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        title,
        style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w600),
      ),
      content: TextField(
        controller: field,
        autofocus: true,
        onSubmitted: (v) => Navigator.of(context).pop(v),
        style: GoogleFonts.hankenGrotesk(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(field.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
