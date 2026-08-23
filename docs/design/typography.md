# Typography

Sheaf's interface has no illustration budget to lean on — type carries the personality.
Three faces, three jobs, no exceptions.

## The trio

| Role | Face | Where it appears |
|---|---|---|
| **Display** | Bricolage Grotesque 500/600/700 | App name, screen titles, empty-state headlines, section moments |
| **Reading** | Hanken Grotesk 400/500/600/700 | Note bodies, editor, buttons, labels — everything read for content |
| **Utility** | Spline Sans Mono 400/500 | Timestamps, word counts, sync status, date-group eyebrows, tag chips |

Why these: Bricolage's ink-trap quirks echo handwriting without going script;
Hanken Grotesk is a warm grotesque built for long screen reading; the mono face
marks everything *the machine recorded* versus what *the human wrote* — structure
that encodes truth about the content.

All three ship on Google Fonts (bundle via `google_fonts` or asset fonts; never rely on
remote fetch at runtime).

## Scale (dp = sp)

| Style | Face / weight | Size / line height | Tracking | Usage |
|---|---|---|---|---|
| `display.lg` | Bricolage 600 | 34 / 40 | −0.5% | Empty-state headlines |
| `display.sm` | Bricolage 600 | 24 / 30 | −0.25% | Editor note title, screen titles |
| `heading` | Hanken 700 | 20 / 28 | 0 | Card titles in lists |
| `body` | Hanken 400 | 16 / 26 | 0 | Note bodies, editor default |
| `body.emphasis` | Hanken 600 | 16 / 26 | 0 | Bold spans inside notes |
| `label` | Hanken 500 | 14 / 20 | +1% | Buttons, list metadata |
| `caption` | Hanken 400 | 13 / 18 | +1% | Secondary hints |
| `mono` | Spline Mono 400 | 13 / 18 | +2% | Timestamps, counts, status footer |
| `eyebrow` | Spline Mono 500 · uppercase | 11 / 16 | +8% | Date groups ("TODAY"), section labels |

Rules of engagement:

- Display faces are used with restraint — one `display` style per screen. If two
  Bricolage elements compete on a screen, demote one to Hanken.
- Never set note body text below 16 sp; reading comfort beats density.
- The mono face never sets sentences longer than a line. It labels machines' facts,
  not human prose.
- Eyebrows are the only uppercase in the app, and they always mark *real groupings*
  (calendar days, A–Z sections) — never decoration.

## In-editor text styles

The editor renders user content, so its palette of inline styles is deliberately small:

| Span | Treatment |
|---|---|
| Heading in note | Hanken 700, 20/28 |
| Sub-heading in note | Hanken 600, 17/24 |
| Link | `accent.ink`, underline on press only |
| Highlighted span | `hl.*` wash behind text, matching foreground |
| Code span | Spline Mono 13/18 on `surface.inset`, radius 4 |

Checklists and quotes inherit body styling plus an ink-colored gutter marker
(checkbox / 3 px left rule) — no new colors.

## Numerals & details

- Tabular figures (`FontFeature.tabularFigures`) everywhere the mono face appears,
  so timestamps don't jitter as digits change.
- Word count uses a middle dot separator: `128 words · saved 9:42`.
- Long note titles truncate at two lines with an ellipsis; full title shows in the editor.
