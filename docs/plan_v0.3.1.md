# Implementation Plan: Sheaf v0.3.1 — "paper cuts"

Derived from `docs/spec.md` v0.2 + `docs/plan_v0.3.md` audit and user brief for next iteration (6 asks). Ordered by dependency; each task lands as its own Conventional Commit behind `flutter analyze` + `flutter test`. No new dependencies.

## Overview

Six paper-cut fixes that block the polished feel of v0.3.0: nested folders silently dropped, find bar that moves selection but not focus, tag chips living outside the editor gutter, scrollbar that never changes cursor or animates, full-width text selection that paints the gutter, and leftover Task 11 (action bar) docs that describe code that never shipped or is untested. All slices are UI-thin; the only pure-logic work is the folder-tree rendering and selection-geometry fix.

- **Nested folders — render what `FolderNode.children` already holds.** `VaultRepository.folderTree()` already builds a recursive `FolderNode(name, relPath, children)` (see `lib/data/vault_repository.dart:208-231`). The bug is in the view: `Sidebar`/`Section`/`FolderRow` only iterates the top-level list. Fix is recursive view with expand/collapse: `FolderRow` becomes `StatefulWidget` with `bool _expanded` (initial `true`), chevron `Icons.chevron_right` rotated 90° when expanded, tap chevron toggles without selecting folder; indent via `Padding(left: depth*16)` and reuse existing `HoverRow`; collapsed state hides `children` subtree. Persist `expanded` per `relPath` in memory only for v0.3.1 (no storage).
- **Find selection & focus — single source of truth.** `EditorPane._jumpToCurrentMatch` already sets `TextSelection` (covers highlight / counter) but never ensures the editable holds focus. The bar's `TextField` steals focus on typing. Fix: after `_jumpToCurrentMatch` call ` _bodyFocus.requestFocus()` and keep `_body.selection` as the highlighted range; `FindBar.onChanged` is debounced 80 ms via existing `_recomputeFind` listener so typing does not thrash focus. `Esc` already closes via `CloseFindIntent` → `_closeFind` which restores `_bodyFocus`; next/prev buttons keep focus in the editor, not the bar.
- **In-editor tag chip — reuse existing `extractTags` + chip style.** The chips currently live in a `Container` above the body (`editor_pane.dart:591-632`). v0.3.1 moves them into the editor column as a dedicated `TagChipBar` widget under the title row (same `Wrap` + `secondaryContainer` pill style) but *inside* the scrollable editor surface so they scroll with content and are reachable in focus mode. No new parsing; just placement + a tap callback that inserts `#tag ` at caret or filters (defer filter to later — tap copies to clipboard for now, keeps scope S).
- **Scrollbar cursor + hover animation — theme-owned.** `ScrollbarThemeData` already exists in `quire_theme.dart:459`. Add `MouseCursor` handling via `MouseRegion` wrapping the `RawScrollbar` thumb (or `Scrollbar` with `thumbVisibility`) and animate `thumbColor` `WidgetStateProperty` with `AnimatedContainer` 150 ms ease. Cursor = `SystemMouseCursors.click` (or `grab`/`grabbing` while dragging). No new dependency; hover detection via `onHover`/`onExit` on the scrollbar track.
- **Word-only selection — constrain the editable's hit area.** Today `EditorPane` wraps the `TextField` in `ConstrainedBox(maxWidth: 680) + Align(topLeft)` inside an `Expanded` that still lets `TextField`'s `RenderEditable` fill the row. Selection highlight therefore paints the full row width. Fix: wrap the editable in `IntrinsicWidth`-style `SizedBox` + `SelectionArea` semantics so the `EditableText`'s width equals its content; alternatively set `TextField`s `expands: false` inside a `SizedBox` constrained to content and use `SelectionContainer.disabled` around the outer padding. Verify with golden: selection rect width ≤ text width + caret.
- **Task 11 docs — delete untested fiction.** `docs/plan_v0.3.md:127-135` describes `EditorActionBar`/`ListKind`/`list_formatting.dart`/`action_bar.dart`/`link_bar.dart` that either never shipped or have no tests. v0.3.1 removes those doc blocks and leaves the real list-continuation behavior (Task 3) as the only list story. No code delete needed if files do not exist; if they do, remove the untested widgets and keep `continueList` logic.
## Task List

