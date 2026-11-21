import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

Rectangle {
    id: root

    property string titleText: ""
    property string subtitleText: ""
    property string iconName: ""
    property bool isActive: false
    property bool canForget: false
    property bool wifiStyle: false
    property bool isConnecting: false

    signal clicked()
    signal actionClicked()
    signal disconnectClicked()
    signal forgetClicked()

    Layout.fillWidth: true
    implicitWidth: 280
    implicitHeight: root.wifiStyle ? 60 : 52
    radius: root.wifiStyle ? Constants.sizeMd : Constants.sizeSm
    color: root.wifiStyle
        ? (root.isActive ? Theme.bgAccent : Theme.bgSecondary)
        : Theme.bgTertiary
    border.width: 1
    border.color: root.wifiStyle && root.isActive ? Theme.accent : Theme.border

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Constants.sizeSm
        anchors.rightMargin: Constants.sizeSm
        spacing: Constants.sizeSm

        Rectangle {
            width: Constants.size3Xl - 2
            height: Constants.size3Xl - 2
            radius: height / 2
            color: root.isActive
                ? Theme.accent
                : (root.wifiStyle ? Theme.bgTertiary : Theme.bgSecondary)
            Layout.alignment: Qt.AlignVCenter

            SvgIcon {
                anchors.centerIn: parent
                icon: root.iconName
                iconColor: root.isActive ? Theme.bg : Theme.fg
                iconSize: Constants.sizeLg
                flat: true
                visible: !root.isConnecting
            }

            SvgIcon {
                anchors.centerIn: parent
                icon: "reload"
                iconColor: Theme.accent
                iconSize: Constants.sizeLg
                flat: true
                visible: root.isConnecting

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 850
                    loops: Animation.Infinite
                    running: root.isConnecting
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Constants.animFast
                }

            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            ThemedText {
                text: root.titleText
                color: Theme.fg
                font.bold: root.isActive
                customSize: Constants.sizeSm
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            ThemedText {
                visible: root.subtitleText !== ""
                text: root.subtitleText
                color: root.isActive ? Theme.accent : Theme.muted
                customSize: Constants.sizeXs + 2
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

        }

        Rectangle {
            id: forgetBtn

            visible: root.canForget
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Constants.size2Xl + 4
            implicitHeight: Constants.size2Xl + 4
            radius: Constants.sizeSm
            color: forgetHover.hovered ? Theme.bgSecondary : "transparent"
            border.width: 1
            border.color: forgetHover.hovered ? Theme.border : "transparent"

            SvgIcon {
                anchors.centerIn: parent
                icon: "trash"
                iconColor: forgetHover.hovered ? Theme.accentComplementary : Theme.muted
                iconSize: Constants.sizeSm + 2
                flat: true
            }

            HoverHandler {
                id: forgetHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.forgetClicked()
            }

        }

        Rectangle {
            id: actionBtn

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: btnText.implicitWidth + Constants.sizeXs * 2
            implicitHeight: Constants.size2Xl + 4
            radius: root.wifiStyle ? height / 2 : Constants.sizeSm
            color: root.wifiStyle
                ? (btnHover.hovered ? Theme.bgAccent : Theme.bgAccent)
                : (btnHover.hovered ? Theme.bgSecondary : Theme.bgTertiary)
            border.width: 1
            border.color: Theme.border

            ThemedText {
                id: btnText

                text: root.isConnecting ? "Connecting..." : (root.isActive ? "Disconnect" : "Connect")
                color: root.isConnecting ? Theme.accent : (root.isActive ? Theme.accentComplementary : Theme.fg)
                customSize: Constants.sizeXs + 2
                font.bold: true
                anchors.centerIn: parent
            }

            HoverHandler {
                id: btnHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: {
                    if (root.isActive)
                        root.disconnectClicked();
                    else
                        root.clicked();
                }
            }

        }

    }

}
