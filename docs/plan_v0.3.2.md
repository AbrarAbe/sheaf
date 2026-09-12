# Implementation Plan: Sheaf v0.3.2 — "no surprises"

Derived from `docs/spec.md` v0.3.1 and brief for next iteration. Ordered by dependency; each task lands as its own Conventional Commit behind `flutter analyze` + `flutter test`. No new dependencies.

## Overview

Four UX fixes addressing confirmation gaps, palette visual glitches, missing note metadata visibility, and editor scroll behaviour on last-line Enter.

- **Delete confirmation — modal before destructive action.** Deleting a note or folder currently happens immediately with only an undo toast. Both flows now show a centred confirmation dialog with a Cancel button and a destructive-styled Confirm button. Folder delete copy warns that all contained notes will be trashed. The "Delete forever" button in the Trash view also gets a confirmation dialog ("Permanently delete?").
- **Trash restore toast.** Restoring an item from the Trash view shows a success toast ("Restored \"{name}\""), giving user feedback that the action completed.
- **Command palette highlight on type — instant, not stale.** The palette currently resets `_index = 0` on query change but the first result's background won't paint until an arrow key or hover touches it. Typing must instantly highlight the first result and scroll it into view. Arrow-key navigation at the boundaries must not flicker.
- **Note info dialog — inspect metadata from context menu.** Every note row's context menu gains an Info entry with a tooltip showing the file path. Clicking opens a non-modal dialog showing file name, full path, created/last-modified dates, word count, and character count.
- **Editor scroll on last-line Enter — no invisible new lines.** Pressing `Enter` on the last visible line of the editor inserts a blank line but does not scroll the viewport until a character is typed, leaving the user blind to how many blank lines were registered. A post-frame scroll to `maxScrollExtent` after Enter-at-end-of-text keeps the new line visible.

## Task List

### Phase 1 — Delete & trash confirmation dialogs

- [ ] **Task 1: Confirmation dialog before note delete (note list → trash)**
  **Description:** Wrap every note-delete entry point (list row, shell shortcut) with a centred modal dialog before moving the note to trash. After trash, show the undo toast.
  **Acceptance criteria:**
  - [ ] `showConfirmDeleteDialog` widget in `lib/ui/dialogs/confirm_delete.dart` renders: Cancel `FilledButton` (accent), Delete `TextButton` (error color). Returns `true`/`false`.
  - [ ] `ListPane._deleteWithUndo` shows dialog → on confirm → `showLoadingOverlay(context, controller.deleteNote)` → trash → undo toast (`entries.last` for correct entry).
  - [ ] `Shell._deleteSelectedWithUndo` same pattern.
  - [ ] `NoteRow` delete button from context menu also shows the dialog.
  - [ ] Dialog barrier-dismissible, Esc cancels.
  - [ ] Yellow underlines (spell-check decoration) removed from toast text via `decoration: TextDecoration.none`.
  - [ ] `showLoadingOverlay` utility shows centred spinner during async delete.
  **Verification:**
  - [ ] `flutter test test/ui/dialogs/confirm_delete_test.dart`
  - [ ] `flutter test test/ui/note_list/context_menu_test.dart` — right-click → Delete → dialog → confirm → note trashed.
  - [ ] `flutter test test/ui/shell/shortcut_test.dart` — Del key → dialog → confirm → note trashed.
  **Dependencies:** None
  **Files likely touched:**
  - `lib/ui/dialogs/confirm_delete.dart`
  - `lib/ui/common/widgets/loading_overlay.dart` (new)
  - `lib/ui/common/widgets/corner_toast_card.dart` (decoration fix)
  - `lib/ui/note_list/list_pane.dart`
  - `lib/ui/note_list/widgets/note_row.dart`
  - `lib/ui/shell/shell.dart`
  - `test/ui/dialogs/confirm_delete_test.dart` (new)
  - `test/ui/note_list/context_menu_test.dart`
  - `test/ui/shell/shortcut_test.dart`
  **Estimated scope:** S

- [ ] **Task 2: Confirmation dialog before folder delete (sidebar → trash)**
  **Description:** Wrap folder delete in the sidebar context menu with the same confirmation pattern.
  **Acceptance criteria:**
  - [ ] `FolderRow` context menu `Delete` action shows `showConfirmDeleteDialog` with title "Delete folder?" and body "Are you sure you want to delete \"{name}\"? All notes inside will be moved to trash."
  - [ ] `case 'delete':` in folder_row.dart shows dialog → on confirm → `showLoadingOverlay(context, controller.deleteFolder(relPath))`.
  - [ ] Dialog barrier-dismissible, Esc cancels.
  **Verification:**
  - [ ] `flutter test test/ui/sidebar/sidebar_test.dart`
  **Dependencies:** Task 1 (same dialog widget)
  **Files likely touched:**
  - `lib/ui/sidebar/widgets/folder_row.dart`
  - `test/ui/sidebar/sidebar_test.dart`
  **Estimated scope:** XS

- [ ] **Task 3: Confirmation dialog before permanent delete in Trash view + restore toast**
  **Description:** The "Delete forever" icon button in the Trash view currently deletes immediately. Show a confirmation dialog first. The "Restore" button shows a success toast.
  **Acceptance criteria:**
  - [ ] `showConfirmDeleteDialog` called with title "Delete permanently?" and body "This action cannot be undone. The file "{name}" will be permanently deleted." Use `confirmLabel: 'Delete permanently'`.
  - [ ] Only proceeds to `controller.emptyTrashItem(trashedName)` on confirm.
  - [ ] After `controller.restoreFromTrash(trashedName)` completes, show `CornerToast.show(context, message: 'Restored "{name}"', icon: Icons.restore)`.
  - [ ] Loading overlay during the async delete operation.
  - [ ] The restore toast appears even though the trash dialog is still open — it renders in the root overlay.
  **Verification:**
  - [ ] `flutter test test/ui/sidebar/trash_view_test.dart` — delete forever → dialog → confirm → item removed.
  - [ ] Manual: open trash, tap Restore → toast appears.
  **Dependencies:** Task 1 (dialog widget)
  **Files likely touched:**
  - `lib/ui/sidebar/trash_view.dart`
  - `test/ui/sidebar/trash_view_test.dart`
  **Estimated scope:** XS

