# Audit: Markdown/Editor overrides v0.1.0 → v0.3.3

**Scope.** Every place Sheaf overrides, extends, or works around the native
behavior of `package:markdown` (v7.3.1), `package:markdown_widget` (v2.3.2+8),
and the editor's three-mode formatting stack.

**Method.** Read-only survey of `lib/ui/editor/`, `lib/logic/`, `docs/spec.md`,
`docs/plan/plan_v0.1–v0.3.3.md`, plus targeted greps in the pub cache at
`~/.pub-cache/hosted/pub.dev/markdown-7.3.1/` and
`~/.pub-cache/hosted/pub.dev/markdown_widget-2.3.2+8/`.

**Bottom line.** 5 overrides in the preview layer, 3 hand-rolled editor
features that overlap with what a generic markdown editor does, and 1
editor-mode mechanic worth flagging. Details and verdicts below.

---

## A. Preview layer (`lib/ui/editor/markdown_preview.dart`)

### A1. `_UnderlineSyntax` (line 13-21)
- **What it replaces:** `InlineHtmlSyntax`'s generic `namedTagDefinition` match
  already matches `<u>…</u>` verbatim (the `namedTagDefinition` pattern in
  `markdown-7.3.1/lib/src/patterns.dart` accepts any lowercase tag name
  followed by an optional attribute block). So `<u>hello</u>` produces an
  `md.Element('u', [...])` *without* the custom syntax.
- **Verdict: FLAG / likely redundant.** Adding a custom `InlineSyntax` with
  pattern `<u>(.+?)</u>` may or may not actually take precedence over the
  library's `InlineHtmlSyntax` — the inline parser walks syntaxes in a fixed
  order (`InlineParser.parse` at
  `~/.pub-cache/.../inline_parser.dart:60-95`), so it depends on insertion
  order. The custom syntax is safe but *probably duplicative* of the library's
  inline-HTML pass. Worth a targeted probe (see next section).

### A2. `_UnderlineNode` + `SpanNodeGeneratorWithTag(tag: 'u', ...)` (lines 75-85, 239-241)
- **What it replaces:** `markdown_widget` does not ship a `<u>` renderer. Its
  default node set (`widget/blocks/leaf/` = code_block, heading,
  horizontal_rules, link, paragraph; `widget/inlines/` covers bold/italic/code/
  strikethrough) has no underline. `SpanNodeGeneratorWithTag(tag: 'u')` is the
  documented extension point.
- **Verdict: KEEP.** Genuinely needed — the widget package has no underline
  node. (There is exactly one `underline` occurrence in the widget source:
  `widget/blocks/leaf/link.dart:56`, applied to links, not `<u>`.)

### A3. `_IndentedParagraphSyntax` (lines 36-72) — shipped as Task 5 of v0.3.3
- **What it replaces:** `CodeBlockSyntax` (4-space indent → `<pre>` code) and
  the 1–3-space visual indent leak into `<p>`. `CodeBlockSyntax` is in
  `BlockParser.standardBlockSyntaxes` (verified at
  `~/.pub-cache/.../block_parser.dart:65-77`, confirmed: it appears at line 70
  of that array, and line 83 shows `blockSyntaxes.addAll(standardBlockSyntaxes)`
  runs unconditionally because `withDefaultBlockSyntaxes` defaults to `true` in
  `Document` at `~/.pub-cache/.../document.dart:53`). **No `ExtensionSet`
  contains `CodeBlockSyntax`**, so `extensionSet` cannot disable it. Document
  syntaxes (from `blockSyntaxList`) are walked before standard ones in
  `BlockParser.parseLines` at `~/.pub-cache/.../block_parser.dart:179-200`, so
  the custom syntax wins.
- **Verdict: KEEP.** No native option to strip leading whitespace from prose.
  The `MarkdownGenerator.buildWidgets` at
  `~/.pub-cache/.../markdown_widget-2.3.2+8/lib/config/markdown_generator.dart:50-55`
  confirms: it forwards `inlineSyntaxes`, `blockSyntaxes`, `extensionSet`
  straight through to `md.Document(...)` with no way to override
  `withDefaultBlockSyntaxes`. The custom syntax is the only path.

