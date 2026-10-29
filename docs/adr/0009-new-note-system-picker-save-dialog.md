# ADR 0009 — System new-note picker uses the OS Save dialog (v0.3.6)

Status: **Accepted** — implemented in v0.3.6 "deliberate", replacing the
directory-chooser system branch.

## Context

The `NewNotePicker.system` branch originally opened a folder chooser
(`FilePicker.getDirectoryPath`) and created `Untitled` in the chosen directory.
Two problems: the dialog title said "Choose a vault folder" (a vault-selection
title, wrong for note creation), and there was no way to type the note title —
every new note was `Untitled`, then renamed by hand. The desired UX is the
xdg-desktop-portal **Save** dialog, where the user types the note title directly
in the dialog's name field, exactly like a browser's "save this download" flow.

## Decision

Use `FilePicker.saveFile` for the system new-note branch:

- **Dialog title** — `"Create new note"` (vault selection keeps
  "Choose a vault folder").
- **Initial directory** — the sidebar-scoped folder
  (`controller.selectedFolder`, vault-relative) joined onto the vault root, or
  the vault root when the all-notes view is active; `null` when no vault is open.
- **Default name** — `Untitled.md` in the dialog's name field.
- **Note creation** — the dialog's chosen absolute path is converted to
  vault-relative, the title is `basenameWithoutExtension`, the folder is
  `dirname`, and creation still runs through `VaultRepository.createNote` so the
  name is slugified and made unique against collisions. A pick outside the
  active vault is discarded (no stray folder).

### The saveFile-writes-then-delete pattern

`FilePicker.saveFile` does not just return a path — on Linux it writes the
supplied `bytes` to the chosen path after the portal returns. So it cannot be
used as a pure "pick name + location" UI without creating a file. The real
implementation therefore calls `saveFile` with empty bytes, captures the chosen
absolute path, and deletes the empty stub file, leaving the note to be created
(and slugified) by the normal funnel. The seam contract is "return the chosen
path for a new note, leaving no file behind"; tests inject a fake seam and never
touch the filesystem.

## Consequences

- **Known limitation — overwrite.** If the user types an existing note's exact
  name and confirms the portal's "Replace?" prompt, `saveFile` truncates that
  file to zero bytes before the stub is deleted. The original content is lost;
  `createNote` then recreates the name (as a fresh note or a unique sibling).
  This is inherent to the Save dialog and only reachable by deliberately
  retyping an existing name and confirming Replace — acceptable for a
  create-note flow, but recorded here rather than silently assumed away.
- **No new dependency.** `file_picker` ^12.0.0 already backs vault selection.
- **Title lives with the action, not the seam.** The vault-choosing title stays
  on `defaultPickFolder`; the new-note title is passed per-call from
  `Shell._createNote`, so the two flows never share a heading.

## Trade-offs considered

- **`getDirectoryPath` + in-app name field** — rejected: the user explicitly
  wants the name field inside the system picker, matching the save-download
  mental model.
- **`saveFile` writing the note directly** — rejected: the portal would write an
  un-slugified file name (e.g. `My Note.md`, not the canonical `my-note.md`) and
  would truncate on replace, breaking the canonical path scheme.
