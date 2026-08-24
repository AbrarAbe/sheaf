# Spec: Sheaf — living product spec

Milestone history: v0.1 ("the desk") shipped and released as `v0.1.0`. This
revision adds milestone **v0.2 ("the editor")**: keyboard-complete editing,
editor modes, real pinning, find-in-note, user-controlled panes, fullscreen,
and appearance customization.

## Objective

Make the desk feel like a mature editor. A v0.1 user can take notes but edits
with bare hands: no formatting keys, no find-in-note, no way to pin, forced
pane layouts, one look. Success looks like: every common action reachable from
the keyboard, the editor offers Normal/Markdown/Preview like Obsidian, panes
obey the user instead of the window width, and the settings page meaningfully
changes how the app looks (worlds, zoom, type size, typeface).

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

### User stories — v0.2

10. **Formatting keys** — While editing (either editing mode):
    `Ctrl+B` toggles `**bold**`, `Ctrl+I` toggles `*italic*`, `Ctrl+U` toggles
    `<u>underline</u>` around the selection — wrapping when there is a
    selection, inserting an empty pair and placing the caret inside when not;
    invoking on any text already inside a wrapped span (exact selection,
    partial selection, or bare caret inside) unwraps that span. Terminal-style
    `Ctrl+Shift+C` / `Ctrl+Shift+V` copy/paste the focused editor selection
    (plain `Ctrl+C/V/X` keep working natively). Preview renders `<u>`
    underlined; all other raw HTML stays literal.
11. **Navigation & zoom keys** — `Ctrl+Tab` / `Ctrl+Shift+Tab` select the
    next/previous note in the current list order. `Ctrl+=` / `Ctrl+-` step the
    app-wide text scale by 10% within 50%–200%, `Ctrl+0` resets to 100%. The
    zoom level persists across restarts and scales text everywhere
    (list, sidebar, editor, preview) — icons and layout metrics are unaffected.
12. **Editor modes** — Three-way switch (segmented control in the editor
    header, cycled by `Ctrl+Shift+M`). Both editing modes share the same
    buffer and the same keyboard behaviors (formatting, list continuation,
    find): **Normal** — word-like reading surface: written formatting
    *renders live* (bold looks bold, italics slant, `<u>` underlines, headings
    scale) with markers dimmed rather than hidden, proportional type;
    **Markdown** — raw source view in monospace, no styling; **Preview** —
    rendered read-only output. Autosave behaves identically in all modes.
    The last-used mode persists as the opening mode for the next session.
13. **Pinning** — Notes can be pinned from the row's hover pin button (today a
    dead stub) and the note context menu. Pinned notes sort into a **Pinned**
    group above the rest of the list with a filled-pin indicator; unpinning
    restores normal ordering. Pin state must not modify note `.md` files — it
    lives in a vault-sidecar `<vault>/.sheaf/meta.json` (same philosophy as
    `.trash/index.json`). Deleting a note drops its pin record.
14. **Find in note** — `Ctrl+F` opens a find bar docked in the editor: query
    field (pre-filled with the selection if any), match counter `n/m`,
    next/previous (`Enter` / `Shift+Enter` plus buttons), highlight of the
    current match via selection jump, `Esc` closes and restores focus. Works
    in Normal and Markdown modes.
15. **List continuation** — Pressing `Enter` at the end of a list item
    continues the list: `- `, `* `, `- [ ] ` carry over verbatim; `1. `
    increments to `2. `; leading indentation is preserved. `Enter` on a line
    holding only a marker clears it (smart exit), matching Obsidian. Active
    in Normal and Markdown editing.
