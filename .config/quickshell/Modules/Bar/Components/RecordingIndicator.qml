import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    property int animationDuration: HyprlandService.enableAnimations ? Constants.animExpressive : 0
    property int customHeight: 0
    readonly property int actualHeight: customHeight > 0 ? customHeight : SettingsService.barWidgetHeight
    readonly property var easeCurve: [0.25, 0.1, 0.25, 1, 1, 1]
    readonly property var overshotCurve: [0.13, 0.99, 0.29, 1.05, 1, 1]

    implicitWidth: contentRow.implicitWidth + 24
    implicitHeight: actualHeight
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: actualHeight
    visible: opacity > 0.001
    clip: true

    states: [
        State {
            name: "running"
            when: RecorderService.running
            PropertyChanges { target: root; Layout.preferredWidth: container.width; opacity: 1 }
        },
        State {
            name: "hidden"
            when: !RecorderService.running
            PropertyChanges { target: root; Layout.preferredWidth: 0; opacity: 0 }
        }
    ]

    transitions: [
        Transition {
            from: "hidden"
            to: "running"
            NumberAnimation { property: "Layout.preferredWidth"; duration: Constants.animNormal; easing.type: Easing.OutQuint }
            NumberAnimation { property: "opacity"; duration: Constants.animFast; easing.type: Easing.Linear }
        },
        Transition {
            from: "running"
            to: "hidden"
            NumberAnimation { property: "Layout.preferredWidth"; duration: Constants.animNormal; easing.type: Easing.OutQuint }
            NumberAnimation { property: "opacity"; duration: Constants.animFast; easing.type: Easing.Linear }
        }
    ]

    Item {
        anchors.fill: parent
        clip: true

        Item {
            id: container
            width: innerRect.width
            height: innerRect.height
            anchors.centerIn: parent

            Rectangle {
                id: innerRect
                property bool isHovered: pauseMouse.containsMouse || stopMouse.containsMouse
                property bool isPressed: pauseMouse.pressed || stopMouse.pressed
                width: contentRow.implicitWidth + 16
                height: root.actualHeight
                color: (isHovered || isPressed) ? Theme.bgTertiary : Theme.bgSecondary
                radius: height / 2
                scale: isPressed ? 0.98 : (isHovered ? 1.01 : 1)

                Row {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: Constants.sizeXs

                    Rectangle {
                        width: Constants.sizeXs
                        height: Constants.sizeXs
                        radius: height / 2
                        color: RecorderService.paused ? Theme.accent : Theme.accentComplementary
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on opacity {
                            running: RecorderService.running && !RecorderService.paused
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: Constants.animFast + 50; easing.type: Easing.OutSine }
                            NumberAnimation { to: 1; duration: Constants.animFast + 50; easing.type: Easing.InSine }
                            PauseAnimation { duration: Constants.animExpressive + 100 }
                        }
                    }

                    ThemedText {
                        text: RecorderService.paused ? ("PAUSED " + RecorderService.formattedTime()) : RecorderService.formattedTime()
                        color: Theme.fg
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        id: pauseButton
                        width: root.actualHeight - 6
                        height: root.actualHeight - 6
                        radius: height / 2
                        color: pauseMouse.containsMouse ? Theme.accent : Theme.bgTertiary
                        anchors.verticalCenter: parent.verticalCenter

                        SvgIcon {
                            anchors.centerIn: parent
                            icon: RecorderService.paused ? "player-play" : "player-pause"
                            iconColor: Theme.fg
                            iconSize: Constants.sizeSm
                            flat: true
                        }

                        MouseArea {
                            id: pauseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: RecorderService.togglePause()
                        }
                    }

                    Rectangle {
                        id: stopButton
                        width: root.actualHeight - 6
                        height: root.actualHeight - 6
                        radius: height / 2
                        color: stopMouse.containsMouse ? Theme.accentComplementary : Theme.bgTertiary
                        anchors.verticalCenter: parent.verticalCenter

                        SvgIcon {
                            anchors.centerIn: parent
                            icon: "player-stop"
                            iconColor: Theme.fg
                            iconSize: Constants.sizeSm
                            flat: true
                        }

                        MouseArea {
                            id: stopMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: RecorderService.stop()
                        }
                    }
                }
            }
        }
    }
}
