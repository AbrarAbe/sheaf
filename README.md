# Sheaf

A local-first Markdown notes desk for the Linux desktop. Your vaults are just
folders of plain `.md` files — no database, no lock-in. Add multiple vault
directories in Settings; notes merge newest-first. Built with Flutter + GTK,
shipped as a self-contained tarball.

## Features

- **Multi-vaults** — add multiple vault folders in Settings; notes merge newest-first, scoped by `vaultIndex`/`folderPath`. Each vault keeps its own `.trash/` and `.sheaf/meta.json` pins.
- **Plain-file vaults** — notes are standard Markdown you can open anywhere. Folder create/rename/delete included; dot-directories are left alone.
- **Three-pane shell** — sidebar · note list · editor, adapting across wide
  (≥1120 px), compact (720–1119 px), and stacked (<720 px) layouts. The
  sidebar is user-owned in every tier (toggle button or `Ctrl+\`), persists
  per tier, and becomes an overlay drawer when stacked. Draggable dividers
  with sane clamps.
- **Fast retrieval** — pinned notes float in a PINNED section; the rest is
  day-grouped, recent-first, with instant filtering across title + body and
  title-priority ranking.
- **Three editor modes** — Normal renders formatting live with markers hidden
  until touched; Markdown shows raw monospace source; Preview renders the GFM
  subset read-only. Autosave (~1 s) behaves identically everywhere.
- **Keyboard-complete editing** — `Ctrl+B/I/U` toggle bold/italic/underline (combinable, nesting `***`/`**<u>`; word-aware Unicode `café naïve` at bare caret), Enter continues lists (`- `, `* `, `1. `, `- [ ] `), `Ctrl+F` finds inside the note (recomputes on edit), `Ctrl+D` selects word, `Ctrl+Shift+C/V` copy/paste, `Ctrl+Tab` cycles notes.
- **Nested folders** — folder tree renders recursively with chevron expand/collapse; indent per depth; collapsed state hides subtree without selecting.
- **Sticky DIRECTORIES header** — FOLDERS header (DIRECTORIES on Linux) stays pinned above the scrollable folder list.
- **In-editor tags** — `#tag` chips live inside the editor column under the title, scroll with content; tap copies `#tag ` at caret.
- **Tight selection & scrollbar** — multi-line selection hugs glyphs (`BoxWidthStyle.tight`); interactive scrollbar shows hand cursor and padded gutter (`right 18/24`) without covering text.
- **Live preview** — GFM subset (headings, emphasis, lists, task lists,
  quotes, fenced code, links, tables, `<u>` underline) rendered with your
  chosen theme world; System mode follows your desktop.
- **Theme worlds & type controls** — Quire, Graphite, and Sepia color sets ×
  System/Light/Dark; app-wide zoom (`Ctrl+=/-/0`); editor type size 12–24 px.
- **Quick-switcher** — `Ctrl+K` (or the header search pill) jumps to any note across vaults; an empty query lists notes newest-first, so the first row is always what you touched last.
- **Custom shortcuts** — remap non-formatting shortcuts in Settings (Keyboard Shortcuts); `Ctrl+B/I/U` stay reserved for formatting.
- **Focus & fullscreen** — `F10` collapses to an editor-only surface;
  `F11` true native fullscreen; optional traffic-light window controls in
  the header (hideable in settings).
- **Images** — drag & drop images into `<vault>/attachments/` and reference
  them relatively, with Obsidian-compatible width syntax:
  `![alt|400](attachments/img.png)`. The insert-image picker button is
  **deferred** (round 6) until the file-chooser flow is ready.
- **Trash** — deletions land in `.trash/`; restore returns notes to their
  original folder, or delete forever; each entry shows when it was trashed.
- **Auto-refresh** — external changes to the vault appear live via a file
  watcher.

## Keyboard shortcuts

| Action | Keys |
|---|---|
| New note | `Ctrl+N` |
| Move selection | `↑` / `↓` |
| Open selected | `Enter` |
| Delete selected | `Del` (corner toast with Undo) |
| Find/filter list | `Ctrl+F`, dismiss with `Esc` |
| Show/hide sidebar | `Ctrl+\` |
| Cycle theme mode | `Ctrl+Shift+L` |
| Next/previous note | `Ctrl+Tab` / `Ctrl+Shift+Tab` |
| Bold / italic / underline | `Ctrl+B` / `Ctrl+I` / `Ctrl+U` |
| Select word | `Ctrl+D` |
| Find in note | `Ctrl+F` inside the editor, `Esc` closes |
| Copy/paste (terminal-style) | `Ctrl+Shift+C` / `Ctrl+Shift+V` |
| Cycle editor mode | `Ctrl+Shift+M` |
| Zoom | `Ctrl+=` / `Ctrl+-`, reset `Ctrl+0` |
| Focus mode | `F10` |
| Fullscreen | `F11` |

## Install (Linux x64)

Download and install to `~/.local/share/sheaf` (keep the `sheaf/` folder intact — `lib/` and `data/` must stay beside the binary):

```
curl -LO https://github.com/AbrarAbe/sheaf/releases/latest/download/sheaf-v0.3.1-linux-x64.tar.gz
mkdir -p ~/.local/share
tar xzf sheaf-v0.3.1-linux-x64.tar.gz -C ~/.local/share
~/.local/share/sheaf/sheaf
```

Optional — add to `PATH`:

```
mkdir -p ~/.local/bin
ln -sf ~/.local/share/sheaf/sheaf ~/.local/bin/sheaf
```

AppImage alternative (portable, no install):

```
curl -LO https://github.com/AbrarAbe/sheaf/releases/latest/download/Sheaf-x86_64.AppImage
chmod +x Sheaf-x86_64.AppImage
./Sheaf-x86_64.AppImage
```

GTK 3 is the only runtime expectation, and it ships with virtually every
desktop distribution. Download a specific version by replacing `latest` with `download/v0.3.1` in the URL, or pick a tarball from [Releases](https://github.com/AbrarAbe/sheaf/releases).

## Build from source

Prerequisites: a Flutter SDK on the **beta** channel (see the `sdk:` constraint
in `pubspec.yaml`), plus the standard Linux desktop build tools:

```
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```

```
flutter pub get
flutter run -d linux            # development
flutter build linux --release   # produces build/linux/x64/release/bundle
```

## Project docs

- [`docs/spec.md`](docs/spec.md) — what Sheaf is (living spec)
- [`docs/design/`](docs/design) — design docs (theming, layout, voice)
- [`docs/adr/`](docs/adr) — architecture decision records
- [`docs/plan_v0.1.md`](docs/plan_v0.1.md) — v0.1 implementation plan
- [`docs/plan_v0.2.md`](docs/plan_v0.2.md) — v0.2 implementation plan (editor, modes, pinning, appearance)
- [`docs/plan_v0.3.md`](docs/plan_v0.3.md) — v0.3 implementation plan (polish & multi-directory)
- [`docs/plan_v0.3.1.md`](docs/plan_v0.3.1.md) — v0.3.1 implementation plan (paper cuts)
