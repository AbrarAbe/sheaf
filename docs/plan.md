# Implementation Plan: Taker v0.1

Implements [spec.md](spec.md). Order follows the dependency graph bottom-up,
sliced vertically: every phase ends with something runnable.

## Architecture Decisions

- **Vault = plain files on disk** (no DB). Repository layer is the only filesystem I/O.
- **Settings = one JSON file** under the platform config dir (`path_provider`),
  loaded through an injectable store so tests pass a temp dir. No `shared_preferences`.
- **State = ChangeNotifier controllers**, no state framework; widgets stay thin.
- **Image resize syntax `![alt|400](rel/path)`** — Obsidian-compatible; handled by a
  small pre-parser feeding `markdown_widget`'s image builder.
- Full rationale recorded in `docs/adr/`.

## Task List

### Phase 1: Foundation (pure Dart, headless-testable)

- [x] **Task 1: Dependencies & scaffold** (XS)
  - Acceptance: pubspec gains `path`, `path_provider`, `file_picker`, `markdown`,
    `markdown_widget`, `desktop_drop`, `intl`; analyze clean; app still boots.
  - Verify: `flutter pub get && flutter analyze && flutter test`
  - Files: `pubspec.yaml`

- [x] **Task 2: Quire theme module** (M)
  - Acceptance: `QuireColors` ThemeExtension (4 highlighters, focus ring),
    `buildQuireLight()/buildQuireDark()` matching every token in color.md/theming.md;
    lerp works; no hardcoded hexes anywhere else afterwards.
  - Verify: tests assert exact token values + ColorScheme role mapping table.
  - Files: `lib/theme/*`, `test/theme/*`

- [x] **Task 3: Models + Markdown parser** (M)
  - Acceptance: `Note` model; parser extracts inline `#tags` (skipping code fences
    and URLs), title (H1 else filename stem), image refs incl. `![alt|W](p)` widths.
  - Verify: pure-Dart unit tests with edge cases.
  - Files: `lib/models/note.dart`, `lib/data/markdown_parser.dart`, `test/data/markdown_parser_test.dart`

- [x] **Task 4: SettingsRepository** (S)
  - Acceptance: JSON `{vaultPath, themeMode}` load/save; missing/corrupt → defaults;
    round-trips.
  - Verify: unit tests on `Directory.systemTemp`.
  - Files: `lib/data/settings_repository.dart`, `test/data/settings_repository_test.dart`

- [x] **Task 5: VaultRepository** (L)
  - Acceptance: note CRUD; delete→`.trash/` + restore; folder create/rename/delete;
    folder-tree scan; attachments helper; filename slugging; ignores dot-dirs.
  - Verify: unit tests on real temp vaults (round-trip, trash semantics, tree shape).
  - Files: `lib/data/vault_repository.dart`, `test/data/vault_repository_test.dart`

### Checkpoint: Foundation
- [ ] Analyze clean, all green, data-layer coverage ≥80%.

### Phase 2: Core vertical slices

- [x] **Task 6: Controllers + app bootstrap** (M)
  - Acceptance: `VaultController` (vault path lifecycle, selection state),
    `EditorController` (debounced autosave ≤1 s, dirty flag); no-vault state shows
    chooser (`file_picker`); hello world replaced.
  - Verify: controller unit tests (injectable clock for debounce); widget test for chooser.
  - Files: `lib/logic/*.dart`, `lib/app.dart`, `lib/main.dart`, `lib/ui/dialogs/vault_picker.dart`

- [x] **Task 7: Responsive three-pane shell** (M)
  - Acceptance: Expanded ≥1120 / Full 720–1119 / Stack <720 per layout doc;
    sidebar↔rail collapse persists; draggable dividers clamp (sidebar 200–320,
    list 300–420); min window 360×560.
  - Verify: widget tests pump at tier widths, assert pane visibility/rail width.
  - Files: `lib/ui/shell/*`

- [x] **Task 8: Sidebar** (M)
  - Acceptance: folder tree; tag list with counts; Trash entry lists `.trash/`;
    ink-wash selection; context menus create/rename/delete folder.
  - Verify: widget tests with seeded temp vault.
  - Files: `lib/ui/sidebar/*`

- [x] **Task 9: Note list** (M)
  - Acceptance: rows (title, snippet, mono time) under day eyebrows; recent-first;
    filter box matches title+body, title-priority ranking; empty-state copy from
    design voice.
  - Verify: search-ordering unit tests; widget tests for grouping/filter/empty.
  - Files: `lib/ui/note_list/*`, `lib/logic/search_controller.dart`

- [x] **Task 10: Editor slice** (L)
  - Acceptance: monospace source editing; debounced autosave writes `.md`; title row
    renames file; tag chips row; mono footer `saved HH:MM`/`saving…`; Del deletes
    with undo toast; `Ctrl+N` creates note in selected folder.
  - Verify: controller tests (debounce, rename); widget tests (status text, undo).
  - Files: `lib/ui/editor/*`, `lib/logic/editor_controller.dart`

### Checkpoint: Core
- [ ] Manual Linux flow: choose vault → create folder → notes → restart → restored.

### Phase 3: Rich content & polish

- [x] **Task 11: Markdown preview** (M)
  - Acceptance: edit/preview toggle renders GFM subset (headings, emphasis, lists,
    task lists, quotes, fenced code, links, tables) via Quire tokens;
    `![alt|400](…)` constrains width; bare images natural size.
  - Verify: widget tests for structure + width constraint; parser tests for resize syntax.
  - Files: `lib/ui/editor/preview.dart`, `lib/data/markdown_parser.dart`

- [x] **Task 12: Image insertion** (M)
  - Acceptance: picker/drop copies into `<vault>/attachments/` (dedupe names) and
    inserts relative link at cursor.
  - Verify: repo-level copy/dedupe unit tests; widget test for insert-at-cursor.
  - Files: `lib/ui/editor/image_insert.dart`, `lib/data/vault_repository.dart`

- [x] **Task 13: Trash UX** (S)
  - Acceptance: trash view lists deleted notes with restore + "Delete forever";
    restore returns to original folder (recorded in frontmatter-free sidecar or
    path-encoded name — ADR).
  - Verify: repo tests for encode/restore round-trip.
  - Files: `lib/ui/sidebar/trash_view.dart`, `lib/data/vault_repository.dart`

- [x] **Task 14: Shortcuts + theme cycle** (S)
  - Acceptance: `Ctrl+N`, `Ctrl+\`, `Ctrl+Shift+L` cycle System→Light→Dark persisted,
    `↑/↓`+`Enter` list navigation, focus rings visible everywhere.
  - Verify: widget tests pump shortcuts and assert effects.
  - Files: `lib/ui/shell/shortcuts.dart`, `lib/logic/theme_controller.dart`

### Checkpoint: Complete
- [x] All spec success criteria checked; analyze + full suite green.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `file_picker`/`path_provider` need platform channels (untestable in plain tests) | Med | Keep behind repository interfaces; UI tests use fakes |
| Non-standard `\|width` image syntax vs markdown_widget defaults | Med | Pre-parse to width metadata before render; fallback natural size |
| Autosave races with rename/delete | High | Single-writer rule: EditorController owns writes for its note only |
| Large vaults slow tree scan | Low | v1 loads lazily per folder; optimize later if needed |

## Open Questions

Carried from spec.md — proceeding on documented assumptions unless redirected.
