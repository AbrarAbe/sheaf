# Implementation Plan: Sheaf v0.3.4 — "sticky state"

Derived from `docs/spec.md` v0.3.3 brief. Ordered by dependency; each task
lands as its own Conventional Commit behind `flutter analyze` + `flutter test`.
No new dependencies.

## Overview

Five paper cuts around state that should survive navigation — undo history,
scroll position, and small rendering nits:

- **Undo history persists across note and mode switches.** The current
  in-note Ctrl+Z works, but switching notes (Ctrl+Tab) or cycling modes
  drops the history. Cache the undo/redo stack per note so returning to a
  note restores the history; and keep it alive across mode switches.
- **Preview scroll position survives mode cycles.** Moving Normal → Preview
  → Normal currently snaps the preview back to the top because the shared
  `_bodyScroll` controller is dropped between modes. Cache the offset per
  note; add a "go to top" FAB to the preview for quick recovery.
- **Wrapped text in lists aligns like preview mode.** Two interpretations
  are possible; the plan assumes the user wants wrapped list text to align
  with the first line of *content* (a hanging indent) in both the editor
  and the preview, so the marker doesn't visually indent the wrapped lines.
  If the user meant the opposite (align with marker, as it renders today),
  the change is reverted at review time.
- **`.attachments/` is hidden.** The vault attachments directory gains a
  leading dot so it stops appearing in file browsers and OS searches.
- **Link color uses the theme accent.** Markdown links in the preview were
  using the widget's default color; wire them to `colorScheme.primary`.

## Architecture Decisions

- **Undo history is per-note, in-memory only.** Following the caret memory
  pattern from v0.3.3 Task 7 (`EditorController._caretByPath`), the undo
  stack is keyed by note path on `EditorController`. Nothing is written to
  disk. Each history entry is `(text, selection, timestamp)`; undo/redo
  pop/push from the current stack. Native Ctrl+Z in `EditableText` is
  preserved for the current note's session — the custom handler only kicks
  in when there's no native history available (cross-note/mode cases) or
  when the user hits Ctrl+Shift+Z for redo.
- **Cross-note undo does not cross note boundaries.** Undo never traverses
  from note A's history into note B's. Each note has an independent stack;
  switching notes archives the current stack into the cache and loads the
  target's stack.
- **Scroll offset cache is per-note, in-memory only.** Same shape as the
  undo cache. The offset is captured on every mode switch and on note
  switch; restored on return. Preview-only position is separate from edit
  mode because the layouts differ (raw text vs rendered blocks).
- **Mode switch is not a note switch.** Caching is keyed by note path;
  within a note, the same cached history is used across all three modes.
  Only the preview-vs-edit offset splits — the layout dimensions differ
  enough that an absolute pixel offset wouldn't transfer correctly.
- **`.attachments` is a vault-level directory**, sibling of `.trash/` and
  `.sheaf/`. Existing `attachments/` directories are migrated on first
  vault open.
- **List wrap alignment uses the marker column's own width.** The plan
  assumes the editor and preview both render wrapped list text with a
  hanging indent (aligned to the start of the first line's *content*, not
  the marker). The exact mechanism for the preview is a `ListConfig`
  tweak; for the editor it's a layout/alignment change in the highlighted
  source view.
- **Link color is a config change, not a widget override.** `LinkConfig`
  takes a `style` parameter; wiring it to `theme.colorScheme.primary`
  keeps it consistent with the rest of the preview's Quire theming.

## Task List

### Phase 1 — Undo history persists

