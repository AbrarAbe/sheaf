# Implementation Plan: Sheaf v0.3 — "polish & power"

Derived from `docs/spec.md` v0.2 + codebase audit 2026-08-31 and user brief (5 feature asks). Ordered by dependency; each task lands as its own Conventional Commit behind `flutter analyze` + `flutter test` gates.

## Overview

Three thrusts: (1) correctness & perf hardening surfaced by audit (word-aware italic contamination, list Enter on middle lines, preview sync I/O, rebuild storms), (2) user-requested formatting power (true word-aware, combinable styles, action-bar/context-menu lists, link/image), (3) multi-directory vaults. Foundations (pure-logic formatting/list/find + HighlightingController) come first so UI slices stay thin.

## Architecture Decisions

- **Word definition = Unicode-aware** — `\w` (ASCII `[A-Za-z0-9_]`) is retired. Word = maximal run of `\p{L}\p{N}_` (letters+numbers from any script) via `RegExp(r'[\p{L}\p{N}_]+', unicode:true)` or `characters` package. Fixes `café naïve 中文` splitting and surrogate-pair emoji. (replaces `lib/logic/formatting.dart:74,295`)
- **Combinable formatting = stacking markers, not toggle-one-style** — `toggleWrap` gains no new concept; instead the engine guarantees that `*`, `**`, `<u>` are orthogonal and `***`/`**<u>` nest predictably. Rule: unwrap only the requested marker's smallest qualifying span; wrapping nests. Enables `Ctrl+B` then `Ctrl+I` → `***word***`. (no new storage)
- **Multi-directory = `List<String> vaultPaths` replacing `String vaultPath`** — `AppSettings.vaultPaths` (primary = index 0), `VaultController` holds `List<VaultRepository>`, operations fan-out but `selectedFolder` is scoped to `(vaultIndex, relPath)`. `.sheaf/meta.json` per vault (no cross-vault pin file). `watcher` fans out per vault. Single-vault JSON migrates via `fromJson` tolerant read.
- **Action bar = `EditorActionBar` widget** owned by `EditorPane` header, emitting `FormatKind`/`ListKind`/`LinkKind` intents; context menu mirrors same intents via `quireMenu`. No new dependency.
- **Rebuild scoping** — `VaultController` stays as source of truth but UI subscribes via `Selector`/`ValueListenable` per slice (notes vs folders vs tagCounts) or splits into `notesListenable/folderListenable`. Prevents per-keystroke full-shell rebuild.
- **Preview image I/O async** — `_image` becomes async-aware: `FutureBuilder` + `FileImage` with `cacheWidth`, `errorBuilder`, traversal guard (`p.normalize` + `isWithin`). No sync `existsSync()` in `build`.

## Task List

### Phase 1 — Correctness foundations (pure logic, headless-testable)

- [ ] **Task 1: Word-aware formatting, Unicode + not interfered by other word's `*`**
  Fix `lib/logic/formatting.dart:47-82,175-243,291-314`.
  - Replace `isWord`/`wordBoundary` with Unicode word run (`\p{L}\p{N}_`), static `RegExp` (no per-char construction). Treat `*`/`**` and list markers (`- `, `* `) as non-word; scanning skips them when locating word bounds (already partially done for italic, generalize to all markers).
  - "Not interfered by other word's `*`" → `_enclosingSpan` smallest-qualifying-span rule already prevents other-word bleed, but fix touchingOnly gap (caret between `*a* *b*` at 3 unwraps first span) by requiring `start==stop==caret` and `mStart<caret && caret<mEnd` strictly interior, not inclusive of `mEnd`. Word expansion must not cross `*`/`<u>` boundaries.
  - Clamp/normalize selection (`min/max`) before `toggleWrap`.
  - Acceptance: `café` caret formats `*café*`; `hello *a* world *b*` caret on `b` only touches `*b*`; `*a* *b*` caret on inter-word space inserts empty pair, does not unwrap `*a*`.
  - Verify: `flutter test test/logic/formatting_test.dart` — new groups: unicode words, CJK, emoji surrogate, inter-word gap, list-marker isolation.
  - Files: `lib/logic/formatting.dart`, tests.
  - Scope: M

