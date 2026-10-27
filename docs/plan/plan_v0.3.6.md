# Implementation Plan: Sheaf v0.3.6 — "deliberate"

Derived from `docs/spec.md` v0.3.5 brief. Ordered by dependency; each task
lands as its own Conventional Commit behind `flutter analyze` + `flutter test`.
No new dependencies (`file_picker` ^12.0.0 is already in `pubspec.yaml` and
backs the OS-picker branch).

## Overview

Three deferred new-note ideas, refined into one coherent flow. The core shift:
creating a note stops being an instant "Untitled.md" side effect and becomes a
deliberate, single-modal step that every entry point goes through. Alongside it,
note rows in the unscoped list finally say which directory they live in.

- **New-note modal.** `lib/ui/dialogs/new_note_dialog.dart` asks for two
  required-but-defaulted fields — name (default `Untitled`) and location
  (default = current directory) — chosen from the folder tree rather than typed,
  so no stray folders are created by typo. `Enter` accepts the defaults, `Esc`
  cancels. `Ctrl+N`, the list-pane button, the scaffold context menu, the empty
  state, and the stack shell all funnel through the same step — the built-in
  modal, or the OS directory picker when the `NewNotePicker` setting is `system`.
- **Directory label on note rows.** In the unfiltered view only
  (`selectedFolder == null && selectedTag == null`), each row shows the
  immediate parent folder name (or `Vault root` for top-level notes), with the
  full relative directory as a tooltip. Hidden in any scoped view where it is
  redundant.
- **"New note inside" in the folder-row context menu.** Sits next to the
  existing "New folder inside"; it selects that folder and reuses the same
  funnel, so the modal's defaults are already correct.
- **Optional settings toggle.** Appearance-level switch (system picker vs.
  built-in modal), defaulting to the built-in modal. System mode uses the
  existing `file_picker` chooser.

## Architecture Decisions

- **`file_picker` is the only seam for OS-level choice.** `WelcomeScreen.defaultPickFolder`
  already wraps `FilePicker.getDirectoryPath`. Task A reuses that function and
  adds `FilePicker.saveFile` only if the system branch wants a filename; the
  default system branch in v0.3.6 stays a directory chooser
  (`getDirectoryPath`) and the note is created as `Untitled` in that directory.
  The chosen path is absolute, so it is converted to vault-relative before
  reaching `VaultRepository.createNote` — whose `_normalizeFolder` throws
  `ArgumentError` on absolute input — and a pick outside the active vault is
  discarded rather than creating a stray folder. No new dependency is introduced.
- **One funnel, unchanged public signature.** `Shell._createNote()` remains the
  single caller of creation logic; note creation calls still resolve to
  `controller.createNote(title:, folder:)`. All UI entry points
  (Ctrl+N via `sheafActions`, list-pane button, scaffold context menu,
  `EmptyState`, `StackShell`) already reach `_createNote` and must keep doing so.
- **Modal returns intent, not a note.** `showNewNoteDialog` returns
  `Future<NewNoteRequest?>` with `title` + `relFolder` (empty string = vault
  root). `NewNoteRequest` is an immutable class declared alongside the dialog in
  `lib/ui/dialogs/new_note_dialog.dart`, matching the shape of `Note` and
  `AppSettings`. The dialog does no I/O and owns no controller state. Creation
  runs after dismissal so a cancelled dialog creates nothing.
- **Location is chosen, not typed.** The modal's location control is a
  `DropdownButtonFormField<String>` over the folder tree flattened depth-first
  (empty root entry first), so users cannot invent directory names by typo.
- **Directory label means immediate parent.** A note's directory is derived from
  `note.path` (vault-relative POSIX, e.g. `dir/sub/note.md`):
  `final segs = note.path.split('/'); final dir = segs.length <= 1 ? '' : segs.sublist(0, segs.length - 1).join('/');`
  so top-level notes yield `dir == ''` and map to `Vault root`, and nested notes
  yield their folder path. The row shows the last segment of `dir` only, not the
  full relative path, to keep compact rows on one line; the full `dir` is the
  tooltip. Showing the full path on every row would dominate the snippet line
  and restate what the sidebar already scopes.
