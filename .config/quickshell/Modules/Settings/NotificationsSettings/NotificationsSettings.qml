import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Settings.Components

AppContainer {
    id: root

    pageTitle: "Notifications"
    pageDescription: "Control popup timing, quiet hours and Do Not Disturb behavior."
    pageIcon: "bell"
    // The live service discovers apps as notifications arrive.
    property var notificationService: null

    AppGroup {
        title: "Popup Behavior"
        icon: "bell"

        SettingToggle {
            label: "Show Notification Popups"
            description: "Keep notifications in history when popups are disabled"
            checked: SettingsService.notificationsPopupsEnabled
            onToggled: (checked) => {
                SettingsService.notificationsPopupsEnabled = checked;
            }
        }

        SettingSpinBox {
            label: "Popup Duration"
            description: "How long standard notification popups remain visible"
            from: 2
            to: 15
            stepSize: 1
            value: SettingsService.notificationPopupDuration
            defaultValue: 5
            suffix: "sec"
            onMoved: (val) => {
                SettingsService.notificationPopupDuration = Math.round(val);
            }
            enabled: SettingsService.notificationsPopupsEnabled
        }
    }

    AppGroup {
        title: "Do Not Disturb"
        icon: "moon"

        SettingToggle {
            label: "Enable Do Not Disturb"
            description: DisplayProfileService.gameModeActive ? "Game Mode is enforcing DND; this sets your manual preference for afterward" : (NotificationService.quietHoursActive ? "Quiet Hours is enforcing DND; this sets your manual preference for afterward" : "Remember your manual preference; Quiet Hours, media playback, and Game Mode can also enable DND")
            checked: SettingsService.notificationsDndEnabled
            onToggled: (checked) => {
                SettingsService.notificationsDndEnabled = checked;
            }
        }

        SettingToggle {
            label: "Enable DND While Media Plays"
            description: "Automatically mute popups while an MPRIS player is playing; this also includes music apps such as Spotify"
            checked: SettingsService.notificationDndWhileMediaPlaying
            onToggled: (checked) => {
                SettingsService.notificationDndWhileMediaPlaying = checked;
            }
        }

        SettingToggle {
            label: "Allow Critical Notifications"
            description: "Show critical alerts, such as very low battery, while DND is active"
            checked: SettingsService.notificationsCriticalDuringDnd
            onToggled: (checked) => {
                SettingsService.notificationsCriticalDuringDnd = checked;
            }
            enabled: SettingsService.notificationsDndEnabled || DisplayProfileService.gameModeActive || NotificationService.quietHoursActive || NotificationService.mediaDndActive
        }
    }

    AppGroup {
        title: "Quiet Hours"
        icon: "moon"

        SettingToggle {
            label: "Schedule Do Not Disturb"
            description: "Automatically mute ordinary popups during your quiet hours"
            checked: SettingsService.notificationQuietHoursEnabled
            onToggled: (checked) => {
                SettingsService.notificationQuietHoursEnabled = checked;
            }
        }

        SettingSpinBox {
            label: "Quiet Hours Start"
            description: "24-hour clock, hourly steps; example 22:00"
            from: 0
            to: 23
            stepSize: 1
            value: SettingsService.notificationQuietHoursStartHour
            defaultValue: 22
            suffix: ":00"
            onMoved: (val) => SettingsService.notificationQuietHoursStartHour = Math.round(val)
            enabled: SettingsService.notificationQuietHoursEnabled
        }

        SettingSpinBox {
            label: "Quiet Hours End"
            description: "The schedule supports overnight ranges such as 22:00–07:00"
            from: 0
            to: 23
            stepSize: 1
            value: SettingsService.notificationQuietHoursEndHour
            defaultValue: 7
            suffix: ":00"
            onMoved: (val) => SettingsService.notificationQuietHoursEndHour = Math.round(val)
            enabled: SettingsService.notificationQuietHoursEnabled
        }
    }

    AppGroup {
        title: "Per-app Popups"
        icon: "apps"

        Repeater {
            model: root.notificationService ? root.notificationService.knownAppNames : []

            delegate: SettingToggle {
                label: modelData
                description: SettingsService.isNotificationAppEnabled(modelData)
                    ? "Popups allowed; turn off to mute this app only"
                    : "Popups muted; notifications remain in history"
                checked: SettingsService.isNotificationAppEnabled(modelData)
                onToggled: (checked) => SettingsService.setNotificationAppEnabled(modelData, checked)
            }
        }
    }

    AppGroup {
        title: "History & Grouping"
        icon: "apps"

        SettingToggle {
            label: "Group Chat Notifications"
            description: "Combine bursts from WhatsApp, Telegram, Discord, and Slack"
            checked: SettingsService.notificationGroupingEnabled
            onToggled: (checked) => {
                SettingsService.notificationGroupingEnabled = checked;
            }
        }

        SettingSpinBox {
            label: "Notification History Limit"
            description: "Maximum number of recent notifications kept in the notification center"
            from: 10
            to: 100
            stepSize: 10
            value: SettingsService.notificationHistoryLimit
            defaultValue: 50
            suffix: "items"
            onMoved: (val) => {
                SettingsService.notificationHistoryLimit = Math.round(val);
            }
        }
    }
}
