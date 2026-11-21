import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Settings.Components

AppContainer {
    id: root

    pageTitle: "Power & Battery"
    pageDescription: "Choose a performance profile and check your battery status."
    pageIcon: "battery-charging"

    AppGroup {
        collapsible: true
        title: "Performance Profile"
        icon: "cpu"
        badge: SystemInfoService.hasPerformanceProfile
            ? SystemInfoService.effectivePowerProfile
            : "Unavailable"

        SettingToggle {
            label: "Adaptive Power"
            description: "Use Power Saver on battery and Balanced on AC. Game Mode temporarily overrides this."
            checked: SettingsService.adaptivePowerEnabled
            enabled: SystemInfoService.hasPerformanceProfile && SystemInfoService.hasBattery
            onToggled: (checked) => SettingsService.adaptivePowerEnabled = checked
        }

        SettingSegmented {
            label: "Power Mode"
            description: "Balances responsiveness, energy use and system cooling"
            enabled: SystemInfoService.hasPerformanceProfile
            model: [
                { "text": "Saver", "value": "power-saver" },
                { "text": "Balanced", "value": "balanced" },
                { "text": "Performance", "value": "performance" }
            ]
            currentValue: SystemInfoService.effectivePowerProfile
            onActivated: (value) => {
                SettingsService.adaptivePowerEnabled = false;
                SystemInfoService.applyProfile(value);
            }
        }

        ThemedText {
            Layout.fillWidth: true
            visible: !SystemInfoService.hasPerformanceProfile
            text: "powerprofilesctl is not installed or is unavailable. Install and enable power-profiles-daemon to manage performance profiles here."
            customSize: Constants.sizeXs + 1
            color: Theme.muted
            wrapMode: Text.WordWrap
        }
    }

    AppGroup {
        collapsible: true
        title: "Battery"
        icon: "battery-full"
        badge: SystemInfoService.hasBattery
            ? SystemInfoService.batteryPercentage : "Desktop"

        InfoRow {
            label: "Charge"
            value: SystemInfoService.hasBattery ? SystemInfoService.batteryPercentage : "No battery detected"
        }

        InfoRow {
            label: "Status"
            value: SystemInfoService.hasBattery
                ? (SystemInfoService.batteryStatus || "Checking…")
                : "Connected to external power"
        }

        InfoRow {
            label: "Power estimate"
            value: SystemInfoService.batteryEstimation
        }
    }

    AppGroup {
        collapsible: true
        title: "Automatic Power Saving"
        icon: "power"

        SettingToggle {
            label: "Eco Visuals on Battery"
            description: "Automatically drop blur passes to 1 and pause the spinning gradient border on battery, restoring full eye-candy on AC."
            enabled: SystemInfoService.hasBattery
            onToggled: (value) => SettingsService.autoBatteryEyeCandy = value
            Binding on checked { value: SettingsService.autoBatteryEyeCandy }
        }

        SettingToggle {
            label: "Auto-Dim Display on Battery"
            description: "Slightly lower screen brightness when unplugging and restore your previous brightness when plugged back in."
            enabled: SystemInfoService.hasBattery
            onToggled: (value) => SettingsService.autoBatteryDim = value
            Binding on checked { value: SettingsService.autoBatteryDim }
        }

        ThemedText {
            Layout.fillWidth: true
            text: "Display blanking, locking and suspend timers are configured in Lock Screen settings so that idle behavior stays in one place."
            customSize: Constants.sizeXs + 1
            color: Theme.muted
            wrapMode: Text.WordWrap
        }
    }
}
