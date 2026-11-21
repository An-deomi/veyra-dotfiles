import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Core
pragma Singleton

Item {
    id: systemInfoService

    property string powerProfile: "balanced"
    property string systemProfile: ""
    readonly property string effectivePowerProfile: systemProfile !== "" ? systemProfile : powerProfile
    property bool hasPerformanceProfile: false
    property date currentTime: systemClock.date
    property string osId: "arch"
    readonly property string osName: {
        switch (osId) {
        case "endeavouros":
            return "EndeavourOS";
        case "manjaro":
        case "manjaro-arm":
            return "Manjaro";
        case "garuda":
            return "Garuda Linux";
        case "arcolinux":
            return "ArcoLinux";
        case "cachyos":
            return "CachyOS";
        case "artix":
            return "Artix Linux";
        default:
            return "Arch Linux";
        }
    }
    property bool hasBattery: true
    property int batteryLevel: 100
    property bool lastOnBatteryState: UPower.onBattery
    property bool batteryRulesInitialized: false
    readonly property string batteryPercentage: batteryLevel + "%"
    property string batteryStatus: ""
    property string batteryEstimation: {
        if (!hasBattery)
            return "Continuous power supply active";

        if (batteryStatus === "Charging")
            return "Charging";
        else if (batteryStatus === "Discharging")
            return "Discharging";
        else if (batteryStatus === "Full")
            return "Fully Charged";
        else if (batteryStatus === "Not charging")
            return "Not charging";
        else
            return "Stationary";
    }

    function applyProfile(profile) {
        const targetProfile = String(profile || "");
        if (!["power-saver", "balanced", "performance"].includes(targetProfile)) {
            console.warn("Veyra: ignoring unsupported power profile:", targetProfile);
            return;
        }

        if (XdgPaths.safeTestMode) {
            systemInfoService.powerProfile = targetProfile;
            systemInfoService.systemProfile = targetProfile;
            console.info("Veyra safe test: skipped system power-profile changes.");
            return;
        }

        systemInfoService.powerProfile = targetProfile;
        setPowerProfileProc.command = ["powerprofilesctl", "set", targetProfile];
        setPowerProfileProc.running = false;
        setPowerProfileProc.running = true;

        // Battery mode trims expensive decoration effects (blur/shadows) but
        // keeps compositor animations enabled. Animations are a visual
        // preference, not a power switch, and forcing them off here used to
        // persist `animations:enabled = false` into userprefs.lua.
        if (targetProfile === "power-saver") {
            if (SettingsService.settingsLoaded)
                HyprlandService.setPowerSaverMode(true);
            DisplayProfileService.caffeineActive = false;
        } else {
            if (SettingsService.settingsLoaded)
                HyprlandService.setPowerSaverMode(false);
        }

        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();
    }

    // Adaptive policy: save power on battery and return to balanced on AC.
    // Game Mode temporarily owns the profile and applies its own restoration.
    function syncAdaptiveProfile() {
        if (XdgPaths.safeTestMode
                || !SettingsService.settingsLoaded
                || !SettingsService.adaptivePowerEnabled
                || !systemInfoService.hasPerformanceProfile
                || !systemInfoService.hasBattery
                || DisplayProfileService.gameModeActive)
            return;

        const targetProfile = UPower.onBattery ? "power-saver" : "balanced";
        if (systemInfoService.effectivePowerProfile === targetProfile)
            return;
        if (setPowerProfileProc.running && systemInfoService.powerProfile === targetProfile)
            return;

        systemInfoService.applyProfile(targetProfile);
    }

    SystemClock {
        id: systemClock

        precision: SettingsService.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Process {
        id: setPowerProfileProc

        onExited: (exitCode) => {
            if (exitCode === 0) {
                // Reflect the acknowledged change immediately; the follow-up
                // query remains authoritative for changes made outside Veyra.
                systemInfoService.systemProfile = systemInfoService.powerProfile;
                if (!getProfileProc.running)
                    getProfileProc.running = true;
            } else {
                console.warn("Veyra: power profile change failed with exit code", exitCode);
            }
        }
    }

    Process {
        id: powerProfileSupportProc

        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && powerprofilesctl get >/dev/null 2>&1"]
        running: true
        onExited: (exitCode) => {
            systemInfoService.hasPerformanceProfile = exitCode === 0;
            if (exitCode === 0 && !getProfileProc.running)
                getProfileProc.running = true;
            Qt.callLater(systemInfoService.syncAdaptiveProfile);
        }
    }

    Timer {
        interval: 15000
        running: systemInfoService.hasPerformanceProfile
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!getProfileProc.running)
                getProfileProc.running = true;

        }
    }

    Process {
        id: getProfileProc

        command: ["powerprofilesctl", "get"]

        // Reconcile the desired profile after every query as a safety net.
        // This catches missed UPower source-change signals, so reconnecting AC
        // reliably restores Balanced mode and the normal compositor effects.
        onExited: (exitCode) => {
            if (exitCode === 0)
                Qt.callLater(systemInfoService.syncAdaptiveProfile);
        }

        stdout: SplitParser {
            onRead: (data) => {
                let p = data ? data.trim() : "";
                if (p !== "" && p !== systemInfoService.systemProfile) {
                    systemInfoService.systemProfile = p;
                    Qt.callLater(systemInfoService.syncAdaptiveProfile);
                }
            }
        }

    }

    Process {
        id: osReleaseProc

        command: ["sh", "-c", "grep '^ID=' /etc/os-release | cut -d '=' -f 2 | tr -d '\"'"]
        running: true
        onExited: (exitCode) => {
            if (exitCode === 0) {
                let id = osOutput.text.trim();
                if (id !== "")
                    systemInfoService.osId = id;

            }
        }

        stdout: StdioCollector {
            id: osOutput
        }

    }


    // Event-driven battery updates via UPower.
    // No recurring shell process or battery polling timer.
    function syncBatteryFromUPower() {
        const dev = UPower.displayDevice;

        if (!dev || !dev.ready)
            return;

        if (dev.type !== UPowerDeviceType.Battery) {
            systemInfoService.hasBattery = false;
            systemInfoService.batteryStatus = "No battery";
            systemInfoService.batteryLevel = 0;
            return;
        }

        const percentage = dev.percentage;
        const level = percentage <= 1
            ? percentage * 100
            : percentage;

        systemInfoService.hasBattery = true;
        systemInfoService.batteryLevel =
            Math.max(0, Math.min(100, Math.round(level)));

        switch (dev.state) {
        case UPowerDeviceState.Charging:
            systemInfoService.batteryStatus = "Charging";
            break;
        case UPowerDeviceState.Discharging:
        case UPowerDeviceState.Empty:
            systemInfoService.batteryStatus = "Discharging";
            break;
        case UPowerDeviceState.FullyCharged:
            systemInfoService.batteryStatus = "Full";
            break;
        case UPowerDeviceState.PendingCharge:
        case UPowerDeviceState.PendingDischarge:
            systemInfoService.batteryStatus = "Not charging";
            break;
        default:
            systemInfoService.batteryStatus = "Unknown";
        }

        Qt.callLater(systemInfoService.syncAdaptiveProfile);
        if (!systemInfoService.batteryRulesInitialized) {
            systemInfoService.lastOnBatteryState = UPower.onBattery;
            systemInfoService.batteryRulesInitialized = true;
        }
    }

    function applyBatteryEcoRules(onBattery, announce) {
        if (XdgPaths.safeTestMode || !SettingsService.settingsLoaded || !systemInfoService.hasBattery || DisplayProfileService.gameModeActive)
            return;

        if (SettingsService.autoBatteryEyeCandy) {
            if (onBattery) {
                ecoVisualsProc.command = [
                    "hyprctl", "eval",
                    "hl.config({ decoration = { blur = { passes = 1 } } }); hl.animation({ leaf = 'borderangle', enabled = false, speed = 60, bezier = 'linear', style = 'loop' })"
                ];
            } else {
                ecoVisualsProc.command = ["hyprctl", "reload"];
            }
            ecoVisualsProc.running = false;
            ecoVisualsProc.running = true;
        }

        if (SettingsService.autoBatteryDim) {
            if (onBattery) {
                ecoDimProc.command = [
                    "sh", "-c",
                    'brightnessctl -s && cur=$(brightnessctl -m | awk -F, \'{gsub(/%/,"",$4); print $4}\'); if [ -n "$cur" ] && [ "$cur" -gt 45 ]; then brightnessctl set 20%-; fi'
                ];
            } else {
                ecoDimProc.command = ["brightnessctl", "-r"];
            }
            ecoDimProc.running = false;
            ecoDimProc.running = true;
        }

        if (announce) {
            SettingsService.playUiSound(onBattery ? "power-unplug" : "power-plug");
            IslandEventService.showEvent(
                "power",
                onBattery ? "On Battery" : "Plugged In",
                onBattery ? "Eco visuals active" : "Full visuals restored",
                onBattery ? "battery-low" : "battery-charging",
                systemInfoService.batteryLevel,
                2000
            );
        }
    }

    Process {
        id: ecoVisualsProc
        running: false
    }

    Process {
        id: ecoDimProc
        running: false
    }

    Connections {
        target: UPower.displayDevice

        function onReadyChanged() {
            systemInfoService.syncBatteryFromUPower();
        }

        function onStateChanged() {
            systemInfoService.syncBatteryFromUPower();
        }

        function onPercentageChanged() {
            systemInfoService.syncBatteryFromUPower();
        }
    }

    Connections {
        target: UPower

        function onOnBatteryChanged() {
            systemInfoService.syncBatteryFromUPower();
            if (systemInfoService.batteryRulesInitialized && UPower.onBattery !== systemInfoService.lastOnBatteryState) {
                systemInfoService.lastOnBatteryState = UPower.onBattery;
                systemInfoService.applyBatteryEcoRules(UPower.onBattery, true);
            }
        }
    }

    Component.onCompleted: Qt.callLater(syncBatteryFromUPower)

}
