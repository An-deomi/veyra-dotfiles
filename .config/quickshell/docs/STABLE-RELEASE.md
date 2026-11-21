# Path to a stable release

What is actually missing before this rice can be called stable, ordered by how much damage each
gap can do. Written after the 2026-11-13 session, so it reflects real failures seen then.

## Blockers — a release would be dishonest without these

1. ~~**A broken singleton takes the whole shell down with no diagnosis.**~~ *Partly closed.*
   `Scripts/system/start_shell.sh` (now launched from autostart) verifies a `quickshell` layer
   exists after startup and otherwise prints the cause, sends a critical notification, shows a
   Hyprland overlay and exits 1. `check.sh` gained a duplicate-handler scan for singletons, which
   is the exact failure that happened. Remaining: an in-shell error surface for the case where
   *some* windows load and others fail — the supervisor only catches "nothing rendered".
2. **No behavioural tests.** The 17 tests cover lock-screen parsing only. Nothing exercises
   settings persistence, theme appliers, the search index, or slot rendering. The cheapest
   high-value additions: prefs round-trip, each theme applier against a fixtures palette, and
   `search_settings.py` against a known query.
3. ~~**Settings writes are not versioned.**~~ *Mostly closed.* Saves now carry
   `schemaVersion: 1`; an unparseable file or one from a newer schema puts the session in a
   read-only state, the corrupt file is moved to `.bak-<ts>` with a critical notification, and the
   write guard sits in the save timer so a save queued before loading cannot slip through.
   Remaining: a real migration path once v2 exists, and parsing the whole file instead of one
   line at a time (the `SplitParser` is why pretty-printing used to be fatal).
4. **Convex and Island can drift apart silently.** They already did: Convex ignored the Island
   surface settings and duplicated the notch geometry. Any new bar feature must land in both, or
   the style switch becomes lossy. Consider one shared `BarSurfaceConfig` rather than per-style
   copies.
5. **Lock screen and power menu are untested end to end.** Both were only reviewed statically.
   A bad suspend command or a broken auth box is release-blocking.

## Should-have

- **Multi-monitor.** Everything assumes a single `eDP-1` (bar style, convex frame, exclusions).
  Decide whether v1 supports multi-monitor and say so in the README.
- **Missing binaries are referenced.** Window rules mention `satty` and `hyprlock`, neither is
  installed; the power menu used `mpc` until this session. Guard rules and menu entries on
  `command -v`, or document the dependencies.
- **Accessibility.** Font scale exists; there is no reduce-motion switch (animations are spread
  across `Constants.anim*`) and no high-contrast variant.
- **Idle cost baseline.** Record CPU/RSS with the bar idle and with music playing, then keep it as
  a regression check. Samplers that only run when visible (net speed, CAVA) should stay that way.
- **Rollback for theme changes.** Appliers overwrite files in place. Back up first and offer a
  "revert last theme" action.
- **Error surface for scripts.** `Process` failures are mostly ignored; a failed theme apply is
  invisible. Collect them into one status area in Settings.

## Nice-to-have

- Per-monitor bar layout and widget slots.
- Search that jumps to and highlights the matched control (today it opens the page).
- Settings sync/export, so a rice can be shared without copying JSON.
- A single `VERSION` file plus changelog and a `git tag` based release flow.

## Definition of done for "stable"

- [ ] `check.sh` green **and** a smoke test that boots the shell and asserts every expected
      surface exists (bar, launcher, control centre, lock screen).
- [ ] Settings prefs survive a malformed file, a partial write, and an upgrade.
- [ ] Both bar styles expose the same settings surface.
- [ ] Lock screen, suspend and resume exercised on real hardware.
- [ ] Documented dependencies with a `command -v` check at startup.
- [ ] README with screenshots, keybind list, and the multi-monitor statement.
