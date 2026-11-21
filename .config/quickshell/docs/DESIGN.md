# Veyra design system

Practical rules for the Quickshell shell. New components should consume
`qs.Core.Components.Chrome` and `Constants` instead of inventing values.

## Tokens

Radii: `radiusSm 8` · `radiusMd 12` · `radiusLg 16` · `radiusXl 22`
Borders: `Chrome.borderColor` (= theme `border`), width `Chrome.borderWidth`
Focus ring: `Chrome.focusRingWidth` in `Theme.accent`
Hover/selected tints: `Chrome.accentTint` (14%), `Chrome.accentTintStrong` (28%)
Attention tint: `Chrome.attentionTint`, `Chrome.attention` (complementary)
Elevation: `Theme.shadow`, blur from `HyprlandService.hyprShadowRange`;
`RectangularShadow.spread` must stay normalized to 0..1 (see `ThemedShadow`).
Motion: strengths via `Constants.anim*` (UltraFast 100 → Expressive 500);
the `durationFactor` scales them for reduced animation/Game Mode.

## Accent discipline

- `Theme.accent` — interactive elements only: selection, focus, primary action,
  progress fill, active toggle, links.
- `Theme.accentComplementary` — attention/secondary emphasis, and only one such
  focal point per screen (e.g. auth failure, low battery health, paused recording).
- Everything else is `fg` / `muted` / `border`. Do not decorate with accents.
- Error semantics ride on `attention` until a dedicated danger token exists.

## OSD contract (volume / mic / brightness / media / recording / workspace)

- One renderer: `Modules/Bar/Components/EventToast.qml` fed by
  `IslandEventService` — icon + `Title  value` (11/12px ramp, `DemiBold`),
  plus a 150px accent progress track when `eventPercent >= 0`.
- Capsule is fixed-width; no layout jumps between events.
- Dwell ≈ 1.4–1.5 s, fade in/out with `animFast`/OutCubic.
- Sound-capable OSD types (volume/brightness) are silent by design; there is
  no double libnotify path.

## Surfaces

- 1 background level (`Theme.bg`), 2 card levels (`bgSecondary`, `bgTertiary`),
  1 accent overlay (`bgAccent`).
- Shell windows on Hyprland get blur via layer rules
  (`hypr/modules/effects.lua`): `ignore_alpha 0.12`, vibrancy tuned by the
  wallpaper; surfaces should never be flat opaque blocks.

## Typography

- Geist everywhere (`Constants.fontFamily`).
- Ramp: 12 (labels) · 14–16 (body) · 20+ (hero). Tabular numerics for clock,
  battery, speed readouts.
- One weight axis: 400 / 600 / 700; nothing lighter on dark glass.

## Icons

- Custom stroke set in `assets/*.svg`: stroke ≈ 1.5, uniform cap/join rounding,
  single fg/muted tone; theme service recolors gradients only via
  `svg_assets.py` (accent/complementary stops).
- New icons follow the same stroke and corner language; no filled silhouettes
  next to stroked ones.

## Contrast

- `muted` must hold ≥ 4.5:1 against `Theme.bg` for any text meant to be read;
  decorative-only text may go dimmer. If a wallpaper yields a bad palette,
  `ColorUtils.ensureContrast()` is the correct tool — do not hand-pick fixes.

## Checklist for new components

1. Chrome tokens for radii/borders/tints — no literal hexes.
2. Focus state visible (ring or accent border).
3. Uses `Constants.anim*` durations; honors `durationFactor`.
4. Keyboard path exists or the control is pointer-only by design.
5. Percent/progress uses the accent track pattern from `EventToast`.
