import "Components"
import QtQuick
import Quickshell
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Windows
import qs.Modules.ControlCenter.Widgets.QuickSettings.Components

Item {
    id: root

    property bool quickSettingsOpen: false
    property var notificationService
    property int activePageIndex: 0
    property string audioMode: "out"
    property real extraExpandedHeight: 0

    function resetView() {
        root.activePageIndex = 0;
    }

    onQuickSettingsOpenChanged: {
        if (!quickSettingsOpen) {
            resetPageTimer.restart();
        } else {
            resetPageTimer.stop();
            root.resetView();
        }
    }

    onActivePageIndexChanged: {
        if (root.activePageIndex === 3 && root.quickSettingsOpen)
            Qt.callLater(batteryPage.refreshHardwareDetails);
    }

    implicitWidth: mainPage.implicitWidth
    implicitHeight: mainPage.implicitHeight + (activePageIndex !== 0 ? extraExpandedHeight : 0)

    Timer {
        id: resetPageTimer

        interval: Constants.animNormal + 50
        repeat: false
        onTriggered: {
            if (!root.quickSettingsOpen)
                root.resetView();

        }
    }

    Item {
        id: stackContainer

        anchors.fill: parent
        clip: true

        ColumnLayout {
            id: mainPage

            width: parent.width
            spacing: Constants.sizeMd
            x: root.activePageIndex === 0 ? 0 : -parent.width

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeMd

                ThemedText {
                    text: "CONNECTIVITY"
                    customSize: Constants.sizeXs + 1
                    font.bold: true
                    font.letterSpacing: 0.8
                    color: Theme.muted
                    Layout.leftMargin: Constants.size2Xs
                    Layout.topMargin: Constants.size2Xs
                }

                GridLayout {
                    id: topControlsGrid

                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: Constants.sizeXs
                    columnSpacing: Constants.sizeXs

                    WifiControl {
                        id: wifiControl

                        Layout.fillWidth: true
                        prominent: true
                        isVisible: root.quickSettingsOpen
                        expanded: root.activePageIndex === 1
                        onMenuClicked: {
                            root.activePageIndex = 1;
                        }
                        onIsActiveChanged: {
                            if (!isActive && root.activePageIndex === 1)
                                root.activePageIndex = 0;

                        }
                    }

                    BluetoothControl {
                        id: btControl

                        Layout.fillWidth: true
                        prominent: true
                        isVisible: root.quickSettingsOpen
                        expanded: root.activePageIndex === 2
                        onMenuClicked: {
                            root.activePageIndex = 2;
                        }
                    }

                }

                Card {
                    id: networkOverviewCard
                    Layout.fillWidth: true
                    cardRadius: Constants.sizeMd
                    useBorder: true
                    borderColor: Theme.border
                    backgroundColor: Theme.bgSecondary
                    contentPadding: Constants.sizeSm

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Constants.sizeXs

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Constants.sizeXs

                            ThemedText {
                                text: "NETWORK STATUS"
                                customSize: Constants.sizeXs + 1
                                font.bold: true
                                color: Theme.muted
                            }

                            Item { Layout.fillWidth: true; implicitWidth: 1; implicitHeight: 1 }

                            ThemedText {
                                text: wifiControl.vpnActive ? "VPN active" : "VPN off"
                                customSize: Constants.sizeXs + 1
                                color: wifiControl.vpnActive ? Theme.accent : Theme.muted
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Constants.sizeSm

                            NetworkStatusItem {
                                icon: wifiControl.wifiConnected ? "wifi" : "wifi-off"
                                label: "Wi-Fi"
                                value: wifiControl.wifiConnected
                                    ? (wifiControl.wifiConnection || "Connected")
                                    : (wifiControl.isActive ? "On · not connected" : "Off")
                                active: wifiControl.wifiConnected
                            }

                            NetworkStatusItem {
                                icon: "ethernet"
                                label: "Ethernet"
                                value: wifiControl.ethernetConnected
                                    ? (wifiControl.ethernetConnection || wifiControl.ethernetDevice || "Connected")
                                    : "Disconnected"
                                active: wifiControl.ethernetConnected
                            }

                            NetworkStatusItem {
                                icon: wifiControl.vpnActive ? "vpn" : "shield-off"
                                label: "VPN"
                                value: wifiControl.vpnActive
                                    ? ((wifiControl.vpnConnection && wifiControl.vpnConnection !== wifiControl.vpnDevice)
                                        ? wifiControl.vpnConnection : "Connected")
                                    : "Disconnected"
                                active: wifiControl.vpnActive
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Constants.size2Xs
                    Layout.leftMargin: Constants.size2Xs

                    ThemedText {
                        text: "QUICK TOGGLES"
                        customSize: Constants.sizeXs + 1
                        font.bold: true
                        font.letterSpacing: 0.8
                        color: Theme.muted
                    }

                    Item { Layout.fillWidth: true }

                    ThemedText {
                        text: "6 SHORTCUTS"
                        customSize: Constants.size2Xs
                        color: Theme.muted
                    }
                }

                GridLayout {
                    id: middleControlsGrid

                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: Constants.sizeSm
                    columnSpacing: Constants.sizeSm

                    NightLightControl {
                        id: nightLightBtn

                        Layout.fillWidth: true
                    }

                    CaffeineControl {
                        id: caffeineBtn

                        Layout.fillWidth: true
                    }

                    GameModeControl {
                        id: gamepadBtn

                        Layout.fillWidth: true
                    }

                    BatteryLimitControl {
                        id: batteryLimitBtn

                        Layout.fillWidth: true
                        isVisible: root.quickSettingsOpen
                        onMenuClicked: root.activePageIndex = 3
                    }

                    HotspotControl {
                        id: hotspotBtn

                        Layout.fillWidth: true
                        isVisible: root.quickSettingsOpen
                        onMenuClicked: root.activePageIndex = 4
                    }

                    DoNotDisturbControl {
                        Layout.fillWidth: true
                    }

                }

                ThemedText {
                    text: "DISPLAY & AUDIO"
                    customSize: Constants.sizeXs + 1
                    font.bold: true
                    font.letterSpacing: 0.8
                    color: Theme.muted
                    Layout.leftMargin: Constants.size2Xs
                    Layout.topMargin: Constants.size2Xs
                }

                Card {
                    Layout.fillWidth: true
                    cardRadius: Constants.sizeMd
                    useBorder: true
                    borderColor: Theme.border
                    backgroundColor: Theme.bgSecondary
                    contentPadding: Constants.sizeSm

                    ColumnLayout {
                        id: sliderCol

                        anchors.fill: parent
                        spacing: Constants.sizeXs

                        BrightnessSlider {
                            Layout.fillWidth: true
                            isVisible: root.quickSettingsOpen
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Constants.sizeXs

                            SvgIconButton {
                                icon: "tune"
                                iconSize: Constants.sizeMd
                                flat: true
                                onClicked: {
                                    root.audioMode = "out";
                                    root.activePageIndex = 5;
                                }
                            }

                            VolumeSlider {
                                Layout.fillWidth: true
                            }

                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Constants.sizeXs

                            SvgIconButton {
                                icon: "tune"
                                iconSize: Constants.sizeMd
                                flat: true
                                onClicked: {
                                    root.audioMode = "in";
                                    root.activePageIndex = 5;
                                }
                            }

                        ThemedSlider {
                            id: micSlider

                            label: "Microphone input"
                            Layout.fillWidth: true
                            enabled: AudioService.hasPhysicalMic
                            value: AudioService.micVolume
                            icon: AudioService.micMuted ? "microphone-off" : "microphone"
                            onMoved: (val) => {
                                AudioService.setMicVolume(val);
                                                }
                            onIconClicked: {
                                AudioService.setMicMuted(!AudioService.micMuted);
                                            }
                        }

                        }

                    }

                }

            }

            Behavior on x {
                enabled: root.quickSettingsOpen

                NumberAnimation {
                    duration: Constants.animNormal
                    easing.type: Easing.OutCubic
                }

            }

        }

        ColumnLayout {
            id: wifiPage

            spacing: Constants.sizeSm
            width: parent.width
            height: parent.height
            x: root.activePageIndex === 1 ? 0 : parent.width

            RowLayout {
                Layout.fillWidth: true

                SvgIconButton {
                    icon: "chevron-left"
                    iconSize: Constants.sizeLg
                    flat: true
                    onClicked: root.activePageIndex = 0
                }

                ThemedText {
                    text: wifiList.showSavedProfiles ? "Saved Wi-Fi Networks" : "Wi-Fi Networks"
                    customSize: Constants.sizeMd
                    font.bold: true
                    Layout.fillWidth: true
                }

                SvgIconButton {
                    icon: "tune"
                    iconSize: Constants.sizeMd
                    flat: true
                    onClicked: wifiList.openSavedProfiles()
                }

                SvgIconButton {
                    icon: "reload"
                    iconSize: Constants.sizeMd
                    flat: true
                    onClicked: wifiControl.scan()
                    visible: wifiControl.isActive && !wifiList.showSavedProfiles

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: Constants.animExpressive * 2
                        loops: Animation.Infinite
                        running: wifiControl.isScanning
                    }

                }

            }

            WifiList {
                id: wifiList
                Layout.fillWidth: true
                Layout.fillHeight: true
                isVisible: root.quickSettingsOpen
                expanded: root.activePageIndex === 1
                isActive: wifiControl.isActive
                wifiList: wifiControl.wifiList
                isScanning: wifiControl.isScanning
                onConnect: (ssid) => {
                    return wifiControl.connect(ssid);
                }
                connecting: wifiControl.isConnecting
                connectError: wifiControl.connectError
                connectErrorSsid: wifiControl.connectingSsid
                connectionStatus: wifiControl.connectionStatus
                connectionStatusSuccess: wifiControl.connectionStatusSuccess
                onConnectWithPassword: (ssid, password) => {
                    return wifiControl.connectWithPassword(ssid, password);
                }
                onPasswordCancelled: wifiControl.connectError = ""
                onRefreshRequested: {
                    wifiControl.scan(true);
                }
            }

            Behavior on x {
                enabled: root.quickSettingsOpen

                NumberAnimation {
                    duration: Constants.animNormal
                    easing.type: Easing.OutCubic
                }

            }

        }

        ColumnLayout {
            id: hotspotPageCol

            spacing: Constants.sizeSm
            width: parent.width
            height: parent.height
            x: root.activePageIndex === 4 ? 0 : parent.width

            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                SvgIconButton {
                    icon: "chevron-left"
                    iconSize: Constants.sizeLg
                    flat: true
                    onClicked: root.activePageIndex = 0
                }

                ThemedText {
                    text: "Hotspot"
                    customSize: Constants.sizeMd
                    font.bold: true
                    Layout.fillWidth: true
                }

            }

            HotspotPage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                isOpen: root.activePageIndex === 4 && root.quickSettingsOpen
                profileName: hotspotBtn.profileName
                hotspotActive: hotspotBtn.isActive
                busy: hotspotBtn.busy
                actionMessage: hotspotBtn.statusMessage
                onToggleRequested: hotspotBtn.clicked()
            }

            Behavior on x {
                enabled: root.quickSettingsOpen

                NumberAnimation {
                    duration: Constants.animNormal
                    easing.type: Easing.OutCubic
                }

            }

        }

        ColumnLayout {
            id: audioPageCol

            spacing: Constants.sizeSm
            width: parent.width
            height: parent.height
            x: root.activePageIndex === 5 ? 0 : parent.width

            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                SvgIconButton {
                    icon: "chevron-left"
                    iconSize: Constants.sizeLg
                    flat: true
                    onClicked: root.activePageIndex = 0
                }

                ThemedText {
                    text: "Audio Center"
                    customSize: Constants.sizeMd
                    font.bold: true
                    Layout.fillWidth: true
                }

            }

            AudioPage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                isOpen: root.activePageIndex === 5 && root.quickSettingsOpen
                mode: root.audioMode
                onModeRequested: (requestedMode) => { root.audioMode = requestedMode; }
            }

            Behavior on x {
                enabled: root.quickSettingsOpen

                NumberAnimation {
                    duration: Constants.animNormal
                    easing.type: Easing.OutCubic
                }

            }

        }

        ColumnLayout {
            id: batteryPage

            property var hardwareDetails: ({})
            readonly property var dev: UPower.displayDevice
            readonly property bool devReady: dev !== null && dev.ready
            readonly property int st: devReady ? dev.state : UPowerDeviceState.Unknown
            readonly property bool charging: st === UPowerDeviceState.Charging
            readonly property bool discharging: st === UPowerDeviceState.Discharging
            readonly property real watts: devReady ? Math.abs(dev.changeRate) : 0
            readonly property real upowerHealth: Number(hardwareDetails.healthPercentage || 0)
            readonly property bool directHealthAvailable: devReady && dev.healthSupported && dev.healthPercentage > 0
            readonly property bool reportedHealthAvailable: directHealthAvailable || upowerHealth > 0
            readonly property real fullCapacityWh: devReady && dev.energyCapacity > 0
                ? dev.energyCapacity : Number(hardwareDetails.fullCapacityWh || 0)
            readonly property real remainingEnergyWh: devReady && dev.energy > 0 ? dev.energy : 0
            readonly property real reportedHealth: directHealthAvailable ? dev.healthPercentage : upowerHealth
            readonly property real designCapacityWh: Number(hardwareDetails.designCapacityWh || 0) > 0
                ? Number(hardwareDetails.designCapacityWh)
                : (reportedHealthAvailable && fullCapacityWh > 0
                    ? fullCapacityWh / (reportedHealth / 100) : 0)
            readonly property real healthPercent: reportedHealthAvailable
                ? Math.max(0, Math.min(100, reportedHealth))
                : (designCapacityWh > 0 && fullCapacityWh > 0
                    ? Math.max(0, Math.min(100, fullCapacityWh / designCapacityWh * 100)) : 0)
            readonly property bool healthAvailable: healthPercent > 0
            readonly property real wearPercent: healthAvailable ? Math.max(0, 100 - healthPercent) : 0
            readonly property string healthLabel: {
                if (!healthAvailable)
                    return "Not reported";
                if (healthPercent >= 80)
                    return "Good";
                if (healthPercent >= 60)
                    return "Reduced capacity";
                if (healthPercent >= 40)
                    return "Degraded";
                return "Heavily worn";
            }
            readonly property string modelName: {
                const manufacturer = String(hardwareDetails.manufacturer || "").trim();
                const model = String(hardwareDetails.model || (devReady ? dev.model : "") || "").trim();
                return manufacturer && model ? manufacturer + " · " + model : (model || manufacturer);
            }
            readonly property string hardwareSourceText: String(hardwareDetails.source || "").trim()
            readonly property string voltageText: Number(hardwareDetails.voltage) > 0
                ? Number(hardwareDetails.voltage).toFixed(2) + " V" : "—"
            readonly property string powerUsageLabel: charging ? "CHARGE RATE" : (discharging ? "POWER DRAW" : "POWER USAGE")
            readonly property string powerUsageText: devReady && Number.isFinite(watts)
                ? watts.toFixed(1) + " W" : "—"
            readonly property string timeRemainingLabel: charging ? "TIME TO FULL" : (discharging ? "TIME LEFT" : "TIME REMAINING")
            readonly property string timeRemainingText: {
                if (charging)
                    return fmtTime(devReady ? dev.timeToFull : 0);
                if (discharging)
                    return fmtTime(devReady ? dev.timeToEmpty : 0);
                if (st === UPowerDeviceState.FullyCharged)
                    return "Fully charged";
                return "—";
            }
            readonly property string stateText: {
                if (st === UPowerDeviceState.FullyCharged)
                    return "Fully charged";
                if (st === UPowerDeviceState.Empty)
                    return "Empty";
                if (st === UPowerDeviceState.PendingCharge || st === UPowerDeviceState.PendingDischarge)
                    return "Not charging";
                if (discharging)
                    return "On battery";
                return "Power status unavailable";
            }
            readonly property string batteryIcon: charging ? "battery-charging" : (discharging ? "battery-medium" : "battery-full")
            readonly property string chargeDetail: charging
                ? "AC power connected"
                : (discharging ? "Battery power" : stateText)

            function refreshHardwareDetails() {
                if (batteryHardwareProc.running)
                    batteryHardwareProc.running = false;
                batteryHardwareProc.running = true;
            }

            function fmtTime(sec) {
                if (!sec || sec <= 0)
                    return "Calculating...";
                let h = Math.floor(sec / 3600);
                let m = Math.round((sec % 3600) / 60);
                if (m === 60) {
                    h += 1;
                    m = 0;
                }
                return h > 0 ? (h + "h " + m + "m") : (m + " min");
            }

            Process {
                id: batteryHardwareProc

                command: ["python3", Quickshell.shellDir + "/Scripts/system/battery_details.py"]
                onExited: (exitCode) => {
                    if (exitCode !== 0) {
                        const errorText = batteryHardwareError.text.trim();
                        batteryPage.hardwareDetails = ({ available: false, error: errorText || ("Battery reader exited with code " + exitCode) });
                        console.warn("Veyra: battery hardware reader failed:", batteryPage.hardwareDetails.error);
                        return;
                    }
                    try {
                        const raw = batteryHardwareOutput.text.trim();
                        batteryPage.hardwareDetails = raw ? JSON.parse(raw) : ({ available: false, error: "Battery reader returned no data" });
                    } catch (error) {
                        batteryPage.hardwareDetails = ({ available: false, error: String(error) });
                        console.warn("Veyra: could not parse battery hardware details:", error);
                    }
                }

                stdout: StdioCollector {
                    id: batteryHardwareOutput
                }

                stderr: StdioCollector {
                    id: batteryHardwareError
                }
            }

            spacing: Constants.sizeSm
            width: parent.width
            height: parent.height
            x: root.activePageIndex === 3 ? 0 : parent.width

            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                SvgIconButton {
                    icon: "chevron-left"
                    iconSize: Constants.sizeLg
                    flat: true
                    onClicked: root.activePageIndex = 0
                }

                ThemedText {
                    text: "Battery & power"
                    customSize: Constants.sizeXl + 1
                    font.bold: true
                    Layout.fillWidth: true
                }

                SvgIconButton {
                    icon: "refresh"
                    iconSize: Constants.sizeMd
                    flat: true
                    disabled: batteryHardwareProc.running
                    onClicked: batteryPage.refreshHardwareDetails()
                }
            }

            // Keep the title fixed while the longer dashboard scrolls independently.
            // ScrollView handles mouse-wheel, touchpad and touch scrolling.
            ScrollView {
                id: batteryScroll

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    id: batteryScrollContent

                    width: batteryScroll.availableWidth
                    spacing: Constants.sizeSm

                // Charge hero: one strong number, one progress indicator, no tiny metadata rows.
                Card {
                    Layout.fillWidth: true
                    cardRadius: Constants.sizeXl
                    contentPadding: Constants.sizeMd
                    backgroundColor: Theme.bgAccent
                    borderColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24)

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Constants.sizeSm

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Constants.sizeSm

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                ThemedText {
                                    text: "CURRENT CHARGE"
                                    customSize: Constants.sizeSm
                                    color: Theme.muted
                                    font.bold: true
                                    font.letterSpacing: 0.7
                                }

                                ThemedText {
                                    text: Math.round(SystemInfoService.batteryLevel) + "%"
                                    customSize: Constants.size4Xl + 4
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 58
                                Layout.preferredHeight: 58
                                radius: 20
                                color: Theme.bgAccent
                                border.width: 1
                                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.32)

                                SvgIcon {
                                    anchors.centerIn: parent
                                    icon: batteryPage.batteryIcon
                                    iconSize: Constants.size2Xl + 2
                                    iconColor: Theme.accent
                                    flat: true
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 9
                            radius: height / 2
                            color: Theme.bgSecondary
                            clip: true

                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(100, SystemInfoService.batteryLevel)) / 100
                                height: parent.height
                                radius: height / 2
                                color: Theme.accent

                                Behavior on width {
                                    NumberAnimation {
                                        duration: Constants.animNormal
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Constants.sizeXs

                            Rectangle {
                                Layout.preferredWidth: 7
                                Layout.preferredHeight: 7
                                radius: 4
                                color: batteryPage.charging ? Theme.accent : (batteryPage.discharging ? Theme.accentComplementary : Theme.muted)
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ThemedText {
                                text: batteryPage.charging ? "Charging" : (batteryPage.discharging ? "On battery" : batteryPage.stateText)
                                customSize: Constants.sizeMd
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            ThemedText {
                                text: batteryPage.chargeDetail
                                customSize: Constants.sizeSm
                                color: Theme.muted
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }

                // Health and capacity use a larger type scale and a clear hierarchy.
                Card {
                    Layout.fillWidth: true
                    cardRadius: Constants.sizeXl
                    contentPadding: Constants.sizeMd
                    backgroundColor: Theme.bgSecondary
                    borderColor: Theme.border

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Constants.sizeSm

                        RowLayout {
                            Layout.fillWidth: true

                            ThemedText {
                                text: "BATTERY HEALTH"
                                customSize: Constants.sizeSm
                                color: Theme.muted
                                font.bold: true
                                font.letterSpacing: 0.7
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredWidth: healthStatusLabel.implicitWidth + Constants.sizeSm * 2
                                Layout.preferredHeight: Constants.size2Xl
                                radius: height / 2
                                color: batteryPage.healthAvailable ? Theme.bgAccent : Theme.bgTertiary

                                ThemedText {
                                    id: healthStatusLabel
                                    anchors.centerIn: parent
                                    text: batteryPage.healthLabel
                                    customSize: Constants.sizeXs + 2
                                    color: batteryPage.healthAvailable ? Theme.accent : Theme.muted
                                    font.bold: true
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Constants.sizeSm

                            ThemedText {
                                text: batteryPage.healthAvailable ? batteryPage.healthPercent.toFixed(1) + "%" : "N/A"
                                customSize: Constants.size3Xl + 4
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            ColumnLayout {
                                spacing: 1
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                                ThemedText {
                                    text: batteryPage.healthAvailable ? batteryPage.wearPercent.toFixed(1) + "% wear" : "Health unavailable"
                                    customSize: Constants.sizeMd
                                    font.bold: true
                                    horizontalAlignment: Text.AlignRight
                                }

                                ThemedText {
                                    text: batteryPage.directHealthAvailable
                                        ? "Battery firmware"
                                        : (batteryPage.upowerHealth > 0
                                            ? "UPower capacity report"
                                            : (batteryPage.healthAvailable ? "Capacity estimate" : "Not exposed by firmware"))
                                    customSize: Constants.sizeXs + 2
                                    color: Theme.muted
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 7
                            radius: height / 2
                            color: Theme.bgTertiary
                            clip: true

                            Rectangle {
                                width: parent.width * (batteryPage.healthAvailable ? batteryPage.healthPercent / 100 : 0)
                                height: parent.height
                                radius: height / 2
                                color: batteryPage.healthPercent >= 80 ? Theme.accent : Theme.accentComplementary

                                Behavior on width {
                                    NumberAnimation { duration: Constants.animNormal; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: Constants.sizeXs
                            columnSpacing: Constants.sizeXs

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                radius: Constants.sizeSm
                                color: Theme.bgTertiary
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Constants.sizeSm
                                    spacing: 0
                                    ThemedText { text: "FULL CHARGE"; customSize: Constants.sizeXs + 2; color: Theme.muted; font.bold: true }
                                    ThemedText {
                                        text: batteryPage.fullCapacityWh > 0 ? batteryPage.fullCapacityWh.toFixed(1) + " Wh" : "—"
                                        customSize: Constants.sizeLg
                                        font.bold: true
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                radius: Constants.sizeSm
                                color: Theme.bgTertiary
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Constants.sizeSm
                                    spacing: 0
                                    ThemedText { text: "DESIGN CAPACITY"; customSize: Constants.sizeXs + 2; color: Theme.muted; font.bold: true }
                                    ThemedText {
                                        text: batteryPage.designCapacityWh > 0 ? batteryPage.designCapacityWh.toFixed(1) + " Wh" : "—"
                                        customSize: Constants.sizeLg
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }

                // Four concise diagnostics; unavailable values remain obvious, not hidden.
                Card {
                    Layout.fillWidth: true
                    cardRadius: Constants.sizeXl
                    contentPadding: Constants.sizeMd
                    backgroundColor: Theme.bgSecondary
                    borderColor: Theme.border

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Constants.sizeXs

                        RowLayout {
                            Layout.fillWidth: true
                            ThemedText {
                                text: "BATTERY DETAILS"
                                customSize: Constants.sizeSm
                                color: Theme.muted
                                font.bold: true
                                font.letterSpacing: 0.7
                                Layout.fillWidth: true
                            }
                            ThemedText {
                                text: batteryPage.remainingEnergyWh > 0 ? batteryPage.remainingEnergyWh.toFixed(1) + " Wh left" : ""
                                customSize: Constants.sizeXs + 2
                                color: Theme.muted
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: Constants.sizeXs
                            columnSpacing: Constants.sizeXs

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                radius: Constants.sizeSm
                                color: Theme.bgTertiary
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Constants.sizeXs
                                    spacing: 0
                                    ThemedText { text: "VOLTAGE"; customSize: Constants.sizeXs + 2; color: Theme.muted; font.bold: true }
                                    ThemedText { text: batteryPage.voltageText; customSize: Constants.sizeMd; font.bold: true }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                radius: Constants.sizeSm
                                color: Theme.bgTertiary
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Constants.sizeXs
                                    spacing: 0
                                    ThemedText { text: batteryPage.powerUsageLabel; customSize: Constants.sizeXs + 2; color: Theme.muted; font.bold: true }
                                    ThemedText { text: batteryPage.powerUsageText; customSize: Constants.sizeMd; font.bold: true }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                radius: Constants.sizeSm
                                color: Theme.bgTertiary
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Constants.sizeXs
                                    spacing: 0
                                    ThemedText { text: batteryPage.timeRemainingLabel; customSize: Constants.sizeXs + 2; color: Theme.muted; font.bold: true }
                                    ThemedText { text: batteryPage.timeRemainingText; customSize: Constants.sizeMd; font.bold: true }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                radius: Constants.sizeSm
                                color: Theme.bgTertiary
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Constants.sizeXs
                                    spacing: 0
                                    ThemedText { text: "BATTERY MODEL"; customSize: Constants.sizeXs + 2; color: Theme.muted; font.bold: true }
                                    ThemedText {
                                        text: batteryPage.modelName !== "" ? batteryPage.modelName : "—"
                                        customSize: Constants.sizeMd
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }

                        ThemedText {
                            Layout.fillWidth: true
                            text: batteryHardwareProc.running
                                ? "Refreshing hardware details…"
                                : (batteryPage.hardwareSourceText !== ""
                                    ? "Data source · " + batteryPage.hardwareSourceText
                                    : (batteryPage.hardwareDetails.error || "Some details are not exposed by the battery firmware"))
                            color: Theme.muted
                            customSize: Constants.sizeXs + 1
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // A single, spacious Material-style control row keeps the toggle easy to hit.
                Card {
                    Layout.fillWidth: true
                    cardRadius: Constants.sizeXl
                    contentPadding: Constants.sizeMd
                    backgroundColor: Theme.bgSecondary
                    borderColor: Theme.border

                    RowLayout {
                        anchors.fill: parent
                        spacing: Constants.sizeSm

                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            radius: Constants.sizeMd
                            color: Theme.bgAccent
                            SvgIcon {
                                anchors.centerIn: parent
                                icon: "charger-filled"
                                iconSize: Constants.sizeXl
                                iconColor: Theme.accent
                                flat: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            ThemedText {
                                text: batteryLimitBtn.disabled ? "Charge limit unavailable" : "Battery protection"
                                customSize: Constants.sizeMd
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            ThemedText {
                                text: batteryLimitBtn.disabled ? "Not supported on this device" : "Stop charging at 80%"
                                customSize: Constants.sizeXs + 2
                                color: Theme.muted
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 30
                            radius: height / 2
                            color: batteryLimitBtn.isLimitActive ? Theme.accent : Theme.bgTertiary
                            border.width: batteryLimitBtn.isLimitActive ? 0 : 1
                            border.color: Theme.border
                            opacity: batteryLimitBtn.disabled ? 0.4 : 1

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                anchors.verticalCenter: parent.verticalCenter
                                x: batteryLimitBtn.isLimitActive ? parent.width - width - 4 : 4
                                color: batteryLimitBtn.isLimitActive ? Theme.bg : Theme.muted

                                Behavior on x {
                                    NumberAnimation { duration: Constants.animFast; easing.type: Easing.OutCubic }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !batteryLimitBtn.disabled
                                onClicked: batteryLimitBtn.clicked()
                            }
                        }
                    }
                }

                }
            }

            Behavior on x {
                enabled: root.quickSettingsOpen
                NumberAnimation {
                    duration: Constants.animNormal
                    easing.type: Easing.OutCubic
                }
            }
        }

        ColumnLayout {
            id: bluetoothPage

            spacing: Constants.sizeSm
            width: parent.width
            height: parent.height
            x: root.activePageIndex === 2 ? 0 : parent.width

            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                SvgIconButton {
                    icon: "chevron-left"
                    iconSize: Constants.sizeLg
                    flat: true
                    onClicked: root.activePageIndex = 0
                }

                ThemedText {
                    text: "Bluetooth Devices"
                    customSize: Constants.sizeMd
                    font.bold: true
                    Layout.fillWidth: true
                }

                SvgIconButton {
                    icon: "reload"
                    iconSize: Constants.sizeMd
                    flat: true
                    onClicked: btControl.scan()
                    visible: btControl.isActive

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: Constants.animExpressive * 2
                        loops: Animation.Infinite
                        running: btControl.isScanning
                    }

                }

            }

            BluetoothList {
                Layout.fillWidth: true
                Layout.fillHeight: true
                isVisible: root.quickSettingsOpen
                expanded: root.activePageIndex === 2
                isActive: btControl.isActive
                btList: btControl.btList
                isScanning: btControl.isScanning
                connectingMac: btControl.connectingMac
                statusMessage: btControl.statusMessage
                actionFailed: btControl.actionFailed
                adapterAvailable: btControl.adapterAvailable
                adapterName: btControl.adapterName
                onConnect: (mac) => {
                    return btControl.connect(mac);
                }
                onRefreshRequested: {
                    btControl.scan();
                }
                onPowerRequested: btControl.toggle()
            }

            Behavior on x {
                enabled: root.quickSettingsOpen

                NumberAnimation {
                    duration: Constants.animNormal
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

}
