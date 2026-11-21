import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

RowLayout {
    id: root

    property string icon: "network"
    property string label: "Network"
    property string value: "Unknown"
    property bool active: false

    spacing: Constants.size2Xs
    Layout.fillWidth: true
    Layout.minimumWidth: 0

    SvgIcon {
        icon: root.icon
        iconSize: Constants.sizeMd
        iconColor: root.active ? Theme.accent : Theme.muted
        flat: true
        Layout.alignment: Qt.AlignVCenter
    }

    ColumnLayout {
        spacing: 0
        Layout.fillWidth: true
        Layout.minimumWidth: 0

        ThemedText {
            text: root.label
            customSize: Constants.sizeXs + 2
            font.bold: true
            color: Theme.muted
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        ThemedText {
            text: root.value
            customSize: Constants.sizeXs + 1
            color: root.active ? Theme.fg : Theme.muted
            Layout.fillWidth: true
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
