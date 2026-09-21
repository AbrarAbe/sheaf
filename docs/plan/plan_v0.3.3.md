# Implementation Plan: Sheaf v0.3.3 — "type-first"

Derived from `docs/spec.md` v0.3.2 brief and brief for next iteration. Ordered by dependency; each task lands as its own Conventional Commit behind `flutter analyze` + `flutter test`. No new dependencies.

## Overview

Four UX fixes that remove friction between clicking a note and actually typing in it:

- **Auto-focus the editor on open.** Opening a note from the note list or the quick-switcher places the caret in the body immediately, so the user can start typing without a click.
- **Title autosave on blur.** Editing the note title and leaving the field (clicking away, Tab, opening another note) commits the rename at once — Enter is no longer required.
- **Tab indent / Shift+Tab outdent.** Tab indents the current line (or every line of a selection) with two spaces; Shift+Tab removes up to two leading spaces. Indentation is structural, per markdownformatting.com — it nests lists, never a visual paragraph indent.
- **Indent is not code in preview.** The preview no longer turns leading-space-indented prose into an indented code block; indentation renders only as list structure. Fenced code blocks still render as code.

## Architecture Decisions

- **Indentation unit = two spaces, from Tab/Shift+Tab.** The existing list-continuation logic preserves arbitrary existing indent but defines no unit; there is no indentation convention in the codebase yet. Following markdownformatting.com, indentation uses spaces (never the tab character) and two spaces is the standard nested-list increment. (spec decision 14)
- **Indent/outdent is a pure, headless transform** in `lib/logic/` (like
  `continueList` and the formatting toggles), returning text + selection; the
  editor layer maps it onto `TextEditingController`.
- **Extensible line-edit contract.** `indentBlock`/`outdentBlock` are the first
  of a family of per-line block transforms (future: wrap/unwrap fenced code,
  blockquote markers, bullet toggles). They share one contract — given text + a
  selection range, return new text + selection — so the editor layer and tests
  stay uniform. Built over a tiny reusable line-range helper (offset → line
  index), so each future transform supplies only its per-line prefix logic.
  Task 3 delivers this layer; later features plug in without new architecture.
- **Tab/Shift+Tab are native editor keys** (like `Ctrl+B/I/U`), hard-coded and not part of the rebindable `ShortcutAction` surface — indentation is core editing, not a user shortcut.
- **Preview suppresses indented-code blocks via a custom extension set.** `MarkdownGenerator` accepts an `extensionSet`; passing a gitHubFlavored-derived set minus `IndentedCodeSyntax` makes `Document` treat 2–4-space leading indents as prose while nested-list and fenced-code parsing is untouched.

## Task List

### Phase 1 — Editor auto-focus on open

- [x] **Task 1: Auto-focus the body when a note is opened (list + quick-switcher)**
  **Description:** When a note opens from the note list or the command-palette quick-switcher, the body editor gains focus with a visible caret so typing can begin immediately.
  **Acceptance criteria:**
  - [x] On note open, set the sticky body-focus intent and `requestFocus()` the body in a post-frame callback.
  - [x] Works in Normal and Markdown edit modes. In Preview the preview segment is focused instead; returning to an edit mode restores the caret via the existing `_wantBodyFocus` path.
  - [x] Does not steal focus while the title is being edited.
  **Verification:**
  - [x] `flutter test test/ui/editor/editor_pane_test.dart` — open a note, assert the body `EditableText` has focus.
  **Follow-ups:**
  - Auto-focus changes the premise of `Del outside editors` in `test/ui/shell/shortcut_test.dart` — those two tests now unfocus the body first (committed). They cannot be validated green here because the Shell-rendering tests depend on live network to `fonts.gstatic.com`; making them hermetic is a logged follow-up.

### Phase 2 — Title autosave on blur

- [x] **Task 2: Commit the title rename on focus loss**
  **Description:** Renaming a note by editing its title currently saves only on Enter (`onSubmitted`/`onEditingComplete`). Commit the rename when the title field loses focus instead.
  **Acceptance criteria:**
  - [x] Editing the title then unfocusing (clicking the body, Tab out, opening another note) calls the existing `_commitRename(_title.text)`.
  - [x] Enter still commits; empty or unchanged titles revert the field without renaming (existing `_commitRename` guards).
  - [x] No double rename when Enter and blur both fire (guards are idempotent).
  **Verification:**
  - [x] `flutter test test/ui/editor/editor_pane_test.dart` — edit title, unfocus, assert rename committed.
  **Dependencies:** None (independent of Task 1)
  **Files likely touched:**
  - `lib/ui/editor/editor_pane.dart`
  - `test/ui/editor/editor_pane_test.dart`
  **Estimated scope:** XS

### Phase 3 — Tab indent / Shift+Tab outdent

