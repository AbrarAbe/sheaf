import 'package:flutter/services.dart';

/// A snapshot of the editor's text and selection at a single moment.
class UndoEntry {
  const UndoEntry(this.text, this.selection, this.timestamp);

  final String text;
  final TextSelection selection;
  final DateTime timestamp;
}

/// Per-note undo/redo history with a fixed depth cap and a time-based
/// coalesce window.
///
/// Model: a linear list of states, with a cursor pointing at the current
/// one. When a note is opened, its current text is seeded as the
/// "before any edits" state at index 0. Each subsequent edit either
/// appends a new state or merges into the last one (when the previous
/// entry was recorded less than [coalesceWindow] ago — this is the
/// "undo per word, not per character" behavior). Undo moves the cursor
/// back; redo moves it forward. The redo branch is discarded on the
/// next edit after an undo (standard linear-history semantics).
class UndoHistory {
  UndoHistory({this.maxDepth = 50, this.coalesceWindow = const Duration(milliseconds: 800)});

  /// Maximum number of entries retained. Older entries are evicted FIFO.
  final int maxDepth;

  /// When two edits arrive within this window of each other (and the
  /// text is a prefix-extension of the previous entry), they merge into a
  /// single undo step. This is what makes typing feel like "undo one
  /// word" rather than "undo one character". Formatting and list-edit
  /// operations fall outside this window in practice, so they always
  /// record their own step.
  final Duration coalesceWindow;

  final List<UndoEntry> _entries = [];
  int _cursor = -1;

  bool get canUndo => _cursor > 0;
  bool get canRedo => _cursor >= 0 && _cursor < _entries.length - 1;
  bool get isEmpty => _entries.isEmpty;

  /// The current state, or null when no state has been recorded.
  UndoEntry? get current => _cursor >= 0 ? _entries[_cursor] : null;

  /// Records the current text as the baseline. Call once when a note is
  /// opened. Subsequent [setState] calls build on top of this.
  void seed(UndoEntry entry) {
    _entries
      ..clear()
      ..add(entry);
    _cursor = 0;
  }

  /// Records [entry] as the new current state. When the previous entry
  /// was recorded less than [coalesceWindow] ago, the new text merges
  /// into it (typewriter undo). Otherwise it appends a fresh step. When
  /// the cursor is not at the tail, any redo branch is discarded before
  /// appending.
  ///
  /// Pass [coalesce] as false to force a distinct step even when the
  /// timing window is open — useful for programmatic edits that should
  /// always be their own undo step (formatting, indent, list
  /// continuation). The default (true) lets typing feel like "undo one
  /// word" rather than "undo one character".
  void setState(UndoEntry entry, {bool coalesce = true}) {
    if (_cursor < 0 || _entries.isEmpty) {
      _entries.add(entry);
      _cursor = 0;
      return;
    }
    if (_entries[_cursor].text == entry.text) return;
    // Coalesce: replace the previous entry when the timing window is open.
    // The previous entry's timestamp is preserved so that a longer typing
    // run keeps coalescing into the same step. The baseline (seed) is never
    // coalesced — undo must always be able to return to the note-as-opened
    // state.
    final isBaseline = _cursor == 0 && _entries.length == 1;
    final atTip = _cursor == _entries.length - 1;
    if (coalesce &&
        !isBaseline &&
        atTip &&
        _withinCoalesce(_entries[_cursor].timestamp, entry.timestamp)) {
      _entries[_cursor] = UndoEntry(
          entry.text, entry.selection, _entries[_cursor].timestamp);
      return;
    }
    if (_cursor < _entries.length - 1) {
      _entries.removeRange(_cursor + 1, _entries.length);
    }
    _entries.add(entry);
    _cursor = _entries.length - 1;
    if (_entries.length > maxDepth) {
      _entries.removeRange(0, _entries.length - maxDepth);
      _cursor = _entries.length - 1;
    }
  }

  bool _withinCoalesce(DateTime a, DateTime b) {
    final delta = b.difference(a);
    // Only coalesce forward in time (a new timestamp always ≥ previous).
    return delta.isNegative ? false : delta < coalesceWindow;
  }

  /// Moves the cursor back one step and returns the new current state, or
  /// null when there is nothing to undo.
  UndoEntry? undo() {
    if (!canUndo) return null;
    _cursor -= 1;
    return _entries[_cursor];
  }

  /// Moves the cursor forward one step and returns the new current state,
  /// or null when there is nothing to redo.
  UndoEntry? redo() {
    if (!canRedo) return null;
    _cursor += 1;
    return _entries[_cursor];
  }

  /// Clears the history entirely.
  void clear() {
    _entries.clear();
    _cursor = -1;
  }
}