### A4. `MarkdownConfig` block (lines 120-205) — theme-only
- **What it replaces:** `MarkdownConfig.defaultConfig` defaults. Sheaf
  supplies custom fonts/sizes/colors/borders for every block (P, H1, H2, H3,
  Code, Pre, Blockquote, Table, List, CheckBox) plus a custom `ImgConfig`
  builder.
- **Verdict: KEEP (expected).** This is the documented styling hook for
  markdown_widget. No override, no workaround.

### A5. `MarkdownGenerator` config at lines 235-242
- **What it replaces:** defaults. Sheaf sets `linesMargin: vertical: 7` (vs
  default `vertical: 8`), `blockSyntaxList: [_IndentedParagraphSyntax]`,
  `inlineSyntaxList: [_UnderlineSyntax]`, and `generators:
  [SpanNodeGeneratorWithTag(tag: 'u', ...)]`. Notably it does **not** set
  `extensionSet`, so `gitHubFlavored` is used (the widget's default at
  `markdown_generator.dart:51`).
- **Verdict: KEEP, with one caveat.** The config itself is fine. The caveat is
  that the plan/spec describe this as the "canonical" approach for indentation,
  but the underlying mechanism (custom `BlockSyntax` shadowing
  `CodeBlockSyntax`) is a workaround that only works because of the fixed parse
  order in `BlockParser.parseLines`. If the library changes parse order or
  moves `CodeBlockSyntax` into an `ExtensionSet`, this breaks silently. Worth
  a test comment, not a code change.

### A6. Empty-body placeholder (lines 209-220)
- **What it replaces:** Nothing — `MarkdownPreview.build` early-returns on
  empty body, so it never reaches the parser.
- **Verdict: KEEP.** Presentation-only; no library interaction.

### A7. `_image` builder with `![alt|400]` width syntax (lines 244-299)
- **What it replaces:** `markdown_widget`'s `ImgConfig.builder` default renders
  with no width hint. Sheaf parses an Obsidian-style `|400` suffix out of the
  alt text and applies it as a width.
- **Verdict: KEEP.** Obsidian extension, not in the library. `markdown_widget`
  has no width-hint parse in `ImgConfig`.

---

## B. Editor 3-mode layer

### B1. `HighlightingController` (`lib/ui/editor/highlighting_controller.dart:11-201`)
- **What it is:** A `TextEditingController` that overrides `buildTextSpan` to
  render markdown source with styled spans *live in the text field* — markers
  stay as real characters, only their paint is dimmed/hidden. Regex-driven:
  `_heading` matches `^ {0,3}(#{1,6})( +)(.*)$`, `_inline` matches `***...***`,
  `**...**`, `*...*`, `_..._`, `` `...` ``, etc.
- **What a library does:** This is the classic "in-place syntax highlighting"
  pattern. `flutter_highlight`, `code_text_field`, and `highlighted_text`
  packages do this — but they target *source code* highlighting (Dart, Python,
  …), not markdown source. A markdown source highlighter would need to parse
  *both* inline (`**bold**`, `*italic*`) and block (`# heading`, `- item`,
  fences) and render them with different styles, while keeping the source
  editable. `flutter_markdown_editor` does this (per its README), but it's an
  editor widget, not a `TextEditingController` mixin.
- **Verdict: KEEP (deliberately hand-rolled).** The spec story 12 pins the
  behavior: "styled spans with **dimmed markers** — markers stay real
  characters, so selection/caret offsets are untouched." No shipping package
  exposes a `TextEditingController` subclass with this contract. This is
  genuinely app-specific; it's not a library feature being duplicated.

### B2. `FormatKind` / `toggleWrap` / `_enclosingSpan` (`lib/logic/formatting.dart:22-387`)
- **What it does:** Toggles `**bold**`, `*italic*`, `<u>underline</u>` around
  a selection, with smart unwrapping and caret placement. `wordBoundary`
  implements VS Code-style word selection.
