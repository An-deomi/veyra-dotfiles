import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

// Shared capsule for every OSD event routed through IslandEventService
// (volume, microphone, brightness, media, recording, workspace).
//
// The toast is content, not a second surface: it draws directly on the island
// pill instead of nesting another card inside it. Layout is one compact row —
// flat icon, muted title, bright tabular value — with a thin accent progress
// line along the bottom. The pill is sized from the toast's implicit width, so
// short events (Workspace 2) stay narrow while media titles are capped instead
// of stretching the island across the screen.
Item {
    id: root

    readonly property bool isAttention: IslandEventService.eventType === "recording"
    readonly property color highlight: root.isAttention ? Chrome.attention : Theme.accent
    readonly property bool hasPercent: IslandEventService.eventPercent >= 0

    // Clamped content width: the row may not shrink below a readable minimum
    // or grow past a sane maximum. The pill animates between these widths.
    implicitWidth: Math.min(280, Math.max(132, eventRow.implicitWidth))
    implicitHeight: Math.max(26, eventRow.implicitHeight + 10)
    height: parent ? parent.height : implicitHeight
    opacity: IslandEventService.eventActive ? 1 : 0
    scale: IslandEventService.eventActive ? 1 : 0.98

    Behavior on opacity {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutCubic
        }
    }

    RowLayout {
        id: eventRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.hasPercent ? -2 : 0
        spacing: 7

        Item {
            id: toastArtBox

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            visible: IslandEventService.eventType === "media" && toastArt.status === Image.Ready && (IslandEventService.eventArtUrl || "") !== ""

            Image {
                id: toastArt

                anchors.fill: parent
                source: IslandEventService.eventArtUrl || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                mipmap: true
                visible: false
            }

            Rectangle {
                id: toastArtMask

                anchors.fill: parent
                radius: width / 2
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: toastArt
                maskSource: toastArtMask
            }
        }

        SvgIcon {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Constants.sizeLg
            Layout.preferredHeight: Constants.sizeLg
            icon: IslandEventService.eventIcon
            iconColor: root.isAttention ? Chrome.attention : Theme.fg
            iconSize: Constants.sizeLg
            flat: true
            visible: !toastArtBox.visible
        }

        ThemedText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Math.min(implicitWidth, 96)
            text: IslandEventService.eventTitle
            customSize: 11
            font.weight: Font.DemiBold
            color: Theme.muted
            elide: Text.ElideRight
            maximumLineCount: 1
            visible: text !== ""
        }

        ThemedText {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            Layout.preferredWidth: Math.min(implicitWidth, 110)
            horizontalAlignment: Text.AlignRight
            text: IslandEventService.eventValue
            customSize: 12
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
            color: Theme.fg
            elide: Text.ElideRight
            maximumLineCount: 1
            visible: text !== ""
        }
    }

    // Sits just above the pill's bottom edge, inset enough to clear the
    // capsule radius so the line never pokes past the rounded corner.
    Rectangle {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.bottomMargin: Constants.size3Xs
        height: Constants.size3Xs
        radius: height / 2
        color: Theme.border
        visible: root.hasPercent

        Rectangle {
            id: fill

            width: parent.width * Math.max(0, Math.min(100, IslandEventService.eventPercent)) / 100
            height: parent.height
            radius: parent.radius
            color: root.highlight

            Behavior on width {
                NumberAnimation {
                    duration: Constants.animFast
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
