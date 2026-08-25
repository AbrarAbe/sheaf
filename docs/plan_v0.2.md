# Implementation Plan: Sheaf v0.2 — "the editor"

Derived from `docs/spec.md` stories 10–16. Ordered by dependency; each task
lands as its own Conventional Commit after analyze+test gates.

## Overview

Six feature areas: keyboard bindings, 3-mode editor, component audit fixes
(pin/find), pane control + fullscreen, appearance customization. Foundation
tasks (settings schema, pure-logic engines) come first so UI slices stay thin.

## Architecture Decisions

- **Pin state in `.sheaf/meta.json`** — keeps note files pristine/portable;
  mirrors the existing `.trash/index.json` precedent. (ADR)
- **Zoom** = global text scaler applied at the app root (`MediaQuery`);
  every surface scales together, crisp at any factor. Fixed-dp icons and
  layout metrics stay constant (scaling painted pixels would blur them).
  Editor font size is the separate per-editor control. (ADR)
- **Theme worlds registry** in `lib/theme`: `worlds: Map<String, World>`
  where `World` = light/dark `ThemeData` builders; settings gain
  `(worldId, mode)` replacing bare mode; migration maps old values to
  `(quire, oldMode)`. (ADR)
- **Fonts**: scan standard dirs for `.ttf/.otf/.ttc`, load chosen file once at
  startup via `FontLoader`, register under a stable family name
  (`SheafUserFont`); settings store family display name + path.
- **Editor modes** replace `_preview` bool with an enum owned by
  `EditorController` (persisted), so shell shortcuts can act on it without
  widget-state reach-arounds.

## Task List

### Phase 1 — Foundations

- [x] **Task 1: Settings schema v2**
  Add to `AppSettings`: `editorMode`, `zoomFactor`, `editorFontSize`,
  `fontFamily`/`fontPath`, `themeWorld`; keep `theme` (mode). Tolerant
  `fromJson` (old JSON → defaults; unknown world → quire).
  - Acceptance: round-trip tests; v0.1 settings.json loads unchanged behavior.
  - Verify: `flutter test test/data test/models`
  - Files: `lib/models/settings.dart`, `lib/data/settings_repository_test.dart`
  - Scope: S

- [x] **Task 2: Zoom engine + global wiring**
  `ZoomController` (factor get/set/step/reset, clamp 0.5–2.0 step .1,
  persist via controller). SheafApp wraps home in `MediaQuery(textScaler)`
  override. Shortcuts `Ctrl+=`, `Ctrl+-`, `Ctrl+0`.
  - Acceptance: keys adjust scale within bounds and persist; restart keeps it.
  - Verify: unit tests + shortcut widget test.
  - Files: `lib/logic/zoom_controller.dart` (new),
    `lib/app.dart`, `lib/ui/shell/shortcuts.dart`, tests.
  - Scope: M

- [x] **Task 3: Formatting engine (pure logic)**
  `lib/logic/formatting.dart`: `toggleWrap(text, selection, marker)` handling
  selected text, collapsed caret, and already-wrapped unwrap. Markers:
  `**`, `*`, `<u>`…`</u>`.
  - Acceptance: table of cases green incl. nested/partial overlaps.
  - Verify: `flutter test test/logic/formatting_test.dart`
  - Files: new logic file + test.
  - Scope: S

- [x] **Task 4: Preview renders `<u>` only**
  Minimal inline pass converting `<u>x</u>` → underlined span; all other
  `<` stays literal.
  - Acceptance: `<u>hi</u>` underlines; `<script>` shows literally.
  - Verify: markdown_preview_test additions.
  - Files: `lib/ui/editor/markdown_preview.dart` + test.
  - Scope: S

### Phase 2 — Editor modes & keys

- [x] **Task 5: Three editor modes**
  `EditorMode {normal, markdown, preview}` on `EditorController` (persisted);
  segmented control in header replaces preview toggle; Normal = current
  proportional field + formatting enabled; Markdown = Spline Sans Mono raw;
  Preview = rendered. `Ctrl+Shift+M` cycles.
  - Acceptance: switch renders correct surface; autosave fires in all modes;
    mode persists across restart.
  - Verify: widget tests per mode + persistence test.
  - Files: `lib/logic/editor_controller.dart`, `lib/ui/editor/editor_pane.dart`,
    `shortcuts.dart`, `shell.dart`, tests.
  - Scope: M

- [x] **Task 6: Formatting keybindings in editor**
  Editor-scoped `Shortcuts/Actions`: Ctrl+B/I/U call formatting engine on the
  live body controller (Normal mode only); `Ctrl+Shift+C/V` copy/paste
  terminal-style on focused editable.
  - Acceptance: wrap/unwrap through real TextField selection; inert in
    Markdown/Preview.
  - Verify: widget tests driving selections.
  - Files: `editor_pane.dart`, tests.
  - Scope: M (depends 3, 5)