- [ ] **Task 2: Combinable formatting (bold+italic+underline stack)**
  Depends on Task 1.
  - Allow `inner.contains('*')` when inner is `**…**` or `<u>…</u>`; reject only bare `*` inside italic inner would break nesting. Change italic inner validation to permit `**` pairs but not lone `*` not forming `**`. Bold inner may contain `*`/`_u` freely.
  - Add edge-case guard: `***word***` unwrapping `*` yields `**word**`, unwrapping `**` yields `*word*` — verify via piecewise offset map already correct; add tests.
  - `_toggleAroundSelection` exact-wrap branch: require inner trimmed non-empty and not pure whitespace (prevent `****`→``).
  - Acceptance: `Ctrl+B` then `Ctrl+I` on `word` → `***word***`; second `Ctrl+B` → `*word*`; `Ctrl+U` stacks: `***<u>word</u>***` order-independent; preview renders nested underline+bold italic correctly.
  - Verify: formatting_test combinable group; manual cycle `word` → bold → bold+italic → italic → plain.
  - Files: `lib/logic/formatting.dart`, `lib/ui/editor/highlighting_controller.dart` (inline Regex already bold-first, ensure underline `<u>` style stacks), tests.
  - Scope: S

- [ ] **Task 3: List continuation critical fix + extensions**
  Fix `lib/logic/list_continuation.dart:24-33,52-60`.
  - Replace `lineEnd = text.indexOf('\n', caret); if(lineEnd!=-1) return null;` with proper end-of-line check: `lineEnd = text.indexOf('\n', caret); if(lineEnd!=-1 && caret != lineEnd) return null;` plus handle selection: new signature `continueList({required String text, required int selStart, required int selEnd})` replaces selection range with `\n`+marker when non-collapsed (mirrors normal typing).
  - Static RegExps, guard `int.parse` with try/catch + clamp to `1..9999`; keep marker style (`)` vs `.`) through increment.
  - Smart-exit: replaceRange includes indent (`lineStart`..`caret`) not `indent.length` offset, producing empty line not whitespace.
  - Acceptance: `"- a\n- b\nnext"` caret at end of `"- b"` continues to `"- "`; `"  - "` Enter clears to `""`; `"9999999999. x"` Enter does not throw.
  - Verify: `flutter test test/logic/list_continuation_test.dart` — middle-line, selection-overwrite, indent, overflow cases.
  - Files: `lib/logic/list_continuation.dart`, `lib/ui/editor/editor_pane.dart:331-349` (pass selection not just caret).
  - Scope: S

- [ ] **Task 4: FindController staleness + perf**
  Fix `lib/ui/editor/editor_pane.dart:353-402`, `lib/logic/find_controller.dart:9-28`.
  - Add `_body.addListener(_recomputeFind)` when `_findOpen` and remove on close/dispose; `_recomputeFind` re-runs `matchOffsets` and preserves `_matchIndex` clamped.
  - Cache `text.toLowerCase()` per body change, not per query keystroke; debounce find `onChanged` 80 ms.
  - Fix `_lastQuery.length` offset after body shift: recomputed matches cover it; no extra length bookkeeping.
  - Acceptance: open find `hello` at 100, type 10 chars before 100 → highlight tracks to 110, counter updates without closing bar.
  - Verify: widget test find bar with body edit; logic test lower-cache.
  - Files: `lib/logic/find_controller.dart`, `lib/ui/editor/editor_pane.dart`.
  - Scope: S

### Phase 2 — Performance & stability hardening

- [ ] **Task 5: Rebuild scoping & watcher de-dupe**
  Fix `lib/app.dart:20-32`, `lib/ui/shell/shell.dart:187-267`, `lib/ui/sidebar/sidebar.dart:52-95`, `lib/logic/vault_controller.dart:253-307`.
  - `app.dart`: split `VaultController` into selectors or introduce `ValueNotifier<AppSettings>` for theme/zoom so `MaterialApp` rebuilds only on settings change, not on every note-list notify.
  - `VaultController.refresh`: add monotonic `int _gen` and cancel stale results (`if(gen!=_gen) return;` after each await); `visibleNotes`/`tagCounts` memoize per `_notes` identity.
  - `Sidebar`/`ListPane`: listen to `folders`/`tagCounts` slice only, not whole controller.
  - Acceptance: typing in editor (autosave) does not rebuild sidebar folder tree; folder tree rebuild only on folder create/rename.
  - Verify: widget test counting builds via spy listener; `flutter test test/logic/vault_controller_test.dart` gen guard.
  - Files: `lib/app.dart`, `lib/logic/vault_controller.dart`, `lib/ui/sidebar/sidebar.dart`, `lib/ui/note_list/list_pane.dart`.
  - Scope: M

