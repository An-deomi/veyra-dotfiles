import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

RowLayout {
    id: root

    property string processName: ""
    property string pidText: ""
    property string cpuText: ""
    property string memoryText: ""

    Layout.fillWidth: true
    Layout.preferredHeight: 22
    spacing: 8

    ThemedText {
        Layout.fillWidth: true
        text: root.processName
        customSize: 10
        elide: Text.ElideRight
    }

    ThemedText {
        text: root.pidText.length ? "#" + root.pidText : ""
        customSize: 8
        color: Theme.muted
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 34
    }

    ThemedText {
        text: root.cpuText
        customSize: 10
        color: Theme.accent
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 42
    }

    ThemedText {
        text: root.memoryText
        customSize: 10
        color: Theme.muted
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 42
    }
}
