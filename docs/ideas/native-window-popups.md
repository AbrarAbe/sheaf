# Feasibility: hosting Sheaf's modals/dialogs as native OS windows

**Status:** investigation only. Recommendation: **DO NOT RECOMMEND** (see verdict).

## Current state

Sheaf is a Linux-first Flutter desktop app. Every popup — the settings dialog, note-info
dialog, confirm-delete, new-note dialog, welcome screen, command palette, shortcut prompt,
text prompt — is an in-app Flutter `AlertDialog`/overlay widget rendered inside the single
main window (see `lib/ui/dialogs/`). Shared window chrome, theme, and state live in one
`StatefulApp`/shell; `lib/main.dart` uses `window_manager` only for the one main window
(ensureInitialized, size/fullscreen, minimize/maximize/close, title bar). There are 9
`showDialog` call sites across `lib/` plus one in `test/ui/dialogs/note_info_test.dart`.

Sheaf already depends on `window_manager: ^0.5.2`. Note: the pub.dev release line is at
`0.6.x` with a rewritten nativeapi backend; Sheaf is still on the `0.5.x` API.

## What Flutter supports today (stable vs experimental)

- **Stable Flutter ships no first-class multi-window / native window API.** As of the
  3.44.8 stable release (`2026-07-23`), the framework contains a complete windowing
  API in `lib/src/widgets/_window.dart`, but every class is marked `@internal`, the file
  is not exported from `package:flutter/widgets.dart`, and constructors throw
  `UnsupportedError` unless the `windowing` feature flag is enabled — which is defined
  with `master:` only and has **no `beta:` or `stable:` entry**. Beta will not work;
  `main` channel only.
  - Enable path: `flutter channel main && flutter upgrade && flutter config --enable-windowing`; requires a rebuild (not hot-restart); framework reads `FLUTTER_ENABLED_FEATURE_FLAGS`. Skipping the flag produces the "Windowing APIs are not enabled" / "currently experimental" error.
  - Sources: startdebugging.net (2026-08), https://startdebugging.net/2026/08/how-to-enable-multi-window-support-in-a-flutter-desktop-app/ ; Flutter tracker issue https://github.com/flutter/flutter/issues/30701 (multi-window for desktop shells, still open); umbrella https://github.com/flutter/flutter/issues/142845.
