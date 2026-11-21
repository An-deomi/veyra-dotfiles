# Veyra code review — findings and triage

> Session log for 2026-11-13 (every file touched, why, verification, and open gaps):
> [`HANDOFF-2026-11-13.md`](HANDOFF-2026-11-13.md).

Reviewed: the whole Quickshell tree (219 QML files, 69 Python files, shell scripts) and the
Hyprland Lua config (`~/.config/hypr`). Method: automated checks (`./scripts/check.sh`,
`qmllint`, `luac5.4`, `bash -n`) plus targeted line-by-line review of services, scripts and
logic-heavy modules. Findings were triaged into **fixed** (committed) and **deferred**
(below; mostly robustness/UX notes, not correctness bugs). None of the fixes were exercised
in a live session yet — test with `./scripts/run-safe-test.sh` (or `qs log` output) before
driving this on a daily session.

Everything in "Fixed" is one commit per fix on branch `main`. The Hyprland config is **not**
a git repository yet, so those fixes exist only in the working tree.

## Fixed — security and correctness

| Commit | Issue |
| ------ | ----- |
| `ed74013` | `grayscale` template filter produced near-black output (missing `* 255`). |
| `816717e` | Corrupt `colorscheme.json` crashed `apply_theme.py` via `get_brightness()` (`int(x, 16)` unguarded). |
| `7dbc723` | `gtk.py` silently unlinked the user's `gtk.css` symlink; now renamed aside to `.veyra-backup` first. |
| `550c811` | Unguarded `json.load` of the colorscheme cache killed theme application; now a clean diagnostic + no-op. |
| `14dc450` | `app_theme_manager._write_text` raced on a fixed temp name and never fsynced; `_restore_tree` crashed `rmtree` on symlinks (half-restored themes). |
| `0ecdf80` | `todo.py` passed the task list as argv (visible in `/proc`) and trace-dashed on bad JSON; now stdin + parse-error object. QML caller updated. |
| `1069388` | `clipboard_pins.py` took the snippet as argv and hardcoded the share path; now stdin + `XDG_DATA_HOME`. (File is unused — see Deferred.) |
| `093c20d` | `write_colorscheme.py` hardcoded `~/.local/state/veyra`; writer and readers diverged under `XDG_STATE_HOME`. |
| `e3a6dad` | **CRITICAL**: `qs ipc call lockScreen unlock` unlocked the session with no authentication. IPC now only locks; unlocking requires PAM. Also: 10 s timeout around `auth.py` (a hung PAM module used to freeze unlocking forever) and password passed via `onStarted` stdin. |
| `36c119a` | Wi-Fi PSK passed as argv by QML → world-readable `/proc/<pid>/cmdline`. Now QML → wifi.py over stdin, and secrets persist to NM over D-Bus (`connection.modify`/`AddConnection`) with nmcli argv only as fallback. |
| `def1879` | Predictable `/tmp/ocr_temp_<ts>.png` and `/tmp/quickshell-record.log` (symlink attacks). Now `mktemp`/`$XDG_RUNTIME_DIR`. |
| `5e05dd7` | Desktop CAVA visualizer sampled with hardcoded `/36`; now scales by `desktopCavaBarCount`. |
| `7ded4f2` | Keybinds Manager allowed CR/LF in shortcut names → arbitrary Lua injection into `keybinds_custom.lua` on reload. Now rejected; comment emission strips control chars. |
| `1ea22b8` | `Workspaces.qml` crashed on compositor reconnect (`Hyprland.workspaces` null); guarded. |
| `dc5b2f5` | Wallpaper list wiped spuriously when `find` failed; exit code is now checked and ` PIPESTATUS`-distinguished empty dirs from failures. |
| `c3bfc12` | **CRITICAL**: clipboard image cache used predictable world-writable `/tmp/quickshell-clipboard` with a shell loop built from cliphist ids. Now private `$XDG_CACHE_HOME/quickshell/clipboard-images` (0700), fixed Python decoder (0600), numeric-id validation, no shell. |
| `a8c610d` | `CavaService` destroyed its `running` binding from the watchdog (audio capture never stopped); now imperative, plus `sh -c` wrapper dropped. |
| `9cc409d` | `WallpaperManager.wallpaperSaveProc` never enabled stdin → every wallpaper save wiped `current_wallpaper`. |
| `8b836e8` | `Mpris.Playing` does not exist; comparison was dead code. Now `MprisPlaybackState.Playing`. |
| `86533f1` | Settings load failure overwrote the user's `settings_prefs.json` with defaults. Now: never auto-save on failure, and an unparseable file is moved to `.bak-<ts>` instead of silently replaced. |
| `c48d435` | `mouseAccelProfile` interpolated into `hyprctl eval` single-quoted Lua (injection via user config; silent breakage for quotes/backslashes). Now allowlisted (`flat/adaptive/custom`) in QML and quotes/backslashes rejected in `update_hypr_prefs.py`. |

