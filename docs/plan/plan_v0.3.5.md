# Implementation Plan: Sheaf v0.3.5 — "steady"

Derived from `docs/spec.md` v0.3.4 brief. Ordered by dependency; each task
lands as its own Conventional Commit behind `flutter analyze` + `flutter test`.
No new dependencies.

## Overview

Two deferred items from v0.3.4, both about how the editor handles its own
surface:

- **Scroll flicker on mode switch.** Switching Preview → Normal (or
  Markdown) briefly shows the editor at offset 0 before jumping to the
  cached position. The current restore path runs in
  `addPostFrameCallback`, which fires after the frame is painted, so
  the user sees one frame of the wrong offset. Fix: give each mode its
  own `ScrollController`, constructed with the cached offset as
  `initialScrollOffset`, so the offset is honored at attach time (before
  first paint). Eliminates both the flicker and the 12-hop retry chain.
- **Wrapped list text in the editor aligns with the content, not the
  marker.** The preview already renders a hanging indent via
  `Row(marker SizedBox, Flexible content)`; the editor uses raw text
  markers in `EditableText` where wrapped lines inherit the left edge.
  Matches Obsidian/Typora behavior. Implementation: a custom
  `LineBoxPainter` that reads the source line, detects a list marker
  (bullet, ordered, or task), and indents every continuation line past
  the marker width. Preview is already correct and stays as-is.

## Architecture Decisions

- **Scroll restoration uses separate controllers per mode.** The
  current single `_bodyScroll` controller is shared across modes and
  disposed/recreated between them, so the cached offset can only be
  applied in a post-frame callback (after the wrong-offset frame has
  already been painted). Giving each mode its own controller means the
  cached offset is baked into `ScrollController(initialScrollOffset:)`
  and honored at the first attach — no post-frame needed. The 12-hop
  retry chain in v0.3.4 (added to win a race against
  `EditableText._scheduleShowCaretOnScreen`) becomes unnecessary because
  the offset is correct before `EditableText` mounts, so the
  caret-on-screen animation targets the already-correct scroll
  position rather than pulling it back.
- **Controllers are disposed on mode switch.** The old controller is
  disposed when leaving a mode; the new one is constructed with
  `initialScrollOffset` from the per-note cache. The cache itself
  (`_previewScrollByPath` / `_editScrollByPath` in
  `EditorController`) is unchanged — it is still keyed by note path and
  written on mode switch and on note load.
- **Scroll capture still happens on mode switch.** The listener that
  reads the offset before the body unmounts is preserved; only the
  restore path changes. `_onBodyScroll` continues to write user-driven
  scrolls to the cache (so scrolling within a mode updates the cache
  immediately); `_syncFromController` captures on mode switch (so
  programmatic jumps are captured too).
- **Hanging indent uses `LineBoxPainter`, not a `TextPainter`
  override.** `TextPainter` overrides the layout (line heights, box
  metrics), which risks breaking caret math, selection, and the
  existing highlight/selection paint. `LineBoxPainter` overrides only
  the per-line paint of the body text — layout is unchanged. Each
  continuation line is translated right by the marker width computed
  from the source text of that logical line.
- **Marker detection is by source-text prefix, not AST.** The
  highlight controller already scans for `-{1,3} `, `* `, `+ `,
  `\d+\.\s`, and `- \[ \] `/`- \[x\] `. The `LineBoxPainter` uses the
  same regex set so editor and preview agree on which lines are
  list items. Marker width is measured in the current font/style so
  wrapping stays proportional across font-size changes.
- **Line boxes are computed per line, not per paragraph.** A single
  list item can wrap across N physical lines; each physical line's
  `LineBoxPainter` computes its own indent from the source text of the
  logical line it belongs to. This keeps the calculation local and
  avoids coupling to the paragraph boundary (which would require
  walking the `TextPainter.getBoxesForRange` per paragraph).
- **Preview is already correct and is not touched.** `ListConfig` in
  `markdown_preview.dart` uses `Row(marker SizedBox, Flexible
  content)` which gives the preview its hanging indent for free. Only
  the editor side changes.
- **Continuation is unchanged.** List continuation (story 15/23) is the
  shipped behavior; the hanging indent is a pure paint change and does
  not touch text content or selection math.

## Task List

### Phase 1 — Scroll flicker fix

