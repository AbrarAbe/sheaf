# Layout, Space & Surfaces

Sheaf is **desktop-first**: designed at a desk on Linux, then folded down into a
pocket shape. Every feature lands on the desktop first; the phone is the same
structure compressed, never a separate app.

## Window tiers

| Tier | Window width | Sidebar | Panes |
|---|---|---|---|
| **Expanded** | ≥ 1120 dp | Full sidebar, 240 dp | List + editor side by side |
| **Full** | 720–1119 dp | Collapsed to 64 dp icon rail | List + editor side by side |
| **Stack** | < 720 dp | Hidden (drawer) | One pane at a time |

- Minimum window size: 360 × 560 dp.
- Dividers between panes drag to resize; ratios persist per tier across sessions.
- Sidebar state (expanded/collapsed) persists per tier too — shrinking the window
  collapses the sidebar once, growing it back restores the user's last choice.

Input hierarchy: **keyboard → pointer → touch**. On the desk everything is
keyboard-reachable; hover does the revealing that long-presses do on touch.

## The desktop shell (Expanded tier)

```
┌──────────────────────────────────────────────────────────────────┐
│ ◫ Sheaf          ⌕ Search notes…                        ─ ▢ ✕    │ ← GTK header bar
├────────────┬─────────────────────────┬───────────────────────────┤
│ All notes  │ ⌕ Filter…     ⇅ Recent  │ today 9:41         ⭐  ⋮   │
│ Pinned     │─────────────────────────│                           │
│ Reminders  │ Meeting notes           │ Meeting notes             │
│────────────│ Budget talk — ship Q3…  │                           │
│ TAGS       │ 9:41 · #work       📌   │ Budget talk — ship Q3.    │
│ #work      │─────────────────────────│ Mara owns the deck. Check │
│ #q3        │ Idea: ink spines        │ with finance before Fri.  │
│ #ideas     │ 8:02                    │                           │
│────────────│─────────────────────────│                           │
│ 🗑 Trash   │ ╭─────────────────────╮ │ #work #q3                 │
│            │ │ ✎ Take a note…   ^N │ │                           │
│            │ ╰─────────────────────╯ │ 128 words · saved 9:42    │
└────────────┴─────────────────────────┴───────────────────────────┘
  sidebar 240          list 340              editor flex (min 480)
```

### Pane specs

