import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

Item {
    id: root

    property string label: ""
    property string description: ""
    property int labelSize: Constants.sizeSm
    property bool isSubSetting: false
    default property alias content: controlContainer.data

    implicitHeight: mainLayout.implicitHeight
    Layout.fillWidth: true

    RowLayout {
        id: mainLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Constants.sizeLg

        // The text column takes the leftover width and wraps, so a long
        // description can never push the control past the card edge.
        ColumnLayout {
            spacing: Constants.size3Xs
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

            ThemedText {
                text: root.label
                customSize: root.labelSize
                font.weight: Font.Medium
                color: root.enabled ? Theme.fg : Theme.muted
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            ThemedText {
                text: root.description
                customSize: 11
                color: Theme.muted
                visible: root.description !== ""
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

        }

        Item {
            id: controlContainer

            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }

    }

}
