import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Hyprland
import qs.Core
import qs.Core.Services
pragma Singleton

Singleton {
    id: root

    property bool initialized: false
    property bool eventActive: false
    property string eventType: ""
    property string eventTitle: ""
    property string eventValue: ""
    property string eventIcon: "volume"
    property string eventArtUrl: ""
    property int eventPercent: -1
    property int lastVolume: -1
    property bool lastMuted: false
    property int lastBrightness: -1
    property var sink: Pipewire.defaultAudioSink
    property var source: Pipewire.defaultAudioSource
    property int lastMicVolume: -1
    property bool lastMicMuted: false

    function showEvent(type, title, value, icon, percent, duration) {
        if (type !== "media")
            root.eventArtUrl = "";
        root.eventType = type;
        root.eventTitle = title;
        root.eventValue = value || "";
        root.eventIcon = icon || "bell";
        root.eventPercent = (percent === undefined || percent === null) ? -1 : percent;
        root.eventActive = true;
        hideTimer.interval = duration || 1450;
        hideTimer.restart();
    }

    function showCurrentVolume() {
        if (!root.sink || !root.sink.audio)
            return;
        const audio = root.sink.audio;
        const muted = Boolean(audio.muted);
        const value = Math.max(0, Math.min(150, Math.round(Number(audio.volume || 0) * 100)));
        root.showEvent(
            "volume",
            muted || value === 0 ? "Muted" : "Volume",
            muted || value === 0 ? "" : value + "%",
            muted || value === 0 ? "volume-off" : "volume",
            muted || value === 0 ? 0 : value,
            1500
        );
    }

    function showCurrentMicrophone() {
        if (!root.source || !root.source.audio)
            return;
        const muted = Boolean(root.source.audio.muted);
        const value = Math.max(0, Math.min(100, Math.round(Number(root.source.audio.volume || 0) * 100)));
        root.showEvent(
            "microphone",
            muted ? "Microphone muted" : "Microphone",
            muted ? "Muted" : value + "%",
            muted ? "microphone-off" : "microphone",
            muted ? 0 : value,
            1500
        );
    }

    function showCurrentBrightness(value) {
        const brightness = Math.max(0, Math.min(100, value));
        root.showEvent("brightness", "Brightness", brightness + "%", "sun", brightness, 1500);
    }

    function showCurrentMedia() {
        const player = MprisService.activePlayer;
        if (!player || !MprisService.isPlaying)
            return;
        const title = String(player.trackTitle || "").trim();
        if (title === "")
            return;
        root.showEvent("media", "Now playing", title, "music", -1, 2200);
        root.eventArtUrl = String(player.trackArtUrl || "").trim();
    }

    Component.onCompleted: {
        backlightDiscover.running = true;
        if (root.sink && root.sink.audio) {
            root.lastVolume = Math.round(Number(root.sink.audio.volume || 0) * 100);
            root.lastMuted = Boolean(root.sink.audio.muted);
        }
        if (root.source && root.source.audio) {
            root.lastMicVolume = Math.round(Number(root.source.audio.volume || 0) * 100);
            root.lastMicMuted = Boolean(root.source.audio.muted);
        }
        Qt.callLater(() => root.initialized = true);
    }

    Connections {
        target: root.sink ? root.sink.audio : null
        ignoreUnknownSignals: true

        function onVolumeChanged() {
            if (!root.sink || !root.sink.audio)
                return;
            const next = Math.round(Number(root.sink.audio.volume || 0) * 100);
            if (root.initialized && root.lastVolume >= 0 && next !== root.lastVolume)
                root.showCurrentVolume();
            root.lastVolume = next;
        }

        function onMutedChanged() {
            if (!root.sink || !root.sink.audio)
                return;
            const next = Boolean(root.sink.audio.muted);
            if (root.initialized && next !== root.lastMuted)
                root.showCurrentVolume();
            root.lastMuted = next;
        }
    }

    Connections {
        target: Pipewire
        ignoreUnknownSignals: true

        function onDefaultAudioSinkChanged() {
            root.sink = Pipewire.defaultAudioSink;
            if (root.sink && root.sink.audio) {
                root.lastVolume = Math.round(Number(root.sink.audio.volume || 0) * 100);
                root.lastMuted = Boolean(root.sink.audio.muted);
            }
        }
    }

    Connections {
        target: root.source ? root.source.audio : null
        ignoreUnknownSignals: true

        function onVolumeChanged() {
            if (!root.source || !root.source.audio)
                return;
            const next = Math.round(Number(root.source.audio.volume || 0) * 100);
            if (root.initialized && root.lastMicVolume >= 0 && next !== root.lastMicVolume)
                root.showCurrentMicrophone();
            root.lastMicVolume = next;
        }

        function onMutedChanged() {
            if (!root.source || !root.source.audio)
                return;
            const next = Boolean(root.source.audio.muted);
            if (root.initialized && next !== root.lastMicMuted)
                root.showCurrentMicrophone();
            root.lastMicMuted = next;
        }
    }

    Connections {
        target: Pipewire
        ignoreUnknownSignals: true

        function onDefaultAudioSourceChanged() {
            root.source = Pipewire.defaultAudioSource;
            if (root.source && root.source.audio) {
                root.lastMicVolume = Math.round(Number(root.source.audio.volume || 0) * 100);
                root.lastMicMuted = Boolean(root.source.audio.muted);
            }
        }
    }

    PwObjectTracker {
        objects: {
            const tracked = [];
            if (root.sink) tracked.push(root.sink);
            if (root.source) tracked.push(root.source);
            return tracked;
        }
    }

    property string backlightPath: ""
    property int backlightMax: -1
    property FileView backlightWatcher: null

    // Brightness changes are detected directly from sysfs: instant, and without a
    // permanent background subprocess. The brightnessctl poll below is only a
    // fallback for setups without a standard backlight device.
    Process {
        id: backlightDiscover

        command: ["sh", "-c", "ls -d /sys/class/backlight/*/brightness 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = String(text || "").trim();
                if (line !== "")
                    root.backlightPath = line.slice(0, -"/brightness".length);
            }
        }
    }

    FileView {
        id: backlightMaxView

        path: root.backlightPath === "" ? "" : root.backlightPath + "/max_brightness"
        printErrors: false
        onLoaded: {
            const max = parseInt(String(text() || "").trim(), 10);
            if (Number.isFinite(max) && max > 0) {
                root.backlightMax = max;
                // Establish the baseline before watching, so the first change after
                // startup shows an OSD instead of being swallowed as the baseline.
                Qt.callLater(root.syncBacklightFromSysfs);
            }
        }
    }

    Component {
        id: backlightWatcherComponent

        FileView {
            printErrors: false
            watchChanges: true
            onFileChanged: root.syncBacklightFromSysfs()
            onLoaded: root.syncBacklightFromSysfs()
        }
    }

    // sysfs attributes do not reliably deliver inotify/fsnotify events to
    // QFileSystemWatcher, so the backlight file is polled instead: one tiny
    // read per second, no subprocess, works on every kernel.
    Timer {
        interval: 1000
        repeat: true
        running: root.backlightPath !== ""
        onTriggered: if (root.backlightWatcher) root.backlightWatcher.reload()
    }

    onBacklightPathChanged: {
        if (root.backlightWatcher) {
            root.backlightWatcher.destroy();
            root.backlightWatcher = null;
        }

        if (root.backlightPath !== "")
            root.backlightWatcher = backlightWatcherComponent.createObject(root, { path: root.backlightPath + "/brightness" });
    }

    function syncBacklightFromSysfs() {
        if (!root.backlightWatcher || root.backlightMax <= 0)
            return;

        const raw = parseInt(String(root.backlightWatcher.text() || "").trim(), 10);
        if (!Number.isFinite(raw))
            return;

        const next = Math.round(raw * 100 / root.backlightMax);
        if (root.initialized && root.lastBrightness >= 0 && Math.abs(next - root.lastBrightness) >= 2)
            root.showCurrentBrightness(next);

        root.lastBrightness = next;
    }

    // Fallback poll for setups without a standard backlight sysfs device.
    // The initial baseline read happens once in Component.onCompleted.
    Timer {
        interval: 5000
        repeat: true
        running: root.backlightPath === "" && SettingsService.barIslandMode && !DisplayProfileService.gameModeActive
        triggeredOnStart: true
        onTriggered: {
            if (!brightnessProc.running)
                brightnessProc.running = true;
        }
    }

    Process {
        id: brightnessProc
        command: ["brightnessctl", "-m"]

        stdout: SplitParser {
            onRead: (data) => {
                const parts = String(data || "").trim().split(",");
                if (parts.length < 4)
                    return;
                const next = parseInt(String(parts[3]).replace("%", ""), 10);
                if (!Number.isFinite(next))
                    return;
                if (root.initialized && root.lastBrightness >= 0 && Math.abs(next - root.lastBrightness) >= 2)
                    root.showCurrentBrightness(next);
                root.lastBrightness = next;
            }
        }
    }

    Connections {
        target: Hyprland
        ignoreUnknownSignals: true

        function onRawEvent(event) {
            if (!event || !event.name)
                return;
            if (event.name === "workspace" || event.name === "workspacev2")
                workspaceDebounce.restart();
            else if (event.name === "activelayout") {
                const parts = String(event.data || "").split(",");
                const layoutName = (parts.length > 1 ? parts.slice(1).join(",") : parts[0]).trim();
                if (layoutName !== "")
                    root.showEvent("kb_layout", "Keyboard", layoutName, "keyboard", -1, 1300);
            }
        }
    }

    Timer {
        id: workspaceDebounce
        interval: 70
        repeat: false
        onTriggered: {
            const workspace = Hyprland.focusedWorkspace;
            const id = workspace ? workspace.id : 1;
            root.showEvent("workspace", "Workspace", String(id), "layout-filled", -1, 1250);
        }
    }

    Connections {
        target: RecorderService
        ignoreUnknownSignals: true

        function onRunningChanged() {
            if (!root.initialized)
                return;
            SettingsService.playUiSound(RecorderService.running ? "record-start" : "record-stop");
            if (RecorderService.running)
                root.showEvent("recording", "Screen recording", "Started", "record-icon", -1, 2200);
            else
                root.showEvent("recording", "Screen recording", "Stopped", "record-icon", -1, 1800);
        }

        function onPausedChanged() {
            if (!root.initialized || !RecorderService.running)
                return;
            root.showEvent("recording", "Screen recording", RecorderService.paused ? "Paused" : "Resumed", "record-icon", -1, 1800);
        }
    }

    Connections {
        target: MprisService.activePlayer
        ignoreUnknownSignals: true

        function onTrackTitleChanged() {
            if (root.initialized)
                root.showCurrentMedia();
        }

        function onPlaybackStateChanged() {
            if (!root.initialized)
                return;
            if (MprisService.isPlaying)
                root.showCurrentMedia();
            else if (MprisService.activePlayer)
                root.showEvent("media", "Playback", "Paused", "music", -1, 1300);
        }
    }

    Connections {
        target: MprisService
        ignoreUnknownSignals: true

        function onActivePlayerChanged() {
            if (root.initialized && MprisService.isPlaying)
                root.showCurrentMedia();
        }
    }

    Timer {
        id: hideTimer
        interval: 1450
        repeat: false
        onTriggered: root.eventActive = false
    }
}
