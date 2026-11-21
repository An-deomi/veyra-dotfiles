import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

Rectangle {
    id: root

    property bool expanded: false
    property bool isActive: false
    property var wifiList: []
    property bool isScanning: false
    property bool timedOut: false
    property bool isVisible: true
    property string connectionStatus: ""
    property bool connectionStatusSuccess: false
    readonly property var savedList: {
        let res = [];
        for (let i = 0; i < root.wifiList.length; i++) {
            const net = root.wifiList[i];
            if ((net.saved || net.active) && root.pendingSsid !== net.ssid)
                res.push(net);
        }
        return res;
    }
    readonly property var availableList: {
        let res = [];
        for (let i = 0; i < root.wifiList.length; i++) {
            const net = root.wifiList[i];
            if ((!net.saved && !net.active) ||
                (!net.active && root.pendingSsid === net.ssid))
                res.push(net);
        }
        return res;
    }

    signal connect(string ssid)
    signal refreshRequested()
    signal connectWithPassword(string ssid, string password)
    signal passwordCancelled()
    signal focusPasswordRequested()

    property string pendingSsid: ""
    property string passwordInput: ""
    property bool connecting: false
    property string connectError: ""
    property string connectErrorSsid: ""
    property bool showSavedProfiles: false
    property var savedProfiles: []
    property string editingProfileUuid: ""
    property string newSavedPassword: ""
    property string savedActionMessage: ""
    property bool savedActionSuccess: false
    property string forgetProfileUuid: ""
    property string forgetProfileSsid: ""
    property string shownSavedPasswordUuid: ""
    property string shownSavedPassword: ""
    property string loadingSavedPasswordUuid: ""
    readonly property bool savedPasswordBusy: savedPasswordProc.running

    function openConnectionEditor() {
        settingsProc.running = true;
    }

    function loadSavedProfiles() {
        savedProfilesProc.command = [
            "python3",
            Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py",
            "saved"
        ];
        savedProfilesProc.running = false;
        savedProfilesProc.running = true;
    }

    function openSavedProfiles() {
        root.showSavedProfiles = true;
        root.editingProfileUuid = "";
        root.newSavedPassword = "";
        root.savedActionMessage = "";
        root.savedActionSuccess = false;
        root.loadSavedProfiles();
    }

    function askForgetProfile(ssid, profileUuid) {
        if (forgetSavedProc.running)
            return;

        root.forgetProfileSsid = ssid;
        root.forgetProfileUuid = profileUuid || "";
        root.savedActionMessage = "";
        root.savedActionSuccess = false;
        root.editingProfileUuid = "";
        root.shownSavedPasswordUuid = "";
        root.shownSavedPassword = "";
    }

    function saveSavedPassword(profileUuid) {
        if (root.newSavedPassword === "" || savedPasswordProc.running)
            return;

        root.savedActionMessage = "";
        root.savedActionSuccess = false;
        // Secret travels over stdin, never in argv (/proc/<pid>/cmdline).
        savedPasswordProc.stdinEnabled = true;
        savedPasswordProc.command = [
            "python3",
            Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py",
            "set-password",
            profileUuid,
            "--stdin"
        ];
        savedPasswordProc.running = true;
        savedPasswordProc.write(root.newSavedPassword + "\n");
        savedPasswordProc.stdinEnabled = false;
    }

    function toggleSavedPassword(profile) {
        const uuid = profile.profile_uuid;

        if (root.shownSavedPasswordUuid === uuid) {
            root.shownSavedPasswordUuid = "";
            root.shownSavedPassword = "";
            return;
        }

        if (showSavedPasswordProc.running)
            return;

        root.shownSavedPasswordUuid = "";
        root.shownSavedPassword = "";
        root.loadingSavedPasswordUuid = uuid;
        root.savedActionMessage = "";

        showSavedPasswordProc.command = [
            "python3",
            Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py",
            "get-password",
            uuid
        ];
        showSavedPasswordProc.running = true;
    }

    function requestConnect(net, forcePassword) {
        if (net.active || !net.security) {
            root.connect(net.ssid);
            return;
        }

        if (!forcePassword && net.saved &&
            (!net.can_change_password || net.has_password)) {
            root.connect(net.ssid);
            return;
        }

        root.connectError = "";
        root.pendingSsid = net.ssid;
    }

    function submitPassword() {
        if (root.passwordInput === "" || root.connecting)
            return ;

        root.connectWithPassword(root.pendingSsid, root.passwordInput);
    }

    function cancelPassword() {
        root.passwordInput = "";
        root.pendingSsid = "";
        root.passwordCancelled();
    }

    onPendingSsidChanged: {
        AppState.textInputActive =
            (pendingSsid !== "" || editingProfileUuid !== "");
        root.passwordInput = "";
        if (pendingSsid !== "")
            focusTimer.restart();
    }

    onEditingProfileUuidChanged: {
        AppState.textInputActive =
            (pendingSsid !== "" || editingProfileUuid !== "");
        root.newSavedPassword = "";
    }

    onExpandedChanged: {
        if (!expanded && pendingSsid !== "")
            cancelPassword();

        if (!expanded) {
            root.showSavedProfiles = false;
            root.editingProfileUuid = "";
            root.newSavedPassword = "";
            root.shownSavedPasswordUuid = "";
            root.shownSavedPassword = "";
            root.loadingSavedPasswordUuid = "";
        }
    }
    onConnectingChanged: {
        if (!connecting && pendingSsid !== "")
            closeCheck.restart();

    }
    Component.onDestruction: AppState.textInputActive = false

    Timer {
        id: focusTimer

        interval: 150
        repeat: false
        onTriggered: root.focusPasswordRequested()
    }

    Timer {
        id: closeCheck

        interval: 300
        repeat: false
        onTriggered: {
            if (root.connectError === "")
                root.cancelPassword();

        }
    }

    function getWifiIcon(signal) {
        let sig = parseInt(signal) || 0;
        if (sig <= 25)
            return "wifi-0";

        if (sig <= 50)
            return "wifi-1";

        if (sig <= 75)
            return "wifi-2";

        return "wifi";
    }

    Layout.fillWidth: true
    Layout.fillHeight: expanded
    implicitHeight: expanded ? Math.max(wifiListCol.implicitHeight, 80) : 0
    opacity: expanded ? 1 : 0
    visible: opacity > 0
    clip: true
    radius: 0
    color: "transparent"
    border.width: 0

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Constants.sizeSm
        visible: root.expanded && root.wifiList.length === 0 && !root.showSavedProfiles

        Item {
            Layout.alignment: Qt.AlignHCenter
            width: Constants.size2Xl
            height: Constants.size2Xl
            visible: root.isScanning

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
                running: root.expanded && root.isScanning && root.wifiList.length === 0
            }

        }

        SvgIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: "wifi-off"
            iconColor: Theme.muted
            iconSize: Constants.size2Xl
            flat: true
            visible: !root.isScanning
        }

        ThemedText {
            Layout.alignment: Qt.AlignHCenter
            text: root.isScanning ? "Searching for networks..." : "No networks found"
            color: root.isScanning ? Theme.fg : Theme.muted
            font.bold: root.isScanning
        }

        ThemedText {
            Layout.alignment: Qt.AlignHCenter
            text: "Make sure Wi-Fi is turned on or tap reload"
            color: Theme.muted
            customSize: Constants.sizeXs + 2
            visible: !root.isScanning
        }

    }

    ColumnLayout {
        id: wifiListCol

        anchors.fill: parent
        visible: root.wifiList.length > 0 || root.showSavedProfiles
            || root.connectionStatus !== ""

        Rectangle {
            Layout.fillWidth: true
            visible: root.connectionStatus !== ""
            implicitHeight: statusText.implicitHeight + Constants.sizeSm * 2
            radius: Constants.sizeMd
            color: Theme.bgSecondary
            border.width: 1
            border.color: root.connectionStatus.startsWith("Connecting to ")
                ? Theme.border
                : (root.connectionStatusSuccess ? Theme.accent : Theme.accentComplementary)

            ThemedText {
                id: statusText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Constants.sizeMd
                anchors.rightMargin: Constants.sizeMd
                text: root.connectionStatus
                color: (root.connectionStatusSuccess ||
                    root.connectionStatus.startsWith("Connecting to "))
                    ? Theme.fg : Theme.accentComplementary
                customSize: Constants.sizeXs + 2
                wrapMode: Text.WordWrap
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.forgetProfileUuid !== "" || root.forgetProfileSsid !== ""
            spacing: Constants.sizeSm

            Rectangle {
                Layout.fillWidth: true
                radius: Constants.sizeMd
                color: Theme.bgSecondary
                border.width: 1
                border.color: Theme.border
                implicitHeight: forgetConfirmContents.implicitHeight + Constants.sizeMd * 2

                ColumnLayout {
                    id: forgetConfirmContents
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Constants.sizeMd
                    spacing: Constants.sizeSm

                    ThemedText {
                        text: "Forget saved Wi-Fi?"
                        color: Theme.fg
                        customSize: Constants.sizeMd
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    ThemedText {
                        text: 'Remove "' + root.forgetProfileSsid +
                            '" from saved Wi-Fi networks?'
                        color: Theme.muted
                        customSize: Constants.sizeSm
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    ThemedText {
                        visible: root.savedActionMessage !== "" && !root.savedActionSuccess
                        text: root.savedActionMessage
                        color: Theme.accentComplementary
                        customSize: Constants.sizeXs + 2
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Constants.sizeSm

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: forgetCancelLabel.implicitWidth + Constants.sizeLg * 2
                            implicitHeight: Constants.size2Xl + 4
                            radius: height / 2
                            color: Theme.bg
                            opacity: forgetSavedProc.running ? 0.5 : 1

                            ThemedText {
                                id: forgetCancelLabel
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: Theme.fg
                                customSize: Constants.sizeXs + 2
                            }

                            TapHandler {
                                enabled: !forgetSavedProc.running
                                onTapped: {
                                    root.forgetProfileUuid = "";
                                    root.forgetProfileSsid = "";
                                    root.savedActionMessage = "";
                                    root.savedActionSuccess = false;
                                }
                            }
                        }

                        Rectangle {
                            implicitWidth: forgetConfirmLabel.implicitWidth + Constants.sizeLg * 2
                            implicitHeight: Constants.size2Xl + 4
                            radius: height / 2
                            color: Theme.accentComplementary
                            opacity: forgetSavedProc.running ? 0.5 : 1

                            ThemedText {
                                id: forgetConfirmLabel
                                anchors.centerIn: parent
                                text: forgetSavedProc.running ? "Removing..." : "Forget"
                                color: Theme.bg
                                customSize: Constants.sizeXs + 2
                                font.bold: true
                            }

                            TapHandler {
                                enabled: !forgetSavedProc.running
                                onTapped: {
                                    root.savedActionMessage = "";
                                    root.savedActionSuccess = false;

                                    const target = root.forgetProfileUuid !== ""
                                        ? ("uuid:" + root.forgetProfileUuid)
                                        : root.forgetProfileSsid;

                                    forgetSavedProc.command = [
                                        "python3",
                                        Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py",
                                        "forget",
                                        target
                                    ];
                                    forgetSavedProc.running = true;
                                }
                            }
                        }
                    }
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: parent.width
                spacing: Constants.sizeLg

                ColumnLayout {
                    visible: root.showSavedProfiles
                    Layout.fillWidth: true
                    spacing: Constants.sizeMd

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Constants.sizeSm

                        SvgIconButton {
                            icon: "chevron-left"
                            iconSize: Constants.sizeLg
                            flat: true
                            onClicked: {
                                root.showSavedProfiles = false;
                                root.editingProfileUuid = "";
                                root.newSavedPassword = "";
                                root.savedActionMessage = "";
                            }
                        }

                        ThemedText {
                            text: "Back to nearby networks"
                            color: Theme.fg
                            customSize: Constants.sizeSm
                            Layout.fillWidth: true
                        }

                        SvgIconButton {
                            icon: "reload"
                            iconSize: Constants.sizeMd
                            flat: true
                            onClicked: root.loadSavedProfiles()
                        }
                    }

                    ThemedText {
                        visible: savedProfilesProc.running
                        text: "Loading saved networks..."
                        color: Theme.muted
                        customSize: Constants.sizeXs + 2
                        Layout.fillWidth: true
                    }

                    ThemedText {
                        visible: !savedProfilesProc.running && root.savedProfiles.length === 0
                        text: "No saved Wi-Fi profiles found."
                        color: Theme.muted
                        customSize: Constants.sizeSm
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: root.savedProfiles
                        delegate: SavedWifiProfileDelegate {
                            controller: root
                            profileData: modelData
                        }
                    }

                    ThemedText {
                        visible: root.savedActionMessage !== ""
                        text: root.savedActionMessage
                        color: root.savedActionSuccess ? Theme.accent : Theme.accentComplementary
                        customSize: Constants.sizeXs + 2
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                // Saved / Known Networks
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Constants.sizeMd
                    visible: !root.showSavedProfiles && root.savedList.length > 0

                    ThemedText {
                        text: "Saved networks"
                        customSize: Constants.sizeXs + 2
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                        color: Theme.muted
                        Layout.fillWidth: true
                        Layout.leftMargin: Constants.size2Xs
                    }

                    Repeater {
                        model: root.savedList

                        ControlCenterListDelegate {
                            wifiStyle: true
                            isConnecting: root.connecting && root.connectErrorSsid === modelData.ssid
                            Layout.fillWidth: true
                            width: parent.width
                            titleText: modelData.ssid
                            subtitleText: root.connecting && root.connectErrorSsid === modelData.ssid
                                ? "Connecting..."
                                : (modelData.active
                                    ? ("Connected • " + (modelData.signal > 75 ? "Excellent signal" : (modelData.signal > 50 ? "Good signal" : "Weak signal")))
                                    : (modelData.signal > 75 ? "Excellent signal" : (modelData.signal > 50 ? "Good signal" : "Weak signal")))
                            iconName: root.getWifiIcon(modelData.signal)
                            isActive: modelData.active
                            canForget: true
                            onClicked: root.requestConnect(modelData)
                            onActionClicked: {
                                settingsProc.running = true;
                            }
                            onDisconnectClicked: {
                                disconnectProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py", "disconnect", modelData.ssid];
                                disconnectProc.running = true;
                            }
                            onForgetClicked: {
                                root.askForgetProfile(modelData.ssid, modelData.profile_uuid || "");
                            }
                        }

                    }

                }

                // Available Networks (Never connected)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Constants.sizeMd
                    visible: !root.showSavedProfiles && root.availableList.length > 0

                    ThemedText {
                        text: "Available networks"
                        customSize: Constants.sizeXs + 2
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                        color: Theme.muted
                        Layout.fillWidth: true
                        Layout.leftMargin: Constants.size2Xs
                    }

                    Repeater {
                        model: root.availableList

                        ColumnLayout {
                            id: netItem

                            readonly property bool isPending: root.pendingSsid === modelData.ssid
                            property bool showPassword: false

                            Layout.fillWidth: true
                            width: parent.width
                            spacing: Constants.sizeXs

                            ControlCenterListDelegate {
                                wifiStyle: true
                                isConnecting: root.connecting && root.connectErrorSsid === modelData.ssid
                                Layout.fillWidth: true
                                titleText: modelData.ssid
                                subtitleText: root.connecting && root.connectErrorSsid === modelData.ssid
                                    ? "Connecting..."
                                    : (modelData.signal > 75 ? "Excellent signal" : (modelData.signal > 50 ? "Good signal" : "Weak signal"))
                                iconName: root.getWifiIcon(modelData.signal)
                                isActive: false
                                onClicked: root.requestConnect(modelData)
                            }

                            Rectangle {
                                id: pwBlock

                                Layout.fillWidth: true
                                Layout.preferredHeight: netItem.isPending ? pwCol.implicitHeight + Constants.sizeMd * 2 : 0
                                opacity: netItem.isPending ? 1 : 0
                                visible: opacity > 0.001
                                clip: true
                                radius: Constants.sizeMd
                                color: Theme.bgSecondary
                                border.width: 1
                                border.color: Theme.border

                                Connections {
                                    function onFocusPasswordRequested() {
                                        if (netItem.isPending)
                                            pwField.forceActiveFocus();

                                    }

                                    function onPendingSsidChanged() {
                                        pwField.text = "";
                                        netItem.showPassword = false;
                                    }

                                    target: root
                                }

                                ColumnLayout {
                                    id: pwCol

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: Constants.sizeMd
                                    spacing: Constants.sizeSm

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Constants.sizeXs

                                        VeyraTextField {
                                            id: pwField

                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            echoMode: netItem.showPassword
                                                ? TextInput.Normal : TextInput.Password
                                            placeholderText: "Wi-Fi password"
                                            color: Theme.fg
                                            placeholderTextColor: Theme.muted
                                            selectByMouse: true
                                            enabled: !root.connecting
                                            onTextChanged: root.passwordInput = text
                                            onAccepted: root.submitPassword()
                                            Keys.onEscapePressed: root.cancelPassword()

                                            background: Rectangle {
                                                radius: Constants.sizeSm
                                                color: Theme.isDark
                                                    ? Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.68)
                                                    : Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.82)
                                                border.width: pwField.activeFocus ? 1.5 : 1
                                                border.color: pwField.activeFocus ? Theme.accent : (pwField.hovered ? Theme.muted : Theme.border)
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth:
                                                showPasswordLabel.implicitWidth + Constants.sizeMd * 2
                                            Layout.preferredHeight: pwField.implicitHeight
                                            radius: height / 2
                                            color: Theme.bg
                                            border.width: 1
                                            border.color: Theme.border

                                            ThemedText {
                                                id: showPasswordLabel
                                                anchors.centerIn: parent
                                                text: netItem.showPassword ? "Hide" : "Show"
                                                color: Theme.fg
                                                customSize: Constants.sizeXs + 2
                                            }

                                            TapHandler {
                                                onTapped: netItem.showPassword = !netItem.showPassword
                                            }

                                            HoverHandler {
                                                cursorShape: Qt.PointingHandCursor
                                            }
                                        }
                                    }

                                    ThemedText {
                                        visible: root.connectError !== "" && root.connectErrorSsid === modelData.ssid
                                        text: root.connectError
                                        color: Qt.rgba(0.9, 0.4, 0.4, 1)
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Constants.sizeSm

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        Rectangle {
                                            implicitWidth: cancelLbl.implicitWidth + Constants.sizeLg * 2
                                            implicitHeight: 30
                                            radius: height / 2
                                            color: Theme.bg

                                            ThemedText {
                                                id: cancelLbl

                                                anchors.centerIn: parent
                                                text: "Cancel"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.cancelPassword()
                                            }

                                        }

                                        Rectangle {
                                            implicitWidth: connectLbl.implicitWidth + Constants.sizeLg * 2
                                            implicitHeight: 30
                                            radius: height / 2
                                            color: Theme.accent
                                            opacity: root.connecting ? 0.5 : 1

                                            ThemedText {
                                                id: connectLbl

                                                anchors.centerIn: parent
                                                text: root.connecting ? "Connecting..." : "Connect"
                                                color: Theme.bg
                                                font.bold: true
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                enabled: !root.connecting
                                                onClicked: root.submitPassword()
                                            }

                                        }

                                    }

                                }

                                Behavior on Layout.preferredHeight {
                                    NumberAnimation {
                                        duration: Constants.animNormal
                                        easing.type: Easing.OutCubic
                                    }

                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Constants.animNormal
                                    }

                                }

                            }

                        }

                    }

                }

            }

        }

    }

    Process {
        id: savedProfilesProc

        command: ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py", "saved"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return;
                try {
                    const result = JSON.parse(data.trim());
                    root.savedProfiles = Array.isArray(result) ? result : [];
                } catch (e) {
                    root.savedProfiles = [];
                    root.savedActionMessage = "Could not read saved Wi-Fi profiles.";
                    root.savedActionSuccess = false;
                }
            }
        }
    }

    Process {
        id: showSavedPasswordProc

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return;

                const targetUuid = root.loadingSavedPasswordUuid;
                root.loadingSavedPasswordUuid = "";

                try {
                    const result = JSON.parse(data.trim());

                    if (result.success && targetUuid !== "" && root.showSavedProfiles) {
                        root.shownSavedPasswordUuid = targetUuid;
                        root.shownSavedPassword = String(result.password || "");
                        root.savedActionMessage = "";
                        root.savedActionSuccess = true;
                    } else if (targetUuid !== "") {
                        root.shownSavedPasswordUuid = "";
                        root.shownSavedPassword = "";
                        root.savedActionMessage = result.output || "Could not read the saved password.";
                        root.savedActionSuccess = false;
                    }
                } catch (e) {
                    root.shownSavedPasswordUuid = "";
                    root.shownSavedPassword = "";
                    root.savedActionMessage = "Could not read NetworkManager's password response.";
                    root.savedActionSuccess = false;
                }
            }
        }
    }

    Process {
        id: savedPasswordProc

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return;
                try {
                    const result = JSON.parse(data.trim());
                    root.savedActionMessage = result.output || (
                        result.success ? "Password saved. Reconnect to use it." : "Could not save the password."
                    );
                    root.savedActionSuccess = !!result.success;

                    if (result.success) {
                        root.editingProfileUuid = "";
                        root.newSavedPassword = "";
                        root.loadSavedProfiles();
                    }
                } catch (e) {
                    root.savedActionMessage = "Could not read NetworkManager's response.";
                    root.savedActionSuccess = false;
                }
            }
        }
    }

    Process {
        id: forgetSavedProc

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return;
                try {
                    const result = JSON.parse(data.trim());
                    root.savedActionMessage = result.output || (
                        result.success ? "Saved network removed." : "Could not remove the saved network."
                    );
                    root.savedActionSuccess = !!result.success;

                    if (result.success) {
                        root.forgetProfileUuid = "";
                        root.forgetProfileSsid = "";
                        root.shownSavedPasswordUuid = "";
                        root.shownSavedPassword = "";
                        root.refreshRequested();
                        if (root.showSavedProfiles)
                            root.loadSavedProfiles();
                    }
                } catch (e) {
                    root.savedActionMessage = "Could not read NetworkManager's response.";
                    root.savedActionSuccess = false;
                }
            }
        }
    }

    Process {
        id: settingsProc

        command: ["nm-connection-editor"]
    }

    Process {
        id: disconnectProc

        onRunningChanged: {
            if (!running)
                root.refreshRequested();

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

    Behavior on Layout.preferredHeight {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: root.expanded ? Easing.OutExpo : Easing.OutCubic
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: root.expanded ? Easing.Linear : Easing.OutCubic
        }

    }

}
