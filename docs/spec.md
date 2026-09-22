# Spec: Sheaf — living product spec

Milestone history: v0.1 ("the desk") shipped as `v0.1.0`; v0.2
("the editor") shipped; v0.3 ("polish & power") shipped; v0.3.1
("paper cuts") shipped; v0.3.2 ("no surprises") shipped; v0.3.3
("type-first") is the current release. This revision brings the spec up to
v0.3.3 and records the deferred items still open.

## Objective

Make the desk feel like a mature editor. A v0.1 user could take notes but
edited with bare hands: no formatting keys, no find-in-note, no way to pin,
forced pane layouts, one look. v0.2 made every common action reachable from
the keyboard and gave the user control of panes and appearance. v0.3 hardened
the foundation (correctness, performance, multi-vault) and added real
formatting power. v0.3.1 closed the paper cuts that blocked the polished feel
of v0.3.0. v0.3.2 "no surprises" adds delete/folder confirmation dialogs,
command palette polish, note info (EXIF) dialog, and an editor scroll fix
for Enter on the last line.

### User stories — v0.1 (shipped)

1. **Vault** ✅ pick/create folder, persists, plain `.md` files on disk
2. **Notes** ✅ CRUD, `.trash/` soft-delete with restore, ~1 s debounced autosave
3. **Folders** ✅ tree create/rename/delete, notes land in selected folder
4. **Tags** ✅ inline `#tag` parse → chips → sidebar → click-to-filter
5. **Markdown** ✅ GFM-subset preview (headings, emphasis, lists, tasks,
   quotes, code, links, tables, images)
6. **Images** ✅ `![alt|400](…)` resize syntax, insert copies into `attachments/`
7. **Search** ✅ vault-wide filter, title-priority ranking
8. **Shell** ✅ three tiers (≥1120 / 720–1119 / <720), draggable dividers
9. **Theme** ✅ Daylight/Lamplight/System, `Ctrl+Shift+L`, persisted

### User stories — v0.2 (shipped)

10. **Formatting keys** — `Ctrl+B` toggles `**bold**`, `Ctrl+I` toggles
    `*italic*`, `Ctrl+U` toggles `<u>underline</u>`. Selection wraps/unwraps;
    bare caret touching a word selects and wraps the whole word; caret on
    whitespace/punctuation inserts an empty pair. `Ctrl+Shift+C` /
    `Ctrl+Shift+V` copy/paste the focused editor selection. Preview renders
    `<u>` underlined; all other raw HTML stays literal.
11. **Navigation & zoom keys** — `Ctrl+Tab` / `Ctrl+Shift+Tab` cycle notes.
    `Ctrl+D` selects the word at the caret. `Ctrl+=` / `Ctrl+-` step app-wide
    text scale 50%–200%, `Ctrl+0` resets. Zoom persists and scales text
    everywhere; icons and layout metrics are unaffected.
12. **Editor modes** — Normal (live-rendered, markers hidden until the caret
    touches a span), Markdown (raw monospace), Preview (rendered read-only).
    Segmented control + `Ctrl+Shift+M`; last mode persists.
13. **Pinning** — pin from row hover or context menu; Pinned group sorts above
    the rest; state lives in `<vault>/.sheaf/meta.json`, never in `.md` files.
14. **Find in note** — `Ctrl+F` bar: query field, `n/m` counter,
    `Enter`/`Shift+Enter` traversal, `Esc` closes.
15. **List continuation** — `Enter` at the end of a list item carries the
    marker (`- `, `* `, `- [ ] ` verbatim; `1. ` increments), preserves
    indentation, and clears a marker-only line (smart exit).
