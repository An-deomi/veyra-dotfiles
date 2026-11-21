import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

QuickSettingsTile {
    id: root

    property bool isLimitActive: false
    property bool isVisible: true
    property bool disabled: false
    readonly property string batteryStateText: {
        if (!SystemInfoService.hasBattery)
            return "No battery";

        let status = SystemInfoService.batteryStatus;
        if (!status || status === "Unknown")
            return SystemInfoService.batteryPercentage;

        return SystemInfoService.batteryPercentage + " • " + status;
    }

    isActive: root.isLimitActive
    icon: (SystemInfoService.batteryStatus === "Charging" || root.isActive) ? "charger-filled" : "charger"
    label: "Battery"
    subtitle: root.batteryStateText
    hasMenu: true
    onClicked: {
        if (!root.disabled)
            toggleProcess.running = true;

    }

    Rectangle {
        id: chargeRing

        visible: SystemInfoService.batteryStatus === "Charging"
        x: Constants.sizeXs - (width - Constants.size3Xl) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: Constants.size3Xl + 6
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        opacity: 0

        ParallelAnimation {
            running: chargeRing.visible
            loops: Animation.Infinite

            NumberAnimation {
                target: chargeRing
                property: "scale"
                from: 1
                to: 1.35
                duration: 1500
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: chargeRing
                property: "opacity"
                from: 0.7
                to: 0
                duration: 1500
                easing.type: Easing.OutCubic
            }

        }

    }

    Timer {
        id: updateTimer

        interval: 5000
        running: root.isVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statusProcess.running = true;
        }
    }

    Process {
        id: statusProcess

        command: [Quickshell.shellDir + "/Scripts/system/toggle_battery_limit.sh", "status"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                let val = data.trim();
                root.visible = true;
                if (val === "1") {
                    root.isLimitActive = true;
                    root.disabled = false;
                } else if (val === "0") {
                    root.isLimitActive = false;
                    root.disabled = false;
                } else if (val === "unsupported") {
                    root.disabled = true;
                    root.isLimitActive = false;
                }
            }
        }

    }

    Process {
        id: toggleProcess

        command: [Quickshell.shellDir + "/Scripts/system/toggle_battery_limit.sh", "toggle"]
        onRunningChanged: {
            if (!running)
                statusProcess.running = true;

        }

        stdout: SplitParser {
            onRead: (data) => {
                if (data && data.trim() === "1")
                    root.isLimitActive = true;
                else if (data && data.trim() === "0")
                    root.isLimitActive = false;
            }
        }

    }

}
