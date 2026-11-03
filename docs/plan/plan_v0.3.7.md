# Implementation Plan: Sheaf v0.3.7 — "tactile"

Interaction-polish bundle: give the pointer a consistent, responsive language
across the app. Derived from the v0.3.7 brief (pinned toggle, cursor
affordances, folder auto-expand, selectable note info, caret-accurate
right-click, optional native-window popups). Each task lands as its own
Conventional Commit behind `flutter analyze` + `flutter test`.

Branch: `feature/v0.3.7` (bundle — several related behaviors reviewed together).

## Overview

Five mostly-independent behavior changes plus one optional investigation. The
unifying goal is that the app responds visibly and predictably to the pointer:
buttons show a hand cursor, in-flight operations show a busy cursor, navigating
folders opens them, metadata is copyable, and a right-click lands exactly where
you clicked.

- **Pinned list expand/hide.** The PINNED section gets a toggle so it can be
  collapsed to just the eyebrow (freeing vertical space) or expanded to the
  rows, persisted across restarts.
- **Cursor affordances.** Hand cursor on every tappable control; busy cursor
  during async work (create note/folder, delete, etc.).
- **Auto-expand folder on selection.** Selecting a collapsed folder reveals its
  children instead of requiring a second click on the chevron.
- **Selectable note-info content.** Title/filename/path/dates in the note-info
  dialog become selectable and copyable.
- **Caret-accurate right-click.** Right-clicking in the note body moves the
  caret to that exact character and opens the edit menu there.
- **(Optional) native-window popups.** Investigate the current Flutter window
  APIs for hosting modals/settings in a real native window; implement only if
  clean. Default: investigation + recommendation, not a forced rewrite.

## Architecture Decisions

- **Cursors are applied last.** The cursor task wraps the *final* widgets of
  every other task (list rows, sidebar rows, editor field, dialogs). Running it
  after the structural changes avoids edit collisions and double-wrapping, so it
  is deliberately sequenced last even though it touches the most files.
- **Pinned-collapse is a settings-backed UI preference**, following the
  existing pattern (`setShowWindowControls` → `AppSettings.copyWith` →
  `_settingsRepo.save`), not per-vault state. Default expanded, so existing
  layouts are unchanged on upgrade.
- **Note-info selectability uses Flutter's selection APIs** (`SelectionArea` /
  `SelectableText`) rather than hand-rolled copy buttons, so selection + Ctrl+C
  behave natively.
- **Right-click caret repositions before the menu anchors.** The edit menu
  already anchors to the caret (`showBodyEditMenu` → `_anchorFor`). So the fix is
  to move the caret to the tapped offset first (via the field's text-position
  lookup), then let the existing anchored menu open there — no new menu code.
- **No new dependencies** for the five in-scope tasks. The optional window task
  is investigation-only unless a clean, already-supported API emerges.

## Tasks

Each task = one checkbox group = one commit. Scope is `S` unless noted; all on
`feature/v0.3.7`.

### Task 1 — Pinned list expand/hide toggle
- [x] Add a collapse/expand affordance to the PINNED eyebrow row in the list pane.
- [x] Collapsed state shows only the PINNED eyebrow (rows hidden); expanded shows the rows.
- [x] Persist the state as an `AppSettings` flag (default expanded) via the existing settings-save path.
- [x] Toggle control shows a hand cursor.
- [x] `analyze_files` clean; widget test asserts rows hide/show and state round-trips through settings.
- Files: `lib/ui/note_list/list_pane.dart`, `lib/models/settings.dart`, `lib/logic/vault_controller.dart`.
- Test: `test/ui/note_list/` (extend the list-pane widget test).

### Task 2 — Hand cursor on tappable controls
- [ ] Every tappable control shows `SystemMouseCursors.click` on hover.
- [ ] Reuse the existing `MouseRegion(cursor: ...)` pattern (see `win_dot.dart`, `palette_row.dart`, `drag_divider.dart`); add wrappers where absent.
- [ ] `analyze_files` clean; widget tests assert the cursor annotation on a representative button per surface.
- Files (non-exclusive): `lib/ui/note_list/widgets/note_row.dart`, `lib/ui/sidebar/widgets/hover_row.dart`, `lib/ui/shell/widgets/*`, `lib/ui/dialogs/*`.
- Test: extend per-surface widget tests.

### Task 3 — Auto-expand folder on selection
- [x] Selecting a collapsed folder with children expands it to reveal subfolders.
- [x] Chevron/expand affordance still works independently (manual toggle not broken).
- [x] `analyze_files` clean; widget test asserts a collapsed parent expands on select.
- Files: `lib/ui/sidebar/sidebar.dart`.
- Test: `test/ui/sidebar/`.

### Task 4 — Selectable note-info content
- [x] Note-info dialog values (title, filename, path, dates, counts) are selectable and copyable.
- [x] Keep the existing layout/typography; wrap the value column in a selection surface.
- [x] `analyze_files` clean; widget test asserts a selection surface / `SelectableText` is present.
- Files: `lib/ui/dialogs/note_info.dart`.
- Test: `test/ui/dialogs/note_info_test.dart` (extend).

### Task 5 — Caret-accurate right-click in the note body
- [x] Secondary-clicking in the note body moves the caret to the exact tapped character.
- [x] The Quire edit menu opens anchored at that position (reuse `showBodyEditMenu`).
- [x] Existing selection behavior (cut/copy of an active selection) is preserved when the right-click is within a selection.
- [x] `analyze_files` clean; widget test asserts the caret offset matches the tapped position.
- Files: `lib/ui/editor/editor_pane.dart`, `lib/ui/editor/edit_menu.dart`.
- Test: `test/ui/editor/`.

### Task 6 (stretched, optional) — Busy cursor during async operations
- [ ] Show `SystemMouseCursors.wait` while a note/folder is being created or a note deleted.
- [ ] Follow the existing `_creatingFolder` wait-cursor precedent in the sidebar.
- [ ] `analyze_files` clean; widget test asserts the wait cursor during an in-flight op.
- Files: `lib/ui/sidebar/sidebar.dart`, `lib/ui/note_list/*`, `lib/ui/shell/*`.
- Sequenced after Tasks 1–5 so it wraps their final widgets.
- Test: extend per-surface widget tests.

### Task 7 (optional) — Native-window popups (investigation)
- [ ] Survey the current Flutter window APIs (multi-window / native window support) for hosting modals and the settings dialog as real OS windows.
- [ ] Produce a short feasibility note in `docs/ideas/`: what's supported today, effort, risk, and a recommend/do-not-recommend.
- [ ] No product code changes unless the note concludes there is a clean path AND the user opts in.
- Scope: `XS` (investigation/spike). Deliverable is the note + a recommendation.

## Verification (per task)

- `analyze_files` (or `flutter analyze`) clean.
- `flutter test` green relative to the v0.3.6 baseline; no new failures/skips.
- `impact` before editing shared symbols; `detect_changes` before each commit.
- Parent verifies each delegated task's diff before folding it in.

## Revisions

- v0.3.7 (in flight) — initial plan. Cursor work split into Task 2 (hand
  cursor) and Task 6 (busy cursor) and both sequenced after the structural
  tasks so they wrap final widgets without colliding on shared files.