- [x] **Task 1: Cache undo/redo per note and restore on open**
  **Description:** Add a per-note undo/redo history to `EditorController`,
  following the same in-memory pattern as `_caretByPath`. Switching notes
  archives the current note's history and loads the target note's. Ctrl+Z
  undoes the last edit; Ctrl+Shift+Z redoes. History entries are
  `(text, selection, timestamp)` triples; the stack is bounded to a
  reasonable depth (50) so long sessions don't grow unboundedly. Native
  Ctrl+Z inside `EditableText` is left alone — the custom handler only
  fires when the native stack is empty (cross-note/mode cases).
  **Acceptance criteria:**
  - [x] `EditorController` gains a `_historyByPath: Map<String, UndoStack>`
        field alongside `_caretByPath`.
  - [x] `_pushHistory(notePath, text, selection)` called on every
        `updateBody` (and after each `FormatIntent` / `IndentIntent` /
        `continueList` apply, so formatting toggles and indent changes are
        undoable too).
  - [x] `open(note)` archives the current note's stack to the cache and
        loads the target note's stack.
  - [x] `close()` archives before clearing.
  - [x] `undoCurrent()` / `redoCurrent()` pop/push from the active stack;
        return the restored text and selection to the caller.
  - [x] Stack depth capped at 50 (older entries evicted FIFO).
  - [x] Ctrl+Z fires the custom undo when the native stack is empty
        (cross-note/mode); otherwise passes through to native.
  - [x] Ctrl+Shift+Z always fires the custom redo.
  **Verification:**
  - [x] `test/logic/editor_controller_test.dart` — type text, undo, redo;
        switch notes and verify each note's history is independent.
  - [x] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** None
  **Files likely touched:**
  - `lib/logic/editor_controller.dart`
  - `lib/ui/editor/editor_pane.dart`
  - `test/logic/editor_controller_test.dart`
  **Estimated scope:** M