- **`onCreateNote` override stays as the test escape hatch.** `Shell`, `ListPane`,
  `EmptyState`, and `StackShell` keep their existing no-arg `Future<Note?> Function()?`
  hooks; `Sidebar` has none today and gains one in Task C so `FolderRow`
  (Task E) can reach the same funnel. When `Shell.onCreateNote` is non-null it
  short-circuits the whole flow (preserving the existing `shell_test.dart`
  expectations); otherwise the real funnel runs and consults the new
  `showNewNoteDialog` / directory-picker seams. Those two seams live on `Shell`
  only — `Sidebar` and `StackShell` never open a dialog, so they only carry
  `onCreateNote`. New widget tests inject a fake dialog by passing
  `showNewNoteDialog`, mirroring the `pickFolder` idiom already used for vault
  selection.
- **Folder-row creation selects first.** "New note inside" calls
  `controller.selectFolder(node.relPath)` and then invokes the funnel, so the
  modal's default location is already correct without a separate pre-seed code
  path.
- **Settings persistence follows the established pattern.** `AppSettings`
  stays Flutter-free; `VaultController.setNewNotePicker` early-returns when
  unchanged, then `copyWith`, `save`, `notifyListeners`.

## Task List

### Phase 1 — Settings gate

- [x] **Task A: settings field + OS-picker seam**
  **Description:** Add `NewNotePicker` (system picker vs. built-in modal,
  default `builtin`) to `AppSettings` — constructor default, `copyWith`,
  `toJson`/`fromJson`, and `==`/`hashCode`. The JSON key is camelCase
  `newNotePicker`, emitting the enum name and always written on `toJson` (unlike
  `shortcutOverrides`, which is omitted when empty); `fromJson` falls back to
  `NewNotePicker.builtin` on a missing or unknown value, mirroring the
  `ThemeSetting.fromJson` / `EditorMode.fromJson` idiom. Add
  `Future<void> setNewNotePicker(NewNotePicker picker)` following the existing
  setter shape (early-return when unchanged → `copyWith` → `_settingsRepo.save`
  → `notifyListeners`, as in `setShowWindowControls`). Expose the toggle in
  `settings_dialog.dart` in a new `Notes` section (before the Vault section)
  using a `SwitchListTile` copied from the `window-controls-switch` block:
  `dense`, `contentPadding: EdgeInsets.zero`, `theme.textTheme.bodySmall` title
  `Use system picker for new notes`, and `key: const Key('new-note-picker-switch')`
  so tests can locate and toggle it (that key is what makes the existing
  `window-controls-switch` test target work).
  Document that the system branch reuses `WelcomeScreen.defaultPickFolder`
  (`FilePicker.getDirectoryPath`) and that no dependency is added.
  **Acceptance criteria:**
  - [x] `AppSettings.newNotePicker` round-trips through `toJson`/`fromJson`.
  - [x] Missing key on read yields `NewNotePicker.builtin`.
  - [x] `copyWith(newNotePicker:)` works; `==`/`hashCode` include the field.
  - [x] `VaultController.setNewNotePicker` early-returns when unchanged,
        persists via `_settingsRepo.save`, and notifies.
  - [x] Settings dialog renders the toggle under `key('new-note-picker-switch')`
        and routes `onChanged` to `setNewNotePicker`.
  **Verification:**
  - [x] `test/models/settings_test.dart` (or the existing settings test) gains
        round-trip + legacy-default assertions.
  - [x] `test/logic/vault_controller_test.dart` gains the setter test.
  - [x] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** None
  **Files likely touched:**
  - `lib/models/settings.dart`
  - `lib/logic/vault_controller.dart`
  - `lib/ui/dialogs/settings_dialog.dart`
  - `test/models/settings_test.dart`
  - `test/logic/vault_controller_test.dart`
  **Estimated scope:** M

### Phase 2 — The modal