### Phase 1 — Data-visible correctness

- [x] **Task 1: Nested folders render recursively with expand/collapse**
  **Description:** Make the folder list show the full tree that `VaultRepository` already returns, indented per depth, with chevron expand/collapse.
  **Acceptance criteria:**
  - [x] Creating `a/b/c` (via `createFolderAt` or on-disk) appears as `a` → `b` → `c` indented in `Sidebar`; `folderTree()` with nested dirs returns `children` matching disk layout.
  - [x] `FolderRow` is `StatefulWidget` with `bool _expanded = false`; chevron `Icons.chevron_right` (rotated 90° when expanded) toggles subtree without selecting folder; collapsed hides `children` `Column`; indent `left: depth*16`.
  - [x] Selecting any nested folder (tap row, not chevron) sets `controller.selectedFolder == relPath` and filters `visibleNotes` to that subtree; expand state is in-memory per `relPath` for v0.3.1.
  **Verification:**
  - [x] `flutter test test/ui/sidebar/sidebar_test.dart` — new case: nested `a/b/c` renders 3 rows with increasing indent; tap `c` selects `a/b/c`; tap chevron on `a` collapses/hides `b/c` and expands again.
  - [x] `flutter test test/data/vault_repository_test.dart` — existing `folderTree` recursion still passes.
  - [x] Manual: `mkdir -p /tmp/vault/a/b/c && flutter run` → indented rows with chevrons, collapse/expand works.
  **Dependencies:** None
  **Files likely touched:**
  - `lib/ui/sidebar/sidebar.dart`
  - `lib/ui/sidebar/widgets/folder_row.dart` (now StatefulWidget)
  - `lib/ui/sidebar/widgets/section.dart`
  - `test/ui/sidebar/sidebar_test.dart`
  **Estimated scope:** S (3-4 files)

### Phase 1b — UX polish (folder creation, sticky header, platform label)

- [x] **Task 7: Select & focus new folder after creation with loading state**
  **Description:** When a user creates a folder via the dialog, the sidebar should select it and show a loading indicator (cursor spinner) while the async operation is in-flight.
  **Acceptance criteria:**
  - [x] `_newFolderDialog` selects the newly created folder via `controller.selectFolder(relPath)` after creation, so the folder tree scopes to it immediately.
  - [x] While `createFolderAt` is running (after dialog closes, before refresh completes), the sidebar shows a loading affordance: `SystemMouseCursors.wait` on the sidebar pane and a small `CircularProgressIndicator` replacing the "new folder" button during the operation.
  - [x] Loading state is `_SidebarState`-local (a `bool _creatingFolder` flag), set `true` before calling `createFolderAt`, `false` after it completes; `ListenableBuilder` rebuilds on `setState`.
  **Verification:**
  - [x] Widget test: pump sidebar, open dialog, enter name, confirm → `selectFolder` called with the new folder's relPath; `_creatingFolder` was `true` during the async gap.
  - [x] Manual: create folder → spinner appears briefly, then folder is selected with highlight.
  **Dependencies:** Task 1
  **Files likely touched:**
  - `lib/ui/sidebar/sidebar.dart`
  - `lib/logic/vault_controller.dart` (add `selectFolder` call in `createFolderAt` or a new wrapper)
  - `test/ui/sidebar/sidebar_test.dart`
  **Estimated scope:** S (2-3 files)