16. **Pane control** — sidebar visibility is user-owned in every tier, header
    toggle + `Ctrl+\`, per-tier persistence, focus mode (`F10`), OS fullscreen
    (`F11`).
17. **Appearance settings** — theme worlds (Graphite, Sepia) × System/Light/Dark,
    zoom %, editor base size 12–24 px, functional window controls. The v0.2
    typeface picker was removed in feedback round 5 — bundled Google Fonts only;
    old settings JSON with font keys still loads.
18. **Quick-switcher (⌘K)** — header pill (hidden on stack tier) + global
    `Ctrl+K` overlay: ranked note rows, empty query lists newest-first, typing
    narrows by title then body, ↑/↓ move, Enter opens, Esc closes.
19. **Scope chips in the list pane** — removable `in proj` / `#urgent` chip when
    a folder or tag filter is active; tapping clears to All notes.
20. **Trash timestamps** — compact age stamp per trash entry, full timestamp on
    hover.

### User stories — v0.3 "polish & power" (shipped)

21. **Unicode-aware word formatting** — word = maximal run of `\p{L}\p{N}_`
    (any script), replacing the ASCII-only `\w`. Fixes `café naïve 中文`
    splitting and surrogate-pair emoji. Marker scanning skips `*`, `**`, and
    list markers so one word's emphasis never bleeds into a neighbour.
22. **Combinable formatting** — `*`, `**`, `<u>` are orthogonal and stack:
    `Ctrl+B` then `Ctrl+I` yields `***word***`; unwrapping removes only the
    requested marker's smallest qualifying span. `***word***` unwraps
    piecewise (`*` → `**word**`, `**` → `*word*`).
23. **List continuation correctness** — `Enter` on a middle line of a document
    continues/clears correctly (line-end guard), non-collapsed selections are
    replaced like normal typing, and numeric markers clamp (`9999999999.` no
    longer throws).
24. **Find staleness** — editing the body while the find bar is open
    re-computes matches and keeps the current match tracked, without closing
    the bar; lowercase cache is per body change, not per query keystroke.
25. **Rebuild scoping** — typing/autosave no longer rebuilds the sidebar
    folder tree; note-list, folder, and tag-count slices notify independently,
    and stale async refreshes are cancelled by a generation guard.
26. **Editor & preview performance** — highlighting memoizes its parse per text
    change (caret moves reuse spans); preview images load asynchronously with
    `cacheWidth` and an `errorBuilder`, behind a path-traversal guard that
    rejects `..`/absolute paths.
27. **Large-vault scrolling** — the note list virtualizes per group
    (`SliverList.builder`), prunes stale row keys, and the command palette
    computes results once per query change.
28. **Focus & shortcut correctness** — a single autofocus owner in the shell;
    the palette restores focus on close; the stack-tier drawer closes on `Esc`;
    `Delete` in a focused editor edits text instead of deleting the note.
29. **Multi-directory vaults** — `AppSettings.vaultPaths` (ordered, primary =
    index 0) replaces the single path; `VaultController` fans out over
    `List<VaultRepository>`, notes merge newest-first, folders are sectioned
    per vault with a vault header and "Add vault" row, drag-drop/import routes
    to the note's owning vault, and pins are namespaced per vault via each
    root's `.sheaf/meta.json`. Legacy single-path settings JSON migrates on
    read.
30. **Keyboard shortcut customization** — Settings gains a Keyboard Shortcuts
    section: every shell/editor action except the formatting trio is
    remappable through a key recorder with conflict detection, persisted as
    `AppSettings.shortcutOverrides` (`Map<String,String>`, empty omitted,
    corrupt → defaults). `Ctrl+B/I/U` and `Ctrl+C/V/X` are reserved.

### User stories — v0.3.1 "paper cuts" (shipped)

31. **Nested folders** — the sidebar renders the full recursive folder tree
    that `FolderNode.children` already returns, indented per depth, with a
    chevron expand/collapse that does not select the folder. Selecting any
    nested folder filters notes to that subtree. Expand state is in-memory per
    `relPath` for this release.
32. **Find selection & focus** — jumping between matches keeps focus in the
    editor body (the bar never steals it), `Esc` closes and restores the body
    focus, and every listener added for the bar is paired with a removal.