- [x] **Task 3: Line-edit primitives — indent / outdent**
  **Description:** Add headless line-range editing primitives for two-space
  indent and outdent, designed as the first of a family of per-line block
  transforms so future code-formatting and blockquote toggles reuse the same
  line indexing and text+selection contract.
  **Acceptance criteria:**
  - [x] A reusable line-range helper maps selection offsets to the line(s)
        being edited; transforms operate per line.
  - [x] `indentBlock(text, selStart, selEnd)` indents every touched line by two
        spaces; returns new text + selection.
  - [x] `outdentBlock(...)` removes up to two leading spaces per touched line;
        no-op on lines with no leading space.
  - [x] Collapsed caret and multi-line selection both handled; spaces only,
        never a tab character.
  - [x] Functions are pure (no Flutter imports), unit-testable headlessly like
        `continueList`.
  **Verification:**
  - [x] `flutter test test/logic/line_edit_test.dart` — single-line,
        multi-line, no-indent outdent, mixed indent, selection preservation.
  **Dependencies:** None
  **Files likely touched:**
  - `lib/logic/line_edit.dart` (new)
  - `test/logic/line_edit_test.dart` (new)
  **Estimated scope:** S

- [x] **Task 4: Wire Tab / Shift+Tab into the editor**
  **Description:** Bind Tab → indent, Shift+Tab → outdent in editing modes so the keys act on the body instead of moving focus.
  **Acceptance criteria:**
  - [x] `IndentIntent`/`OutdentIntent` bound to `Tab` and `Shift+Tab` in `_editShortcuts` (hard-coded, like `Ctrl+B/I/U`), consumed so Tab no longer moves focus out of the field.
  - [x] Works in Normal and Markdown modes; inert in Preview (no editable body).
  - [x] Selection collapses/extends sensibly and auto-scrolls to the caret.
  **Verification:**
  - [x] `flutter test test/ui/editor/editor_pane_test.dart` — Tab indents, Shift+Tab outdents, focus stays in the field.
  **Dependencies:** Task 3
  **Files likely touched:**
  - `lib/ui/editor/intents.dart`
  - `lib/ui/editor/editor_pane.dart`
  - `test/ui/editor/editor_pane_test.dart`
  **Estimated scope:** S

### Phase 4 — Indent is not code in preview

