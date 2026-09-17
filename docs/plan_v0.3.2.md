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

- [x] **Task 1: Confirmation dialog before note delete (note list → trash)**
  **Description:** Wrap every note-delete entry point (list row, shell shortcut) with a centred modal dialog before moving the note to trash. After trash, show the undo toast.
  **Acceptance criteria:**
  - [x] `showConfirmDeleteDialog` widget in `lib/ui/dialogs/confirm_delete.dart` renders: Cancel `FilledButton` (accent), Delete `TextButton` (error color). Returns `true`/`false`.
  - [x] `ListPane._deleteWithUndo` shows dialog → on confirm → `showLoadingOverlay(context, controller.deleteNote)` → trash → undo toast (`entries.last` for correct entry).
  - [x] `Shell._deleteSelectedWithUndo` same pattern.
  - [x] `NoteRow` delete button from context menu also shows the dialog.
  - [x] Dialog barrier-dismissible, Esc cancels.
  - [x] Yellow underlines (spell-check decoration) removed from toast text via `decoration: TextDecoration.none`.
  - [x] `showLoadingOverlay` utility shows centred spinner during async delete.
  **Verification:**
  - [x] `flutter test test/ui/dialogs/confirm_delete_test.dart`
  - [x] `flutter test test/ui/note_list/context_menu_test.dart` — right-click → Delete → dialog → confirm → note trashed.
  - [x] `flutter test test/ui/shell/shortcut_test.dart` — Del key → dialog → confirm → note trashed.
  **Dependencies:** None
  **Files touched:**
  - `lib/ui/dialogs/confirm_delete.dart` (new)
  - `lib/ui/common/widgets/loading_overlay.dart` (new)
  - `lib/ui/common/widgets/corner_toast_card.dart` (decoration fix)
  - `lib/ui/note_list/list_pane.dart`
  - `lib/ui/shell/shell.dart`
  - `lib/ui/sidebar/trash_view.dart`
  - `test/ui/dialogs/confirm_delete_test.dart` (new)
  - `test/ui/note_list/context_menu_test.dart`
  - `test/ui/shell/shortcut_test.dart`
  - `test/ui/sidebar/trash_view_test.dart`
  **Scope:** S — committed 030f20f

- [x] **Task 2: Confirmation dialog before folder delete (sidebar → trash)**
  **Description:** Wrap folder delete in the sidebar context menu with a strong confirmation dialog. When a folder is trashed, the entire directory tree (all subdirectories and all notes/files inside) is moved to `.trash/` atomically via `Directory.rename()`. The dialog must clearly warn about this.
  **Acceptance criteria:**
  - [x] `FolderRow` context menu `Delete` action shows `showConfirmDeleteDialog` with:
    - Title: "Move folder to trash?"
    - Message: "Entire folder "{name}" and ALL its contents (subdirectories, notes, files) will be moved to trash."
    - Confirm label: "Move folder to trash"
  - [x] `case 'delete':` in folder_row.dart shows dialog → on confirm → `showLoadingOverlay(context, controller.deleteFolder(relPath))`.
  - [x] No separate entry per file in the trash — the whole directory is one `TrashEntry(isFolder: true)`. Restoring it restores everything.
  - [x] Dialog barrier-dismissible, Esc cancels.
  **Verification:**
  - [x] `flutter analyze` clean, `flutter test` 315/315 green.
  **Dependencies:** Task 1 (same dialog widget)
  **Files touched:**
  - `lib/ui/sidebar/widgets/folder_row.dart`
  **Estimated scope:** XS — committed 8cfa005

- [x] **Task 3: Confirmation dialog before permanent delete in Trash view + restore toast**
  **Description:** The "Delete forever" icon button in the Trash view currently deletes immediately. Show a confirmation dialog first. The "Restore" button shows a success toast.
  **Acceptance criteria:**
  - [x] `showConfirmDeleteDialog` called with title "Delete permanently?" and body "This action cannot be undone. The file "{name}" will be permanently deleted." Use `confirmLabel: 'Delete permanently'`.
  - [x] Only proceeds to `controller.emptyTrashItem(trashedName)` on confirm.
  - [x] After `controller.restoreFromTrash(trashedName)` completes, show `CornerToast.show(context, message: 'Restored "{name}"', icon: Icons.restore)`.
  - [x] Loading overlay during the async delete operation.
  - [x] The restore toast appears even though the trash dialog is still open — it renders in the root overlay.
  **Verification:**
  - [x] `flutter test test/ui/sidebar/trash_view_test.dart` — delete forever → dialog → confirm → item removed.
  - [x] Manual: open trash, tap Restore → toast appears.
  **Dependencies:** Task 1 (dialog widget)
  **Files touched:**
  - `lib/ui/sidebar/trash_view.dart`
  - `test/ui/sidebar/trash_view_test.dart`
  **Estimated scope:** XS — committed 030f20f