- [x] **Task 7: List continuation on Enter**
  Pure logic `continueList(text, caretOffset)`: carries `- `/`* `/`- [ ] `
  markers, increments ordered numbers, preserves indentation; empty-marker
  line clears instead. Wired into body field's newline handling in editing
  modes.
  - Acceptance: unit cases for each marker type + nesting + smart exit;
    Enter through real TextField continues lists.
  - Verify: logic tests + editor widget test.
  - Files: `lib/logic/list_continuation.dart` (new), `editor_pane.dart`,
    tests.
  - Scope: S (depends 5)

- [x] **Task 8: Ctrl+Tab note cycling**
  Shell action selects next/prev note in displayed list order (wraps);
  disabled when list empty.
  - Acceptance: order matches visible list incl. pinned group after Task 10.
  - Verify: widget test on spy controller.
  - Files: `shortcuts.dart`, `shell.dart`, tests.
  - Scope: S

- [x] **Task 9: Find-in-note bar**
  `FindController` (pure scan → match offsets) + find bar widget docked over
  editor header. Ctrl+F opens (pre-fill selection), Enter/Shift+Enter/buttons
  traverse with caret jump + counter, Esc closes restoring focus.
  - Acceptance: counts case-insensitive matches; traversal wraps; works
    Normal+Markdown.
  - Verify: logic unit tests + widget test.
  - Files: `lib/logic/find_controller.dart` (new), `editor_pane.dart`, tests.
  - Scope: M

### Phase 3 — Panes, pinning, fullscreen

- [x] **Task 10: User-owned sidebar visibility**
  `PaneWidths` gains per-tier visibility model; Full tier drops forced rail
  (toggle hides completely); Stack tier drawer toggle; header menu button
  always present; persist per tier.
  - Acceptance: each tier honors story 15; states survive restart.
  - Verify: shell widget tests across tiers.
  - Files: `pane_widths.dart`, `shell.dart`, tests.
  - Scope: M

- [x] **Task 11: Pinning**
  VaultRepository meta.json API (load/save/corrupt-recover, drop-on-delete);
  VaultController pin toggles; ListPane Pinned section + filled-pin indicator +
  working hover button + context-menu entry.
  - Acceptance: pin persists, sorts first, unpin restores, delete cleans up.
  - Verify: repo round-trip tests + list widget tests.
  - Files: `vault_repository.dart`, `vault_controller.dart`, `list_pane.dart`,
    `context_menus.dart`, tests.
  - Scope: L (split if needed)

- [x] **Task 12: Focus mode + OS fullscreen**
  Focus-mode header button + `F10` hides sidebar+list (editor fills window);
  `F11` via `window_manager` toggles native fullscreen.
  - Acceptance: focus collapses/expands cleanly from any tier; F11 fullscreens
    on Linux desktop.
  - Verify: widget tests (F10 path); manual F11 check on running app.
  - Files: `shell.dart`, `pubspec.yaml`, `main.dart`, tests.
  - Scope: M

### Checkpoint A (after Task 9): ✅ REACHED 2026-08-24 — modes+keys usable end-to-end; analyze clean, 194 tests green.

### Feedback round 1 (2026-08-24, post-checkpoint)

- [x] **F1: toggle unwrap anywhere** — Ctrl+B/I/U unwraps when the caret or
  any partial selection sits inside a wrapped span (was: exact selection only).
- [x] **F2: formatting keys in Markdown mode too** — both editing modes share
  keybindings; modes differ visually only.
- [x] **F3: preview top-aligned** — rendered output was vertically centered
  by the shared Center wrapper; align top-left (horizontal centering kept).
- [x] **F4: Normal mode renders formatting live** — styled spans via a
  TextEditingController.buildTextSpan highlighter; markers dimmed, not hidden.

### Feedback round 2 (2026-08-24)

