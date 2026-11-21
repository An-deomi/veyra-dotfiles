# Veyra Quickshell configuration

Veyra is a Quickshell desktop shell configuration targeting Hyprland on Arch-based Linux systems.

## Daily-driving optimization pass

See [`docs/DAILY_DRIVING.md`](docs/DAILY_DRIVING.md) for the changes in this build, adaptive power behavior, and validation limitations.

## Checks

Run the static checks and unit tests with:

```bash
./scripts/check.sh
```

`qmllint` is optional and is run when installed. A real Quickshell session is still required to validate visual behavior and desktop integration.

## Safe live test

To test the shell without writing its settings into your normal XDG folders or applying
system font, cursor, power-profile, Game Mode, Hyprland, theme, or wallpaper changes:

1. Stop the currently running Quickshell instance so the two bars do not overlap.
2. Run `./scripts/run-safe-test.sh` from this directory.
3. Exit the test shell with `Ctrl+C`. The temporary test state is removed automatically.
4. Restart your normal shell with `qs --path ~/.config/quickshell/shell.qml`.

The safe test still uses the current Wayland/Hyprland session and real audio/brightness
hardware. Avoid testing controls that deliberately change those devices in this mode.

## Local configuration

`hotspot_backend.json.example` is a template for machine-specific hotspot interface settings. Copy it to `hotspot_backend.json` and configure the interfaces for the local system; do not share machine-specific values in public archives.
