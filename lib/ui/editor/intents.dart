import 'package:flutter/widgets.dart';

import '../../logic/formatting.dart';

class FormatIntent extends Intent {
  const FormatIntent(this.kind);

  final FormatKind kind;
}

/// Tab / Shift+Tab — indent or outdent the current line (or every line of
/// a selection) by two spaces. Hard-coded like `Ctrl+B/I/U`; excluded from
/// the settings-driven shortcut surface.

class IndentIntent extends Intent {
  const IndentIntent({required this.indentIn});

  /// `true` = Tab (indent), `false` = Shift+Tab (outdent).
  final bool indentIn;
}

/// Enter pressed inside an editing surface; handled as list continuation.

class ContinueListIntent extends Intent {
  const ContinueListIntent();
}

/// Ctrl+D — select the word at the caret.

class SelectWordIntent extends Intent {
  const SelectWordIntent();
}

/// Ctrl+F — open the find-in-note bar.

class OpenFindIntent extends Intent {
  const OpenFindIntent();
}

/// Enter in the find bar — jump to the next match.

class FindNextIntent extends Intent {
  const FindNextIntent();
}

/// Shift+Enter in the find bar — jump to the previous match.

class FindPrevIntent extends Intent {
  const FindPrevIntent();
}

/// Escape in the find bar — close it and restore editor focus.

class CloseFindIntent extends Intent {
  const CloseFindIntent();
}

/// Slim query bar docked under the editor header: live count, prev/next,
/// Esc to close (spec story 14).