- [x] **F5: hide markers until touched** — in Normal view `#`/`*`/`` ` ``/`<u>`
  markers render zero-width while the caret is elsewhere; touching the span
  reveals them dimmed (upgrades F4 to true live-preview).
- [x] **F6: Ctrl+D selects the word at the caret** (editing modes).
- [x] **F7: Del rescoped** — global note-delete binding removed; Del edits
  text when an editor holds focus, deletes the note only from the list pane.
- [x] **F8: undo toast → bottom-right corner toast** ✅ done (option a).
- [x] **F9: bare caret on a word wraps the word** — Ctrl+B/I/U with a
  collapsed caret over word text wraps that word (no more `****` splices;
  also fixes the invisible dead-toggle on Ctrl+U).
- [x] **F10: corner toast ships hand-rolled** (`lib/ui/common/corner_toast.dart`)
  after delightful_toast proved unable to anchor bottom-right.

### Feedback round 4 (2026-08-25)

- [x] **F11: untoggle shrinks selection from the right** — closed below as
  round-5 item F20 (same root cause, fixed together with the sweep).

### Feedback round 5 (2026-08-25) — header, search, menus, correctness

All items stay inside the v0.2 milestone; the release tag waits until these
are green.

- [ ] **F12: ⌘K quick-switcher** — restore the header search pill, now
  functional: overlay palette with autofocus field, ↑/↓ + Enter/Esc, mouse
  rows; empty query lists notes newest-first so row 1 = last edited;
  ranking reuses `searchAndSort`; `Ctrl+K` global binding.
- [ ] **F13: retire the list-filter search** — vault-wide search moves to
  ⌘K; the filter field + list-level `Ctrl+F` go away; slot becomes a
  removable scope chip shown when a folder/tag filter is active.
- [x] **F14: focus-mode button joins the right cluster** — sits beside the
  dark/light toggle; left side keeps sidebar toggle + wordmark.
- [x] **F15: functional traffic-light dots** — minimize/maximize-or-restore/
  close via an injectable `WindowControls` seam (production = window_manager);
  colors reuse QuireColors tokens (alert/pin/grow — zero new hex); Settings
  gains "show window controls" (default on).
- [ ] **F16: trash timestamps** — surface the existing `trashedAt`:
  relative label beside the title, full date in tooltip.
- [ ] **F17: tabs vs All-notes** — design proposal only (open-notes tab
  strip vs creation-scope rules); user picks direction before any code.
- [ ] **F18: context-menu restyle** — package defaults reserve 32px gutters
  and wash labels to 70% alpha; ship a custom menu-item entry (30px rows,
  full-contrast Hanken labels, mono shortcuts, destructive tint, themed
  container radius/border/shadow) behind the existing `quireMenu` API.
- [x] **F19: remove the local-font feature** — drop `fontFamily`/`fontPath`
  settings, typeface picker, FontLoader startup step, scanner; old settings
  JSON with those keys must keep loading.
- [x] **F20: fix formatting toggles (closes F11)** — `_enclosingSpan`
  containment misses selections touching marker chars → silent re-wrap →
  nested markers → right-shrink drift. Unwrap on overlap/touch/envelope,
  skip degenerate empty-inner matches, piecewise offset remap; failing-first
  cycle tests for B/I/U.

### Checkpoint B (after Task 12): ✅ code complete 2026-08-25 — widget tests cover F10 + fullscreen seam; manual F11 native check pending on running app.

### Phase 4 — Appearance & audit polish

- [x] **Task 13: Theme worlds**
  `lib/theme/worlds.dart` registry; add Graphite + Sepia token sets; settings
  dialog: world picker + System/Light/Dark radio; migrate old setting.
  - Acceptance: ≥3 worlds render both modes; no hex outside lib/theme;
    old settings load as Quire.
  - Verify: theme tests + settings dialog test.
  - Files: `lib/theme/*`, `settings_dialog.dart`, models/tests.
  - Scope: M

- [x] **Task 14: Typography & zoom settings UI**
  Settings Appearance section: default zoom %, editor size slider (12–24),
  font dropdown from `FontScanner`; startup loads chosen font via FontLoader
  with silent fallback.
  - Acceptance: choices apply immediately and persist; missing font falls back.
  - Verify: scanner unit tests (fixture dirs), dialog widget test.
  - Files: `lib/data/font_scanner.dart` (new), `app.dart`/`main.dart`,
    `settings_dialog.dart`, editor styles, tests.
  - Scope: L

- [x] **Task 15: Component audit fixes**
  Sweep findings from spec review: remove decorative fake window dots (SSD
  titlebar already exists), wire or remove dead "⌘K" search pill, verify
  divider hitpoints, QUIRE badge decision, empty-state copy consistency.
  Present diff-level findings before applying.
  - Acceptance: no dead controls remain; audit notes recorded.
  - Verify: widget tests updated; manual sweep on running app.
  - Files: `shell.dart`, `header` widgets, tests.
  - Scope: M

- [x] **Task 16: Docs & release prep**
  ADRs (meta.json sidecar, zoom model, theme worlds), README feature list,
  archive plan, final gates + coverage report.
  - Acceptance: docs merged; all gates green.
  - Verify: `flutter analyze && flutter test --coverage`.
  - Files: `docs/adr/*`, `README.md`, `docs/plan_v0.2.md`.
  - Scope: S

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| window_manager API drift / Linux quirks | Med | Isolate behind small service; F11 degrades gracefully |
| FontLoader family naming mismatch | Med | Register explicit family name; fallback stack on failure |
| EditorPane rewrite regressions | High | Keep _EditorState structure; mode swap swaps body widget only |
| meta.json corruption | Low | Recover-to-empty + rewrite on parse error (trash precedent) |
| Theme refactor touches many files | Med | Worlds additive; Quire stays default; golden-free tests |

## Open Questions

None — all four resolved 2026-08-24; see spec "Decisions".
