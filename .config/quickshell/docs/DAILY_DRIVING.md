# Daily-driving optimization notes

This pass focuses on reducing idle work and making power-profile changes safer while preserving both Island and Convex bar styles.

## Defaults and behavior

- The code default is **Island**. Existing user preferences remain respected; a saved `barStyle` value still wins over the default.
- Adaptive Power is enabled by default. After saved settings load, and with `power-profiles-daemon` available and a battery detected, Veyra requests `power-saver` on battery and `balanced` on AC power. This avoids overriding a saved manual profile during startup.
- Game Mode temporarily takes control of the performance profile. It records the previous valid profile under the user's runtime directory, then restores that profile when Game Mode ends. If no valid restore point exists, it does not guess a replacement.
- Choosing a profile manually in Power & Battery disables Adaptive Power so the manual choice is not immediately overwritten.

## Idle-work changes

- Lock-screen CPU, memory and uptime values use `Scripts/system/get_lock_stats.py`, which reads `/proc` directly. It does not enumerate processes or query NVIDIA.
- The lock-screen sampler starts only while the session is locked and stops after unlock.
- Detailed System Monitor telemetry remains a separate, on-demand feature.
- Island brightness polling is reduced from 700 ms to 1500 ms and pauses while the Island bar is not selected or Game Mode is active.
- Network speed sampling runs only in Island mode and pauses during Game Mode; it restarts safely if its helper exits unexpectedly.
- CAVA runs only when the desktop visualizer is enabled or the music widget is open, and stops during Game Mode or Power Saver.
- Game Mode status polling is reduced from 5 seconds to 8 seconds to retain responsive auto-detection.
- Bar content and Convex panels are loaded through visibility-bound loaders; GamingBar is loaded only in Game Mode.

## Safety and maintenance

- Game Mode state is stored in a per-user private runtime directory, written atomically with restrictive permissions, and validated before restoration. A valid legacy restore point is migrated only when the current profile indicates Game Mode is still active.
- Authentication reads the password from stdin only; it no longer accepts a password argument.
- The settings loader validates saved power-profile and bar-style values rather than accepting arbitrary strings.
- `scripts/check.sh` runs the Python tests, Python syntax checks, shell syntax checks, and JSON/SVG validation. It runs `qmllint` when available.

## Validation limits

The automated checks do not replace a live Quickshell session. QML behavior, bar switching, focus handling, screen locking, UPower transitions, Game Mode restoration on the target machine, and GPU wake behavior must still be tested on the actual CachyOS/Hyprland installation.


## Media visualizer separation

The compact Island/Convex bar visualizer now has its own `barMediaVisualizerEnabled` preference. The desktop overlay remains controlled independently by `desktopCavaEnabled`. `CavaService` runs one shared CAVA process only while playback is active, power/game policy allows it, and at least one consumer (bar capsule, desktop overlay, or open Music widget) needs audio data. The safe-test profile enables the bar visualizer while keeping the desktop overlay disabled, so this separation is exercised without drawing a desktop overlay.

### Safe-test clipboard isolation (v8)

The safe-test launcher now starts its own text and image `wl-paste --watch cliphist store`
processes after setting the temporary XDG directories. This is necessary because clipboard
watchers are commonly started by the user's Hyprland/autostart configuration and therefore
write into the normal cache, while the safe-test shell reads `cliphist list` from its isolated
cache. The launcher tracks and stops only the watcher processes it created. Test clipboard
history is temporary and removed when the safe-test session exits; the user's normal clipboard
history and watchers are not modified.

### Battery health dashboard (v10)

- The Control Center Battery page reads optional hardware details on demand when the page opens or when Refresh is pressed; it does not add a periodic polling loop.
- Kernel power-supply sysfs remains the preferred source for voltage, temperature, cycle count, model, and design/full capacity.
- The one-shot reader now falls back to `upower -i` for properties omitted by some laptop firmware/kernel drivers, especially `energy-full-design`, UPower capacity/health, charge cycles, voltage, temperature, vendor, and model.
- Battery health is displayed from UPower when available, otherwise estimated from full-charge capacity versus original design capacity. Missing fields remain unavailable rather than being guessed.
- Reader errors are surfaced in the panel so an empty hardware section is easier to diagnose.


### Battery page live power metrics and adaptive effects

- The Control Center battery details grid shows live power rate/draw from UPower (`changeRate`) and the state-appropriate estimate (`timeToFull` while charging, `timeToEmpty` while discharging), alongside voltage and battery model.
- Adaptive Power reconciles the power profile after each existing power-profile query as well as on UPower source-change events, so a missed AC/battery transition signal does not leave the session in Power Saver indefinitely.
- Power Saver applies blur/shadow reductions directly to the live Hyprland configuration with `hyprctl eval`. Temporary power-saving values are not written into the user's saved Hyprland preferences; returning to AC restores the configured blur/shadow values.