- [ ] **Task 6: Editor highlighting & preview perf**
  Fix `lib/ui/editor/highlighting_controller.dart:16-110`, `lib/ui/editor/markdown_preview.dart:243-282`.
  - `HighlightingController`: static compiled `_inline`, `_heading`; memoize last `text` parse result and only re-parse on text change (caret move reuses spans, only `markerStyle` alpha flips). Use `characters` length where needed.
  - `MarkdownPreview._image`: replace `existsSync()` with `FutureBuilder` checking existence off main isolate; `Image.file` → `FileImage` with `cacheWidth` (parse `|400` once), traversal guard (`_relOf` style check rejects `..`/`/` absolute), `errorBuilder` for missing.
  - Acceptance: 50 KB note with 10 images, caret arrow 60 fps no jank; image of `![](../../../etc/passwd)` shows missing placeholder, does not read file.
  - Verify: perf bench widget test (frame budget); preview security test for traversal.
  - Files: `lib/ui/editor/highlighting_controller.dart`, `lib/ui/editor/markdown_preview.dart`.
  - Scope: M

- [ ] **Task 7: ListPane virtualization & resource leaks**
  Fix `lib/ui/note_list/list_pane.dart:235-290`, `lib/ui/shell/command_palette.dart:38-65`, `lib/ui/editor/editor_pane.dart:175-214`.
  - `ListPane`: `ListView(children: blocks)` → `CustomScrollView` with `SliverList.builder` per group (pinned + day sections); prune `_rowKeys` on `didUpdateWidget` (remove keys whose path not in `notes`).
  - `CommandPalette`: compute `_results` once per build/query change, debounce, dispose `_query` controller.
  - `HighlightingController` word-count: memoize `words` per text change, static `RegExp(r'\s+')`.
  - Acceptance: 2000-note vault scrolls at 60 fps; heap snapshot shows bounded GlobalKeys; palette typing no double sort per keystroke.
  - Verify: widget test with 2000 synthetic notes (scroll + find row); leak test for GlobalKey count.
  - Files: `lib/ui/note_list/list_pane.dart`, `lib/ui/shell/command_palette.dart`, `lib/ui/editor/editor_pane.dart`.
  - Scope: M

- [ ] **Task 8: Focus, shortcuts & pane correctness**
  Fix `lib/ui/shell/shell.dart:60-78,266-272,309-332`, `lib/ui/shell/shortcuts.dart:84-125`, `lib/ui/shell/pane_widths.dart:9-55`.
  - Single `autofocus:true` owner (Shell), remove competing autofocus from `ListPane`/`Editor`; `CommandPalette` restores `_shellFocus` on pop via `FocusScope.of(context).requestFocus(_shellFocus)`.
  - Stack dim: wrap in `FocusScope` + `BackButtonListener` (Esc closes), `onTap` unfocuses.
  - `PaneWidths`: instance default, not static singleton; `restoreVisibility` without `notifyListeners` during init.
  - `DeleteIntent` guard: direct `Focus.of(context).context` check via `EditableTextState` instead of `visitAncestorElements`.
  - Acceptance: `Esc` closes stack drawer; `Delete` in `FindBar` deletes char, not note; `Ctrl+K` close returns focus to editor where it was.
  - Verify: shell widget tests for focus routing, deletion guard.
  - Files: `lib/ui/shell/shell.dart`, `lib/ui/shell/shortcuts.dart`, `lib/ui/shell/pane_widths.dart`.
  - Scope: S

### Phase 3 — Multi-directory support