33. **Tight selection boxes** — multi-line selection highlights hug each line's
    glyph run (`BoxWidthStyle.tight`) instead of painting to the widest line.
    The prose column is unbounded by design (740 px in focus mode); no capped
    reading measure.
34. **In-editor tag chip bar** — `TagChipBar` renders `extractTags` pills
    inside the scrollable editor column under the title row, so chips scroll
    with content and remain reachable in focus mode. Tapping a chip inserts
    `#tag ` at the caret.
35. **Scrollbar affordance** — the scrollbar thumb shows a hand cursor, a
    grabbing cursor while dragging, and a state-owned thumb color
    (idle → hovered → dragged). The thumb never paints over text: the gutter is
    reserved inside the content padding, and the built-in overlay scrollbar is
    disabled per editor mode in favour of one interactive `Scrollbar`.
36. **Folder creation feedback** — creating a folder selects it immediately and
    shows a loading affordance (wait cursor + spinner replacing the new-folder
    button) while the async operation is in flight.
37. **Sticky folder header** — the folder-section label, expand/collapse
    toggle, and new-folder button stay pinned above the independently scrolling
    folder list; the tags section scrolls away normally.
38. **Platform-aware section label** — the folder section reads "DIRECTORIES"
    on Linux and "FOLDERS" elsewhere, computed per build with `dart:io`.
39. **Linux AppImage build** — `scripts/build_appimage.sh` packages the Linux
    release build via `linuxdeploy` + `linuxdeploy-plugin-gtk`, fails clearly
    when prerequisites are missing, and runs on a clean Ubuntu 22.04.

### User stories — v0.3.2 "no surprises" (shipped)

40. **Delete confirmation** — deleting a note shows a confirmation dialog
    before the undo-toast path; deleting a folder shows a confirmation dialog
    naming the folder and stating that all contained notes will be trashed.
    The dialog has a non-destructive Cancel and a destructive Confirm.
41. **Command palette arrow-key polish** — up/down arrow navigation no longer
    leaves the selected row with a stale background; typing in the query field
    automatically highlights the first result (the background is not stale).
    The highlight paints instantly (no cross-fade / flicker).
42. **Note info (EXIF) dialog** — the note context menu gains an `Info` entry
    (I icon). Hovering shows a tooltip with the file path. Clicking opens an
    info dialog displaying: file name, full path, created date, last modified
    date, word count, and character count. The dialog is non-modal (the user
    can interact with the editor while it's open).
43. **Editor auto-scroll on last-line Enter** — pressing Enter on the very
    last line of the document scrolls the editor to keep the new blank line
    visible before any character is typed, not after.

### User stories — v0.3.3 "type-first" (in progress)

Indentation follows markdownformatting.com/indent: use spaces, not tabs;
indentation is structural (list nesting), never a visual paragraph indent.

44. **Editor auto-focus on open** — opening a note from the note list or the
    quick-switcher places the caret in the body editor immediately, so typing
    starts on open without a click. In Normal/Markdown modes the body is
    focused; in Preview the preview segment is focused and the caret returns
    on mode switch via the sticky focus intent.
45. **Title autosave on blur** — editing the note title and leaving the field
    (clicking away, Tab, opening another note) commits the rename immediately;
    Enter is no longer required. Empty or unchanged titles are left as-is.
46. **Tab indent / Shift+Tab outdent** — Tab indents the current line (or every
    line of a selection) by four spaces; Shift+Tab removes up to four leading
    spaces. Bound in Normal and Markdown edit modes; inert in Preview.
    Space-based per markdownformatting.com; indentation is structural (nests
    lists), never a visual paragraph indent.
47. **Indent is not code in preview** — leading-space indentation on non-list
    lines never renders as an indented code block; indentation displays only as
    list structure. Fenced code blocks still render as code.
48. **Editor caret memory** — the editor remembers, in memory only (never
    written to disk), the last body caret offset for each note and restores it
    when the note is reopened or cycled to, so writing resumes where it left
    off.
49. **File-name title is authoritative** — a `# Heading` in the note body never
    changes the note title; the title is always the note's file name (set via
    the title row field), and the editor title field, the note list, and the
    note-info dialog always agree.

