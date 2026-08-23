/// Result of splicing an image link into a note body.
class SpliceResult {
  const SpliceResult({required this.text, required this.caret});
  final String text;
  final int caret;
}

/// Inserts [link] into [body] at [offset] (clamped), returning the new text
/// and the caret position right after the inserted link.
SpliceResult insertImageLink({required String body, required String link, int offset = -1}) {
  var at = offset;
  if (at < 0 || at > body.length) at = body.length;
  final text = body.replaceRange(at, at, link);
  return SpliceResult(text: text, caret: at + link.length);
}