- [x] **Task B: new-note modal**
  **Description:** Create `lib/ui/dialogs/new_note_dialog.dart` exposing
  `Future<NewNoteRequest?> showNewNoteDialog(BuildContext context, VaultController
  controller)` — no picker callback here: the built-in modal's location control
  is a dropdown, so it never needs to choose a directory out of band. Define
  `NewNoteRequest` as an immutable class with `title` and `relFolder`.
  Render an `AlertDialog` with two fields: name (default `Untitled`) and
  location (default `controller.selectedFolder ?? ''`). Location uses a
  `DropdownButtonFormField<String>` filled by flattening `controller.folders`
  depth-first with an empty-string "Vault root" entry. Trim the name; an empty
  submission becomes `Untitled`. `Enter` submits, `Esc`/barrier dismiss cancels.
  No I/O inside the dialog.

  `AlertDialog` does not submit on `Enter` by itself, so the mechanism must be
  explicit. Give the name field a `FocusNode` with an `onFieldSubmitted` (or a
  `Shortcuts`/`Actions` binding over the dialog) that calls
  `Navigator.pop(context, request)`, where `request` is built from the *current*
  form state — including the location dropdown's value — not just the text
  field. Cancel is `showDialog`'s default barrier dismiss, which resolves
  `null`.
  **Acceptance criteria:**
  - [x] `showNewNoteDialog` returns `null` on cancel and `NewNoteRequest` on submit.
  - [x] Defaults are `Untitled` and `controller.selectedFolder ?? ''`.
  - [x] Location control is a dropdown over the folder tree plus `Vault root`;
        no free text.
  - [x] Empty name submissions are normalized to `Untitled`.
  - [x] Reloading after a prior submit re-shows the defaults (no stale state).
  **Verification:**
  - [x] `test/ui/dialogs/new_note_dialog_test.dart` covers default submit,
        empty-name normalization, cancel (Esc + barrier), and the location default
        when a folder is selected.
  - [x] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** Task A (conceptually — settings exists, though the modal does
  not read it yet)
  **Files likely touched:**
  - `lib/ui/dialogs/new_note_dialog.dart` (new)
  - `test/ui/dialogs/new_note_dialog_test.dart` (new)
  **Estimated scope:** M

### Phase 3 — Rewire the funnel

- [x] **Task C: rewire the single funnel**
  **Description:** `Shell._createNote()` now: (1) if `widget.onCreateNote != null`,
  invoke it unchanged (test escape hatch); else (2) consult
  `controller.settings.newNotePicker` — on `system`, call the directory chooser
  seam and build a `NewNoteRequest(title: 'Untitled', relFolder: picked)` only when
  a directory is picked; on `builtin`, await `showNewNoteDialog(context,
  controller)`. On `null` from either branch, abort. Otherwise call
  `controller.createNote(title: request.title, folder: request.relFolder)` and
  `controller.selectNote(note)`.

  Seam placement matters. **`Shell` is the only widget that opens a dialog**, so
  only `Shell` gains the injectable `showNewNoteDialog` and `pickFolder` parameters
  (each defaulting to its real implementation) so tests never hit a real dialog.
  `Sidebar` and `StackShell` never show a dialog and must not receive dialog or
  picker seams; they only accept and forward `onCreateNote:
  Future<Note?> Function()?`. Note that the `sidebar.dart` edit in this task is
  pure plumbing — `Sidebar` takes `onCreateNote` and passes it to `FolderRow`
  for Task E to consume; Task E is what adds behaviour to the row.

  Both of `Shell`'s `Sidebar(...)` constructions — the expanded/full tier row and
  the stack-tier overlay — must gain `onCreateNote: _createNote`, or Task E's
  menu item is dead in exactly the two tiers where the sidebar is reachable. Both
  pass `controller`, `width`, `onTrashTapped`, `onSettingsTapped` today and
  neither passes a creation callback. `StackShell` already receives
  `onCreateNote`, so only those two `Sidebar` call sites change.

  The system branch needs an explicit path conversion. `pickFolder` resolves to
  `FilePicker.getDirectoryPath`, which returns an absolute OS path, while
  `VaultRepository._normalizeFolder` → `_normalizeRel` requires a vault-relative
  folder and throws `ArgumentError` on an absolute one. Convert before creating:
  `final rel = p.relative(picked, from: controller.vaultPath);` and map
  `rel == '.'` to `''` (vault root); abort without creating anything when
  `controller.vaultPath` is empty, `p.isAbsolute(rel)`, `rel == '..'`, or
  `rel.startsWith('../')` — so an in-vault folder literally named `..hidden`
  stays legal rather than being mistaken for a parent-directory escape.
  A directory picked outside the active vault cannot become a note folder.
  **Acceptance criteria:**
  - [x] Every listed entry point reaches `_createNote` and behaves identically.
  - [x] Cancelling the modal leaves the vault untouched (no note, no refresh).
  - [x] System-picker branch creates `Untitled` in the chosen directory, and a
        directory picked outside the vault (or no vault open) creates nothing.
  - [x] `onCreateNote` override still short-circuits (existing `shell_test.dart`
        expectations remain green).
  - [x] New note is selected + opened after creation.
  **Verification:**
  - [x] `test/ui/shell_test.dart` existing new-note test still passes.
  - [x] Add a modal-path test using an injected `showNewNoteDialog` seam
        asserting the returned request is fed to `createNote`, plus a cancel
        test.
  - [x] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** Task A (reads `settings.newNotePicker`), Task B (modal)
  **Files likely touched:**
  - `lib/ui/shell/shell.dart`
  - `lib/ui/shell/widgets/stack_shell.dart`
  - `lib/ui/sidebar/sidebar.dart`
  - `test/ui/shell_test.dart`
  - `test/ui/sidebar/sidebar_test.dart`
  **Estimated scope:** M