- [x] **Task 2: Preserve undo history across mode switches**
  **Description:** Mode switches (Normal ↔ Markdown ↔ Preview) drop the
  undo stack because the `EditableText` widget unmounts/remounts. Keep
  the history alive across mode switches by archiving it into the per-note
  cache on unmount and restoring it on remount.
  **Acceptance criteria:**
  - [x] `_EditorState` (or equivalent) calls
        `EditorController.archiveCurrent()` when the editable body is
        unmounted (mode → Preview) and `EditorController.restoreCurrent()`
        when remounted (Preview → edit mode).
  - [x] After mode switch round-trip, Ctrl+Z still undoes the original
        edit.
  - [x] Undoing past a mode boundary is a no-op (not allowed to cross
        into the prior mode's stack).
  - [x] Redoing past a mode boundary is a no-op.
  **Verification:**
  - [x] Widget test: type text in Normal, switch to Preview, switch back,
        press Ctrl+Z, assert the original text is restored.
  - [x] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** Task 1
  **Files likely touched:**
  - `lib/logic/editor_controller.dart`
  - `lib/ui/editor/editor_pane.dart`
  - `test/ui/editor/editor_pane_test.dart`
  **Estimated scope:** S

### Phase 2 — Preview scroll position

- [x] **Task 3: Cache preview scroll offset per note across mode switches**
  **Description:** The shared `_bodyScroll` controller is dropped between
  edit and preview modes, so returning to preview always starts at the
  top. Cache the preview scroll offset per note in
  `EditorController._previewScrollByPath`; restore it on mode return.
  **Acceptance criteria:**
  - [x] `EditorController` gains a
        `_previewScrollByPath: Map<String, double>` field.
  - [x] `_savePreviewScroll(offset)` / `previewScrollFor(path)` accessed
        by `_EditorState` on mode switch.
  - [x] On mode switch away from Preview, capture the current offset and
        write to cache.
  - [x] On mode switch to Preview, read the cached offset and
        `ScrollController.jumpTo` after a post-frame callback (scrollbar
        needs to be attached).
  - [x] Uncached notes start at 0 (no jump).
  **Verification:**
  - [x] Widget test: scroll preview, switch to Normal, switch back to
        Preview, assert the preview is at the cached offset.
  - [x] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** None
  **Files likely touched:**
  - `lib/logic/editor_controller.dart`
  - `lib/ui/editor/editor_pane.dart`
  - `test/ui/editor/editor_pane_test.dart`
  **Estimated scope:** M


- [x] **Task 4: Cache edit scroll offset per note across mode switches**
  **Description:** The shared `_bodyScroll` controller is also dropped on
  mode switch, so returning to Normal/Markdown after Preview snaps to the
  top. Cache the edit-surface scroll offset per note in
  `EditorController._editScrollByPath`; restore it on mode return. Same
  shape as Task 3, keyed by note path. Edit uses a post-frame retry chain
  (not a single `jumpTo`) to hold the offset pinned across the ~100 ms
  EditableText `showCaretOnScreen` animation that fires on focus.
  **Acceptance criteria:**
  - [x] `EditorController` gains an
        `_editScrollByPath: Map<String, double>` field.
  - [x] `saveEditScroll(offset)` / `editScrollFor(path)` accessed by
        `_EditorState` on mode switch and note load.
  - [x] On mode switch away from an editable mode (Normal/Markdown),
        capture the current offset and write to cache.
  - [x] On mode switch to an editable mode, restore via post-frame retry
        chain (`addPostFrameCallback` x N) so the target survives
        EditableText's caret-on-screen animation.
  - [x] Uncached notes start at 0 (no jump).
  **Verification:**
  - [x] Widget test: scroll Normal, switch to Preview, switch back to
        Normal, assert the offset is restored.
  - [x] Widget test: opening note B does not inherit note A's edit cache.
  - [x] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** None
  **Files likely touched:**
  - `lib/logic/editor_controller.dart`
  - `lib/ui/editor/editor_pane.dart`
  - `test/ui/editor/editor_pane_test.dart`
  **Estimated scope:** M

- [ ] **Task 5: Add "go to top" FAB to the preview**
  **Description:** Overlay a small floating action button in the
  preview pane's bottom-right corner. Arrow-up icon. Appears (with a
  short fade-in) when the user has scrolled down past a threshold;
  disappears when they scroll back near the top. Tapping jumps to the
  top.
  **Acceptance criteria:**
  - [ ] New `GoToTopFab` widget in
        `lib/ui/editor/widgets/go_to_top_fab.dart`.
  - [ ] `MarkdownPreview` (or its parent in `editor_pane.dart`) renders
        the FAB overlay when scrolled past the threshold (50 px).
  - [ ] FAB uses `Icon(Icons.arrow_up_rounded)` with the Quire theme's
        `primaryContainer` background.
  - [ ] Opacity animates 0 → 1 over 200 ms on appear/disappear.
  - [ ] Tap calls `scrollController.animateTo(0, duration: 300ms,
        curve: Curves.easeOut)`.
  - [ ] FAB is `MaterialApp`-scoped so it doesn't get clipped.
  **Verification:**
  - [ ] Widget test: scroll the preview, assert FAB is visible; tap it,
        assert offset is 0; scroll to top, assert FAB disappears.
  - [ ] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** Task 3 (uses the same `_bodyScroll` controller)
  **Files likely touched:**
  - `lib/ui/editor/widgets/go_to_top_fab.dart` (new)
  - `lib/ui/editor/editor_pane.dart`
  - `test/ui/editor/editor_pane_test.dart`
  **Estimated scope:** S

### Phase 3 — List wrap alignment

- [x] **Task 6: Hide the attachments directory as `.attachments`**
  **Description:** Rename the vault attachments directory from `attachments`
  to `.attachments` so it doesn't appear in file browsers, OS searches, or
  `ls` output. Existing `attachments/` directories are migrated on first
  vault open.
  **Acceptance criteria:**
  - [x] `VaultRepository.attachmentsDirName` is `.attachments`.
  - [x] `importAttachment()` writes to `.attachments/` and returns
        `.attachments/<name>` as the vault-relative path.
  - [x] `VaultRepository.attachmentsDir` getter returns the `.attachments`
        directory.
  - [x] On `VaultRepository` init, if `attachments/` exists and
        `.attachments/` does not, rename `attachments/` to `.attachments/`
        (non-destructive; abort silently on failure).
  - [x] `MarkdownPreview._image` and any other path resolution uses the
        `.attachments` prefix.
  - [x] All tests that hard-code `attachments/` are updated.
  **Verification:**
  - [x] `test/data/vault_repository_test.dart` — verify the directory is
        created as `.attachments/`, imports land in `.attachments/`,
        and the migration path works when `attachments/` already exists.
  - [x] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** None
  **Files likely touched:**
  - `lib/data/vault_repository.dart`
  - `lib/ui/editor/editor_pane.dart` (if path resolution is duplicated)
  - `lib/ui/editor/markdown_preview.dart` (if path resolution is duplicated)
  - `test/data/vault_repository_test.dart`
  - other tests that reference `attachments/`
  **Estimated scope:** M

