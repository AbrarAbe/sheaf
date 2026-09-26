# Changelog

All notable changes to this project will be documented in this file.

## [0.3.4] - 2026-09-26

### Added

- Add app screenshots and feature highlights
- Add Linux release status badge
- Add GoToTopFab to preview

### Changed

- Draft v0.3.4 "sticky state"
- Cache undo/redo history per note
- Cache preview scroll per note
- Cache edit scroll per note
- Wire edit scroll capture/restore per note
- Renumber v0.3.4 tasks after adding edit-scroll task
- Defer list wrap alignment to v0.3.5
- Hide attachments directory as .attachments
- Link color uses theme accent

### Fixed

- Undo survives mode switch
- FAB icon color uses onPrimaryContainer
- Image path URL encoding round-trip + legacy dir fallback
- FAB survives cold-start with cached scroll offset

## [0.3.3] - 2026-09-22

### Added

- Add caret bug fixes to v0.3.3 plan
- Add two-space indent / outdent line-edit primitives

### Changed

- Docs(readme): install binary via ~/.local/bin symlink, fix AppImage
- Spec + plan for v0.3.3 "type-first"
- Auto-focus the body when a note is opened
- Remember and restore the caret per note
- Commit the title rename on focus loss
- Wire Tab / Shift+Tab into the body editor
- Use four-space indent unit
- Strip leading whitespace from non-list prose
- Survey preview + editor overrides against the libraries
- V0.3.3

### Fixed

- Split publish into its own job for rebuild-free retry
- Move plan docs to its own directory
- Keep caret width after a trailing space in a heading
- Note title is the file name, not the first # heading

## [0.3.2] - 2026-09-17

### Added

- Add confirmation dialogs for note and trash delete with restore toast
- Add confirmation dialog for folder delete with strong warning
- Add metadata dialog via note context menu

### Changed

- Split context menu into Trash (soft) and Delete (permanent)
- Refactor(note-row): rename delete methods, add permanent delete with
- Ignore all AppImage build targets
- Improve scrolling and list layout in command palette
- Ignore AppDir directory in gitignore
- Auto-scroll on last-line Enter
- V0.3.2

### Fixed

- Move body padding into editor modes
- No-op refresh when vault vanishes mid-scan

## [0.3.1] - 2026-09-11

### Added

- Add linux installer
- Docs(plan): add v0.3.1 paper cuts — nested folders, find, chips,
- Add in-editor TagChipBar
- Add AppImage support for Linux distribution
- Add key param to public widgets

### Changed

- Update header initial to S
- Extract private widgets to sibling widgets/ folders
- Require private widgets be extracted to widgets/ folders
- Render nested folders with expand/collapse
- Scrollbar hover cursor and thumb fade
- Simplify find & tag containers
- Improve tag chip tooltip clarity and folder row styling
- Merged expand/collapse folder button
- Select new folder, sticky header, platform label
- Own padded scrollbar with hand cursor, drop 680 cap
- V0.3.1

### Fixed

- Keep find navigation focus in editor
- Word-only selection, no gutter highlight
- Tag focus, find match case, single scrollbar, collapsed folders
- Tag chip focuses tag in editor, not note filter
- Focus find bar when opened
- Constrain command palette height
- Fix(editor): constrain selection to prose column and use tight selection
- Make AppImage script executable and invoke via bash

### Removed

- Remove untested Task 11/12 action-bar fiction

## [0.3.0] - 2026-08-31

### Added

- Add README sync to linux release skill and update readme for v0.2
- Add v0.3 polish & multi-directory plan
- Support multi-directory vaultPaths with migration
- Add list and link/image toggle logic
- Add keyboard shortcut customization with responsive layout

### Changed

- Use curl and ~/.local/share install location for Linux tarball
- Triangulate git history for README sync; add push confirmation gate
- Make word-aware unicode and allow combinable styles
- Center focus mode with wider column
- Center title in focus mode
- Mark v0.3 tasks complete
- V0.3.0

### Fixed

- Continue at line end not text end, handle selection and clamp overflow
- Recompute matches on body edit without closing bar
- Preserve single-vault equality for round-trip
- Canonical nesting for bold/italic/underline combine
- Stop infinite italic wrap in bold and caret drift in underline
- Render combined *** and nested <u> correctly
- Curly braces and doc comment nits

## [0.2.0] - 2026-08-29

### Changed