### Phase 4 — List + folder surfaces

- [x] **Task D: directory label in the note list**
  **Description:** `NoteRow` gains a `showDirectory` bool (default `false`) and
  renders the note's immediate-parent folder name — derived from
  `note.path` (the segment before the file name, or `Vault root` when top-level) —
  on the title/snippet column when `showDirectory` is true, with the full
  relative directory as a tooltip. `ListPane._rowFor` passes
  `showDirectory: controller.selectedFolder == null && controller.selectedTag == null`.
  Any new small widget this introduces goes in `lib/ui/note_list/widgets/`
  (one widget per file, no new private widgets in a pane); the label is expected
  to be small enough to stay inline in `NoteRow` and needs no new file.
  **Acceptance criteria:**
  - [x] Label appears only in the unfiltered view; hidden under folder or tag scope.
  - [x] Top-level notes show `Vault root`; nested notes show the immediate
        parent folder name.
  - [x] Full relative directory is available as a tooltip (key
        `note-row-directory-${Uri.encodeComponent(note.path)}`, matching the row's
        existing `row-pin-…` key style).
  - [x] No layout overflow on narrow rows; label uses `TextOverflow.ellipsis`.
  **Verification:**
  - [x] `test/ui/note_list/list_pane_test.dart` gains assertions: an unfiltered
        list shows the parent label; a folder-scoped list does not.
  - [ ] (N/A — NoteRow was not extracted, the label is inline in it, so there is
        no new file to test directly; the top-level vs. nested and scoped/unscoped
        cases are covered by the ListPane assertions above.)
  - [x] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** None
  **Files likely touched:**
  - `lib/ui/note_list/widgets/note_row.dart`
  - `lib/ui/note_list/list_pane.dart`
  - `test/ui/note_list/list_pane_test.dart`
  **Estimated scope:** S

- [x] **Task E: "New note inside" in folder-row context menu**
  **Description:** Add `menuItem('New note inside', value: 'new-note-inside',
  icon: Icons.note_add_outlined)` to `FolderRow`'s `QuireContextMenuRegion`
  before the existing `New folder inside`. On selection, call
  `controller.selectFolder(node.relPath)` and then invoke
  `widget.onCreateNote?.call()`. Because the folder was just selected, the funnel's
  default location is already correct — no separate pre-seeded code path.
  `Sidebar` receives the seam from `Shell` (Task C) and forwards it to each
  `FolderRow`; the row gains the same `Future<Note?> Function()? onCreateNote`
  seam shape used elsewhere so tests can drive it without a shell.

  Two `FolderRow` signature points to not miss. The row currently takes only
  `controller`, `node`, `depth`, `expandVersion`, `expandValue`, so it gains one
  new optional `onCreateNote` parameter. And `FolderRow` builds its own children
  recursively (`_FolderRowState.build` renders `FolderRow` for each
  `node.children`), so the recursive call must forward `onCreateNote` too —
  otherwise only top-level folders get the new menu item.

  One more constraint: `menuItem(...)` in `lib/ui/common/context_menus.dart` has no
  `enabled` argument — it forwards only `label`, `value`, `icon`, `destructive`,
  and `shortcut` to `QuireMenuItem`. A disabled item therefore needs either a new
  `bool enabled = true` parameter on `menuItem` or a direct
  `QuireMenuItem(..., enabled: widget.onCreateNote != null)` construction at this
  call site.
  **Acceptance criteria:**
  - [x] Menu contains both `New note inside` and `New folder inside`.
  - [x] Selecting it selects the folder and triggers note creation.
  - [x] When `onCreateNote` is null the item is still rendered but disabled/no-op
        (no crash).
  - [x] Existing rename/delete behaviour is unchanged.
  **Verification:**
  - [x] `test/ui/sidebar/sidebar_test.dart` gains a test that the context menu
        includes "New note inside", and that selecting it calls the injected
        creation callback with the folder selected.
  - [x] `flutter analyze` clean; `flutter test` green.
  **Dependencies:** Task C (funnel wired); Task B conceptually
  **Files likely touched:**
  - `lib/ui/sidebar/widgets/folder_row.dart`
  - `lib/ui/sidebar/sidebar.dart`
  - `lib/ui/common/context_menus.dart` (only if `menuItem` gains an `enabled` param)
  - `test/ui/sidebar/sidebar_test.dart`
  **Estimated scope:** S

