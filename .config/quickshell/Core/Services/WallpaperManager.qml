import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Services
pragma Singleton

QtObject {
    id: root

    property string currentWallpaper: ""
    property string currentWallpaperPath: ""
    property string transitionType: HyprlandService.wpTransitionType
    property int transitionStep: HyprlandService.wpTransitionStep
    property string transitionPos: HyprlandService.wpTransitionPos
    property int transitionFps: HyprlandService.wpTransitionFps
    property int transitionAngle: HyprlandService.wpTransitionAngle
    property string resizeMode: HyprlandService.wpResizeMode
    property string cropGravity: HyprlandService.wpCropGravity
    property bool enableTransitions: HyprlandService.wpEnableTransitions
    property bool autoShuffle: HyprlandService.wpAutoShuffle
    property int shuffleInterval: HyprlandService.wpShuffleInterval
    property Process wallpaperApplyProc
    property Process wallpaperSaveProc
    property Process wallpaperLoader
    property Process randomWallpaperProc
    property Timer shuffleTimer

    function wallpaperDirectory() {
        const dir = SettingsService.wallpaperDirectory;
        return dir && dir.length > 0 ? dir : (XdgPaths.picturesDir + "/Wallpapers");
    }

    function resolveWallpaperPath(name) {
        if (!name)
            return "";
        return name.startsWith("/") ? name : (wallpaperDirectory() + "/" + name);
    }

    function applyWallpaperWithSync(wallpaperName, rawPath) {
        currentWallpaper = wallpaperName;
        currentWallpaperPath = rawPath;
        saveCurrentWallpaper(wallpaperName);
        applyWallpaper(rawPath);
    }

    function reapplyCurrentWallpaper() {
        let p = resolveWallpaperPath(currentWallpaperPath || currentWallpaper);
        if (p)
            applyWallpaperInstant(p);

    }

    function applyWallpaperInstant(rawPath) {
        if (XdgPaths.safeTestMode) {
            console.info("Veyra safe test: skipped wallpaper changes.");
            return;
        }
        wallpaperApplyProc.running = false;
        let rMode = HyprlandService.wpResizeMode || "crop";
        let gravity = HyprlandService.wpCropGravity || "center";
        let cmd = ["awww", "img", rawPath, "--resize", rMode];
        if (rMode === "crop")
            cmd.push("--crop-gravity", gravity);

        cmd.push("--transition-type", "none");
        wallpaperApplyProc.command = cmd;
        wallpaperApplyProc.startDetached();
    }

    function applyWallpaper(rawPath) {
        if (XdgPaths.safeTestMode) {
            console.info("Veyra safe test: skipped wallpaper changes.");
            return;
        }
        wallpaperApplyProc.running = false;
        let rMode = HyprlandService.wpResizeMode || "crop";
        let gravity = HyprlandService.wpCropGravity || "center";
        let cmd = ["awww", "img", rawPath, "--resize", rMode];
        if (rMode === "crop")
            cmd.push("--crop-gravity", gravity);

        if (enableTransitions) {
            if (transitionPos === "cursor") {
                let posExpr = '$(hyprctl cursorpos 2>/dev/null | tr -d " ")';
                let angleArg = (transitionType === "wipe" || transitionType === "wave") ? (" --transition-angle " + String(transitionAngle)) : "";
                let cropArg = (rMode === "crop") ? (" --crop-gravity " + gravity) : "";
                wallpaperApplyProc.command = [
                    "sh", "-c",
                    'pos="' + posExpr + '"; [ -n "$pos" ] || pos=center; inv=""; [ "$pos" = "center" ] || inv="--invert-y"; '
                    + 'awww img "$1" --resize ' + rMode + cropArg
                    + ' --transition-type ' + transitionType
                    + ' --transition-pos "$pos" $inv'
                    + ' --transition-step ' + String(transitionStep)
                    + ' --transition-fps ' + String(transitionFps) + angleArg,
                    "sh", rawPath
                ];
            } else {
                cmd.push("--transition-type", transitionType, "--transition-pos", transitionPos, "--transition-step", String(transitionStep), "--transition-fps", String(transitionFps));
                if (transitionType === "wipe" || transitionType === "wave")
                    cmd.push("--transition-angle", String(transitionAngle));

                wallpaperApplyProc.command = cmd;
            }
        } else {
            cmd.push("--transition-type", "none");
            wallpaperApplyProc.command = cmd;
        }
        wallpaperApplyProc.startDetached();
    }

    function saveCurrentWallpaper(wallName) {
        wallpaperSaveProc.running = false;
        wallpaperSaveProc.command = [
            "python3",
            Quickshell.shellDir + "/Scripts/system/write_text.py",
            XdgPaths.cacheDir + "/current_wallpaper",
            "600"
        ];
        wallpaperSaveProc.running = true;
        wallpaperSaveProc.write(wallName + "\n");
    }

    function shuffle() {
        randomWallpaperProc.running = false;
        randomWallpaperProc.running = true;
    }

    Component.onCompleted: {
        wallpaperLoader.running = true;
    }

    shuffleTimer: Timer {
        interval: root.shuffleInterval * 60000
        running: root.autoShuffle
        repeat: true
        onTriggered: root.shuffle()
    }

    wallpaperApplyProc: Process {
    }

    wallpaperSaveProc: Process {
        stdinEnabled: true
    }

    randomWallpaperProc: Process {
        command: ["bash", "-c", "find \"$1\" -maxdepth 2 -type f 2>/dev/null | grep -iE '\\.(jpg|jpeg|png|webp|gif)$' | shuf -n 1", "veyra-wallpaper", root.wallpaperDirectory()]
        onExited: function(exitCode) {
            if (exitCode === 0) {
                let path = randomWallOutput.text.trim();
                if (path) {
                    let parts = path.split('/');
                    let wallName = parts[parts.length - 1];
                    root.applyWallpaperWithSync(wallName, path);
                }
            }
        }

        stdout: StdioCollector {
            id: randomWallOutput
        }

    }

    wallpaperLoader: Process {
        command: ["cat", XdgPaths.cacheDir + "/current_wallpaper"]
        onExited: function(exitCode) {
            if (exitCode === 0) {
                let name = wallpaperLoaderOutput.text.trim();
                if (name) {
                    root.currentWallpaper = name;
                    root.currentWallpaperPath = root.resolveWallpaperPath(name);
                }
            }
        }

        stdout: StdioCollector {
            id: wallpaperLoaderOutput
        }

    }

}
