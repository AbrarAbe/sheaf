# Taker

A local-first Markdown notes desk for the Linux desktop. Your vault is just a
folder of plain `.md` files — no database, no lock-in. Built with Flutter +
GTK, shipped as a self-contained tarball.

## Features

- **Plain-file vaults** — pick any folder; notes are standard Markdown you can
  open anywhere. Folder create/rename/delete included; dot-directories are
  left alone.
- **Three-pane shell** — sidebar · note list · editor, adapting across wide
  (≥1120 px), compact (720–1119 px), and stacked (<720 px) layouts, with a
  collapsible rail and draggable dividers with sane clamps.
- **Fast retrieval** — day-grouped, recent-first note list and instant
  filtering across title + body with title-priority ranking.
- **Focused editor** — monospace source editing with debounced autosave
  (~1 s), rename-by-title, inline tag chips, and a `saved HH:MM` footer.
- **Live preview** — GFM subset (headings, emphasis, lists, task lists,
  quotes, fenced code, links, tables) rendered with the Quire light/dark
  themes; System mode follows your desktop.
- **Images** — pick or drop images into `<vault>/attachments/` and reference
  them relatively, with Obsidian-compatible width syntax:
  `![alt|400](attachments/img.png)`.
- **Trash** — deletions land in `.trash/`; restore returns notes to their
  original folder, or delete forever.
- **Auto-refresh** — external changes to the vault appear live via a file
  watcher.

## Keyboard shortcuts

| Action | Keys |
|---|---|
| New note | `Ctrl+N` |
| Move selection | `↑` / `↓` |
| Open selected | `Enter` |
| Delete selected | `Del` (undo toast) |
| Find/filter | `Ctrl+F`, dismiss with `Esc` |
| Toggle sidebar rail | `Ctrl+\` |
| Cycle theme | `Ctrl+Shift+L` |

## Install (Linux x64)

Download the latest tarball from
[Releases](https://github.com/AbrarAbe/taker/releases), extract, and run:

```
tar xzf taker-v0.1.0-linux-x64.tar.gz
./taker
```

GTK 3 is the only runtime expectation, and it ships with virtually every
desktop distribution.

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

- [`docs/spec.md`](docs/spec.md) — what Taker is (living spec)
- [`docs/design/`](docs/design) — design docs (theming, layout, voice)
- [`docs/adr/`](docs/adr) — architecture decision records
- [`docs/plan_v0.1.md`](docs/plan_v0.1.md) — v0.1 implementation plan
