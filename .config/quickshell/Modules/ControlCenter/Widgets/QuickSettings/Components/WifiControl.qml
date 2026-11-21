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
    property bool isScanning: wifiScanProc.running
    property var wifiList: []
    property string connectedSsid: "Disconnected"
    property bool ethernetConnected: false
    property string ethernetConnection: ""
    property string ethernetDevice: ""
    property bool wifiConnected: false
    property string wifiConnection: ""
    property string wifiDevice: ""
    property bool vpnActive: false
    property string vpnConnection: ""
    property string vpnDevice: ""
    property string currentSsid: {
        if (ethernetConnected) {
            const name = ethernetConnection.trim();
            return name.length > 0 ? ("Ethernet · " + name) : "Ethernet connected";
        }

        if (!isActive)
            return "Off";

        return connectedSsid;
    }
    property bool isVisible: true
    property bool isConnecting: wifiConnectProc.running
    property string connectError: ""
    property string connectingSsid: ""
    property string connectionStatus: ""
    property bool connectionStatusSuccess: false

    function toggle() {
        wifiSetProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py", "toggle-radio"];
        wifiSetProc.running = true;
        root.isActive = !root.isActive;
    }

    function scan(forceRescan) {
        if (!root.isActive)
            return ;

        let rescan = (forceRescan === undefined) ? true : forceRescan;
        wifiScanProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py", "scan", rescan ? "yes" : "no"];
        wifiScanProc.running = false;
        wifiScanProc.running = true;
    }

    function beginConnection(ssid) {
        if (wifiConnectProc.running)
            return false;

        root.connectError = "";
        root.connectingSsid = ssid;
        root.connectionStatus = "Connecting to " + ssid + "...";
        root.connectionStatusSuccess = false;
        connectionStatusTimer.stop();
        return true;
    }

    function connect(ssid) {
        if (!root.beginConnection(ssid))
            return;

        wifiConnectProc.command = [
            "python3",
            Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py",
            "connect",
            ssid
        ];
        wifiConnectProc.running = true;
    }

    function connectWithPassword(ssid, password) {
        if (!root.beginConnection(ssid))
            return;

        // Secret travels over stdin, never in argv (/proc/<pid>/cmdline).
        wifiConnectProc.stdinEnabled = true;
        wifiConnectProc.command = [
            "python3",
            Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py",
            "connect",
            ssid,
            "--stdin"
        ];
        wifiConnectProc.running = true;
        wifiConnectProc.write(password + "\n");
        wifiConnectProc.stdinEnabled = false;
    }

    Timer {
        id: connectionStatusTimer
        interval: 6500
        repeat: false

        onTriggered: {
            root.connectionStatus = "";
            root.connectionStatusSuccess = false;
        }
    }

    hasMenu: true
    prominent: false
    icon: root.isActive ? "wifi" : "wifi-off"
    label: "Wi-Fi"
    subtitle: root.currentSsid
    onClicked: root.toggle()
    onExpandedChanged: {
        if (expanded)
            scan(true);

    }
    onIsActiveChanged: {
        if (isActive) {
            scan(false);
            if (expanded)
                scan(true);

        } else {
            wifiList = [];
            connectedSsid = "Disconnected";
        }
    }
    onIsVisibleChanged: {
        if (isVisible && isActive && root.wifiList.length === 0)
            scan(false);

    }
    Component.onCompleted: {
        if (isActive && root.wifiList.length === 0)
            scan(false);

    }

    Timer {
        interval: 2000
        running: root.isVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            wifiGetProc.running = true;
        }
    }

    Process {
        id: wifiGetProc

        command: ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py", "status"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                try {
                    let st = JSON.parse(data.trim());
                    root.isActive = !!st.radio;
                    root.connectedSsid = st.connected_ssid || "Disconnected";
                    root.ethernetConnected = !!st.ethernet_connected;
                    root.ethernetConnection = st.ethernet_connection || "";
                    root.ethernetDevice = st.ethernet_device || "";
                    root.wifiConnected = !!st.wifi_connected;
                    root.wifiConnection = st.wifi_connection || "";
                    root.wifiDevice = st.wifi_device || "";
                    root.vpnActive = !!st.vpn_active;
                    root.vpnConnection = st.vpn_connection || "";
                    root.vpnDevice = st.vpn_device || "";
                } catch (e) {
                }
            }
        }

    }

    Process {
        id: wifiSetProc

        onRunningChanged: {
            if (!running)
                wifiGetProc.running = true;

        }
    }

    Process {
        id: wifiScanProc

        command: ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py", "scan"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                try {
                    let list = JSON.parse(data.trim());
                    if (Array.isArray(list))
                        root.wifiList = list;

                } catch (e) {
                }
            }
        }

    }

    Process {
        id: wifiConnectProc

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                try {
                    let res = JSON.parse(data.trim());
                    root.connectError = res.success ? "" : (res.output || "Could not connect");
                    root.connectionStatus = res.success
                        ? ("Connected to " + root.connectingSsid)
                        : (res.output || "Could not connect");
                    root.connectionStatusSuccess = !!res.success;
                    connectionStatusTimer.restart();
                } catch (e) {
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                if (root.connectionStatus.startsWith("Connecting to ")) {
                    root.connectionStatus = root.connectError
                        || "Connection attempt finished.";
                    root.connectionStatusSuccess = false;
                    connectionStatusTimer.restart();
                }

                wifiGetProc.running = true;
                root.scan(true);
            }
        }
    }

}
