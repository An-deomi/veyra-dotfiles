import QtQuick
import qs.Modules.Music as MusicModule
import qs.Modules.Bar.Components as BarComponents
import qs.Modules.Bar.Styles.Island as IslandModule

Item {
    id: root

    required property QtObject centerWidget
    required property int flareW
    required property int contentPadding
    required property bool isClosing
    required property real openProgress
    required property bool isOpen
    required property string activeContentType
    readonly property alias item: contentLoader.item

    function focusLoadedItem() {
        if (!root.isOpen || !contentLoader.item)
            return;
        if (typeof contentLoader.item.forceActiveFocus === "function")
            contentLoader.item.forceActiveFocus();
    }

    onIsOpenChanged: {
        if (isOpen)
            focusDelay.restart();
    }
    onActiveContentTypeChanged: {
        if (isOpen)
            focusDelay.restart();
    }

    Timer {
        id: focusDelay
        interval: 40
        repeat: false
        onTriggered: root.focusLoadedItem()
    }

    anchors.fill: parent
    anchors.leftMargin: root.flareW + root.contentPadding
    anchors.rightMargin: root.flareW + root.contentPadding
    anchors.topMargin: root.contentPadding
    anchors.bottomMargin: root.contentPadding
    clip: true
    opacity: root.isClosing ? Math.min(1, Math.max(0, (root.openProgress - 0.4) / 0.6)) : Math.min(1, Math.max(0, (root.openProgress - 0.2) / 0.8))
    scale: root.isClosing ? (0.94 + 0.06 * Math.min(1, Math.max(0, (root.openProgress - 0.3) / 0.7))) : (0.94 + 0.06 * Math.min(1, Math.max(0, (root.openProgress - 0.15) / 0.85)))
    visible: opacity > 0.001

    Loader {
        id: contentLoader

        anchors.fill: parent
        active: root.isOpen || root.openProgress > 0.001
        sourceComponent: root.activeContentType === "islandOverview" ? overviewComp : (root.activeContentType === "sysmon" ? sysmonComp : (root.activeContentType === "music" ? musicComp : null))
        onLoaded: {
            if (root.isOpen)
                focusDelay.restart();
        }
    }

    Component {
        id: overviewComp

        IslandModule.IslandOverview {
            widget: root.centerWidget
        }
    }

    Component {
        id: sysmonComp

        BarComponents.SysMonPanel {
        }
    }

    Component {
        id: musicComp

        MusicModule.MiniMusicWidget {
            widget: root.centerWidget
        }

    }

}