- [x] **Task 8: Sticky FOLDERS section header**
  **Description:** The FOLDERS label, expand/collapse toggle, and new-folder button should stay pinned at the top of the scrollable area so they're always visible when the folder list is long.
  **Acceptance criteria:**
  - [x] The folders header (label + expand/collapse + new-folder button) is extracted from the `SingleChildScrollView` and placed in a fixed position above the scrollable folder list.
  - [x] The folder list scrolls independently underneath the header; empty state ("No folders yet...") also lives in the scrollable area.
  - [x] TAGS section remains below the folder list inside the scrollable area (it scrolls away as expected).
  - [x] No visual regression: padding, divider, and spacing match the current layout.
  **Verification:**
  - [x] Widget test: sidebar with many folders, scroll down → FOLDERS header stays visible at top; TAGS header scrolls out of view.
  - [x] Manual: create 10+ folders, scroll → header pinned.
  **Dependencies:** Task 1
  **Files likely touched:**
  - `lib/ui/sidebar/sidebar.dart`
  **Estimated scope:** XS (1 file)

- [x] **Task 9: Platform-aware folder section label**
  **Description:** On Linux, the FOLDERS section label reads "DIRECTORIES" instead of "FOLDERS" to match platform conventions. Other platforms keep "FOLDERS".
  **Acceptance criteria:**
  - [x] `dart:io` `Platform.isLinux` check in the `Sidebar` build method selects the label string: `'DIRECTORIES'` on Linux, `'FOLDERS'` otherwise.
  - [x] No new dependency; `dart:io` is already available in Flutter on all desktop targets.
  - [x] Label is computed once per build, not stored in state.
  **Verification:**
  - [x] Widget test: verify label text matches platform expectation.
  - [x] Manual: run on Linux → "DIRECTORIES"; macOS/Windows → "FOLDERS".
  **Dependencies:** None
  **Files likely touched:**
  - `lib/ui/sidebar/sidebar.dart`
  **Estimated scope:** XS (1 file)

### Phase 2 — Editor focus & selection

- [x] **Task 2: Find selection & focus**
  **Description:** `Ctrl+F` bar drives selection *and* focus correctly through typing, next/prev, and `Esc`.
  **Acceptance criteria:**
  - [x] `_jumpToCurrentMatch` after setting `TextSelection` calls `_bodyFocus.requestFocus()`; focus stays in `_body` while navigating matches (Enter / Shift+Enter / buttons do not move focus to the bar).
  - [x] Typing in the bar keeps `_recomputeFind` but does not steal editor focus when `_body` had it; bar `onChanged` is debounced and does not call `requestFocus` on the bar.
  - [x] `Esc` (`CloseFindIntent`) closes bar, clears `_findCtrl`, and restores `_bodyFocus`; `_body.removeListener(_recomputeFind)` is always paired.
  **Verification:**
  - [x] `flutter test test/ui/editor/editor_pane_test.dart` — `find in note (spec story 14)` group passes; new case: open bar, type, `Enter` moves highlight without focusing bar; `Esc` returns focus to `editor-body`.
  - [x] Manual: `Ctrl+F` with selection prefill, type query, `Enter`/`Shift+Enter` cycle, `Esc` → caret in editor.
  **Dependencies:** None
  **Files likely touched:**
  - `lib/ui/editor/editor_pane.dart`
  - `lib/ui/editor/widgets/find_bar.dart`
  - `test/ui/editor/editor_pane_test.dart`
  **Estimated scope:** S (2 files)

- [x] **Task 3: Word-only selection (no full-width highlight)**
  **Description:** Restrict the editable's selection paint to the text width, not the container width.
  **Acceptance criteria:**
  - [x] Drafting `TextField` inside `EditorPane` does not paint selection across the full row; the selection is bounded to the prose column; empty gutter is not selectable.
  - [x] Implemented by bounding the body prose column: the body `ConstrainedBox` now uses `maxWidth: 680` (non-focus) / `740` (focus) instead of `double.infinity`. The unbounded box was the actual bug — a `RenderEditable` can only paint a selection as wide as its own box, so a full-pane box let a gutter drag bleed the highlight across the pane. `Align` + `SelectionContainer.disabled` turned out to be unnecessary: the space beyond 680px lies outside the editable's hit area entirely.
  - [x] Second, independent cause: `EditableText.defaultSelectionWidthStyle` is `ui.BoxWidthStyle.max` on non-web platforms, which pads every selected line's boxes out to the widest line in the paragraph — exactly the reported multi-line symptom. The body field now passes `selectionWidthStyle: ui.BoxWidthStyle.tight`.
  - [x] Preview mode unaffected (the constraint sits above the mode switch).
  **Verification:**
  - [x] Widget tests: `body selection is bounded to the prose column, not the pane` asserts `renderEditable.size.width < pane width` and `<= 680`; `body field uses tight selection boxes so multi-line highlight hugs text` asserts `selectionWidthStyle == ui.BoxWidthStyle.tight`. Whole file green (39/39).
  - [x] Manual: drag across gutter → no selection; drag across words → word-local highlight.
  **Dependencies:** Task 2 (focus correctness before selection geometry)
  **Files likely touched:**
  - `lib/ui/editor/editor_pane.dart`
  - `lib/ui/editor/widgets/` (if extraction)
  **Estimated scope:** S (1-2 files)