### Phase 2 — Command palette polish

- [x] **Task 4: Improve scrolling and list layout in command palette**
  **Description:** Refactor the command palette layout and scrolling behaviour to restrict the maximum height of the list, eliminate layout wrap-around, and ensure smooth caret-like scrolling.
  **Acceptance criteria:**
  - [x] Implement a custom scrolling viewport matching exactly 15 visible rows before scrolling (`_pageSize = 15`, `_rowExtent = 38.0`, clamped `fifteenRowHeight`).
  - [x] Clamp arrow navigation to prevent wrap-around at list boundaries (`_index = (_index + 1).clamp(0, results.length - 1)` and symmetric for up).
  - [x] Track precise viewport positions in `_reveal` — only triggers `Scrollable.ensureVisible` when the selected item actually exits the viewport (caret-like, no jump for already-visible rows).
  - [x] `_reveal` uses `alignment: 0` for arrow-up (top-pin) and `alignment: 1` for arrow-down (bottom-pin) for symmetric caret behaviour.
  - [x] `PaletteRow` uses plain `Container` colour (no `AnimatedContainer`) for flicker-free highlight.
  - [x] `PaletteRow` uses `theme.colorScheme.secondaryContainer` (not `surfaceContainerHighest`) for highlighting selected rows.
  - [x] No regressions.
  **Verification:**
  - [x] `flutter test test/ui/shell/command_palette_test.dart` — instant highlight on type, no-wrap arrow boundaries, no `AnimatedContainer`.
  **Dependencies:** None
  **Files touched:**
  - `lib/ui/shell/command_palette.dart`
  - `lib/ui/shell/widgets/palette_row.dart`
  - `test/ui/shell/command_palette_test.dart`
  **Estimated scope:** S - (3-4 files)

### Phase 3 — Note info (EXIF) dialog

- [x] **Task 5: Add Info entry to note context menu**
  **Description:** Every `NoteRow` context menu gains an Info item.
  **Acceptance criteria:**
  - [x] `NoteRow._menu` gains `menuItem('Info', value: 'info', icon: Icons.info_outline)`.
  - [x] `NoteRow` gains `VoidCallback? onInfoTap`.
  - [x] `ListPane._rowFor` passes `onInfoTap`.
  **Verification:**
  - [x] `flutter test test/ui/note_list/note_row_test.dart`
  **Dependencies:** Task 6
  **Files likely touched:**
  - `lib/ui/note_list/widgets/note_row.dart`
  - `lib/ui/note_list/list_pane.dart`
  **Estimated scope:** XS

- [x] **Task 6: Build NoteInfoDialog**
  **Description:** Non-modal dialog showing file name, full path, created/modified dates, word and character counts.
  **Acceptance criteria:**
  - [x] New `NoteInfoDialog` in `lib/ui/dialogs/note_info.dart`.
  - [x] Layout: header "Note Info" with `Icons.info_outline`, rows of label:value pairs (Path, Created, Modified, Words, Characters), Close button.
  - [x] Reads `File.statSync()` at open time via `controller.fileOf(note.path)`.
  **Verification:**
  - [x] `flutter test test/ui/dialogs/note_info_test.dart`
  **Dependencies:** Task 5 + Task 7
  **Files likely touched:**
  - `lib/ui/dialogs/note_info.dart` (new)
  - `test/ui/dialogs/note_info_test.dart` (new)
  **Estimated scope:** S

- [x] **Task 7: Wire VaultController.fileOf**
  **Description:** Expose `VaultController.fileOf(relPath)` for stat access.
  **Acceptance criteria:**
  - [x] `VaultController.fileOf(String relPath)` delegates to `_requireVault().fileOf(relPath)`.
  **Verification:**
  - [x] `flutter test test/logic/vault_controller_test.dart`
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