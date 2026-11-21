import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.Core

Scope {
    id: root

    PolkitAgent {
        id: agent
        onIsRegisteredChanged: console.log("Veyra Polkit registered:", isRegistered)
        onAuthenticationRequestStarted: password.forceActiveFocus()
    }

    readonly property var flow: agent.flow

    PanelWindow {
        id: dialog
        anchors { top: true; bottom: true; left: true; right: true }
        visible: agent.isActive
        focusable: agent.isActive
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "veyra-polkit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive


        Rectangle {
            anchors.centerIn: parent
            width: Math.min(dialog.width - 32, 420)
            height: content.implicitHeight + 48
            radius: 24
            color: Theme.opaqueBg
            border.color: Theme.border
            border.width: 1

            Column {
                id: content
                anchors { fill: parent; margins: 24 }
                spacing: 16

                Text {
                    text: "Authentication required"
                    color: Theme.fg
                    font.pixelSize: 22
                    font.bold: true
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                Text {
                    text: root.flow ? root.flow.message : ""
                    color: Theme.fg
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                Text {
                    visible: !!root.flow && root.flow.isResponseRequired
                    text: root.flow ? root.flow.inputPrompt : ""
                    color: Theme.fg
                    width: parent.width
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: 48
                    radius: Constants.sizeSm
                    color: Theme.isDark
                        ? Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.68)
                        : Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.82)
                    border.width: password.activeFocus ? 1.5 : 1
                    border.color: password.activeFocus ? Theme.accent : Theme.border

                    TextInput {
                        id: password
                        anchors.fill: parent
                        anchors.margins: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.fg
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.bg
                        echoMode: root.flow && root.flow.responseVisible
                            ? TextInput.Normal : TextInput.Password
                        enabled: !!root.flow && root.flow.isResponseRequired
                        onAccepted: root.submitResponse()
                        Keys.onEscapePressed: root.cancelRequest()
                    }
                }

                Text {
                    width: parent.width
                    visible: !!root.flow && root.flow.supplementaryMessage.length > 0
                    text: root.flow ? root.flow.supplementaryMessage : ""
                    color: root.flow && root.flow.supplementaryIsError
                        ? "#ff7777" : Theme.fg
                    wrapMode: Text.WordWrap
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 44
                        radius: 12
                        color: Theme.bgSecondary

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Theme.fg
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.cancelRequest()
                        }
                    }

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 44
                        radius: 12
                        color: Theme.accent
                        opacity: root.flow && root.flow.isResponseRequired ? 1 : 0.5

                        Text {
                            anchors.centerIn: parent
                            text: "Authenticate"
                            color: Theme.bg
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !!root.flow && root.flow.isResponseRequired
                            onClicked: root.submitResponse()
                        }
                    }
                }
            }
        }
    }

    function submitResponse() {
        if (!flow || !flow.isResponseRequired)
            return
        const value = password.text
        password.text = ""
        flow.submit(value)
    }

    function cancelRequest() {
        if (flow)
            flow.cancelAuthenticationRequest()
        password.text = ""
    }

    Connections {
        target: root.flow
        ignoreUnknownSignals: true

        function onIsResponseRequiredChanged() {
            password.text = ""
            if (root.flow && root.flow.isResponseRequired)
                password.forceActiveFocus()
        }

        function onAuthenticationFailed() {
            password.text = ""
            password.forceActiveFocus()
        }
    }
}
