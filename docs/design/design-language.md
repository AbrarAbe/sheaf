# Quire — Concept & Principles

Sheaf is a quick-capture note app, **desktop-first on Linux**, folding down to phones.
Its users open it dozens of times a day for thirty-second sessions: a thought arrives,
they get it down, they leave. The design must serve two opposite moods of the same
person — **the fast hand** (capture in seconds: `Ctrl+Alt+N` at the desk, a thumb on
the phone) and **the patient eye** (reading notes back later should feel calm, never busy).

## Thesis: Same ink, different light

A pen's ink does not change when you move from a desk by the window to a desk
under a lamp. Only the light on the paper changes.

That is the whole theming story of Sheaf:

- **One accent family, always.** Ink blue (`#2F4BD7` light / `#93A8F0` dark) is
  the same pen in both themes. Selection, links, primary actions — all "written in ink."
- **Surfaces invert temperature.** Light mode (**Daylight**) is cool, morning-paper gray.
  Dark mode (**Lamplight**) is warm charcoal — lamplight falling on a dark desk,
  not a cold gray photocopy of Daylight.

This makes the two themes siblings rather than clones: recognizably the same app,
each honest about its time of day.

## The five principles

1. **Capture outranks chrome.** The fastest path from thought to saved note wins every
   tie-breaker. Writing is never more than one gesture away — a global hotkey
   quick-capture window and an inline compose field on the desktop, a docked capture
   bar on the phone (see [layout-and-space.md](layout-and-space.md)).
2. **Paper doesn't float.** Surfaces sit on the desk; they are distinguished by tint
   steps and hairlines, not drop shadows. Shadows are reserved for things you are
   actively *holding*: the expanded composer, dragged cards, menus.
3. **Color means something.** Accent = ink (interaction). Highlighters = state
   (pinned, alert, saved, waiting). If color carries no meaning, it isn't used.
4. **Type does the talking.** Personality lives in typography — Bricolage Grotesque
   display moments, Hanken Grotesk reading body, mono for anything the machine records
   (time, counts). No decorative illustration needed for the interface to have character.
5. **Quiet until touched.** Resting state is calm and low-contrast-noise. Motion,
   washes, and weight appear as responses to the user's hand.

## Signature elements

Spend boldness in exactly two places; everything else stays disciplined.

### 1. The highlighter wash (visual signature)
Semantic states are rendered like marker strokes on paper: a translucent highlighter
background behind text or chips with a darker same-hue foreground — never a solid fill,
never a gradient. A pinned note wears a yellow wash chip. An error line wears coral.
It reads instantly because everyone knows what a highlighter means on a page.

Rules: washes mark *state*, at roughly 14–30% alpha, with rounded terminals.
Never use a wash for decoration on headings or marketing copy inside the product UI.

### 2. Capture without navigation (interaction signature)
Writing starts where you already are. On the desktop: an inline compose field above the
note list, `Ctrl+Alt+N` for a global quick-capture window over whatever you're doing,
and `Ctrl+K` to search your way anywhere. On the phone: the docked capture bar expands
in place into the editor — the app's orchestrated motion moment (see [motion.md](motion.md)).

## What Sheaf is not (anti-patterns)

| Not this | Why |
|---|---|
| Cream paper + serif display + terracotta accents | The cozy-stationery cliché. Sheaf's light mode is cool daylight gray, its accent is cobalt ink. |
| Near-black + single acid-green accent | Dark mode is warm charcoal with the same constant ink family — not a hacker terminal. |
| Hairline-rule broadsheet grids, zero radius | Notes are soft objects on a desk: 16 px card radius, hairlines only as quiet separators. |
| Decorative color, gradients, glass blur | Color is vocabulary (principle 3), not wallpaper. |
| FAB → new route → blank editor | Two taps before a word is written violates principle 1. |

## Voice & microcopy

Words are design material. Plain verbs, sentence case, active voice. An action keeps
its name through the whole flow ("Delete" produces "Note deleted"). Errors state what
happened and what to do next — they don't apologize and don't shrug. Empty states are
invitations, not mood pieces.

| Moment | Copy |
|---|---|
| Empty notes list | Title: "Nothing here yet." · Button: **Write the first note** |
| Capture bar placeholder | "Take a note…" |
| Delete confirmation | Title: "Delete note?" · Body: "This can't be undone." · Actions: **Delete** / **Keep** |
| Sync failure banner | "Couldn't sync. Your notes are safe on this device." · Action: **Retry** |
| Search with no results | "No notes match 'quokka'." · Hint: "Try fewer words, or check the spelling." |
| Save status (mono footer) | `saved 9:42` · `saving…` |

## Accessibility floor (non-negotiable)

- Body text contrast ≥ 7:1; secondary ≥ 4.5:1; all pairings verified in [color.md](color.md).
- Desktop is keyboard-complete: every action has a shortcut or palette entry, and the
  focus ring (2 px ink, 2 px offset) is always visible.
- Touch targets ≥ 48 × 48 dp on touch hardware; pointer-only targets bottom out at
  32 dp with 8 dp spacing (see [layout-and-space.md](layout-and-space.md)).
- All states distinguishable without color alone — washes always accompany a label or icon.
- Every animation has a reduced-motion fallback ([motion.md](motion.md)).
