import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    property bool isOpen: false
    property string profileName: ""
    property bool hotspotActive: false
    property bool busy: false
    property var clients: []
    property string statusMsg: ""
    property string actionMessage: ""
    property string serviceMessage: ""
    property string interfaceSummary: ""
    property bool backendAvailable: false
    property var wifiInterfaces: []
    property var internetInterfaces: ["AUTO", "NONE"]
    property var internetLabels: ({ "AUTO": "Automatic (default route)", "NONE": "No Internet sharing" })
    property string selectedWifiInterface: ""
    property string selectedInternetInterface: "AUTO"
    property string defaultInternetInterface: ""
    property string vpnInterface: ""
    property bool shareVpn: false
    property string interfaceMessage: ""
    property bool interfaceSaving: false
    property bool saving: false
    property bool showPw: false
    property int currentTab: 0 // 0 = Overview, 1 = Devices, 2 = Settings
    property string diagnosticText: ""
    property bool diagnosticsBusy: false
    readonly property string script: Quickshell.shellDir + "/Modules/ControlCenter/scripts/hotspot.py"

    signal toggleRequested()

    function saveInterfaceChoices() {
        if (root.interfaceSaving || !root.selectedWifiInterface || !root.selectedInternetInterface)
            return;
        root.interfaceSaving = true;
        // Polkit opens a separate window. Tell the global popup-dismissal
        // handler to suspend its focus-grab close behavior until authorization
        // and the UFW route update have finished.
        AppState.polkitAuthActive = true;
        root.interfaceMessage = "Saving interface choices and updating UFW...";
        saveInterfacesProc.command = ["python3", root.script, "set-interfaces", root.selectedWifiInterface, root.selectedInternetInterface];
        saveInterfacesProc.running = true;
    }

    function currentInternetSource() {
        if (root.selectedInternetInterface === "AUTO")
            return root.defaultInternetInterface || "automatic route";
        return root.selectedInternetInterface;
    }

    function isVpnLikeInterface(name) {
        return /^(proton\d*|pvpn[a-z0-9_-]*|tun\d*|wg\d*|wgcf\d*|nordlynx|mullvad[a-z0-9_-]*|warp[a-z0-9_-]*|vpn\d*)$/i.test(name || "");
    }

    function updateVpnToggle() {
        var source = root.currentInternetSource();
        root.shareVpn = root.vpnInterface ? source === root.vpnInterface : root.isVpnLikeInterface(source);
    }

    function setVpnSharing(enabled) {
        if (root.interfaceSaving || root.hotspotActive || root.busy)
            return;
        if (enabled) {
            if (!root.vpnInterface) {
                root.interfaceMessage = "No VPN tunnel was detected. Connect ProtonVPN, then reopen Hotspot Settings.";
                root.shareVpn = false;
                return;
            }
            root.selectedInternetInterface = root.vpnInterface;
        } else {
            if (!root.selectedWifiInterface) {
                root.interfaceMessage = "No Wi-Fi interface is selected for direct sharing.";
                return;
            }
            root.selectedInternetInterface = root.selectedWifiInterface;
        }
        root.shareVpn = enabled;
        root.saveInterfaceChoices();
    }

    function reloadDiagnostics() {
        if (diagnosticsBusy) return;
        diagnosticsBusy = true;
        diagnosticProc.running = true;
    }

    onIsOpenChanged: {
        AppState.textInputActive = isOpen;
        if (isOpen) {
            statusMsg = "";
            infoProc.running = true;
            if (!interfaceProc.running)
                interfaceProc.running = true;
        }
    }
    onHotspotActiveChanged: {
        if (!hotspotActive)
            clients = [];

    }
    Component.onDestruction: {
        AppState.textInputActive = false;
        AppState.polkitAuthActive = false;
    }

    Timer {
        interval: 4000
        running: root.isOpen && root.hotspotActive
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!clientsProc.running)
                clientsProc.running = true;

        }
    }

    Process {
        id: infoProc

        command: ["python3", root.script, "info", root.profileName]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                try {
                    let d = JSON.parse(data.trim());
                    ssidField.text = d.ssid || "";
                    pskField.text = d.psk || "";
                    root.backendAvailable = Boolean(d.backendAvailable);
                    root.serviceMessage = d.message || "";
                    root.interfaceSummary = d.interfaceSummary || "";
                    if (d.vpnInterface) root.vpnInterface = d.vpnInterface;
                } catch (e) {
                }
            }
        }

    }

    Process {
        id: interfaceProc

        command: ["python3", root.script, "interfaces"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return;
                try {
                    let d = JSON.parse(data.trim());
                    root.wifiInterfaces = Array.isArray(d.wifi) ? d.wifi : [];
                    root.internetInterfaces = Array.isArray(d.internet) ? d.internet : ["AUTO", "NONE"];
                    root.internetLabels = d.internetLabels || ({ "AUTO": "Automatic (default route)", "NONE": "No Internet sharing" });
                    root.selectedWifiInterface = d.selectedWifi || "";
                    root.selectedInternetInterface = d.selectedInternet || "AUTO";
                    root.defaultInternetInterface = d.defaultInternet || "";
                    root.vpnInterface = d.vpnInterface || "";
                    root.updateVpnToggle();
                    root.backendAvailable = Boolean(d.backendAvailable);
                    root.serviceMessage = d.message || "";
                    root.interfaceSummary = d.interfaceSummary || "";
                } catch (e) {
                }
            }
        }
    }

    Process {
        id: saveInterfacesProc

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return;
                try {
                    let d = JSON.parse(data.trim());
                    root.interfaceMessage = d.message || (d.success ? "Interface choices saved." : "Could not save interface choices.");
                    if (!d.success && !interfaceProc.running)
                        interfaceProc.running = true;
                } catch (e) {
                    root.interfaceMessage = data.trim();
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                root.interfaceSaving = false;
                AppState.polkitAuthActive = false;
                if (root.isOpen && !interfaceProc.running)
                    interfaceProc.running = true;
            }
        }
    }

    Process {
        id: clientsProc

        command: ["python3", root.script, "clients", root.profileName]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                try {
                    let l = JSON.parse(data.trim());
                    if (Array.isArray(l))
                        root.clients = l;

                } catch (e) {
                }
            }
        }

    }

    Process {
        id: saveProc

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                try {
                    let d = JSON.parse(data.trim());
                    root.statusMsg = d.message || (d.success ? "Saved" : "Failed");
                } catch (e) {
                }
            }
        }

        onRunningChanged: {
            if (!running)
                root.saving = false;

        }
    }

    Process {
        id: diagnosticProc
        command: ["python3", root.script, "diagnostics", root.profileName]
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    let d = JSON.parse(data.trim());
                    root.diagnosticText = (d.checks || []).map(x => (x.ok ? "✓ " : "! ") + x.label + (x.detail ? ": " + x.detail : "")).join("\n");
                } catch (e) { root.diagnosticText = "Could not read diagnostics."; }
            }
        }
        onRunningChanged: if (!running) root.diagnosticsBusy = false
    }

    // New Veyra-style hotspot page: compact status hero, segmented navigation,
    // clearer network summary, and grouped settings while retaining the existing backend.
    Flickable {
        id: settingsFlickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: settingsContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 5
        }

        ColumnLayout {
            id: settingsContent
            width: settingsFlickable.width
            spacing: Constants.sizeMd

            // Page heading
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Constants.sizeSm
                Layout.rightMargin: Constants.sizeSm
                spacing: 2

                ThemedText {
                    text: "NETWORK SHARING"
                    customSize: 10
                    font.bold: true
                    font.letterSpacing: 1.1
                    color: Theme.muted
                }
                ThemedText {
                    text: "Hotspot"
                    customSize: 22
                    font.bold: true
                    color: Theme.fg
                }
            }

            // Primary state and action
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: Constants.sizeSm
                Layout.rightMargin: Constants.sizeSm
                implicitHeight: heroRow.implicitHeight + Constants.sizeMd * 2
                radius: Constants.sizeLg
                color: Theme.bgSecondary
                border.width: 1
                border.color: root.hotspotActive ? Theme.accent : Theme.muted

                RowLayout {
                    id: heroRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Constants.sizeMd
                    spacing: Constants.sizeMd

                    Rectangle {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: Constants.sizeMd
                        color: root.hotspotActive ? Theme.accent : Theme.bg
                        ThemedText {
                            anchors.centerIn: parent
                            text: "Wi-Fi"
                            customSize: 12
                            font.bold: true
                            color: root.hotspotActive ? Theme.bg : Theme.fg
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        ThemedText {
                            text: root.hotspotActive ? "Hotspot is on" : (root.busy ? "Starting hotspot…" : "Hotspot is off")
                            font.bold: true
                            customSize: 16
                            color: Theme.fg
                            Layout.fillWidth: true
                        }
                        ThemedText {
                            text: root.hotspotActive
                                ? (root.clients.length === 1 ? "1 device connected" : root.clients.length + " devices connected")
                                : (root.backendAvailable ? "Ready when you are" : "Hotspot service unavailable")
                            color: Theme.muted
                            customSize: Constants.sizeXs + 1
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 26
                        radius: height / 2
                        color: root.hotspotActive ? Theme.accent : Theme.bg
                        border.width: root.hotspotActive ? 0 : 1
                        border.color: Theme.muted
                        opacity: root.busy || (!root.hotspotActive && !root.backendAvailable) ? 0.55 : 1

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.hotspotActive ? parent.width - width - 3 : 3
                            color: root.hotspotActive ? Theme.bg : Theme.muted
                            Behavior on x { NumberAnimation { duration: Constants.animFast } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.busy && (root.hotspotActive || root.backendAvailable)
                            onClicked: root.toggleRequested()
                        }
                    }
                }
            }

            // Backend / action feedback is a compact message, not a second hero.
            Rectangle {
                visible: !root.backendAvailable || root.actionMessage !== "" || root.statusMsg !== ""
                Layout.fillWidth: true
                Layout.leftMargin: Constants.sizeSm
                Layout.rightMargin: Constants.sizeSm
                implicitHeight: noticeText.implicitHeight + Constants.sizeMd * 2
                radius: Constants.sizeMd
                color: Theme.bgSecondary
                border.width: 1
                border.color: (!root.backendAvailable) ? Theme.accent : Theme.muted

                ThemedText {
                    id: noticeText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Constants.sizeMd
                    text: !root.backendAvailable
                        ? (root.serviceMessage || "Install the linux-wifi-hotspot backend to enable hotspot sharing.")
                        : (root.actionMessage !== "" ? root.actionMessage : root.statusMsg)
                    color: (!root.backendAvailable) ? Theme.accent : Theme.fg
                    wrapMode: Text.WordWrap
                    customSize: Constants.sizeXs + 1
                }
            }

            // Segmented navigation
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: Constants.sizeSm
                Layout.rightMargin: Constants.sizeSm
                implicitHeight: 42
                radius: Constants.sizeMd
                color: Theme.bgSecondary

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Repeater {
                        model: ["Overview", "Devices", "Settings"]
                        delegate: Rectangle {
                            required property int index
                            required property string modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Constants.sizeSm
                            color: root.currentTab === index ? Theme.accent : "transparent"

                            ThemedText {
                                anchors.centerIn: parent
                                text: modelData
                                customSize: Constants.sizeXs + 1
                                font.bold: root.currentTab === index
                                color: root.currentTab === index ? Theme.bg : Theme.fg
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentTab = index;
                                    settingsFlickable.contentY = 0;
                                }
                            }
                        }
                    }
                }
            }

            // OVERVIEW
            ColumnLayout {
                visible: root.currentTab === 0
                Layout.fillWidth: true
                spacing: Constants.sizeMd

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Constants.sizeSm
                    Layout.rightMargin: Constants.sizeSm
                    spacing: Constants.sizeSm

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 78
                        radius: Constants.sizeMd
                        color: Theme.bgSecondary
                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Constants.sizeMd
                            spacing: 3
                            ThemedText { text: "STATUS"; customSize: 10; font.bold: true; color: Theme.muted }
                            ThemedText {
                                text: root.hotspotActive ? "Active" : (root.busy ? "Working…" : "Inactive")
                                customSize: 16
                                font.bold: true
                                color: root.hotspotActive ? Theme.accent : Theme.fg
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 78
                        radius: Constants.sizeMd
                        color: Theme.bgSecondary
                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Constants.sizeMd
                            spacing: 3
                            ThemedText { text: "DEVICES"; customSize: 10; font.bold: true; color: Theme.muted }
                            ThemedText {
                                text: String(root.clients.length)
                                customSize: 16
                                font.bold: true
                                color: Theme.fg
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Constants.sizeSm
                    Layout.rightMargin: Constants.sizeSm
                    implicitHeight: networkSummary.implicitHeight + Constants.sizeMd * 2
                    radius: Constants.sizeMd
                    color: Theme.bgSecondary
                    ColumnLayout {
                        id: networkSummary
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Constants.sizeMd
                        spacing: Constants.sizeSm
                        RowLayout {
                            Layout.fillWidth: true
                            ThemedText { text: "NETWORK"; customSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Theme.muted; Layout.fillWidth: true }
                            ThemedText { text: root.hotspotActive ? "● LIVE" : "○ IDLE"; customSize: 10; font.bold: true; color: root.hotspotActive ? Theme.accent : Theme.muted }
                        }
                        ThemedText {
                            text: ssidField.text || "No network name set"
                            customSize: 16
                            font.bold: true
                            color: Theme.fg
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        ThemedText {
                            text: root.interfaceSummary || (root.selectedWifiInterface ? "Broadcast adapter: " + root.selectedWifiInterface : "Choose a Wi-Fi adapter in Settings")
                            customSize: Constants.sizeXs + 1
                            color: Theme.muted
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: height / 2
                            color: Theme.bg
                            border.width: 1
                            border.color: Theme.muted
                            ThemedText { anchors.centerIn: parent; text: "View connected devices  →"; color: Theme.fg; customSize: Constants.sizeXs + 1 }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.currentTab = 1; settingsFlickable.contentY = 0; }
                            }
                        }
                    }
                }
            }

            // DEVICES
            ColumnLayout {
                visible: root.currentTab === 1
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Constants.sizeSm
                    Layout.rightMargin: Constants.sizeSm
                    ThemedText { text: "Connected devices"; customSize: 16; font.bold: true; color: Theme.fg; Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 28
                        radius: Constants.sizeSm
                        color: Theme.bgSecondary
                        ThemedText { anchors.centerIn: parent; text: String(root.clients.length); customSize: 12; font.bold: true; color: Theme.fg }
                    }
                }
                Rectangle {
                    visible: root.clients.length === 0
                    Layout.fillWidth: true
                    Layout.leftMargin: Constants.sizeSm
                    Layout.rightMargin: Constants.sizeSm
                    implicitHeight: deviceEmptyColumn.implicitHeight + Constants.sizeLg * 2
                    radius: Constants.sizeMd
                    color: Theme.bgSecondary
                    ColumnLayout {
                        id: deviceEmptyColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Constants.sizeLg
                        spacing: Constants.sizeSm
                        ThemedText { text: root.hotspotActive ? "No devices connected yet" : "Your device list will appear here"; customSize: 14; font.bold: true; color: Theme.fg; Layout.fillWidth: true }
                        ThemedText { text: root.hotspotActive ? "When a device joins your network, its details will show up here." : "Turn on the hotspot to start sharing your connection."; color: Theme.muted; customSize: Constants.sizeXs + 1; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    }
                }
                Repeater {
                    model: root.clients
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.leftMargin: Constants.sizeSm
                        Layout.rightMargin: Constants.sizeSm
                        implicitHeight: deviceColumn.implicitHeight + Constants.sizeMd * 2
                        radius: Constants.sizeMd
                        color: Theme.bgSecondary
                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Constants.sizeMd
                            spacing: Constants.sizeMd
                            Rectangle {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                radius: Constants.sizeSm
                                color: Theme.bg
                                ThemedText { anchors.centerIn: parent; text: "DEV"; customSize: 10; font.bold: true; color: Theme.accent }
                            }
                            ColumnLayout {
                                id: deviceColumn
                                Layout.fillWidth: true
                                spacing: 3
                                ThemedText { text: modelData.name || "Unknown device"; font.bold: true; color: Theme.fg; elide: Text.ElideRight; Layout.fillWidth: true }
                                ThemedText { text: (modelData.ip ? modelData.ip + "  ·  " : "") + (modelData.mac || "MAC unavailable"); customSize: Constants.sizeXs + 1; color: Theme.muted; elide: Text.ElideRight; Layout.fillWidth: true }
                                ThemedText { visible: modelData.signal !== null && modelData.signal !== undefined; text: "Signal " + modelData.signal + " dBm"; customSize: 10; color: Theme.muted }
                            }
                        }
                    }
                }
            }

            // SETTINGS
            ColumnLayout {
                visible: root.currentTab === 2
                Layout.fillWidth: true
                spacing: Constants.sizeMd

                ThemedText {
                    text: "Changes to adapters or routing are available while the hotspot is off. Network name and password are saved to the existing profile."
                    color: Theme.muted
                    customSize: Constants.sizeXs + 1
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.leftMargin: Constants.sizeSm
                    Layout.rightMargin: Constants.sizeSm
                }

                // Connection and routing
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Constants.sizeSm
                    Layout.rightMargin: Constants.sizeSm
                    implicitHeight: connectionSettings.implicitHeight + Constants.sizeMd * 2
                    radius: Constants.sizeMd
                    color: Theme.bgSecondary
                    ColumnLayout {
                        id: connectionSettings
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Constants.sizeMd
                        spacing: Constants.sizeMd
                        ThemedText { text: "CONNECTION & ROUTING"; customSize: 10; font.bold: true; font.letterSpacing: 0.9; color: Theme.muted }
                        ThemedSelect {
                            id: wifiAdapterSelect
                            Layout.fillWidth: true
                            label: "Wi-Fi adapter"
                            description: root.wifiInterfaces.length > 1 ? "Adapter that broadcasts the hotspot" : "Adapter used to broadcast the hotspot"
                            comboWidth: 132
                            fallbackText: root.wifiInterfaces.length ? "Choose adapter" : "No Wi-Fi adapter"
                            model: root.wifiInterfaces
                            enabled: root.backendAvailable && !root.hotspotActive && !root.busy && !root.interfaceSaving && root.wifiInterfaces.length > 0
                            onActivated: (index) => {
                                if (index >= 0 && index < root.wifiInterfaces.length) {
                                    root.selectedWifiInterface = root.wifiInterfaces[index];
                                    root.saveInterfaceChoices();
                                }
                            }
                            Binding { target: wifiAdapterSelect; property: "currentIndex"; value: root.wifiInterfaces.indexOf(root.selectedWifiInterface) }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: vpnShareRow.implicitHeight + Constants.sizeMd * 2
                            radius: Constants.sizeMd
                            color: Theme.bg
                            RowLayout {
                                id: vpnShareRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Constants.sizeMd
                                spacing: Constants.sizeMd
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: 0
                                    spacing: 3
                                    ThemedText { text: "Share through VPN"; font.bold: true; color: Theme.fg; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                    ThemedText {
                                        text: root.hotspotActive
                                            ? "Turn the hotspot off to change routing mode"
                                            : (root.selectedInternetInterface === "NONE"
                                               ? "No Internet sharing"
                                               : (root.shareVpn
                                                  ? (root.vpnInterface ? "Clients use " + root.vpnInterface + " · VPN protected" : "No active VPN tunnel detected")
                                                  : "Clients use " + root.currentInternetSource() + " · not VPN-protected" + (!root.vpnInterface ? " · connect VPN to enable" : "")))
                                        color: root.shareVpn ? Theme.accent : Theme.muted
                                        customSize: Constants.sizeXs + 1
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                                Rectangle {
                                    Layout.minimumWidth: 42
                                    Layout.preferredWidth: 42
                                    Layout.maximumWidth: 42
                                    Layout.minimumHeight: 24
                                    Layout.preferredHeight: 24
                                    Layout.maximumHeight: 24
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    radius: height / 2
                                    color: root.shareVpn ? Theme.accent : Theme.bgSecondary
                                    border.width: root.shareVpn ? 0 : 1
                                    border.color: Theme.muted
                                    Rectangle {
                                        width: 18; height: 18; radius: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: root.shareVpn ? parent.width - width - 3 : 3
                                        color: root.shareVpn ? Theme.bg : Theme.muted
                                        Behavior on x { NumberAnimation { duration: Constants.animFast } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: root.backendAvailable && (root.shareVpn || Boolean(root.vpnInterface)) && !root.hotspotActive && !root.busy && !root.interfaceSaving
                                        onClicked: root.setVpnSharing(!root.shareVpn)
                                    }
                                }
                            }
                        }
                        ThemedSelect {
                            id: internetSourceSelect
                            Layout.fillWidth: true
                            label: "Internet source"
                            description: "Automatic follows the default route. No Internet disables sharing."
                            comboWidth: 132
                            fallbackText: "Automatic"
                            model: root.internetInterfaces
                            textMap: root.internetLabels
                            enabled: root.backendAvailable && !root.hotspotActive && !root.busy && !root.interfaceSaving
                            onActivated: (index) => {
                                if (index >= 0 && index < root.internetInterfaces.length) {
                                    root.selectedInternetInterface = root.internetInterfaces[index];
                                    root.updateVpnToggle();
                                    root.saveInterfaceChoices();
                                }
                            }
                            Binding { target: internetSourceSelect; property: "currentIndex"; value: root.internetInterfaces.indexOf(root.selectedInternetInterface) }
                        }
                        ThemedText {
                            visible: root.interfaceMessage !== ""
                            text: root.interfaceMessage
                            color: Theme.muted
                            customSize: Constants.sizeXs + 1
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                // Network credentials
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Constants.sizeSm
                    Layout.rightMargin: Constants.sizeSm
                    implicitHeight: credentialsSettings.implicitHeight + Constants.sizeMd * 2
                    radius: Constants.sizeMd
                    color: Theme.bgSecondary
                    ColumnLayout {
                        id: credentialsSettings
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Constants.sizeMd
                        spacing: Constants.sizeSm
                        ThemedText { text: "NETWORK DETAILS"; customSize: 10; font.bold: true; font.letterSpacing: 0.9; color: Theme.muted }
                        ThemedText { text: "Network name"; customSize: Constants.sizeXs + 1; color: Theme.muted }
                        VeyraTextField {
                            id: ssidField
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            placeholderText: "Hotspot name"
                        }
                        ThemedText { text: "Password · 8–63 characters"; customSize: Constants.sizeXs + 1; color: Theme.muted }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: Constants.sizeSm
                            VeyraTextField {
                                id: pskField
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                echoMode: root.showPw ? TextInput.Normal : TextInput.Password
                                placeholderText: "Hotspot password"
                            }
                            Rectangle {
                                implicitWidth: 54
                                implicitHeight: 36
                                radius: Constants.sizeSm
                                color: Theme.bg
                                ThemedText { anchors.centerIn: parent; text: root.showPw ? "Hide" : "Show"; color: Theme.accent; customSize: Constants.sizeXs + 1 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.showPw = !root.showPw }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Constants.sizeSm
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                implicitWidth: saveLbl.implicitWidth + Constants.sizeLg * 2
                                implicitHeight: 36
                                radius: height / 2
                                color: Theme.accent
                                opacity: root.saving ? 0.55 : 1
                                ThemedText { id: saveLbl; anchors.centerIn: parent; text: root.saving ? "Saving…" : "Save details"; color: Theme.bg; font.bold: true; customSize: Constants.sizeXs + 1 }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !root.saving
                                    onClicked: {
                                        root.saving = true;
                                        root.statusMsg = "";
                                        saveProc.command = ["python3", root.script, "set", root.profileName, ssidField.text, pskField.text];
                                        saveProc.running = true;
                                    }
                                }
                            }
                        }
                        ThemedText {
                            visible: root.statusMsg !== ""
                            text: root.statusMsg
                            color: Theme.muted
                            customSize: Constants.sizeXs + 1
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                // Diagnostics
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Constants.sizeSm
                    Layout.rightMargin: Constants.sizeSm
                    implicitHeight: diagnosticsContent.implicitHeight + Constants.sizeMd * 2
                    radius: Constants.sizeMd
                    color: Theme.bgSecondary
                    ColumnLayout {
                        id: diagnosticsContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Constants.sizeMd
                        spacing: Constants.sizeSm
                        ThemedText { text: "DIAGNOSTICS"; customSize: 10; font.bold: true; font.letterSpacing: 0.9; color: Theme.muted }
                        ThemedText { text: "Check the hotspot service and network routing."; color: Theme.muted; customSize: Constants.sizeXs + 1; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: height / 2
                            color: Theme.bg
                            border.width: 1
                            border.color: Theme.muted
                            ThemedText { anchors.centerIn: parent; text: root.diagnosticsBusy ? "Running checks…" : "Run connection checks"; color: Theme.accent; customSize: Constants.sizeXs + 1 }
                            MouseArea { anchors.fill: parent; enabled: !root.diagnosticsBusy; cursorShape: Qt.PointingHandCursor; onClicked: root.reloadDiagnostics() }
                        }
                        ThemedText {
                            visible: root.diagnosticText.length > 0
                            text: root.diagnosticText
                            wrapMode: Text.WordWrap
                            color: Theme.muted
                            customSize: Constants.sizeXs + 1
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