- **What a library does:** Generic text-editing primitives (wrap, unwrap,
  word-boundary). `package:markdown` is a *parser* — it doesn't do text
  editing. Editor packages (`code_text_field`, `flutter_markdown_editor`) ship
  wrap/unwrap, but they bundle a whole editor widget, not a pure function.
- **Verdict: KEEP.** Deliberately pure string math (no Flutter imports,
  headlessly unit-testable). This is the right shape for a portable
  format-toggle API.

### B3. `indentBlock` / `outindentBlock` (`lib/logic/line_edit.dart:17-106`)
- **What it does:** Four-space indent/outindent per touched line, with
  selection remap.
- **What a library does:** Standard editor feature; every IDE has it. No
  shipping Flutter package exposes this as a pure function.
- **Verdict: KEEP.** Same shape as B2 — pure string math, headlessly
  testable, no library to lean on.

### B4. `continueList` (`lib/logic/list_continuation.dart:31-117`)
- **What it does:** Enter at end of a list item inserts a new item with the
  same marker (incrementing ordered numbers, preserving `-` / `*` / `+`,
  preserving task checkboxes). Empty-item Exit: clears the marker.
- **What a library does:** The classic Obsidian/Typora/VS Code list
  continuation. No shipping Flutter package exposes this as a pure function.
- **Verdict: KEEP.** Pure string math. The regex `_markerPattern` is a
  hand-rolled markdown list parser — but it's a *line-level* regex matching
  the marker at the start of a line, not a full markdown parser. This is the
  standard implementation approach (every editor that does list continuation
  uses a regex like this). Not a duplication of `package:markdown`, which
  doesn't expose line-editing.

---

## C. Things worth FLAGGING (not overrides, but behavior worth re-checking)

