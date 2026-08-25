# ADR 0007 — Open-notes editor tabs (PROPOSED, not yet implemented)

Status: **Proposed** — feedback round 5 item F17 asked for a plan before any
code. This document is that plan; nothing here has landed.

## Context

Sheaf's editor shows one note at a time; switching notes happens through the
list pane or the ⌘K quick-switcher. The user flagged: "new tab shouldn't live
under All notes — need a plan to handle this." Today the only "tab-like"
concept is the sidebar's *All notes* scope entry, and every open surfaces
through it. The ask is a real tab model where tabs are their own surface,
orthogonal to the sidebar's scope tree.

## Decision (recommended): editor-owned tab strip

**Tabs = open notes, owned by the editor surface — never entries under the
sidebar.** "All notes" remains purely a list/scope concept.

- **Tab strip**: horizontal row of chips docked between the editor header and
  body (`lib/ui/editor/tab_strip.dart`), visible only when ≥1 note is open.
  Shows title (+ dirty dot while autosave is pending), close ×, favicon-ish
  mode glyph not needed.
- **Session model**: `EditorController` gains an ordered `openPaths` list +
  `activeIndex` (persisted to `.sheaf/session.json`, same sidecar precedent
  as meta.json/trash index). Restored on vault open; missing files dropped.
- **Opening rules**: selecting from list/palette/trash-restore opens-or-
  focuses a tab; creating a note opens one. Closing a tab never deletes —
  closes only.
- **Shortcut retarget**: `Ctrl+Tab` / `Ctrl+Shift+Tab` switch TABS (replacing
  today's list-order cycling); `Ctrl+W` closes active tab. List arrows keep
  their meaning in the list pane.
- **Dirty handling**: autosave debounces per note (already exists), so a
  background tab is just "not selected"; no unsaved-changes prompts needed.

## Alternative considered (rejected for now)

No tabs — keep the single-surface editor and lean on creation-scope rules
(new notes already land in the selected folder) plus ⌘K for fast switching.
Cheapest option but doesn't answer the ask: power users lose the
"several notes in flight" mental model Obsidian/VS Code normalize.

## Consequences

- New session persistence file + tests (round-trip, restore-with-deletions).
- `_syncSelection` in `Shell` moves into the editor controller's tab model —
  the largest refactor risk; mitigated by keeping the pane widget API stable
  (`EditorPane(controller: …)` unchanged).
- Ctrl+Tab semantics change — call out in release notes.

## Phasing sketch (for v0.3)

1. Session store + controller state + unit tests (pure logic first).
2. Tab strip widget + focus/open/close wiring + widget tests.
3. Shortcut retarget + docs/release-note updates.