Explicitly **deferred**: list/link/image action bar (`EditorActionBar`,
`ListKind`, `LinkKind`) — list continuation (story 15/23) is the shipped list
behavior and the untested scaffolding was removed in v0.3.1; open-notes editor
tabs (see `docs/adr/0007-open-notes-tabs.md`); global hotkeys
(`Ctrl+Alt+N`); reminders; sync/mobile polish; true marker-hiding WYSIWYG;
parsing local GTK themes' CSS into color worlds; bundling additional Google
Fonts as offline assets; local font loading (removed).

## Assumptions

1. v0.1 assumptions carry over (files-on-disk vault, source-mode editor +
   preview, inline tags, H1/filename titles, Linux-only).
2. **Normal vs Markdown distinction**: same buffer, same keybindings; Normal
   *renders* formatting live with dimmed markers (not full WYSIWYG — markers
   stay selectable/editable), Markdown shows raw monospace source.
3. **Underline** has no native Markdown; we use `<u></u>` and teach the
   preview's renderer that one tag (minimal inline-HTML support, nothing else).
4. **Pin storage** adds `<vault>/.sheaf/meta.json` (JSON map of path → flags).
   Multi-vault namespaces pins per root; there is no cross-vault pin file.
5. **Zoom** is app-wide *text* scaling via the framework text scaler — every
   surface grows/shrinks together, crisp at every step. Fixed-dp icons and
   layout metrics intentionally stay constant. The settings' editor **font
   size** tunes note-body type independently of zoom.
6. Plain `Ctrl+C/V/X` are native Flutter text behaviors; only the
   `Ctrl+Shift+` variants are added explicitly, and all are reserved against
   remapping.
7. Focus mode is session-scoped; OS fullscreen state follows the WM, not us.
8. **Multi-vault ordering** — merged notes sort by updated time, ties broken by
   vault index then path to keep ordering stable. Cross-vault folder rename is
   not supported; an operation routes to the owning vault.

## Tech Stack

Carried from v0.1 (Flutter Linux desktop, Material 3, `ChangeNotifier`
controllers, `google_fonts`, `markdown`/`markdown_widget`, `desktop_drop`,
`watcher`, `flutter_context_menu`) plus:

- **`window_manager`** (^0.5.x) — F11 OS fullscreen and the functional
  traffic-light window controls.
- **No new deps** for pins (hand-rolled JSON sidecar), shortcut serialization
  (`SingleActivator` round-trip), or multi-vault (per-root `VaultRepository`).

Known deviation from the v0.3 hygiene task: `pubspec.yaml` still pins
`sdk: ^3.14.0-95.2.beta`. The stable-SDK drop and any `dynamic_color` /
`material_ui` removal are **not** confirmed done — treat as open cleanup, not
as shipped.

## Commands

```bash
flutter run -d linux          # dev run
flutter analyze               # lint gate
flutter test                  # test gate
flutter test --coverage       # coverage gate (data+logic ≥80%)
scripts/build_appimage.sh     # package Linux AppImage (needs linuxdeploy)
```

## Project Structure