- [x] **Task 7: Link color uses the theme accent**
  **Description:** Markdown links in the preview currently render with
  `markdown_widget`'s default color. Add a `LinkConfig` to the
  `MarkdownConfig` that wires links to `theme.colorScheme.primary`,
  matching the rest of the preview's Quire theming.
  **Acceptance criteria:**
  - [x] `MarkdownPreview._generator()`'s `MarkdownConfig` adds a
        `LinkConfig` with `style: safeHanken(TextStyle(color: onSurface,
        decoration: TextDecoration.underline, decorationColor:
        colorScheme.primary))` (or a variant using
        `colorScheme.primary` directly).
  - [x] External links (`http://`, `https://`) and internal links
        (`[[note]]`-style, if rendered) use the accent color.
  - [x] Hover/click behavior is unchanged (existing `link.dart` handles
        it).
  **Verification:**
  - [x] `test/ui/editor/markdown_preview_test.dart` — assert the link's
        rendered `TextStyle.color` equals `colorScheme.primary`.
  - [x] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** None
  **Files likely touched:**
  - `lib/ui/editor/markdown_preview.dart`
  - `test/ui/editor/markdown_preview_test.dart`
  **Estimated scope:** XS

### Checkpoint: v0.3.4 complete

- [ ] All acceptance criteria from tasks 1–7 met
- [ ] `flutter analyze` clean
- [ ] `flutter test` green (new tests for undo cache, scroll cache, FAB,
      list alignment, `.attachments`, link color)
- [ ] Hot reload pushed to running app after each Dart edit
- [ ] One Conventional Commit per completed task

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Custom undo handler conflicts with native Ctrl+Z | Medium | Only override when the native stack is empty; pass through otherwise. |
| Undo stack grows unbounded in long sessions | Low | Cap at 50 entries per note; FIFO eviction. |
| Scroll offset restore races with the post-frame callback | Medium | Use `WidgetsBinding.instance.addPostFrameCallback` and check `hasClients`. |
| `.attachments` migration fails silently on a corrupt directory | Low | Wrap in try/catch; log the failure; continue with the new name. |
| FAB covers content at small viewport sizes | Low | Position bottom-right with a 16 dp margin; hide on window resize below a threshold. |
| List wrap alignment breaks selection | Medium | Verify `TextEditingController.selection` round-trips after wrap; test multi-line selection. |

## Confirmed Decisions

- **Undo history depth** — 50 entries per note, in-memory only. If the
  user wants a different depth, adjust the constant.
- **Cross-note undo** — not allowed. Each note has an independent stack.
- **`.attachments` migration** — automatic on first vault open; no
  settings flag, no user prompt.
- **Link color** — `colorScheme.primary` with underline; matches the rest
  of the preview's accent color usage.
- **Deferred list wrap alignment to v0.3.5** — preview already
  renders a hanging indent via `Row(marker SizedBox, Flexible content)`.
  Editor uses raw text markers in `EditableText` where wrapped lines
  inherit the left edge; a proper hanging indent needs a custom
  `LineBoxPainter` or paragraph-level `TextPainter` override that would
  risk caret math, selection, and undo. Revisit in v0.3.5 with a proper
  design.
- **Deferred task semantics (list wrap)** — confirmed at review: interpretation (a), a
  hanging indent. Wrapped list text aligns with the first character of
  the item's content, not the marker. Matches Obsidian/Typora behavior
  and what the preview already renders.