15. **Pane control** — Sidebar visibility is user-owned, not tier-forced:
    - Expanded (≥1120): `Ctrl+\` and a header toggle collapse to the rail or
      restore (unchanged).
    - Full (720–1119): a header toggle button shows/hides the sidebar
      completely; no forced rail.
    - Stack (<720): the same button opens/closes the sidebar as an overlay
      drawer.
    - Choice persists per tier across sessions (per layout-and-space.md).
    - **Focus mode**: a header button (and `F10`) hides sidebar and note list
      so the editor fills the window; any pane toggle or `F10` again exits.
    - **OS fullscreen**: `F11` toggles true window fullscreen via a window
      manager plugin.
16. **Appearance settings** — The settings page grows an Appearance section:
    - **Theme worlds**: curated hardcoded worlds beyond Daylight/Lamplight
      (launch set: **Graphite** neutral light/dark, **Sepia** paper-warm
      light/dark), selected alongside the existing System/Light/Dark mode —
      i.e. pick a world *and* a mode. All worlds defined purely as token sets
      in `lib/theme`; nothing outside reads hex.
    - **Zoom**: default view zoom percent (persisted; story 11 keys adjust it).
    - **Type size**: editor base font size (12–24 px) applied to editor body
      and preview.
    - **Typeface**: font family picker listing fonts discovered in standard
      Linux directories (`~/.fonts`, `~/.local/share/fonts`,
      `/usr/share/fonts`); the chosen font loads at runtime (`dart:ui`
      FontLoader) and applies to editor body + preview; falls back silently
      to the bundled stack if the file is missing at launch.

Explicitly **deferred**: command palette (`Ctrl+K`), global hotkeys
(`Ctrl+Alt+N`), reminders, sync/mobile polish, WYSIWYG editing, parsing local
GTK themes' CSS into color worlds (see Open Questions), bundling additional
Google Fonts as offline assets.

## Assumptions

1. v0.1 assumptions carry over (files-on-disk vault, source-mode editor +
   preview, inline tags, H1/filename titles, Linux-only).
2. **Normal vs Markdown distinction**: same buffer, same keybindings;
    Normal *renders* formatting live (styled spans, dimmed markers — not
    full WYSIWYG: markers stay selectable/editable), Markdown shows the raw
    monospace source. True marker-hiding WYSIWYG stays deferred.
3. **Underline** has no native Markdown; we use `<u></u>` and teach the
   preview's renderer that one tag (minimal inline-HTML support, nothing else).
4. **Pin storage** adds `<vault>/.sheaf/meta.json` (JSON map of path → flags).
   This touches the vault contract — flagged for review below.
5. **Zoom** is app-wide *text* scaling via the framework text scaler — every
   surface (list, sidebar, editor, preview, menus) grows/shrinks together,
   crisp at every step. Fixed-dp icons and layout metrics intentionally stay
   constant: Flutter re-renders text at any scale without quality loss, but
   scaling painted pixels would blur them. The settings' editor **font size**
   tunes note-body type independently of zoom.
6. Plain `Ctrl+C/V/X` are native Flutter text behaviors already; only the
   `Ctrl+Shift+` variants are added explicitly.
7. Focus mode is session-scoped; OS fullscreen state follows the WM, not us.

## Tech Stack

Unchanged from v0.1 (Flutter ^3.14 Linux desktop, Material 3,
ChangeNotifier controllers, google_fonts, markdown/markdown_widget,
desktop_drop, watcher, flutter_context_menu, dynamic_color/material_ui) plus:

- **New dependency:** `window_manager` (^0.5.x) — F11 OS fullscreen. Nothing
  on the current stack can fullscreen the native window.
- **No new deps** for fonts (directory scan + `dart:ui` FontLoader) or pins
  (hand-rolled JSON sidecar).

## Commands

```bash
flutter run -d linux          # dev run
flutter analyze               # lint gate
flutter test                  # test gate
flutter test --coverage       # coverage gate (data+logic ≥80%)
```

## Project Structure

```
lib/theme/         → Quire tokens; NEW: world registry (Quire/Graphite/Sepia)
lib/models/        → NEW fields on AppSettings (mode, world, zoom, sizes, fonts)
lib/data/          → NEW: font_scanner.dart; vault_repository gains meta.json API
lib/logic/         → NEW: formatting.dart, find_controller.dart, zoom_controller.dart
lib/ui/editor/     → 3-mode editor, find bar, formatting keybindings
lib/ui/shell/      → pane visibility model, focus mode, new shortcuts
lib/ui/dialogs/    → settings dialog: Appearance section
docs/adr/          → decisions: meta.json sidecar, zoom model, theme worlds
```

## Code Style

Carried from v0.1: `ChangeNotifier` + `switch` expressions, private widgets
prefixed `_`, injectable platform seams for tests (`pickFolder` pattern),
2-space indent, single quotes. Pure logic lives in `lib/logic` with zero
Flutter imports wherever possible (e.g. `formatting.dart` operates on
`String` + offsets, not controllers):

```dart
FormatEdit toggleWrap({required String text, required TextSelection sel, required String marker});
// returns new text + adjusted selection — trivially unit-testable
```

## Testing Strategy

Carried from v0.1: real temp dirs for `data/`+`logic/`, widget tests via
`flutter_test` with `tester.runAsync` for disk, spy controllers for dialogs,
failing-first regression tests for bugs. New coverage targets:

- `formatting.dart`, `find_controller.dart`, `zoom_controller.dart`,
  `font_scanner.dart`: ≥90% lines (pure logic).
- Meta.json round-trip incl. corrupt-file recovery and delete-cleanup.
- Widget: mode switch renders correct surface per mode; find bar counts and
  jumps; pane toggle in all three tiers; settings dialog new controls.

## Boundaries

- **Always:** `flutter analyze` + `flutter test` green before done; Quire
  tokens/design docs govern visuals; hot reload pushed to running app after
  Dart edits; commit per task with Conventional Commits ≤72 chars.
- **Ask first:** adding dependencies (`window_manager` requested here);
  changing the vault contract (`.sheaf/meta.json` requested here); settings
  schema growth (fields enumerated in story 16, backward-compatible).
- **Never:** hard-delete user content; hardcode colors outside `lib/theme`;
  write outside the vault except `.trash/`, `attachments/`, `.sheaf/`;
  regress v0.1 stories (all 130+ existing tests stay green).

## Success Criteria

v0.1 criteria remain true (regression gate). v0.2 adds:

- [ ] `Ctrl+B/I/U` wrap/unwrap correctly with selection, empty caret, and
      repeat-invocation; preview shows `<u>` underlined
- [ ] `Ctrl+Tab`/`Ctrl+Shift+Tab` walk the note list cyclically
- [ ] `Ctrl+=/-/0` change/reset persistent app-wide text scale, clamped
      50–200%
- [ ] Mode switcher + `Ctrl+Shift+M` swap Normal/Markdown/Preview; mode
      persists; autosave works in every mode
- [ ] `Enter` continues `- `/`* `/`1. ` lists with correct increments and
      exits cleanly when the marker line is empty
- [ ] Pin from hover + context menu; Pinned group orders first; survives
      restart; deleting removes the pin record
- [ ] `Ctrl+F` find bar: count, Enter/Shift+Enter traversal, Esc closes;
      selection lands on each match
- [ ] Header toggle shows/hides sidebar in Full tier and drawers it in Stack;
      per-tier state persists
- [ ] `F10` focus mode collapses to editor-only; `F11` true fullscreen
- [ ] Settings offer ≥3 worlds × 3 modes, zoom %, editor size 12–24, font
      picker from system dirs; choices persist and survive missing-font launch
- [ ] `flutter analyze` clean; `flutter test` green; new logic ≥90%;
      data+logic ≥80%

## Decisions (resolved 2026-08-24)

1. **GTK themes** — deferred. Curated hardcoded worlds + system accent cover
   v0.2; parsing arbitrary `gtk.css` is fragile.
2. **Font sources** — standard directories only (`~/.fonts`,
   `~/.local/share/fonts`, `/usr/share/fonts`). No file-browser entry.
3. **List continuation** — approved (story 15).
4. **Zoom scope** — app-wide text scaling; editor font size is the
   independent per-editor control (assumption 5 records the icon/padding
   tradeoff).
5. **New dependency** `window_manager` and the **`.sheaf/meta.json` vault
   sidecar** were reviewed and approved alongside these answers.