```
lib/theme/         → Quire tokens + world registry (Quire/Graphite/Sepia)
lib/models/        → AppSettings (mode, world, zoom, sizes, vaultPaths,
                     shortcutOverrides), shortcut_settings.dart
lib/data/          → vault_repository, settings_repository, markdown_parser
lib/logic/         → formatting.dart, list_continuation.dart,
                     find_controller.dart, zoom_controller.dart,
                     vault_controller.dart, shortcut_serializer.dart
lib/ui/editor/     → 3-mode editor, widgets/ (find bar, tag chip bar)
lib/ui/shell/      → pane model, focus mode, shortcuts, command palette
lib/ui/sidebar/    → recursive folder tree, widgets/ (folder_row, section)
lib/ui/note_list/  → virtualized list pane
lib/ui/common/widgets/ → hover_scrollbar
lib/ui/dialogs/    → settings dialog: Appearance, Keyboard Shortcuts
scripts/           → build_appimage.sh
docs/adr/          → 0001 vault/storage, 0004–0006 v0.2, 0007 open-notes tabs
```

## Code Style

Carried from v0.1: `ChangeNotifier` + `switch` expressions, injectable platform
seams for tests (`pickFolder` pattern), 2-space indent, single quotes. Widget
organization: any non-`State` widget class becomes a public `class Foo` in its
own file under a sibling `widgets/` directory; only `_FooState` may stay private
alongside its widget. Pure logic lives in `lib/logic` with zero Flutter imports
wherever possible (e.g. `formatting.dart` operates on `String` + offsets, not
controllers):

```dart
FormatEdit toggleWrap({required String text, required TextSelection sel, required String marker});
// returns new text + adjusted selection — trivially unit-testable
```

## Testing Strategy

Carried from v0.1: real temp dirs for `data/`+`logic/`, widget tests via
`flutter_test` with `tester.runAsync` for disk, spy controllers for dialogs,
failing-first regression tests for bugs. Coverage targets:

- `formatting.dart`, `list_continuation.dart`, `find_controller.dart`,
  `zoom_controller.dart`, `shortcut_serializer.dart`: ≥90% lines (pure logic).
- Meta.json round-trip incl. corrupt-file recovery and delete-cleanup;
  settings migration from single-path to `vaultPaths`.
- Widget: mode switch surface per mode; find bar count/jump/focus; recursive
  folder tree expand/collapse; tag chip bar; scrollbar hover/drag cursor;
  shortcut recorder conflict handling; pane toggle per tier.
- Security: preview image path-traversal rejection (`../../etc/passwd` renders
  a missing placeholder, no read).

## Boundaries

- **Always:** `flutter analyze` + `flutter test` green before done; Quire
  tokens/design docs govern visuals; hot reload pushed to running app after
  Dart edits; commit per task with Conventional Commits ≤72 chars.
- **Ask first:** adding dependencies; changing the vault contract
  (`.sheaf/meta.json`); settings schema growth (must stay backward-compatible).
- **Never:** hard-delete user content; hardcode colors outside `lib/theme`;
  write outside the vault except `.trash/`, `attachments/`, `.sheaf/`;
  regress v0.1–v0.3 stories (existing tests stay green).

## Success Criteria

v0.1–v0.2 criteria remain true (regression gate). v0.3 / v0.3.1 / v0.3.2 add:

- [x] `Ctrl+B/I/U` wrap/unwrap with selection, empty caret, Unicode words, and
      stacking (`Ctrl+B` → `Ctrl+I` → `***word***`); preview renders `<u>`
- [x] `Ctrl+Tab`/`Ctrl+Shift+Tab` walk the note list cyclically;
      `Ctrl+=/-/0` change/reset persistent text scale, clamped 50–200%
- [x] Mode switcher + `Ctrl+Shift+M` swap Normal/Markdown/Preview; persists
- [x] `Enter` continues `- `/`* `/`1. ` lists on any line, increments, and
      exits cleanly when the marker line is empty
- [x] Pin from hover + context menu; Pinned group first; survives restart;
      deleting removes the pin record
- [x] `Ctrl+F` find bar: count, traversal, Esc; highlight tracks body edits
      without closing the bar
- [x] Sidebar toggle per tier; `F10` focus mode; `F11` true fullscreen
- [x] Settings offer worlds × modes, zoom %, editor size 12–24; choices
      persist
