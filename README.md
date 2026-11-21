# Veyra Dotfiles

A wallpaper-driven **Hyprland 0.57+ (Lua)** and **Quickshell** desktop rice (**Veyra**) for Arch Linux / CachyOS, built upon and customized from [**t4lentles5/minflair**](https://github.com/t4lentles5/minflair).

## Highlights

- **Adaptive Wallpaper Palette**: Extracts dark/light Material + accent palettes from your active wallpaper (`awww` + `matugen`) and updates Hyprland, Quickshell, Kitty, Fastfetch, Starship, GTK 3/4, Qt, Spicetify (`marketplace`), and Discord/Vesktop (`veyra.theme.css`).
- **Dynamic Island, Convex & Gaming Bar Styles**:
  - **Rotating Two-Color Gradient Borders** (`Theme.accent` ↔ `Theme.accentComplementary`) on Island capsules, expanded Island popups, and the connected Convex bar + screen frame bezel.
  - Live **Island Overview** (`SUPER + Tab`) with `ScreencopyView` window thumbnails per workspace and an inline system tray.
  - **Focus / Pomodoro Timer** (`25m Focus`, `5m Break`, `15m Long`) inside the Island Clock popup.
  - **Quick-Note Pad** inside the Dashboard (`CTRL + ALT + D`) with auto-save and one-click copy.
  - **Auto-Hide on Gaming Workspace** (`SUPER + G`).
  - Cursor-origin `awww` wallpaper grow transitions, album art media toasts, and keyboard-layout OSDs.
- **Native GLSL ES 3.00 Screen Shaders**: Toggle/cycle `Vibrance`, `Film Grain`, `CRT`, and `Warm` shaders via `SUPER + ALT + H` or Veyra Settings.
- **Compositor Customization Studio** (`SUPER + Z`): Live controls for **Accent Window Glow** (toggle, primary/secondary accent color, opacity, range, falloff), **Hyprland Animations** (curve, window open/close style, workspace transition style, speed scaling, rotating border spin, layer pop-ins), and **Lock Screen** clock layouts & font weights.
- **Laptop Eco & Idle Rules**: Automatic battery vs AC rules to drop blur passes / pause border spin / gently dim on unplug and restore full visuals on AC, plus `hypridle` screen dimming and battery-aware suspend.
- **UI Sound Effects**: Subtle audio cues on screenshots, recording start/stop, charger plug/unplug, lock/unlock, and Pomodoro completion.

---

## Keybinds

| Shortcut | Action |
|---|---|
| `SUPER + Space` | App Launcher (`=math`, `:emoji`, `!g`, `!yt`, `!ddg`, `!gh`, `!aw`, `cb`, `>cmd`) |
| `SUPER + Tab` | Live Island Overview (workspace window thumbnails + tray) |
| `SUPER + SHIFT + Tab` | Cycle windows |
| `SUPER + \`` | Toggle dropdown Kitty scratchpad |
| `SUPER + T` / `SUPER + SHIFT + T` | Open Kitty / floating Kitty |
| `SUPER + E` | File manager |
| `SUPER + Return` | Code editor |
| `SUPER + W` | Browser |
| `SUPER + Q` | Close active window |
| `SUPER + F` / `SUPER + D` | Fullscreen / Maximize |
| `SUPER + ALT + Space` | Toggle floating |
| `SUPER + G` | Switch to Gaming workspace (hides top bar) |
| `SUPER + Z` | Veyra Settings |
| `SUPER + K` | Keybinds Manager |
| `SUPER + X` | Control Center |
| `SUPER + V` | Clipboard History |
| `SUPER + A` | Notifications Center |
| `SUPER + SHIFT + W` | Wallpaper Selector |
| `SUPER + ALT + S` / `Print` | Screenshot Widget (`Shift+Print` monitor, `Ctrl+Print` silent) |
| `SUPER + ALT + N` | Toggle Night Light (`hyprsunset`) |
| `SUPER + ALT + H` | Cycle GLSL Screen Shader |
| `SUPER + L` | Lock Screen |
| `SUPER + ALT + C` | Power Menu |
| `SUPER + R` | Restart Quickshell |
| `CTRL + ALT + D` | Dashboard (Updates, Quick Note, Quote) |
| `3-finger swipe` (left/right) | Switch workspaces |

---

## Directory Layout

```text
dotfiles/
├── .config/
│   ├── hypr/          # Hyprland 0.57+ Lua modules, animations, rice extras, GLSL shaders, hypridle
│   ├── quickshell/    # Veyra shell (Bar/Island, Launcher, LockScreen, Settings, Theme engine)
│   ├── kitty/         # Kitty terminal config
│   ├── fastfetch/     # Fastfetch layout (dynamically colored from wallpaper)
│   ├── starship/      # Starship prompt config using [palettes.quickshell]
│   └── fish/          # Fish shell config
├── .local/share/veyra/
│   └── custom_templates/  # Fastfetch, Foot, and Discord/Vesktop palette templates
├── LICENSE
└── README.md
```

---

## Installation

### Dependencies
- **Core:** `hyprland` (0.57+ with Lua config), `quickshell`, `awww`, `matugen`, `python`, `jq`
- **Utilities:** `kitty`, `fastfetch`, `starship`, `fish`, `grim`, `slurp`, `wl-clipboard`, `cliphist`, `brightnessctl`, `hypridle`, `hyprsunset`, `hyprpicker`, `pipewire` (`pw-play` / `wpctl`), `cava`
- **Fonts & Cursors:** `Geist`, `JetBrainsMono Nerd Font`, `Bibata-Modern-Ice`

### Setup
```bash
git clone https://github.com/An-deomi/veyra-dotfiles.git ~/dotfiles

# Back up any existing configs before copying or stowing
mkdir -p ~/.config ~/.local/share/veyra
cp -r ~/dotfiles/.config/* ~/.config/
cp -r ~/dotfiles/.local/share/veyra/* ~/.local/share/veyra/

# Symlink Starship config & copy example local overrides
ln -sf ~/.config/starship/starship.toml ~/.config/starship.toml
cp ~/.config/hypr/examples/userprefs.local.lua.example ~/.config/hypr/userprefs.local.lua
cp ~/.config/quickshell/hotspot_backend.json.example ~/.config/quickshell/hotspot_backend.json

# Generate initial dynamic palette from your wallpaper
python3 ~/.config/quickshell/Scripts/theme/apply_theme.py
```

---

## Credits

- Based on [**MinFlair**](https://github.com/t4lentles5/minflair) by [**@t4lentles5**](https://github.com/t4lentles5) — thank you for the original modular Hyprland + Quickshell foundation.
- Modified, extended, and maintained as **Veyra** by [**@An-deomi**](https://github.com/An-deomi).

## License

GNU General Public License v3.0 (GPL-3.0) — see [LICENSE](LICENSE), matching upstream [t4lentles5/minflair](https://github.com/t4lentles5/minflair).