- [x] **Task 1: Separate ScrollController per mode**
  **Description:** Replace the single shared `_bodyScroll` with a pair
  of controllers (`_editScroll`, `_previewScroll`) constructed
  per-mode with `initialScrollOffset` from the per-note cache. The
  cache itself (`_previewScrollByPath` / `_editScrollByPath` in
  `EditorController`) is unchanged.
  **Acceptance criteria:**
  - [ ] `_bodyScroll` is replaced by `_editScroll` and `_previewScroll`.
  - [ ] Each controller is constructed with
        `initialScrollOffset` from the corresponding cache entry for
        the note that is open.
  - [ ] On mode switch, the outgoing controller is disposed; the
        incoming one is constructed with the cached offset.
  - [ ] Uncached notes (cache miss) start at 0 (no special handling).
  - [ ] `_onBodyScroll` writes to the matching cache on user scroll.
  - [ ] `_syncFromController` captures the offset on mode switch away
        from a mode (so programmatic jumps and `jumpTo` calls are also
        captured), then constructs the new controller.
  - [ ] The 12-hop retry chain (`_scheduleScrollRestore`) is removed;
        the offset is now correct before first paint.
  **Verification:**
  - [ ] Widget test: scroll Normal to a known offset, switch to
        Preview, switch back to Normal; the editor's `pixels` on the
        first frame after the switch equals the cached offset (no
        post-frame dance needed).
  - [ ] Widget test: opening a note for the first time (no cache)
        starts at 0 in every mode.
  - [ ] Existing scroll-cache tests still pass (Normal → Preview →
        Normal restores; per-note isolation holds).
  - [ ] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** None
  **Files likely touched:**
  - `lib/ui/editor/editor_pane.dart`
  - `lib/ui/editor/widgets/go_to_top_fab.dart` (the FAB is bound to the
    scroll controller it watches; update to the preview controller)
  - `test/ui/editor/editor_pane_test.dart`
  - `test/ui/editor/editor_pane_test.dart` (GoToTopFab tests reference
    the shared controller)
  **Estimated scope:** M

- [x] **Task 2: Cache miss restores at 0**
  **Description:** With separate controllers, the cache-miss case
  (first open of a note in a mode) starts at 0 by construction. No
  special handling needed; the default `initialScrollOffset` is 0.
  This task exists to verify the behavior and remove any vestigial
  "uncached" branches from `_syncFromController`.
  **Acceptance criteria:**
  - [ ] Removing any "if cache is null, skip restore" branches in
        `_syncFromController` and the retry chain.
  - [ ] The `previewScrollFor` / `editScrollFor` getters still return
        `null` for uncached notes; callers must treat `null` as 0.
  - [ ] `EditorController` gains no new public surface for this;
        cache semantics are unchanged.
  **Verification:**
  - [ ] Existing test: opening a note for the first time starts at 0.
  - [ ] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** Task 1
  **Files likely touched:**
  - `lib/ui/editor/editor_pane.dart`
  **Estimated scope:** XS

### Phase 2 — List wrap alignment

- [ ] **Task 3: Hanging indent in the editor via LineBoxPainter**
  **Description:** Add a custom `LineBoxPainter` to the editor body
  `TextField` that translates each physical line right by the marker
  width when the source text belongs to a list item. Marker detection
  matches the highlight controller's set (bullet, ordered, task). The
  preview is unchanged.
  **Acceptance criteria:**
  - [ ] `lib/ui/editor/highlighting_controller.dart` gains a
        `lineBoxPainter` getter that returns a `ListHangingIndentPainter`
        (or equivalent) when `highlight` is true.
  - [ ] The painter reads the source text via `controller.text`,
        detects the marker prefix of the logical line each physical
        line belongs to, and computes the indent in pixels using the
        current `TextStyle`.
  - [ ] Marker width is measured at the body font size; zoom and
        `baseFontSize` changes re-flow correctly (the painter is
        recreated on every layout pass anyway).
  - [ ] Wrapped list text aligns with the first character of the item's
        content (the hanging indent), not with the marker.
  - [ ] Non-list lines are unaffected (no indent).
  - [ ] Code blocks (fenced), quotes, and headings are unaffected —
        they are not list items by the marker regex.
  - [ ] The highlight controller's existing marker-dim behavior is
        preserved (markers stay real characters, selection/caret
        offsets are untouched).
  - [ ] CJK and emoji in the item content wrap correctly (no overflow,
        no overlap with the marker column).
  **Verification:**
  - [ ] Widget test: render a 500-char list item at narrow width;
        assert the wrapped continuation's left edge equals the first
        line's content left edge (measure via `RenderBox.getLocalToGlobal`
        on the body's `RenderParagraph`).
  - [ ] Widget test: a non-list long line wraps at the left edge (no
        hanging indent on non-list text).
  - [ ] Widget test: nested list items (`- item` / `  - sub`) each get
        their own indent matching their marker column.
  - [ ] Existing list-continuation tests still pass.
  - [ ] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** None
  **Files likely touched:**
  - `lib/ui/editor/highlighting_controller.dart`
  - `lib/ui/editor/editor_pane.dart` (pass `lineBoxPainter` to the
    `TextField`)
  - `test/ui/editor/editor_pane_test.dart` (new alignment tests)
  **Estimated scope:** L