- [ ] **Task 9: Multi-directory vault layer**
  - `AppSettings`: `{vaultPaths: List<String>, vaultPath: String?}` with `fromJson` migration (old `vaultPath` → `[vaultPath]`); `vaultPaths` persisted ordered, primary = 0.
  - `VaultController`: `List<VaultRepository> vaults`, `int activeVaultIndex`, fan-out `notes = merge(sortByUpdated)`, `folders` per-vault with vault prefix, `visibleNotes` filtered per selected scope `(vaultIndex, folder)`, watcher per vault, `createNote` takes `vaultIndex` (default active), `delete/restore` route to owning repo via path prefix, `pinnedPaths` namespaced per vault meta.
  - Acceptance: add second vault via Settings → notes from both appear merged newest-first; pin in vault A does not affect vault B; delete+restore routes correctly; old single-path settings loads as one vault.
  - Verify: `flutter test test/data/settings_repository_test.dart` migration, `test/logic/vault_controller_multidir_test.dart` fan-out, widget test sidebar shows two roots.
  - Files: `lib/models/settings.dart`, `lib/data/settings_repository.dart`, `lib/logic/vault_controller.dart`, `lib/data/vault_repository.dart` (no change except meta per root), `lib/ui/dialogs/settings_dialog.dart`, `lib/ui/sidebar/sidebar.dart`.
  - Scope: L

- [ ] **Task 10: Multi-directory UI (sidebar + palette + drag-drop)**
  Depends on Task 9.
  - Sidebar: sectioned folder trees per vault with vault header + "Add vault" row; context menus respect owning vault.
  - Command palette & search: notes already merged, show vault hint subtitle.
  - Drag-drop / image import: target vault = note's owning vault (or activeVaultIndex for new note).
  - Settings dialog: list of vault paths with add/remove/reorder + primary badge.
  - Acceptance: drag image into note belonging to vault B copies into vault B `attachments/`; palette row subtitle shows vault name.
  - Verify: widget tests for sidebar sections, drop routing.
  - Files: `lib/ui/sidebar/sidebar.dart`, `lib/ui/shell/command_palette.dart`, `lib/ui/editor/editor_pane.dart`, `lib/ui/dialogs/settings_dialog.dart`.
  - Scope: M

### Phase 4 — Editor chrome: lists, links, images

- [ ] **Task 11: List formatting (action bar + context menu)**
  New `ListKind {bullet, bulletStar, numbered, task}` + `lib/logic/list_formatting.dart` (pure) with `toggleList(text, selStart, selEnd, kind)` — line-wise prefix/suffix toggling via `TextSelection` lines: already same kind → unwrap, else set/convert; blank selection at caret → insert marker via `continueList` path.
  - `EditorActionBar` (top of `EditorPane`, spec story 18 analog): buttons `•`, `1.`, `☐` with active state (uses `selection` line inspection). Shortcuts: same intents.
  - Context menu: `quireMenu` adds `Format → List` submenu with same kinds, shortcuts shown monospaced.
  - Unwrap preserves indentation; ordered renumbers on toggle (sequential from first selected line).
  - Acceptance: select 3 lines → `•` prefixes each with `"- "`; again removes; numbered lines increment `1. 2. 3.`; action bar highlights when caret inside list.
  - Verify: `flutter test test/logic/list_formatting_test.dart` (wrap/unwrap/convert, indent, numbered seq), widget test bar+menu drive selection.
  - Files: `lib/logic/list_formatting.dart` (new), `lib/ui/editor/editor_pane.dart`, `lib/ui/editor/action_bar.dart` (new), `lib/ui/common/context_menus.dart`, tests.
  - Scope: M

- [ ] **Task 12: Link & image formatting (action bar + menu + shortcuts)**
  New `LinkKind.link` / `LinkKind.image` via `lib/logic/link_formatting.dart` (pure): `toggleLink(text, selStart, selEnd, kind, {url})` — collapsed word-aware selection → `[word](url)` or `![word](url)` (image alt), non-collapsed selection → wrap selection as `[sel](url)` (prompt for URL via inline bar if `url` absent); already wrapped → unwrap to inner text. URL prompt uses existing `CommandPalette` pattern: small overlay `LinkBar`.
  - Action bar buttons `Link` / `Image`; shortcuts `Ctrl+K` (link) conflicts with palette → palette moves to `Ctrl+Shift+K` or link uses `Ctrl+K` scoped to editor focus (editor-scoped binding wins when `_bodyFocus` hasFocus, shell palette otherwise) — document choice in code comment.
  - MarkdownPreview already renders images with width `|400`; link formatting ensures vault-relative paths via `p.relative`.
  - Acceptance: collapsed on `word` + `Ctrl+K` + type `https://x` → `[word](https://x)`; select `word` + Image → `![word](attachments/…)` via `VaultRepository.importAttachment` then insert; second toggle unwraps.
  - Verify: `flutter test test/logic/link_formatting_test.dart`, widget test link bar end-to-end.
  - Files: `lib/logic/link_formatting.dart` (new), `lib/ui/editor/editor_pane.dart`, `lib/ui/editor/action_bar.dart`, `lib/ui/editor/link_bar.dart` (new), `lib/data/vault_repository.dart` (reuse `importAttachment`), tests.
  - Scope: M

