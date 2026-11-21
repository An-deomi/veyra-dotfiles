import QtQuick
import qs.Core
import qs.Core.Services

// Compact download-only readout. IslandLeftPill supplies the shared
// capsule background, border and shadow used by the other Island capsules.
Item {
    id: root

    readonly property real downloadBps: NetSpeedService.downloadBps

    // Width follows the reading so "8.9 MB/s" is not elided to "8.9 M…".
    // The Island capsule adds its own outer padding around this item.
    implicitWidth: Math.max(44, Math.ceil(rateText.implicitWidth) + Constants.sizeXs)
    implicitHeight: 32
    width: implicitWidth
    height: implicitHeight

    function formatRate(bytesPerSecond) {
        const value = Math.max(0, Number(bytesPerSecond) || 0);
        if (value >= 1048576)
            return (value / 1048576).toFixed(value >= 10 * 1048576 ? 0 : 1) + " MB/s";
        if (value >= 1024)
            return (value / 1024).toFixed(value >= 100 * 1024 ? 0 : 1) + " KB/s";
        return Math.round(value) + " B/s";
    }

    Text {
        id: rateText

        anchors.centerIn: parent
        text: root.formatRate(root.downloadBps)
        color: Theme.fg
        font.family: Constants.fontFamily
        font.pixelSize: 8
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: AppState.toggleWidget("sysmon")
    }
}