- **What the experimental API adds on `main` only:** regular + dialog + popup windows in
  a single widget tree ("all windows are in a single widget tree… share state without
  additional work"); sized-to-content dialogs, popup/tooltip windows on Win32/Linux,
  platform handles as escape hatch. Material is being wired to use native windows for
  `showDialog`/`showMenu`/`Tooltip` via a `useWindowing` flag on `MaterialApp`.
  - Sources: Flutter blog https://flutter.dev/blog/desktop-windowing-apis (2026-08-24); flutter/flutter PRs #168728 (engine) and #173715 (Win32 regular windows); FlutterCook summary https://fluttercook.github.io/news/flutter-multi-window-desktop-guide/.
- **The official issue cited (`flutter/flutter#30735`)** is the broader lifecycle
  delegation/superset; the actual multi-window tracking issues are #30701 (engine/shells)
  and #142845 (multi view). Helper PR #168728 landed in 3.35 ("Multi-window support (engine)").

So: in **stable**, Flutter still lacks first-class multi-window. Either use a third-party
package or stay on overlays. The experimental surface is explicitly subject to rename
(`preferredSize` → `size` in 3.47 is the template) and retained "ability to change".

## Options

1. **Hold the course (status quo): single window + in-app overlays.** `showDialog` etc.
   already work cross-platform and are what all current dialog tests target.
2. **window_manager ^0.5.x second-window.** Cannot do it: `window_manager` manages one
   native window (size/move/show/hide/decorate/title bar). It does not create a new
   Flutter engine. You need `desktop_multi_window` (or `multi_window_manager` /
   `window_manager_plus` forks) to spawn a second engine window and `window_manager` to
   decorate it — as documented in desktop_multi_window's README.
   - Sources: https://pub.dev/packages/window_manager and
     https://pub.dev/packages/desktop_multi_window ; leanflutter issue #430 (multi-window feature request).
3. **Official Flutter windowing API (`main` + flag).** Gives same-tree state sharing
   (huge upside vs engine-per-window), but is main-channel, feature-gated, breaking
   across patch releases, has no stable availability, and is `@internal` — explicitly
   "do not use in production apps or plugins published to pub.dev". Also lacks mature
   per-window position/bounds APIs and move events as of late 2026 (issue #30701 thread).

## Effort to move dialogs (settings, note-info, confirm-delete, new-note, etc.)

- **State sharing collapses.** With `desktop_multi_window` each new window is a separate
  Flutter engine/isolate, so Sheaf's Riverpod/Bloc/shared prefs/cache do not cross the
  boundary — everything must be serialized via `WindowMethodChannel`/method channels, just
  like isolates. Must rework every dialog to send/receive requests. Note-info dialog (and
  welcome screen) touch note data; settings persists preferences. That is a lot of IPC.
  The official API avoids this (single tree), but forces main channel → not shippable now.
- **App lifecycle/main() dispatch.** Need `if (args.isEmpty) runApp(MainApp()) else
  runApp(DialogApp())` parse of `WindowController.arguments`; main becomes dispatch
  rather than single entry. window_manager's ensureInitialized per sub-window (per the
  example).
- **Plugin registration per engine.** desktop_multi_window requires editing
  `flutter_window.cpp`, macOS runner, Linux runner to call `RegisterPlugins` for each new
  engine — native change in all three runners that Sheaf ships; easy to break and must
  keep up with Flutter upgrades.
- **Theming/branding.** Each sub-window needs its own `MaterialApp`/theme init (no
  inherited theme across engines). Dialog sizing: window_options waitUntilReadyToShow;
  rounded corners, transparency, taskbar entries, modality are ours to reproduce.
- **Window controls/modality.** Real OS modal dialogs are not auto-modal; need
  parent→child focus/stacking management, prevent-close handlers for confirmation
  dialogs, multi-monitor placement, DPI scaling (mixed-DPI). Multi-monitor sadness is
  where desktop window bugs live.
- **Navigation.** `showDialog` returns a future bound to a route; a native window uses
  window close callback + channel, so every `return showDialog<...>` call site becomes
  controller-first. Command palette and context menu inside dialogs complicate further.
- **Hot reload.** desktop_multi_window + multi-engine breaks the nice hot-reload loop
  in practice; secondary windows need manual restart. Dialog definitions duplicated
  between windows or routed by args.
- **Tests.** The existing dialog tests use `tester.showDialog` and pump within one
  widget tree; native windows require integration tests with real windows (or fakes of
  the window controller layer). Significant rework; widget tests become much weaker.

Rough effort: **L–XL** (a multi-week refactor with native runner edits, an IPC layer for
note/settings communication, theme bootstrap per window, and new integration tests), for
a polish item. New windows are currently not a user-facing requirement.

## Risk

- State sync & dead windows: closing parent while a child dialog window is open, orphaned
  windows, duplicate windows, z-order/focus glitches.
- Platform divergence: Linux X11 vs Wayland vs Windows vs macOS windowing semantics;
  Sheaf is Linux-first but also ships Windows/Linux binaries — parity cost. desktop_multi_window supports all three but historically had title bar / file I/O quirks; must pin and validate.
- Dependency fragility: desktop_multi_window requires a fork-pinned window_manager git ref
  (`boyan01/window_manager` @ `6fae92d…`) per its README; Sheaf's pinned 0.5.2 is
  older than the 0.6.x line it expects. Upgrading window_manager means absorbing the
  nativeapi rewrite (synchronous `window.*` API, `Window` objects) — a separate breaking
  change touching shell/window_controls.dart and tests.
- Channel churn: flutter windowing API is still being renamed/changed; `showDialog`'s
  `useWindowing` flag isn't standardized. Adopting early means tracking renames per
  release.
- Multi-monitor/DPI, black-window flash, transparency quirks. Native modal windows can
  feel less "Dart-native" to debug.
- Lost abstraction: `OverlayPortal`/in-app overlays are simpler and already suffice
  for context menus (`flutter_context_menu`).

## Recommendation

**DO NOT RECOMMEND for v0.3.7 — keep in-app overlays.**

Reasons, in order:

1. Stable Flutter still lacks a first-class windowing API (main-channel-only,
   feature-gated, `@internal`, experimental, subject to rename). Not production-ready.
2. The one production-grade route (`desktop_multi_window`) splits the app into separate
   Flutter engines, which is exactly wrong for Sheaf's dialog use case: dialogs must share
   note data, settings state, theme, and context. An IPC layer for every dialog costs
   more than the polish it buys.
3. The payoff is cosmetic (dialogs render as OS windows / escape the window edge) and no
   user-facing requirement demands it; in-app overlays are the common desktop convention
   (VS Code, Obsidian) and already work in tests.
4. Cost/risk are disproportionate: runner edits on 3 platforms, theming bootstrap per
   window, modality & stacking, and rewriting dialog tests, all while absorbing a
   window_manager major-version upgrade.

Revisit only when: (a) Flutter's windowing API reaches stable + Material's `showDialog`
uses it transparently with `useWindowing`, **and** it preserves single-tree state; or (b)
a specific feature (e.g., a detached floating inspector) justifies the cost. Until then,
keep brainstorming under docs/ideas and monitor the tracker issues #30701 / #142845.

## Sources

- window_manager @ pub.dev: https://pub.dev/packages/window_manager
- desktop_multi_window @ pub.dev: https://pub.dev/packages/desktop_multi_window
- Flutter multi-window trackers: https://github.com/flutter/flutter/issues/30701
  and https://github.com/flutter/flutter/issues/142845
- Stable no-public-API walkthrough: https://startdebugging.net/2026/08/how-to-enable-multi-window-support-in-a-flutter-desktop-app/
- Flutter desktop windowing blog: https://flutter.dev/blog/desktop-windowing-apis
- Practical status summary: https://fluttercook.github.io/news/flutter-multi-window-desktop-guide/