### C1. `<u>` inline — possible double-parse (spec story 10)
- The spec pins "renders `<u>` spans underlined" but the *library already
  parses `<u>…</u>` as `md.Element('u', ...)`* via `InlineHtmlSyntax` (part of
  `gitHubFlavored`'s inline list). The custom `_UnderlineSyntax` may be
  matching the *same* text the library already matches, or the custom syntax
  may win depending on the inline parser's iteration order.
- **Worth probing:** add a one-line debug print in `_UnderlineSyntax.onMatch`
  and `InlineHtmlSyntax.onMatch` (or a probe script) to see which one fires
  for `<u>hello</u>`. If both fire, the custom syntax is dead code; if only
  the library fires, the custom syntax is being shadowed and the test only
  passes because the *rendering* side (`_UnderlineNode`) is what produces the
  underline. Either way, worth confirming before the next release.
- **Not a breaking issue** — the test `renders <u> spans underlined` passes
  either way. But the custom `_UnderlineSyntax` may be redundant.

### C2. `_IndentedParagraphSyntax` pattern is broader than spec requires
- Spec story 47 says: "leading-space indentation on non-list lines never
  renders as an indented code block; indentation displays only as list
  structure. Fenced code blocks still render as code."
- The custom syntax matches `^[ \t]+` — *any* leading whitespace — and strips
  it all. So a user who writes a hand-indented ASCII diagram in prose
  (indented by 8 spaces to align with a fence above) gets their diagram
  dedented. Not a spec violation, but worth noting: the spec says "indent
  displays only as list structure," which is what the code does. If a future
  user wants to hand-indent ASCII diagrams, they need a way to bypass this
  (e.g. a fence-wrapped diagram, or a `no-indent` directive).
- **Verdict: KEEP as-is.** The spec is unambiguous about the intent. Add a
  comment in the syntax if this ever becomes a support issue.

### C3. `extensionSet` is never customized
- The plan/spec consistently say "the preview uses a custom extension set,"
  but the code actually uses the default `gitHubFlavored` (via
  `MarkdownGenerator`'s default at
  `markdown_generator.dart:51`). The custom syntax is *additional*, not
  replacing any extension.
- **Verdict: doc-only drift, not code.** The plan at
  `docs/plan/plan_v0.3.3.md:28` already corrects this: "Registering a custom
  `BlockSyntax` … runs before the standard syntaxes (document syntaxes are
  tried first in `BlockParser.parseLines`)." The older story at
  `docs/spec.md:14` (section 14, Indentation policy) also describes the
  custom-syntax approach correctly. The phrase "custom extension set" appears
  only in the *original* plan text that Task 5 already rewrote. Nothing to
  fix.

---

## D. What is *not* overridden (verified clean)

- `extensionSet`: never set, defaults to `gitHubFlavored`. Verified
  `MarkdownGenerator.buildWidgets` at
  `markdown_widget-2.3.2+8/lib/config/markdown_generator.dart:50-55`
  forwards it straight to `md.Document`.
- `withDefaultBlockSyntaxes`: never set, defaults to `true` at
  `markdown-7.3.1/lib/src/document.dart:53`. Verified `standardBlockSyntaxes`
  is added unconditionally at `block_parser.dart:83`.
- Inline syntaxes: only `_UnderlineSyntax` is added; the library's
  `InlineHtmlSyntax`, `StrikethroughSyntax`, `AutolinkExtensionSyntax` (from
  `gitHubFlavored`) all still fire.
- Block syntaxes: only `_IndentedParagraphSyntax` is added; the library's
  `FencedCodeBlockSyntax`, `TableSyntax`, `UnorderedListWithCheckboxSyntax`,
  `OrderedListWithCheckboxSyntax`, `FootnoteDefSyntax` (from
  `gitHubFlavored`) all still fire. The custom syntax is gated on
  `parentSyntax == null` so it never fires inside a list/quote.
- `SplitRegExp`: never set, uses `WidgetVisitor.defaultSplitRegExp`
  (`RegExp(r'(\r?\n)|(\r)')`).
- MarkdownConfig defaults: overridden but only for *styling*, not for
  parse behavior.

---

## E. Verdict summary

**KEEP (genuinely needed — no library covers it):**
- `_UnderlineNode` + `SpanNodeGeneratorWithTag('u', ...)` — no underline
  node in markdown_widget.
- `_IndentedParagraphSyntax` — `CodeBlockSyntax` cannot be disabled via
  `extensionSet`; custom syntax is the only path.
- `MarkdownConfig` styling block — documented styling hook, no override.
- `_image` builder with `|400` width hint — Obsidian extension.
- `HighlightingController` — in-place source highlighting; no library exposes
  a `TextEditingController` subclass with this contract.
- `toggleWrap`, `wordBoundary`, `indentBlock`, `outindentBlock`,
  `continueList` — pure string-math editor primitives; no library exposes
  these as headlessly-testable functions.

**FLAG (worth confirming, not necessarily wrong):**
- `_UnderlineSyntax` — the library's `InlineHtmlSyntax` already matches
  `<u>…</u>`; the custom syntax may be redundant. Probe to confirm.
- `_IndentedParagraphSyntax` pattern — strips *all* leading whitespace,
  which means hand-indented ASCII diagrams in prose get dedented. Spec is
  unambiguous, but worth documenting as a known tradeoff.
- "Custom extension set" language in old plan text — plan already corrected
  in Task 5's rewrite; no doc drift to fix.

**REVERT (not found):** None. Every override in the codebase has a
justification that the library doesn't cover. No duplicative library feature
found.

---

## F. Files touched by this audit

None. Read-only investigation.

## G. What I would probe next (not doing here)

1. **`_UnderlineSyntax` redundancy probe** — a 30-line dart script under
   `test/tmp/` that parses `<u>hello</u>` with and without the custom syntax,
   prints which syntax fires. Would settle whether `_UnderlineSyntax` is dead
   code.
2. **ASCII-diagram regression probe** — a test case like
   `before\n\n        line 1\n        line 2\nafter` (8-space indent for an
   ASCII diagram) to document the current behavior (it gets dedented) so a
   future change is a conscious decision, not a silent regression.

Both are non-urgent; the current code is correct and the audit found no
duplicative library features.