### Phase 5 — Cleanup & hardening

- [ ] **Task 13: Dependency & theme hygiene**
  Remove `dynamic_color`, `material_ui` imports if truly unused (`grep` confirms zero refs) or document retention reason; pin `sdk: ^3.22.0` stable, drop beta constraint; audit `google_fonts` runtime fetch vs bundled asset caching; memoize `ThemeData` per world in `worlds.dart`.
  - Acceptance: `flutter analyze` clean, `flutter pub get` resolves stable SDK, bundle size reduced, theme switch no longer allocates new `ThemeData` per frame.
  - Verify: `flutter analyze`, `flutter test`, `grep -R dynamic_color lib` empty.
  - Files: `pubspec.yaml`, `lib/theme/worlds.dart`, `lib/theme/quire_theme.dart`.
  - Scope: S

- [x] **Task 14: Keyboard shortcut customization (excluding formatting)**
  - Customize shell + editor non-formatting shortcuts; formatting `Ctrl+B/I/U` remains hard-coded and excluded.
  - `AppSettings.shortcutOverrides: Map<String,String>` (`lib/models/settings.dart`, `lib/models/shortcut_settings.dart` defines `enum ShortcutAction` with `label`/`defaultActivator`/`defaultActivatorLabel`, `activatorFor`; `lib/logic/shortcut_serializer.dart` `serializeActivator`/`tryParseActivator` `Ctrl+Shift+K` format, `F10`, `Del`).
  - Persistence via `SettingsRepository` JSON `shortcutOverrides` (empty omitted, tolerant parse, corrupt → defaults).
  - `VaultController.setShortcutOverride(ShortcutAction, SingleActivator?)` + `resetAllShortcuts()` + `shortcutFor()` (`lib/logic/vault_controller.dart`); live rebuild via `notifyListeners`, `Shell`'s `Shortcuts` inside `ListenableBuilder` on `VaultController` uses `sheafShortcuts(controller.settings)` (`lib/ui/shell/shortcuts.dart:118` `sheafShortcuts([AppSettings])` settings-driven, canonical `Ctrl+=`/`Ctrl+-` etc).
  - `EditorPane` (`lib/ui/editor/editor_pane.dart:267`) `_editShortcuts` settings-driven for `openFind` `Ctrl+F`, `selectWord` `Ctrl+D`, `copySelection` `Ctrl+Shift+C`, `pasteSelection` `Ctrl+Shift+V`, `continueList` `Enter` (+ `NumpadEnter` alias), find bar `findNext` `Enter`, `findPrev` `Shift+Enter`, `closeFind` `Esc`; preview `cycleEditorMode` `Ctrl+Shift+M` also settings-driven; formatting block stays hard-coded.
  - `SettingsDialog` (`lib/ui/dialogs/settings_dialog.dart:27`) Keyboard Shortcuts section after Vault: `Divider` + `_SectionLabel` + `Column` of `_ShortcutRow` (label, monospace `serializeActivator`, Edit/Reset), `Reset all`; recorder `_ShortcutRecorderDialog` captures next `KeyDownEvent` via `Focus.onKeyEvent` + `HardwareKeyboard`, ignores pure modifiers, conflict checks against other actions, `reservedFormattingLabels` (`Ctrl+B/I/U`) and `Ctrl+C/V/X`, shows error and disables Save.
  - Acceptance: Settings lists customizable actions (no formatting), Edit → recorder shows `Ctrl+Shift+K` → Save calls `setShortcutOverride`, Reset restores default, `Ctrl+B` blocked as reserved, restart persists.
  - Verify: `flutter analyze` clean; `test/models/settings_test.dart` round-trip + missing/corrupt tolerance, `test/logic/shortcut_serializer_test.dart` round-trip `Ctrl+Shift+K`/`F10`/`Del`/invalid, `test/ui/dialogs/settings_dialog_test.dart` widget recorder/conflict, manual `flutter run -d linux` change `Create note` `Ctrl+N` → `Ctrl+Shift+N` works and persists, formatting `Ctrl+B/I/U` still wrap/unwrap.
  - Files: `lib/models/settings.dart`, `lib/models/shortcut_settings.dart` (new), `lib/logic/shortcut_serializer.dart` (new), `lib/logic/vault_controller.dart`, `lib/ui/shell/shortcuts.dart`, `lib/ui/shell/shell.dart`, `lib/ui/editor/editor_pane.dart`, `lib/ui/dialogs/settings_dialog.dart`, tests.
  - Scope: M