### Phase 3 — Chips & chrome

- [x] **Task 4: Onclick to focus tag chip bar**
  **Description:** Move tag chips from the standalone container above the body into a proper `TagChipBar` inside the editor column.
  **Acceptance criteria:**
  - [x] New `lib/ui/editor/widgets/tag_chip_bar.dart` (`TagChipBar extends StatelessWidget`) renders `Wrap` of pill chips from `extractTags(bodyText)` with same `secondaryContainer` style as before; appears directly under the title/header inside the scrollable editor column (scrolls with content, visible in focus mode).
  - [x] Old `Container` at `editor_pane.dart:591-632` removed; `TagChipBar` replaces it; `lib/data/markdown_parser.dart:extractTags` is the only tag source (no forked regex).
  - [x] Tapping a chip focus `#tag ` in the editor; hover shows 'Go to #tag' tooltip.
  **Verification:**
  - [x] `flutter test test/ui/editor/editor_pane_test.dart` — chips render for `#a #b`, tap inserts text at caret.
  - [x] Manual: open note with `#urgent #proj` → chips under title, scroll with body, tap chip → text inserted.
  **Dependencies:** None (parallel with Task 2/3)
  **Files likely touched:**
  - `lib/ui/editor/widgets/tag_chip_bar.dart` (new)
  - `lib/ui/editor/editor_pane.dart`
  - `test/ui/editor/editor_pane_test.dart`
  **Estimated scope:** S (2-3 files)

- [ ] **Task 5: Scrollbar cursor shape + hover animation**
  **Description:** Scrollbar thumb shows correct cursor and animates on hover/drag.
  **Acceptance criteria:**
  - [ ] Scrollbar thumb `MouseRegion` cursor = `SystemMouseCursors.click` on hover, `SystemMouseCursors.grabbing` while dragging; track cursor = `SystemMouseCursors.basic`.
  - [ ] Thumb color animates `thumbColor` 150 ms ease on hover/drag via `ScrollbarThemeData` or `AnimatedContainer`; inactive `alpha 0.28` → hover `alpha 0.45` → dragging `alpha 0.6`.
  - [ ] Works in `Shell`'s scroll views and `EditorPane`'s body `SingleChildScrollView`/`ListView`; no cursor flicker on theme switch.
  **Verification:**
  - [ ] Widget test: hover scrollbar thumb → `MouseRegion` cursor changes; pump 150 ms → color lerp.
  - [ ] Manual: hover scrollbar in editor/list → thumb darkens and cursor becomes hand; drag → grabbing.
  **Dependencies:** None
  **Files likely touched:**
  - `lib/theme/quire_theme.dart`
  - `lib/ui/editor/editor_pane.dart` (scrollbar wrapper)
  - `lib/ui/note_list/list_pane.dart`
  - `lib/ui/shell/shell.dart`
  **Estimated scope:** S (3-4 files)

### Phase 4 — Docs hygiene

