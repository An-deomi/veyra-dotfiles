import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
pragma Singleton

Item {
    id: settingsService

    property bool settingsLoaded: false
    // Bumped whenever the meaning of a stored key changes. A file written by a
    // newer build is never overwritten with this build's defaults, and a file
    // that failed to parse is never rewritten either, so a bad or future file
    // cannot silently reset every setting.
    readonly property int supportedPrefsVersion: 1
    property bool settingsWriteBlocked: false
    property string settingsLoadIssue: ""
    property bool settingsBlockWarned: false
    property bool adaptivePowerEnabled: true
    // Tracks whether the settings loader received a non-empty preferences payload.
    property bool settingsLoadDataReceived: false
    // Super+R waits for the latest successful settings write before restarting Quickshell.
    property bool settingsRestartAfterWrite: false
    property bool settingsRestartWriteStarted: false

    // Shell surface transparency (independent from application-window opacity)
    property real shellBackgroundOpacity: 0.85

    // Lock screen appearance preferences
    property bool lockScreenShowClock: true
    property bool lockScreenShowDate: true
    property bool lockScreenShowSeconds: false
    property bool lockScreen24h: true
    property bool lockScreenShowMedia: true
    property bool lockScreenShowMediaState: true
    property bool lockScreenShowBattery: true
    property string lockScreenClockStyle: "classic"
    property bool lockScreenAdaptiveContrast: true
    property real lockScreenBackgroundBlur: 1.0
    property real lockScreenBackgroundDim: 0.7

    // Notification preferences
    property bool notificationsPopupsEnabled: true
    property bool notificationsDndEnabled: false
    property bool notificationsCriticalDuringDnd: true
    property bool notificationGroupingEnabled: true
    property int notificationPopupDuration: 5
    property int notificationHistoryLimit: 50
    property bool notificationQuietHoursEnabled: false
    property bool notificationDndWhileMediaPlaying: false
    property int notificationQuietHoursStartHour: 22
    property int notificationQuietHoursEndHour: 7
    // Only explicit per-app mutes are stored; apps are allowed by default.
    // Keys are normalized lower-case app names, values are false for muted popups.
    property var notificationAppPopupRules: ({})

    // Independent bar-capsule and desktop music visualizer preferences.
    property bool barMediaVisualizerEnabled: true
    property bool desktopCavaEnabled: true
    property int desktopCavaHeight: 92
    property int desktopCavaWidth: 720
    property int desktopCavaBarCount: 36
    property int desktopCavaSpacing: 4
    property string desktopCavaColorMode: "gradient"
    property bool shadowGlowEnabled: true
    property string shadowGlowMode: "accent"
    property int shadowGlowOpacity: 80
    property string hyprAnimCurve: "overshot"
    property string hyprAnimWindowStyle: "popin 80%"
    property string hyprAnimWorkspaceStyle: "slide"
    property bool hyprAnimBorderSpin: true
    property int hyprAnimBorderSpeed: 60
    property bool hyprAnimLayers: true
    property string hyprScreenShader: "none"
    property bool uiSoundsEnabled: true
    property string lockScreenClockLayout: "horizontal"
    property string lockScreenClockWeight: "bold"
    property bool autoBatteryEyeCandy: true
    property bool autoBatteryDim: true
    property string packageManagerMode: "install"
    property int clipboardMaxItems: 100
    property var pinnedLauncherApps: []
    property var recentLauncherApps: []
    property var enabledKbLayouts: ["us"]
    property string githubUsername: ""
    property string githubToken: ""
    property bool githubTokenReady: false
    property bool legacyGithubTokenFound: false
    property bool migratingGithubToken: false
    property bool loadingGithubToken: false
    property string musicPlayer: "none"
    property string musicPlayerCommand: ""

    // Default application preferences used by Veyra and Linux MIME associations.
    property string defaultTerminalCommand: "kitty"
    property string defaultBrowserAppId: ""
    property string defaultCodingAppId: "codium.desktop"
    property string defaultFileManagerAppId: ""
    property string defaultTextEditorAppId: ""
    property string defaultImageViewerAppId: ""
    property string defaultVideoPlayerAppId: ""
    property string defaultMusicPlayerAppId: ""
    property string defaultPdfViewerAppId: ""
    property bool isSettingsLoading: settingsLoader.running
    property string quoteCategory: "All"
    property string fontFamily: "Geist"
    property real fontScale: 1
    property string wallpaperDirectory: XdgPaths.picturesDir + "/Wallpapers"
    property bool clock24h: true
    property bool clockSeconds: false
    property string trayIconSize: "medium"
    readonly property real trayScale: {
        switch (trayIconSize) {
        case "small":
            return 0.85;
        case "large":
            return 1.3;
        case "xlarge":
            return 1.6;
        default:
            return 1;
        }
    }

    onTrayIconSizeChanged: {
        if (settingsService.settingsLoaded)
            settingsService.saveSettings();

    }
    property bool clockShowDate: true
    property bool clockWeatherEnabled: false
    property string clockWeatherLocation: ""
    property bool appThemeZenBrowserEnabled: false
    property bool appThemeSpicetifyEnabled: false
    property bool appThemeHeroicEnabled: false
    property bool appThemePapirusEnabled: false
    property bool appThemeTelegramEnabled: false
    property bool appThemeVSCodiumEnabled: false
    property bool dynamicThemeGtkEnabled: true
    property bool dynamicThemeKColorSchemeEnabled: true
    property bool dynamicThemeHyprlandEnabled: true
    property bool dynamicThemeKittyEnabled: true
    property bool dynamicThemeNeovimEnabled: true
    property bool dynamicThemeQtEnabled: true
    property bool dynamicThemeStarshipEnabled: true
    property bool dynamicThemeBtopEnabled: true
    property bool dynamicThemeLazygitEnabled: true
    property bool dynamicThemeSvgAssetsEnabled: true
    property string cursorTheme: "Bibata-Modern-Classic"
    property int cursorSize: Constants.size2Xl
    property string barStyle: "island"
    property bool barIslandMode: barStyle === "island"
    property bool barConvexMode: barStyle === "convex"
    property bool barIslandExpanded: false
    property string islandRightMode: "auto"
    // Shared Island geometry and independent idle-capsule dimensions.
    // islandWidthScale/islandHeight are retained for migration from older prefs.
    property int islandWidthScale: 100
    property int islandHeight: 32
    property int islandLeftWidthScale: 100
    property int islandLeftHeight: 32
    property int islandCenterWidthScale: 100
    property int islandCenterHeight: 32
    property int islandRightWidthScale: 100
    property int islandRightHeight: 32
    property int islandGap: 10
    property int islandCornerRadius: 16

    // Island surface appearance. Backdrop blur is supplied by Hyprland's
    // layer rule; disabling it makes the surface opaque instead of translucent.
    property bool islandBackdropBlur: true
    property real islandBackgroundOpacity: shellBackgroundOpacity
    property bool islandBorderEnabled: false
    property real islandBorderWidth: 1
    property string islandBorderColorMode: "gradient"
    property bool islandShadowEnabled: true
    property int islandShadowStrength: 65

    // Convex (top-notch) bar geometry and surface. The style used to hardcode
    // every one of these numbers inside ConvexShape/ConvexDesktop.
    property int convexBarHeight: 40
    property int convexTopInset: 0
    property int convexCornerRadius: 16
    property int convexNotchFlare: 18
    property bool convexBackdropBlur: true
    property real convexBackgroundOpacity: shellBackgroundOpacity
    property bool convexBorderEnabled: false
    property real convexBorderWidth: 1
    property string convexBorderColorMode: "gradient"
    property bool convexShadowEnabled: true
    property bool convexFrameEnabled: true
    property int convexFrameSize: 8
    // Configurable idle contents for the three visible Island capsules.
    property string islandLeftWidget: "sysmon"
    property string islandCenterWidget: "clock_workspaces"
    property string barSlotL1: "workspaces"
    property string barSlotL2: "none"
    property string barSlotL3: "none"
    property string barSlotC1: "clock"
    property string barSlotC2: "media"
    property string barSlotR1: "recording"
    property string barSlotR2: "control_center"
    property string barSlotR3: "tray"
    readonly property int barWidgetHeight: 28

    // Screen Capture recording defaults (v35)
    property string screenRecordAudioSource: "output"
    property string screenRecordResolution: "source"
    property bool screenCaptureIncludeCursor: false

    onScreenRecordAudioSourceChanged: {
        if (settingsService.settingsLoaded)
            settingsService.saveSettings();
    }
    onScreenRecordResolutionChanged: {
        if (settingsService.settingsLoaded)
            settingsService.saveSettings();
    }
    onScreenCaptureIncludeCursorChanged: {
        if (settingsService.settingsLoaded)
            settingsService.saveSettings();
    }
    onPackageManagerModeChanged: {
        if (settingsService.settingsLoaded)
            settingsService.saveSettings();
    }
    onWallpaperDirectoryChanged: {
        if (settingsService.settingsLoaded)
            settingsService.saveSettings();
    }

    function saveSettings() {
        if (settingsWriteBlocked) {
            if (!settingsBlockWarned) {
                settingsBlockWarned = true;
                console.warn("Veyra: settings are read-only this session (" + settingsLoadIssue + "); changes are not written to disk.");
            }
            return ;
        }
        saveTimer.restart();
    }

    function normalizeWallpaperDirectory(value) {
        let dir = String(value || "").trim();
        if (dir === "~")
            return XdgPaths.homeDir;
        if (dir.startsWith("~/"))
            dir = XdgPaths.homeDir + dir.slice(1);
        if (dir.length > 1 && dir.endsWith("/"))
            dir = dir.slice(0, -1);
        return dir;
    }

    function setWallpaperDirectory(value) {
        const dir = normalizeWallpaperDirectory(value);
        if (dir !== "")
            wallpaperDirectory = dir;
    }

    function notificationAppKey(appName) {
        return String(appName || "").trim().toLowerCase();
    }

    function isNotificationAppEnabled(appName) {
        const key = notificationAppKey(appName);
        if (key === "")
            return true;
        return notificationAppPopupRules[key] !== false;
    }

    function setNotificationAppEnabled(appName, enabled) {
        const key = notificationAppKey(appName);
        if (key === "")
            return;
        const next = Object.assign({}, notificationAppPopupRules || {});
        if (enabled)
            delete next[key];
        else
            next[key] = false;
        notificationAppPopupRules = next;
    }

    function toggleLauncherPin(appId) {
        if (!appId)
            return;
        let next = (pinnedLauncherApps || []).slice();
        let index = next.indexOf(appId);
        if (index >= 0)
            next.splice(index, 1);
        else
            next.push(appId);
        pinnedLauncherApps = next;
        if (settingsLoaded)
            saveSettings();
    }

    function recordLauncherLaunch(appId) {
        if (!appId)
            return;
        let next = (recentLauncherApps || []).slice();
        const index = next.indexOf(appId);
        if (index >= 0)
            next.splice(index, 1);
        next.unshift(appId);
        if (next.length > 12)
            next = next.slice(0, 12);
        recentLauncherApps = next;
        if (settingsLoaded)
            saveSettings();
    }

    function storeGithubToken(value) {
        githubTokenStoreProc.running = false;
        githubTokenStoreProc.command = ["python3", Quickshell.shellDir + "/Scripts/system/github_token.py", value ? "set" : "clear"];
        githubTokenStoreProc.running = true;
        if (value)
            githubTokenStoreProc.write(String(value).trim() + "\n");
    }

    function loadGithubToken() {
        if (legacyGithubTokenFound && githubToken !== "") {
            // Do not remove the legacy value from preferences until secure storage succeeds.
            migratingGithubToken = true;
            githubTokenStoreProc.running = false;
            githubTokenStoreProc.command = ["python3", Quickshell.shellDir + "/Scripts/system/github_token.py", "set"];
            githubTokenStoreProc.running = true;
            githubTokenStoreProc.write(String(githubToken).trim() + "\n");
            return;
        }
        githubTokenLoadProc.running = false;
        githubTokenLoadProc.running = true;
    }

    function load() {
        if (!settingsLoaded && !isSettingsLoading)
            settingsLoader.running = true;

    }

    function applyCursor(theme, size) {
        if (XdgPaths.safeTestMode) {
            console.info("Veyra safe test: skipped system cursor changes.");
            return;
        }
        let t = theme !== undefined ? theme : cursorTheme;
        let s = size !== undefined ? size : cursorSize;
        applyCursorProc.command = ["python3", Quickshell.shellDir + "/Scripts/theme/apply_cursor.py", t, s.toString()];
        applyCursorProc.running = false;
        applyCursorProc.running = true;
    }

    function applyFont(font, size) {
        if (XdgPaths.safeTestMode) {
            console.info("Veyra safe test: skipped system font changes.");
            return;
        }
        let f = font !== undefined ? font : fontFamily;
        let s = size !== undefined ? size : Math.round(11 * fontScale);
        applyFontProc.command = ["python3", Quickshell.shellDir + "/Scripts/theme/apply_font.py", f, s.toString()];
        applyFontProc.running = false;
        applyFontProc.running = true;
    }

    Component.onCompleted: {
        load();
    }

    // Autosave user-facing preferences that are also changed by settings controls.
    onBarMediaVisualizerEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDesktopCavaEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDesktopCavaHeightChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDesktopCavaWidthChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDesktopCavaBarCountChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDesktopCavaSpacingChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDesktopCavaColorModeChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDefaultTerminalCommandChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDefaultBrowserAppIdChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDefaultCodingAppIdChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDefaultFileManagerAppIdChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDefaultTextEditorAppIdChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDefaultImageViewerAppIdChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDefaultVideoPlayerAppIdChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDefaultMusicPlayerAppIdChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDefaultPdfViewerAppIdChanged: {
        if (settingsLoaded)
            saveSettings();
    }

    onClipboardMaxItemsChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onEnabledKbLayoutsChanged: {
        if (settingsLoaded) {
            saveSettings();
            applyKeyboardLayouts();
        }
    }
    onGithubUsernameChanged: {
        if (settingsLoaded)
            saveSettings();

    }

    onGithubTokenChanged: {
        if (settingsLoaded && githubTokenReady && !loadingGithubToken)
            storeGithubToken(githubToken);
    }
    onMusicPlayerChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onMusicPlayerCommandChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onQuoteCategoryChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onFontFamilyChanged: {
        if (settingsLoaded) {
            saveSettings();
            applyFont(fontFamily, Math.round(11 * fontScale));
        }
    }
    onFontScaleChanged: {
        if (settingsLoaded) {
            saveSettings();
            applyFont(fontFamily, Math.round(11 * fontScale));
        }
    }
    onClock24hChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onClockSecondsChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onClockShowDateChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onClockWeatherEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onClockWeatherLocationChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onCursorThemeChanged: {
        if (settingsLoaded) {
            saveSettings();
            applyCursor(cursorTheme, cursorSize);
        }
    }
    onCursorSizeChanged: {
        if (settingsLoaded) {
            saveSettings();
            applyCursor(cursorTheme, cursorSize);
        }
    }
    onBarStyleChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onBarIslandExpandedChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onIslandRightModeChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onIslandLeftWidgetChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onIslandCenterWidgetChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onBarSlotL1Changed: {
        if (settingsLoaded)
            saveSettings();

    }
    onBarSlotL2Changed: {
        if (settingsLoaded)
            saveSettings();

    }
    onBarSlotL3Changed: {
        if (settingsLoaded)
            saveSettings();

    }
    onBarSlotC1Changed: {
        if (settingsLoaded)
            saveSettings();

    }
    onBarSlotC2Changed: {
        if (settingsLoaded)
            saveSettings();

    }
    onBarSlotR1Changed: {
        if (settingsLoaded)
            saveSettings();

    }
    onBarSlotR2Changed: {
        if (settingsLoaded)
            saveSettings();

    }
    onBarSlotR3Changed: {
        if (settingsLoaded)
            saveSettings();

    }

    Timer {
        id: saveTimer

        interval: 100
        repeat: false
        onTriggered: {
            // A save requested before the file finished loading must not write
            // defaults over a file we could not read or one from a newer build.
            if (settingsService.settingsWriteBlocked) {
                if (!settingsService.settingsBlockWarned) {
                    settingsService.settingsBlockWarned = true;
                    console.warn("Veyra: settings are read-only this session (" + settingsService.settingsLoadIssue + "); changes are not written to disk.");
                }
                return ;
            }
            // Wait for an in-flight atomic writer instead of killing it.
            if (settingsSaver.running) {
                saveTimer.restart();
                return;
            }
            settingsService.settingsRestartWriteStarted = settingsService.settingsRestartAfterWrite;
            let data = {
                "schemaVersion": settingsService.supportedPrefsVersion,
                "powerProfile": SystemInfoService.powerProfile,
                "adaptivePowerEnabled": settingsService.adaptivePowerEnabled,
                "packageManagerChecksEnabled": UpdateService.packageManagerChecksEnabled,
                "packageManagerCheckInterval": UpdateService.packageManagerCheckInterval,
                "packageManagerMode": settingsService.packageManagerMode,
                "clipboardMaxItems": settingsService.clipboardMaxItems,
                "enabledKbLayouts": settingsService.enabledKbLayouts,
                "animationSpeedFactor": HyprlandService.animationSpeedFactor,
                "githubUsername": settingsService.githubUsername,
                                "musicPlayer": settingsService.musicPlayer,
                "musicPlayerCommand": settingsService.musicPlayerCommand,
                "nightLightActive": DisplayProfileService.nightLightActive,
                "caffeineActive": DisplayProfileService.caffeineActive,
                // Persist only a user-enabled Game Mode; daemon-only activation is temporary.
                "gameModeActive": DisplayProfileService.gameModeActive && !DisplayProfileService.autoActivatedByDaemon,
                "nightLightTemperature": DisplayProfileService.nightLightTemperature,
                "keyboardLayout": HyprlandService.keyboardLayout,
                "wpAutoShuffle": HyprlandService.wpAutoShuffle,
                "wpShuffleInterval": HyprlandService.wpShuffleInterval,
                "wpEnableTransitions": HyprlandService.wpEnableTransitions,
                "wpTransitionType": HyprlandService.wpTransitionType,
                "wpTransitionPos": HyprlandService.wpTransitionPos,
                "wpTransitionStep": HyprlandService.wpTransitionStep,
                "wpTransitionFps": HyprlandService.wpTransitionFps,
                "wpTransitionAngle": HyprlandService.wpTransitionAngle,
                "wpResizeMode": HyprlandService.wpResizeMode,
                "wpCropGravity": HyprlandService.wpCropGravity,
                "wallpaperDirectory": settingsService.wallpaperDirectory,
                "micMuted": AudioService.micMuted,
                "micVolume": AudioService.micVolume,
                "quoteCategory": settingsService.quoteCategory,
                "fontFamily": settingsService.fontFamily,
                "fontScale": settingsService.fontScale,
                "clock24h": settingsService.clock24h,
                "clockSeconds": settingsService.clockSeconds,
                "trayIconSize": settingsService.trayIconSize,
                "clockShowDate": settingsService.clockShowDate,
                "clockWeatherEnabled": settingsService.clockWeatherEnabled,
                "clockWeatherLocation": settingsService.clockWeatherLocation,
                "shellBackgroundOpacity": settingsService.shellBackgroundOpacity,
                "lockScreenShowClock": settingsService.lockScreenShowClock,
                "lockScreenShowDate": settingsService.lockScreenShowDate,
                "lockScreenShowSeconds": settingsService.lockScreenShowSeconds,
                "lockScreen24h": settingsService.lockScreen24h,
                "lockScreenShowMedia": settingsService.lockScreenShowMedia,
                "lockScreenShowMediaState": settingsService.lockScreenShowMediaState,
                "lockScreenShowBattery": settingsService.lockScreenShowBattery,
                "lockScreenClockStyle": settingsService.lockScreenClockStyle,
                "lockScreenAdaptiveContrast": settingsService.lockScreenAdaptiveContrast,
                "lockScreenBackgroundBlur": settingsService.lockScreenBackgroundBlur,
                "lockScreenBackgroundDim": settingsService.lockScreenBackgroundDim,
                "notificationsPopupsEnabled": settingsService.notificationsPopupsEnabled,
                "notificationsDndEnabled": settingsService.notificationsDndEnabled,
                "notificationsCriticalDuringDnd": settingsService.notificationsCriticalDuringDnd,
                "notificationGroupingEnabled": settingsService.notificationGroupingEnabled,
                "notificationPopupDuration": settingsService.notificationPopupDuration,
                "notificationHistoryLimit": settingsService.notificationHistoryLimit,
                "notificationQuietHoursEnabled": settingsService.notificationQuietHoursEnabled,
                "notificationDndWhileMediaPlaying": settingsService.notificationDndWhileMediaPlaying,
                "notificationQuietHoursStartHour": settingsService.notificationQuietHoursStartHour,
                "notificationQuietHoursEndHour": settingsService.notificationQuietHoursEndHour,
                "notificationAppPopupRules": settingsService.notificationAppPopupRules,
                "cursorTheme": settingsService.cursorTheme,
                "cursorSize": settingsService.cursorSize,
                "barStyle": settingsService.barStyle,
                "barIslandExpanded": settingsService.barIslandExpanded,
                "islandRightMode": settingsService.islandRightMode,
                "islandLeftWidget": settingsService.islandLeftWidget,
                "islandCenterWidget": settingsService.islandCenterWidget,
                "islandWidthScale": settingsService.islandWidthScale,
                "islandHeight": settingsService.islandHeight,
                "islandLeftWidthScale": settingsService.islandLeftWidthScale,
                "islandLeftHeight": settingsService.islandLeftHeight,
                "islandCenterWidthScale": settingsService.islandCenterWidthScale,
                "islandCenterHeight": settingsService.islandCenterHeight,
                "islandRightWidthScale": settingsService.islandRightWidthScale,
                "islandRightHeight": settingsService.islandRightHeight,
                "islandGap": settingsService.islandGap,
                "islandCornerRadius": settingsService.islandCornerRadius,
                "islandBackdropBlur": settingsService.islandBackdropBlur,
                "islandBackgroundOpacity": settingsService.islandBackgroundOpacity,
                "islandBorderEnabled": settingsService.islandBorderEnabled,
                "islandBorderWidth": settingsService.islandBorderWidth,
                "islandBorderColorMode": settingsService.islandBorderColorMode,
                "islandShadowEnabled": settingsService.islandShadowEnabled,
                "islandShadowStrength": settingsService.islandShadowStrength,
                "convexBarHeight": settingsService.convexBarHeight,
                "convexTopInset": settingsService.convexTopInset,
                "convexCornerRadius": settingsService.convexCornerRadius,
                "convexNotchFlare": settingsService.convexNotchFlare,
                "convexBackdropBlur": settingsService.convexBackdropBlur,
                "convexBackgroundOpacity": settingsService.convexBackgroundOpacity,
                "convexBorderEnabled": settingsService.convexBorderEnabled,
                "convexBorderWidth": settingsService.convexBorderWidth,
                "convexBorderColorMode": settingsService.convexBorderColorMode,
                "convexShadowEnabled": settingsService.convexShadowEnabled,
                "convexFrameEnabled": settingsService.convexFrameEnabled,
                "convexFrameSize": settingsService.convexFrameSize,
                "barSlotL1": settingsService.barSlotL1,
                "barSlotL2": settingsService.barSlotL2,
                "barSlotL3": settingsService.barSlotL3,
                "barSlotC1": settingsService.barSlotC1,
                "barSlotC2": settingsService.barSlotC2,
                "barSlotR1": settingsService.barSlotR1,
                "barSlotR2": settingsService.barSlotR2,
                "appThemeZenBrowserEnabled": settingsService.appThemeZenBrowserEnabled,
                "appThemeSpicetifyEnabled": settingsService.appThemeSpicetifyEnabled,
                "appThemeHeroicEnabled": settingsService.appThemeHeroicEnabled,
                "appThemePapirusEnabled": settingsService.appThemePapirusEnabled,
                "appThemeTelegramEnabled": settingsService.appThemeTelegramEnabled,
                "dynamicThemeGtkEnabled": settingsService.dynamicThemeGtkEnabled,
                "dynamicThemeKColorSchemeEnabled": settingsService.dynamicThemeKColorSchemeEnabled,
                "dynamicThemeHyprlandEnabled": settingsService.dynamicThemeHyprlandEnabled,
                "dynamicThemeKittyEnabled": settingsService.dynamicThemeKittyEnabled,
                "dynamicThemeNeovimEnabled": settingsService.dynamicThemeNeovimEnabled,
                "dynamicThemeQtEnabled": settingsService.dynamicThemeQtEnabled,
                "dynamicThemeStarshipEnabled": settingsService.dynamicThemeStarshipEnabled,
                "dynamicThemeBtopEnabled": settingsService.dynamicThemeBtopEnabled,
                "dynamicThemeLazygitEnabled": settingsService.dynamicThemeLazygitEnabled,
                "dynamicThemeSvgAssetsEnabled": settingsService.dynamicThemeSvgAssetsEnabled,
                "appThemeVSCodiumEnabled": settingsService.appThemeVSCodiumEnabled,
                "barSlotR3": settingsService.barSlotR3,
                "barMediaVisualizerEnabled": settingsService.barMediaVisualizerEnabled,
                "desktopCavaEnabled": settingsService.desktopCavaEnabled,
                "desktopCavaHeight": settingsService.desktopCavaHeight,
                "desktopCavaWidth": settingsService.desktopCavaWidth,
                "desktopCavaBarCount": settingsService.desktopCavaBarCount,
                "desktopCavaSpacing": settingsService.desktopCavaSpacing,
                "desktopCavaColorMode": settingsService.desktopCavaColorMode,
                "pinnedLauncherApps": settingsService.pinnedLauncherApps,
                "recentLauncherApps": settingsService.recentLauncherApps,
                "screenRecordAudioSource": settingsService.screenRecordAudioSource,
                "screenRecordResolution": settingsService.screenRecordResolution,
                "defaultTerminalCommand": settingsService.defaultTerminalCommand,
                "defaultBrowserAppId": settingsService.defaultBrowserAppId,
                "defaultCodingAppId": settingsService.defaultCodingAppId,
                "defaultFileManagerAppId": settingsService.defaultFileManagerAppId,
                "defaultTextEditorAppId": settingsService.defaultTextEditorAppId,
                "defaultImageViewerAppId": settingsService.defaultImageViewerAppId,
                "defaultVideoPlayerAppId": settingsService.defaultVideoPlayerAppId,
                "defaultMusicPlayerAppId": settingsService.defaultMusicPlayerAppId,
                "defaultPdfViewerAppId": settingsService.defaultPdfViewerAppId,
                "screenCaptureIncludeCursor": settingsService.screenCaptureIncludeCursor,
                "shadowGlowEnabled": settingsService.shadowGlowEnabled,
                "shadowGlowMode": settingsService.shadowGlowMode,
                "shadowGlowOpacity": settingsService.shadowGlowOpacity,
                "hyprAnimCurve": settingsService.hyprAnimCurve,
                "hyprAnimWindowStyle": settingsService.hyprAnimWindowStyle,
                "hyprAnimWorkspaceStyle": settingsService.hyprAnimWorkspaceStyle,
                "hyprAnimBorderSpin": settingsService.hyprAnimBorderSpin,
                "hyprAnimBorderSpeed": settingsService.hyprAnimBorderSpeed,
                "hyprAnimLayers": settingsService.hyprAnimLayers,
                "hyprScreenShader": settingsService.hyprScreenShader,
                "uiSoundsEnabled": settingsService.uiSoundsEnabled,
                "lockScreenClockLayout": settingsService.lockScreenClockLayout,
                "lockScreenClockWeight": settingsService.lockScreenClockWeight,
                "autoBatteryEyeCandy": settingsService.autoBatteryEyeCandy,
                "autoBatteryDim": settingsService.autoBatteryDim,
            };
            if (settingsService.legacyGithubTokenFound)
                data.githubToken = settingsService.githubToken;
            settingsSaver.command = [
                "python3",
                Quickshell.shellDir + "/Scripts/system/write_text.py",
                XdgPaths.stateDir + "/settings_prefs.json",
                "600"
            ];
            settingsSaver.running = true;
            settingsSaver.write(JSON.stringify(data) + "\n");
        }
    }

    IpcHandler {
        target: "veyraSettingsRestart"

        function restart() {
            if (!settingsService.settingsLoaded) {
                console.error("Veyra restart canceled: settings have not finished loading.");
                return;
            }
            settingsService.settingsRestartAfterWrite = true;
            settingsService.settingsRestartWriteStarted = false;
            saveTimer.stop();
            saveTimer.restart();
        }
    }

    // Keyboard layouts are stored as xkb codes. Hyprland only knows the layouts
    // it was configured with, so the list has to be applied live and also
    // persisted into hypr/veyra-settings.lua for the next login.
    readonly property string keyboardLayoutCodes: {
        let layouts = settingsService.enabledKbLayouts || [];
        let codes = [];
        for (let i = 0; i < layouts.length; i++) {
            let code = String(layouts[i] || "").trim();
            if (/^[A-Za-z0-9_-]{1,20}$/.test(code) && codes.indexOf(code) === -1)
                codes.push(code);
        }
        return codes.length > 0 ? codes.join(",") : "us";
    }

    function applyKeyboardLayouts() {
        if (!settingsLoaded)
            return;
        kbLayoutApplyProc.command = ["hyprctl", "eval", "hl.config({input = {kb_layout = '" + keyboardLayoutCodes + "'}})"];
        kbLayoutApplyProc.running = false;
        kbLayoutApplyProc.running = true;
        kbLayoutPersistProc.command = ["python3", Quickshell.shellDir + "/Core/Services/scripts/update_veyra_prefs.py", JSON.stringify({
            "keyboard_layout": keyboardLayoutCodes
        })];
        kbLayoutPersistProc.running = false;
        kbLayoutPersistProc.running = true;
    }

    Process {
        id: kbLayoutApplyProc

        running: false
    }

    Process {
        id: kbLayoutPersistProc

        running: false
    }

    onShadowGlowEnabledChanged: {
        if (settingsService.settingsLoaded) {
            settingsService.saveSettings();
            settingsService.applyShadowGlow();
        }
    }
    onShadowGlowModeChanged: {
        if (settingsService.settingsLoaded) {
            settingsService.saveSettings();
            settingsService.applyShadowGlow();
        }
    }
    onShadowGlowOpacityChanged: {
        if (settingsService.settingsLoaded) {
            settingsService.saveSettings();
            settingsService.applyShadowGlow();
        }
    }

    function applyShadowGlow() {
        if (!settingsLoaded || XdgPaths.safeTestMode)
            return;
        shadowGlowPersistProc.command = [
            "python3",
            Quickshell.shellDir + "/Core/Services/scripts/update_veyra_prefs.py",
            JSON.stringify({
                "shadow_glow_enabled": shadowGlowEnabled,
                "shadow_glow_mode": shadowGlowMode,
                "shadow_glow_opacity": Math.max(5, Math.min(100, Math.round(shadowGlowOpacity)))
            })
        ];
        shadowGlowPersistProc.running = false;
        shadowGlowPersistProc.running = true;
    }

    Process {
        id: shadowGlowPersistProc

        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                shadowGlowReloadProc.running = false;
                shadowGlowReloadProc.running = true;
            }
        }
    }

    Process {
        id: shadowGlowReloadProc

        command: ["hyprctl", "reload"]
        running: false
    }

    onHyprAnimCurveChanged: {
        if (settingsService.settingsLoaded) {
            settingsService.saveSettings();
            settingsService.applyHyprAnimations();
        }
    }
    onHyprAnimWindowStyleChanged: {
        if (settingsService.settingsLoaded) {
            settingsService.saveSettings();
            settingsService.applyHyprAnimations();
        }
    }
    onHyprAnimWorkspaceStyleChanged: {
        if (settingsService.settingsLoaded) {
            settingsService.saveSettings();
            settingsService.applyHyprAnimations();
        }
    }
    onHyprAnimBorderSpinChanged: {
        if (settingsService.settingsLoaded) {
            settingsService.saveSettings();
            settingsService.applyHyprAnimations();
        }
    }
    onHyprAnimBorderSpeedChanged: {
        if (settingsService.settingsLoaded) {
            settingsService.saveSettings();
            settingsService.applyHyprAnimations();
        }
    }
    onHyprAnimLayersChanged: {
        if (settingsService.settingsLoaded) {
            settingsService.saveSettings();
            settingsService.applyHyprAnimations();
        }
    }

    function applyHyprAnimations() {
        if (!settingsLoaded || XdgPaths.safeTestMode)
            return;
        hyprAnimPersistProc.command = [
            "python3",
            Quickshell.shellDir + "/Core/Services/scripts/update_veyra_prefs.py",
            JSON.stringify({
                "anim_curve": hyprAnimCurve,
                "anim_window_style": hyprAnimWindowStyle,
                "anim_workspace_style": hyprAnimWorkspaceStyle,
                "anim_speed_factor": Math.max(0.2, Math.min(3.0, Number(HyprlandService.animationSpeedFactor.toFixed(2)))),
                "anim_border_spin": hyprAnimBorderSpin,
                "anim_border_speed": Math.max(15, Math.min(120, Math.round(hyprAnimBorderSpeed))),
                "anim_layers": hyprAnimLayers
            })
        ];
        hyprAnimPersistProc.running = false;
        hyprAnimPersistProc.running = true;
    }

    Process {
        id: hyprAnimPersistProc

        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                shadowGlowReloadProc.running = false;
                shadowGlowReloadProc.running = true;
            }
        }
    }

    onHyprScreenShaderChanged: {
        if (settingsService.settingsLoaded) {
            settingsService.saveSettings();
            settingsService.applyScreenShader();
        }
    }

    function applyScreenShader() {
        if (!settingsLoaded || XdgPaths.safeTestMode)
            return;
        screenShaderPersistProc.command = [
            "python3",
            Quickshell.shellDir + "/Core/Services/scripts/update_veyra_prefs.py",
            JSON.stringify({ "screen_shader": hyprScreenShader })
        ];
        screenShaderPersistProc.running = false;
        screenShaderPersistProc.running = true;
    }

    function cycleScreenShader() {
        const order = ["none", "vibrance", "film-grain", "crt", "warm"];
        const labels = {
            "none": "Off",
            "vibrance": "Vibrance",
            "film-grain": "Film Grain",
            "crt": "CRT",
            "warm": "Warm"
        };
        const idx = order.indexOf(hyprScreenShader);
        const next = order[(idx + 1) % order.length];
        hyprScreenShader = next;
        IslandEventService.showEvent("shader", "Screen Shader", labels[next], "sparkles", -1, 1450);
    }

    Process {
        id: screenShaderPersistProc

        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                shadowGlowReloadProc.running = false;
                shadowGlowReloadProc.running = true;
            }
        }
    }

    onUiSoundsEnabledChanged: { if (settingsService.settingsLoaded) settingsService.saveSettings(); }
    onLockScreenClockLayoutChanged: { if (settingsService.settingsLoaded) settingsService.saveSettings(); }
    onLockScreenClockWeightChanged: { if (settingsService.settingsLoaded) settingsService.saveSettings(); }
    onAutoBatteryEyeCandyChanged: {
        if (settingsService.settingsLoaded) {
            settingsService.saveSettings();
            SystemInfoService.applyBatteryEcoRules(SystemInfoService.lastOnBatteryState, false);
        }
    }
    onAutoBatteryDimChanged: {
        if (settingsService.settingsLoaded) {
            settingsService.saveSettings();
            SystemInfoService.applyBatteryEcoRules(SystemInfoService.lastOnBatteryState, false);
        }
    }

    function playUiSound(kind) {
        if (!settingsLoaded || !uiSoundsEnabled || XdgPaths.safeTestMode)
            return;
        const sounds = {
            "power-plug":   ["/usr/share/sounds/ocean/stereo/power-plug.oga", "/usr/share/sounds/freedesktop/stereo/power-plug.oga"],
            "power-unplug": ["/usr/share/sounds/ocean/stereo/power-unplug.oga", "/usr/share/sounds/freedesktop/stereo/power-unplug.oga"],
            "record-start": ["/usr/share/sounds/freedesktop/stereo/device-added.oga"],
            "record-stop":  ["/usr/share/sounds/ocean/stereo/outcome-success.oga", "/usr/share/sounds/freedesktop/stereo/complete.oga"],
            "lock":         ["/usr/share/sounds/freedesktop/stereo/service-logout.oga"],
            "unlock":       ["/usr/share/sounds/freedesktop/stereo/service-login.oga"],
            "timer-done":   ["/usr/share/sounds/ocean/stereo/alarm-clock-elapsed.oga", "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"]
        };
        const candidates = sounds[kind];
        if (!candidates || candidates.length === 0)
            return;
        Quickshell.execDetached([
            "sh", "-c",
            'for f in "$@"; do if [ -r "$f" ]; then (command -v pw-play >/dev/null 2>&1 && exec pw-play "$f" || exec paplay "$f") >/dev/null 2>&1; exit 0; fi; done',
            "veyra-sound"
        ].concat(candidates));
    }

    Process {
        id: settingsLoader

        command: ["bash", "-c", XdgPaths.migrateCatSnippet, "veyra-settings-loader", XdgPaths.stateDir + "/settings_prefs.json", XdgPaths.cacheDir + "/settings_prefs.json"]
        onExited: function(exitCode) {
            // cat exits successfully for an empty file, so check the payload as well.
            if (exitCode !== 0 || !settingsService.settingsLoadDataReceived) {
                if (exitCode === 0)
                    console.warn("Veyra: settings file was empty; keeping it untouched and using defaults.");
                else
                    console.warn("Veyra: settings file could not be read; keeping it untouched and using defaults (exit " + exitCode + ").");

                // Never overwrite the preferences file after a failed read:
                // a transient error must not erase the user's settings.
                if (!settingsService.adaptivePowerEnabled)
                    SystemInfoService.applyProfile("balanced");
                settingsService.settingsLoaded = true;
                Qt.callLater(SystemInfoService.syncAdaptiveProfile);
                settingsService.loadGithubToken();
                settingsService.applyCursor(settingsService.cursorTheme, settingsService.cursorSize);
                settingsService.applyFont(settingsService.fontFamily, Math.round(11 * settingsService.fontScale));
            }
        }

        stdout: SplitParser {
            onRead: (data) => {
                if (data && data.trim() !== "") {
                    settingsService.settingsLoadDataReceived = true;
                    try {
                        let prefs = JSON.parse(data.trim());
                        let storedVersion = Number(prefs.schemaVersion);
                        if (Number.isFinite(storedVersion) && storedVersion > settingsService.supportedPrefsVersion) {
                            settingsService.settingsWriteBlocked = true;
                            settingsService.settingsLoadIssue = "file uses schema v" + storedVersion + ", newer than v" + settingsService.supportedPrefsVersion;
                            console.warn("Veyra: " + settingsService.settingsLoadIssue + "; keeping it untouched.");
                        }
                        if (prefs.barMediaVisualizerEnabled !== undefined)
                            settingsService.barMediaVisualizerEnabled = Boolean(prefs.barMediaVisualizerEnabled);

                        if (prefs.desktopCavaEnabled !== undefined)
                            settingsService.desktopCavaEnabled = Boolean(prefs.desktopCavaEnabled);

                        if (prefs.desktopCavaHeight !== undefined)
                            settingsService.desktopCavaHeight = Math.max(50, Math.min(180, Math.round(Number(prefs.desktopCavaHeight))));

                        if (prefs.desktopCavaWidth !== undefined)
                            settingsService.desktopCavaWidth = Math.max(300, Math.min(1600, Math.round(Number(prefs.desktopCavaWidth))));

                        if (prefs.desktopCavaBarCount !== undefined)
                            settingsService.desktopCavaBarCount = Math.max(12, Math.min(72, Math.round(Number(prefs.desktopCavaBarCount))));

                        if (prefs.desktopCavaSpacing !== undefined)
                            settingsService.desktopCavaSpacing = Math.max(0, Math.min(12, Math.round(Number(prefs.desktopCavaSpacing))));

                        if (["gradient", "accent", "complementary"].indexOf(prefs.desktopCavaColorMode) !== -1)
                            settingsService.desktopCavaColorMode = prefs.desktopCavaColorMode;

                        if (prefs.shadowGlowEnabled !== undefined)
                            settingsService.shadowGlowEnabled = Boolean(prefs.shadowGlowEnabled);

                        if (["accent", "complementary"].indexOf(prefs.shadowGlowMode) !== -1)
                            settingsService.shadowGlowMode = prefs.shadowGlowMode;

                        if (prefs.shadowGlowOpacity !== undefined)
                            settingsService.shadowGlowOpacity = Math.max(5, Math.min(100, Math.round(Number(prefs.shadowGlowOpacity))));

                        if (["overshot", "spring", "ease", "snappy"].indexOf(prefs.hyprAnimCurve) !== -1)
                            settingsService.hyprAnimCurve = prefs.hyprAnimCurve;

                        if (["popin 80%", "popin 60%", "slide", "gnomed"].indexOf(prefs.hyprAnimWindowStyle) !== -1)
                            settingsService.hyprAnimWindowStyle = prefs.hyprAnimWindowStyle;

                        if (["slide", "slidevert", "slidefade 20%", "fade"].indexOf(prefs.hyprAnimWorkspaceStyle) !== -1)
                            settingsService.hyprAnimWorkspaceStyle = prefs.hyprAnimWorkspaceStyle;

                        if (prefs.hyprAnimBorderSpin !== undefined)
                            settingsService.hyprAnimBorderSpin = Boolean(prefs.hyprAnimBorderSpin);

                        if (prefs.hyprAnimBorderSpeed !== undefined)
                            settingsService.hyprAnimBorderSpeed = Math.max(15, Math.min(120, Math.round(Number(prefs.hyprAnimBorderSpeed))));

                        if (prefs.hyprAnimLayers !== undefined)
                            settingsService.hyprAnimLayers = Boolean(prefs.hyprAnimLayers);

                        if (["none", "vibrance", "film-grain", "crt", "warm"].indexOf(prefs.hyprScreenShader) !== -1)
                            settingsService.hyprScreenShader = prefs.hyprScreenShader;

                        if (prefs.uiSoundsEnabled !== undefined)
                            settingsService.uiSoundsEnabled = Boolean(prefs.uiSoundsEnabled);

                        if (["horizontal", "stacked"].indexOf(prefs.lockScreenClockLayout) !== -1)
                            settingsService.lockScreenClockLayout = prefs.lockScreenClockLayout;

                        if (["thin", "regular", "bold"].indexOf(prefs.lockScreenClockWeight) !== -1)
                            settingsService.lockScreenClockWeight = prefs.lockScreenClockWeight;

                        if (prefs.autoBatteryEyeCandy !== undefined)
                            settingsService.autoBatteryEyeCandy = Boolean(prefs.autoBatteryEyeCandy);

                        if (prefs.autoBatteryDim !== undefined)
                            settingsService.autoBatteryDim = Boolean(prefs.autoBatteryDim);

                        if (prefs.pinnedLauncherApps !== undefined)
                            settingsService.pinnedLauncherApps = prefs.pinnedLauncherApps;
                        if (prefs.recentLauncherApps !== undefined)
                            settingsService.recentLauncherApps = prefs.recentLauncherApps;
                        if (["none", "output", "input", "both"].indexOf(prefs.screenRecordAudioSource) !== -1)
                            settingsService.screenRecordAudioSource = prefs.screenRecordAudioSource;
                        if (["source", "1080p", "720p", "480p"].indexOf(prefs.screenRecordResolution) !== -1)
                            settingsService.screenRecordResolution = prefs.screenRecordResolution;
                        if (prefs.screenCaptureIncludeCursor !== undefined)
                            settingsService.screenCaptureIncludeCursor = Boolean(prefs.screenCaptureIncludeCursor);
                        if (typeof prefs.defaultTerminalCommand === "string" && prefs.defaultTerminalCommand !== "")
                            settingsService.defaultTerminalCommand = prefs.defaultTerminalCommand;
                        if (typeof prefs.defaultBrowserAppId === "string")
                            settingsService.defaultBrowserAppId = prefs.defaultBrowserAppId;
                        if (typeof prefs.defaultCodingAppId === "string")
                            settingsService.defaultCodingAppId = prefs.defaultCodingAppId;
                        if (typeof prefs.defaultFileManagerAppId === "string")
                            settingsService.defaultFileManagerAppId = prefs.defaultFileManagerAppId;
                        if (typeof prefs.defaultTextEditorAppId === "string")
                            settingsService.defaultTextEditorAppId = prefs.defaultTextEditorAppId;
                        if (typeof prefs.defaultImageViewerAppId === "string")
                            settingsService.defaultImageViewerAppId = prefs.defaultImageViewerAppId;
                        if (typeof prefs.defaultVideoPlayerAppId === "string")
                            settingsService.defaultVideoPlayerAppId = prefs.defaultVideoPlayerAppId;
                        if (typeof prefs.defaultMusicPlayerAppId === "string")
                            settingsService.defaultMusicPlayerAppId = prefs.defaultMusicPlayerAppId;
                        if (typeof prefs.defaultPdfViewerAppId === "string")
                            settingsService.defaultPdfViewerAppId = prefs.defaultPdfViewerAppId;

                        if (typeof prefs.adaptivePowerEnabled === "boolean")
                            settingsService.adaptivePowerEnabled = prefs.adaptivePowerEnabled;

                        const validPowerProfiles = ["power-saver", "balanced", "performance"];
                        if (typeof prefs.powerProfile === "string" && validPowerProfiles.includes(prefs.powerProfile)) {
                            SystemInfoService.powerProfile = prefs.powerProfile;
                            if (!settingsService.adaptivePowerEnabled)
                                SystemInfoService.applyProfile(prefs.powerProfile);
                        } else if (!settingsService.adaptivePowerEnabled) {
                            SystemInfoService.applyProfile("balanced");
                        }
                        if (prefs.packageManagerChecksEnabled !== undefined)
                            UpdateService.packageManagerChecksEnabled = prefs.packageManagerChecksEnabled;

                        if (prefs.packageManagerCheckInterval !== undefined)
                            UpdateService.packageManagerCheckInterval = prefs.packageManagerCheckInterval;

                        if (prefs.clipboardMaxItems !== undefined)
                            settingsService.clipboardMaxItems = prefs.clipboardMaxItems;

                        if (prefs.animationSpeedFactor !== undefined)
                            HyprlandService.animationSpeedFactor = prefs.animationSpeedFactor;

                        if (prefs.githubUsername !== undefined)
                            settingsService.githubUsername = prefs.githubUsername;

                        if (typeof prefs.githubToken === "string" && prefs.githubToken !== "") {
                            // One-time migration from older plaintext settings files.
                            settingsService.githubToken = prefs.githubToken;
                            settingsService.legacyGithubTokenFound = true;
                        }

                        if (prefs.musicPlayer !== undefined)
                            settingsService.musicPlayer = prefs.musicPlayer;

                        if (prefs.musicPlayerCommand !== undefined)
                            settingsService.musicPlayerCommand = prefs.musicPlayerCommand;

                        if (prefs.nightLightActive !== undefined)
                            DisplayProfileService.nightLightActive = prefs.nightLightActive;

                        if (prefs.caffeineActive !== undefined)
                            DisplayProfileService.caffeineActive = prefs.caffeineActive;

                        if (prefs.gameModeActive !== undefined)
                            DisplayProfileService.gameModeActive = prefs.gameModeActive;

                        if (prefs.nightLightTemperature !== undefined)
                            DisplayProfileService.nightLightTemperature = prefs.nightLightTemperature;

                        if (prefs.keyboardLayout !== undefined)
                            HyprlandService.keyboardLayout = prefs.keyboardLayout;

                        if (prefs.enabledKbLayouts !== undefined)
                            settingsService.enabledKbLayouts = prefs.enabledKbLayouts;

                        if (prefs.wpAutoShuffle !== undefined)
                            HyprlandService.wpAutoShuffle = prefs.wpAutoShuffle;

                        if (prefs.wpShuffleInterval !== undefined)
                            HyprlandService.wpShuffleInterval = prefs.wpShuffleInterval;

                        if (prefs.wpEnableTransitions !== undefined)
                            HyprlandService.wpEnableTransitions = prefs.wpEnableTransitions;

                        if (prefs.wpTransitionType !== undefined)
                            HyprlandService.wpTransitionType = prefs.wpTransitionType;

                        if (prefs.wpTransitionPos !== undefined)
                            HyprlandService.wpTransitionPos = prefs.wpTransitionPos;

                        if (prefs.wpTransitionStep !== undefined)
                            HyprlandService.wpTransitionStep = prefs.wpTransitionStep;

                        if (prefs.wpTransitionFps !== undefined)
                            HyprlandService.wpTransitionFps = prefs.wpTransitionFps;

                        if (prefs.wpTransitionAngle !== undefined)
                            HyprlandService.wpTransitionAngle = prefs.wpTransitionAngle;

                        if (prefs.wpResizeMode !== undefined)
                            HyprlandService.wpResizeMode = prefs.wpResizeMode;

                        if (prefs.wpCropGravity !== undefined)
                            HyprlandService.wpCropGravity = prefs.wpCropGravity;

                        if (typeof prefs.wallpaperDirectory === "string" && prefs.wallpaperDirectory.trim() !== "")
                            settingsService.setWallpaperDirectory(prefs.wallpaperDirectory);

                        if (prefs.micVolume !== undefined) {
                            AudioService.micVolume = AudioService.hasPhysicalMic ? prefs.micVolume : 0;
                            if (AudioService.hasPhysicalMic)
                                AudioService.setMicVolume(prefs.micVolume);

                        }
                        if (prefs.micMuted !== undefined) {
                            AudioService.micMuted = AudioService.hasPhysicalMic ? prefs.micMuted : true;
                            if (AudioService.hasPhysicalMic)
                                AudioService.setMicMuted(prefs.micMuted);

                        }
                        if (prefs.quoteCategory !== undefined)
                            settingsService.quoteCategory = prefs.quoteCategory;

                        if (prefs.fontFamily !== undefined)
                            settingsService.fontFamily = prefs.fontFamily;

                        if (prefs.fontScale !== undefined)
                            settingsService.fontScale = prefs.fontScale;

                        if (prefs.packageManagerMode === "install" || prefs.packageManagerMode === "update")
                            settingsService.packageManagerMode = prefs.packageManagerMode;
                        if (prefs.clock24h !== undefined)
                            settingsService.clock24h = prefs.clock24h;

                        if (prefs.clockSeconds !== undefined)
                            settingsService.clockSeconds = prefs.clockSeconds;

                        if (prefs.trayIconSize !== undefined)
                            settingsService.trayIconSize = prefs.trayIconSize;

                        if (prefs.clockShowDate !== undefined)
                            settingsService.clockShowDate = prefs.clockShowDate;
                        if (prefs.clockWeatherEnabled !== undefined)
                            settingsService.clockWeatherEnabled = prefs.clockWeatherEnabled;
                        if (prefs.clockWeatherLocation !== undefined)
                            settingsService.clockWeatherLocation = prefs.clockWeatherLocation;
                        if (prefs.shellBackgroundOpacity !== undefined) {
                            const shellOpacity = Number(prefs.shellBackgroundOpacity);
                            if (Number.isFinite(shellOpacity))
                                settingsService.shellBackgroundOpacity = Math.max(0.3, Math.min(1, shellOpacity));
                        }
                        if (prefs.islandBackgroundOpacity !== undefined) {
                            const islandOpacity = Number(prefs.islandBackgroundOpacity);
                            if (Number.isFinite(islandOpacity))
                                settingsService.islandBackgroundOpacity = Math.max(0.3, Math.min(1, islandOpacity));
                        }
                        if (prefs.islandBackdropBlur !== undefined)
                            settingsService.islandBackdropBlur = Boolean(prefs.islandBackdropBlur);
                        if (prefs.islandBorderEnabled !== undefined)
                            settingsService.islandBorderEnabled = Boolean(prefs.islandBorderEnabled);
                        if (prefs.islandBorderWidth !== undefined) {
                            const borderWidth = Number(prefs.islandBorderWidth);
                            if (Number.isFinite(borderWidth))
                                settingsService.islandBorderWidth = Math.max(0.5, Math.min(3, borderWidth));
                        }
                        if (prefs.islandBorderColorMode !== undefined && ["gradient", "accent", "subtle"].includes(prefs.islandBorderColorMode))
                            settingsService.islandBorderColorMode = prefs.islandBorderColorMode;
                        if (prefs.islandShadowEnabled !== undefined)
                            settingsService.islandShadowEnabled = Boolean(prefs.islandShadowEnabled);
                        if (prefs.islandShadowStrength !== undefined) {
                            const shadowStrength = Number(prefs.islandShadowStrength);
                            if (Number.isFinite(shadowStrength))
                                settingsService.islandShadowStrength = Math.max(0, Math.min(100, Math.round(shadowStrength)));
                        }
                        if (prefs.convexBarHeight !== undefined) {
                            const convexHeight = Number(prefs.convexBarHeight);
                            if (Number.isFinite(convexHeight))
                                settingsService.convexBarHeight = Math.max(28, Math.min(56, Math.round(convexHeight)));
                        }
                        if (prefs.convexTopInset !== undefined) {
                            const convexInset = Number(prefs.convexTopInset);
                            if (Number.isFinite(convexInset))
                                settingsService.convexTopInset = Math.max(0, Math.min(12, Math.round(convexInset)));
                        }
                        if (prefs.convexCornerRadius !== undefined) {
                            const convexRadius = Number(prefs.convexCornerRadius);
                            if (Number.isFinite(convexRadius))
                                settingsService.convexCornerRadius = Math.max(0, Math.min(24, Math.round(convexRadius)));
                        }
                        if (prefs.convexNotchFlare !== undefined) {
                            const convexFlare = Number(prefs.convexNotchFlare);
                            if (Number.isFinite(convexFlare))
                                settingsService.convexNotchFlare = Math.max(0, Math.min(32, Math.round(convexFlare)));
                        }
                        if (prefs.convexBackgroundOpacity !== undefined) {
                            const convexOpacity = Number(prefs.convexBackgroundOpacity);
                            if (Number.isFinite(convexOpacity))
                                settingsService.convexBackgroundOpacity = Math.max(0.3, Math.min(1, convexOpacity));
                        }
                        if (prefs.convexBackdropBlur !== undefined)
                            settingsService.convexBackdropBlur = Boolean(prefs.convexBackdropBlur);
                        if (prefs.convexBorderEnabled !== undefined)
                            settingsService.convexBorderEnabled = Boolean(prefs.convexBorderEnabled);
                        if (prefs.convexBorderWidth !== undefined) {
                            const convexBorderWidth = Number(prefs.convexBorderWidth);
                            if (Number.isFinite(convexBorderWidth))
                                settingsService.convexBorderWidth = Math.max(0.5, Math.min(3, convexBorderWidth));
                        }
                        if (prefs.convexBorderColorMode !== undefined && ["gradient", "accent", "subtle"].includes(prefs.convexBorderColorMode))
                            settingsService.convexBorderColorMode = prefs.convexBorderColorMode;
                        if (prefs.convexShadowEnabled !== undefined)
                            settingsService.convexShadowEnabled = Boolean(prefs.convexShadowEnabled);
                        if (prefs.convexFrameEnabled !== undefined)
                            settingsService.convexFrameEnabled = Boolean(prefs.convexFrameEnabled);
                        if (prefs.convexFrameSize !== undefined) {
                            const convexFrameSize = Number(prefs.convexFrameSize);
                            if (Number.isFinite(convexFrameSize))
                                settingsService.convexFrameSize = Math.max(0, Math.min(16, Math.round(convexFrameSize)));
                        }
                        if (prefs.lockScreenShowClock !== undefined)
                            settingsService.lockScreenShowClock = Boolean(prefs.lockScreenShowClock);
                        if (prefs.lockScreenShowDate !== undefined)
                            settingsService.lockScreenShowDate = Boolean(prefs.lockScreenShowDate);
                        if (prefs.lockScreenShowSeconds !== undefined)
                            settingsService.lockScreenShowSeconds = Boolean(prefs.lockScreenShowSeconds);
                        if (prefs.lockScreen24h !== undefined)
                            settingsService.lockScreen24h = Boolean(prefs.lockScreen24h);
                        if (prefs.lockScreenShowMedia !== undefined)
                            settingsService.lockScreenShowMedia = Boolean(prefs.lockScreenShowMedia);
                        if (prefs.lockScreenShowMediaState !== undefined)
                            settingsService.lockScreenShowMediaState = Boolean(prefs.lockScreenShowMediaState);
                        if (prefs.lockScreenShowBattery !== undefined)
                            settingsService.lockScreenShowBattery = Boolean(prefs.lockScreenShowBattery);
                        if (prefs.lockScreenClockStyle !== undefined) {
                            const style = String(prefs.lockScreenClockStyle);
                            settingsService.lockScreenClockStyle = ["classic", "compact", "minimal"].includes(style) ? style : "classic";
                        }
                        if (prefs.lockScreenAdaptiveContrast !== undefined)
                            settingsService.lockScreenAdaptiveContrast = Boolean(prefs.lockScreenAdaptiveContrast);
                        if (prefs.lockScreenBackgroundBlur !== undefined)
                            settingsService.lockScreenBackgroundBlur = Math.max(0, Math.min(1, Number(prefs.lockScreenBackgroundBlur)));
                        if (prefs.lockScreenBackgroundDim !== undefined)
                            settingsService.lockScreenBackgroundDim = Math.max(0, Math.min(0.95, Number(prefs.lockScreenBackgroundDim)));

                        if (prefs.notificationsPopupsEnabled !== undefined)
                            settingsService.notificationsPopupsEnabled = Boolean(prefs.notificationsPopupsEnabled);
                        if (prefs.notificationsDndEnabled !== undefined)
                            settingsService.notificationsDndEnabled = Boolean(prefs.notificationsDndEnabled);
                        if (prefs.notificationsCriticalDuringDnd !== undefined)
                            settingsService.notificationsCriticalDuringDnd = Boolean(prefs.notificationsCriticalDuringDnd);
                        if (prefs.notificationGroupingEnabled !== undefined)
                            settingsService.notificationGroupingEnabled = Boolean(prefs.notificationGroupingEnabled);
                        if (prefs.notificationPopupDuration !== undefined)
                            settingsService.notificationPopupDuration = Math.max(2, Math.min(15, Math.round(Number(prefs.notificationPopupDuration))));
                        if (prefs.notificationHistoryLimit !== undefined)
                            settingsService.notificationHistoryLimit = Math.max(10, Math.min(100, Math.round(Number(prefs.notificationHistoryLimit))));
                        if (prefs.notificationQuietHoursEnabled !== undefined)
                            settingsService.notificationQuietHoursEnabled = Boolean(prefs.notificationQuietHoursEnabled);
                        if (prefs.notificationDndWhileMediaPlaying !== undefined)
                            settingsService.notificationDndWhileMediaPlaying = Boolean(prefs.notificationDndWhileMediaPlaying);
                        if (prefs.notificationQuietHoursStartHour !== undefined)
                            settingsService.notificationQuietHoursStartHour = Math.max(0, Math.min(23, Math.round(Number(prefs.notificationQuietHoursStartHour))));
                        if (prefs.notificationQuietHoursEndHour !== undefined)
                            settingsService.notificationQuietHoursEndHour = Math.max(0, Math.min(23, Math.round(Number(prefs.notificationQuietHoursEndHour))));
                        if (prefs.notificationAppPopupRules !== undefined && prefs.notificationAppPopupRules !== null && typeof prefs.notificationAppPopupRules === "object" && !Array.isArray(prefs.notificationAppPopupRules)) {
                            const validRules = {};
                            for (const appKey in prefs.notificationAppPopupRules) {
                                if (Object.prototype.hasOwnProperty.call(prefs.notificationAppPopupRules, appKey) && prefs.notificationAppPopupRules[appKey] === false)
                                    validRules[String(appKey).trim().toLowerCase()] = false;
                            }
                            settingsService.notificationAppPopupRules = validRules;
                        }

                        if (prefs.cursorTheme !== undefined)
                            settingsService.cursorTheme = prefs.cursorTheme;

                        if (prefs.cursorSize !== undefined)
                            settingsService.cursorSize = prefs.cursorSize;

                        applyCursor(settingsService.cursorTheme, settingsService.cursorSize);
                        applyFont(settingsService.fontFamily, Math.round(11 * settingsService.fontScale));
                        if (prefs.barStyle === "island" || prefs.barStyle === "convex")
                            settingsService.barStyle = prefs.barStyle;
                        if (prefs.barIslandExpanded !== undefined)
                            settingsService.barIslandExpanded = prefs.barIslandExpanded;

                        if (prefs.islandRightMode !== undefined)
                            settingsService.islandRightMode = prefs.islandRightMode;
                        if (prefs.islandLeftWidget !== undefined && ["sysmon", "workspaces"].includes(prefs.islandLeftWidget))
                            settingsService.islandLeftWidget = prefs.islandLeftWidget;
                        if (prefs.islandCenterWidget !== undefined && ["clock", "workspaces", "clock_workspaces"].includes(prefs.islandCenterWidget))
                            settingsService.islandCenterWidget = prefs.islandCenterWidget;

                        if (prefs.islandWidthScale !== undefined) {
                            const widthScale = Number(prefs.islandWidthScale);
                            if (Number.isFinite(widthScale))
                                settingsService.islandWidthScale = Math.max(80, Math.min(150, Math.round(widthScale)));
                        }
                        if (prefs.islandHeight !== undefined) {
                            const islandHeight = Number(prefs.islandHeight);
                            if (Number.isFinite(islandHeight))
                                settingsService.islandHeight = Math.max(24, Math.min(48, Math.round(islandHeight)));
                        }
                        if (prefs.islandGap !== undefined) {
                            const islandGap = Number(prefs.islandGap);
                            if (Number.isFinite(islandGap))
                                settingsService.islandGap = Math.max(4, Math.min(24, Math.round(islandGap)));
                        }
                        if (prefs.islandCornerRadius !== undefined) {
                            const islandRadius = Number(prefs.islandCornerRadius);
                            if (Number.isFinite(islandRadius))
                                settingsService.islandCornerRadius = Math.max(8, Math.min(24, Math.round(islandRadius)));
                        }

                        // Migrate the old shared width/height values to each capsule
                        // unless a newer independent value is already stored.
                        const legacyIslandWidth = Math.max(70, Math.min(160, Math.round(Number(settingsService.islandWidthScale) || 100)));
                        const legacyIslandHeight = Math.max(24, Math.min(56, Math.round(Number(settingsService.islandHeight) || 32)));
                        const capsuleKeys = [
                            ["islandLeftWidthScale", "islandLeftHeight"],
                            ["islandCenterWidthScale", "islandCenterHeight"],
                            ["islandRightWidthScale", "islandRightHeight"]
                        ];
                        for (let i = 0; i < capsuleKeys.length; i++) {
                            const widthKey = capsuleKeys[i][0];
                            const heightKey = capsuleKeys[i][1];
                            if (prefs[widthKey] !== undefined) {
                                const widthValue = Number(prefs[widthKey]);
                                if (Number.isFinite(widthValue))
                                    settingsService[widthKey] = Math.max(70, Math.min(160, Math.round(widthValue)));
                            } else {
                                settingsService[widthKey] = legacyIslandWidth;
                            }
                            if (prefs[heightKey] !== undefined) {
                                const heightValue = Number(prefs[heightKey]);
                                if (Number.isFinite(heightValue))
                                    settingsService[heightKey] = Math.max(24, Math.min(56, Math.round(heightValue)));
                            } else {
                                settingsService[heightKey] = legacyIslandHeight;
                            }
                        }

                        if (prefs.barSlotL1 !== undefined)
                            settingsService.barSlotL1 = prefs.barSlotL1;

                        if (prefs.barSlotL2 !== undefined)
                            settingsService.barSlotL2 = prefs.barSlotL2;

                        if (prefs.barSlotL3 !== undefined)
                            settingsService.barSlotL3 = prefs.barSlotL3;

                        if (prefs.barSlotC1 !== undefined)
                            settingsService.barSlotC1 = prefs.barSlotC1;

                        if (prefs.barSlotC2 !== undefined)
                            settingsService.barSlotC2 = prefs.barSlotC2;

                        if (prefs.barSlotR1 !== undefined)
                            settingsService.barSlotR1 = prefs.barSlotR1;

                        if (prefs.barSlotR2 !== undefined)
                            settingsService.barSlotR2 = prefs.barSlotR2;

                        if (prefs.barSlotR3 !== undefined)
                            settingsService.barSlotR3 = prefs.barSlotR3;

                        if (prefs.appThemeZenBrowserEnabled !== undefined)
                            settingsService.appThemeZenBrowserEnabled = prefs.appThemeZenBrowserEnabled;
                        if (prefs.appThemeSpicetifyEnabled !== undefined)
                            settingsService.appThemeSpicetifyEnabled = prefs.appThemeSpicetifyEnabled;
                        if (prefs.appThemeHeroicEnabled !== undefined)
                            settingsService.appThemeHeroicEnabled = prefs.appThemeHeroicEnabled;
                        if (prefs.appThemePapirusEnabled !== undefined)
                            settingsService.appThemePapirusEnabled = prefs.appThemePapirusEnabled;
                        if (prefs.appThemeTelegramEnabled !== undefined)
                            settingsService.appThemeTelegramEnabled = prefs.appThemeTelegramEnabled;
                        if (prefs.appThemeVSCodiumEnabled !== undefined)
                            settingsService.appThemeVSCodiumEnabled = prefs.appThemeVSCodiumEnabled;
                        if (prefs.dynamicThemeGtkEnabled !== undefined)
                            settingsService.dynamicThemeGtkEnabled = prefs.dynamicThemeGtkEnabled;
                        if (prefs.dynamicThemeKColorSchemeEnabled !== undefined)
                            settingsService.dynamicThemeKColorSchemeEnabled = prefs.dynamicThemeKColorSchemeEnabled;
                        if (prefs.dynamicThemeHyprlandEnabled !== undefined)
                            settingsService.dynamicThemeHyprlandEnabled = prefs.dynamicThemeHyprlandEnabled;
                        if (prefs.dynamicThemeKittyEnabled !== undefined)
                            settingsService.dynamicThemeKittyEnabled = prefs.dynamicThemeKittyEnabled;
                        if (prefs.dynamicThemeNeovimEnabled !== undefined)
                            settingsService.dynamicThemeNeovimEnabled = prefs.dynamicThemeNeovimEnabled;
                        if (prefs.dynamicThemeQtEnabled !== undefined)
                            settingsService.dynamicThemeQtEnabled = prefs.dynamicThemeQtEnabled;
                        if (prefs.dynamicThemeStarshipEnabled !== undefined)
                            settingsService.dynamicThemeStarshipEnabled = prefs.dynamicThemeStarshipEnabled;
                        if (prefs.dynamicThemeBtopEnabled !== undefined)
                            settingsService.dynamicThemeBtopEnabled = prefs.dynamicThemeBtopEnabled;
                        if (prefs.dynamicThemeLazygitEnabled !== undefined)
                            settingsService.dynamicThemeLazygitEnabled = prefs.dynamicThemeLazygitEnabled;
                        if (prefs.dynamicThemeSvgAssetsEnabled !== undefined)
                            settingsService.dynamicThemeSvgAssetsEnabled = prefs.dynamicThemeSvgAssetsEnabled;

                    } catch (e) {
                        console.error("Error loading settings: " + e);
                        // Preserve the corrupt file for manual recovery and
                        // leave defaults in memory; do not overwrite it.
                        settingsService.settingsWriteBlocked = true;
                        settingsService.settingsLoadIssue = "file could not be parsed";
                        saveTimer.stop();
                        corruptSettingsBackupProc.running = true;
                        if (!settingsService.adaptivePowerEnabled)
                            SystemInfoService.applyProfile("balanced");
                    }
                }
                settingsService.settingsLoaded = true;
                Qt.callLater(SystemInfoService.syncAdaptiveProfile);
                settingsService.loadGithubToken();
            }
        }

    }

    Process {
        id: corruptSettingsBackupProc

        command: [
            "bash",
            "-c",
            "f=\"$1\"; b=\"\"; if [ -e \"$f\" ]; then b=\"$f.bak-$(date +%Y%m%d-%H%M%S)\"; mv -- \"$f\" \"$b\" || exit 0; fi; if [ -n \"$b\" ]; then notify-send -u critical -a Veyra 'Veyra: settings could not be read' \"Kept as $(basename \"$b\") — defaults are in use this session.\" >/dev/null 2>&1 || true; fi",
            "veyra-settings-backup",
            XdgPaths.stateDir + "/settings_prefs.json"
        ]
    }

    onAdaptivePowerEnabledChanged: {
        if (settingsLoaded) {
            saveSettings();
            Qt.callLater(SystemInfoService.syncAdaptiveProfile);
        }
    }
    onShellBackgroundOpacityChanged: { if (settingsLoaded) saveSettings(); }
    onIslandWidthScaleChanged: { if (settingsLoaded) saveSettings(); }
    onIslandHeightChanged: { if (settingsLoaded) saveSettings(); }
    onIslandGapChanged: { if (settingsLoaded) saveSettings(); }
    onIslandCornerRadiusChanged: { if (settingsLoaded) saveSettings(); }
    onIslandLeftWidthScaleChanged: { if (settingsLoaded) saveSettings(); }
    onIslandLeftHeightChanged: { if (settingsLoaded) saveSettings(); }
    onIslandCenterWidthScaleChanged: { if (settingsLoaded) saveSettings(); }
    onIslandCenterHeightChanged: { if (settingsLoaded) saveSettings(); }
    onIslandRightWidthScaleChanged: { if (settingsLoaded) saveSettings(); }
    onIslandRightHeightChanged: { if (settingsLoaded) saveSettings(); }
    onIslandBackdropBlurChanged: { if (settingsLoaded) saveSettings(); }
    onIslandBackgroundOpacityChanged: { if (settingsLoaded) saveSettings(); }
    onIslandBorderEnabledChanged: { if (settingsLoaded) saveSettings(); }
    onIslandBorderWidthChanged: { if (settingsLoaded) saveSettings(); }
    onIslandBorderColorModeChanged: { if (settingsLoaded) saveSettings(); }
    onIslandShadowEnabledChanged: { if (settingsLoaded) saveSettings(); }
    onIslandShadowStrengthChanged: { if (settingsLoaded) saveSettings(); }
    onConvexBarHeightChanged: { if (settingsLoaded) saveSettings(); }
    onConvexTopInsetChanged: { if (settingsLoaded) saveSettings(); }
    onConvexCornerRadiusChanged: { if (settingsLoaded) saveSettings(); }
    onConvexNotchFlareChanged: { if (settingsLoaded) saveSettings(); }
    onConvexBackdropBlurChanged: { if (settingsLoaded) saveSettings(); }
    onConvexBackgroundOpacityChanged: { if (settingsLoaded) saveSettings(); }
    onConvexBorderEnabledChanged: { if (settingsLoaded) saveSettings(); }
    onConvexBorderWidthChanged: { if (settingsLoaded) saveSettings(); }
    onConvexBorderColorModeChanged: { if (settingsLoaded) saveSettings(); }
    onConvexShadowEnabledChanged: { if (settingsLoaded) saveSettings(); }
    onConvexFrameEnabledChanged: { if (settingsLoaded) saveSettings(); }
    onConvexFrameSizeChanged: { if (settingsLoaded) saveSettings(); }
    onLockScreenShowClockChanged: { if (settingsLoaded) saveSettings(); }
    onLockScreenShowDateChanged: { if (settingsLoaded) saveSettings(); }
    onLockScreenShowSecondsChanged: { if (settingsLoaded) saveSettings(); }
    onLockScreen24hChanged: { if (settingsLoaded) saveSettings(); }
    onLockScreenShowMediaChanged: { if (settingsLoaded) saveSettings(); }
    onLockScreenShowMediaStateChanged: { if (settingsLoaded) saveSettings(); }
    onLockScreenShowBatteryChanged: { if (settingsLoaded) saveSettings(); }
    onLockScreenClockStyleChanged: { if (settingsLoaded) saveSettings(); }
    onLockScreenAdaptiveContrastChanged: { if (settingsLoaded) saveSettings(); }
    onLockScreenBackgroundBlurChanged: { if (settingsLoaded) saveSettings(); }
    onLockScreenBackgroundDimChanged: { if (settingsLoaded) saveSettings(); }
    onNotificationsPopupsEnabledChanged: { if (settingsLoaded) saveSettings(); }
    onNotificationsDndEnabledChanged: { if (settingsLoaded) saveSettings(); }
    onNotificationsCriticalDuringDndChanged: { if (settingsLoaded) saveSettings(); }
    onNotificationGroupingEnabledChanged: { if (settingsLoaded) saveSettings(); }
    onNotificationPopupDurationChanged: { if (settingsLoaded) saveSettings(); }
    onNotificationHistoryLimitChanged: { if (settingsLoaded) saveSettings(); }
    onNotificationQuietHoursEnabledChanged: { if (settingsLoaded) saveSettings(); }
    onNotificationDndWhileMediaPlayingChanged: { if (settingsLoaded) saveSettings(); }
    onNotificationQuietHoursStartHourChanged: { if (settingsLoaded) saveSettings(); }
    onNotificationQuietHoursEndHourChanged: { if (settingsLoaded) saveSettings(); }
    onNotificationAppPopupRulesChanged: { if (settingsLoaded) saveSettings(); }

    onAppThemeZenBrowserEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onAppThemeSpicetifyEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onAppThemeHeroicEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onAppThemePapirusEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onAppThemeTelegramEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onAppThemeVSCodiumEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }

    onDynamicThemeGtkEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDynamicThemeKColorSchemeEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDynamicThemeHyprlandEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDynamicThemeKittyEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDynamicThemeNeovimEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDynamicThemeQtEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDynamicThemeStarshipEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDynamicThemeBtopEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDynamicThemeLazygitEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDynamicThemeSvgAssetsEnabledChanged: {
        if (settingsLoaded)
            saveSettings();
    }

    Process {
        id: githubTokenStoreProc
        stdinEnabled: true
        onExited: function(exitCode) {
            if (!settingsService.migratingGithubToken)
                return;
            settingsService.migratingGithubToken = false;
            if (exitCode === 0) {
                settingsService.legacyGithubTokenFound = false;
                settingsService.githubTokenReady = true;
                settingsService.saveSettings();
            } else {
                // Preserve the legacy value in the preferences file for a later retry.
                settingsService.githubTokenReady = true;
                settingsService.saveSettings();
                console.warn("Veyra: secure GitHub token migration failed; retaining the old preference for retry.");
            }
        }
    }

    Process {
        id: githubTokenLoadProc
        command: ["python3", Quickshell.shellDir + "/Scripts/system/github_token.py", "get"]
        stdout: StdioCollector { id: githubTokenOutput }
        onExited: function(exitCode) {
            settingsService.loadingGithubToken = true;
            settingsService.githubToken = exitCode === 0 ? githubTokenOutput.text.trim() : "";
            settingsService.loadingGithubToken = false;
            settingsService.githubTokenReady = true;
        }
    }

    Process {
        id: settingsSaver
        stdinEnabled: true
        onExited: (exitCode) => {
            if (!settingsService.settingsRestartAfterWrite || !settingsService.settingsRestartWriteStarted)
                return;
            settingsService.settingsRestartWriteStarted = false;
            if (exitCode !== 0) {
                settingsService.settingsRestartAfterWrite = false;
                console.error("Veyra restart canceled: settings writer failed with exit code " + exitCode);
                return;
            }
            // A newer save may have been queued while this write was running.
            // Let that timer write the newest snapshot before restarting.
            if (saveTimer.running)
                return;

            settingsService.settingsRestartAfterWrite = false;
            settingsRestartProc.startDetached();
        }
    }

    // Detached so the restart command survives the current Quickshell instance.
    // Scope the kill to this config path so other Quickshell instances are untouched.
    Process {
        id: settingsRestartProc
        command: ["bash", "-c", "sleep 0.25; qs kill -p \"$1\" >/dev/null 2>&1 || true; exec qs -p \"$1\"", "veyra-restart", Quickshell.shellDir]
    }

    Process {
        id: applyCursorProc
    }

    Process {
        id: applyFontProc
    }

}