### Checkpoint: v0.3.6 complete

- [x] All acceptance criteria from tasks A–E met
- [x] `flutter analyze` clean
- [x] `flutter test` green
- [ ] (N/A — no Flutter app was connected via `dtd` this session, so no reload could
      be pushed; code was validated by `flutter test` + `flutter analyze` instead.)
      Hot reload pushed to running app after each Dart edit
- [x] One Conventional Commit per completed task

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Dialog I/O leaks into the widget | Medium | `showNewNoteDialog` returns intent only; creation runs in `Shell._createNote` and is unit-tested with a fake seam. |
| Test suite depends on `onCreateNote` no-arg shape | Medium | Keep the override as a short-circuit; only the default path changes, so existing `shell_test.dart` and list tests need no edits. `sidebar_test.dart` changes only when Task E exercises the forwarded callback. |
| `FolderRow` is recursive; nested folders lose the new menu item | Medium | Forward `onCreateNote` in the recursive `FolderRow` construction inside `_FolderRowState.build`; cover a nested folder in the sidebar test. |
| System picker returns an absolute OS path, but `createNote` wants vault-relative | High | Convert with `p.relative(picked, from: controller.vaultPath)` before creating; abort on out-of-vault picks. `VaultRepository._normalizeFolder` throws `ArgumentError` otherwise. |
| New-note funnel unreachable from the sidebar | Medium | `Shell` passes `onCreateNote: _createNote` into both `Sidebar(...)` constructions (expanded/full tier and stack overlay), which neither does today. |
| `Sidebar`/`StackShell` callback plumbing churn | Low | Add optional `onCreateNote` with a `null` default; `Sidebar` and `StackShell` never receive dialog or picker seams. Wiring is additive and non-breaking. |
| OS-picker branch semantics under-specified | Low | Resolve to a directory chooser (`FilePicker.getDirectoryPath`); title defaults to `Untitled`. Documented in Task A. |
| Folder-tree dropdown becomes long in large vaults | Low | Flatten + scroll; if a tree renderer is later needed, replace the dropdown without changing `NewNoteRequest`. |
| Directory label misread as a scope | Low | Label only renders in the unfiltered view; scoped views omit it entirely. |

## Confirmed Decisions

- **Modal before creation.** Every entry point runs the same modal; `Enter`
  accepts `Untitled` + current directory and still counts as "creating with
  intent" because the step is visible and cancellable. No skip bypass.
- **System picker is opt-in, off by default.** `NewNotePicker.builtin` is the
  default; the toggle lives in a new `Notes` section in Settings.
- **Directory label only when unscoped.** `selectedFolder == null &&
  selectedTag == null`; immediate parent name (or `Vault root`) with full path
  as tooltip.
- **"New note inside" selects then creates.** Single code path reuses the
  funnel; no separate pre-seeded-modal fork.
- **Out-of-vault picker picks create nothing.** A directory chosen outside the
  active vault (or with no vault open) is discarded silently; the OS returns an
  absolute path and `createNote` wants a vault-relative one.
- **No new dependency.** `file_picker` ^12.0.0 is already present.

## Open Questions

- Whether the system-picker branch should grow into a full `FilePicker.saveFile`
  (filename + directory) in a later version. v0.3.6 ships the directory chooser
  only, matching the seam already in use for vault selection.
- Whether the directory label should be promoted to a full relative path for
  deeply nested vaults. v0.3.6 ships the immediate-parent name plus tooltip.