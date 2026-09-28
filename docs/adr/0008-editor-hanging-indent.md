# ADR 0008 — Hanging indent for wrapped list text in the editor (DEFERRED)

Status: **Deferred** — plan task 3 of v0.3.5 "steady". The mechanism
specified in the plan (`LineBoxPainter`) does not exist in Flutter 3.49
beta (confirmed by grep of the entire `packages/flutter/lib/` source
tree, and by `pub.dev/packages?q=linebox+painter` returning 0 results).
This document records the decision and the best available implementation
path for a future version.

## Context

The preview renders wrapped list text with a hanging indent via
`Row(marker SizedBox, Flexible content)` — wrapped continuation lines
align with the first character of the item's content, not the marker.
This matches Obsidian/Typora.

The editor uses a plain `TextField` with a `HighlightingController`
that styles spans. List markers (`- `, `* `, `1. `, `- [ ] `) are real
characters in the text buffer, and wrapped continuation lines inherit
the left edge of the first line — they align with the marker column,
not the content column.

This is a cosmetic-only limitation: text content, selection, caret,
IME, undo, and autosave are all unaffected. Only the visual alignment
of wrapped continuation lines differs from the preview.

## Why `LineBoxPainter` is not available

The v0.3.5 plan assumed `LineBoxPainter` — a per-line paint hook on
`TextPainter` / `RenderEditable` — exists as a public Flutter API.
It does not. Verified:

- `grep -rn "LineBoxPainter\|lineBoxPainter" packages/flutter/lib/`
  returns zero matches.
- `pub.dev/packages?q=linebox+painter` returns 0 packages.
- `pub.dev/packages?q=hanging+indent+flutter` returns 42 packages,
  none providing an editor-level hanging indent hook.
- `pub.dev/packages?q=text+indent+editor+flutter` returns 51 packages;
  all are full rich-text editors (`flutter_quill`, `novident_editor`
  / AppFlowy fork, WebView-based), not drop-in `TextField` extensions.
- The only painter hooks in `RenderEditable` are `painter` and
  `foregroundPainter` (both `RenderEditablePainter`, which paint
  highlights/carets on top of the text layer — they cannot translate
  individual text lines).
- `TextField` and `EditableText` expose no per-line paint callback.

## Why the obvious hack does not work

A `TextPainter` subclass can override `paint` to translate continuation
lines via `canvas.save() → translate(indent) → clipRect(line) →
super.paint() → restore()`, using `computeLineMetrics()` to find line
boundaries. This moves the *paint* of wrapped text.

But the caret and selection in `RenderEditable` are painted by separate
painters that read from `TextPainter.getOffsetForCaret()` and
`getBoxForSelection()` — both return positions in *layout* space, not
paint space. If paint is translated and layout is not, the caret and
selection highlight appear at the original (left-edge) x-position
while the text is visually indented. The caret would appear to the
left of the text it belongs to.

Fixing this would require overriding `RenderEditable`'s `paint` method
and the caret/selection position conversion — neither of which is a
supported extension point. `RenderEditable` is not designed to be
subclassed for this purpose.

## Decision

**Defer to a future version. Revisit with a custom-editor-architecture
approach.** The preview already renders lists correctly; the editor's
limitation is cosmetic and not solvable within the current `TextField`
architecture without either (a) a Flutter framework change, or (b) a
multi-day rewrite on a custom render-object framework.

## Best available implementation path (for future work)

### Option A: Custom paragraph-based editor (recommended)

Build a custom editor widget that renders each paragraph as a separate
`RenderBox` child, rather than using a single `TextField`. This is the
approach used by `flutter_quill` (via `RenderQuillDocument` /
`RenderQuillParagraph`) and `novident_editor` (AppFlowy fork).

**Architecture sketch:**

1. **`RenderEditor`** (custom `RenderBox`): vertical stack of paragraph
   render objects. Manages text layout, caret, selection, and IME
   across paragraphs. Similar to `RenderEditable` but paragraph-aware.

2. **`RenderParagraph`** (custom `RenderBox` per paragraph): wraps a
   `TextPainter` + `RenderParagraph`. For list items, uses
   `ParagraphConstraints.indent` (engine-level, accessible via
   `ui.ParagraphBuilder.setIndent`) to set the hanging indent — the
   first line starts at the marker position, wrapped lines start at
   the content position. The engine's paragraph layout handles the
   hanging indent natively, so caret and selection positions are
   computed correctly by the layout engine.

3. **IME / caret / selection**: implemented at the `RenderEditor` level,
   mirroring `RenderEditable`'s approach but spanning multiple
   `RenderParagraph` children. This is the largest piece of work —
   `RenderEditable` is ~3000 lines of carefully reasoned code.

4. **Undo / formatting / shortcuts**: Sheaf's existing `UndoHistory`,
   `formatting.dart`, `list_continuation.dart`, and `shortcuts.dart`
   are controller-level and editor-agnostic — they operate on
   `TextEditingValue`, not on the render object. They can be reused
   as-is.

**Effort estimate:** 3–5 engineering days. The paragraph-based layout
is ~1–2 days; the IME/caret/selection port is the riskiest ~2 days;
formatting and undo wiring is ~0.5 day.

**Tradeoffs:** Full control over rendering, including hanging indent,
per-paragraph styling, and custom decorations. Loses the built-in
behavior of `TextField` (accessibility, context menu, scroll behavior)
and requires reimplementing them. Higher maintenance burden — the
custom editor is one more surface to keep in sync with Flutter changes.

### Option B: TextPainter paint translation (rejected — broken)

Subclass `TextPainter`, override `paint`, translate continuation lines
via `canvas.save() → translate → clipRect → super.paint() → restore()`.

**Broken:** caret and selection paint at layout positions, not paint
positions. The caret appears to the left of the text it belongs to.
Would require overriding `RenderEditable.paint` and the caret position
conversion — neither is a supported extension point.

### Option C: CustomPaint gutter overlay (rejected — misleading)

Wrap the `TextField` in a `Stack` with a `CustomPaint` that paints a
colored gutter (marker background) to the left of list items. Text
stays at the left edge; the gutter is a visual decoration only.

**Broken:** text is not actually indented — it's at the left edge with
a colored stripe beside it. Caret and selection are correct, but the
visual alignment doesn't match the preview's hanging indent. This is
not a real hanging indent; it's a marker background. Misleading.

### Option D: Accept the limitation (current state)

The preview renders lists correctly. The editor's wrapped continuation
lines align with the left edge instead of the marker column. Cosmetic
only. No code change needed.

## Revisit triggers

Revisit this ADR when:

1. **Flutter ships a per-line paint hook** on `TextPainter` or
   `RenderEditable` (a `LineBoxPainter` API). This would make Option A
   unnecessary — the hook would let us translate continuation lines
   without breaking caret/selection.
2. **Sheaf's editor gains features that require a custom render object**
   — e.g. inline images, math blocks, embeds. A custom paragraph-based
   editor would handle these naturally.
3. **The user prioritizes visual parity with the preview over editor
   editing capability** — e.g. a read-only editor mode that renders
   like the preview but accepts text input.

## Decision log

- 2026-09-28: Deferred. `LineBoxPainter` does not exist in Flutter 3.49
  beta or on pub.dev. Task 3 of v0.3.5 "steady" is deferred to a future
  version; the plan should be updated to mark it as deferred. Proceed
  to Task 4 (preview alignment regression test, independent, test-only).