### Fixed outside git

- `hypr/modules/windowrules.lua:103` — `float = true` moved out of the `match` table (Wine
  windows were never made to float).
- `hypr/alt-tab/shell.qml` — removed unused `Quickshell.Widgets` import.
- `hypr/hyprland.lua` — `pcall(require, "keybinds_custom")` no longer swallows real load
  errors (still silent when the file is simply absent).
- `hypr/scripts/brightness.sh` — unreadable brightness no longer makes the regex tests crash.

## Deferred — needs your decision

- `hypr/modules/windowrules.lua:52` — `initial_title = "negative:^(.*\\\\home\\\\.*)$"` matches
  literal backslashes; on Linux paths contain `/`, so this negative filter likely never
  excludes what it was meant to. Intent?
- `hypr/hypridle.conf` — `ignore_dbus_inhibit = true` locks/suspends even during inhibited
  workloads (video). Confirm intentional.
- `Modules/Clipboard` — `Scripts/system/clipboard_pins.py` appears to be dead code (live
  pins go through `ClipboardService.qml` + `save_pins.py`). Keep (now stdin-safe) or delete?
- Core review: `Theme.qml` failure paths (generator exit non-zero = stale theme forever;
  failed theme never logged), `FileView watchChanges` re-arming on atomic-rename replaced
  files, `AudioService` `pactl subscribe` never restarts, several service processes fail
  silently (no `onExited`/stderr logging: `HyprlandService` apply procs, `SettingsService`
  github-token save in the user-initiated path). All robustness, not correctness bugs.
- `WallpaperManager.qml:148` — `wallpaperLoader` uses bare `cat` with no failure log.
- `NotificationService` quiet-hours can apply up to 30 s late (minor).
- `NetSpeedService`/`SystemStats` restart timers lack backoff (crash-looping sampler).
- Qt6 `qmllint` reports no syntax errors but plenty of "uncreatable type" and unused-import
  notes elsewhere; not run in CI yet.

## Deferred — quality / consistency (highest value first)

**Security-adjacent**
- Notification icons / `trackArtUrl` hand untrusted IPC data to `Image` incl. remote
  `http(s)://` — allowlist `file://` / icon names or gate behind a setting.
- `custom_template_manager.expand_path` lets third-party templates overwrite any dotfile
  under `$HOME`; consider restricting to XDG config/data/state/cache roots.
- `image_utils.py` — GIF frame cache key is `basename + ".jpg"`; same-named wallpapers
  collide (serve stale frames). Hash the full path. `nvim.py` — checks `/tmp` nvim sockets
  without ownership check.
- `matugen_palette.py` — validate accent is hex before passing into matugen argv.

**Config corruption / data safety**
- Appliers rewrite user configs non-atomically with no backup (`gtk.css`/`settings.ini`/
  `kitty.conf`/`colors.local.lua` etc.) while sibling modules use `atomic_write_text` —
  reuse it and snapshot originals like the spicetify/vscode appliers.
- `svg_assets.py` rewrites repo-shipped `assets/*.svg` on every theme change (dirties git);
  plus its `re.sub` replacement is unescaped. Generate into `$XDG_DATA_HOME/veyra/assets`.
- `btop.py` — `os.system(f"sed -i ...")` breaks on quotes in `$HOME`; use regex+atomic write.
- `app_theme_manager` — Zen `userChrome.css`/`user.js` edited without backup snapshot.
- `kcolorscheme.py` — `kwriteconfig6` without existence check; `get_system_info.py` —
  `shell=True` pipeline, reports "0 packages" on non-Arch; `fetch_weather.py` — shared
  fixed `.tmp` name; `apply_cursor.py`/`apply_font.py` — raw tracebacks on missing helper.
- `qt.py`/`kitty.py` — `configparser.read()` without encoding; kitty maps srgb 0–15 all to
  accent (stylistic); `kcolorscheme`/`matugen` as above; `nvim.py` socket check.
- `ThemedShadow.qml` — `spread` fed a Hyprland 1–5 integer into a 0–1 factor; unused
  Qt5Compat import. `SvgIcon.qml`/`Card.qml` — dead `clicked` signals.
  `IslandOverlayStyle.qml` — duplicated identical ternary branches.

**Duplication / polish**
- `parsedNotif` WhatsApp heuristic duplicated across `NotificationItemDelegate.qml` and
  `Notifications/NotificationDelegateContent.qml`; `hideWidget()` duplicated 3×; kill the
  dead "graphical effects" imports etc.
