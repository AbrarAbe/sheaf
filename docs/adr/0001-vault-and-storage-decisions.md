# ADR-0001: Vault is plain files on disk

- Status: accepted (2026-08-23)
- Context: Sheaf must interoperate with other editors and keep user data
  portable, Obsidian-style.
- Decision: notes are ordinary `.md` files inside a user-chosen folder;
  `VaultRepository` is the only component doing filesystem I/O. No database,
  no hidden index files.
- Consequences: no query engine — search scans parsed in-memory notes
  (fine at v1 scale); external edits require a rescan (`VaultController.refresh`).

# ADR-0002: Settings live in one JSON file

- Status: accepted
- Context: only two settings (vault path, theme) needed persistence; shared_preferences adds a plugin dependency and platform-channel test friction.
- Decision: `SettingsRepository` reads/writes `<config-dir>/settings.json`
  via `path_provider`; the file is injected so tests use temp dirs. Missing,
  corrupt, or wrong-shaped files fall back to defaults.

# ADR-0003: Image resize uses Obsidian's `![alt|400]` syntax

- Status: accepted
- Context: CommonMark has no image sizing; users coming from Obsidian expect
  the pipe syntax.
- Decision: width rides in alt text (`![alt|400](rel/path)`); the preview's
  image builder parses it and constrains display width. Bare images render
  natural size; missing files degrade to an icon + alt-text fallback checked
  synchronously to avoid error flicker.

# ADR-0004: Trash = `.trash/` + `index.json`

- Status: accepted
- Context: deletes must be recoverable (spec boundary: never hard-delete),
  including whole folders, without losing the original path.
- Decision: deletions move items into `<vault>/.trash/` with uniquified names;
  `.trash/index.json` records `{trashedName, isFolder, originalPath,
  trashedAt}` per item. Restore renames back using the index; delete-forever
  removes both file and entry.

# ADR-0005: ChangeNotifier controllers, no state framework

- Status: accepted
- Context: app state fits three small controllers (vault, editor, theme).
- Decision: plain `ChangeNotifier` + `ListenableBuilder`. Selection/filter
  state lives on `VaultController`; note writes are single-writer through
  `EditorController` (debounced autosave, flush-before-switch/rename).

# ADR-0006: Note selection passes objects, not paths

- Status: accepted
- Context: list rows already hold fully parsed notes; re-reading from disk on
  selection both duplicates I/O and deadlocks widget tests that select notes
  inside their FakeAsync zone.
- Decision: `VaultController.selectNote(Note?)` carries the parsed object to
  the shell/editor; disk is touched only for writes (autosave, rename).
