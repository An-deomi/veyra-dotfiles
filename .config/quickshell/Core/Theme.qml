import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Services
import qs.Core.Utils
pragma Singleton

QtObject {
    id: root

    property var themes: [{
        "name": "Default",
        "dark": {
            "name": "Default",
            "bg": '#030107',
            "fg": '#d1d1d1',
            "accent": '#a77ef5',
            "accentComplementary": '#f57eb6'
        },
        "light": {
            "name": "Default Light",
            "bg": '#e8dbff',
            "fg": '#1e1a2e',
            "accent": '#7040e8',
            "accentComplementary": '#e840a1'
        }
    }]
    property string currentScheme: "Default"
    property real bgOpacity: 1
    property color _rawBg: themes[0].dark.bg
    property color opaqueBg: _rawBg
    // Keep shell surface transparency independent from app-window opacity.
    property color bg: Qt.rgba(_rawBg.r, _rawBg.g, _rawBg.b, SettingsService.shellBackgroundOpacity)
    property bool isDark: ColorUtils.isDark(_rawBg)
    property color overlayBase: isDark ? Qt.rgba(fg.r * 0.3 + accent.r * 0.7, fg.g * 0.3 + accent.g * 0.7, fg.b * 0.3 + accent.b * 0.7, 1) : accent
    property color bgSecondary: Qt.rgba(overlayBase.r, overlayBase.g, overlayBase.b, isDark ? 0.06 : 0.1)
    property color bgTertiary: Qt.rgba(overlayBase.r, overlayBase.g, overlayBase.b, isDark ? 0.02 : 0.04)
    property color bgAccent: Qt.rgba(accent.r, accent.g, accent.b, isDark ? 0.15 : 0.3)
    property color bgAccentComplementary: Qt.rgba(accentComplementary.r, accentComplementary.g, accentComplementary.b, isDark ? 0.15 : 0.3)
    property color fg: themes[0].dark.fg
    property color muted: Qt.rgba(fg.r, fg.g, fg.b, 0.4)
    property color border: isDark ? Qt.rgba(fg.r, fg.g, fg.b, 0.1) : Qt.rgba(fg.r, fg.g, fg.b, 0.2)
    property color accent: themes[0].dark.accent
    property color accentComplementary: themes[0].dark.accentComplementary
    property color shadow: isDark ? Qt.rgba(0, 0, 0, 0.75) : Qt.rgba(0, 0, 0, 0.45)
    property bool generateFromWallpaper: false
    property bool wallpaperIsDark: true
    property var wallpaperColors: null
    property Process saver
    property Process loader
    property Process wallpaperLoader
    property Process generatorProc
    property Process applyThemeProc
    property Connections wpConn

   // Watch external palette updates and synchronize the running theme.
   property FileView schemeWatcher: FileView {
       path: XdgPaths.stateDir + "/colorscheme.json"
       watchChanges: true

       onFileChanged: reload()
       onLoaded: root.syncCachedScheme(text())
   }

    signal themeApplied()

    function applyScheme(scheme) {
        currentScheme = scheme.name;
        _rawBg = scheme.bg;
        fg = scheme.fg;
        accent = scheme.accent;
        accentComplementary = scheme.accentComplementary;
        saveScheme();
    }

    function applyWallpaperTheme(isDark) {
        if (!wallpaperColors || !wallpaperColors.dark || !wallpaperColors.light)
            return ;

        wallpaperIsDark = isDark;
        let activeScheme = isDark ? wallpaperColors.dark : wallpaperColors.light;
        applyScheme({
            "name": activeScheme.name || "Wallpaper Theme",
            "bg": activeScheme.bg,
            "fg": activeScheme.fg,
            "muted": activeScheme.muted,
            "border": activeScheme.border,
            "accent": activeScheme.accent,
            "accentComplementary": activeScheme.accentComplementary,
            "shadow": activeScheme.shadow || "#000000"
        });
    }

    function saveScheme() {
        let obj = {
            "name": currentScheme,
            "generateFromWallpaper": generateFromWallpaper,
            "wallpaperIsDark": wallpaperIsDark,
            "bgOpacity": bgOpacity,
            "bg": "" + _rawBg,
            "opaqueBg": "" + opaqueBg,
            "fg": "" + fg,
            "muted": "" + muted,
            "border": "" + border,
            "accent": "" + accent,
            "accentComplementary": "" + accentComplementary,
            "overlayBase": "" + overlayBase,
            "bgSecondary": "" + bgSecondary,
            "bgTertiary": "" + bgTertiary,
            "bgAccent": "" + bgAccent,
            "bgAccentComplementary": "" + bgAccentComplementary,
            "shadow": "" + shadow
        };
        let json = JSON.stringify(obj);
        saver.running = false;
        saver.command = [
            "python3",
            Quickshell.shellDir + "/Scripts/system/write_text.py",
            XdgPaths.stateDir + "/colorscheme.json",
            "600"
        ];
        saver.running = true;
        saver.write(json + "\n");
    }


    function paletteColorDiffers(current, value) {
        const candidate = Qt.color(value);
        return Math.abs(current.r - candidate.r) > 0.001
            || Math.abs(current.g - candidate.g) > 0.001
            || Math.abs(current.b - candidate.b) > 0.001
            || Math.abs(current.a - candidate.a) > 0.001;
    }

    // Synchronize the in-memory theme when another process updates the cache.
    // Do not call saveScheme() here: that would rewrite the file we're watching.
    function syncCachedScheme(content) {
        try {
            const data = JSON.parse(content);
            if (!data || !data.bg || !data.fg || !data.accent)
                return;

            const nextName = data.name || root.currentScheme;
            const nextGenerate = data.generateFromWallpaper !== undefined
                ? data.generateFromWallpaper : root.generateFromWallpaper;
            const nextDark = data.wallpaperIsDark !== undefined
                ? data.wallpaperIsDark : root.wallpaperIsDark;
            const nextOpacity = data.bgOpacity !== undefined
                ? Number(data.bgOpacity) : root.bgOpacity;
            const nextComplementary = data.accentComplementary
                || root.accentComplementary;

            const changed = root.currentScheme !== nextName
                || root.generateFromWallpaper !== nextGenerate
                || root.wallpaperIsDark !== nextDark
                || Math.abs(root.bgOpacity - nextOpacity) > 0.001
                || paletteColorDiffers(root._rawBg, data.bg)
                || paletteColorDiffers(root.fg, data.fg)
                || paletteColorDiffers(root.accent, data.accent)
                || paletteColorDiffers(root.accentComplementary, nextComplementary);

            if (!changed)
                return;

            root.currentScheme = nextName;
            root.generateFromWallpaper = nextGenerate;
            root.wallpaperIsDark = nextDark;
            root.bgOpacity = nextOpacity;
            root._rawBg = data.bg;
            root.fg = data.fg;
            root.accent = data.accent;
            root.accentComplementary = nextComplementary;

            console.log("Theme: synchronized live palette:", nextName);
        } catch (e) {
            // Ignore incomplete writes; the next file-change event will retry.
        }
    }

    function generateTheme(wallpaperPath) {
        generatorProc.running = false;
        generatorProc.command = ["python3", Quickshell.shellDir + "/Scripts/theme/generate_theme.py", wallpaperPath, generateFromWallpaper ? "True" : "False"];
        generatorProc.running = true;
    }

    function loadScheme() {
        loader.running = false;
        loader.running = true;
        wallpaperLoader.running = false;
        wallpaperLoader.running = true;
    }

    Component.onCompleted: loadScheme()

    wpConn: Connections {
        function onCurrentWallpaperPathChanged() {
            if (root.generateFromWallpaper && WallpaperManager.currentWallpaperPath !== "")
                root.generateTheme(WallpaperManager.currentWallpaperPath);

        }

        target: WallpaperManager
    }

    generatorProc: Process {
        id: generatorProc

        onExited: function(exitCode) {
            if (exitCode === 0) {
                let output = generatorOutput.text;
                let colorsLine = "";
                let lines = output.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].startsWith("COLORS:")) {
                        colorsLine = lines[i].substring(7);
                        break;
                    }
                }
                if (colorsLine) {
                    try {
                        let colors = JSON.parse(colorsLine);
                        root.wallpaperColors = colors;
                        if (colors.activeIsDark !== undefined)
                            root.wallpaperIsDark = colors.activeIsDark;

                        if (root.generateFromWallpaper)
                            root.applyWallpaperTheme(root.wallpaperIsDark);

                    } catch (e) {
                        root.loadScheme();
                    }
                } else {
                    root.loadScheme();
                }
            }
        }

        stderr: StdioCollector {
            id: generatorError
        }

        stdout: StdioCollector {
            id: generatorOutput
        }

    }

    saver: Process {
        stdinEnabled: true
        onExited: function(exitCode) {
            if (exitCode === 0) {
                if (!XdgPaths.safeTestMode) {
                    applyThemeProc.running = false;
                    applyThemeProc.command = ["python3", Quickshell.shellDir + "/Scripts/theme/apply_theme.py"];
                    applyThemeProc.running = true;
                }
            }
        }
    }

    loader: Process {
        command: ["bash", "-c", XdgPaths.migrateCatSnippet, "veyra-theme-loader", XdgPaths.stateDir + "/colorscheme.json", XdgPaths.cacheDir + "/colorscheme.json"]
        onExited: function(exitCode) {
            if (exitCode === 0) {
                try {
                    let colors = JSON.parse(loaderOutput.text);
                    if (colors.generateFromWallpaper !== undefined)
                        root.generateFromWallpaper = colors.generateFromWallpaper;

                    if (colors.wallpaperIsDark !== undefined)
                        root.wallpaperIsDark = colors.wallpaperIsDark;

                    if (colors.name)
                        root.currentScheme = colors.name;

                    if (colors.bgOpacity !== undefined)
                        root.bgOpacity = colors.bgOpacity;

                    if (colors.bg)
                        root._rawBg = colors.bg;

                    if (colors.fg)
                        root.fg = colors.fg;

                    if (colors.accent)
                        root.accent = colors.accent;

                    if (colors.accentComplementary)
                        root.accentComplementary = colors.accentComplementary;

                    if (!XdgPaths.safeTestMode) {
                        applyThemeProc.running = false;
                        applyThemeProc.command = ["python3", Quickshell.shellDir + "/Scripts/theme/apply_theme.py"];
                        applyThemeProc.running = true;
                    }
                } catch (e) {
                    root.applyScheme(root.themes[0].dark);
                }
            } else {
                root.applyScheme(root.themes[0].dark);
            }
        }

        stdout: StdioCollector {
            id: loaderOutput
        }

    }


    wallpaperLoader: Process {
        command: ["python3", Quickshell.shellDir + "/Scripts/system/load_wallpaper_colors.py", XdgPaths.cacheDir]
        onExited: function(exitCode) {
            if (exitCode === 0) {
                try {
                    root.wallpaperColors = JSON.parse(wallpaperLoaderOutput.text);
                } catch (e) {
                }
            }
        }

        stdout: StdioCollector {
            id: wallpaperLoaderOutput
        }

    }

    applyThemeProc: Process {
        onExited: function(exitCode) {
            if (exitCode === 0)
                root.themeApplied();

        }
    }

}
