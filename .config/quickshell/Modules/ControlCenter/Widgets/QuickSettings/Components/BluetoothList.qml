import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components

Rectangle {
    id: root

    property bool expanded: false
    property bool isActive: false
    property var btList: []
    property bool isScanning: false
    property bool timedOut: false
    property bool isVisible: true
    property bool adapterAvailable: true
    property string adapterName: ""
    property string connectingMac: ""
    property string statusMessage: ""
    property bool actionFailed: false

    readonly property var pairedList: {
        const result = [];
        for (let i = 0; i < root.btList.length; i++) {
            if (root.btList[i].paired || root.btList[i].connected)
                result.push(root.btList[i]);
        }
        return result;
    }
    readonly property var availableList: {
        const result = [];
        for (let i = 0; i < root.btList.length; i++) {
            if (!root.btList[i].paired && !root.btList[i].connected)
                result.push(root.btList[i]);
        }
        return result;
    }
    readonly property int connectedCount: {
        let count = 0;
        for (let i = 0; i < root.btList.length; i++) {
            if (root.btList[i].connected)
                count++;
        }
        return count;
    }

    signal connect(string mac)
    signal refreshRequested()
    signal powerRequested()

    Layout.fillWidth: true
    Layout.fillHeight: expanded
    // Keep preferred height independent of child layout measurements.
    implicitHeight: expanded ? 150 : 0
    opacity: expanded ? 1 : 0
    visible: opacity > 0
    clip: true
    radius: 0
    color: "transparent"
    border.width: 0

    function deviceIcon(device) {
        const kind = String(device.icon || "").toLowerCase();
        if (kind.indexOf("keyboard") >= 0)
            return "keyboard-filled";
        if (kind.indexOf("mouse") >= 0 || kind.indexOf("pointing") >= 0)
            return "cursor";
        if (kind.indexOf("gaming") >= 0 || kind.indexOf("joystick") >= 0 || kind.indexOf("gamepad") >= 0)
            return "gamepad-filled";
        if (kind.indexOf("audio") >= 0 || kind.indexOf("headset") >= 0 || kind.indexOf("headphone") >= 0 || kind.indexOf("speaker") >= 0)
            return "music";
        if (kind.indexOf("computer") >= 0 || kind.indexOf("display") >= 0 || kind.indexOf("laptop") >= 0)
            return "monitor";
        return device.connected ? "bluetooth" : "bluetooth-off";
    }

    function deviceSubtitle(device, isPaired) {
        let value = device.connected ? "Connected" : (isPaired ? "Paired" : "New device · tap to pair");
        if (device.battery !== null && device.battery !== undefined && Number(device.battery) >= 0)
            value += " · Battery " + Number(device.battery) + "%";
        return value;
    }

    ColumnLayout {
        id: panelContent
        anchors.fill: parent
        spacing: Constants.sizeSm

        // Adapter state card: keep the status and a power control in the same page.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 68
            radius: Constants.sizeMd
            color: root.isActive ? Theme.bgAccent : Theme.bgSecondary
            border.width: 1
            border.color: root.isActive ? Theme.accent : Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Constants.sizeMd
                anchors.rightMargin: Constants.sizeSm
                spacing: Constants.sizeSm

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: Constants.size3Xl
                    height: Constants.size3Xl
                    radius: width / 2
                    color: root.isActive ? Theme.accent : Theme.bgTertiary

                    SvgIcon {
                        anchors.centerIn: parent
                        icon: root.adapterAvailable ? (root.isActive ? "bluetooth" : "bluetooth-off") : "warning"
                        iconColor: root.isActive ? Theme.bg : Theme.fg
                        iconSize: Constants.sizeLg
                        flat: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    ThemedText {
                        Layout.fillWidth: true
                        text: !root.adapterAvailable ? "Bluetooth unavailable" : (root.isActive ? "Bluetooth is on" : "Bluetooth is off")
                        color: Theme.fg
                        font.bold: true
                        customSize: Constants.sizeSm
                        elide: Text.ElideRight
                    }

                    ThemedText {
                        Layout.fillWidth: true
                        text: !root.adapterAvailable
                            ? "Check BlueZ and the Bluetooth adapter"
                            : (root.isActive
                                ? ((root.adapterName !== "" ? root.adapterName + " · " : "") + root.connectedCount + " connected · " + root.pairedList.length + " paired")
                                : "Turn Bluetooth on to discover devices")
                        color: Theme.muted
                        customSize: Constants.sizeXs + 2
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.adapterAvailable
                    implicitWidth: powerLabel.implicitWidth + Constants.sizeSm * 2
                    implicitHeight: Constants.size2Xl + 4
                    radius: height / 2
                    color: powerHover.hovered ? Theme.bgTertiary : (root.isActive ? Theme.bgSecondary : Theme.accent)
                    border.width: 1
                    border.color: root.isActive ? Theme.border : Theme.accent

                    ThemedText {
                        id: powerLabel
                        anchors.centerIn: parent
                        text: root.isActive ? "Turn off" : "Turn on"
                        color: root.isActive ? Theme.fg : Theme.bg
                        customSize: Constants.sizeXs + 2
                        font.bold: true
                    }

                    HoverHandler {
                        id: powerHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: root.powerRequested()
                    }
                }
            }
        }

        ThemedText {
            Layout.fillWidth: true
            visible: root.statusMessage !== ""
            text: root.statusMessage
            color: root.actionFailed ? Theme.accentComplementary : Theme.accent
            customSize: Constants.sizeXs + 2
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        // Helpful empty states instead of a blank device list.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Constants.sizeMd
            spacing: Constants.sizeSm
            visible: root.btList.length === 0

            Item {
                Layout.alignment: Qt.AlignHCenter
                width: Constants.size2Xl
                height: Constants.size2Xl
                visible: root.isActive && root.isScanning

                SvgIcon {
                    anchors.centerIn: parent
                    icon: "reload"
                    iconColor: Theme.accent
                    iconSize: Constants.sizeLg
                    flat: true
                }

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: Constants.animExpressive * 2
                    loops: Animation.Infinite
                    running: root.expanded && root.isScanning && root.btList.length === 0
                }
            }

            SvgIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: !root.adapterAvailable ? "warning" : (root.isActive ? "bluetooth-off" : "bluetooth-off")
                iconColor: Theme.muted
                iconSize: Constants.size2Xl
                flat: true
                visible: !root.isScanning
            }

            ThemedText {
                Layout.alignment: Qt.AlignHCenter
                text: !root.adapterAvailable
                    ? "No Bluetooth adapter available"
                    : (!root.isActive
                        ? "Bluetooth is turned off"
                        : (root.isScanning ? "Searching for nearby devices…" : "No devices found yet"))
                color: Theme.fg
                font.bold: root.isScanning
                customSize: Constants.sizeSm
            }

            ThemedText {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
            Layout.leftMargin: Constants.sizeSm
            Layout.rightMargin: Constants.sizeSm
                text: !root.adapterAvailable
                    ? "Check that the Bluetooth adapter is enabled and the BlueZ service is running."
                    : (!root.isActive
                        ? "Turn Bluetooth on above to scan for devices."
                        : (root.isScanning
                            ? "Put your headphones, keyboard, or other device into pairing mode."
                            : "Try scanning again with the refresh button above."))
                color: Theme.muted
                customSize: Constants.sizeXs + 2
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            visible: root.btList.length > 0
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: parent.width
                spacing: Constants.sizeMd

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Constants.sizeSm
                    visible: root.pairedList.length > 0

                    ThemedText {
                        text: "MY DEVICES"
                        customSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                        color: Theme.muted
                        Layout.fillWidth: true
                        Layout.leftMargin: Constants.size2Xs
                    }

                    Repeater {
                        model: root.pairedList

                        ControlCenterListDelegate {
                            Layout.fillWidth: true
                            titleText: modelData.name
                            subtitleText: root.deviceSubtitle(modelData, true)
                            iconName: root.deviceIcon(modelData)
                            isActive: modelData.connected
                            isConnecting: root.connectingMac === modelData.mac
                            canForget: true
                            onClicked: root.connect(modelData.mac)
                            onDisconnectClicked: root.connect(modelData.mac)
                            onForgetClicked: {
                                forgetProc.command = ["bluetoothctl", "remove", modelData.mac];
                                forgetProc.running = true;
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Constants.sizeSm
                    visible: root.availableList.length > 0

                    ThemedText {
                        text: "NEARBY DEVICES"
                        customSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                        color: Theme.muted
                        Layout.fillWidth: true
                        Layout.leftMargin: Constants.size2Xs
                    }

                    Repeater {
                        model: root.availableList

                        ControlCenterListDelegate {
                            Layout.fillWidth: true
                            titleText: modelData.name
                            subtitleText: root.deviceSubtitle(modelData, false)
                            iconName: root.deviceIcon(modelData)
                            isActive: false
                            isConnecting: root.connectingMac === modelData.mac
                            onClicked: root.connect(modelData.mac)
                        }
                    }
                }
            }
        }
    }

    Process {
        id: forgetProc
        onRunningChanged: {
            if (!running)
                root.refreshRequested();
        }
    }

    transform: Translate {
        y: root.expanded ? 0 : -Constants.sizeSm
        Behavior on y {
            NumberAnimation {
                duration: Constants.animNormal
                easing.type: Easing.OutCubic
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: root.expanded ? Easing.Linear : Easing.OutCubic
        }
    }
}