| Pane | Width | Contents |
|---|---|---|
| Sidebar | 240 dp, resizable 200–320; collapses to 64 dp rail (`Ctrl+\`) | Quick filters (All notes, Pinned, Reminders), tags, Trash |
| Note list | 340 dp, resizable 300–420 | Filter field, sort control, compact rows grouped by day |
| Editor | Flexible, min 480 dp | Title, body, tag row, mono status footer |

- **Header bar:** GTK-style client-side decorations on Linux — wordmark left,
  global search center, window controls right. No traditional menu bar; the
  command palette replaces it.
- **List rows** are compact at the desk: 56 dp tall — title, one-line snippet,
  mono timestamp; trailing actions reveal on hover.
- **Editor prose** caps at ~72 characters per line, centered; extra width becomes margin.

### Command palette (`Ctrl+K`)

Centered overlay on `surface.inset`, `radius.xl`, held shadow. Fuzzy-searches notes
*and* commands ("Pin note", "Switch theme", "Empty trash"). Arrows navigate,
Enter runs, Esc dismisses.

### Quick capture (global hotkey)

`Ctrl+Alt+N` (remappable) opens a small borderless quick-capture window near the tray:
one field, Enter saves to Inbox and closes, Esc discards with an undo toast.
This is the desktop expression of the capture bar — writing without finding the app.

## Keyboard map

| Action | Shortcut |
|---|---|
| New note in editor pane | `Ctrl+N` |
| Quick-capture window (system-wide) | `Ctrl+Alt+N` |
| Command palette / search | `Ctrl+K` |
| Find in note | `Ctrl+F` |
| Toggle pin | `Ctrl+Shift+P` |
| Delete note (undoable) | `Del` |
| Cycle theme System → Light → Dark | `Ctrl+Shift+L` |
| Collapse / expand sidebar | `Ctrl+\` |
| Move between list rows | `↑ / ↓` |
| Open selected note | `Enter` |
| Close overlay / collapse composer | `Esc` |

Every interactive element is reachable by Tab in reading order; the focus ring
(2 px ink, offset 2 px) is always visible — never suppressed for aesthetics.

## Pointer behavior

| Interaction | Response |
|---|---|
| Hover list row | Tint steps one level up; trailing pin/delete icons fade in (120 ms) |
| Hover card | Hairline darkens one step — no scale, no shadow |
| Editable text | `cursor: text`; buttons and links `cursor: pointer` |
| Right-click row | Context menu (`radius.m`, held shadow): Open · Pin · Copy · Delete |
| Text selection | Ink @ 24% selection color |
| Scrollbars | Thin overlay style, auto-hide; appear while scrolling or hovering the area |

## Grid & spacing

- Base unit: **8 pt** grid, 4 pt half-steps. Ramp: `4 · 8 · 12 · 16 · 24 · 32 · 48 · 64`.
- Pane inner padding: **24 dp**. Card padding: **16 dp**. Card gap: **10 dp**.
- The phone keeps its 20 dp gutter; the desk uses 24 dp because it is read from farther away.

## Radius scale

| Token | Value | Applied to |
|---|---|---|
| `radius.pill` | 999 | Chips, capture bar, washes |
| `radius.xl` | 20 | Sheets, dialogs, command palette |
| `radius.l` | 16 | Note cards, expanded composer, quick-capture window |
| `radius.m` | 12 | Inputs, menus |
| `radius.s` | 8 | Small buttons, code spans |

Nested corners step down one level (card 16 → pill chip inside is fine).

## Elevation: "Paper doesn't float"

Surfaces separate by **tint steps and hairlines**, not shadows:

| Level | Daylight | Lamplight | Used by |
|---|---|---|---|
| 0 — canvas | `#F3F4F7` | `#131110` | Screen background |
| 1 — card | `#FFFFFF` + hairline | `#1D1B17` | Note cards, list rows on hover |
| 2 — raised | `#EAEDF1` | `#26231D` | Header bar, docked bars |
| inset — sunk | `#E4E8EF` | `#0E0D0C` | Search/filter fields, wells |

Real shadows belong only to things being *held*: expanded composer, dragged cards,
command palette, quick-capture window, menus (blur 24, y-offset 8, black @ 18%).

## Stack tier (phone companion)

Below 720 dp the shell stacks: the sidebar folds into a drawer, and list ↔ editor
swap in place. The docked capture bar returns — the pocket expression of the
inline compose field.

```
┌──────────────────────────────┐
│ ☰  Sheaf            ⌕    ⋮   │
│                              │
│ TODAY                        │ ← mono eyebrow (real grouping)
│ ┌──────────────────────────┐ │
│ │ Meeting notes       9:41 │ │
│ │ Budget talk — ship Q3.   │ │
│ │ #work  ▓pinned▓          │ │
│ └──────────────────────────┘ │
│ YESTERDAY                    │
│ ┌──────────────────────────┐ │
│ │ Groceries           yest.│ │
│ └──────────────────────────┘ │
│ ╭──────────────────────────╮ │
│ │ ✎  Take a note…          │ │
│ ╰──────────────────────────╯ │
└──────────────────────────────┘
```

Structural devices encode real information only: day eyebrows exist because notes
group by day; mono timestamps exist because time is machine-recorded. No numbered
markers anywhere — a pile of notes has no inherent sequence.

## Iconography

- **Material Symbols Rounded** as the baseline set; weight 400, optical sizes 20/24.
- Selected/active states bump to weight 600 (and filled where available) — weight,
  not color, signals selection wherever possible.
- Stroke rhythm matches Hanken 500; avoid mixing sharp-cornered icon sets.

## Target-size floor

- Focus ring (2 px ink, offset 2 px) on every interactive element, all tiers.
- Touch hardware: targets ≥ 48 × 48 dp, including timestamps and chips.
- Pointer only: targets may bottom out at 32 × 32 dp with ≥ 8 dp between neighbors.
