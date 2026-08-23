# Color — Daylight & Lamplight

Color in Taker has three jobs, strictly separated:

1. **Ink** — interaction. One blue family, constant across themes.
2. **Highlighters** — semantic state. Four marker hues, applied only as translucent washes.
3. **Neutrals** — surfaces and text, temperature-inverted between themes (cool ↔ warm).

Everything else is off-limits. No gradients, no additional brand hues.

## Daylight (light variant)

Cool, morning-light paper. Slightly blue-gray neutrals so the ink feels native.

### Neutrals

| Token | Value | Usage |
|---|---|---|
| `surface.canvas` | `#F3F4F7` | App background |
| `surface.card` | `#FFFFFF` | Note cards, sheets |
| `surface.raised` | `#EAEDF1` | App bar, elevated containers |
| `surface.inset` | `#E4E8EF` | Search field, wells, code blocks |
| `text.primary` | `#191C24` | Titles, body — 15.9:1 on canvas |
| `text.secondary` | `#565D6E` | Supporting text — 6.0:1 on canvas |
| `text.tertiary` | `#8A91A3` | Disabled, hints — large/mono only |
| `line.hairline` | `#D8DDE6` | 1 px separators, card borders |

### Ink (accent)

| Token | Value | Contrast |
|---|---|---|
| `accent.ink` | `#2F4BD7` | 6.8:1 on white — safe as text |
| `accent.inkPressed` | `#2439AC` | Pressed fills, visited links |
| `accent.wash` | `ink @ 10%` | Selected row background |
| `accent.onInk` | `#FFFFFF` | Text/icons on ink fills |
| `focus.ring` | `#2F4BD7`, 2 px | Keyboard focus, offset 2 px |

## Lamplight (dark variant)

Warm charcoal under a lamp. Neutrals shift hue toward amber-brown; the ink stays a pen.

### Neutrals

| Token | Value | Usage |
|---|---|---|
| `surface.canvas` | `#131110` | App background |
| `surface.card` | `#1D1B17` | Note cards, sheets |
| `surface.raised` | `#26231D` | App bar, elevated containers |
| `surface.inset` | `#0E0D0C` | Search field, wells |
| `text.primary` | `#ECE7DC` | Warm paper-white — 15.0:1 on canvas |
| `text.secondary` | `#A69F8F` | 7.3:1 on canvas |
| `text.tertiary` | `#6E685C` | Disabled, hints — large/mono only |
| `line.hairline` | `#33302A` | Separators, card borders |

### Ink (accent) — brightened, not re-hued

The same cobalt lifted for dark surfaces, drifting toward periwinkle. Never use the
Daylight value on Lamplight backgrounds.

| Token | Value | Contrast |
|---|---|---|
| `accent.ink` | `#93A8F0` | 8.0:1 on canvas |
| `accent.inkPressed` | `#B7C4F5` | Pressed fills |
| `accent.wash` | `ink @ 16%` | Selected row background |
| `accent.onInk` | `#10131F` | Dark text on ink-filled buttons (inverted vs. Daylight — correct practice) |
| `focus.ring` | `#93A8F0`, 2 px | Keyboard focus |

## Highlighters (semantic set)

Marker strokes for state. Applied as **wash + darkened same-hue foreground**;
never solid fills, never on more than a chip, badge, or inline span.

| Name | Meaning | Light base | Light fg | Light wash | Dark base | Dark fg | Dark wash |
|---|---|---|---|---|---|---|---|
| `hl.pin` (yellow) | Pinned / favorite | `#F2C94C` | `#7A5E00` | 30% | `#E8C34A` | `#F4DC86` | 20% |
| `hl.alert` (coral) | Errors, destructive confirm | `#E5484D` | `#B02A30` | 14% | `#FF8A85` | `#FFC2BE` | 18% |
| `hl.grow` (green) | Saved / synced success | `#3FB97F` | `#17603E` | 16% | `#6FCB98` | `#A8E0C2` | 18% |
| `hl.wait` (orange) | Reminders, pending | `#ED8B16` | `#8F5606` | 16% | `#F2A65A` | `#F8CF9E` | 18% |

Wash syntax: hex at the listed alpha over the current surface, e.g. Flutter
`hl.pin.light.base.withOpacity(0.30)`.

Every highlighted element also carries a label or icon — color is never the sole signal.

## Do / Don't

**Do**

- Use ink for anything tappable-meaningful: selection, links, primary buttons, focus.
- Pair each highlighter wash with its matching darkened foreground for text.
- Keep neutrals doing quiet work: canvas recedes, cards advance, inset sinks.
- Let Lamplight be warm. If a dark-mode screenshot looks gray, it's wrong.

**Don't**

- Don't use pure black (`#000000`) or pure white text in Lamplight — halation and dead contrast.
- Don't reuse the Daylight ink value on dark backgrounds (fails contrast and looks muddy).
- Don't introduce a fifth highlighter or a second accent. New meanings need new shapes first.
- Don't place washes behind long paragraphs — they mark chips, badges, spans, rows.

## Contrast ledger (verified pairings)

| Pairing | Ratio |
|---|---|
| Daylight `text.primary` on `canvas` / `card` | 15.9 : 1 / 17.2 : 1 |
| Daylight `text.secondary` on `canvas` | 6.0 : 1 |
| Daylight `accent.ink` on white | 6.8 : 1 |
| Lamplight `text.primary` on `canvas` | 15.0 : 1 |
| Lamplight `text.secondary` on `canvas` | 7.3 : 1 |
| Lamplight `accent.ink` on `canvas` | 8.0 : 1 |
| Highlighter foregrounds on their own wash | ≥ 4.5 : 1 (all eight variants) |