- `NotificationCenter.qml` — 900 ms full-history rebuild poll; use model signals.
- `AuthBox.qml` — clear-password MouseArea permanently shadowed by the overlay TextField.
- `WifiControl.qml` — radio tile pre-flips `isActive` with no reconciliation on failure.
- `ClipboardContent.qml` — `currentIndex` used without upper-bound check after model shrink.
- `PowerMenuContent.qml` — suspend mutes `Master` but never unmutes on resume.
- `KeybindsCheatSheet.qml` — skip binds with empty `keys` arrays.
- `NotificationProgressBar.qml` — NaN progress → NaN width. `OsdProgressBar.qml` shows the
  correct pattern.
- `WallpaperManager.qml` — duplicate `running = false` lines (fixed already elsewhere).
- `CavaService` — now imperative; Desktop CAVA `/36` (fixed) — same pattern audit done.
- `HyprlandService.qml:217,648` — dead `changeLayoutProc` spawns with command `["true"]`.
- `HyprlandService.qml:733` — `activeLayoutProc` can drop updates during rapid switches.

**Housekeeping before GitHub**
- ✅ `LICENSE` (MIT) and local git repo added; `__pycache__`/`.pyc` purged and ignored;
  `hotspot_backend.json` stays ignored. Initial commit `cb335bc`.
- Consider `.github/workflows/check.sh` CI, installation/README notes (dependencies:
  quickshell, hyprland 0.57+, matugen, awww, qs), and whether `~/.config/hypr` gets its own
  repo.
- `emoji/emoji-test.txt` is Unicode consortium data; keep its copyright header.

## Follow-up pass — implemented after triage

- Chrome tokens (`Core/Components/Chrome.qml`) + `ThemedShadow` spread normalization — `a7f0fc3`, `d4e8b83`.
- OSD unification (`EventToast.qml`, accent progress track, fixed-width capsule) — `e3625b3`.
- Design system (`docs/DESIGN.md`) and wallpaper-tracking alt-tab palette — outside this repo for the latter (hypr is not versioned yet).

Still open: the icon-application write path in `svg_assets.py` (repo assets recolored in place —
this is why `assets/*.svg` shows as perpetually modified), and converging more modules onto
`Chrome`/`DESIGN.md` tokens.

## Verification still owed

Live-session checks: lock/unlock flow, Wi-Fi connect (new + saved profile), settings-load
failure injection, wallpaper apply, clipboard images, theme apply end-to-end, keybinds
manager save, CAVA visualizer with non-default bar counts. Run `./scripts/check.sh` after
every future change; it is static-only.

## Polish pass — 2026-11-13 (uncommitted)

Scope: finish the in-flight OSD restyle, clear the deferred polish bugs, one Hyprland
config pass, and a live visual check. `~/config` and `~/.config` were byte-identical when
this started; edits were mirrored into `~/.config` so the running session loads them.

Verified with `./scripts/check.sh` (17 tests, 221 QML, 70 Python, 3 JSON, 129 SVG — green),
a live `qs` restart (0 warnings, 0 reference errors, was 84 log lines), and screenshots of
the volume toast, workspace toast and Control Center. The lock screen was **not** exercised
(it would end the session).

| Area | Change |
| ---- | ------ |
| `Core/XdgPaths.qml` | `dataHome` was never defined, so `dataDir` was `undefined` and every icon resolved to `file:///assets/…`. Added the `XDG_DATA_HOME` → `~/.local/share` fallback. |
| `Scripts/theme/theme_appliers/svg_assets.py` | Mirrors all 129 shipped icons into the data dir; recoloring only the 3 gradient icons left the rest failing first (73 warnings/start, then a second load). |
| `Modules/Bar/Components/EventToast.qml` | Width was pinned at 200 while the row's preferred widths summed ~247, so two `fillWidth` children fought and elided early. Now content-measured and clamped to 132–280; one flexible title; progress line inset 10 px and 2 px off the bottom edge to clear the capsule radius. |
| `Modules/Notifications/Components/NotificationProgressBar.qml` | NaN/out-of-range `progress` propagated into the width; now clamped with `Number.isFinite`, plus the width `Behavior` `OsdProgressBar` already had. |
| `Modules/LockScreen/Components/AuthBox.qml` | Click-to-clear sat under the full-size invisible `TextField` and never fired. Moved above it, below the content layout so the submit button stays clickable. |
| `Modules/PowerMenu/PowerMenuContent.qml` | Suspend muted `Master` and never unmuted (and used `mpc`, which is not installed). Now uses `wpctl`/`playerctl` and restores the previous mute state after resume. |
| `Core/Services/HyprlandService.qml` | Removed `changeLayoutProc` and `startupApplyTimer`, whose only effect was spawning `/usr/bin/true`. |
| `hypr/modules/windowrules.lua` | Removed the Discord rule that matched `^(vesktop\|discord)$` and applied no action. |