## Critical files & anchors

- `lib/logic/formatting.dart:47-314` — wordBoundary, toggleWrap, _enclosingSpan (italic `*` vs `**` vs `<u>`). Word-aware+combinable core.
- `lib/logic/list_continuation.dart:10-50` — `_markerPattern`, `continueList` line-end guard, selection replace.
- `lib/ui/editor/editor_pane.dart:175-400` — `_applyFormat`, `_handleEnter`, find listeners, focus intent, action bar integration.
- `lib/ui/editor/highlighting_controller.dart:16-130` — `buildTextSpan` parse memo, marker hide/show via `selection` touch.
- `lib/logic/vault_controller.dart:14-322` — fan-out to `List<VaultRepository>`, watcher debounce, refresh gen guard.
- `lib/models/settings.dart:5` — `shortcutOverrides` map, `copyWith`/`toJson`/`fromJson`/`==` tolerant.
- `lib/models/shortcut_settings.dart` — `ShortcutAction` (21 values, formatting excluded), `activatorFor`, `reservedFormattingLabels`.
- `lib/logic/shortcut_serializer.dart` — `serializeActivator`/`tryParseActivator` (`Ctrl+Shift+K`, `F10`, `Del`).
- `lib/ui/shell/shortcuts.dart:118` — `sheafShortcuts([AppSettings])` settings-driven.
- `lib/ui/dialogs/settings_dialog.dart:27` — Keyboard Shortcuts section, `_ShortcutRow`, `_ShortcutRecorderDialog` conflict handling.
## Verification

- `flutter analyze` clean after each phase.
- `flutter test` green; new pure-logic suites: `formatting_test.dart` (unicode, combinable, gap), `list_formatting_test.dart`, `link_formatting_test.dart`, `list_continuation_test.dart` expanded; `vault_controller_multidir_test.dart`; plus `shortcut_serializer_test.dart`, `settings` shortcut round-trip, `settings_dialog` recorder/conflict widget.
- Manual smoke: `flutter run -d linux` — (a) `café naïve` italic toggle not split, (b) `Ctrl+B` → `Ctrl+I` → `***word***` → unwrap cycle, (c) middle-of-doc list `Enter` continues vs blank-line exit, (d) open Find, edit before match, highlight tracks, (e) add second vault in Settings, notes merge, image drop lands in correct `attachments/`, (f) action bar `•`/`1.`/`Link`/`Image` and right-click menu mirror them, (g) 2000-note vault scroll no jank, (h) traversal image `![](../../../etc/passwd)` shows placeholder, (i) Settings → Keyboard Shortcuts → change `Create note` `Ctrl+N` → `Ctrl+Shift+N` → `Ctrl+Shift+N` creates note, old `Ctrl+N` no longer does, `F3` for find, `Ctrl+B` blocked as reserved, restart persists.
- Perf: `flutter test --coverage` data+logic ≥80%; frame time on i3-7020U typing 60 fps (DevTools performance overlay).
## Assumptions & contingencies

- `Ctrl+K` clash (palette vs link): editor-scoped `Ctrl+K` wins when editor has focus; palette uses same binding at shell scope but editor route consumes first. If QA finds confusion, fallback is to move palette to `Ctrl+Shift+K` — implementer picks editor-wins default and records in code comment.
- `characters` package not yet depended on: if Unicode word regex `[\p{L}\p{N}_]` proves insufficient for grapheme clusters (Zwj emoji), add `characters: ^1.3` and iterate via `String.characters`.
- Multi-directory merge sort: ties broken by vault index then path to keep stable order; no cross-vault folder rename across roots.
- If `watcher` per-vault proves expensive (>3 vaults), cap watchers to active vault + lazy scan others on `refresh` only.

