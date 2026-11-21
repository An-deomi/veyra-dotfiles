pragma Singleton
import Quickshell
import QtQuick

QtObject {
    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (homeDir + "/.config")
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || (homeDir + "/.cache")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (homeDir + "/.local/state")
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || (homeDir + "/.local/share")
    readonly property string picturesDir: Quickshell.env("XDG_PICTURES_DIR") || (homeDir + "/Pictures")
    // The opt-in safe test mode keeps shell testing from changing host settings.
    readonly property bool safeTestMode: Quickshell.env("VEYRA_SAFE_TEST") === "1"

    // Keep the existing Veyra/Quickshell directory names while honoring XDG overrides.
    readonly property string configDir: configHome + "/quickshell"
    readonly property string cacheDir: cacheHome + "/quickshell"
    readonly property string stateDir: stateHome + "/veyra"
    // User-generated, wallpaper-colored copies of the shipped SVG icons.
    readonly property string dataDir: dataHome + "/veyra"

    // Print a persistent state file, migrating it out of the legacy cache dir
    // on first use so a cache cleaner can no longer wipe user settings.
    // Args: 1 = destination path, 2 = legacy cache path, 3 = fallback text
    // (optional). Exits 1 when the file is absent and no fallback is given,
    // matching the previous "cat" behavior.
    readonly property string migrateCatSnippet:
        "f=\"$1\"; o=\"$2\"; " +
        "if [ ! -e \"$f\" ] && [ -e \"$o\" ]; then mkdir -p \"$(dirname \"$f\")\"; mv -- \"$o\" \"$f\"; fi; " +
        "if [ -e \"$f\" ]; then cat -- \"$f\"; elif [ \"$#\" -ge 3 ]; then printf '%s' \"$3\"; fi"
}