### Phase 2 — Command palette polish

- [ ] **Task 4: Auto-highlight first result on type, fix arrow-key background staleness**
  **Description:** When typing in the palette query field, the first result immediately shows the selected background (no arrow-key required) and the list scrolls to it.
  **Acceptance criteria:**
  - [ ] `_CommandPaletteState.onChanged` already calls `setState(() => _index = 0)`. Add a `_reveal` call for `results[0]` so the first result is scrolled into view.
  - [ ] Verify animation-free highlight in `PaletteRow` (plain `Container` color, no `AnimatedContainer`).
  - [ ] No regressions.
  **Verification:**
  - [ ] `flutter test test/ui/shell/command_palette_test.dart`
  **Dependencies:** None
  **Files likely touched:**
  - `lib/ui/shell/command_palette.dart`
  - `test/ui/shell/command_palette_test.dart`
  **Estimated scope:** XS

### Phase 3 — Note info (EXIF) dialog

- [ ] **Task 5: Add Info entry to note context menu**
  **Description:** Every `NoteRow` context menu gains an Info item.
  **Acceptance criteria:**
  - [ ] `NoteRow._menu` gains `menuItem('Info', value: 'info', icon: Icons.info_outline)`.
  - [ ] `NoteRow` gains `VoidCallback? onInfoTap`.
  - [ ] `ListPane._rowFor` passes `onInfoTap`.
  **Verification:**
  - [ ] `flutter test test/ui/note_list/note_row_test.dart`
  **Dependencies:** Task 6
  **Files likely touched:**
  - `lib/ui/note_list/widgets/note_row.dart`
  - `lib/ui/note_list/list_pane.dart`
  **Estimated scope:** XS

- [ ] **Task 6: Build NoteInfoDialog**
  **Description:** Non-modal dialog showing file name, full path, created/modified dates, word and character counts.
  **Acceptance criteria:**
  - [ ] New `NoteInfoDialog` in `lib/ui/dialogs/note_info.dart`.
  - [ ] Layout: header "Note Info" with `Icons.info_outline`, rows of label:value pairs (Path, Created, Modified, Words, Characters), Close button.
  - [ ] Reads `File.statSync()` at open time via `controller.fileOf(note.path)`.
  **Verification:**
  - [ ] `flutter test test/ui/dialogs/note_info_test.dart`
  **Dependencies:** Task 5 + Task 7
  **Files likely touched:**
  - `lib/ui/dialogs/note_info.dart` (new)
  - `test/ui/dialogs/note_info_test.dart` (new)
  **Estimated scope:** S

- [ ] **Task 7: Wire VaultController.fileOf**
  **Description:** Expose `VaultController.fileOf(relPath)` for stat access.
  **Acceptance criteria:**
  - [ ] `VaultController.fileOf(String relPath)` delegates to `_requireVault().fileOf(relPath)`.
  **Verification:**
  - [ ] `flutter test test/logic/vault_controller_test.dart`
  **Dependencies:** Task 6
  **Files likely touched:**
  - `lib/logic/vault_controller.dart`
  - `test/logic/vault_controller_test.dart`
  **Estimated scope:** XS

### Phase 4 — Editor auto-scroll on last-line Enter

- [ ] **Task 8: Auto-scroll editor viewport when Enter creates a new blank line at end of document**
  **Description:** After pressing Enter at the very end of the editor text, schedule a post-frame scroll to `maxScrollExtent`.
  **Acceptance criteria:**
  - [ ] In `_handleEnter()`, after setting `_body.value`, schedule `addPostFrameCallback` that checks if caret is at `_body.text.length` and scrolls to `maxScrollExtent` with zero duration.
  - [ ] Does not fire for mid-document Enter or list continuation.
  **Verification:**
  - [ ] `flutter test test/ui/editor/editor_pane_test.dart`
  **Files likely touched:**
  - `lib/ui/editor/editor_pane.dart`
  - `test/ui/editor/editor_pane_test.dart`
  **Estimated scope:** XS

### Checkpoint: v0.3.2 complete
- [ ] All acceptance criteria from tasks 1–8 met
- [ ] `flutter analyze` clean
- [ ] `flutter test` green (new tests for confirm dialog, palette highlight, note info dialog, editor auto-scroll)
- [ ] Hot reload pushed to running app after each Dart edit
- [ ] One Conventional Commit per completed task

## Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Confirm dialog adds friction to rapid delete workflows | Low | One-tap via toast undo already exists as an alternative escape hatch. |
| Trash dialog restore toast appears behind trash dialog | Low | `CornerToast` renders in root overlay, always above dialog barriers. |
| fileOf across multi-vault points to wrong vault | Low | `_requireVault()` returns the active vault. |
| Editor auto-scroll competes with user-initiated scroll-up after Enter | Low | Post-frame callback fires once. If issue arises, gate on `offset >= maxScrollExtent - 20`. |
| Palette first-result highlight uses `_reveal` which may cause jumpy UX | Low | `_reveal` uses `Scrollable.ensureVisible` smoothly. `addPostFrameCallback` coalesces to last frame of rapid typing batch. |