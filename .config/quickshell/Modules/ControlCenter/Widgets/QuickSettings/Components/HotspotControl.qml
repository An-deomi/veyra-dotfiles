import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components

QuickSettingsTile {
    id: root

    property string profileName: ""
    property bool isVisible: true
    property bool busy: false
    property bool backendAvailable: false
    property bool initialized: false
    property string statusMessage: ""
    readonly property string script: Quickshell.shellDir + "/Modules/ControlCenter/scripts/hotspot.py"

    hasMenu: true
    icon: "wifi"
    label: "Hotspot"
    subtitle: root.busy ? "Working..." : (!root.initialized ? "Checking..." : (root.isActive ? "On" : (!root.backendAvailable ? "Setup needed" : "Off")))

    onClicked: {
        if (root.busy)
            return;
        if (!root.isActive && !root.backendAvailable) {
            root.statusMessage = "Install linux-wifi-hotspot (AUR package)";
            return;
        }
        root.busy = true;
        let cmd = ["python3", root.script, root.isActive ? "stop" : "start"];
        if (root.profileName)
            cmd.push(root.profileName);
        toggleProc.command = cmd;
        toggleProc.running = true;
    }

    Timer {
        interval: 5000
        running: root.isVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.busy && !statusProc.running)
                statusProc.running = true;
        }
    }

    Process {
        id: statusProc
        command: ["python3", root.script, "status"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return;
                try {
                    let d = JSON.parse(data.trim());
                    root.initialized = true;
                    root.backendAvailable = Boolean(d.backendAvailable);
                    root.isActive = Boolean(d.active);
                    if (d.profile)
                        root.profileName = d.profile;
                    if (d.message)
                        root.statusMessage = d.message;
                } catch (e) {
                }
            }
        }
    }

    Process {
        id: toggleProc

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return;
                try {
                    let d = JSON.parse(data.trim());
                    if (d.message)
                        root.statusMessage = d.message;
                    if (d.active !== undefined)
                        root.isActive = Boolean(d.active);
                    if (d.backendAvailable !== undefined)
                        root.backendAvailable = Boolean(d.backendAvailable);
                } catch (e) {
                    root.statusMessage = data.trim();
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                root.busy = false;
                if (!statusProc.running)
                    statusProc.running = true;
            }
        }
    }
}
