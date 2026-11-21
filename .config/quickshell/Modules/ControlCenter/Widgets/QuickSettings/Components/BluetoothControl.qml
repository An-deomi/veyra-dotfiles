import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components

QuickSettingsTile {
    id: root

    property bool expanded: false
    property bool isScanning: btDiscoveryProc.running
    property var btList: []
    property bool isVisible: true
    property bool adapterAvailable: true
    property string adapterName: ""
    property string statusMessage: ""
    property bool actionFailed: false
    property string connectingMac: ""

    function showMessage(message, failed) {
        root.statusMessage = message || "";
        root.actionFailed = failed === true;
        if (root.statusMessage !== "")
            actionMessageTimer.restart();
        else
            actionMessageTimer.stop();
    }

    function consumeActionOutput(data) {
        if (!data)
            return;
        try {
            const parsed = JSON.parse(data);
            if (parsed.message !== undefined)
                showMessage(parsed.message, parsed.ok === false);
        } catch (e) {
            // Ignore non-JSON noise from bluetoothctl; the helper returns JSON.
        }
    }

    function toggle() {
        showMessage("", false);
        btSetProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/bluetooth.py", "toggle-power"];
        btSetProc.running = false;
        btSetProc.running = true;
    }

    function scan() {
        if (!root.isActive || !root.adapterAvailable)
            return;
        btDiscoveryProc.running = false;
        btDiscoveryProc.running = true;
    }

    function connect(mac) {
        if (!mac || root.connectingMac !== "")
            return;
        root.connectingMac = mac;
        showMessage("", false);
        btConnectProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/bluetooth.py", "toggle-connect", mac];
        btConnectProc.running = false;
        btConnectProc.running = true;
    }

    hasMenu: true
    icon: root.isActive ? "bluetooth" : "bluetooth-off"
    label: "Bluetooth"
    subtitle: {
        if (!root.adapterAvailable)
            return "Adapter unavailable";
        if (!isActive)
            return "Off";
        for (let i = 0; i < btList.length; i++) {
            if (btList[i].connected)
                return btList[i].name;
        }
        return "Ready to connect";
    }
    onClicked: root.toggle()
    onExpandedChanged: {
        if (expanded)
            scan();
        else
            btDiscoveryProc.running = false;
    }
    onIsActiveChanged: {
        if (!isActive) {
            btDiscoveryProc.running = false;
            btList = [];
        } else {
            if (!btGetProc.running)
                btGetProc.running = true;
            if (expanded)
                Qt.callLater(root.scan);
        }
    }
    onIsVisibleChanged: {
        if (isVisible && !btGetProc.running) {
            btGetProc.running = true;
        }
    }
    Component.onCompleted: {
        btGetProc.running = true;
    }

    Timer {
        id: updateTimer
        interval: 3000
        running: root.isVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!btGetProc.running)
                btGetProc.running = true;
        }
    }

    Timer {
        id: actionMessageTimer
        interval: 6500
        repeat: false
        onTriggered: root.statusMessage = ""
    }

    Process {
        id: btGetProc
        command: ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/bluetooth.py", "status"]
        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return;
                try {
                    const parsed = JSON.parse(data);
                    root.adapterAvailable = parsed.adapter_available !== false;
                    root.adapterName = parsed.adapter_name || "";
                    if (parsed.error) {
                        root.showMessage(parsed.error, true);
                    } else if (root.statusMessage === "") {
                        root.actionFailed = false;
                    }
                    root.isActive = !!parsed.powered;
                    if (!btDiscoveryProc.running || root.btList.length === 0) {
                        const devices = (parsed.devices || []).slice();
                        if (devices.length > 0 || !root.isScanning)
                            root.btList = devices;
                    }
                } catch (e) {
                    root.adapterAvailable = false;
                    root.showMessage("Could not read Bluetooth status.", true);
                }
            }
        }
    }

    Process {
        id: btSetProc
        stdout: SplitParser {
            onRead: (data) => root.consumeActionOutput(data)
        }
        onRunningChanged: {
            if (!running && !btGetProc.running)
                btGetProc.running = true;
        }
    }

    Process {
        id: btDiscoveryProc
        command: ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/bluetooth.py", "scan"]
        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return;
                try {
                    const parsed = JSON.parse(data);
                    if (parsed.event === "devices")
                        root.btList = (parsed.devices || []).slice();
                    else if (parsed.event === "error")
                        root.showMessage(parsed.message || "Bluetooth scan failed.", true);
                } catch (e) {
                    // Ignore incomplete or non-JSON process output.
                }
            }
        }
    }

    Process {
        id: btConnectProc
        stdout: SplitParser {
            onRead: (data) => root.consumeActionOutput(data)
        }
        onRunningChanged: {
            if (!running) {
                root.connectingMac = "";
                if (!btGetProc.running)
                    btGetProc.running = true;
                // Refresh discovery results if the device list is open.
                if (root.expanded)
                    Qt.callLater(root.scan);
            }
        }
    }
}
