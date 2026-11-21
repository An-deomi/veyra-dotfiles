import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Core
import qs.Core.Services
pragma Singleton

Item {
    id: hyprlandService

    property bool enableAnimations: true
    property real animationSpeedFactor: 1
    property string keyboardLayout: "us"
    property bool wpAutoShuffle: false
    property int wpShuffleInterval: 10
    property bool wpEnableTransitions: true
    property string wpTransitionType: "grow"
    property string wpTransitionPos: "cursor"
    property int wpTransitionStep: 120
    property int wpTransitionFps: 60
    property int wpTransitionAngle: 30
    property string wpResizeMode: "crop"
    property string wpCropGravity: "center"
    property bool hyprBlur: true
    property int hyprRounding: Constants.size3Xl
    property int hyprActiveOpacity: 100
    property int hyprInactiveOpacity: 100
    property int hyprBlurSize: 6
    property int hyprBlurPasses: 4
    property int hyprGapsIn: 4
    property int hyprGapsOut: 8
    property string hyprLayout: "dwindle"
    property bool hyprPreserveSplit: true
    property bool dwindleSmartSplit: false
    property bool dwindleSmartResizing: true
    property int dwindleForceSplit: 0
    property real dwindleDefaultSplitRatio: 1.0
    property bool dwindlePermanentDirectionOverride: false
    property real dwindleSplitWidthMultiplier: 1.0
    property bool dwindleUseActiveForSplits: true
    property int dwindleSplitBias: 0
    property bool dwindlePreciseMouseMove: false
    property real masterMfact: 0.55
    property string masterOrientation: "left"
    property string masterNewStatus: "slave"
    property bool masterAllowSmallSplit: false
    property bool masterSmartResizing: true
    property bool masterNewOnTop: false
    property string masterNewOnActive: "none"
    property bool masterDropAtCursor: true
    property bool masterAlwaysKeepPosition: false
    property bool masterFocusMasterOnClose: false
    property int masterSlaveCountForCenter: 2
    property string masterCenterFallback: "left"
    property int hyprBorderSize: 0
    property bool hyprShadow: true
    property int hyprShadowRange: 8
    property int hyprShadowRenderPower: 3
    property real mouseSensitivity: 0
    property string mouseAccelProfile: "flat"
    property bool mouseNaturalScroll: false
    property real mouseScrollFactor: 1
    property bool mouseLeftHanded: false
    property int mouseFollowMouse: 1
    property int cursorInactiveTimeout: 5
    property bool cursorNoWarps: false
    property bool touchpadNaturalScroll: true
    property bool touchpadTapToClick: true
    property bool touchpadDisableWhileTyping: true
    property bool hyprPrefsLoaded: false
    property bool isSyncing: false
    property bool isTrueFullscreen: false

    function reloadHyprPrefs() {
        if (!readHyprPrefsProc.running)
            readHyprPrefsProc.running = true;

    }

    function checkFullscreen() {
        if (checkFullscreenProc.running)
            checkFullscreenProc.running = false;

        checkFullscreenProc.running = true;
    }

    function applyHyprlandSettings() {
        if (XdgPaths.safeTestMode || !hyprPrefsLoaded || isSyncing || DisplayProfileService.gameModeActive)
            return ;

        applySettingsTimer.restart();
    }

    function applyAdvancedLayoutOptions() {
        if (XdgPaths.safeTestMode || !hyprPrefsLoaded || isSyncing || DisplayProfileService.gameModeActive)
            return;
        applyLayoutOptionsTimer.restart();
    }

    function setPowerSaverMode(enabled) {
        if (XdgPaths.safeTestMode) {
            console.info("Veyra safe test: skipped Hyprland power-save changes.");
            return;
        }

        // Apply temporary power-saving decoration changes to the live compositor.
        // Do not write temporary false values into userprefs.lua: doing so can
        // leave blur and shadows disabled after AC power is restored.
        const blurEnabled = enabled ? false : hyprBlur;
        const shadowEnabled = enabled ? false : hyprShadow;
        const lua = "hl.config({ decoration = { blur = { enabled = "
            + (blurEnabled ? "true" : "false")
            + " }, shadow = { enabled = "
            + (shadowEnabled ? "true" : "false")
            + " } } })";

        powerEffectsProc.command = ["hyprctl", "eval", lua];
        powerEffectsProc.running = false;
        powerEffectsProc.running = true;

        // On AC, also persist the user's configured values (not the temporary
        // power-saver override) so the next compositor reload keeps them.
        if (!enabled)
            applyHyprlandSettings();
    }

    function applyMouseSettings() {
        if (XdgPaths.safeTestMode || !hyprPrefsLoaded || isSyncing)
            return ;

        applyMouseSettingsTimer.restart();
    }

    onEnableAnimationsChanged: {
        if (!XdgPaths.safeTestMode && SettingsService.settingsLoaded && hyprPrefsLoaded && !isSyncing && !DisplayProfileService.gameModeActive) {
            animationsProc.running = false;
            animationsProc.command = ["hyprctl", "eval", "hl.config({ animations = { enabled = " + (enableAnimations ? "true" : "false") + " } })"];
            animationsProc.running = true;
            let jsonArgs = {
                "animations": {
                    "enabled": enableAnimations
                }
            };
            patchUserPrefsProc.command = ["python3", Quickshell.shellDir + "/Core/Services/scripts/update_hypr_prefs.py", JSON.stringify(jsonArgs)];
            patchUserPrefsProc.running = false;
            patchUserPrefsProc.running = true;
        }
    }
    onAnimationSpeedFactorChanged: {
        if (SettingsService.settingsLoaded) {
            SettingsService.saveSettings();
            SettingsService.applyHyprAnimations();
        }

    }
    onWpAutoShuffleChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

    }
    onWpShuffleIntervalChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

    }
    onWpEnableTransitionsChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

    }
    onWpTransitionTypeChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

    }
    onWpTransitionPosChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

    }
    onWpTransitionStepChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

    }
    onWpTransitionFpsChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

    }
    onWpTransitionAngleChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

    }
    onWpResizeModeChanged: {
        if (SettingsService.settingsLoaded) {
            SettingsService.saveSettings();
            WallpaperManager.reapplyCurrentWallpaper();
        }
    }
    onWpCropGravityChanged: {
        if (SettingsService.settingsLoaded) {
            SettingsService.saveSettings();
            WallpaperManager.reapplyCurrentWallpaper();
        }
    }
    onKeyboardLayoutChanged: {
        if (SettingsService.settingsLoaded) {
            SettingsService.saveSettings();
        }
    }
    onHyprBlurChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyHyprlandSettings();

    }
    onHyprRoundingChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyHyprlandSettings();

    }
    onHyprActiveOpacityChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyHyprlandSettings();

    }
    onHyprInactiveOpacityChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyHyprlandSettings();

    }
    onHyprBlurSizeChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyHyprlandSettings();

    }
    onHyprBlurPassesChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyHyprlandSettings();

    }
    onHyprGapsInChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyHyprlandSettings();

    }
    onHyprGapsOutChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyHyprlandSettings();

    }
    onHyprLayoutChanged: {
        if (hyprPrefsLoaded && !isSyncing && (hyprLayout === "dwindle" || hyprLayout === "master")) {
            layoutApplyProc.command = ["hyprctl", "keyword", "general:layout", hyprLayout];
            layoutApplyProc.running = false;
            layoutApplyProc.running = true;
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onHyprPreserveSplitChanged: {
        if (hyprPrefsLoaded && !isSyncing && hyprLayout === "dwindle") {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onDwindleSmartSplitChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onDwindleSmartResizingChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onDwindleForceSplitChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onDwindleDefaultSplitRatioChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onDwindlePermanentDirectionOverrideChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onDwindleSplitWidthMultiplierChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onDwindleUseActiveForSplitsChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onDwindleSplitBiasChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onDwindlePreciseMouseMoveChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onMasterMfactChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onMasterOrientationChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onMasterNewStatusChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onMasterAllowSmallSplitChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onMasterSmartResizingChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onMasterNewOnTopChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onMasterNewOnActiveChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onMasterDropAtCursorChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onMasterAlwaysKeepPositionChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onMasterFocusMasterOnCloseChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onMasterSlaveCountForCenterChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onMasterCenterFallbackChanged: {
        if (hyprPrefsLoaded && !isSyncing) {
            applyHyprlandSettings();
            applyAdvancedLayoutOptions();
        }
    }
    onHyprBorderSizeChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyHyprlandSettings();

    }
    onHyprShadowChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyHyprlandSettings();

    }
    onHyprShadowRangeChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyHyprlandSettings();

    }
    onHyprShadowRenderPowerChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyHyprlandSettings();

    }
    onMouseSensitivityChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyMouseSettings();

    }
    onMouseAccelProfileChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyMouseSettings();

    }
    onMouseNaturalScrollChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyMouseSettings();

    }
    onMouseScrollFactorChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyMouseSettings();

    }
    onMouseLeftHandedChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyMouseSettings();

    }
    onMouseFollowMouseChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyMouseSettings();

    }
    onCursorInactiveTimeoutChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyMouseSettings();

    }
    onCursorNoWarpsChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyMouseSettings();

    }
    onTouchpadNaturalScrollChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyMouseSettings();

    }
    onTouchpadTapToClickChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyMouseSettings();

    }
    onTouchpadDisableWhileTypingChanged: {
        if (hyprPrefsLoaded && !isSyncing)
            applyMouseSettings();

    }
    Component.onCompleted: {
        readHyprPrefsProc.running = true;
        checkFullscreen();
    }

    Timer {
        id: applySettingsTimer

        interval: 50
        repeat: false
        onTriggered: {
            if (!hyprPrefsLoaded || isSyncing)
                return ;

            let ao = (hyprActiveOpacity / 100).toFixed(2);
            let io = (hyprInactiveOpacity / 100).toFixed(2);
            let jsonArgs = {
                "animations": {
                    "enabled": enableAnimations
                },
                "general": {
                    "gaps_in": hyprGapsIn,
                    "gaps_out": hyprGapsOut,
                    "border_size": hyprBorderSize,
                    "layout": hyprLayout
                },
                "dwindle": {
                    "preserve_split": hyprPreserveSplit,
                    "smart_split": dwindleSmartSplit,
                    "smart_resizing": dwindleSmartResizing,
                    "force_split": dwindleForceSplit,
                    "default_split_ratio": parseFloat(dwindleDefaultSplitRatio.toFixed(2)),
                    "permanent_direction_override": dwindlePermanentDirectionOverride,
                    "split_width_multiplier": parseFloat(dwindleSplitWidthMultiplier.toFixed(2)),
                    "use_active_for_splits": dwindleUseActiveForSplits,
                    "split_bias": dwindleSplitBias,
                    "precise_mouse_move": dwindlePreciseMouseMove
                },
                "master": {
                    "mfact": parseFloat(masterMfact.toFixed(2)),
                    "orientation": masterOrientation,
                    "new_status": masterNewStatus,
                    "allow_small_split": masterAllowSmallSplit,
                    "smart_resizing": masterSmartResizing,
                    "new_on_top": masterNewOnTop,
                    "new_on_active": masterNewOnActive,
                    "drop_at_cursor": masterDropAtCursor,
                    "always_keep_position": masterAlwaysKeepPosition,
                    "focus_master_on_close": masterFocusMasterOnClose,
                    "slave_count_for_center_master": masterSlaveCountForCenter,
                    "center_master_fallback": masterCenterFallback
                },
                "decoration": {
                    "rounding": hyprRounding,
                    "active_opacity": parseFloat(ao),
                    "inactive_opacity": parseFloat(io),
                    "blur": {
                        "enabled": hyprBlur,
                        "size": hyprBlurSize,
                        "passes": hyprBlurPasses
                    },
                    "shadow": {
                        "enabled": hyprShadow,
                        "range": hyprShadowRange,
                        "render_power": hyprShadowRenderPower
                    }
                }
            };
            patchUserPrefsProc.command = ["python3", Quickshell.shellDir + "/Core/Services/scripts/update_hypr_prefs.py", JSON.stringify(jsonArgs)];
            patchUserPrefsProc.running = false;
            patchUserPrefsProc.running = true;
        }
    }

    Timer {
        id: applyLayoutOptionsTimer

        interval: 100
        repeat: false
        onTriggered: {
            if (!hyprPrefsLoaded || isSyncing || DisplayProfileService.gameModeActive)
                return;

            let options = {
                "dwindle": {
                    "preserve_split": hyprPreserveSplit,
                    "smart_split": dwindleSmartSplit,
                    "smart_resizing": dwindleSmartResizing,
                    "force_split": dwindleForceSplit,
                    "default_split_ratio": parseFloat(dwindleDefaultSplitRatio.toFixed(2)),
                    "permanent_direction_override": dwindlePermanentDirectionOverride,
                    "split_width_multiplier": parseFloat(dwindleSplitWidthMultiplier.toFixed(2)),
                    "use_active_for_splits": dwindleUseActiveForSplits,
                    "split_bias": dwindleSplitBias,
                    "precise_mouse_move": dwindlePreciseMouseMove
                },
                "master": {
                    "mfact": parseFloat(masterMfact.toFixed(2)),
                    "orientation": masterOrientation,
                    "new_status": masterNewStatus,
                    "allow_small_split": masterAllowSmallSplit,
                    "smart_resizing": masterSmartResizing,
                    "new_on_top": masterNewOnTop,
                    "new_on_active": masterNewOnActive,
                    "drop_at_cursor": masterDropAtCursor,
                    "always_keep_position": masterAlwaysKeepPosition,
                    "focus_master_on_close": masterFocusMasterOnClose,
                    "slave_count_for_center_master": masterSlaveCountForCenter,
                    "center_master_fallback": masterCenterFallback
                }
            };
            applyLayoutOptionsProc.command = ["python3", Quickshell.shellDir + "/Core/Services/scripts/apply_layout_options.py", JSON.stringify(options)];
            applyLayoutOptionsProc.running = false;
            applyLayoutOptionsProc.running = true;
        }
    }

    Timer {
        id: applyMouseSettingsTimer

        interval: 100
        repeat: false
        onTriggered: {
            if (!hyprPrefsLoaded || isSyncing)
                return ;

            // accel_profile comes from the user's Hyprland config; only the
            // documented values are ever interpolated into `hyprctl eval`.
            const validAccelProfiles = ["flat", "adaptive", "custom"];
            const accelProfile = validAccelProfiles.includes(mouseAccelProfile) ? mouseAccelProfile : "";
            if (mouseAccelProfile !== "" && accelProfile === "")
                console.warn("Veyra: ignoring invalid mouse accel profile (expected flat|adaptive|custom):", JSON.stringify(mouseAccelProfile));

            let evalCmd = "hl.config({ " + "input = { " + "sensitivity = " + mouseSensitivity.toFixed(2) + ", " + (accelProfile !== "" ? "accel_profile = '" + accelProfile + "', " : "") + "natural_scroll = " + (mouseNaturalScroll ? "true" : "false") + ", " + "scroll_factor = " + mouseScrollFactor.toFixed(2) + ", " + "left_handed = " + (mouseLeftHanded ? "true" : "false") + ", " + "follow_mouse = " + mouseFollowMouse + ", " + "touchpad = { " + "natural_scroll = " + (touchpadNaturalScroll ? "true" : "false") + ", " + "tap_to_click = " + (touchpadTapToClick ? "true" : "false") + ", " + "disable_while_typing = " + (touchpadDisableWhileTyping ? "true" : "false") + "} " + "}, " + "cursor = { " + "inactive_timeout = " + cursorInactiveTimeout + ", " + "no_warps = " + (cursorNoWarps ? "true" : "false") + "} " + "})";
            mouseApplyProc.command = ["hyprctl", "eval", evalCmd];
            mouseApplyProc.running = false;
            mouseApplyProc.running = true;
            let inputArgs = {
                "sensitivity": parseFloat(mouseSensitivity.toFixed(2)),
                "natural_scroll": mouseNaturalScroll,
                "scroll_factor": parseFloat(mouseScrollFactor.toFixed(2)),
                "left_handed": mouseLeftHanded,
                "follow_mouse": mouseFollowMouse,
                "touchpad": {
                    "natural_scroll": touchpadNaturalScroll,
                    "tap_to_click": touchpadTapToClick,
                    "disable_while_typing": touchpadDisableWhileTyping
                }
            };
            // Only persist values hyprland can actually parse.
            if (accelProfile !== "")
                inputArgs["accel_profile"] = accelProfile;
            let jsonArgs = {
                "input": inputArgs,
                "cursor": {
                    "inactive_timeout": cursorInactiveTimeout,
                    "no_warps": cursorNoWarps
                }
            };
            patchUserPrefsProc.command = ["python3", Quickshell.shellDir + "/Core/Services/scripts/update_hypr_prefs.py", JSON.stringify(jsonArgs)];
            patchUserPrefsProc.running = false;
            patchUserPrefsProc.running = true;
        }
    }

    Process {
        id: mouseApplyProc
    }

    Process {
        id: layoutApplyProc
    }

    Process {
        id: animationsProc
    }

    Process {
        id: powerEffectsProc

        onExited: (exitCode) => {
            if (exitCode !== 0)
                console.warn("Veyra: could not apply power-saving blur/shadow state; hyprctl exited with", exitCode);
        }
    }

    Process {
        id: patchUserPrefsProc
    }

    Process {
        id: applyLayoutOptionsProc
    }

    Process {
        id: checkFullscreenProc

        command: ["sh", "-c", "hyprctl activewindow -j 2>/dev/null | jq -r '(.fullscreen == 2) // false' 2>/dev/null"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                hyprlandService.isTrueFullscreen = (data.trim() === "true");
            }
        }

    }

    Timer {
        id: reapplyGameModeTimer

        interval: 100
        repeat: false
        onTriggered: {
            if (DisplayProfileService.gameModeActive)
                DisplayProfileService.applyGameMode(true);

        }
    }

    Connections {
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                activeLayoutProc.running = true;
            } else if (event.name === "fullscreen") {
                if (event.data === "0")
                    hyprlandService.isTrueFullscreen = false;
                else
                    hyprlandService.checkFullscreen();
            } else if (event.name === "activewindow" || event.name === "activewindowv2" || event.name === "workspace" || event.name === "workspacev2") {
                hyprlandService.checkFullscreen();
            } else if (event.name === "configreloaded") {
                if (DisplayProfileService.gameModeActive)
                    reapplyGameModeTimer.restart();
                else
                    hyprlandService.reloadHyprPrefs();
            }
        }

        target: Hyprland
    }

    Process {
        id: activeLayoutProc

        command: ["sh", "-c", "hyprctl devices -j | jq -r '(.keyboards | (map(select(.main == true))[0] // .[0])) | .active_keymap'"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                let raw = data.trim();
                let code = "us";
                // Map Hyprland full layout names to XKB codes
                const layoutMap = {
                    "English": "us",
                    "Spanish": "latam",
                    "Spanish (Latin American)": "latam",
                    "Spanish (Spain)": "es",
                    "French": "fr",
                    "German": "de",
                    "Italian": "it",
                    "Portuguese": "pt",
                    "Russian": "ru",
                    "Arabic": "ara"
                };
                // Try exact match first
                if (layoutMap[raw] !== undefined) {
                    code = layoutMap[raw];
                } else {
                    // Try partial match (e.g. "English (US)")
                    let matched = false;
                    for (let key of Object.keys(layoutMap)) {
                        if (raw.includes(key)) {
                            code = layoutMap[key];
                            matched = true;
                            break;
                        }
                    }
                    if (!matched)
                        code = raw.toLowerCase().split(" ")[0];

                }
                if (hyprlandService.keyboardLayout !== code)
                    hyprlandService.keyboardLayout = code;

            }
        }

    }

    Process {
        id: readHyprPrefsProc

        command: ["python3", Quickshell.shellDir + "/Core/Services/scripts/read_hypr_prefs.py"]
        onExited: (code) => {
            hyprlandService.isSyncing = false;
            hyprlandService.hyprPrefsLoaded = true;
        }

        stdout: SplitParser {
            onRead: (data) => {
                if (data && data.trim() !== "") {
                    if (DisplayProfileService.gameModeActive)
                        return ;

                    try {
                        let prefs = JSON.parse(data.trim());
                        hyprlandService.isSyncing = true;
                        if (prefs["decoration:blur:enabled"] !== undefined)
                            hyprBlur = prefs["decoration:blur:enabled"];

                        if (prefs["decoration:rounding"] !== undefined)
                            hyprRounding = prefs["decoration:rounding"];

                        if (prefs["decoration:active_opacity"] !== undefined)
                            hyprActiveOpacity = Math.round(prefs["decoration:active_opacity"] * 100);

                        if (prefs["decoration:inactive_opacity"] !== undefined)
                            hyprInactiveOpacity = Math.round(prefs["decoration:inactive_opacity"] * 100);

                        if (prefs["decoration:blur:size"] !== undefined)
                            hyprBlurSize = prefs["decoration:blur:size"];

                        if (prefs["decoration:blur:passes"] !== undefined)
                            hyprBlurPasses = prefs["decoration:blur:passes"];

                        if (prefs["general:gaps_in"] !== undefined)
                            hyprGapsIn = prefs["general:gaps_in"];

                        if (prefs["general:gaps_out"] !== undefined)
                            hyprGapsOut = prefs["general:gaps_out"];

                        if (prefs["general:layout"] === "dwindle" || prefs["general:layout"] === "master")
                            hyprLayout = prefs["general:layout"];

                        if (prefs["dwindle:preserve_split"] !== undefined)
                            hyprPreserveSplit = prefs["dwindle:preserve_split"];

                        if (prefs["dwindle:smart_split"] !== undefined)
                            dwindleSmartSplit = prefs["dwindle:smart_split"];

                        if (prefs["dwindle:smart_resizing"] !== undefined)
                            dwindleSmartResizing = prefs["dwindle:smart_resizing"];

                        if (prefs["dwindle:force_split"] !== undefined)
                            dwindleForceSplit = Math.round(prefs["dwindle:force_split"]);

                        if (prefs["dwindle:default_split_ratio"] !== undefined)
                            dwindleDefaultSplitRatio = prefs["dwindle:default_split_ratio"];

                        if (prefs["dwindle:permanent_direction_override"] !== undefined)
                            dwindlePermanentDirectionOverride = prefs["dwindle:permanent_direction_override"];

                        if (prefs["dwindle:split_width_multiplier"] !== undefined)
                            dwindleSplitWidthMultiplier = prefs["dwindle:split_width_multiplier"];

                        if (prefs["dwindle:use_active_for_splits"] !== undefined)
                            dwindleUseActiveForSplits = prefs["dwindle:use_active_for_splits"];

                        if (prefs["dwindle:split_bias"] !== undefined)
                            dwindleSplitBias = Math.round(prefs["dwindle:split_bias"]);

                        if (prefs["dwindle:precise_mouse_move"] !== undefined)
                            dwindlePreciseMouseMove = prefs["dwindle:precise_mouse_move"];

                        if (prefs["master:mfact"] !== undefined)
                            masterMfact = prefs["master:mfact"];

                        if (prefs["master:orientation"] !== undefined)
                            masterOrientation = prefs["master:orientation"];

                        if (prefs["master:new_status"] !== undefined)
                            masterNewStatus = prefs["master:new_status"];

                        if (prefs["master:allow_small_split"] !== undefined)
                            masterAllowSmallSplit = prefs["master:allow_small_split"];

                        if (prefs["master:smart_resizing"] !== undefined)
                            masterSmartResizing = prefs["master:smart_resizing"];

                        if (prefs["master:new_on_top"] !== undefined)
                            masterNewOnTop = prefs["master:new_on_top"];

                        if (prefs["master:new_on_active"] !== undefined)
                            masterNewOnActive = prefs["master:new_on_active"];

                        if (prefs["master:drop_at_cursor"] !== undefined)
                            masterDropAtCursor = prefs["master:drop_at_cursor"];

                        if (prefs["master:always_keep_position"] !== undefined)
                            masterAlwaysKeepPosition = prefs["master:always_keep_position"];

                        if (prefs["master:focus_master_on_close"] !== undefined)
                            masterFocusMasterOnClose = prefs["master:focus_master_on_close"];

                        if (prefs["master:slave_count_for_center_master"] !== undefined)
                            masterSlaveCountForCenter = Math.round(prefs["master:slave_count_for_center_master"]);

                        if (prefs["master:center_master_fallback"] !== undefined)
                            masterCenterFallback = prefs["master:center_master_fallback"];

                        if (prefs["general:border_size"] !== undefined)
                            hyprBorderSize = prefs["general:border_size"];

                        if (prefs["decoration:shadow:enabled"] !== undefined)
                            hyprShadow = prefs["decoration:shadow:enabled"];

                        if (prefs["decoration:shadow:range"] !== undefined)
                            hyprShadowRange = prefs["decoration:shadow:range"];

                        if (prefs["decoration:shadow:render_power"] !== undefined)
                            hyprShadowRenderPower = prefs["decoration:shadow:render_power"];

                        if (prefs["animations:enabled"] !== undefined)
                            enableAnimations = prefs["animations:enabled"];

                        if (prefs["input:sensitivity"] !== undefined)
                            mouseSensitivity = prefs["input:sensitivity"];

                        if (prefs["input:accel_profile"] !== undefined && prefs["input:accel_profile"] !== "[[EMPTY]]")
                            mouseAccelProfile = prefs["input:accel_profile"];

                        if (prefs["input:natural_scroll"] !== undefined)
                            mouseNaturalScroll = prefs["input:natural_scroll"];

                        if (prefs["input:scroll_factor"] !== undefined)
                            mouseScrollFactor = prefs["input:scroll_factor"];

                        if (prefs["input:left_handed"] !== undefined)
                            mouseLeftHanded = prefs["input:left_handed"];

                        if (prefs["input:follow_mouse"] !== undefined)
                            mouseFollowMouse = prefs["input:follow_mouse"];

                        if (prefs["cursor:inactive_timeout"] !== undefined)
                            cursorInactiveTimeout = Math.round(prefs["cursor:inactive_timeout"]);

                        if (prefs["cursor:no_warps"] !== undefined)
                            cursorNoWarps = prefs["cursor:no_warps"];

                        if (prefs["input:touchpad:natural_scroll"] !== undefined)
                            touchpadNaturalScroll = prefs["input:touchpad:natural_scroll"];

                        if (prefs["input:touchpad:tap-to-click"] !== undefined)
                            touchpadTapToClick = prefs["input:touchpad:tap-to-click"];

                        if (prefs["input:touchpad:disable_while_typing"] !== undefined)
                            touchpadDisableWhileTyping = prefs["input:touchpad:disable_while_typing"];

                    } catch (e) {
                        console.error("Error parsing hypr prefs: " + e);
                    }
                }
            }
        }

    }

}
