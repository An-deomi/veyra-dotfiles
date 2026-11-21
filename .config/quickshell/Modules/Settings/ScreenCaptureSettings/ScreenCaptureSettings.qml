import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Settings.Components

AppContainer {
    id: root

    pageTitle: "Screen Capture"
    pageDescription: "Configure screenshots, recordings and capture audio."
    pageIcon: "record-icon"
    AppGroup {
        title: "Recording Defaults"
        icon: "record-icon"
        showDividers: false

        SettingSegmented {
            label: "Audio Source"
            description: "Choose what is captured when you start a recording from PrtSc or the bar."
            model: [{
                "text": "None",
                "value": "none"
            }, {
                "text": "Output",
                "value": "output"
            }, {
                "text": "Mic",
                "value": "input"
            }, {
                "text": "Both",
                "value": "both"
            }]
            currentValue: SettingsService.screenRecordAudioSource
            onActivated: (val) => {
                SettingsService.screenRecordAudioSource = val;
            }
        }

        SettingSegmented {
            label: "Recording Resolution"
            description: "Maximum output size. Original keeps the captured display size; lower options downscale to save disk space."
            model: [{
                "text": "Original",
                "value": "source"
            }, {
                "text": "1080p",
                "value": "1080p"
            }, {
                "text": "720p",
                "value": "720p"
            }, {
                "text": "480p",
                "value": "480p"
            }]
            currentValue: SettingsService.screenRecordResolution
            onActivated: (val) => {
                SettingsService.screenRecordResolution = val;
            }
        }
    }

    AppGroup {
        title: "Capture Options"
        icon: "cursor"

        SettingToggle {
            id: includeCursorToggle
            label: "Include Mouse Cursor in Screenshots"
            description: "Adds the pointer to full-screen, area, window, clipboard, and text-extraction screenshots. wf-recorder videos still include the pointer by default."
            onCheckedChanged: {
                if (checked !== SettingsService.screenCaptureIncludeCursor)
                    SettingsService.screenCaptureIncludeCursor = checked;
            }
            Binding {
                target: includeCursorToggle
                property: "checked"
                value: SettingsService.screenCaptureIncludeCursor
            }
        }

        ThemedText {
            Layout.fillWidth: true
            text: "Recording HUD controls appear in the bar while wf-recorder is active. Pause suspends the recorder process; resume continues it, and Stop finalizes the recording."
            color: Theme.muted
            wrapMode: Text.WordWrap
        }
    }

    AppGroup {
        title: "Audio Notes"
        icon: "info"

        ThemedText {
            Layout.fillWidth: true
            text: "Output records system/application sound. Mic records your default input. Both mixes the default output monitor and microphone using a temporary PipeWire/PulseAudio sink, which is removed when recording stops. Veyra does not automatically unmute the microphone."
            color: Theme.muted
            wrapMode: Text.WordWrap
        }

        ThemedText {
            Layout.fillWidth: true
            text: "When Both is selected, a working pactl-compatible audio server and module-null-sink/module-loopback support are required."
            color: Theme.muted
            wrapMode: Text.WordWrap
        }
    }
}