- [ ] **Task 5: Suppress indented-code-block rendering in preview**
  **Description:** The preview currently renders 4-space-indented lines as code. Disable `IndentedCodeSyntax` so tab/prose indentation shows as prose, while list indentation and fenced code keep their structure.
  **Acceptance criteria:**
  - [ ] `MarkdownPreview._generator()` passes an `extensionSet` built from gitHubFlavored minus `IndentedCodeSyntax`.
  - [ ] A 2- or 4-space-indented non-list line renders as prose, not a code block.
  - [ ] Nested lists still nest by indentation; fenced ``` code blocks still render as code.
  **Verification:**
  - [ ] `flutter test test/ui/editor/markdown_preview_test.dart` — indented prose → no `RichText` pre block; nested list + fenced code still render.
  **Dependencies:** None (independent of Tasks 3–4)
  **Files likely touched:**
  - `lib/ui/editor/markdown_preview.dart`
  - `test/ui/editor/markdown_preview_test.dart`
  **Estimated scope:** S

### Phase 5 — Bug: caret ignores a trailing space at the end of a heading

- [x] **Task 6: Fix heading caret collapsing across a trailing space**
  **Description:** In Normal mode (highlight on), after typing a heading like
  `# Heading` and then a space at the end, the caret paints *before* the
  trailing space instead of after it: `# Heading|<space>`. Typing a word then
  places it correctly (`# Heading<space>word|`), but deleting that word snaps
  the caret back in front of the space again, ignoring it.
  **Status (fixed):** the collapse reproduces only when the heading is followed
  by more lines — a styled trailing space at a line end collapses onto the last
  word. `HighlightingController._heading` now emits trailing whitespace of the
  heading content as a base-style span (not the larger heading span) so the
  caret keeps its width. Covered by a multi-line regression test in
  `editor_pane_test.dart`.
  **Acceptance criteria:**
  - [x] Caret placed after a trailing space stays visually after it while
        typing/deleting at the end of a heading followed by more lines.
  - [x] Normal-mode headings with and without trailing spaces behave
        identically for caret navigation; no regression to the marker
        reveal/dim behavior (F4a/F5b still pass).
  - [x] Happy-path (marker hidden when caret elsewhere, dimmed when touched)
        is preserved.
  **Verification:**
  - [x] Regression widget test types `# Heading \nnext line`, moves the caret
        after the trailing space, and asserts it stays after it.
  - [x] `flutter analyze` clean; `flutter test` green.
  **Analysis / root cause:** `HighlightingController.buildTextSpan` renders
  heading content in a larger span, so a trailing space at the end of the
  heading line (when more lines follow) collapses to zero advance — Flutter
  lays it out so the caret for the after-space position falls back onto the
  last word (the F5 reveal rule's `_hidden`/`fontSize: 0` markers are a
  related but distinct mechanism). The fix emits trailing whitespace of the
  heading content as a base-style span so the caret keeps real width.
  **Dependencies:** None (independent; pairs with Task 1's editor focus)
  **Files likely touched:**
  - `lib/ui/editor/highlighting_controller.dart`
  - `test/ui/editor/editor_pane_test.dart`
  **Estimated scope:** S

### Phase 6 — Remember the caret position per note

- [x] **Task 7: Cache and restore the caret position per note (in-memory)**
  **Description:** When a note is reopened or cycled to, the caret should return
  to where the user last left off instead of resetting. Cache the last caret
  offset per note **in memory only** (never written to the note file), so
  returning to a note restores the caret (and scroll) to the last position.
  **Analysis / reported symptom:** Opening or `Ctrl+Tab`-cycling a note places
  the caret somewhere unhelpful — reported as "always at the last line/bottom,
  no matter where I was." `_load()` sets `_body.text = note.body`, which drops
  any record of the prior caret. Additionally, Task 8's post-frame
  `jumpTo(maxScrollExtent)` on last-line Enter means the previous note often
  sits scrolled to the bottom when you switch away, so the next note can feel
  as though the caret "was at the bottom." There is today no caret memory at
  all (`EditorController` tracks only `_current`, `_body`, `_status`).
  **Acceptance criteria:**
  - [x] Record the body caret offset for the current note on note switch /
        pane dispose into an in-memory map keyed by note path. Cache lives on
        `EditorController`; nothing is written to disk or the note file.
  - [x] On `_load()` for a cached note, restore the caret offset; uncached notes
        stay untouched (markers hidden) with the caret placed on focus at the
        top.
  - [x] Task 8 auto-scroll still fires only when the user actually presses Enter
        on the last line — not on a caret restore.
  - [x] Works across Normal/Markdown and across `Ctrl+Tab` cycling.
  **Verification:**
  - [x] Editor widget test: open note A, move caret to offset 20, switch to B
        then back to A; assert the caret is restored to 20 (and remembered).
  - [x] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** Task 1 (focus-on-open); coordinates with Task 6 (caret) and
  Task 8's Enter auto-scroll (v0.3.2).
  **Files likely touched:**
  - `lib/logic/editor_controller.dart`
  - `lib/ui/editor/editor_pane.dart`
  - `test/ui/editor/editor_pane_test.dart`
  **Estimated scope:** S

### Phase 7 — File name is the title

- [x] **Task 8: A `# Heading` never changes the note title**
  **Description:** The note title is always its file name (the title row
  field). A `# Heading` at the top of the body no longer overrides the title,
  so the editor title field, the note list, and note-info stop disagreeing once
  a heading is added to the body.
  **Acceptance criteria:**
  - [x] `extractTitle` returns only the file-name stem and ignores body
        headings (`_heading1` rule removed).
  - [x] Editor title field, note list, and note-info all show the file-name
        title regardless of body headings.
  - [x] Renaming via the title field still renames the file and updates the
        title everywhere.
  **Verification:**
  - [x] `test/data/markdown_parser_test.dart` — heading no longer overrides the
        stem.
  - [x] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** None
  **Files likely touched:**
  - `lib/data/markdown_parser.dart`
  - `test/data/markdown_parser_test.dart`
  - `test/data/vault_repository_test.dart`
  - `test/logic/vault_controller_test.dart`
  **Estimated scope:** S

### Checkpoint: v0.3.3 complete
- [ ] All acceptance criteria from tasks 1–5 met
- [ ] `flutter analyze` clean
- [ ] `flutter test` green (new tests for editor auto-focus, title blur-save, tab indent/outdent, preview indent-as-code)
- [ ] Hot reload pushed to running app after each Dart edit
- [ ] One Conventional Commit per completed task

## Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Auto-focus on open fights app-launch last-note reopen | Low | Gate on a user-initiated open flag if launch reopen proves surprising; default focuses on open. |
| Title blur-save double-commits with Enter | Low | `_commitRename` is idempotent (unchanged title reverts, no rename). |
| Tab binding breaks focus traversal in the editor | Low | Bind via `_editShortcuts` so `Shortcuts` consumes Tab only while an editable surface is focused; verify focus stays in body. |
| Disabling indented-code blocks surprises users who hand-indent code | Low | Fenced ``` is the app's code style; guide recommends fences; call out in the spec decision. |
| markdown_widget `extensionSet` override drops needed syntaxes | Low | Build from `ExtensionSet.gitHubFlavored` and remove only `IndentedCodeSyntax`; covered by preview tests. |

## Confirmed Decisions
- **Auto-focus scope** — resolved: focus on every note open, including
  relaunch into the last-open note (confirmed default).
- **Tab step** — resolved: two spaces per Tab (confirmed).
- **Future line edits** — code formatting and blockquote are anticipated in the
  extensible line-edit contract Task 3 establishes; no separate design is
  needed until those stories are specified.