- [ ] **Task 4: Preview alignment verification**
  **Description:** The preview already renders wrapped list text with
  a hanging indent via `Row(marker SizedBox, Flexible content)`. This
  task is a verification-only step: write a test that asserts the
  preview's wrapped continuation left edge equals the first line's
  content left edge, so we have a regression guard for both surfaces.
  **Acceptance criteria:**
  - [ ] Test renders a long list item in `MarkdownPreview` and
        measures the wrapped continuation's left edge.
  - [ ] Assert the continuation aligns with the first line's content
        (not the marker).
  - [ ] No production code changes — this is test-only.
  **Verification:**
  - [ ] `test/ui/editor/markdown_preview_test.dart` gains the
        alignment test.
  - [ ] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** None
  **Files likely touched:**
  - `test/ui/editor/markdown_preview_test.dart`
  **Estimated scope:** XS

### Phase 3 — Preview ergonomics

- [ ] **Task 5: Tag chips clickable in preview mode**
  **Description:** The `TagChipBar` is rendered in every mode (including
  Preview) via `_focusTag`, but `_focusTag` mutates
  `_body.value.selection` and calls `_bodyFocus.requestFocus()` — both
  of which are no-ops in Preview because the `TextField` is unmounted
  (`EditorMode.preview => Stack(... MarkdownPreview ...)`, not the
  editable branch). The tap looks inert. Rework `_focusTag` to
  dispatch on mode: in editable modes keep the current selection+focus
  behavior; in Preview, search the rendered preview content for the
  tag text and scroll to it.
  **Acceptance criteria:**
  - [ ] `_focusTag(String tag)` checks the current mode; in editable
        modes it behaves as today (select the first `#tag ` occurrence,
        focus the body); in Preview it jumps the preview scroll to the
        rendered `#tag` text (or its first match).
  - [ ] Preview hit-test: tap a chip, assert the preview's scroll
        offset moved to bring the matched tag into view.
  - [ ] If the tag is not found in the rendered preview content, the
        tap is a no-op (no scroll jump).
  - [ ] Existing tag-chip behavior in editable modes is unchanged
        (existing tests still pass).
  **Verification:**
  - [ ] Widget test: open a note with tags in Preview, tap a chip,
        assert the preview scroll offset changes toward the tag.
  - [ ] Existing tag-chip tests in editable modes still pass.
  - [ ] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** None
  **Files likely touched:**
  - `lib/ui/editor/editor_pane.dart`
  - `lib/ui/editor/markdown_preview.dart` (if a tag-search API is
        needed)
  - `test/ui/editor/editor_pane_test.dart`
  **Estimated scope:** M

