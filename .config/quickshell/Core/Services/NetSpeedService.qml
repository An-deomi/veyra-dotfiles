pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core.Services

Item {
    id: root

    property real downloadBps: 0
    property real uploadBps: 0
    // The readout is used by the Island left capsule and the Convex system
    // monitor pill, so the sampler must run for both styles. Game Mode replaces
    // the bar entirely and still stops it.
    property bool active: (SettingsService.barIslandMode || SettingsService.barConvexMode) && !DisplayProfileService.gameModeActive

    function startSampler() {
        restartTimer.stop();
        if (active && !netSampler.running)
            netSampler.running = true;
    }

    function stopSampler() {
        restartTimer.stop();
        if (netSampler.running)
            netSampler.running = false;
        downloadBps = 0;
        uploadBps = 0;
    }

    onActiveChanged: {
        if (active)
            startSampler();
        else
            stopSampler();
    }

    Component.onCompleted: startSampler()

    Timer {
        id: restartTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (root.active && !netSampler.running)
                netSampler.running = true;
        }
    }

    Process {
        id: netSampler

        command: [
            "python3",
            Quickshell.shellDir + "/Scripts/system/net_speed.py"
        ]
        running: false

        onExited: {
            if (root.active)
                restartTimer.start();
        }

        stdout: SplitParser {
            onRead: (data) => {
                try {
                    const result = JSON.parse(data);
                    root.downloadBps = Math.max(0, Number(result.downloadBps) || 0);
                    root.uploadBps = Math.max(0, Number(result.uploadBps) || 0);
                } catch (e) {
                    // Ignore malformed samples; the next sample can recover.
                }
            }
        }
    }
}
