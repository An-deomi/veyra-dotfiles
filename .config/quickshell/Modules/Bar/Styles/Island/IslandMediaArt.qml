import Qt5Compat.GraphicalEffects
import QtQuick
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar.Components

Item {
    id: root

    property bool clickable: true
    readonly property bool hasPlayingMedia: MprisService.activePlayer !== null && (((MprisService.activePlayer.trackTitle || "").trim() !== "") || ((MprisService.activePlayer.trackArtist || "").trim() !== ""))
    // The right capsule can switch between media and Control Center modes.
    property bool showMedia: true

    clip: true

    // Media Album Art
    Item {
        id: mediaArtBox

        width: Constants.sizeXl
        height: Constants.sizeXl
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        // Album art occupies the leading slot only while a track is active.
        // The idle shortcut icon is centered on the full capsule below.
        visible: root.showMedia && root.hasPlayingMedia

        Image {
            id: artImage

            anchors.fill: parent
            source: MprisService.activePlayer ? (MprisService.activePlayer.trackArtUrl || "") : ""
            fillMode: Image.PreserveAspectCrop
            mipmap: true
            asynchronous: true
            visible: false
        }

        Rectangle {
            id: artMask

            anchors.fill: parent
            radius: width / 2
            visible: false
        }

        OpacityMask {
            anchors.fill: parent
            source: artImage
            maskSource: artMask
            visible: artImage.status === Image.Ready && (artImage.source + "").trim() !== ""
        }

        SvgIcon {
            anchors.centerIn: parent
            icon: "music"
            iconSize: Constants.sizeLg
            iconColor: Theme.fg
            visible: root.hasPlayingMedia && (artImage.status !== Image.Ready || (artImage.source + "").trim() === "")
            flat: true
        }

    }

    // Idle state: center the music glyph on the capsule itself, not inside the
    // left-offset album-art slot.
    SvgIcon {
        anchors.centerIn: parent
        icon: "music"
        iconSize: Constants.sizeLg
        iconColor: Theme.fg
        visible: root.showMedia && !root.hasPlayingMedia
        flat: true
    }

    // Mini Equalizer Bars (Dynamic Island style)
    MiniCavaBars {
        id: visualizerRow

        anchors.left: mediaArtBox.right
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        opacity: (SettingsService.barMediaVisualizerEnabled && root.showMedia
            && MprisService.isPlaying && root.width > 36) ? 1 : 0
        visible: SettingsService.barMediaVisualizerEnabled && opacity > 0.001

        Behavior on opacity {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutCubic
            }

        }

    }

    // Tune SVG Icon (Control Center)
    SvgIcon {
        anchors.centerIn: parent
        icon: "tune"
        iconSize: Constants.sizeLg
        iconColor: Theme.fg
        visible: !root.showMedia
        flat: true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: root.clickable
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton && root.showMedia && MprisService.activePlayer) {
                MprisService.activePlayer.togglePlaying();
            } else {
                if (root.showMedia)
                    AppState.toggleWidget("music");
                else
                    AppState.toggleWidget("controlCenter");
            }
        }
    }

}
