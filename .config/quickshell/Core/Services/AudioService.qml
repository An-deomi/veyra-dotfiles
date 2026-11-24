import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
pragma Singleton

Item {
    id: audioService

    property int micVolume: 0
    property bool micMuted: false
    property string defaultSourceName: ""
    property bool hasPhysicalMic: defaultSourceName !== "" && !defaultSourceName.endsWith(".monitor")

    function updateMicStatus() {
        defaultSourceProc.running = false;
        defaultSourceProc.running = true;
    }

    function setMicVolume(val) {
        if (!hasPhysicalMic)
            return ;

        audioService.micVolume = val;
        micSetVolumeProc.setVol(val);
    }

    function setMicMuted(state) {
        if (!hasPhysicalMic)
            return ;

        audioService.micMuted = state;
        micSetMuteProc.setMute(state);
    }

    onMicMutedChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

    }
    onMicVolumeChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

    }
    Component.onCompleted: {
        defaultSourceProc.running = true;
    }

    Process {
        id: micVolumeProc

        command: ["sh", "-c", "if command -v pamixer >/dev/null 2>&1; then pamixer --default-source --get-volume; elif command -v wpctl >/dev/null 2>&1; then wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{printf \"%d\\n\", $2 * 100 + 0.5}'; elif command -v pactl >/dev/null 2>&1; then pactl get-source-volume @DEFAULT_SOURCE@ | grep -oE '[0-9]+%' | head -n1 | tr -d '%'; fi"]

        stdout: SplitParser {
            onRead: (data) => {
                let val = parseInt(data.trim());
                if (!isNaN(val))
                    audioService.micVolume = val;

            }
        }

    }

    Process {
        id: micMuteProc

        command: ["sh", "-c", "if command -v pamixer >/dev/null 2>&1; then pamixer --default-source --get-mute; elif command -v wpctl >/dev/null 2>&1; then wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED && echo true || echo false; elif command -v pactl >/dev/null 2>&1; then pactl get-source-mute @DEFAULT_SOURCE@ | grep -qi yes && echo true || echo false; fi"]

        stdout: SplitParser {
            onRead: (data) => {
                audioService.micMuted = (data.trim() === "true");
            }
        }

    }

    Process {
        id: micSetVolumeProc

        function setVol(val) {
            const clamped = Math.max(0, Math.min(100, Math.round(Number(val) || 0)));
            command = ["sh", "-c", "if command -v pamixer >/dev/null 2>&1; then exec pamixer --default-source --set-volume \"$1\"; elif command -v wpctl >/dev/null 2>&1; then exec wpctl set-volume @DEFAULT_AUDIO_SOURCE@ \"${1}%\"; elif command -v pactl >/dev/null 2>&1; then exec pactl set-source-volume @DEFAULT_SOURCE@ \"${1}%\"; fi", "veyra-mic-vol", String(clamped)];
            running = false;
            running = true;
        }

    }

    Process {
        id: micSetMuteProc

        function setMute(state) {
            command = ["sh", "-c", "if command -v pamixer >/dev/null 2>&1; then exec pamixer --default-source $([ \"$1\" = 1 ] && echo --mute || echo --unmute); elif command -v wpctl >/dev/null 2>&1; then exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ \"$1\"; elif command -v pactl >/dev/null 2>&1; then exec pactl set-source-mute @DEFAULT_SOURCE@ \"$1\"; fi", "veyra-mic-mute", state ? "1" : "0"];
            running = false;
            running = true;
        }

    }

    Process {
        id: defaultSourceProc

        command: ["pactl", "get-default-source"]
        running: false
        onExited: (code) => {
            if (code === 0)
                audioService.defaultSourceName = stdoutSource.text.trim();

            if (audioService.hasPhysicalMic) {
                micVolumeProc.running = false;
                micVolumeProc.running = true;
                micMuteProc.running = false;
                micMuteProc.running = true;
            } else {
                audioService.micMuted = true;
                audioService.micVolume = 0;
            }
            if (!SettingsService.settingsLoaded)
                SettingsService.load();

        }

        stdout: StdioCollector {
            id: stdoutSource
        }

    }

    Process {
        id: pactlSubscribeProc

        command: ["pactl", "subscribe"]
        running: true

        stdout: SplitParser {
            onRead: (data) => {
                if (data.includes("source") && SettingsService.settingsLoaded)
                    audioService.updateMicStatus();

            }
        }

    }

}
