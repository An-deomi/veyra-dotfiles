import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core.Services
pragma Singleton

Singleton {
    id: root

    property bool running: false
    property bool paused: false
    property int durationInSeconds: 0
    property bool hasCheckedStatus: false

    function formattedTime() {
        let m = Math.floor(durationInSeconds / 60);
        let s = durationInSeconds % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function control(action) {
        const script = Quickshell.shellDir + "/Modules/ScreenCapture/scripts/record-control.sh";
        Quickshell.execDetached(["bash", script, action]);
        checkDelay.restart();
    }

    function toggle(args) {
        if (root.running) {
            root.stop();
            return;
        }
        if (args === undefined)
            args = [];
        const script = Quickshell.shellDir + "/Modules/ScreenCapture/scripts/record.sh";
        Quickshell.execDetached(["bash", script].concat(args));
        checkDelay.restart();
    }

    function pause() {
        if (root.running && !root.paused)
            root.control("pause");
    }

    function resume() {
        if (root.running && root.paused)
            root.control("resume");
    }

    function togglePause() {
        if (root.paused)
            root.resume();
        else
            root.pause();
    }

    function stop() {
        if (root.running)
            root.control("stop");
    }

    onRunningChanged: {
        if (!running) {
            durationInSeconds = 0;
            paused = false;
            durationTimer.stop();
        } else if (!paused) {
            durationTimer.start();
        }
    }

    onPausedChanged: {
        if (paused)
            durationTimer.stop();
        else if (running)
            durationTimer.start();
    }

    Timer {
        id: durationTimer
        interval: 1000
        repeat: true
        onTriggered: root.durationInSeconds++
    }

    Timer {
        id: checkTimer
        interval: root.running ? 1000 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!checkProc.running)
                checkProc.running = true;
        }
    }

    Timer {
        id: checkDelay
        interval: 300
        repeat: false
        onTriggered: {
            if (!checkProc.running)
                checkProc.running = true;
        }
    }

    Process {
        id: checkProc
        command: ["bash", Quickshell.shellDir + "/Modules/ScreenCapture/scripts/record-control.sh", "status"]
        stdout: StdioCollector {
            id: stateOutput
        }
        onExited: (code) => {
            const state = (stateOutput.text || "").trim();
            root.paused = state === "paused";
            root.running = state === "running" || state === "paused";
            root.hasCheckedStatus = true;
        }
    }
}
