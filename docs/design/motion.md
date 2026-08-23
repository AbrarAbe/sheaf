# Motion

Motion in Taker answers one question: *where did my note go?* Every transition
preserves spatial continuity so a thought is never lost between screens. Beyond that,
the app is quiet.

## Timing & easing

| Token | Duration | Curve | Usage |
|---|---|---|---|
| `motion.instant` | 120 ms | standard | Press states, chip toggles |
| `motion.quick` | 180 ms | standard | Fades, small slides |
| `motion.standard` | 240 ms | emphasized | Card enter/exit, sheet open |
| `motion.slow` | 320 ms | emphasized | Capture-bar expansion |

- `standard` = cubic(0.2, 0.0, 0.0, 1.0). `emphasized` = Material's emphasized decelerate
  for entrances, accelerate for exits.
- Nothing animates longer than 320 ms. A capture tool must never feel like it hesitates.
- Enter animations travel ≤ 16 dp — notes arrive from where they belong, they don't fly in.

## The orchestrated moment: capture-bar expansion

The one choreographed sequence in the product:

1. Tap the docked pill → it grows from pill to full editor card (`radius.pill` → `radius.l`,
   height animates), while the feed dims to `text.primary` @ 6% and scrolls to top-lock.
2. The keyboard rises *with* the growing bar (shared frame timing, not sequential).
3. Focus lands in the title field; the mono footer fades in last (`motion.quick`).
4. Collapse reverses the path exactly — the note visibly "goes back into the pile,"
   landing in its correct day group with a one-time `hl.grow` flash on save.

This sequence is spring-driven (stiffness ≈ 380, damping ratio ≈ 0.9) so it feels
hand-thrown rather than tweened.

## Micro-interactions

| Element | Response |
|---|---|
| Note card press | Scale 0.98 (touch) / hairline darkens (pointer), 120 ms |
| Chip toggle | Wash fades in/out 120 ms; label crossfades |
| Row hover (pointer) | Tint steps one level; trailing actions fade in 120 ms |
| Palette & menu open/close | 120 ms fade + 4 dp drop; close reverses |
| Pin action | Star fills; `hl.pin` wash blooms once at 30% → settles |
| Delete swipe | Card slides out, gap closes via implicit reflow, undo snackbar 4 s |
| Sync status | Mono footer text swap only — no spinners for background sync |

## Reduced motion

When the platform reports reduced motion (`MediaQuery.disableAnimations` on Android):

- Expansion becomes a 100 ms crossfade with instant focus.
- Springs collapse to their end state; swipe actions become tap-revealed menus.
- The save flash is replaced by the static wash.

Nothing functional is lost — motion is confirmation, never information.
