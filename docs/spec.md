# Spec: Taker v0.1 — Markdown Notes MVP ("the desk")

## Objective

Turn the hello-world Flutter shell into a working desktop-first note app for Linux,
following the Quire design language in `docs/design/`. Users keep a **vault** — an
ordinary folder of plain Markdown files — exactly like Obsidian. Success looks like:
open the app, pick/create a vault folder, and take, find, organize, and read back
notes with images and tags, all persisted as portable `.md` files.

### User stories (acceptance criteria)

1. **Vault** — As a user I choose a folder as my vault (or create one). The choice
   persists across restarts. My notes are plain files I could open in any editor.
2. **Notes** — I create, edit, rename, and delete notes. Deleting moves the file to
   `<vault>/.trash/` and I can restore it. Edits autosave within ~1 second of typing.
3. **Folders** — The sidebar shows my vault's folder tree. I create, rename, and
   delete folders; new notes land in the selected folder; notes can be moved.
4. **Tags** — Inline `#tag` syntax in note bodies is parsed, shown as chips, listed
   in the sidebar, and clicking one filters the note list.
5. **Markdown** — The editor writes raw Markdown (monospace, per design doc).
   Preview renders headings, emphasis, lists, task lists, blockquotes, fenced code,
   links, tables, and images.
6. **Images** — `![alt|400](attachments/foo.png)` renders at 400 px wide (Obsidian
   resize syntax; bare `![alt](path)` renders natural size). Inserting an image
   copies it into `<vault>/attachments/` and emits the relative link. Resizing is
   editable by changing the number.
7. **Search** — The list filter matches title and body across the vault, ranking
   title hits first; results update as I type.
8. **Shell** — Three-pane desktop shell per `layout-and-space.md` (sidebar /
   note list / editor) with Expanded ≥1120 dp, Full 720–1119 dp, Stack <720 dp;
   sidebar collapses to a rail; panes resize by dragging.
9. **Theme** — Daylight/Lamplight/System per `theming.md`, cycled with
   `Ctrl+Shift+L`, choice persisted; no hardcoded colors outside the theme module.

Explicitly **deferred** (tracked in Open Questions): global hotkey capture window,
command palette, reminders, sync, mobile fold-down polish, WYSIWYG editing.

## Assumptions (correct me and I'll amend the spec)

1. Files-on-disk vault model — no database, no hidden index files in v1.
2. Source-mode editor + rendered preview toggle (like Obsidian's edit/read modes),
   not WYSIWYG.
3. Tags are inline `#tags` only (no YAML frontmatter in v1).
4. Note title = H1 if present, else filename stem. Renaming a note renames its file.
5. Images referenced by vault-relative paths; `attachments/` is the default home.
6. Linux desktop is the only launch target this milestone (matches `linux/` dir).
7. New pub.dev dependencies are allowed (listed under Tech Stack) — flag if you want
   any swapped.

## Tech Stack

- Flutter (SDK ^3.14) targeting Linux desktop, Material 3
- State: `ChangeNotifier` controllers (no state-framework dependency)
- New dependencies: `file_picker` (folder chooser), `shared_preferences`
  (lightweight prefs), `path`, `markdown` + `markdown_widget` (GFM rendering),
  `desktop_drop` (image drop-in), `intl` (day grouping)
- Dev: `flutter_lints`, `flutter_test`

## Commands

```sh
flutter pub get            # install deps
flutter analyze            # lint — must be clean
flutter test               # all unit + widget tests — must pass
flutter run -d linux       # launch desktop app
flutter test --coverage    # coverage report
```

## Project Structure

```
lib/
  main.dart              # entrypoint
  app.dart               # MaterialApp, theme wiring, theme-mode controller
  theme/                 # Quire tokens → ColorScheme + QuireColors extension
  models/                # Note, TagRef, FolderNode (pure Dart)
  data/
    vault_repository.dart    # all filesystem I/O for notes/folders/trash
    settings_repository.dart # vault path + theme preference persistence
    markdown_parser.dart     # tag extraction, image-ref extraction, title
  logic/                 # VaultController, EditorController, SearchController
  ui/
    shell/               # three-pane responsive scaffold
    sidebar/  note_list/  editor/  dialogs/  common/
test/
  data/  logic/          # pure-Dart unit tests (real temp dirs, no mocks)
  ui/                    # widget tests
docs/
  spec.md  plan.md  adr/ # this file, task breakdown, decision records
```

## Code Style

Follow `analysis_options.yaml` (flutter_lints) and existing formatting. Pure logic
lives outside widgets so it is testable headlessly:

```dart
// GOOD: testable service, injected root, no Flutter imports
class VaultRepository {
  VaultRepository({required Directory root}) : _root = root;
  final Directory _root;

  Future<Note> createNote(String folder, String title) async { /* … */ }
}

// Widgets stay thin: read state from controllers, emit intents back.
```

UI resolves every color through `Theme.of(context)` + `QuireColors` — never literals.

## Testing Strategy

- **Unit (dart:test via flutter_test):** `data/` and `logic/` run against real
  temporary directories (`Directory.systemTemp`) — no filesystem mocks. Parser
  cases cover tags, titles, image links, edge whitespace.
- **Widget:** shell tier switching, sidebar interactions, editor autosave debounce,
  empty states, theme cycling.
- **Coverage expectation:** ≥80% lines for `lib/data` + `lib/logic`.
- Every bug fix lands with a failing-first regression test.

## Boundaries

- **Always:** `flutter analyze` + `flutter test` green before calling work done;
  follow Quire tokens/copy from the design docs; document deviations as ADRs.
- **Ask first:** changing the vault file format or settings schema, adding
  dependencies beyond the stack above, touching `android/` targets.
- **Never:** write outside the chosen vault except its `.trash/`/`attachments/`;
  hard-delete user content (trash only); hardcode colors/hex outside `lib/theme`.

## Success Criteria

- [ ] `flutter run -d linux` shows the three-pane shell in all three window tiers
- [ ] Pick/create vault persists across restart; reopening restores tree + selection
- [ ] Note CRUD round-trips to real `.md` files; delete → `.trash/` → restore works
- [ ] Autosave fires ≤1 s after last keystroke; status footer shows mono `saved HH:MM`
- [ ] `#tags` extracted, sidebar-listed, click-to-filter works
- [ ] Markdown preview renders the feature list above; `![alt|400](…)` sizes images
- [ ] Image insert copies into `attachments/` and rewrites the link vault-relative
- [ ] Search filters by title/body with title-priority ordering
- [ ] `flutter analyze` clean; `flutter test` all green; data+logic coverage ≥80%

## Open Questions

1. Global hotkey quick-capture (`Ctrl+Alt+N`) needs tray/window-manager plugins —
   separate milestone?
2. Command palette (`Ctrl+K`) — same question.
3. Reminders quick-filter appears in the design but wasn't in your feature list —
   out of scope for v0.1?
4. Should renaming a folder rewrite note paths silently, or prompt?
