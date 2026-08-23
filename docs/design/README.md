# Sheaf Design Language — Quire

> Codename **Quire**: a quire is a gathering of folded pages — the unit a notebook is built from.
> This design language is the unit Sheaf's interface is built from.

| Doc | What it covers |
|---|---|
| [design-language.md](design-language.md) | Concept, principles, signature elements, voice |
| [color.md](color.md) | Full token palettes — Daylight, Lamplight, highlighters, contrast |
| [typography.md](typography.md) | Typefaces, scale, weights, usage rules |
| [layout-and-space.md](layout-and-space.md) | Desktop-first three-pane shell, window tiers, grid, elevation, keyboard map |
| [motion.md](motion.md) | Timing, easing, transitions, reduced-motion policy |
| [theming.md](theming.md) | Daylight / Lamplight / System variants and the Flutter implementation map |

## The one-sentence thesis

**Same ink, different light.** The pen never changes — one ink-blue accent family is constant —
while surfaces invert temperature: cool daylight paper in light mode, warm lamplight charcoal in dark mode.

**Platform posture:** desktop-first on Linux, folding down to phones. One structure,
three window tiers; every feature lands on the desk before it folds into a pocket.

## Quick-start token cheat sheet

| Token | Daylight (light) | Lamplight (dark) |
|---|---|---|
| `canvas` | `#F3F4F7` | `#131110` |
| `card` | `#FFFFFF` | `#1D1B17` |
| `text.primary` | `#191C24` | `#ECE7DC` |
| `accent.ink` | `#2F4BD7` | `#93A8F0` |
| `accent.onInk` | `#FFFFFF` | `#10131F` |

Full sets live in [color.md](color.md).