- [x] **Task 6: Remove untested Task 11 action-bar fiction**
  **Description:** Delete the `EditorActionBar`/`ListKind`/`link_formatting` docs that describe unshipped/untested code and keep only the real list behavior.
  **Acceptance criteria:**
  - [x] `docs/plan_v0.3.md:127-144` (Task 11 & Task 12 blocks) edited: if `lib/ui/editor/action_bar.dart` / `lib/logic/list_formatting.dart` / `link_bar.dart` have no tests and are not wired, remove those Task sections and replace with a one-line note: "List action bar deferred — list continuation (Task 3) is the shipped list behavior."
  - [x] No code left that is both untested and unreferenced; `flutter analyze` clean, `grep -R ActionBar lib` empty after the doc cut (or file deleted).
  - [x] `docs/spec.md` not re-adding a spec story for the bar; deferred list lives in Spec's deferred list if needed.
  **Verification:**
  - [x] `grep -R "ActionBar\|ListKind" docs/` shows only the deferral note.
  - [x] `flutter analyze` + `flutter test` still green.
  **Dependencies:** Tasks 1-5 (so grep scope is final)
  **Files likely touched:**
  - `docs/plan_v0.3.md`
  - `lib/ui/editor/action_bar.dart` (delete if exists)
  - `lib/logic/list_formatting.dart` (delete if exists & untested)
  **Estimated scope:** XS (1-2 files)

### Phase 5 — Build & Distribution

- [x] **Task 10: AppImage build for Linux**
  **Description:** Create a script to package the Flutter Linux build as a portable AppImage.
  **Acceptance criteria:**
  - [x] Script `scripts/build_appimage.sh` exists and is executable.
  - [x] It runs `flutter build linux --release`, then uses `linuxdeploy` and `linuxdeploy-plugin-gtk` to create `Sheaf.AppImage`.
  - [x] The AppImage runs on a clean Ubuntu 22.04 system without additional dependencies.
  - [x] The script exits with a clear error if prerequisites are missing.
  **Verification:**
  - [x] Run `scripts/build_appimage.sh` – produces `Sheaf.AppImage` in the project root.
  - [x] Test the AppImage on a fresh Linux VM: `./Sheaf.AppImage` launches the app.
  **Dependencies:** None
  **Files likely touched:**
  - `scripts/build_appimage.sh` (new)
  - `.gitignore` (add `Sheaf.AppImage`)
  - `.github/workflows/release.yml` (new)

### Checkpoint: v0.3.1 complete
- [ ] `flutter analyze` clean
- [ ] `flutter test` green (new cases: nested folders, find focus, word-only selection, tag chips, scrollbar hover)
- [ ] Manual smoke: (a) `a/b/c` nested, (b) `Ctrl+F` focus stays in editor, (c) tag chips scroll with editor, (d) scrollbar hand cursor + fade, (e) gutter drag does not select, (f) no ActionBar fiction in docs

## Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Recursive FolderRow creates deep widget tree (>10 levels) | Med | `ListView` with fixed indent; Flutter handles 20-depth Column — add `SingleChildScrollView` only if overflow; cap recursion depth 12 in view. |
| Word-only selection breaks triple-click line selection | Med | Keep `RenderEditable` line-select behavior; constrain only the paint area, not the gesture arena; test triple-click. |
| Find focus fight with bar TextField | Low | Bar field uses `onChanged` only; editor focus is always restored after `_jumpToCurrentMatch`; no `autofocus` on FindBar. |
| Tag chip insertion conflicts with autosave debounce | Low | Chip tap does `_body.value = ...` then `controller.updateBody`; autosave 1s debounce coalesces — no extra flush. |
| Docs deletion hides real intent for future action bar | Low | Keep one-sentence deferral note with ADR link placeholder. |
| Loading spinner race: folder created but refresh hasn't returned yet | Low | `_creatingFolder` state is scoped to `_SidebarState`; `setState` after completion always clears it. |
| Sticky header increases Sidebar complexity | Low | Simple `Column` split: header outside `Expanded`, scrollable list inside `Expanded`. No new widget. |
| `Platform.isLinux` returns true inside Flutter test on Linux host | Low | Acceptable — test verifies correct label on the host platform; CI on Linux confirms "DIRECTORIES". |
