import QtQuick
import qs.Core
import qs.Core.Components
import qs.Core.Services

QuickSettingsTile {
    id: root

    readonly property bool enforcedByGameMode: DisplayProfileService.gameModeActive === true
    readonly property bool enforcedByQuietHours: NotificationService.quietHoursActive === true
    readonly property bool enforcedByMedia: NotificationService.mediaDndActive === true

    isActive: SettingsService.notificationsDndEnabled
    icon: isActive ? "moon-filled" : "moon"
    label: "Do Not Disturb"
    subtitle: {
        if (enforcedByGameMode)
            return "Managed by Game Mode";
        if (enforcedByQuietHours)
            return "Quiet Hours";
        if (enforcedByMedia)
            return "While media plays";
        return SettingsService.notificationsDndEnabled ? "On" : "Off";
    }

    // Preserve the user's manual preference even while another feature is
    // temporarily enforcing DND (Game Mode, Quiet Hours, or media playback).
    onClicked: SettingsService.notificationsDndEnabled = !SettingsService.notificationsDndEnabled
}