- [x] Multi-vault: add a second root, notes merge newest-first, per-vault pins,
      delete/restore routes to the owning vault, legacy settings migrate
- [x] Remappable shortcuts (formatting reserved) persist across restart
- [x] Nested folder tree renders recursively and filters to the subtree
- [x] In-editor tag chips scroll with content; tapping inserts `#tag `
- [x] Scrollbar hand/grabbing cursor, state-owned thumb color, gutter never
      paints over text
- [x] Multi-line selection hugs text (tight boxes); prose column unbounded
- [x] Folder creation selects the new folder and shows a loading affordance
- [x] Sticky folder header; "DIRECTORIES" label on Linux
- [x] `scripts/build_appimage.sh` produces a runnable `Sheaf.AppImage`
- [ ] Open cleanup: research `dynamic_color` + `material_ui` removal
- [x] `flutter analyze` clean; `flutter test` green; new logic ≥90%;
      data+logic ≥80%

v0.3.3 adds (partial; in progress):

- [x] Opening from the note list or quick-switcher focuses the editor (caret
      visible and ready to type)
- [x] Editing the title then unfocusing renames the note without Enter
- [x] `Tab`/`Shift+Tab` indent/outdent lines by four spaces (spaces, not tabs)
- [x] Preview renders indents as list structure only — never as an indented
      code block
- [x] `flutter analyze` clean; `flutter test` green

## Decisions

Resolved 2026-08-24 (v0.2):

1. **GTK themes** — deferred. Curated hardcoded worlds + system accent cover
   v0.2; parsing arbitrary `gtk.css` is fragile.
2. **Font sources** — standard directories only. Superseded for the typeface
   picker, which was removed in feedback round 5 (bundled Google Fonts only).
3. **List continuation** — approved (story 15).
4. **Zoom scope** — app-wide text scaling; editor font size is the independent
   per-editor control (assumption 5 records the icon/padding tradeoff).
5. **New dependency** `window_manager` and the **`.sheaf/meta.json` vault
   sidecar** reviewed and approved.

Resolved during v0.3 / v0.3.1:

6. **Word definition** — Unicode-aware `\p{L}\p{N}_`, replacing ASCII `\w`
   (fixes accented and CJK words plus surrogate pairs).
7. **Combinable formatting** — stacking markers, not a toggle-one-style model;
   unwrap only the requested marker's smallest qualifying span.
8. **Multi-directory** — `List<String> vaultPaths` replaces `String vaultPath`;
   one `.sheaf/meta.json` per vault, no cross-vault state.
9. **List action bar** — deferred; the untested `EditorActionBar` /
   `list_formatting` / `link_formatting` scaffolding was deleted rather than
   shipped (story 21 deferral note).
10. **Keyboard shortcuts** — settings-driven `Map<String,String>` with
    `SingleActivator` serialization; formatting `Ctrl+B/I/U` stays hard-coded
    and reserved.
11. **Scrollbar gutter** — reserved inside content padding per editor mode
    rather than laid over text; built-in overlay scrollbar disabled.
12. **Selection paint** — `BoxWidthStyle.tight` for tight boxes; prose column
    intentionally unbounded, no reading-measure cap.
13. **Linux packaging** — AppImage via `linuxdeploy` + GTK plugin, driven by a
    checked-in script.
14. **Indentation policy (v0.3.3)** — Tab/Shift+Tab insert/remove spaces (four
    per level), per markdownformatting.com; indentation is structural, never a
    visual paragraph indent. The preview registers a custom `BlockSyntax` via
    `MarkdownGenerator.blockSyntaxList` that matches any leading whitespace
    (`^[ 	]+`) and emits a `<p>` with stripped content. Document syntaxes are
    tried before standard ones in `BlockParser.parseLines`, so the custom
    syntax wins over `CodeBlockSyntax` (which would otherwise turn 4-space+
    indents into a `<pre>` code block, and leave 1–3-space indents as visual
    indent). Nested lists and fenced code keep their structure.