- Scope v0.2 editor milestone with resolved decisions
- Extend schema for v0.2 editor and appearance
- App-wide view zoom with Ctrl+=/-/0
- Pure wrap/unwrap engine for bold, italic, underline
- Render <u> underline spans in markdown preview
- Three modes — Normal, Markdown, Preview
- Bind Ctrl+B/I/U formatting and Ctrl+Shift+C/V
- Continue markdown lists on Enter
- Ctrl+Tab cycles through visible notes
- Find-in-note bar with match traversal
- Tick phase 1-2 tasks, mark checkpoint A
- Live-render Normal mode; keys in both modes; top-aligned preview
- Hide markers until touched; Ctrl+D selects word
- Record feedback round 2 decisions and delight_toast findings
- Quire corner toast replaces snackbars
- User-owned sidebar visibility per tier
- Tick task 10
- Pin notes with .sheaf/meta.json sidecar
- Tick task 11
- Focus mode (F10) and OS fullscreen (F11)
- Tick task 12, note checkpoint B verification
- Theme worlds — Quire, Graphite, Sepia
- Tick task 13
- Type size, zoom stepper, and local font picker
- Tick task 14
- Audit sweep — drop dead decorations, fix stale copy
- Tick task 15
- V0.2 ADRs, README refresh, tick task 16
- Tick task 16 — v0.2 complete
- Focus-mode button joins the right cluster
- Functional traffic-light window controls
- Ctrl+K quick-switcher palette with search pill
- Scope chips replace the list-filter search
- Show when each entry was deleted
- Quire-styled context menus
- Tabs proposal (ADR 0007), spec/README refresh for round 5
- Row spacing/dimension tuning
- Hide image picker button, defer feature
- Quire context menu for the note body
- Docs(agents): update GitNexus metadata from taker to sheaf
- V0.2.0

### Fixed

- Pin repo links in cliff config and sync changelog
- Unwrap spans from caret or partial selection
- Del edits text while an editor holds focus
- Bare caret on a word formats the whole word
- Formatting toggles no longer nest or shrink selection
- Instant row highlight — no more hover flicker
- Search pill holds position when window dots hide
- Layer the header so chrome packs right and pill stays put
- Edit menu opens once — no more stacked duplicates
- Restore vertical centering lost by the layered Stack
- Italic toggle no longer splices nested markers
- Preserve caret/selection on format toggle, anchor preview left
- Enable formatting shortcuts in Markdown mode
- Sort listNotes newest-first to restore pinned order
- Package tarball with top-level dir so lib stays beside binary

### Removed

- Remove local-font feature, add window-controls flag

## [0.1.0] - 2026-08-24

### Added

- Add v0.1 spec and implementation plan
- Add vault, markdown, and desktop integration packages
- Add Quire Daylight/Lamplight token themes
- Add Note model and markdown structure parser
- Add settings repository with json persistence
- Add vault repository for notes, folders, trash
- Add responsive three-pane desktop shell
- Add folders, tags, and trash navigation
- Add searchable, day-grouped note list
- Add markdown editing pane with autosave
- Add markdown preview with resizable images
- Add image insertion via picker and drag-drop
- Add trash view with restore and delete-forever
- Add keyboard shortcuts and theme cycling
- Add settings dialog with theme and vault controls
- Add watcher and flutter_context_menu
- Add context menus, note deletion, and expanding filter
- Add keyboard navigation for the note list
- Implement Quire typography via Google Fonts
- Add git-cliff config and v0.1.0 changelog
- Add tag-triggered Linux release workflow

### Changed

- Init
- Bind development workflow to agent skills
- Mark tasks 1-2 complete
- Track Quire design language sources
- Mark task 3 complete
- Mark task 4 complete
- Mark task 5 complete, foundation phase done
- Wire controllers, welcome flow, and app bootstrap
- Mark task 6 complete
- Mark task 7 complete
- Mark task 8 complete
- Mark task 9 complete
- Wire selection to editor via in-memory notes
- Mark task 10 complete, core phase done
- Mark task 11 complete
- Mark task 12 complete
- Mark task 13 complete
- All 14 tasks complete
- Record storage, trash, state, and selection decisions
- Record v0.2 fixes (tasks 15-17)
- Replace scaffold with real project overview
- Replace placeholder description
- Use null-aware list element in _Section
- Archive v0.1 implementation plan as plan_v0.1.md
- Rename app from taker to sheaf
- Reindex codebase as sheaf

### Fixed

- Follow system theme on Wayland and Android
- Define washes with withValues for exact alpha
- Make note creation reachable from the UI
- Widen divider hit target to 12 dp
- Drop fill background from title and body fields
- Explicit parent for folder creation
- Adopt io.github.AbrarAbe.Taker application id

[0.3.4]: https://github.com/AbrarAbe/sheaf/compare/v0.3.3..v0.3.4
[0.3.3]: https://github.com/AbrarAbe/sheaf/compare/v0.3.2..v0.3.3
[0.3.2]: https://github.com/AbrarAbe/sheaf/compare/v0.3.1..v0.3.2
[0.3.1]: https://github.com/AbrarAbe/sheaf/compare/v0.3.0..v0.3.1
[0.3.0]: https://github.com/AbrarAbe/sheaf/compare/v0.2.0..v0.3.0
[0.2.0]: https://github.com/AbrarAbe/sheaf/compare/v0.1.0..v0.2.0
[0.1.0]: https://github.com/AbrarAbe/sheaf/tree/v0.1.0

