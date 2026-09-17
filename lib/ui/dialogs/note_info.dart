import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;

import '../../logic/vault_controller.dart';
import '../../models/note.dart';

/// Non-modal dialog showing file metadata for a note.
///
/// Reads file stats at open time and displays them in a compact format.
/// The dialog can be dismissed by clicking outside or pressing Esc.
class NoteInfoDialog extends StatelessWidget {
  const NoteInfoDialog({super.key, required this.controller, required this.note});

  final VaultController controller;
  final Note note;

  @override
  Widget build(BuildContext context) {
    // Read file stats at dialog open time via VaultController
    final file = controller.fileOf(note.path);
    final stats = file.statSync();

    final cs = Theme.of(context).colorScheme;

    // Build the relative path (URL-decoded so spaces show as spaces not %20)
    // and derive the file name from the same decoded path so Filename and Path
    // rows agree on how encoded characters are shown.
    final relPath = _normalizeRelPath(note.path);
    final fileName = p.basename(relPath);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.info_outlined, size: 20, color: cs.onSurface),
          const SizedBox(width: 6),
          const Text('Note Info'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRow(context, 'Title', note.title.isNotEmpty ? note.title : 'Untitled'),
            _buildRow(context, 'Filename', fileName),
            _buildRow(context, 'Path', relPath),
            // dart:io exposes no birth/creation time on Linux, so Created is
            // a best-effort read of ctime (stats.changed) while Modified
            // reads mtime (stats.modified). Passing stats.modified to both
            // is what made the two rows show the same data.
            _buildRow(context, 'Created', _formatCreated(stats.changed)),
            _buildRow(context, 'Modified', _formatModified(stats.modified)),
            _buildRow(context, 'Lines', _lineCount(note.body).toString()),
            _buildRow(context, 'Words', _wordCount(note.body).toString()),
            _buildRow(context, 'Characters', _charCount(note.body).toString()),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }

  /// Normalize a vault-relative path and URL-decode it so spaces appear as spaces.
  String _normalizeRelPath(String relPath) {
    // The path uses POSIX separators; decode percent-encoded characters
    final decoded = Uri.decodeComponent(relPath);
    return decoded;
  }

  /// Count the number of lines in a body string.
  int _lineCount(String body) {
    if (body.isEmpty) return 0;
    // Count lines: split on newlines, last empty line if trailing newline
    final lines = body.split('\n');
    // If the body ends with a newline, the split adds an extra empty element
    return lines.length;
  }

  /// Format creation date, showing the time plus a relative age suffix.
  String _formatCreated(DateTime date) => _formatTimestamp(date);

  /// Format modification date, showing the time plus a relative age suffix.
  String _formatModified(DateTime date) => _formatTimestamp(date);

  /// Shared formatter behind [_formatCreated] and [_formatModified].
  String _formatTimestamp(DateTime date) {
    final diff = DateTime.now().difference(date);
    final datePart = _datePart(date);
    final timePart = ' at ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
    return '$datePart$timePart${_relativeAgeSuffix(diff)}';
  }

  /// Date part as dd/MM/yyyy (day and month zero-padded).
  String _datePart(DateTime date) {
    return '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year}';
  }

  /// Relative age suffix such as ` (3d ago)`, ` (2h ago)` or ` (just now)`.
  String _relativeAgeSuffix(Duration diff) {
    final days = diff.inDays;
    if (days >= 365) {
      return ' (${days ~/ 365} years ago)';
    }
    if (days >= 30) {
      return ' (${days ~/ 30} month ago)';
    }
    if (days > 0) {
      return ' ($days days ago)';
    }
    if (diff.inHours > 0) {
      return ' (${diff.inHours} hours ago)';
    }
    if (diff.inMinutes > 0) {
      return ' (${diff.inMinutes} minutes ago)';
    }
    return ' (just now)';
  }

  /// Zero-pad a date/time component to two digits.
  String _twoDigits(int n) => n < 10 ? '0$n' : '$n';

  int _wordCount(String body) {
    if (body.isEmpty) return 0;
    return body.split(RegExp(r'\s+')).length;
  }

  int _charCount(String body) {
    return body.length;
  }

  Widget _buildRow(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.splineSansMono(
                fontSize: 11,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.splineSansMono(fontSize: 11, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