- [ ] **Task 6: Find in note in preview mode**
  **Description:** `Ctrl+F` opens the find bar in every mode, but the
  find handlers (`_runFind`, `_nextMatch`, `_prevMatch`,
  `_jumpToCurrentMatch`) operate on `_body.text` and
  `_body.value.selection` — which are inert in Preview because the
  `TextField` is unmounted. The bar opens but does nothing useful.
  Rework the find flow to dispatch on mode: in editable modes keep
  the current selection+scroll behavior; in Preview, match against the
  rendered preview text and scroll the preview to each match.
  **Acceptance criteria:**
  - [ ] `_runFind(query)` matches against the rendered preview text
        when in Preview mode (the plain-text source is fine for a
        first pass; if the preview renders a different text — e.g.
        `**bold**` becomes "bold" — note the limitation in the test
        rather than over-engineering).
  - [ ] `_nextMatch` / `_prevMatch` cycle through matches and scroll
        the preview to each (via `_previewScroll.animateTo` or
        `jumpTo`).
  - [ ] `_counterLabel` reflects the match count in the rendered
        preview text.
  - [ ] Case-sensitive toggle works in both modes.
  - [ ] `Esc` closes the find bar and restores focus appropriately
        (in Preview, to the preview focus node; in editable modes, to
        the body — unchanged).
  - [ ] Body-editing re-computes matches (story 24) — in Preview the
        preview text re-renders on body change, so the listener still
        fires; in editable modes, unchanged.
  - [ ] Highlighting current match in Preview: either skip (accept
        the limitation — no visual highlight in the preview) or add a
        simple `TextEditingController` overlay on the preview if
        feasible; document whichever choice is made in the test.
  **Verification:**
  - [ ] Widget test: open a note in Preview, press `Ctrl+F`, type a
        query, assert `n/m` counter shows the match count; press `Enter`,
        assert the preview scroll moved toward the match.
  - [ ] Widget test: cycling `Enter` / `Shift+Enter` advances/rewinds
        through matches and scrolls the preview.
  - [ ] Widget test: `Esc` closes the bar.
  - [ ] Existing find-in-note tests in editable modes still pass.
  - [ ] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** Task 1 (separate `_previewScroll` controller gives
  the find flow a stable scroll target in Preview)
  **Files likely touched:**
  - `lib/ui/editor/editor_pane.dart`
  - `lib/ui/editor/markdown_preview.dart` (if the rendered text needs
        a hook for the find flow)
  - `test/ui/editor/editor_pane_test.dart`
  **Estimated scope:** M

### Checkpoint: v0.3.5 complete

- [ ] All acceptance criteria from tasks 1–6 met
- [ ] `flutter analyze` clean
- [ ] `flutter test` green
- [ ] Hot reload pushed to running app after each Dart edit
- [ ] One Conventional Commit per completed task

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Separate controllers leak across mode switches | Medium | Dispose the outgoing controller in `_syncFromController` before constructing the incoming one; add a leak-detection assertion in tests. |
| `LineBoxPainter` shifts the caret visually when wrapping changes | High | Painter only translates the paint, not the layout; caret rect is computed by `TextPainter.getRectForRange` which uses layout metrics, so the caret stays correct. Verify with a caret-position test. |
| Marker width measured in wrong font | Medium | Painter reads the current `TextStyle` from the controller's `style` and re-computes on every layout pass; zoom/baseFontSize changes re-layout anyway. |
| CJK/emoji overflow past the marker column | Medium | Painter only translates the paint; the underlying text layout already handles CJK/emoji. Verify with a wrapping test on CJK content. |
| Performance: painter runs per physical line | Low | Painter is O(1) per line (one regex match on the source prefix). The body has at most a few hundred physical lines; negligible cost. |
| Highlight controller's marker-dim behavior breaks | Low | Painter is additive; the existing span-styling logic is untouched. Verify with the existing marker-dim tests. |
| Preview alignment test measures the wrong thing | Low | Test measures the `Flexible content` left edge inside the `Row`, not the marker's left edge. If the test is wrong, the production code is still correct. |

## Confirmed Decisions

- **Scroll flicker fix** — separate `ScrollController` per mode
  (`_editScroll`, `_previewScroll`), each constructed with
  `initialScrollOffset` from the per-note cache. Eliminates the
  post-frame restore path and the 12-hop retry chain. The cache
  itself (`_previewScrollByPath` / `_editScrollByPath`) is unchanged.
- **List wrap alignment mechanism** — `LineBoxPainter` (paint-only
  override), not a `TextPainter` override (which would risk layout,
  caret math, selection, and undo). The preview is unchanged.
- **List wrap semantics** — confirmed at review: interpretation (a),
  a hanging indent. Wrapped list text aligns with the first character
  of the item's content, not the marker. Matches Obsidian/Typora
  behavior and what the preview already renders.
- **Marker detection set** — same as the highlight controller: `-{1,3} `,
  `* `, `+ `, `\d+\.\s`, `- \[ \] `, `- \[x\] `. If the highlight
  controller's set changes, the painter must change in lockstep.
- **Preview alignment test is test-only** — no production changes to
  the preview; the test is a regression guard.

## Open Questions

- Should the painter handle task-list checkboxes (`- [ ] ` / `- [x] `)
  by measuring the checkbox width specifically, or treat them as a
  generic marker? The current plan treats them generically (measure the
  marker prefix width); a future refinement could special-case
  checkboxes to align content with the text after the checkbox.
- Is the `LineBoxPainter` API stable across Flutter releases? It is
  part of the public `flutter/material.dart` API and has been stable
  for years. If it ever changes, the painter will need to be rewritten,
  but that's a one-day change.
