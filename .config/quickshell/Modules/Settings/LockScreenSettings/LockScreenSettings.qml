import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Settings.Components

AppContainer {
    id: root

    pageTitle: "Lock Screen"
    pageDescription: "Personalize the lock-screen background, clock and visibility."
    pageIcon: "lock"
    property int hypridleLockMinutes: 5
    property int hypridleScreenOffMinutes: 10
    property int hypridleSuspendMinutes: 30
    property bool hypridleHasLock: false
    property bool hypridleHasScreenOff: false
    property bool hypridleHasSuspend: false
    property bool hypridleBusy: false
    property bool hypridleReceivedResponse: false
    property string hypridleProcessMode: "status"
    property string hypridleStatus: "Checking your Hypridle configuration…"

    function handleHypridleResponse(data) {
        let result;
        try {
            result = JSON.parse(data.trim());
        } catch (error) {
            root.hypridleStatus = "Could not read Hypridle's response. Check the Quickshell log.";
            root.hypridleBusy = false;
            root.hypridleReceivedResponse = true;
            return;
        }

        root.hypridleReceivedResponse = true;
        root.hypridleStatus = result.message || (result.ok ? "Hypridle configuration loaded." : "Could not inspect Hypridle configuration.");
        const actions = result.actions || ({});
        if (actions.lock) {
            root.hypridleHasLock = Boolean(actions.lock.found);
            if (actions.lock.found)
                root.hypridleLockMinutes = Math.max(1, Number(actions.lock.minutes));
        }
        if (actions.screen_off) {
            root.hypridleHasScreenOff = Boolean(actions.screen_off.found);
            if (actions.screen_off.found)
                root.hypridleScreenOffMinutes = Math.max(1, Number(actions.screen_off.minutes));
        }
        if (actions.suspend) {
            root.hypridleHasSuspend = Boolean(actions.suspend.found);
            if (actions.suspend.found)
                root.hypridleSuspendMinutes = Math.max(1, Number(actions.suspend.minutes));
        }
        root.hypridleBusy = false;
    }

    function loadHypridleConfig() {
        if (hypridleStatusProcess.running || hypridleApplyProcess.running)
            return;
        root.hypridleProcessMode = "status";
        root.hypridleReceivedResponse = false;
        root.hypridleStatus = "Checking your Hypridle configuration…";
        hypridleStatusProcess.running = true;
    }

    function applyHypridleConfig() {
        if (root.hypridleBusy || !(root.hypridleHasLock || root.hypridleHasScreenOff || root.hypridleHasSuspend))
            return;
        if (root.hypridleHasLock && root.hypridleHasScreenOff && root.hypridleLockMinutes > root.hypridleScreenOffMinutes) {
            root.hypridleStatus = "Please set the lock timeout earlier than display-off so the session is locked before the screen turns off.";
            return;
        }
        if (root.hypridleHasScreenOff && root.hypridleHasSuspend && root.hypridleScreenOffMinutes > root.hypridleSuspendMinutes) {
            root.hypridleStatus = "Please set display-off earlier than suspend so the display can turn off before the laptop suspends.";
            return;
        }
        if (root.hypridleHasLock && root.hypridleHasSuspend && root.hypridleLockMinutes > root.hypridleSuspendMinutes) {
            root.hypridleStatus = "Please set the lock timeout earlier than suspend so the session locks before sleep.";
            return;
        }
        root.hypridleBusy = true;
        root.hypridleProcessMode = "apply";
        root.hypridleReceivedResponse = false;
        root.hypridleStatus = "Updating Hypridle and restarting it…";
        hypridleApplyProcess.command = [
            "python3",
            Quickshell.shellDir + "/Scripts/system/hypridle_settings.py",
            "apply",
            root.hypridleHasLock ? String(root.hypridleLockMinutes) : "-",
            root.hypridleHasScreenOff ? String(root.hypridleScreenOffMinutes) : "-",
            root.hypridleHasSuspend ? String(root.hypridleSuspendMinutes) : "-"
        ];
        hypridleApplyProcess.running = true;
    }

    Component.onCompleted: root.loadHypridleConfig()

    AppGroup {
        title: "Background"
        icon: "picture"

        SettingSpinBox {
            label: "Wallpaper Blur"
            description: "Adjust how soft the current wallpaper looks behind the lock screen"
            from: 0
            to: 1
            stepSize: 0.1
            decimals: 1
            value: SettingsService.lockScreenBackgroundBlur
            defaultValue: 1
            onMoved: (val) => SettingsService.lockScreenBackgroundBlur = Math.max(0, Math.min(1, Number(val.toFixed(1))))
        }

        SettingSpinBox {
            label: "Background Dimming"
            description: "Darken the wallpaper to keep the lock screen text readable"
            from: 0
            to: 95
            stepSize: 5
            suffix: "%"
            value: Math.round(SettingsService.lockScreenBackgroundDim * 100)
            defaultValue: 70
            onMoved: (val) => SettingsService.lockScreenBackgroundDim = Math.max(0, Math.min(0.95, Math.round(val) / 100))
        }

        SettingToggle {
            label: "Adaptive Text Contrast"
            description: "Use high-contrast text colors matched to the wallpaper palette light/dark variant"
            checked: SettingsService.lockScreenAdaptiveContrast
            onCheckedChanged: {
                if (checked !== SettingsService.lockScreenAdaptiveContrast)
                    SettingsService.lockScreenAdaptiveContrast = checked;
            }
        }
    }

    AppGroup {
        title: "Clock & Date"
        icon: "clock"

        ThemedSelect {
            label: "Clock Style"
            description: "Choose the visual size of the lock-screen clock"
            model: ["classic", "compact", "minimal"]
            currentIndex: {
                let idx = model.indexOf(SettingsService.lockScreenClockStyle);
                return idx >= 0 ? idx : 0;
            }
            textMap: ({ "classic": "Classic", "compact": "Compact", "minimal": "Minimal" })
            onActivated: (index) => SettingsService.lockScreenClockStyle = model[index]
        }

        SettingSegmented {
            label: "Clock Layout"
            description: "Display hours and minutes side-by-side or stacked vertically."
            model: [
                { "text": "Horizontal (HH:MM)", "value": "horizontal" },
                { "text": "Stacked (HH / MM)", "value": "stacked" }
            ]
            currentValue: SettingsService.lockScreenClockLayout
            onActivated: (value) => SettingsService.lockScreenClockLayout = value
        }

        SettingSegmented {
            label: "Clock Font Weight"
            description: "Adjust the stroke weight of the lock screen clock digits."
            model: [
                { "text": "Thin", "value": "thin" },
                { "text": "Regular", "value": "regular" },
                { "text": "Bold", "value": "bold" }
            ]
            currentValue: SettingsService.lockScreenClockWeight
            onActivated: (value) => SettingsService.lockScreenClockWeight = value
        }

        SettingToggle {
            label: "Show Clock"
            description: "Display the large clock on the lock screen"
            checked: SettingsService.lockScreenShowClock
            onCheckedChanged: {
                if (checked !== SettingsService.lockScreenShowClock)
                    SettingsService.lockScreenShowClock = checked;
            }
        }

        SettingToggle {
            label: "Show Date"
            description: "Display the date below the clock"
            checked: SettingsService.lockScreenShowDate
            onCheckedChanged: {
                if (checked !== SettingsService.lockScreenShowDate)
                    SettingsService.lockScreenShowDate = checked;
            }
        }

        SettingToggle {
            label: "24-hour Clock"
            description: "Use 24-hour time instead of AM/PM"
            checked: SettingsService.lockScreen24h
            onCheckedChanged: {
                if (checked !== SettingsService.lockScreen24h)
                    SettingsService.lockScreen24h = checked;
            }
        }

        SettingToggle {
            label: "Show Seconds"
            description: "Add seconds to the lock screen clock"
            checked: SettingsService.lockScreenShowSeconds
            onCheckedChanged: {
                if (checked !== SettingsService.lockScreenShowSeconds)
                    SettingsService.lockScreenShowSeconds = checked;
            }
        }
    }

    AppGroup {
        title: "Status Indicators"
        icon: "battery-charging"

        SettingToggle {
            label: "Show Battery Status"
            description: "Display the current battery percentage and charging state when available"
            checked: SettingsService.lockScreenShowBattery
            onCheckedChanged: {
                if (checked !== SettingsService.lockScreenShowBattery)
                    SettingsService.lockScreenShowBattery = checked;
            }
        }
    }

    AppGroup {
        title: "Now Playing"
        icon: "music"

        SettingToggle {
            label: "Show Music Information"
            description: "Show the current track when a media player is available"
            checked: SettingsService.lockScreenShowMedia
            onCheckedChanged: {
                if (checked !== SettingsService.lockScreenShowMedia)
                    SettingsService.lockScreenShowMedia = checked;
            }
        }

        SettingToggle {
            label: "Show Playback State"
            description: "Show a small Playing or Paused label inside the music pill"
            checked: SettingsService.lockScreenShowMediaState
            onCheckedChanged: {
                if (checked !== SettingsService.lockScreenShowMediaState)
                    SettingsService.lockScreenShowMediaState = checked;
            }
            enabled: SettingsService.lockScreenShowMedia
            opacity: enabled ? 1 : 0.5
        }
    }

    AppGroup {
        title: "Hypridle"
        icon: "clock"

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.family: Constants.fontFamily
            font.pixelSize: Constants.sizeSm
            color: Theme.muted
            text: "Set how long the laptop must be idle before the lock screen, display-off action, and suspend action run. Controls only activate when Veyra can identify the matching listener in your existing hypridle.conf."
        }

        SettingSpinBox {
            label: "Lock Screen After"
            description: "Idle time before your configured lock action runs"
            from: 1
            to: 120
            stepSize: 1
            suffix: " min"
            value: root.hypridleLockMinutes
            defaultValue: 5
            enabled: root.hypridleHasLock && !root.hypridleBusy
            onMoved: (val) => root.hypridleLockMinutes = Math.round(val)
        }

        SettingSpinBox {
            label: "Turn Display Off After"
            description: "Idle time before your configured DPMS-off action runs"
            from: 1
            to: 180
            stepSize: 1
            suffix: " min"
            value: root.hypridleScreenOffMinutes
            defaultValue: 10
            enabled: root.hypridleHasScreenOff && !root.hypridleBusy
            onMoved: (val) => root.hypridleScreenOffMinutes = Math.round(val)
        }

        SettingSpinBox {
            label: "Suspend After"
            description: "Idle time before your configured suspend action runs"
            from: 1
            to: 480
            stepSize: 1
            suffix: " min"
            value: root.hypridleSuspendMinutes
            defaultValue: 30
            enabled: root.hypridleHasSuspend && !root.hypridleBusy
            onMoved: (val) => root.hypridleSuspendMinutes = Math.round(val)
        }

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.family: Constants.fontFamily
            font.pixelSize: Constants.sizeSm
            color: Theme.muted
            text: root.hypridleStatus
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            ThemeButton {
                Layout.fillWidth: true
                text: root.hypridleBusy ? "Applying…" : "Apply & Restart Hypridle"
                enabled: !root.hypridleBusy && (root.hypridleHasLock || root.hypridleHasScreenOff || root.hypridleHasSuspend)
                onClicked: root.applyHypridleConfig()
            }

            ThemeButton {
                text: "Rescan"
                enabled: !root.hypridleBusy && !hypridleStatusProcess.running && !hypridleApplyProcess.running
                onClicked: root.loadHypridleConfig()
            }
        }

        Process {
            id: hypridleStatusProcess
            command: ["python3", Quickshell.shellDir + "/Scripts/system/hypridle_settings.py", "status"]

            stdout: SplitParser {
                onRead: (data) => root.handleHypridleResponse(data)
            }
            stderr: SplitParser {
                onRead: (data) => root.hypridleStatus = data.trim()
            }
            onExited: function(exitCode, exitStatus) {
                if (exitCode !== 0 && !root.hypridleReceivedResponse)
                    root.hypridleStatus = "Hypridle inspection failed (exit " + exitCode + "). Check the Quickshell log.";
            }
        }

        Process {
            id: hypridleApplyProcess
            command: []

            stdout: SplitParser {
                onRead: (data) => root.handleHypridleResponse(data)
            }
            stderr: SplitParser {
                onRead: (data) => root.hypridleStatus = data.trim()
            }
            onExited: function(exitCode, exitStatus) {
                if (exitCode !== 0 && !root.hypridleReceivedResponse) {
                    root.hypridleBusy = false;
                    root.hypridleStatus = "Applying Hypridle settings failed (exit " + exitCode + "). Check the Quickshell log.";
                }
            }
        }
    }
}