### Found but deliberately not changed

- **`keyboardLayout` never applies.** `onKeyboardLayoutChanged` only saves settings; nothing in
  the tree calls `hyprctl switchxkblayout`, so a layout change needs a re-login. The old
  no-op proc masked this. Needs a decision (apply live vs. label it restart-required).
- `hypr/hyprtoolkit.conf` still hardcodes a gold palette (`accent c9a554`) while the live
  palette is blue (`65a5cc`). Nothing in the theme engine writes it.
- `windowrules.lua:52` `initial_title = "negative:^(.*\\\\home\\\\.*)$"` — intent still unclear;
  it does match Wine-style `\home\` paths, so the earlier "never matches" note may be wrong.
- `KeybindsCheatSheet` empty-`keys` and `ClipboardContent.currentIndex`: re-read both. The
  clipboard handlers already bound-check `filteredModel.count`, and the empty-keys path
  depends on `parse_keybinds.py` output, so neither was changed blind.

## Convex style + Settings chrome pass — 2026-11-13 (uncommitted)

### Convex: what was actually wrong

Traced `ConvexShape.getPath()` against a clean screenshot rather than eyeballing upscales.

- **The bar floated 8 px below the screen edge.** `topBezel` was `Constants.sizeXs` (8) and is
  applied to the notches *and* to every "bridge" segment between them, so the bar's whole top
  edge sat at y=8 with wallpaper showing above it — except two 8 px slivers at the far left and
  right, which still reached y=0. That asymmetry is the tell that it was a bug, not a design.
  Default is now 0 (flush) and it is a setting.
- **Geometry was duplicated.** `ConvexBar` built the path with its own flare constants while
  `ConvexCenter` computed the notch's content width from a second hardcoded copy
  (`sizeLg + 2`). Changing one without the other would misalign the content from its notch.
  Both now read `convexNotchFlare`.
- **Nothing about the style was configurable.** Height, corner radius, flare, opacity, border,
  shadow and the screen frame were all literals, and `BarStyleConfig.barHeight("convex")`
  returned a hardcoded 40 while the Island equivalent already read `islandHeight`. The style
  also ignored the Island surface settings entirely, so switching styles silently changed
  opacity/border/shadow behaviour.
- `island` was also affected: `BarStyleConfig.barHeight("island")` hardcoded 32.

### Settings added (SettingsService + Shell page → "Convex Bar Shape / Surface / Screen Frame")

`convexBarHeight` 28–56 · `convexTopInset` 0–12 · `convexCornerRadius` 0–24 ·
`convexNotchFlare` 0–32 · `convexBackdropBlur` · `convexBackgroundOpacity` 30–100 % ·
`convexBorderEnabled` / `convexBorderWidth` / `convexBorderColorMode` ·
`convexShadowEnabled` · `convexFrameEnabled` / `convexFrameSize` 0–16.

All twelve are clamped on load, saved through the same single-line JSON path as the rest of the
prefs, and the three groups only appear while Convex is the active style. Verified live by
writing a temp prefs file (height 48, inset 6, radius 6, flare 24, border 2 px, frame off) and
screenshotting: every value visibly changed, then the prefs were restored.

Gotcha for future scripted edits: `settings_prefs.json` is parsed **one line at a time** by a
`SplitParser`, so it must be written with `json.dumps(...)` and no indentation. Pretty-printing
it produces 178 `JSON.parse` errors and the defaults silently win.

### Not fixed (deliberately)

- Convex still hardcodes its section contents: `BarLeftSection` always renders the Veyra button +
  workspaces, and the right side is a fixed recording/control-center/tray set. The `barSlotL1..R3`
  preferences exist and `BarCenterContent` consumes them, but Convex bypasses that component and
  no UI exposes the slots anywhere. Wiring them means reworking `BarLeftSection`/`BarRightSection`.
- `ConvexCenter.expandedW/H` fall back to 240×380 when the panel reports zero implicit size.
- With `convexTopInset > 0` the bar genuinely floats and shows wallpaper above it — that is the
  setting's meaning now, not an accident.

### Settings app chrome

The pages were full-bleed: at the 1498 px float size each card's label sat ~700 px from its
control. Fixes, all in shared components so every page benefits:

- `AppContainer` bounds the content column to `maxContentWidth` (900) and centres it.
- `AppGroup` gained a single `rowGap` (20 px) used by both the layout and the divider repeater,
  so dividers can no longer drift from their rows.
- The `^Veyra Settings$` window rule opens the window at 0.64×0.80 of the monitor instead of
  0.78×0.82, which was larger than the app's own `maximumSize` anyway.
